// Phase DLV-M1 — rider money integrity (functions/src/delivery/riderMoney.ts)
// on the Firestore emulator.
//  m1 many COD deliveries with awkward amounts → balances exact to the paisa
//  m2 an account written before M1 (float rupees only) is converted exactly
//  m3 deposits: request id replay returns the first result; the same id with a
//     different amount is refused; 0.001 is refused; two concurrent deposits
//     cannot take more than is held
//  m4 905 eligible lines → 3 statement parts in one run, every line settled,
//     amounts add up; a second run creates nothing
//  m5 a bank change requested after a statement became pending holds it
//  m6 markPayoutPaid refuses while a change is pending; after approval pays
//     and records the destination; a replay is "already"
// Run with: firebase emulators:exec --only firestore "node scripts/phaseDLVM1_money_test.js"
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
const PROJECT = process.env.GCLOUD_PROJECT || "demo-dlvm1-money";
if (!PROJECT.startsWith("demo-")) { console.error("REFUSING: not a demo- project"); process.exit(2); }
const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: PROJECT });
const db = admin.firestore();
const { Timestamp } = require("firebase-admin/firestore");
const M = require("../lib/delivery/riderMoney");
const { statementCutoff } = require("../lib/delivery/riderPay");

const results = [];
const record = (label, pass, detail) => { results.push(pass); console.log(`${pass ? "PASSED" : "FAILED"} — ${label}${pass ? "" : ` :: ${detail}`}`); };
const get = async (p) => (await db.doc(p).get()).data();
const NOW = Date.UTC(2026, 8, 28, 1, 0, 0); // Monday 06:30 IST
const { cutoffMs, weekKey } = statementCutoff(NOW);
const STORE = { lat: 9.9252, lng: 78.1198 };

async function deliveredOrder(id, rider, total) {
  await db.doc(`orders/${id}`).set({ deliveryPartnerId: rider, orderStatus: "delivered", status: "delivered", paymentMethod: "cod",
    paymentStatus: "pending", total, pickupLat: STORE.lat, pickupLng: STORE.lng, deliveryAddress: { latitude: 9.93, longitude: 78.12 } });
}

async function main() {
  console.log("=== PHASE DLV-M1 — money ===");
  // m1
  const amounts = [101.1, 202.2, 127.37, 0.1, 0.2, 19.99, 430.7, 55.55, 0.01, 999.99];
  let expectCashP = 0, expectEarnP = 0;
  for (let i = 0; i < amounts.length; i++) {
    await deliveredOrder(`m1-${i}`, "rA", amounts[i]);
    const v = await M.recordDeliveryEarningCore(db, `m1-${i}`, NOW - 86400000 * 2);
    expectCashP += Math.round(amounts[i] * 100);
    expectEarnP += (await get(`rider_earnings/m1-${i}`)).totalPaise;
    if (v.kind !== "created") { record("m1_setup", false, JSON.stringify(v)); }
  }
  let acc = await get("rider_accounts/rA");
  record("m1_balances_exact_to_the_paisa", acc.cashHeldPaise === expectCashP && acc.cashHeld === expectCashP / 100 &&
    acc.earningsUnsettledPaise === expectEarnP && Number.isInteger(acc.cashHeldPaise) &&
    String(acc.cashHeld).split(".")[1]?.length <= 2, JSON.stringify(acc));

  // m2
  await db.doc("rider_accounts/rLegacy").set({ riderId: "rLegacy", cashHeld: 430.70000000000005, earningsUnsettled: 60.300000000000004 });
  await deliveredOrder("m2-1", "rLegacy", 0.1);
  await M.recordDeliveryEarningCore(db, "m2-1", NOW - 86400000);
  acc = await get("rider_accounts/rLegacy");
  record("m2_legacy_float_account_converted_exactly", acc.cashHeldPaise === 43080 && acc.cashHeld === 430.8, JSON.stringify(acc));

  // m3
  await db.doc("rider_accounts/rD").set({ riderId: "rD", cashHeldPaise: 10000, cashHeld: 100, earningsUnsettledPaise: 0, earningsUnsettled: 0 });
  let d = await M.recordCashDepositCore(db, "adm", "rD", 40, "RCPT-1", NOW, "dep-req-0001");
  const replay = await M.recordCashDepositCore(db, "adm", "rD", 40, "RCPT-1", NOW + 1000, "dep-req-0001");
  const reused = await M.recordCashDepositCore(db, "adm", "rD", 45, "RCPT-1", NOW + 2000, "dep-req-0001");
  const tiny = await M.recordCashDepositCore(db, "adm", "rD", 0.001, "RCPT-2", NOW, "dep-req-0002");
  acc = await get("rider_accounts/rD");
  record("m3a_replay_returns_first_result_once", d.kind === "recorded" && replay.already === true && acc.cashHeldPaise === 6000 &&
    reused.reason === "request_reused" && tiny.reason === "bad_amount", JSON.stringify({ d, replay, reused, tiny, acc }));
  const [c1, c2] = await Promise.all([
    M.recordCashDepositCore(db, "adm", "rD", 40, "RCPT-3", NOW, "dep-req-0003"),
    M.recordCashDepositCore(db, "adm", "rD", 40, "RCPT-4", NOW, "dep-req-0004"),
  ]);
  acc = await get("rider_accounts/rD");
  record("m3b_concurrent_deposits_cannot_overdraw", [c1, c2].filter((x) => x.kind === "recorded").length === 1 &&
    [c1, c2].some((x) => x.reason === "more_than_held") && acc.cashHeldPaise === 2000, JSON.stringify({ c1, c2, acc }));

  // m4 — 905 lines before the cutoff
  await db.doc("delivery_partners/rS").set({ status: "approved", bankAccountNumber: "123456789012", ifscCode: "SBIN0001234", accountHolderName: "S" });
  await db.doc("rider_accounts/rS").set({ riderId: "rS", cashHeldPaise: 0, cashHeld: 0, earningsUnsettledPaise: 905 * 3137, earningsUnsettled: 905 * 31.37 });
  for (let b = 0; b < 905; b += 400) {
    const batch = db.batch();
    for (let i = b; i < Math.min(b + 400, 905); i++) {
      batch.set(db.doc(`rider_earnings/m4-${String(i).padStart(4, "0")}`), { riderId: "rS", total: 31.37, totalPaise: 3137,
        statementId: null, createdAt: Timestamp.fromMillis(cutoffMs - 86400000 + i * 1000) });
    }
    await batch.commit();
  }
  const parts = await M.buildRiderStatementParts(db, "rS", NOW);
  const left = (await db.collection("rider_earnings").where("riderId", "==", "rS").where("statementId", "==", null).get()).size;
  const p1 = await get(`rider_payouts/rS_${weekKey}`), p2 = await get(`rider_payouts/rS_${weekKey}_p2`), p3 = await get(`rider_payouts/rS_${weekKey}_p3`);
  acc = await get("rider_accounts/rS");
  record("m4a_all_905_lines_settled_in_3_parts", parts.filter((p) => p.kind === "created").length === 3 && left === 0 &&
    p1.orderCount === 400 && p2.orderCount === 400 && p3.orderCount === 105 &&
    p1.amountPaise + p2.amountPaise + p3.amountPaise === 905 * 3137 && acc.earningsUnsettledPaise === 0, JSON.stringify({ parts, left, acc }));
  const rerun = await M.buildRiderStatementParts(db, "rS", NOW + 60000);
  record("m4b_second_run_creates_nothing", rerun.every((p) => p.kind !== "created"), JSON.stringify(rerun));

  // m5
  record("m5_pre_statement_pending", p1.status === "pending", p1.status);
  const req = await M.requestBankChangeCore(db, "rS", { accountHolderName: "S New", bankAccountNumber: "999988887777", ifscCode: "HDFC0001234" }, NOW + 1000);
  const held = await get(`rider_payouts/rS_${weekKey}`);
  record("m5_bank_change_holds_pending_statements", req.kind === "requested" && held.status === "on_hold" && held.holdReason === "bank_change_pending",
    JSON.stringify({ req, held }));

  // m6
  await db.doc(`rider_payouts/rS_${weekKey}_p2`).update({ status: "pending", holdReason: null }); // simulate an earlier-released statement
  let paid = await M.markPayoutPaidCore(db, "adm", `rS_${weekKey}_p2`, "UTR123456", "bank", NOW + 2000);
  record("m6a_paid_refused_while_change_pending", paid.reason === "bank_change_pending", JSON.stringify(paid));
  await M.reviewBankChangeCore(db, "adm", req.id, true, null, NOW + 3000);
  paid = await M.markPayoutPaidCore(db, "adm", `rS_${weekKey}`, "UTR777777", "bank", NOW + 4000);
  const again = await M.markPayoutPaidCore(db, "adm", `rS_${weekKey}`, "UTR777777", "bank", NOW + 5000);
  const other = await M.markPayoutPaidCore(db, "adm", `rS_${weekKey}`, "UTR888888", "bank", NOW + 5000);
  const pp = await get(`rider_payouts/rS_${weekKey}`);
  record("m6b_paid_binds_reviewed_destination_once", paid.kind === "paid" && pp.paidTo.accountLast4 === "7777" &&
    pp.paidTo.ifscCode === "HDFC0001234" && again.kind === "already" && other.reason === "payout_not_pending" &&
    !JSON.stringify(pp.paidTo).includes("999988887777"), JSON.stringify({ pp, again, other }));

  const failed = results.filter((x) => !x).length;
  console.log(`\n${results.length - failed}/${results.length} passed`);
  if (failed) { console.log("PHASE DLV-M1: FAILED"); process.exit(1); }
  console.log("PHASE DLV-M1: ALL PASSED"); process.exit(0);
}
main().catch((e) => { console.error(e); process.exit(1); });
