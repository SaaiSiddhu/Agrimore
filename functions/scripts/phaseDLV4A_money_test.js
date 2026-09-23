// Phase DLV-4A — rider money engine against the Firestore emulator
// (functions/src/delivery/riderMoney.ts + the dispatch hooks).
//
//  e — earning per delivered order: road km from the route, waiting, COD
//      cash held + ledger + order codSettlementStatus; exactly once
//  k — cash deposits (admin): never more than held
//  w — weekly statements: net = earned − cash, idempotent, cutoff respected,
//      on_hold without bank details / with a pending change, cash carried
//  b — bank changes: validated, one pending at a time, approve copies and
//      releases held statements, reject keeps the old details
//  d — dispatch: a rider at the cash limit gets no COD offer (still gets a
//      prepaid one); offers carry estimatedPay
//
// Run with:
//   firebase emulators:exec --only firestore "node scripts/phaseDLV4A_money_test.js"
// Requires: npm run build. Honours FIRESTORE_EMULATOR_HOST.
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: "demo-dlv4a-money" });
const db = admin.firestore();
const { Timestamp } = require("firebase-admin/firestore");
const M = require("../lib/delivery/riderMoney");
const D = require("../lib/delivery/dispatch");
const P = require("../lib/delivery/riderPay");

const results = [];
function record(label, pass, detail) {
  results.push({ label, pass });
  console.log(`${pass ? "PASSED" : "FAILED"} — ${label}${pass ? "" : ` :: ${detail}`}`);
}
const STORE = { lat: 9.9252, lng: 78.1198 };
const HOME = { lat: 9.8982, lng: 78.1198 };
const RATES = P.DEFAULT_RIDER_PAY_RATES;
// A Thursday; its statement cutoff is Monday 2026-09-21 00:00 IST.
const THU = Date.UTC(2026, 8, 24, 6, 0, 0);
const BEFORE_CUTOFF = Date.UTC(2026, 8, 19, 8, 0, 0);
const MIN = 60000;
const get = async (path) => (await db.doc(path).get()).data();

let n = 0;
async function deliveredOrder(rider, extra = {}, task = {}) {
  const id = `dlv4a-o${++n}`;
  await db.doc(`orders/${id}`).set({
    userId: "c", sellerId: "s", orderNumber: id.toUpperCase(), total: 480, paymentMethod: "cod",
    orderStatus: "delivered", status: "delivered", deliveryPartnerId: rider,
    deliveryAddress: { latitude: HOME.lat, longitude: HOME.lng }, ...extra,
  });
  await db.doc(`delivery_tasks/${id}`).set({ orderId: id, status: "delivered", pickup: STORE, drop: HOME, ...task });
  return id;
}

async function main() {
  console.log("=== PHASE DLV-4A — rider money engine ===");
  // ── e: earnings ──
  const via = { plan: "via_pickup", legs: [{ distanceMeters: 2100 }, { distanceMeters: 3911 }] };
  const o1 = await deliveredOrder("r1", {
    arrivedAtStoreAt: Timestamp.fromMillis(BEFORE_CUTOFF), pickedUpAt: Timestamp.fromMillis(BEFORE_CUTOFF + 17 * MIN),
  }, { route: via });
  const v1 = await M.recordDeliveryEarningCore(db, o1, BEFORE_CUTOFF + 40 * MIN, RATES);
  const e1 = await get(`rider_earnings/${o1}`);
  record("e01_pay_base_road_km_waiting", v1.kind === "created" && e1.total === 25 + 23.46 + 7 && e1.kmSource === "route" &&
    e1.waitMinutes === 7 && e1.riderId === "r1" && e1.statementId === null && e1.rates.basePay === 25, JSON.stringify(e1));
  const a1 = await get("rider_accounts/r1");
  const o1d = await get(`orders/${o1}`);
  const ledger1 = (await db.collection("rider_cash_ledger").where("orderId", "==", o1).get()).docs.map((d) => d.data());
  record("e02_cod_cash_held_ledger_and_order_status", v1.cod === 480 && a1.cashHeld === 480 && a1.earningsUnsettled === 55.46 &&
    o1d.codSettlementStatus === "collected" && ledger1.length === 1 && ledger1[0].type === "cash_collected", JSON.stringify({ a1, ledger1 }));
  const again = await M.recordDeliveryEarningCore(db, o1, BEFORE_CUTOFF + 50 * MIN, RATES);
  const a1b = await get("rider_accounts/r1");
  record("e03_exactly_once", again.kind === "already" && a1b.cashHeld === 480 && a1b.earningsUnsettled === 55.46, JSON.stringify({ again, a1b }));
  const o2 = await deliveredOrder("r1", { paymentMethod: "razorpay", paymentStatus: "paid" });
  const v2 = await M.recordDeliveryEarningCore(db, o2, BEFORE_CUTOFF + 60 * MIN, RATES);
  const o2d = await get(`orders/${o2}`);
  record("e04_prepaid_no_cash_straight_line_fallback", v2.kind === "created" && v2.cod === 0 && o2d.codSettlementStatus === undefined &&
    (await get(`rider_earnings/${o2}`)).kmSource === "straight_line", JSON.stringify(v2));
  const o3 = await deliveredOrder("r1", { orderStatus: "out_for_delivery", status: "out_for_delivery" });
  record("e05_not_delivered_skipped", (await M.recordDeliveryEarningCore(db, o3, THU, RATES)).kind === "skipped" && !(await get(`rider_earnings/${o3}`)), "");
  const o4 = await deliveredOrder(null);
  record("e06_no_rider_skipped", (await M.recordDeliveryEarningCore(db, o4, THU, RATES)).reason === "no_rider", "");
  const o5 = await deliveredOrder("r1", { paymentMethod: "cod", paymentStatus: "paid" });
  record("e07_cod_already_paid_online_holds_no_cash", (await M.recordDeliveryEarningCore(db, o5, BEFORE_CUTOFF + 70 * MIN, RATES)).cod === 0, "");
  // No task yet and no pickup on the order: the seller's store location is used.
  await db.doc("sellers/geo-seller").set({ storeLat: STORE.lat, storeLng: STORE.lng });
  await db.doc("orders/dlv4a-notask").set({ userId: "c", sellerId: "geo-seller", total: 480, paymentMethod: "razorpay", paymentStatus: "paid",
    orderStatus: "delivered", status: "delivered", deliveryPartnerId: "r-geo", deliveryAddress: { latitude: HOME.lat, longitude: HOME.lng } });
  await M.recordDeliveryEarningCore(db, "dlv4a-notask", THU, RATES);
  const eg = await get("rider_earnings/dlv4a-notask");
  record("e08_no_task_uses_the_sellers_store", eg.kmSource === "straight_line" && eg.km > 3.9 && eg.total > 45, JSON.stringify(eg));
  // A delivery after the cutoff (this week) — must NOT be in last week's statement.
  const o6 = await deliveredOrder("r1", { paymentMethod: "razorpay", paymentStatus: "paid" });
  await M.recordDeliveryEarningCore(db, o6, THU, RATES);

  // ── k: deposits ──
  const k1 = await M.recordCashDepositCore(db, "admin1", "r1", 500, "RCPT-1", THU);
  const k2 = await M.recordCashDepositCore(db, "admin1", "r1", 100, "R", THU);
  const k3 = await M.recordCashDepositCore(db, "admin1", "r1", 400, "RCPT-2", THU);
  const a1c = await get("rider_accounts/r1");
  record("k01_deposit_bounded_by_cash_held", k1.kind === "refused" && k1.reason === "more_than_held" && k2.reason === "bad_reference" &&
    k3.kind === "recorded" && k3.cashHeld === 80 && a1c.cashHeld === 80, JSON.stringify({ k1, k2, k3 }));

  // ── w: statements ──
  await db.doc("delivery_partners/r1").set({ status: "approved", bankAccountNumber: "123456789012", ifscCode: "SBIN0001234", accountHolderName: "Ravi" });
  const w1 = await M.buildStatementCore(db, "r1", THU);
  const st = await get(`rider_payouts/${w1.id}`);
  let earnedBefore = 0; // o1, o2, o5 are before the cutoff; o6 is after it
  for (const id of [o1, o2, o5]) earnedBefore += (await get(`rider_earnings/${id}`)).total;
  record("w01_statement_nets_cash", w1.kind === "created" && st.status === "pending" && st.weekKey === "2026-W38" &&
    Math.abs(st.earned - earnedBefore) < 0.011 && st.netted === 80 && Math.abs(st.amount - (earnedBefore - 80)) < 0.011 &&
    st.cashHeldAfter === 0 && st.orderCount === 3, JSON.stringify(st));
  const lines = (await db.collection("rider_earnings").where("riderId", "==", "r1").get()).docs.map((d) => [d.id, d.data().statementId]);
  record("w02_cutoff_respected_and_lines_stamped", lines.filter(([, s]) => s === w1.id).length === 3 &&
    lines.find(([id]) => id === o6)[1] === null && (await get("rider_accounts/r1")).cashHeld === 0, JSON.stringify(lines));
  record("w03_idempotent", (await M.buildStatementCore(db, "r1", THU + 3600000)).kind === "exists", "");
  // More cash than pay: nothing to pay, cash carried.
  const o7 = await deliveredOrder("r2", { total: 3000 });
  await M.recordDeliveryEarningCore(db, o7, BEFORE_CUTOFF, RATES);
  const w4 = await M.buildStatementCore(db, "r2", THU);
  const st4 = await get(`rider_payouts/${w4.id}`);
  const a2 = await get("rider_accounts/r2");
  record("w04_cash_over_pay_carries_forward", st4.status === "nothing_to_pay" && st4.amount === 0 && Math.abs(a2.cashHeld - (3000 - st4.earned)) < 0.011, JSON.stringify({ st4, a2 }));
  // No bank details: on hold.
  const o8 = await deliveredOrder("r3", { paymentMethod: "razorpay", paymentStatus: "paid" });
  await M.recordDeliveryEarningCore(db, o8, BEFORE_CUTOFF, RATES);
  await db.doc("delivery_partners/r3").set({ status: "approved" });
  const w5 = await M.buildStatementCore(db, "r3", THU);
  record("w05_no_bank_on_hold", (await get(`rider_payouts/${w5.id}`)).holdReason === "no_bank_details", JSON.stringify(w5));
  record("w06_nothing_owed_no_statement", (await M.buildStatementCore(db, "r-idle", THU)).kind === "nothing", "");

  // ── b: bank changes ──
  const b0 = await M.requestBankChangeCore(db, "nobody", { upiId: "xy@upi" }, THU);
  const bBad = await M.requestBankChangeCore(db, "r3", { accountHolderName: "R3", bankAccountNumber: "12", ifscCode: "SBIN0001234" }, THU);
  const b1 = await M.requestBankChangeCore(db, "r3", { accountHolderName: "Rider Three", bankAccountNumber: "998877665544", ifscCode: "HDFC0001234" }, THU);
  const b2 = await M.requestBankChangeCore(db, "r3", { upiId: "r3@upi" }, THU);
  record("b01_request_validated_one_at_a_time", b0.reason === "not_a_rider" && bBad.reason === "invalid_bankAccountNumber" &&
    b1.kind === "requested" && b2.reason === "already_pending" && (await get("rider_accounts/r3")).bankChangePending === b1.id, JSON.stringify({ b0, bBad, b1, b2 }));
  const rj = await M.reviewBankChangeCore(db, "admin1", b1.id, false, null, THU);
  record("b02_reject_needs_a_reason", rj.reason === "reason_required", "");
  const ap = await M.reviewBankChangeCore(db, "admin1", b1.id, true, null, THU);
  const p3 = await get("delivery_partners/r3");
  const held3 = await get(`rider_payouts/${w5.id}`);
  record("b03_approve_copies_and_releases_hold", ap.kind === "approved" && ap.released === 1 && p3.bankAccountNumber === "998877665544" &&
    p3.ifscCode === "HDFC0001234" && held3.status === "pending" && held3.holdReason === null &&
    (await get("rider_accounts/r3")).bankChangePending === null, JSON.stringify({ ap, p3, held3 }));
  record("b04_second_review_refused", (await M.reviewBankChangeCore(db, "admin1", b1.id, true, null, THU)).reason === "not_pending", "");
  // A pending change holds a new statement; a rejection keeps the old details and releases it.
  const o9 = await deliveredOrder("r1", { paymentMethod: "razorpay", paymentStatus: "paid" });
  await M.recordDeliveryEarningCore(db, o9, THU, RATES);
  const b5 = await M.requestBankChangeCore(db, "r1", { upiId: "ravi@upi" }, THU);
  const NEXT_WEEK = THU + 7 * 86400000;
  const w7 = await M.buildStatementCore(db, "r1", NEXT_WEEK);
  const st7 = await get(`rider_payouts/${w7.id}`);
  const rej = await M.reviewBankChangeCore(db, "admin1", b5.id, false, "UPI name does not match", NEXT_WEEK);
  const st7b = await get(`rider_payouts/${w7.id}`);
  record("b05_pending_change_holds_reject_keeps_old", st7.holdReason === "bank_change_pending" && rej.kind === "rejected" && rej.released === 1 &&
    st7b.status === "pending" && (await get("delivery_partners/r1")).upiId === undefined &&
    (await get(`rider_bank_change_requests/${b5.id}`)).rejectionReason === "UPI name does not match", JSON.stringify({ st7, rej, st7b }));

  // ── d: dispatch ──
  const now = Date.now();
  for (const [id, north] of [["d-full", 0.002], ["d-ok", 0.004]]) {
    await db.doc(`delivery_partners/${id}`).set({ status: "approved", isOnline: true, currentLat: STORE.lat + north, currentLng: STORE.lng,
      lastLocationUpdate: Timestamp.fromMillis(now) });
  }
  await db.doc("rider_accounts/d-full").set({ riderId: "d-full", cashHeld: 2400 });
  await db.doc("rider_accounts/d-ok").set({ riderId: "d-ok", cashHeld: 300 });
  await db.doc("sellers/d-seller").set({ storeLat: STORE.lat, storeLng: STORE.lng });
  const mk = async (id, pay) => db.doc(`orders/${id}`).set({ userId: "c", sellerId: "d-seller", orderNumber: id, total: 480, paymentMethod: pay,
    orderStatus: "ready_for_pickup", status: "ready_for_pickup", deliveryAddress: { latitude: HOME.lat, longitude: HOME.lng } });
  await mk("dlv4a-cod", "cod");
  await mk("dlv4a-paid", "razorpay");
  const dc = await D.startDispatch(db, "dlv4a-cod", await get("orders/dlv4a-cod"), now);
  const dp = await D.startDispatch(db, "dlv4a-paid", await get("orders/dlv4a-paid"), now);
  const offer = await get("delivery_requests/dlv4a-paid_d-full");
  record("d01_cash_limit_blocks_cod_offers_only", !dc.offered.includes("d-full") && dc.offered.includes("d-ok") &&
    dp.offered.includes("d-full") && dp.offered.includes("d-ok"), JSON.stringify({ cod: dc.offered, paid: dp.offered }));
  record("d02_offer_carries_estimated_pay", offer.estimatedPay === P.riderPay(RATES, P.tripKm({ pickup: STORE, drop: HOME }).km, 0).total &&
    offer.estimatedPay > 25, JSON.stringify(offer.estimatedPay));
  await db.doc("settings/rider_pay").set({ codCashLimit: 5000, basePay: 40 });
  await mk("dlv4a-cod2", "cod");
  const dc2 = await D.startDispatch(db, "dlv4a-cod2", await get("orders/dlv4a-cod2"), now);
  record("d03_admin_rates_apply", dc2.offered.includes("d-full") && (await get("delivery_requests/dlv4a-cod2_d-ok")).estimatedPay > offer.estimatedPay, JSON.stringify(dc2));

  const failed = results.filter((r) => !r.pass);
  console.log(`\n${results.length - failed.length}/${results.length} passed`);
  if (failed.length) { console.log("PHASE DLV-4A money: FAILED"); process.exit(1); }
  console.log("PHASE DLV-4A money: ALL PASSED");
  process.exit(0);
}
main().catch((e) => { console.error(e); process.exit(1); });
