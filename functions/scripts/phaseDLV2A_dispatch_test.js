// Phase DLV-2A — rider dispatch: offer waves, accept/decline, retries, stops.
//
// Drives the real dispatch core (lib/delivery/dispatch.js) with an explicit
// clock, and the real callables (acceptDeliveryOffer / declineDeliveryOffer)
// through firebase-functions-test, against the Firestore emulator. Riders are
// seeded with NO FCM tokens, so no push is ever attempted.
//
// Geography: the seller's store at (9.9252, 78.1198). Eligible riders sit
// 1, 2, 3, 4, 6, 7, 10 and 22 km north of it; ineligible riders (pending,
// suspended, 'Approved' with a capital A, offline, stale location, busy) sit
// CLOSER than all of them, so any eligibility leak shows up as a wrong pick.
//
// Run with:
//   firebase emulators:exec --only firestore "node scripts/phaseDLV2A_dispatch_test.js"
// Honours FIRESTORE_EMULATOR_HOST (set by emulators:exec), falling back to 127.0.0.1:8080.
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: "agrimore-66a4e" });
const db = admin.firestore();
const { Timestamp, FieldValue } = require("firebase-admin/firestore");

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const D = require("../lib/delivery/dispatch");
const C = require("../lib/delivery/dispatchCallables");
const acceptWrapped = test.wrap(C.acceptDeliveryOffer);
const declineWrapped = test.wrap(C.declineDeliveryOffer);

const STORE = { lat: 9.9252, lng: 78.1198 };
const KM = 1 / 111.2; // degrees of latitude per km
const SELLER = "dlv2a-seller";
const SELLER_NOLOC = "dlv2a-seller-noloc";
const CUSTOMER = "dlv2a-customer";

const results = [];
function record(label, pass, detail) {
  results.push({ label, pass });
  console.log(`${pass ? "PASSED" : "FAILED"} — ${label}${pass ? "" : ` :: ${detail}`}`);
}

let T0 = Date.UTC(2026, 8, 23, 6, 0, 0); // synthetic clock for core calls
const at = (sec) => T0 + sec * 1000;

async function rider(id, kmNorth, extra = {}) {
  const fresh = extra.staleMin ? T0 - extra.staleMin * 60000 : T0;
  delete extra.staleMin;
  await db.collection("delivery_partners").doc(id).set({
    name: id, status: "approved", isOnline: true,
    currentLat: STORE.lat + kmNorth * KM, currentLng: STORE.lng,
    lastLocationUpdate: Timestamp.fromMillis(fresh),
    pincode: "625001", city: "Madurai", ...extra,
  });
  await db.collection("users").doc(id).set({ role: "delivery_partner", name: id });
}

async function order(id, extra = {}) {
  const o = {
    userId: CUSTOMER, sellerId: SELLER, orderNumber: `ORD-${id}`,
    orderStatus: "ready_for_pickup", status: "ready_for_pickup",
    paymentMethod: "cod", total: 450,
    items: [{ productId: "p1", quantity: 2 }, { productId: "p2", quantity: 1 }],
    deliveryAddress: {
      name: "Customer Name", phone: "9000000000", addressLine1: "12 Main St",
      city: "Madurai", pincode: "625002", latitude: STORE.lat - 3 * KM, longitude: STORE.lng,
    },
    deliveryVerificationCode: "123456",
    ...extra,
  };
  await db.collection("orders").doc(id).set(o);
  return o;
}

const offers = async (orderId, status) => {
  let q = db.collection("delivery_requests").where("orderId", "==", orderId);
  if (status) q = q.where("status", "==", status);
  const s = await q.get();
  return s.docs.map((d) => d.data());
};
const ridersOf = (list) => list.map((o) => o.riderId).sort().join(",");
const dispatchOf = async (id) => (await D.dispatchRef(db, id).get()).data() || null;
const orderOf = async (id) => (await db.collection("orders").doc(id).get()).data();

async function callAccept(uid, orderId) {
  try { return { ok: true, r: await acceptWrapped({ data: { orderId }, auth: { uid, token: {} } }) }; }
  catch (e) { return { ok: false, code: e.code, reason: e.details && e.details.reason }; }
}
async function callDecline(uid, orderId, reason) {
  try { return { ok: true, r: await declineWrapped({ data: { orderId, reason }, auth: { uid, token: {} } }) }; }
  catch (e) { return { ok: false, code: e.code, reason: e.details && e.details.reason }; }
}

async function main() {
  console.log("=== PHASE DLV-2A — dispatch ===");
  await db.collection("sellers").doc(SELLER).set({ storeLat: STORE.lat, storeLng: STORE.lng, city: "Madurai", pincode: "625001" });
  await db.collection("sellers").doc(SELLER_NOLOC).set({ city: "Madurai", pincode: "625001" });

  // Eligible, by distance from the store.
  for (const [id, km] of [["r1", 1], ["r2", 2], ["r3", 3], ["r4", 4], ["r5", 6], ["r6", 7], ["r7", 10], ["r8", 22]]) {
    await rider(id, km, id === "r8" ? { pincode: "999999", city: "Elsewhere" } : {});
  }
  // Ineligible, all closer than r1.
  await rider("x_pending", 0.2, { status: "pending" });
  await rider("x_suspended", 0.2, { status: "suspended" });
  await rider("x_capital", 0.2, { status: "Approved" });
  await rider("x_offline", 0.2, { isOnline: false });
  await rider("x_stale", 0.2, { staleMin: 40 });
  await rider("x_busy", 0.2);
  await order("busy-order", { orderStatus: "picked_up", status: "picked_up", deliveryPartnerId: "x_busy" });

  // ── The waves of one order, driven by the scheduler ─────────────────────
  const A = "dlv2a-A";
  const oA = await order(A);
  const s1 = await D.startDispatch(db, A, oA, at(0));
  let open = await offers(A, "offered");
  record("d01_wave1_offers_the_3_nearest_eligible_riders",
    s1.started && s1.wave === 1 && ridersOf(open) === "r1,r2,r3",
    `started=${s1.started} wave=${s1.wave} offered=${ridersOf(open)}`);

  const sample = open.find((o) => o.riderId === "r1");
  const piiKeys = Object.keys(sample).filter((k) => /name|phone|address|verification/i.test(k));
  record("d02_offer_is_redacted_and_carries_what_a_rider_needs",
    piiKeys.length === 0 && Math.abs(sample.pickupDistanceKm - 1) < 0.05 && sample.dropPincode === "625002" &&
    sample.itemCount === 3 && sample.codAmount === 450 && sample.pickupArea === "Madurai · 625001" &&
    sample.expiresAt.toMillis() === at(30) && sample.status === "offered" && sample.partnerId === "r1",
    `pii=${piiKeys} sample=${JSON.stringify({ ...sample, expiresAt: sample.expiresAt.toMillis(), createdAt: undefined, updatedAt: undefined })}`);

  let d = await dispatchOf(A);
  record("d03_dispatch_state_after_wave1",
    d.status === "dispatching" && d.wave === 1 && d.radiusKm === 5 && d.needsAdmin === false &&
    d.nextActionAt.toMillis() === at(30),
    JSON.stringify({ status: d.status, wave: d.wave, r: d.radiusKm, needsAdmin: d.needsAdmin, next: d.nextActionAt.toMillis() - T0 }));

  let tick = await D.runDispatchTick(db, at(10));
  record("d04_tick_before_expiry_changes_nothing",
    tick.expired === 0 && tick.advanced === 0 && (await offers(A, "offered")).length === 3,
    JSON.stringify(tick));

  tick = await D.runDispatchTick(db, at(31));
  open = await offers(A, "offered");
  d = await dispatchOf(A);
  record("d05_after_expiry_wave2_goes_to_new_riders_within_8km",
    tick.expired === 3 && (await offers(A, "expired")).length === 3 &&
    d.wave === 2 && d.radiusKm === 8 && ridersOf(open) === "r4,r5,r6",
    `tick=${JSON.stringify(tick)} wave=${d.wave} offered=${ridersOf(open)}`);

  await D.runDispatchTick(db, at(62));
  open = await offers(A, "offered");
  d = await dispatchOf(A);
  record("d06_wave3_reaches_12km_but_not_22km",
    d.wave === 3 && d.radiusKm === 12 && ridersOf(open) === "r7" && d.needsAdmin === false,
    `wave=${d.wave} offered=${ridersOf(open)} needsAdmin=${d.needsAdmin}`);

  await D.runDispatchTick(db, at(93));
  open = await offers(A, "offered");
  d = await dispatchOf(A);
  record("d07_no_taker_flags_admin_and_retries_the_nearest_again",
    d.wave === 4 && d.needsAdmin === true && d.needsAdminSince.toMillis() === at(93) &&
    ridersOf(open) === "r1,r2,r3" && d.nextActionAt.toMillis() === at(93 + 120),
    `wave=${d.wave} needsAdmin=${d.needsAdmin} offered=${ridersOf(open)} next=${(d.nextActionAt.toMillis() - T0) / 1000}s`);

  tick = await D.runDispatchTick(db, at(130));
  d = await dispatchOf(A);
  record("d08_retry_waits_2_minutes_not_30_seconds", d.wave === 4 && tick.expired === 3,
    `wave=${d.wave} tick=${JSON.stringify(tick)}`);

  await D.runDispatchTick(db, at(214));
  d = await dispatchOf(A);
  open = await offers(A, "offered");
  record("d09_retry_repeats_every_2_minutes_and_stays_flagged",
    d.wave === 5 && d.needsAdmin === true && open.length === 3,
    `wave=${d.wave} needsAdmin=${d.needsAdmin} open=${open.length}`);

  // r1 accepts during the retry.
  const acc = await C.acceptOfferCore(db, "r1", A, at(220));
  const ordA = await orderOf(A);
  d = await dispatchOf(A);
  const withdrawn = await offers(A, "withdrawn");
  record("d10_accept_assigns_order_withdraws_others_and_clears_the_flag",
    acc.kind === "accepted" && ordA.deliveryPartnerId === "r1" && ordA.orderStatus === "delivery_accepted" &&
    ordA.status === "delivery_accepted" && ordA.deliveryAcceptedVia === "acceptDeliveryOffer" &&
    d.status === "assigned" && d.assignedTo === "r1" && d.needsAdmin === false &&
    ridersOf(withdrawn) === "r2,r3" && (await offers(A, "accepted")).length === 1,
    `acc=${JSON.stringify(acc)} order=${ordA.deliveryPartnerId}/${ordA.orderStatus} dispatch=${d.status}/${d.needsAdmin} withdrawn=${ridersOf(withdrawn)}`);

  const again = await C.acceptOfferCore(db, "r1", A, at(221));
  record("d11_repeat_accept_is_idempotent", again.kind === "accepted" && again.alreadyAccepted === true,
    JSON.stringify(again));

  // ── Accept races and refusals ───────────────────────────────────────────
  const B = "dlv2a-B"; // r1 is now busy with A
  const oB = await order(B);
  await D.startDispatch(db, B, oB, at(300));
  const offeredB = ridersOf(await offers(B, "offered"));
  record("d12_busy_rider_is_not_offered", offeredB === "r2,r3,r4", `offered=${offeredB}`);
  const [ra, rb] = await Promise.all([
    C.acceptOfferCore(db, "r2", B, at(305)),
    C.acceptOfferCore(db, "r3", B, at(305)),
  ]);
  const wins = [ra, rb].filter((v) => v.kind === "accepted").length;
  const loser = [ra, rb].find((v) => v.kind === "refused");
  const ordB = await orderOf(B);
  record("d13_two_riders_accept_at_once_exactly_one_wins",
    wins === 1 && loser && loser.reason === "taken" && ["r2", "r3"].includes(ordB.deliveryPartnerId),
    `ra=${JSON.stringify(ra)} rb=${JSON.stringify(rb)} partner=${ordB.deliveryPartnerId}`);

  const Cid = "dlv2a-C";
  const oC = await order(Cid);
  await D.startDispatch(db, Cid, oC, at(400));
  const late = await C.acceptOfferCore(db, "r4", Cid, at(431));
  const r4offer = (await D.offerRef(db, Cid, "r4").get()).data();
  record("d14_expired_offer_is_refused_and_recorded",
    late.kind === "refused" && late.reason === "expired" && r4offer.status === "expired" &&
    !(await orderOf(Cid)).deliveryPartnerId,
    `late=${JSON.stringify(late)} offer=${r4offer.status}`);

  const notMine = await C.acceptOfferCore(db, "r7", Cid, at(401));
  record("d15_rider_without_an_offer_is_refused", notMine.kind === "refused" && notMine.reason === "no_offer",
    JSON.stringify(notMine));

  // An offer to a rider who is already carrying an order.
  await D.offerRef(db, Cid, "r1").set({
    orderId: Cid, riderId: "r1", partnerId: "r1", status: "offered", expiresAt: Timestamp.fromMillis(at(1000)),
  });
  const busy = await C.acceptOfferCore(db, "r1", Cid, at(402));
  record("d16_busy_rider_cannot_accept_a_second_order", busy.kind === "refused" && busy.reason === "busy",
    JSON.stringify(busy));

  // ── Decline ─────────────────────────────────────────────────────────────
  // By now r1 (A) and B's winner are busy; the wave-1 riders for E are the
  // free ones within 5 km, whoever they are.
  const E = "dlv2a-E";
  const oE = await order(E);
  await D.startDispatch(db, E, oE, at(500));
  const firstWaveList = (await offers(E, "offered")).map((o) => o.riderId).sort();
  const expectedFirst = ["r2", "r3", "r4"].filter((r) => r !== ordB.deliveryPartnerId).sort();
  const decliners = firstWaveList;
  const reasons = ["vehicle_issue", "bogus_reason", null];
  const decs = [];
  const wavesSeen = [];
  for (let i = 0; i < decliners.length; i++) {
    decs.push(await C.declineOfferCore(db, decliners[i], E, reasons[i] ?? null, at(501 + i)));
    wavesSeen.push((await dispatchOf(E)).wave);
  }
  let dE = await dispatchOf(E);
  const ordE = await orderOf(E);
  const nextWave = (await offers(E, "offered")).map((o) => o.riderId);
  record("d17_decline_advances_the_wave_only_when_everyone_has_answered",
    firstWaveList.join(",") === expectedFirst.join(",") &&
    decs.slice(0, -1).every((x) => x.declined && !x.advanced) && decs[decs.length - 1].advanced &&
    wavesSeen.slice(0, -1).every((w) => w === 1) && dE.wave >= 2 &&
    !nextWave.some((r) => decliners.includes(r)),
    `first=${firstWaveList} expected=${expectedFirst} decs=${JSON.stringify(decs)} waves=${wavesSeen} next=${nextWave}`);
  const d0 = (await D.offerRef(db, E, decliners[0]).get()).data();
  const d1 = (await D.offerRef(db, E, decliners[1]).get()).data();
  record("d18_decline_records_the_rider_on_order_and_dispatch_and_filters_reasons",
    decliners.every((r) => ordE.deliveryRejectedBy.includes(r) && dE.declinedBy.includes(r)) &&
    d0.status === "declined" && d0.declineReason === "vehicle_issue" && d1.declineReason === null,
    `rejectedBy=${ordE.deliveryRejectedBy} declinedBy=${dE.declinedBy} reasons=${d0.declineReason}/${d1.declineReason}`);

  // ── Every other way an order gets a rider stops the dispatch ────────────
  const F = "dlv2a-F";
  const oF = await order(F);
  await D.startDispatch(db, F, oF, at(600));
  // The released May-6 app claims directly (firestore.rules deliveryPartnerCanClaimOrder).
  await db.collection("orders").doc(F).update({ deliveryPartnerId: "r7", orderStatus: "delivery_accepted", status: "delivery_accepted" });
  await D.runDispatchTick(db, at(631));
  const dF = await dispatchOf(F);
  record("d19_legacy_client_claim_stops_dispatch",
    dF.status === "assigned" && dF.assignedTo === "r7" && dF.stopReason === "assigned_elsewhere" &&
    (await offers(F, "offered")).length === 0,
    JSON.stringify({ status: dF.status, to: dF.assignedTo, why: dF.stopReason }));

  const G = "dlv2a-G";
  const oG = await order(G);
  await D.startDispatch(db, G, oG, at(700));
  // order_assignment_screen.dart: sets deliveryPartnerId, leaves ready_for_pickup.
  await db.collection("orders").doc(G).update({ deliveryPartnerId: "r8" });
  await D.runDispatchTick(db, at(731));
  const dG = await dispatchOf(G);
  record("d20_admin_assignment_stops_dispatch", dG.status === "assigned" && dG.assignedTo === "r8",
    JSON.stringify({ status: dG.status, to: dG.assignedTo }));

  const H = "dlv2a-H";
  const oH = await order(H);
  await D.startDispatch(db, H, oH, at(800));
  await db.collection("orders").doc(H).update({ status: "cancelled" }); // seller panel writes only `status`
  await D.runDispatchTick(db, at(831));
  const dH = await dispatchOf(H);
  record("d21_cancellation_even_status_only_stops_dispatch_and_withdraws_offers",
    dH.status === "stopped" && dH.stopReason === "order_not_ready" &&
    (await offers(H, "offered")).length === 0,
    JSON.stringify({ status: dH.status, why: dH.stopReason }));

  // ── Pickup point is never the customer's address ─────────────────────────
  const P = "dlv2a-P";
  // Seller has no location; the CUSTOMER address is right on top of r8.
  const oP = await order(P, {
    sellerId: SELLER_NOLOC,
    deliveryAddress: { name: "C", phone: "9", city: "Madurai", pincode: "625001", latitude: STORE.lat + 22 * KM, longitude: STORE.lng },
  });
  await D.startDispatch(db, P, oP, at(900));
  const offP = await offers(P, "offered");
  record("d22_no_pickup_point_falls_back_to_area_match_never_the_customer_address",
    offP.length > 0 && !offP.some((o) => o.riderId === "r8") && offP.every((o) => o.pickupDistanceKm === null),
    `offered=${ridersOf(offP)}`);

  // ── Nobody at all ───────────────────────────────────────────────────────
  const N = "dlv2a-N";
  const oN = await order(N, { sellerId: "dlv2a-seller-far" });
  await db.collection("sellers").doc("dlv2a-seller-far").set({ storeLat: 28.61, storeLng: 77.2 }); // Delhi
  const sN = await D.startDispatch(db, N, oN, at(1000));
  const dN = await dispatchOf(N);
  record("d23_no_rider_anywhere_flags_admin_at_once_and_schedules_a_retry",
    sN.started && dN.wave === 3 && dN.needsAdmin === true && dN.nextActionAt.toMillis() === at(1000 + 120) &&
    (await offers(N)).length === 0,
    JSON.stringify({ wave: dN.wave, needsAdmin: dN.needsAdmin, next: (dN.nextActionAt.toMillis() - T0) / 1000 }));

  // ── Single-flight and restart ───────────────────────────────────────────
  const S = "dlv2a-S";
  await order(S);
  await D.dispatchRef(db, S).set({
    orderId: S, status: "dispatching", wave: 0, offeredTo: [], declinedBy: [], needsAdmin: false,
    leaseUntil: Timestamp.fromMillis(0), nextActionAt: Timestamp.fromMillis(at(1100)),
  });
  // Two callers who both saw wave 0 (e.g. the last two riders of a wave
  // declining at once) must advance ONE wave between them.
  const [w1, w2] = await Promise.all([
    D.runNextWave(db, S, at(1100), { force: true, expectWave: 0 }),
    D.runNextWave(db, S, at(1100), { force: true, expectWave: 0 }),
  ]);
  const dS = await dispatchOf(S);
  record("d24_concurrent_wave_calls_run_one_wave",
    [w1.wave, w2.wave].filter((w) => w !== null).length === 1 && dS.wave === 1,
    `w1=${w1.wave} w2=${w2.wave} wave=${dS.wave}`);

  // E's decliners stay excluded after a release + restart.
  await db.collection("orders").doc(E).update({ deliveryPartnerId: "r7", orderStatus: "delivery_accepted", status: "delivery_accepted" });
  await D.closeDispatch(db, E, "r7", at(1200), "accepted");
  await db.collection("orders").doc(E).update({ deliveryPartnerId: FieldValue.delete(), orderStatus: "ready_for_pickup", status: "ready_for_pickup" });
  const restart = await D.startDispatch(db, E, await orderOf(E), at(1201));
  const dE2 = await dispatchOf(E);
  const reoffered = (await offers(E, "offered")).map((o) => o.riderId);
  record("d25_release_restarts_dispatch_keeping_declined_riders_out",
    restart.started && dE2.status === "dispatching" && dE2.wave >= 1 &&
    decliners.every((r) => dE2.declinedBy.includes(r)) && !reoffered.some((r) => decliners.includes(r)),
    `restart=${restart.started} wave=${dE2.wave} declined=${dE2.declinedBy} offered=${reoffered}`);

  // ── The callables themselves (real clock) ───────────────────────────────
  T0 = Date.now();
  // Free every rider: finish the orders that made them busy.
  for (const id of [A, B, F, E, "busy-order"]) {
    await db.collection("orders").doc(id).update({ orderStatus: "delivered", status: "delivered" });
  }
  const Q = "dlv2a-Q";
  const oQ = await order(Q);
  // Riders' location freshness is judged against the core's clock — refresh.
  for (const r of ["r1", "r2", "r3", "r4", "r5", "r6", "r7"]) {
    await db.collection("delivery_partners").doc(r).update({ lastLocationUpdate: Timestamp.fromMillis(Date.now()) });
  }
  await D.startDispatch(db, Q, oQ, Date.now());
  const qOffered = (await offers(Q, "offered")).map((o) => o.riderId);
  const outsider = ["r1", "r2", "r3", "r4", "r5", "r6", "r7"].find((r) => !qOffered.includes(r)) || "nobody";
  const noOffer = await callAccept(outsider, Q);
  const unauth = await acceptWrapped({ data: { orderId: Q } }).then(() => ({ ok: true })).catch((e) => ({ ok: false, code: e.code }));
  const decl = await callDecline(qOffered[0], Q, "safety");
  const win = await callAccept(qOffered[1], Q);
  const lose = await callAccept(qOffered[2], Q);
  const declAgain = await callDecline(qOffered[0], Q, "safety");
  record("d26_callables_map_refusals_to_failed_precondition_with_a_reason",
    qOffered.length === 3 && !noOffer.ok && noOffer.code === "failed-precondition" && noOffer.reason === "no_offer" &&
    !unauth.ok && unauth.code === "unauthenticated" &&
    decl.ok && win.ok && win.r.success === true &&
    !lose.ok && lose.code === "failed-precondition" && lose.reason === "taken" &&
    declAgain.ok && declAgain.r.alreadyClosed === true,
    JSON.stringify({ offered: qOffered, noOffer, unauth, decl, win, lose, declAgain }));

  const failed = results.filter((r) => !r.pass);
  console.log(`\n${results.length - failed.length}/${results.length} passed`);
  test.cleanup();
  if (failed.length) { console.log("PHASE DLV-2A dispatch: FAILED"); process.exit(1); }
  console.log("PHASE DLV-2A dispatch: ALL PASSED");
  process.exit(0);
}

main().catch((e) => { console.error("PHASE DLV-2A dispatch: harness error", e); process.exit(1); });
