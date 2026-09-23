// Phase DLV-3C — the rider-step callables through the REAL functions emulator
// (HTTP with an Auth-emulator ID token, exactly as the rider app calls them)
// and the triggers they set off under genuine background dispatch — never
// test.wrap() (P0-FIELDVALUE: v1 dispatch differs; see phaseDLV2A_trigger_test).
//
//  g01 advanceDeliveryStep (arrived, 1.2 km from the store) → order
//      arrived_at_store, flagged far_from_store; syncDeliveryTask → at_pickup
//  g02 an illegal jump comes back failed-precondition / bad_transition
//  g03 another rider → permission-denied / not_assigned
//  g04 no sign-in → unauthenticated
//  g05 releaseDeliveryOrder → ready_for_pickup; onOrderStatusChanged restarts
//      dispatch; the next offer goes to the OTHER nearby rider, never back to
//      the one who released it
//  g06 picked up → out for delivery → confirmDelivery with a far position →
//      delivered + far_from_customer flag; the task follows to delivered
//
// Run with:
//   firebase emulators:exec --only firestore,functions,auth --project demo-agrimore-dlv3c \
//     "node scripts/phaseDLV3C_dispatch_test.js"
// Requires: npm run build. Honours FIRESTORE_EMULATOR_HOST, FIREBASE_AUTH_EMULATOR_HOST
// and FUNCTIONS_PORT (default 5001).
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
process.env.FIREBASE_AUTH_EMULATOR_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || "127.0.0.1:9099";
const PROJECT = process.env.GCLOUD_PROJECT || "demo-agrimore-dlv3c";
if (!PROJECT.startsWith("demo-")) {
  console.error(`REFUSING: project ${PROJECT} is not a demo- project`);
  process.exit(2);
}
const FN = `http://127.0.0.1:${process.env.FUNCTIONS_PORT || 5001}/${PROJECT}/us-central1`;
const AUTH = process.env.FIREBASE_AUTH_EMULATOR_HOST;

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

const PW = "dlv3c-pass-123";
async function rider(email) {
  let u;
  try { u = await admin.auth().getUserByEmail(email); } catch { u = await admin.auth().createUser({ email, password: PW }); }
  const t = await fetch(`http://${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key`, {
    method: "POST", headers: { "content-type": "application/json" },
    body: JSON.stringify({ email, password: PW, returnSecureToken: true }),
  }).then((r) => r.json());
  return { uid: u.uid, token: t.idToken };
}
async function call(name, token, data) {
  const res = await fetch(`${FN}/${name}`, {
    method: "POST",
    headers: { "content-type": "application/json", ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: JSON.stringify({ data }),
  });
  const j = await res.json().catch(() => ({}));
  return { status: res.status, result: j.result, error: j.error };
}

const STORE = { lat: 9.9252, lng: 78.1198 };
const HOME = { lat: 9.8982, lng: 78.1198 };
const M = 1 / 111320;

async function main() {
  console.log("=== PHASE DLV-3C — rider steps under genuine dispatch ===");
  const r1 = await rider("dlv3c-r1@preview.test");
  const r2 = await rider("dlv3c-r2@preview.test");
  const fresh = Timestamp.now();
  for (const [r, north] of [[r1, 0.004], [r2, 0.006]]) {
    await db.doc(`users/${r.uid}`).set({ role: "delivery_partner", name: r.uid });
    await db.doc(`delivery_partners/${r.uid}`).set({
      id: r.uid, name: `Rider ${r.uid.slice(0, 4)}`, status: "approved", isOnline: true,
      currentLat: STORE.lat + north, currentLng: STORE.lng, lastLocationUpdate: fresh,
    });
  }
  await db.doc("sellers/dlv3c-seller").set({ storeLat: STORE.lat, storeLng: STORE.lng, businessName: "Store" });
  const order = async (id, status) => {
    await db.doc(`orders/${id}`).set({
      userId: "dlv3c-customer", sellerId: "dlv3c-seller", orderNumber: id.toUpperCase(), total: 480, paymentMethod: "cod",
      orderStatus: status, status, deliveryPartnerId: r1.uid,
      deliveryAddress: { latitude: HOME.lat, longitude: HOME.lng, pincode: "625002", city: "Madurai" },
      createdAt: Timestamp.now(),
    });
    await db.doc(`orders/${id}/secrets/delivery`).set({ code: "123456" });
  };

  // ── g01 ──
  await order("dlv3c-g1", "delivery_accepted");
  await waitFor(async () => ({ done: (await db.doc("delivery_tasks/dlv3c-g1").get()).data()?.status === "assigned" }));
  const g1 = await call("advanceDeliveryStep", r1.token,
    { orderId: "dlv3c-g1", step: "arrived_at_store", lat: STORE.lat + 1200 * M, lng: STORE.lng, accuracy: 9, isMocked: false, locationStatus: "ok" });
  const o1 = (await db.doc("orders/dlv3c-g1").get()).data();
  const t1 = await waitFor(async () => {
    const t = (await db.doc("delivery_tasks/dlv3c-g1").get()).data();
    return { done: t?.status === "at_pickup", t };
  });
  record("g01_step_over_http_flagged_and_projected", g1.status === 200 && g1.result?.flags?.join() === "far_from_store" &&
    o1.orderStatus === "arrived_at_store" && o1.deliveryFlagged === true && t1.done, JSON.stringify({ g1, flags: o1.deliveryFlags, task: t1.t?.status }));

  // ── g02 / g03 / g04 ──
  const g2 = await call("advanceDeliveryStep", r1.token, { orderId: "dlv3c-g1", step: "arrived_at_store", locationStatus: "unavailable" });
  const g2b = await call("advanceDeliveryStep", r1.token, { orderId: "dlv3c-g1", step: "out_for_delivery", locationStatus: "unavailable" });
  record("g02_retry_ok_illegal_jump_refused", g2.status === 200 && g2.result?.alreadyAtStep === true &&
    g2b.status === 400 && g2b.error?.status === "FAILED_PRECONDITION" && g2b.error?.details?.reason === "bad_transition", JSON.stringify({ g2, g2b }));
  const g3 = await call("advanceDeliveryStep", r2.token, { orderId: "dlv3c-g1", step: "picked_up", locationStatus: "unavailable" });
  record("g03_other_rider_refused", g3.error?.status === "PERMISSION_DENIED" && g3.error?.details?.reason === "not_assigned", JSON.stringify(g3));
  const g4 = await call("advanceDeliveryStep", null, { orderId: "dlv3c-g1", step: "picked_up" });
  record("g04_unauthenticated", g4.error?.status === "UNAUTHENTICATED", JSON.stringify(g4));

  // ── g05 release → dispatch restarts without the releasing rider ──
  const g5 = await call("releaseDeliveryOrder", r1.token, { orderId: "dlv3c-g1", reason: "seller_not_ready" });
  const offered = await waitFor(async () => {
    const offers = (await db.collection("delivery_requests").where("orderId", "==", "dlv3c-g1").get()).docs.map((d) => d.data());
    const disp = (await db.doc("delivery_dispatch/dlv3c-g1").get()).data();
    return { done: offers.some((o) => (o.riderId ?? o.partnerId) === r2.uid), offers, disp };
  }, 25000);
  const o5 = (await db.doc("orders/dlv3c-g1").get()).data();
  record("g05_release_redispatches_to_someone_else", g5.status === 200 && o5.orderStatus === "ready_for_pickup" && !o5.deliveryPartnerId &&
    offered.done && !offered.offers.some((o) => (o.riderId ?? o.partnerId) === r1.uid) && offered.disp?.declinedBy?.includes(r1.uid),
    JSON.stringify({ g5, status: o5.orderStatus, offers: offered.offers?.map((o) => [o.riderId ?? o.partnerId, o.status]), disp: offered.disp?.declinedBy }));

  // ── g06 the rest of the way, delivered with a far position ──
  await order("dlv3c-g6", "delivery_accepted");
  const near = { lat: STORE.lat + 30 * M, lng: STORE.lng, accuracy: 6, isMocked: false, locationStatus: "ok" };
  const a = await call("advanceDeliveryStep", r1.token, { orderId: "dlv3c-g6", step: "arrived_at_store", ...near });
  const b = await call("advanceDeliveryStep", r1.token, { orderId: "dlv3c-g6", step: "picked_up", ...near });
  const c = await call("advanceDeliveryStep", r1.token, { orderId: "dlv3c-g6", step: "out_for_delivery", ...near });
  const d = await call("confirmDelivery", r1.token, { orderId: "dlv3c-g6", code: "123456", lat: HOME.lat + 900 * M, lng: HOME.lng, accuracy: 7, isMocked: false, locationStatus: "ok" });
  const o6 = (await db.doc("orders/dlv3c-g6").get()).data();
  const t6 = await waitFor(async () => {
    const t = (await db.doc("delivery_tasks/dlv3c-g6").get()).data();
    return { done: t?.status === "delivered", t };
  });
  const checks = o6.deliveryStepChecks || {};
  record("g06_full_flow_delivered_with_drop_flag",
    [a, b, c, d].every((x) => x.status === 200) && o6.orderStatus === "delivered" && o6.deliveryConfirmedVia === "confirmDelivery" &&
    Object.keys(checks).sort().join() === "arrived_at_store,delivered,out_for_delivery,picked_up" &&
    o6.deliveryFlags?.length === 1 && o6.deliveryFlags[0].reasons.join() === "far_from_customer" && t6.done,
    JSON.stringify({ codes: [a, b, c, d].map((x) => x.status), d: d.error, status: o6.orderStatus, flags: o6.deliveryFlags, task: t6.t?.status }));

  const failed = results.filter((r) => !r.pass);
  console.log(`\n${results.length - failed.length}/${results.length} passed`);
  if (failed.length) { console.log("PHASE DLV-3C dispatch: FAILED"); process.exit(1); }
  console.log("PHASE DLV-3C dispatch: ALL PASSED");
  process.exit(0);
}
main().catch((e) => { console.error(e); process.exit(1); });
