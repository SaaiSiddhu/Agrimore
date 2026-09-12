// Phase ONBOARD-1 — proves two things against real engines, never a passing
// compile alone:
//   A. firestore.rules: onboarding_handoffs/{code} is completely
//      client-inaccessible (allow read, write: if false) -- not even the
//      handoff's own owner or an admin, mirroring
//      phase49_scratch_card_claim_test.js's own rules-section pattern.
//   B. createOnboardingWebHandoff / redeemOnboardingWebHandoff, via
//      test.wrap() invoking the real exported handlers with a constructed
//      CallableRequest -- the established pattern for onCall callables in
//      this codebase (mirrors phase49's own call() helper exactly).
//
// Run with:
//   firebase emulators:exec --only firestore,functions,auth \
//     "node scripts/phase51_onboarding_web_handoff_test.js"
// Requires: functions already built (npm run build).
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails } = require("@firebase/rules-unit-testing");

function unprivilegedClaims(email) {
  return {
    email,
    role: "user",
    admin: false,
    seller: false,
    sellerApproved: false,
    delivery_partner: false,
    deliveryApproved: false,
    employee: false,
    employeeApproved: false,
  };
}

function adminClaims(email) {
  return { ...unprivilegedClaims(email), role: "admin", admin: true };
}

// ============================================================
// SECTION A — firestore.rules: onboarding_handoffs is Admin-SDK-only
// ============================================================
async function runRulesSection() {
  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
  const testEnv = await initializeTestEnvironment({
    projectId: "agrimore-66a4e",
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });

  const results = {};
  const record = (k, p) => p.then(
    () => { results[k] = "PASSED"; console.log(`${k}: PASSED`); },
    (e) => { results[k] = `FAILED — ${e.message}`; console.log(`${k}: FAILED — ${e.message}`); }
  );

  try {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("onboarding_handoffs").doc("p51-code").set({
        uid: "p51-owner", purpose: "associate_onboarding", used: false,
      });
    });
    const ownerDb = testEnv.authenticatedContext("p51-owner", unprivilegedClaims("owner@phase51-test.example")).firestore();
    const strangerDb = testEnv.authenticatedContext("p51-stranger", unprivilegedClaims("stranger@phase51-test.example")).firestore();
    const adminDb = testEnv.authenticatedContext("p51-admin", adminClaims("admin@phase51-test.example")).firestore();
    const unauthDb = testEnv.unauthenticatedContext().firestore();

    await record("w1a_unauthenticated_cannot_read",
      assertFails(unauthDb.collection("onboarding_handoffs").doc("p51-code").get()));
    await record("w1b_owner_cannot_read_their_own_handoff",
      assertFails(ownerDb.collection("onboarding_handoffs").doc("p51-code").get()));
    await record("w1c_stranger_cannot_read_someone_elses_handoff",
      assertFails(strangerDb.collection("onboarding_handoffs").doc("p51-code").get()));
    await record("w1d_even_admin_cannot_read_a_handoff",
      assertFails(adminDb.collection("onboarding_handoffs").doc("p51-code").get()));
    await record("w1e_owner_cannot_create_a_handoff_directly",
      assertFails(ownerDb.collection("onboarding_handoffs").doc("p51-forged").set({ uid: "p51-owner", used: false })));
    await record("w1f_owner_cannot_mark_their_own_handoff_used",
      assertFails(ownerDb.collection("onboarding_handoffs").doc("p51-code").update({ used: true })));

    console.log("\n=== PHASE 51 SECTION A (rules) SUMMARY ===");
    const total = Object.keys(results).length;
    const passed = Object.values(results).filter((v) => v === "PASSED").length;
    for (const [k, v] of Object.entries(results)) console.log(`  ${v === "PASSED" ? "PASS" : "FAIL"}  ${k}`);
    console.log(`\n${passed}/${total} scenarios passed`);
    return passed === total;
  } finally {
    await testEnv.cleanup();
  }
}

// ============================================================
// SECTION B — createOnboardingWebHandoff / redeemOnboardingWebHandoff
// (genuine handler invocation)
// ============================================================
async function runFunctionSection() {
  const admin = require("firebase-admin");
  admin.initializeApp({ projectId: "agrimore-66a4e" });
  const db = admin.firestore();

  const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
  const { createOnboardingWebHandoff, redeemOnboardingWebHandoff } = require("../lib/employee/onboardingWebHandoff");
  const wrappedCreate = test.wrap(createOnboardingWebHandoff);
  const wrappedRedeem = test.wrap(redeemOnboardingWebHandoff);

  async function call(wrapped, payload, auth) {
    try {
      return { ok: true, result: await wrapped({ data: payload, auth }) };
    } catch (e) {
      return { ok: false, code: e.code, message: e.message };
    }
  }

  function decodeCustomTokenUid(token) {
    const payload = JSON.parse(Buffer.from(token.split(".")[1], "base64").toString("utf8"));
    return payload.uid;
  }

  let failures = 0;
  function check(label, cond, extra) {
    if (cond) {
      console.log(`PASS  ${label}`);
    } else {
      failures += 1;
      console.log(`FAIL  ${label}`, extra !== undefined ? JSON.stringify(extra) : "");
    }
  }

  const uid = "p51f-owner";

  // s1: createOnboardingWebHandoff refuses an unauthenticated caller, no
  // document is created.
  const rUnauth = await call(wrappedCreate, {}, undefined);
  check("s1_create_unauthenticated_refused", !rUnauth.ok && rUnauth.code === "unauthenticated", rUnauth);

  // s2: a real, authenticated create — mints a code and a matching document.
  const rCreate = await call(wrappedCreate, {}, { uid, token: {} });
  check("s2_create_succeeds_with_a_code", rCreate.ok && typeof rCreate.result.code === "string" && rCreate.result.code.length >= 32, rCreate);
  const code = rCreate.result.code;

  const docAfterCreate = await db.collection("onboarding_handoffs").doc(code).get();
  const dataAfterCreate = docAfterCreate.data();
  check("s2b_document_created_with_correct_uid_and_unused",
    docAfterCreate.exists && dataAfterCreate.uid === uid && dataAfterCreate.used === false, dataAfterCreate);
  check("s2c_expiresAt_is_in_the_future",
    dataAfterCreate.expiresAt && dataAfterCreate.expiresAt.toMillis() > Date.now(), dataAfterCreate.expiresAt);

  // s3: redeemOnboardingWebHandoff refuses a missing code.
  const rNoCode = await call(wrappedRedeem, {}, undefined);
  check("s3_redeem_missing_code_refused", !rNoCode.ok && rNoCode.code === "invalid-argument", rNoCode);

  // s4: redeemOnboardingWebHandoff refuses a nonexistent code. Deliberately
  // called WITHOUT auth -- redemption itself is how a signed-OUT web visitor
  // bootstraps a session, so it must work unauthenticated.
  const rNotFound = await call(wrappedRedeem, { code: "p51f-does-not-exist" }, undefined);
  check("s4_redeem_nonexistent_code_refused", !rNotFound.ok && rNotFound.code === "not-found", rNotFound);

  // s5: the real redemption -- a valid, unexpired, unused code succeeds and
  // returns a custom token for the CORRECT uid.
  const rRedeem = await call(wrappedRedeem, { code }, undefined);
  check("s5_redeem_succeeds", rRedeem.ok && typeof rRedeem.result.customToken === "string", rRedeem);
  check("s5b_custom_token_embeds_the_correct_uid",
    rRedeem.ok && decodeCustomTokenUid(rRedeem.result.customToken) === uid, rRedeem.ok ? decodeCustomTokenUid(rRedeem.result.customToken) : rRedeem);

  const docAfterRedeem = await db.collection("onboarding_handoffs").doc(code).get();
  check("s5c_document_marked_used", docAfterRedeem.data()?.used === true, docAfterRedeem.data());

  // s6: THE HIGHEST-STAKES SCENARIO — redeeming the SAME code a second time
  // must never succeed. This is the exact property a check-then-act (no
  // transaction) implementation would fail under a page reload firing the
  // callable twice.
  const rReRedeem = await call(wrappedRedeem, { code }, undefined);
  check("s6_reredeem_refused_not_a_second_token", !rReRedeem.ok && rReRedeem.code === "failed-precondition", rReRedeem);

  // s7: an expired-but-unused code is refused, distinctly from "already used".
  const expiredCode = "p51f-expired-code";
  await db.collection("onboarding_handoffs").doc(expiredCode).set({
    uid, purpose: "associate_onboarding", used: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() - 1000),
  });
  const rExpired = await call(wrappedRedeem, { code: expiredCode }, undefined);
  check("s7_expired_code_refused", !rExpired.ok && rExpired.code === "deadline-exceeded", rExpired);

  return failures === 0;
}

async function main() {
  const rulesPassed = await runRulesSection();
  const functionPassed = await runFunctionSection();

  console.log(`\n=== PHASE 51 OVERALL: ${rulesPassed && functionPassed ? "ALL PASSED" : "FAILED"} ===`);
  process.exit(rulesPassed && functionPassed ? 0 : 1);
}

main().catch((error) => {
  console.error("PHASE 51: harness error", error);
  process.exit(1);
});
