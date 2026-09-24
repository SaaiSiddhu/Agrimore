// Phase DLV-INT — a rider whose only "active" order was finished through
// `status` alone (seller/admin panels write only `status`; `orderStatus` still
// says out_for_delivery) is NOT busy. Found in the integration pass: the
// server's RIDER_ACTIVE_ORDER_STATUSES queries read `orderStatus` only, so
// such a rider was never offered orders, refused at accept, never swept
// offline and could not delete the account. holdsRider() (dispatch.ts) weighs
// both fields, as the rider app already does.
//  b01 dispatch offers the order to that rider
//  b02 accept is not refused as busy
//  b03 the presence sweep can take the silent rider offline
//  b04 account deletion is not refused for an active order
//  b05 a safety report does not link the finished order
//  b06 a genuinely active order still makes the rider busy (all five)
// Run with: firebase emulators:exec --only firestore "node scripts/phaseDLVINT_rider_busy_test.js"
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
const PROJECT = process.env.GCLOUD_PROJECT || "demo-dlvint-busy";
if (!PROJECT.startsWith("demo-")) { console.error("REFUSING: not a demo- project"); process.exit(2); }
const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: PROJECT });
const db = admin.firestore();
const { Timestamp } = require("firebase-admin/firestore");
const D = require("../lib/delivery/dispatch");
const C = require("../lib/delivery/dispatchCallables");
const P = require("../lib/delivery/riderPresence");
const A = require("../lib/delivery/riderAccountDeletion");
const I = require("../lib/delivery/riderIncidents");

const results = [];
const record = (label, pass, detail) => { results.push(pass); console.log(`${pass ? "PASSED" : "FAILED"} — ${label}${pass ? "" : ` :: ${detail}`}`); };
const NOW = Date.now();
const STORE = { lat: 9.9252, lng: 78.1198 };

async function rider(id, extra = {}) {
  await db.doc(`delivery_partners/${id}`).set({ name: id, status: "approved", isOnline: true, city: "Madurai", pincode: "625001",
    currentLat: STORE.lat + 0.004, currentLng: STORE.lng, lastLocationUpdate: Timestamp.fromMillis(NOW), ...extra });
  await db.doc(`users/${id}`).set({ role: "delivery_partner" });
}
async function held(id, riderId, orderStatus, status) {
  await db.doc(`orders/${id}`).set({ orderStatus, status, deliveryPartnerId: riderId, userId: "c1", sellerId: "s1",
    paymentMethod: "upi", total: 200, createdAt: Timestamp.fromMillis(NOW - 3600e3) });
}
async function ready(id) {
  await db.doc(`orders/${id}`).set({ orderStatus: "ready_for_pickup", status: "ready_for_pickup", userId: "c1", sellerId: "s1",
    pickupLat: STORE.lat, pickupLng: STORE.lng, paymentMethod: "upi", total: 200, deliveryAddress: { latitude: 9.93, longitude: 78.12, pincode: "625002" } });
}

async function main() {
  console.log("=== PHASE DLV-INT — rider busy by both status fields ===");
  await db.doc("sellers/s1").set({ storeLat: STORE.lat, storeLng: STORE.lng, city: "Madurai", pincode: "625001" });

  // The rider under test: one order finished through `status` only.
  await rider("rF");
  await held("f-old", "rF", "out_for_delivery", "delivered");

  // b01
  await ready("f-new");
  await D.startDispatch(db, "f-new", (await db.doc("orders/f-new").get()).data(), NOW);
  const offered = (await db.collection("delivery_requests").where("orderId", "==", "f-new").get()).docs.map((d) => d.data().riderId);
  record("b01_dispatch_offers_to_the_rider", offered.includes("rF"), JSON.stringify(offered));

  // b02
  const acc = offered.includes("rF") ? await C.acceptOfferCore(db, "rF", "f-new", NOW + 1000) : { kind: "no offer to accept" };
  record("b02_accept_not_refused_busy", acc.kind === "accepted", JSON.stringify(acc));

  // b03 (a second rider, silent, with the same kind of finished order)
  await rider("rS", { lastLocationUpdate: Timestamp.fromMillis(NOW - 20 * 60e3), lastStatusUpdate: Timestamp.fromMillis(NOW - 20 * 60e3) });
  await held("s-old", "rS", "picked_up", "cancelled");
  const off = await P.sweepSilentRiders(db, NOW);
  record("b03_silent_rider_swept", off.includes("rS"), JSON.stringify(off));

  // b04 / b05 (a third rider)
  await rider("rD");
  await held("d-old", "rD", "outForDelivery", "delivered");
  const ref = await A.riderDeletionRefusal(db, "rD");
  record("b04_deletion_not_refused_for_finished_order", ref === null || ref.reason !== "rider_active_order", JSON.stringify(ref));
  const inc = await I.reportIncidentCore(db, "rD", { requestId: "busy-test-0001", kind: "sos" }, NOW);
  const incDoc = (await db.doc(`rider_incidents/${inc.incidentId}`).get()).data() ?? {};
  record("b05_incident_does_not_link_finished_order", inc.kind === "reported" && (incDoc.activeOrderIds ?? []).length === 0,
    JSON.stringify({ inc, ids: incDoc.activeOrderIds }));

  // b06: genuinely active orders still count, everywhere.
  await rider("rA", { lastLocationUpdate: Timestamp.fromMillis(NOW - 20 * 60e3), lastStatusUpdate: Timestamp.fromMillis(NOW - 20 * 60e3) });
  await held("a-live", "rA", "out_for_delivery", "out_for_delivery");
  await ready("a-new");
  await D.startDispatch(db, "a-new", (await db.doc("orders/a-new").get()).data(), NOW);
  const offeredA = (await db.collection("delivery_requests").where("orderId", "==", "a-new").get()).docs.map((d) => d.data().riderId);
  await db.doc("delivery_requests/a-new_rA").set({ orderId: "a-new", riderId: "rA", status: "offered", expiresAt: Timestamp.fromMillis(NOW + 30000) });
  await db.doc("delivery_partners/rA").update({ lastLocationUpdate: Timestamp.fromMillis(NOW) });
  const accA = await C.acceptOfferCore(db, "rA", "a-new", NOW + 1000);
  await db.doc("delivery_partners/rA").update({ lastLocationUpdate: Timestamp.fromMillis(NOW - 20 * 60e3), isOnline: true });
  const offA = await P.sweepSilentRiders(db, NOW + 2000);
  const refA = await A.riderDeletionRefusal(db, "rA");
  const incA = await I.reportIncidentCore(db, "rA", { requestId: "busy-test-0002", kind: "sos" }, NOW);
  const incADoc = (await db.doc(`rider_incidents/${incA.incidentId}`).get()).data() ?? {};
  record("b06_live_order_still_busy_everywhere", !offeredA.includes("rA") && accA.reason === "busy" && !offA.includes("rA") &&
    refA?.reason === "rider_active_order" && (incADoc.activeOrderIds ?? []).join() === "a-live",
    JSON.stringify({ offeredA, accA, offA, refA, ids: incADoc.activeOrderIds }));

  const failed = results.filter((x) => !x).length;
  console.log(`\n${results.length - failed}/${results.length} passed`);
  process.exit(failed ? 1 : 0);
}
main().catch((e) => { console.error(e); process.exit(1); });
