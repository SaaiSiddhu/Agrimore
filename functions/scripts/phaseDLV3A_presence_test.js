// Phase DLV-3A — rider presence (riderPresence.ts) and dispatch freshness.
//
//  p01–p07 sweepSilentRiders: an online rider silent > 15 min goes offline
//          (reason no_location); 14 min does not; a rider who only just
//          toggled online is judged by lastStatusUpdate; a rider on an active
//          order is never taken offline; offline riders are untouched; a
//          rider with no timestamps at all goes offline; idempotent.
//  p08–p09 LOCATION_FRESHNESS_MS is 5 min: a 6-min-old location is not
//          offered, a 4-min-old one is.
//  p10–p14 riderAssignmentChange: admin assign → new rider; admin reassign →
//          new + previous; rider's own accept, same rider, or no rider → none.
//
// Riders have NO FCM tokens, so no push is attempted.
// Run with:
//   firebase emulators:exec --only firestore "node scripts/phaseDLV3A_presence_test.js"
// Requires: npm run build. Honours FIRESTORE_EMULATOR_HOST.
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: "demo-dlv3a-presence" });
const db = admin.firestore();
const { Timestamp } = require("firebase-admin/firestore");
const { sweepSilentRiders, riderAssignmentChange, SILENT_OFFLINE_MS } = require("../lib/delivery/riderPresence");
const { rankCandidates, LOCATION_FRESHNESS_MS } = require("../lib/delivery/dispatch");

const results = [];
function record(label, pass, detail) {
  results.push({ label, pass });
  console.log(`${pass ? "PASSED" : "FAILED"} — ${label}${pass ? "" : ` :: ${detail}`}`);
}
const T0 = Date.UTC(2026, 8, 23, 6, 0, 0);
const MIN = 60 * 1000;
const ts = (ms) => Timestamp.fromMillis(ms);

async function clear() {
  for (const c of ["delivery_partners", "orders", "users"]) {
    const s = await db.collection(c).get();
    await Promise.all(s.docs.map((d) => d.ref.delete()));
  }
}
async function rider(id, p) {
  await db.collection("delivery_partners").doc(id).set({ name: id, status: "approved", ...p });
  await db.collection("users").doc(id).set({ role: "delivery_partner" });
}
const get = async (id) => (await db.collection("delivery_partners").doc(id).get()).data();

async function main() {
  console.log("=== PHASE DLV-3A — rider presence ===");
  record("p00_constants", SILENT_OFFLINE_MS === 15 * MIN && LOCATION_FRESHNESS_MS === 5 * MIN,
    `${SILENT_OFFLINE_MS} ${LOCATION_FRESHNESS_MS}`);
  await clear();
  await rider("silent16", { isOnline: true, lastLocationUpdate: ts(T0 - 16 * MIN), lastStatusUpdate: ts(T0 - 60 * MIN) });
  await rider("silent14", { isOnline: true, lastLocationUpdate: ts(T0 - 14 * MIN) });
  await rider("justToggled", { isOnline: true, lastLocationUpdate: ts(T0 - 120 * MIN), lastStatusUpdate: ts(T0 - 1 * MIN) });
  await rider("busySilent", { isOnline: true, lastLocationUpdate: ts(T0 - 40 * MIN) });
  await rider("offlineOld", { isOnline: false, lastLocationUpdate: ts(T0 - 500 * MIN) });
  await rider("noStamps", { isOnline: true });
  await db.collection("orders").doc("o-busy").set({ orderStatus: "picked_up", deliveryPartnerId: "busySilent" });

  const off = (await sweepSilentRiders(db, T0)).sort();
  record("p01_sweep_returns_exactly_the_silent_free_riders", JSON.stringify(off) === JSON.stringify(["noStamps", "silent16"]), JSON.stringify(off));
  const s16 = await get("silent16");
  record("p02_silent_16_min_goes_offline_with_reason",
    s16.isOnline === false && s16.offlineReason === "no_location" && s16.offlineAt?.toMillis() === T0, JSON.stringify(s16));
  record("p03_silent_14_min_stays_online", (await get("silent14")).isOnline === true, "");
  record("p04_just_toggled_online_judged_by_lastStatusUpdate", (await get("justToggled")).isOnline === true, "");
  record("p05_rider_on_an_active_order_never_taken_offline", (await get("busySilent")).isOnline === true, "");
  const o = await get("offlineOld");
  record("p06_offline_rider_untouched", o.isOnline === false && o.offlineReason === undefined, JSON.stringify(o));
  const again = await sweepSilentRiders(db, T0);
  record("p07_second_sweep_is_a_no_op", again.length === 0, JSON.stringify(again));

  const pickup = { lat: 9.9252, lng: 78.1198 };
  const partners = [
    { id: "six", data: { status: "approved", isOnline: true, currentLat: 9.93, currentLng: 78.12, lastLocationUpdate: ts(T0 - 6 * MIN) } },
    { id: "four", data: { status: "approved", isOnline: true, currentLat: 9.93, currentLng: 78.12, lastLocationUpdate: ts(T0 - 4 * MIN) } },
  ];
  const chosen = rankCandidates(partners, { pickup, orderAddress: {}, exclude: new Set(), busy: new Set(), radiusKm: 5, limit: 3, nowMs: T0 }).map((c) => c.id);
  record("p08_six_minute_old_location_not_offered", !chosen.includes("six"), JSON.stringify(chosen));
  record("p09_four_minute_old_location_offered", chosen.includes("four"), JSON.stringify(chosen));

  const eq = (a, b) => JSON.stringify(a) === JSON.stringify(b);
  record("p10_admin_assign_notifies_new_rider",
    eq(riderAssignmentChange({ deliveryPartnerId: null }, { deliveryPartnerId: "r1", deliveryAcceptedVia: "admin" }), { assignedTo: "r1", removedFrom: null }), "");
  record("p11_admin_reassign_notifies_both",
    eq(riderAssignmentChange({ deliveryPartnerId: "r1", deliveryAcceptedVia: "admin" }, { deliveryPartnerId: "r2", deliveryAcceptedVia: "admin" }), { assignedTo: "r2", removedFrom: "r1" }), "");
  record("p12_rider_own_accept_no_push",
    eq(riderAssignmentChange({}, { deliveryPartnerId: "r1", deliveryAcceptedVia: "acceptDeliveryOffer" }), { assignedTo: null, removedFrom: null }), "");
  record("p13_unrelated_update_same_rider_no_push",
    eq(riderAssignmentChange({ deliveryPartnerId: "r1", deliveryAcceptedVia: "admin" }, { deliveryPartnerId: "r1", deliveryAcceptedVia: "admin", orderStatus: "picked_up" }), { assignedTo: null, removedFrom: null }), "");
  record("p14_rider_removed_without_new_one_no_push",
    eq(riderAssignmentChange({ deliveryPartnerId: "r1" }, { deliveryPartnerId: null, deliveryAcceptedVia: "admin" }), { assignedTo: null, removedFrom: null }), "");

  await clear();
  const failed = results.filter((r) => !r.pass);
  console.log(`\n${results.length - failed.length}/${results.length} passed`);
  if (failed.length) { console.log("PHASE DLV-3A presence: FAILED"); process.exit(1); }
  console.log("PHASE DLV-3A presence: ALL PASSED");
  process.exit(0);
}
main().catch((e) => { console.error(e); process.exit(1); });
