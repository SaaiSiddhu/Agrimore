// Phase DLV-2A — the dispatch and projection triggers under GENUINE background
// dispatch (external Firestore writes, triggers run by the functions
// emulator) — never test.wrap(), which does not reproduce the v1
// background-dispatch context where namespace-style
// `admin.firestore.FieldValue` is undefined (P0-FIELDVALUE, see
// src/customer/wallet.ts:557 and phase41_fieldvalue_trigger_fix_test.js).
//
// Proves, end to end through real triggers:
//  t01 an order becoming ready_for_pickup → syncDeliveryTask writes a
//      `searching` delivery_tasks doc (DLV-1A's trigger; it used the
//      namespace style and would have crashed in production)
//  t02 … → onOrderStatusChanged starts dispatch: delivery_dispatch wave 1 and
//      offers to the nearest riders
//  t03 a legacy client claim (order → delivery_accepted) → onOrderStatusChanged
//      closes the dispatch and withdraws the other offers
//  t04 … → syncDeliveryTask moves the task to `assigned`
//
// Riders and customer have NO FCM tokens, so no push is attempted.
//
// Run with:
//   firebase emulators:exec --only firestore,functions,auth --project demo-agrimore-dlv2a \
//     "node scripts/phaseDLV2A_trigger_test.js"
// Requires: npm run build. Honours FIRESTORE_EMULATOR_HOST.
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
// Run under a demo- project so NOTHING can reach production: the role-claim
// triggers call admin.auth() on every users/delivery_partners write, and with
// a real project id the functions emulator would send those to the live
// project for any service not emulated (see the near-miss in CAT-10).
const PROJECT = process.env.GCLOUD_PROJECT || "demo-agrimore-dlv2a";
if (!PROJECT.startsWith("demo-")) {
  console.error(`REFUSING: project ${PROJECT} is not a demo- project`);
  process.exit(2);
}

const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: PROJECT });
const db = admin.firestore();
const { Timestamp } = require("firebase-admin/firestore");

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function waitFor(check, timeoutMs = 20000) {
  const end = Date.now() + timeoutMs;
  let last;
  while (Date.now() < end) {
    last = await check();
    if (last && last.done) return last;
    await sleep(300);
  }
  return last || { done: false };
}

const results = [];
function record(label, pass, detail) {
  results.push({ label, pass });
  console.log(`${pass ? "PASSED" : "FAILED"} — ${label}${pass ? "" : ` :: ${detail}`}`);
}

async function main() {
  console.log("=== PHASE DLV-2A — triggers under genuine background dispatch ===");
  const STORE = { lat: 9.9252, lng: 78.1198 };
  const KM = 1 / 111.2;
  await db.collection("sellers").doc("t-seller").set({ storeLat: STORE.lat, storeLng: STORE.lng, city: "Madurai", pincode: "625001" });
  for (const [id, km] of [["t-r1", 1], ["t-r2", 2], ["t-r3", 3], ["t-r4", 4]]) {
    await db.collection("delivery_partners").doc(id).set({
      status: "approved", isOnline: true, currentLat: STORE.lat + km * KM, currentLng: STORE.lng,
      lastLocationUpdate: Timestamp.now(), pincode: "625001", city: "Madurai",
    });
    await db.collection("users").doc(id).set({ role: "delivery_partner" });
  }
  await db.collection("users").doc("t-customer").set({ role: "user" });

  const id = "t-order-1";
  const ref = db.collection("orders").doc(id);
  await ref.set({
    userId: "t-customer", sellerId: "t-seller", orderNumber: "T-0001",
    orderStatus: "processing", status: "processing", paymentMethod: "cod", total: 300,
    items: [{ productId: "p", quantity: 1 }],
    deliveryAddress: { city: "Madurai", pincode: "625002", latitude: STORE.lat - 2 * KM, longitude: STORE.lng },
  });
  await sleep(1500);
  await ref.update({ orderStatus: "ready_for_pickup", status: "ready_for_pickup" });

  const task = await waitFor(async () => {
    const s = await db.collection("delivery_tasks").doc(id).get();
    return { done: s.exists && s.data().status === "searching", status: s.exists ? s.data().status : null };
  });
  record("t01_syncDeliveryTask_runs_in_real_background_dispatch", task.done, JSON.stringify(task));

  const disp = await waitFor(async () => {
    const d = await db.collection("delivery_dispatch").doc(id).get();
    const offers = await db.collection("delivery_requests").where("orderId", "==", id).where("status", "==", "offered").get();
    const riders = offers.docs.map((o) => o.data().riderId).sort().join(",");
    return { done: d.exists && d.data().wave === 1 && riders === "t-r1,t-r2,t-r3", wave: d.exists ? d.data().wave : null, riders };
  });
  record("t02_onOrderStatusChanged_starts_dispatch_in_real_background_dispatch", disp.done, JSON.stringify(disp));

  // The released May-6 app's direct claim.
  await ref.update({ deliveryPartnerId: "t-r2", orderStatus: "delivery_accepted", status: "delivery_accepted" });
  const closed = await waitFor(async () => {
    const d = await db.collection("delivery_dispatch").doc(id).get();
    const open = await db.collection("delivery_requests").where("orderId", "==", id).where("status", "==", "offered").get();
    const acc = await db.collection("delivery_requests").doc(`${id}_t-r2`).get();
    return {
      done: d.exists && d.data().status === "assigned" && d.data().assignedTo === "t-r2" && open.empty && acc.data().status === "accepted",
      status: d.exists ? d.data().status : null, open: open.size, winner: acc.exists ? acc.data().status : null,
    };
  });
  record("t03_claim_closes_dispatch_through_the_trigger", closed.done, JSON.stringify(closed));

  const assigned = await waitFor(async () => {
    const s = await db.collection("delivery_tasks").doc(id).get();
    return { done: s.exists && s.data().status === "assigned" && s.data().riderId === "t-r2", status: s.exists ? s.data().status : null };
  });
  record("t04_projection_follows_the_claim", assigned.done, JSON.stringify(assigned));

  const failed = results.filter((r) => !r.pass);
  console.log(`\n${results.length - failed.length}/${results.length} passed`);
  if (failed.length) { console.log("PHASE DLV-2A triggers: FAILED"); process.exit(1); }
  console.log("PHASE DLV-2A triggers: ALL PASSED");
  process.exit(0);
}

main().catch((e) => { console.error("PHASE DLV-2A triggers: harness error", e); process.exit(1); });
