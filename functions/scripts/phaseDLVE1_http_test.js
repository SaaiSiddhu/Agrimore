// Phase DLV-E1 — proof and exception callables over GENUINE HTTP with the
// real Storage emulator.
//  h01 attachDeliveryProof before the photo exists → no_photo
//  h02 photo uploaded → attached as the fixed path; retry → already
//  h03 another rider → permission-denied
//  h04 reportDeliveryException → record + order marker; admin acknowledges and
//      resolves (reattempt) over HTTP; a rider cannot resolve
// Run with: firebase emulators:exec --only firestore,functions,auth,storage --project demo-agrimore-dlve1 \
//             "node scripts/phaseDLVE1_http_test.js"
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
process.env.FIREBASE_AUTH_EMULATOR_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || "127.0.0.1:9099";
process.env.FIREBASE_STORAGE_EMULATOR_HOST = process.env.FIREBASE_STORAGE_EMULATOR_HOST || "127.0.0.1:9199";
const PROJECT = process.env.GCLOUD_PROJECT || "demo-agrimore-dlve1";
if (!PROJECT.startsWith("demo-")) { console.error(`REFUSING: project ${PROJECT} is not a demo- project`); process.exit(2); }
const FN = `http://127.0.0.1:${process.env.FUNCTIONS_PORT || 5001}/${PROJECT}/us-central1`;
const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: PROJECT, storageBucket: `${PROJECT}.appspot.com` });
const db = admin.firestore();
const { Timestamp } = require("firebase-admin/firestore");
const results = [];
const record = (label, pass, detail) => { results.push(pass); console.log(`${pass ? "PASSED" : "FAILED"} — ${label}${pass ? "" : ` :: ${detail}`}`); };
async function account(email, claims) {
  let u; try { u = await admin.auth().getUserByEmail(email); } catch { u = await admin.auth().createUser({ email, password: "dlve1-pass-1" }); }
  if (claims) await admin.auth().setCustomUserClaims(u.uid, claims);
  const t = await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake`, {
    method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ email, password: "dlve1-pass-1", returnSecureToken: true }) }).then((r) => r.json());
  return { uid: u.uid, token: t.idToken };
}
async function call(name, token, data) {
  const res = await fetch(`${FN}/${name}`, { method: "POST", headers: { "content-type": "application/json", authorization: `Bearer ${token}` }, body: JSON.stringify({ data }) });
  const j = await res.json().catch(() => ({}));
  return { status: res.status, result: j.result, error: j.error };
}
async function main() {
  const r1 = await account("dlve1-r1@preview.test", { delivery_partner: true });
  const r2 = await account("dlve1-r2@preview.test", { delivery_partner: true });
  const boss = await account("dlve1-admin@preview.test", { admin: true, role: "admin" });
  await db.doc(`users/${boss.uid}`).set({ role: "admin" });
  await db.doc("orders/h-del").set({ deliveryPartnerId: r1.uid, orderStatus: "delivered", status: "delivered", deliveredAt: Timestamp.now() });
  let c = await call("attachDeliveryProof", r1.token, { orderId: "h-del" });
  record("h01_no_photo_yet", c.error?.details?.reason === "no_photo", JSON.stringify(c));
  await admin.storage().bucket().file("delivery_proofs/h-del_proof").save(Buffer.from([0xff, 0xd8, 0xff, 0xe0]), { contentType: "image/jpeg" });
  c = await call("attachDeliveryProof", r1.token, { orderId: "h-del" });
  const again = await call("attachDeliveryProof", r1.token, { orderId: "h-del" });
  record("h02_attached_fixed_path_then_already", c.result?.path === "delivery_proofs/h-del_proof" && again.result?.alreadyAttached === true &&
    (await db.doc("orders/h-del").get()).data().deliveryProofPath === "delivery_proofs/h-del_proof", JSON.stringify({ c, again }));
  c = await call("attachDeliveryProof", r2.token, { orderId: "h-del" });
  record("h03_other_rider_refused", c.error?.status === "PERMISSION_DENIED", JSON.stringify(c));
  await db.doc("orders/h-out").set({ deliveryPartnerId: r1.uid, orderStatus: "out_for_delivery", status: "out_for_delivery", paymentMethod: "cod", total: 200 });
  const rep = await call("reportDeliveryException", r1.token, { orderId: "h-out", requestId: "http-req-0001", reason: "customer_unreachable", note: "No answer" });
  const id = rep.result?.exceptionId;
  const riderResolve = await call("updateDeliveryException", r1.token, { exceptionId: id, action: "resolve", disposition: "reattempt", resolution: "self" });
  const ack = await call("updateDeliveryException", boss.token, { exceptionId: id, action: "acknowledge" });
  const res = await call("updateDeliveryException", boss.token, { exceptionId: id, action: "resolve", disposition: "reattempt", resolution: "Customer answered, try now." });
  const ex = (await db.doc(`delivery_exceptions/${id}`).get()).data();
  const order = (await db.doc("orders/h-out").get()).data();
  record("h04_report_ack_resolve_over_http", !!id && riderResolve.error?.status === "PERMISSION_DENIED" && ack.result?.status === "acknowledged" &&
    res.result?.status === "resolved" && ex.disposition === "reattempt" && order.openDeliveryException === undefined && order.total === 200,
    JSON.stringify({ rep, riderResolve, ack, res }));
  const failed = results.filter((x) => !x).length;
  console.log(`\n${results.length - failed}/${results.length} passed`);
  process.exit(failed ? 1 : 0);
}
main().catch((e) => { console.error(e); process.exit(1); });
