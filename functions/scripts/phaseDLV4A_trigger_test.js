// Phase DLV-4A — onRiderDelivery under GENUINE background dispatch (real
// external writes and HTTP callable calls; the functions emulator runs the
// triggers — never test.wrap()).
//
//  t01 delivered through confirmDelivery (HTTP, rider's ID token) → exactly
//      one rider_earnings doc; COD → cashHeld and codSettlementStatus collected
//  t02 delivered by the RELEASED app's direct write (rules-permitted until
//      DLV-3D) → exactly one earning too
//  t03 later updates to a delivered order (proof photo, admin note) fire the
//      trigger again and create nothing
//  t04 the admin callables over HTTP: a rider cannot record a deposit; admin can
//  t05 a rider's bank-change request over HTTP; admin approves
//
// Run with:
//   firebase emulators:exec --only firestore,functions,auth --project demo-agrimore-dlv4a \
//     "node scripts/phaseDLV4A_trigger_test.js"
// Requires: npm run build. Honours FIRESTORE_EMULATOR_HOST, FIREBASE_AUTH_EMULATOR_HOST, FUNCTIONS_PORT.
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
process.env.FIREBASE_AUTH_EMULATOR_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || "127.0.0.1:9099";
const PROJECT = process.env.GCLOUD_PROJECT || "demo-agrimore-dlv4a";
if (!PROJECT.startsWith("demo-")) {
  console.error(`REFUSING: project ${PROJECT} is not a demo- project`);
  process.exit(2);
}
const FN = `http://127.0.0.1:${process.env.FUNCTIONS_PORT || 5001}/${PROJECT}/us-central1`;
const AUTH = process.env.FIREBASE_AUTH_EMULATOR_HOST;

const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: PROJECT });
const db = admin.firestore();
const { Timestamp, FieldValue } = require("firebase-admin/firestore");

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
const PW = "dlv4a-pass-123";
async function account(email, role, claims) {
  let u;
  try { u = await admin.auth().getUserByEmail(email); } catch { u = await admin.auth().createUser({ email, password: PW }); }
  if (claims) await admin.auth().setCustomUserClaims(u.uid, claims);
  await db.doc(`users/${u.uid}`).set({ role, email });
  const t = await fetch(`http://${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key`, {
    method: "POST", headers: { "content-type": "application/json" },
    body: JSON.stringify({ email, password: PW, returnSecureToken: true }),
  }).then((r) => r.json());
  return { uid: u.uid, token: t.idToken };
}
async function call(name, token, data) {
  const res = await fetch(`${FN}/${name}`, {
    method: "POST", headers: { "content-type": "application/json", ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: JSON.stringify({ data }),
  });
  const j = await res.json().catch(() => ({}));
  return { status: res.status, result: j.result, error: j.error };
}
const STORE = { lat: 9.9252, lng: 78.1198 };
const HOME = { lat: 9.8982, lng: 78.1198 };
const earningsFor = async (orderId) => (await db.collection("rider_earnings").where("orderId", "==", orderId).get()).size;

async function main() {
  console.log("=== PHASE DLV-4A — rider money under genuine dispatch ===");
  const rider = await account("dlv4a-rider@preview.test", "delivery_partner", { role: "delivery_partner", delivery_partner: true });
  const boss = await account("dlv4a-admin@preview.test", "admin", { role: "admin", admin: true });
  await db.doc(`delivery_partners/${rider.uid}`).set({ status: "approved", name: "Ravi", isOnline: true });
  await db.doc("sellers/dlv4a-seller").set({ storeLat: STORE.lat, storeLng: STORE.lng });
  const order = async (id, status, pay = "cod") => {
    await db.doc(`orders/${id}`).set({
      userId: "c", sellerId: "dlv4a-seller", orderNumber: id.toUpperCase(), total: 480, paymentMethod: pay,
      orderStatus: status, status, deliveryPartnerId: rider.uid,
      deliveryAddress: { latitude: HOME.lat, longitude: HOME.lng, pincode: "625002" }, createdAt: Timestamp.now(),
    });
    await db.doc(`orders/${id}/secrets/delivery`).set({ code: "246810" });
  };

  // t01 — confirmDelivery
  await order("dlv4a-t1", "out_for_delivery");
  const c1 = await call("confirmDelivery", rider.token, { orderId: "dlv4a-t1", code: "246810", locationStatus: "unavailable" });
  const e1 = await waitFor(async () => {
    const e = (await db.doc("rider_earnings/dlv4a-t1").get()).data();
    return { done: !!e, e };
  });
  const acc1 = (await db.doc(`rider_accounts/${rider.uid}`).get()).data() || {};
  const o1 = (await db.doc("orders/dlv4a-t1").get()).data();
  record("t01_confirmDelivery_pays_once_and_holds_cash", c1.status === 200 && e1.done && e1.e.riderId === rider.uid && e1.e.total > 25 &&
    acc1.cashHeld === 480 && o1.codSettlementStatus === "collected", JSON.stringify({ c1: c1.error ?? c1.result, e: e1.e?.total, acc1, cod: o1.codSettlementStatus }));

  // t02 — the released app's direct write
  await order("dlv4a-t2", "out_for_delivery", "razorpay");
  await db.doc("orders/dlv4a-t2").update({ orderStatus: "delivered", status: "delivered", deliveredAt: FieldValue.serverTimestamp(), codSettlementStatus: "pending" });
  const e2 = await waitFor(async () => ({ done: (await earningsFor("dlv4a-t2")) === 1 }));
  record("t02_direct_delivered_write_pays_once", e2.done, "");

  // t03 — later updates create nothing
  await db.doc("orders/dlv4a-t1").update({ deliveryProofPhoto: "https://example.invalid/p.jpg" });
  await db.doc("orders/dlv4a-t2").update({ adminNote: "checked", status: "delivered" });
  await sleep(4000);
  const acc3 = (await db.doc(`rider_accounts/${rider.uid}`).get()).data();
  record("t03_later_updates_pay_nothing", (await earningsFor("dlv4a-t1")) === 1 && (await earningsFor("dlv4a-t2")) === 1 && acc3.cashHeld === 480,
    JSON.stringify(acc3));

  // t04 — deposits are admin-only
  const d1 = await call("recordRiderCashDeposit", rider.token, { riderId: rider.uid, amount: 480, reference: "SELF" });
  const d2 = await call("recordRiderCashDeposit", boss.token, { riderId: rider.uid, amount: 480, reference: "RCPT-77" });
  const acc4 = (await db.doc(`rider_accounts/${rider.uid}`).get()).data();
  record("t04_only_admin_records_deposits", d1.error?.status === "PERMISSION_DENIED" && d2.status === 200 && acc4.cashHeld === 0,
    JSON.stringify({ d1: d1.error?.status, d2: d2.error ?? d2.result, acc4 }));

  // t05 — bank change request and approval
  const b1 = await call("requestRiderBankChange", rider.token, { accountHolderName: "Ravi Kumar", bankAccountNumber: "123456789012", ifscCode: "SBIN0001234" });
  const b2 = await call("reviewRiderBankChange", rider.token, { requestId: b1.result?.requestId, approve: true });
  const b3 = await call("reviewRiderBankChange", boss.token, { requestId: b1.result?.requestId, approve: true });
  const p = (await db.doc(`delivery_partners/${rider.uid}`).get()).data();
  record("t05_bank_change_request_and_admin_approval", b1.status === 200 && b2.error?.status === "PERMISSION_DENIED" && b3.status === 200 &&
    p.bankAccountNumber === "123456789012" && p.ifscCode === "SBIN0001234", JSON.stringify({ b1: b1.error ?? b1.result, b2: b2.error?.status, b3: b3.error ?? b3.result }));

  const failed = results.filter((r) => !r.pass);
  console.log(`\n${results.length - failed.length}/${results.length} passed`);
  if (failed.length) { console.log("PHASE DLV-4A trigger: FAILED"); process.exit(1); }
  console.log("PHASE DLV-4A trigger: ALL PASSED");
  process.exit(0);
}
main().catch((e) => { console.error(e); process.exit(1); });
