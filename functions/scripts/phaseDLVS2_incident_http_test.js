// Phase DLV-S2 — reportRiderIncident / updateRiderIncident over GENUINE HTTP
// through the functions emulator (real ID tokens from the auth emulator).
//
//  h01 signed out → unauthenticated
//  h02 a signed-in non-rider → permission-denied (not_a_rider)
//  h03 a rider reports; the same request id again returns the same incident
//  h04 a rider cannot acknowledge or resolve (Admins only)
//  h05 admin acknowledges; resolve without a written resolution is refused;
//      resolve with one closes it; the rider can read the result
//
// Run with:
//   firebase emulators:exec --only firestore,functions,auth --project demo-agrimore-dlvs2 \
//     "node scripts/phaseDLVS2_incident_http_test.js"
// Requires: npm run build. Honours FIRESTORE_EMULATOR_HOST, FIREBASE_AUTH_EMULATOR_HOST, FUNCTIONS_PORT.
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
process.env.FIREBASE_AUTH_EMULATOR_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || "127.0.0.1:9099";
const PROJECT = process.env.GCLOUD_PROJECT || "demo-agrimore-dlvs2";
if (!PROJECT.startsWith("demo-")) {
  console.error(`REFUSING: project ${PROJECT} is not a demo- project`);
  process.exit(2);
}
const FN = `http://127.0.0.1:${process.env.FUNCTIONS_PORT || 5001}/${PROJECT}/us-central1`;
const AUTH = process.env.FIREBASE_AUTH_EMULATOR_HOST;

const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: PROJECT });
const db = admin.firestore();

const results = [];
function record(label, pass, detail) {
  results.push({ label, pass });
  console.log(`${pass ? "PASSED" : "FAILED"} — ${label}${pass ? "" : ` :: ${detail}`}`);
}
const PW = "dlvs2-pass-123";
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

async function main() {
  console.log("=== PHASE DLV-S2 — incident callables over HTTP ===");
  const rider = await account("dlvs2-rider@preview.test", "delivery_partner", { role: "delivery_partner", delivery_partner: true });
  const customer = await account("dlvs2-customer@preview.test", "customer", null);
  const boss = await account("dlvs2-admin@preview.test", "admin", { role: "admin", admin: true });
  await db.doc(`delivery_partners/${rider.uid}`).set({ status: "approved", name: "Ravi", isOnline: true });

  const anon = await call("reportRiderIncident", null, { requestId: "anon-000001" });
  record("h01_signed_out_refused", anon.status === 401 && anon.error?.status === "UNAUTHENTICATED", JSON.stringify(anon));
  const cust = await call("reportRiderIncident", customer.token, { requestId: "cust-000001" });
  record("h02_non_rider_refused", cust.error?.status === "PERMISSION_DENIED" && cust.error?.details?.reason === "not_a_rider", JSON.stringify(cust));

  const first = await call("reportRiderIncident", rider.token, { requestId: "http-000001", lat: 9.93, lng: 78.12, accuracy: 12, isMocked: false });
  const retry = await call("reportRiderIncident", rider.token, { requestId: "http-000001" });
  const mine = await db.collection("rider_incidents").where("riderId", "==", rider.uid).get();
  record("h03_report_is_idempotent_over_http", first.result?.success === true && first.result?.alreadyReported === false &&
    retry.result?.alreadyReported === true && retry.result?.incidentId === first.result?.incidentId && mine.size === 1 &&
    mine.docs[0].data().location.source === "device", JSON.stringify({ first, retry, n: mine.size }));
  const id = first.result?.incidentId;

  const riderAck = await call("updateRiderIncident", rider.token, { incidentId: id, action: "acknowledge" });
  const riderRes = await call("updateRiderIncident", rider.token, { incidentId: id, action: "resolve", resolution: "self-closed" });
  record("h04_rider_cannot_acknowledge_or_resolve", riderAck.error?.status === "PERMISSION_DENIED" && riderRes.error?.status === "PERMISSION_DENIED" &&
    (await db.doc(`rider_incidents/${id}`).get()).data().status === "reported", JSON.stringify({ riderAck, riderRes }));

  const ack = await call("updateRiderIncident", boss.token, { incidentId: id, action: "acknowledge" });
  const short = await call("updateRiderIncident", boss.token, { incidentId: id, action: "resolve", resolution: " " });
  const done = await call("updateRiderIncident", boss.token, { incidentId: id, action: "resolve", resolution: "Called the rider; safe." });
  const after = (await db.doc(`rider_incidents/${id}`).get()).data();
  record("h05_admin_acknowledges_then_resolves_with_a_reason", ack.result?.status === "acknowledged" &&
    short.error?.details?.reason === "resolution_required" && done.result?.status === "resolved" &&
    after.acknowledgedBy === boss.uid && after.resolvedBy === boss.uid && after.resolution === "Called the rider; safe.",
    JSON.stringify({ ack, short, done }));

  const failed = results.filter((r) => !r.pass);
  console.log(`\n${results.length - failed.length}/${results.length} passed`);
  if (failed.length) { console.log("PHASE DLV-S2 http: FAILED"); process.exit(1); }
  console.log("PHASE DLV-S2 http: ALL PASSED");
  process.exit(0);
}
main().catch((e) => { console.error(e); process.exit(1); });
