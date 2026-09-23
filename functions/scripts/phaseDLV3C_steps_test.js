// Phase DLV-3C — server-checked rider steps (advanceDeliveryStep,
// releaseDeliveryOrder) and the location flags (D-DLV-GEOFENCE).
//
// Pure: parseFix, locationCheck (300 m, mocked, no fix, unknown place).
// Core (Firestore emulator): each step moves only where delivery/states.ts
// allows it; the store distance is recorded and > 300 m / mocked / no fix is
// FLAGGED but never refused; a retry is idempotent; only the assigned rider
// may act; release works before pickup only, puts the order back to
// ready_for_pickup and keeps the rider out of the next dispatch; confirmDelivery's
// drop flag (via dropCheck) stays silent for a released app.
//
// Run with:
//   firebase emulators:exec --only firestore "node scripts/phaseDLV3C_steps_test.js"
// Requires: npm run build. Honours FIRESTORE_EMULATOR_HOST.
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: "demo-dlv3c-steps" });
const db = admin.firestore();
const S = require("../lib/delivery/riderSteps");

const results = [];
function record(label, pass, detail) {
  results.push({ label, pass });
  console.log(`${pass ? "PASSED" : "FAILED"} — ${label}${pass ? "" : ` :: ${detail}`}`);
}
const T0 = Date.UTC(2026, 8, 23, 12, 0, 0);
const STORE = { lat: 9.9252, lng: 78.1198 };
const HOME = { lat: 9.8982, lng: 78.1198 };
const M = 1 / 111320; // degrees of latitude per metre
const RIDER = "r-dlv3c", OTHER = "r-other";
const at = (p, metresNorth, extra = {}) => ({ lat: p.lat + metresNorth * M, lng: p.lng, accuracy: 8, isMocked: false, ...extra });

let n = 0;
async function order(status, extra = {}, task = true) {
  const id = `dlv3c-s${++n}`;
  await db.doc(`orders/${id}`).set({
    userId: "c", sellerId: "s", total: 480, paymentMethod: "cod", orderStatus: status, status,
    deliveryPartnerId: RIDER, deliveryAddress: { latitude: HOME.lat, longitude: HOME.lng, pincode: "625002" }, ...extra,
  });
  if (task) await db.doc(`delivery_tasks/${id}`).set({ orderId: id, pickup: STORE, drop: HOME });
  return id;
}
const get = async (id) => (await db.doc(`orders/${id}`).get()).data();
const timeline = async (id) => (await db.collection(`orders/${id}/timeline`).get()).docs.map((d) => d.data());

async function main() {
  console.log("=== PHASE DLV-3C — rider steps ===");
  // ── pure ──
  record("p01_parseFix", S.parseFix({ lat: 9.9, lng: 78.1, accuracy: 5 })?.isMocked === false &&
    S.parseFix({ lat: 91, lng: 0 }) === null && S.parseFix({ lat: "9", lng: 78 }) === null && S.parseFix({}) === null &&
    S.parseFix({ lat: 9.9, lng: 78.1, isMocked: true }).isMocked === true && S.parseFix({ lat: 1, lng: 1, accuracy: -3 }).accuracy === null, "");
  const near = S.locationCheck(at(STORE, 120), STORE, "store");
  const far = S.locationCheck(at(STORE, 1200), STORE, "store");
  record("p02_300m_rule", near.reasons.length === 0 && Math.abs(near.distanceMeters - 120) <= 1 &&
    far.reasons.join() === "far_from_store" && Math.abs(far.distanceMeters - 1200) <= 2, JSON.stringify({ near, far }));
  record("p03_mocked_and_no_fix", S.locationCheck(at(STORE, 10, { isMocked: true }), STORE, "store").reasons.join() === "mocked_location" &&
    S.locationCheck(null, STORE, "store").reasons.join() === "no_location" &&
    S.locationCheck(null, STORE, "store", false).reasons.length === 0, "");
  const nowhere = S.locationCheck(at(STORE, 5000), null, "store");
  record("p04_unknown_place_is_not_the_riders_fault", nowhere.distanceMeters === null && nowhere.reasons.length === 0, JSON.stringify(nowhere));
  record("p05_drop_check_silent_for_released_app", S.dropCheck({}, { orderId: "x", code: "123456" }) === null &&
    S.dropCheck({ deliveryAddress: { latitude: HOME.lat, longitude: HOME.lng } }, { locationStatus: "unavailable" }).check.reasons.join() === "no_location" &&
    S.dropCheck({ deliveryAddress: { latitude: HOME.lat, longitude: HOME.lng } }, at(HOME, 800)).check.reasons.join() === "far_from_customer", "");

  // ── steps ──
  const o1 = await order("delivery_accepted");
  const v1 = await S.advanceStepCore(db, RIDER, o1, "arrived_at_store", at(STORE, 40), T0);
  let d = await get(o1);
  record("s01_arrived_near_the_store_no_flag", v1.kind === "advanced" && v1.from === "assigned" && d.orderStatus === "arrived_at_store" &&
    d.status === "arrived_at_store" && d.arrivedAtStoreAt && d.deliveryStepChecks.arrived_at_store.distanceMeters === 40 &&
    d.deliveryFlagged === undefined && d.deliveryFlags === undefined, JSON.stringify({ v1, d }));
  const v2 = await S.advanceStepCore(db, RIDER, o1, "picked_up", at(STORE, 1500), T0 + 60000);
  d = await get(o1);
  record("s02_far_pickup_allowed_and_flagged", v2.kind === "advanced" && d.orderStatus === "picked_up" && d.deliveryFlagged === true &&
    d.deliveryFlags.length === 1 && d.deliveryFlags[0].step === "picked_up" && d.deliveryFlags[0].reasons.join() === "far_from_store" &&
    Math.abs(d.deliveryFlags[0].distanceMeters - 1500) <= 2, JSON.stringify(d.deliveryFlags));
  const tl = await timeline(o1);
  record("s03_timeline_written_server_side_with_the_flag", tl.length === 2 && tl.some((t) => t.status === "picked_up" && t.flags?.join() === "far_from_store" && t.partnerId === RIDER), JSON.stringify(tl));
  const v3 = await S.advanceStepCore(db, RIDER, o1, "out_for_delivery", at(STORE, 2500), T0 + 120000);
  d = await get(o1);
  record("s04_out_for_delivery_distance_recorded_not_flagged", v3.kind === "advanced" && d.orderStatus === "out_for_delivery" &&
    d.deliveryFlags.length === 1 && d.deliveryStepChecks.out_for_delivery.distanceMeters > 2400, JSON.stringify(d.deliveryStepChecks));
  const again = await S.advanceStepCore(db, RIDER, o1, "out_for_delivery", at(STORE, 2500), T0 + 130000);
  record("s05_retry_is_idempotent", again.kind === "already" && (await timeline(o1)).length === 3, JSON.stringify(again));

  const o2 = await order("delivery_accepted");
  const jump = await S.advanceStepCore(db, RIDER, o2, "out_for_delivery", at(STORE, 10), T0);
  record("s06_accepted_to_out_for_delivery_refused", jump.kind === "refused" && jump.reason === "bad_transition" &&
    (await get(o2)).orderStatus === "delivery_accepted" && (await timeline(o2)).length === 0, JSON.stringify(jump));
  const o3 = await order("out_for_delivery");
  const back = await S.advanceStepCore(db, RIDER, o3, "arrived_at_store", at(STORE, 10), T0);
  record("s07_backwards_refused", back.kind === "refused" && back.reason === "bad_transition", JSON.stringify(back));
  const o4 = await order("cancelled");
  const dead = await S.advanceStepCore(db, RIDER, o4, "picked_up", at(STORE, 10), T0);
  record("s08_finished_order_refused", dead.kind === "refused" && dead.reason === "bad_transition", JSON.stringify(dead));
  const o5 = await order("delivery_accepted");
  const other = await S.advanceStepCore(db, OTHER, o5, "arrived_at_store", at(STORE, 10), T0);
  record("s09_not_the_assigned_rider", other.kind === "refused" && other.reason === "not_assigned" && (await get(o5)).orderStatus === "delivery_accepted", JSON.stringify(other));
  const missing = await S.advanceStepCore(db, RIDER, "no-such-order", "arrived_at_store", null, T0);
  record("s10_missing_order", missing.kind === "refused" && missing.reason === "not_found", "");
  const o6 = await order("delivery_accepted");
  await S.advanceStepCore(db, RIDER, o6, "arrived_at_store", at(STORE, 10, { isMocked: true }), T0);
  d = await get(o6);
  record("s11_mocked_location_flagged", d.deliveryFlags[0].reasons.join() === "mocked_location" && d.orderStatus === "arrived_at_store", JSON.stringify(d.deliveryFlags));
  const o7 = await order("delivery_accepted");
  await S.advanceStepCore(db, RIDER, o7, "arrived_at_store", null, T0);
  d = await get(o7);
  record("s12_no_location_flagged_not_blocked", d.orderStatus === "arrived_at_store" && d.deliveryFlags[0].reasons.join() === "no_location", JSON.stringify(d.deliveryFlags));
  // Admin-assigned order (still ready_for_pickup with a rider) and no task yet:
  // the store comes from the seller doc.
  await db.doc("sellers/s-geo").set({ storeLat: STORE.lat, storeLng: STORE.lng });
  const o8 = await order("ready_for_pickup", { sellerId: "s-geo" }, false);
  const v8 = await S.advanceStepCore(db, RIDER, o8, "arrived_at_store", at(STORE, 50), T0);
  record("s13_admin_assigned_order_without_task_uses_seller_store", v8.kind === "advanced" && v8.from === "assigned" && Math.abs(v8.distanceMeters - 50) <= 1, JSON.stringify(v8));

  // ── release ──
  const r1 = await order("arrived_at_store", { deliveryPartner: { id: RIDER, name: "Ravi" } });
  const rel = await S.releaseOrderCore(db, RIDER, r1, "seller_not_ready", T0);
  d = await get(r1);
  const disp = (await db.doc(`delivery_dispatch/${r1}`).get()).data();
  record("r01_release_before_pickup", rel.kind === "released" && d.orderStatus === "ready_for_pickup" && d.status === "ready_for_pickup" &&
    d.deliveryPartnerId === undefined && d.deliveryPartner === undefined && d.deliveryReleasedBy === RIDER &&
    /not ready/.test(d.deliveryIssue) && disp.declinedBy.includes(RIDER), JSON.stringify({ d, disp }));
  const rel2 = await S.releaseOrderCore(db, RIDER, r1, "seller_not_ready", T0 + 1000);
  record("r02_release_retry_is_idempotent", rel2.kind === "already" && (await timeline(r1)).length === 1, JSON.stringify(rel2));
  const r3 = await order("picked_up");
  const late = await S.releaseOrderCore(db, RIDER, r3, "seller_not_ready", T0);
  record("r03_release_after_pickup_refused", late.kind === "refused" && late.reason === "after_pickup" && (await get(r3)).deliveryPartnerId === RIDER, JSON.stringify(late));
  const r4 = await order("delivery_accepted");
  const notMine = await S.releaseOrderCore(db, OTHER, r4, "seller_not_ready", T0);
  record("r04_release_by_another_rider_refused", notMine.kind === "refused" && notMine.reason === "not_assigned", JSON.stringify(notMine));
  await db.doc("delivery_dispatch/dlv3c-keep").set({ declinedBy: ["someone"] });
  const r5 = await order("delivery_accepted");
  await db.doc(`delivery_dispatch/${r5}`).set({ declinedBy: ["someone"], status: "assigned" });
  await S.releaseOrderCore(db, RIDER, r5, "other", T0);
  const disp5 = (await db.doc(`delivery_dispatch/${r5}`).get()).data();
  record("r05_release_keeps_earlier_declines", disp5.declinedBy.length === 2 && disp5.declinedBy.includes("someone") && disp5.status === "assigned", JSON.stringify(disp5));

  const failed = results.filter((r) => !r.pass);
  console.log(`\n${results.length - failed.length}/${results.length} passed`);
  if (failed.length) { console.log("PHASE DLV-3C steps: FAILED"); process.exit(1); }
  console.log("PHASE DLV-3C steps: ALL PASSED");
  process.exit(0);
}
main().catch((e) => { console.error(e); process.exit(1); });
