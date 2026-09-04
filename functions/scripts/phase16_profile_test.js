// Phase 16, Workstream 4 — proves completeUserProfile.ts against a real
// emulator. Pure Firestore logic (never touches admin.auth()), so unlike
// several other Phase 16 tests, no Auth-emulator caveat applies here — every
// scenario below is a full, unqualified pass/fail.
// completeUserProfile is a v2 onCall, wrapped and invoked as
// `wrapped({ data: payload, auth })`.
// Run with: node scripts/phase16_profile_test.js
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { completeUserProfile } = require("../lib/customer/completeUserProfile");

const wrapped = test.wrap(completeUserProfile);

async function callAndCapture(payload, auth) {
  try {
    const result = await wrapped({ data: payload, auth });
    return { ok: true, result };
  } catch (e) {
    return { ok: false, code: e.code, message: e.message };
  }
}

function validPayload(overrides = {}) {
  return {
    name: "Test User",
    email: "phase16-profile-test@example.com",
    dateOfBirth: "1995-06-15",
    gender: "male",
    ...overrides,
  };
}

async function seedVerifiedEmail(db, email, uid) {
  await db.collection("otp_codes").doc(email).set({
    otpHash: "seed",
    email,
    expiresAt: Date.now() + 5 * 60 * 1000,
    createdAt: Date.now(),
    verified: true,
    verifiedAt: Date.now(),
    verifiedByUid: uid,
    attempts: 0,
  });
}

async function main() {
  const db = admin.firestore();
  let allPassed = true;
  const results = {};

  console.log("=== PHASE 16, WORKSTREAM 4 — completeUserProfile ===");

  // Scenario 1: invalid name rejected
  {
    const uid = "phase16-cup-invalid-name";
    await db.collection("users").doc(uid).set({ role: "user" });
    const r = await callAndCapture(validPayload({ name: "X" }), { uid, token: {} });
    const s = !r.ok && r.code === "invalid-argument";
    results.scenario1_invalid_name_rejected = s;
    console.log(`Scenario 1: ${s ? "PASSED" : "FAILED"} — code=${r.code} message="${r.message}"`);
    if (!s) allPassed = false;
  }

  // Scenario 2: invalid email rejected
  {
    const uid = "phase16-cup-invalid-email";
    await db.collection("users").doc(uid).set({ role: "user" });
    const r = await callAndCapture(validPayload({ email: "not-an-email" }), { uid, token: {} });
    const s = !r.ok && r.code === "invalid-argument";
    results.scenario2_invalid_email_rejected = s;
    console.log(`Scenario 2: ${s ? "PASSED" : "FAILED"} — code=${r.code} message="${r.message}"`);
    if (!s) allPassed = false;
  }

  // Scenario 3: future date of birth rejected
  {
    const uid = "phase16-cup-future-dob";
    await db.collection("users").doc(uid).set({ role: "user" });
    const futureDob = new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString();
    const r = await callAndCapture(validPayload({ dateOfBirth: futureDob }), { uid, token: {} });
    const s = !r.ok && r.code === "invalid-argument";
    results.scenario3_future_dob_rejected = s;
    console.log(`Scenario 3: ${s ? "PASSED" : "FAILED"} — code=${r.code} message="${r.message}"`);
    if (!s) allPassed = false;
  }

  // Scenario 4: underage rejected
  {
    const uid = "phase16-cup-underage";
    await db.collection("users").doc(uid).set({ role: "user" });
    const teenDob = new Date(Date.now() - 10 * 365 * 24 * 60 * 60 * 1000).toISOString();
    const r = await callAndCapture(validPayload({ dateOfBirth: teenDob }), { uid, token: {} });
    const s = !r.ok && r.code === "failed-precondition";
    results.scenario4_underage_rejected = s;
    console.log(`Scenario 4: ${s ? "PASSED" : "FAILED"} — code=${r.code} message="${r.message}"`);
    if (!s) allPassed = false;
  }

  // Scenario 5: invalid gender rejected
  {
    const uid = "phase16-cup-invalid-gender";
    await db.collection("users").doc(uid).set({ role: "user" });
    const r = await callAndCapture(validPayload({ gender: "robot" }), { uid, token: {} });
    const s = !r.ok && r.code === "invalid-argument";
    results.scenario5_invalid_gender_rejected = s;
    console.log(`Scenario 5: ${s ? "PASSED" : "FAILED"} — code=${r.code} message="${r.message}"`);
    if (!s) allPassed = false;
  }

  // Scenario 6 — THE new-user-must-verify proof: a brand new phone-first
  // user (empty email on file, matching verifyPhoneOTP.ts's real create
  // shape) submits a never-verified email and is rejected.
  {
    const uid = "phase16-cup-unverified-email";
    await db.collection("users").doc(uid).set({ role: "user", email: "", phone: "+919876500010" });
    const payload = validPayload({ email: "phase16-cup-unverified@example.com" });
    const r = await callAndCapture(payload, { uid, token: {} });
    const s = !r.ok && r.code === "failed-precondition" && r.message.toLowerCase().includes("verify");
    results.scenario6_new_user_must_verify_email = s;
    console.log(`Scenario 6: ${s ? "PASSED" : "FAILED"} — code=${r.code} message="${r.message}"`);
    if (!s) allPassed = false;
  }

  // Scenario 7: after verifying, the same submission succeeds
  {
    const uid = "phase16-cup-verified-success";
    const email = "phase16-cup-verified-success@example.com";
    await db.collection("users").doc(uid).set({ role: "user", email: "", phone: "+919876500011" });
    await seedVerifiedEmail(db, email, uid);

    const r = await callAndCapture(validPayload({ email }), { uid, token: {} });
    const userDoc = await db.collection("users").doc(uid).get();
    const s =
      r.ok &&
      r.result.success === true &&
      r.result.alreadyComplete === false &&
      userDoc.data()?.profileCompleted === true &&
      userDoc.data()?.email === email &&
      userDoc.data()?.emailVerified === true &&
      userDoc.data()?.gender === "male";
    results.scenario7_valid_submission_completes_profile = s;
    console.log(`Scenario 7: ${s ? "PASSED" : "FAILED"} — result=${JSON.stringify(r)} userDoc.profileCompleted=${userDoc.data()?.profileCompleted}`);
    if (!s) allPassed = false;
  }

  // Scenario 8: duplicate email (belongs to a different uid) rejected
  {
    const existingUid = "phase16-cup-dup-owner";
    const newUid = "phase16-cup-dup-claimant";
    const dupEmail = "phase16-cup-duplicate@example.com";
    await db.collection("users").doc(existingUid).set({ role: "user", email: dupEmail, profileCompleted: true });
    await db.collection("users").doc(newUid).set({ role: "user", email: "" });
    await seedVerifiedEmail(db, dupEmail, newUid);

    const r = await callAndCapture(validPayload({ email: dupEmail }), { uid: newUid, token: {} });
    const s = !r.ok && r.code === "already-exists";
    results.scenario8_duplicate_email_rejected = s;
    console.log(`Scenario 8: ${s ? "PASSED" : "FAILED"} — code=${r.code} message="${r.message}"`);
    if (!s) allPassed = false;
  }

  // Scenario 9: idempotent re-call on an already-complete profile
  {
    const uid = "phase16-cup-idempotent";
    await db.collection("users").doc(uid).set({
      role: "user",
      email: "phase16-cup-idempotent@example.com",
      profileCompleted: true,
    });
    const r = await callAndCapture(validPayload({ email: "phase16-cup-idempotent@example.com" }), {
      uid,
      token: {},
    });
    const s = r.ok && r.result.alreadyComplete === true;
    results.scenario9_idempotent_recall = s;
    console.log(`Scenario 9: ${s ? "PASSED" : "FAILED"} — result=${JSON.stringify(r)}`);
    if (!s) allPassed = false;
  }

  // Scenario 10: resubmitting the SAME email already on file needs no
  // fresh verification (existing-user exemption).
  {
    const uid = "phase16-cup-resubmit-known-email";
    const email = "phase16-cup-resubmit-known@example.com";
    await db.collection("users").doc(uid).set({ role: "user", email, phone: "+919876500012" });
    // Deliberately NOT seeding otp_codes/{email} as verified — this is the
    // exact case the exemption must cover.
    const r = await callAndCapture(validPayload({ email }), { uid, token: {} });
    const s = r.ok && r.result.success === true;
    results.scenario10_resubmit_known_email_no_verification_needed = s;
    console.log(`Scenario 10: ${s ? "PASSED" : "FAILED"} — result=${JSON.stringify(r)}`);
    if (!s) allPassed = false;
  }

  // Scenario 11: the callable operates ONLY on the caller's own uid — an
  // extraneous userId in the payload has zero effect.
  {
    const callerUid = "phase16-cup-self-only-caller";
    const victimUid = "phase16-cup-self-only-victim";
    const callerEmail = "phase16-cup-self-only-caller@example.com";
    await db.collection("users").doc(callerUid).set({ role: "user", email: "", phone: "+919876500013" });
    await db.collection("users").doc(victimUid).set({ role: "user", email: "victim@example.com" });
    await seedVerifiedEmail(db, callerEmail, callerUid);

    const r = await callAndCapture(
      validPayload({ email: callerEmail, userId: victimUid, uid: victimUid }),
      { uid: callerUid, token: {} }
    );
    const callerDoc = await db.collection("users").doc(callerUid).get();
    const victimDoc = await db.collection("users").doc(victimUid).get();
    const s =
      r.ok &&
      callerDoc.data()?.profileCompleted === true &&
      victimDoc.data()?.profileCompleted !== true &&
      victimDoc.data()?.email === "victim@example.com";
    results.scenario11_operates_only_on_caller_uid = s;
    console.log(`Scenario 11: ${s ? "PASSED" : "FAILED"} — callerCompleted=${callerDoc.data()?.profileCompleted} victimCompleted=${victimDoc.data()?.profileCompleted}`);
    if (!s) allPassed = false;
  }

  console.log("");
  console.log(allPassed ? "ALL PASSED" : "SOME FAILED");
  console.log(JSON.stringify(results, null, 2));
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phase16 profile test:", e);
  process.exit(1);
});
