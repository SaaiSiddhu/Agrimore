// Phase DLV-A1 — submitRiderApplication over GENUINE HTTP (functions emulator)
// with the REAL Storage emulator behind the document check.
//
//  h01 signed out → unauthenticated
//  h02 a new account without its photos → invalid-argument, reason documents
//  h03 photos uploaded → pending rider with storage paths; users name exact
//  h04 retry of the same submission → same single record (resubmitted)
//  h05 an approved rider cannot resubmit
//
// Run with:
//   firebase emulators:exec --only firestore,functions,auth,storage --project demo-agrimore-dlva1 \
//     "node scripts/phaseDLVA1_rider_application_http_test.js"
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
process.env.FIREBASE_AUTH_EMULATOR_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || "127.0.0.1:9099";
process.env.FIREBASE_STORAGE_EMULATOR_HOST = process.env.FIREBASE_STORAGE_EMULATOR_HOST || "127.0.0.1:9199";
const PROJECT = process.env.GCLOUD_PROJECT || "demo-agrimore-dlva1";
if (!PROJECT.startsWith("demo-")) { console.error(`REFUSING: project ${PROJECT} is not a demo- project`); process.exit(2); }
const FN = `http://127.0.0.1:${process.env.FUNCTIONS_PORT || 5001}/${PROJECT}/us-central1`;
const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: PROJECT, storageBucket: `${PROJECT}.appspot.com` });
const db = admin.firestore();

const results = [];
const record = (label, pass, detail) => { results.push(pass); console.log(`${pass ? "PASSED" : "FAILED"} — ${label}${pass ? "" : ` :: ${detail}`}`); };
async function signUp(email) {
  const r = await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake`, {
    method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ email, password: " pass with spaces ", returnSecureToken: true }),
  }).then((x) => x.json());
  return { uid: r.localId, token: r.idToken };
}
async function call(token, data) {
  const res = await fetch(`${FN}/submitRiderApplication`, { method: "POST",
    headers: { "content-type": "application/json", ...(token ? { authorization: `Bearer ${token}` } : {}) }, body: JSON.stringify({ data }) });
  const j = await res.json().catch(() => ({}));
  return { status: res.status, result: j.result, error: j.error };
}
const good = { name: "Ravi Kumar", phone: "9876543210", vehicleType: "bike", vehicleNumber: "TN58AB1234",
  licenseNumber: "TN5820200001234", aadhaarNumber: "234567890123", address: "12 Main Road", city: "Madurai", pincode: "625020" };
const JPEG = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0, 16, 0x4a, 0x46, 0x49, 0x46, 0, 1, 0xff, 0xd9]);

async function main() {
  console.log("=== PHASE DLV-A1 — rider application over HTTP ===");
  const anon = await call(null, good);
  record("h01_signed_out_refused", anon.status === 401, JSON.stringify(anon));
  const me = await signUp("dlva1-rider@preview.test");
  const early = await call(me.token, good);
  record("h02_no_photos_yet_refused_documents", early.error?.status === "INVALID_ARGUMENT" && early.error?.details?.reason === "documents" &&
    early.error.details.problems.length === 4, JSON.stringify(early));
  const bucket = admin.storage().bucket();
  for (const d of ["aadhaarFront", "aadhaarBack", "selfie", "license"]) {
    await bucket.file(`delivery_documents/${me.uid}/${d}`).save(JPEG, { contentType: "image/jpeg" });
  }
  const ok = await call(me.token, good);
  const p = (await db.doc(`delivery_partners/${me.uid}`).get()).data();
  const u = (await db.doc(`users/${me.uid}`).get()).data();
  record("h03_submitted_pending_with_paths", ok.result?.status === "pending" && p.status === "pending" &&
    p.kycDocuments.selfie === `delivery_documents/${me.uid}/selfie` && u.name === "Ravi Kumar" && u.role === "delivery_partner" && u.email === "dlva1-rider@preview.test",
    JSON.stringify({ ok, u }));
  const again = await call(me.token, good);
  record("h04_retry_same_single_record", again.result?.resubmitted === true && (await db.collection("delivery_partners").get()).size === 1, JSON.stringify(again));
  await db.doc(`delivery_partners/${me.uid}`).update({ status: "approved" });
  const late = await call(me.token, good);
  record("h05_approved_rider_cannot_resubmit", late.error?.details?.reason === "already_registered" &&
    (await db.doc(`delivery_partners/${me.uid}`).get()).data().status === "approved", JSON.stringify(late));

  const failed = results.filter((x) => !x).length;
  console.log(`\n${results.length - failed}/${results.length} passed`);
  if (failed) { console.log("PHASE DLV-A1 http: FAILED"); process.exit(1); }
  console.log("PHASE DLV-A1 http: ALL PASSED"); process.exit(0);
}
main().catch((e) => { console.error(e); process.exit(1); });
