// ============================================================
//  Phase ADMR-76 — authenticated evidence delivery (viewSupportCaseEvidence)
// ============================================================
//
// Real HTTP against the real functions+auth+firestore+storage emulators
// (mirrors phaseDLVE1_http_test.js's own established convention -- this is
// an onRequest function, not a Callable, so there is no `.run()` bypass;
// genuine HTTP is the only way to exercise the real Authorization-header
// path end to end).
//
// e01 authorized admin, fresh token -> 200, correct bytes and content-type
// e02 missing Authorization header -> 401
// e03 garbage/invalid token -> 401
// e04 valid token, non-admin -> 403
// e05 unknown evidenceId -> 404
// e06 object deleted from Storage after finalize -> 410 object_missing
// e07 live object's generation differs from the recorded one (simulates a
//     privileged Admin-SDK/console tamper) -> 409 integrity_mismatch,
//     never silently served
// e08 a demoted admin's still-unexpired token is rejected LIVE via
//     verifyIdToken's own checkRevoked, not just at its natural 1h expiry --
//     a property no Storage download token could ever offer
//
// Run with: JAVA_HOME=/opt/homebrew/opt/openjdk@21 firebase emulators:exec
//   --only firestore,auth,functions,storage --project demo-agrimore-admr76
//   "node scripts/phaseADMR76_evidence_delivery_test.js"

process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
process.env.FIREBASE_AUTH_EMULATOR_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || "127.0.0.1:9099";
process.env.FIREBASE_STORAGE_EMULATOR_HOST = process.env.FIREBASE_STORAGE_EMULATOR_HOST || "127.0.0.1:9199";
process.env.STORAGE_EMULATOR_HOST = process.env.STORAGE_EMULATOR_HOST || `http://${process.env.FIREBASE_STORAGE_EMULATOR_HOST}`;

const { PROJECT_ID, STORAGE_BUCKET } = require("./lib/emulatorEnv");
const PROJECT = process.env.GCLOUD_PROJECT || PROJECT_ID;
if (!PROJECT.startsWith("demo-") && PROJECT !== PROJECT_ID) {
  console.error(`REFUSING: unexpected project ${PROJECT}`);
  process.exit(2);
}
const RUN_PROJECT = PROJECT.startsWith("demo-") ? PROJECT : PROJECT_ID;
const FN = `http://127.0.0.1:${process.env.FUNCTIONS_PORT || 5001}/${RUN_PROJECT}/us-central1`;

const admin = require("firebase-admin");
if (!admin.apps.length) admin.initializeApp({ projectId: RUN_PROJECT, storageBucket: STORAGE_BUCKET });
const db = admin.firestore();
const { Timestamp } = require("firebase-admin/firestore");

const PW = "admr76-pass-1"; // emulator-only test account
const results = [];
const record = (label, pass, detail) => {
  results.push(pass);
  console.log(`${pass ? "PASSED" : "FAILED"} — ${label}${pass ? "" : ` :: ${detail}`}`);
};

async function account(email, claims) {
  let u;
  try {
    u = await admin.auth().getUserByEmail(email);
  } catch {
    u = await admin.auth().createUser({ email, password: PW });
  }
  if (claims) await admin.auth().setCustomUserClaims(u.uid, claims);
  const t = await fetch(
    `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake`,
    { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ email, password: PW, returnSecureToken: true }) }
  ).then((r) => r.json());
  return { uid: u.uid, idToken: t.idToken };
}

async function view(evidenceId, token) {
  const headers = token ? { authorization: `Bearer ${token}` } : {};
  const res = await fetch(`${FN}/viewSupportCaseEvidence?evidenceId=${encodeURIComponent(evidenceId)}`, { headers });
  const contentType = res.headers.get("content-type");
  let body;
  if (contentType && contentType.startsWith("application/json")) {
    body = await res.json();
  } else {
    body = Buffer.from(await res.arrayBuffer());
  }
  return { status: res.status, contentType, body };
}

async function seedEvidence(caseId, evidenceId, adminUid, bytes, contentType) {
  const path = `support_case_evidence/${caseId}/${adminUid}_req-${evidenceId}`;
  await admin.storage().bucket().file(path).save(bytes, { contentType });
  const [meta] = await admin.storage().bucket().file(path).getMetadata();
  await db.doc(`support_case_evidence/${evidenceId}`).set({
    evidenceId, caseId, storagePath: path, size: bytes.length, contentType,
    generation: String(meta.generation), md5Hash: meta.md5Hash,
    originalFileName: "evidence.png", uploadedBy: adminUid, uploadedAt: Timestamp.now(),
  });
  return path;
}

async function main() {
  const boss = await account("admr76-admin@preview.test", { admin: true, role: "admin" });
  await db.doc(`users/${boss.uid}`).set({ role: "admin" });
  const cust = await account("admr76-cust@preview.test", {});
  await db.doc(`users/${cust.uid}`).set({ role: "user" });

  const PNG = Buffer.from("iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAEElEQVR4nGP4z8AARwzEcQCukw/x0F8jngAAAABJRU5ErkJggg==", "base64");

  // e01
  const path1 = await seedEvidence("case-1", "case-1_ev1", boss.uid, PNG, "image/png");
  const r1 = await view("case-1_ev1", boss.idToken);
  record("e01_authorized_admin_fresh_token_gets_correct_bytes", r1.status === 200 && Buffer.isBuffer(r1.body) && r1.body.equals(PNG) && r1.contentType === "image/png", JSON.stringify({ status: r1.status, contentType: r1.contentType }));

  // e02
  const r2 = await view("case-1_ev1", null);
  record("e02_missing_authorization_header", r2.status === 401 && r2.body.error === "missing_token", JSON.stringify(r2.body));

  // e03
  const r3 = await view("case-1_ev1", "not-a-real-token");
  record("e03_garbage_token", r3.status === 401 && r3.body.error === "invalid_token", JSON.stringify(r3.body));

  // e04
  const r4 = await view("case-1_ev1", cust.idToken);
  record("e04_non_admin_refused", r4.status === 403 && r4.body.error === "not_admin", JSON.stringify(r4.body));

  // e05
  const r5 = await view("case-does-not-exist_ev-missing", boss.idToken);
  record("e05_unknown_evidence_id", r5.status === 404 && r5.body.error === "not_found", JSON.stringify(r5.body));

  // e06
  const path6 = await seedEvidence("case-1", "case-1_ev6", boss.uid, PNG, "image/png");
  await admin.storage().bucket().file(path6).delete();
  const r6 = await view("case-1_ev6", boss.idToken);
  record("e06_object_deleted_after_finalize", r6.status === 410 && r6.body.error === "object_missing", JSON.stringify(r6.body));

  // e07
  const path7 = await seedEvidence("case-1", "case-1_ev7", boss.uid, PNG, "image/png");
  const DIFFERENT_BYTES = Buffer.concat([PNG, Buffer.from([0, 0, 0, 0])]);
  await admin.storage().bucket().file(path7).save(DIFFERENT_BYTES, { contentType: "image/png" }); // simulates a privileged tamper
  const r7 = await view("case-1_ev7", boss.idToken);
  record("e07_live_generation_mismatch_refused_not_silently_served", r7.status === 409 && r7.body.error === "integrity_mismatch", JSON.stringify(r7.body));

  // e08
  const demoted = await account("admr76-demoted@preview.test", { admin: true, role: "admin" });
  await db.doc(`users/${demoted.uid}`).set({ role: "admin" });
  await seedEvidence("case-1", "case-1_ev8", demoted.uid, PNG, "image/png");
  const preRevoke = await view("case-1_ev8", demoted.idToken);
  // Revocation compares the token's own issued-at second against a
  // validSince timestamp of the same granularity -- revoking in the exact
  // same second the token was issued is a genuine race with no real
  // significance (a real caller's token is always at least seconds old by
  // the time an admin is demoted); wait past that second boundary so this
  // scenario tests the real property, not clock-rounding luck.
  await new Promise((r) => setTimeout(r, 1100));
  await admin.auth().revokeRefreshTokens(demoted.uid);
  const postRevoke = await view("case-1_ev8", demoted.idToken); // SAME still-unexpired token
  record(
    "e08_revoked_admin_token_rejected_live_not_just_at_natural_expiry",
    preRevoke.status === 200 && postRevoke.status === 401,
    JSON.stringify({ preRevoke: preRevoke.status, postRevoke: postRevoke.status, postBody: postRevoke.body })
  );

  const failed = results.filter((x) => !x).length;
  console.log(`\n${results.length - failed}/${results.length} passed`);
  process.exit(failed ? 1 : 0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
