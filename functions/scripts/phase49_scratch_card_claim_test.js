// Phase FIX-N50 (finding N-50) — proves two things against real engines,
// never a passing compile alone:
//   A. the new firestore.rules walletBalance coverage on users/{userId}
//      (both the update-time and create-time counterparts), via
//      @firebase/rules-unit-testing (mirrors phase31_collection_coverage_test.js's
//      pattern exactly).
//   B. the new claimScratchCard callable, via test.wrap() invoking the real
//      exported handler with a constructed CallableRequest — the established
//      pattern for onCall callables in this codebase (mirrors
//      phase45_seller_ai_funding_test.js's own call() helper exactly). Unlike
//      a Firestore trigger, an onCall handler has no event-dispatch layer to
//      bypass, so wrap() here exercises the real auth check, the real
//      transaction, and the real Firestore reads/writes.
//
// Run with:
//   firebase emulators:exec --only firestore,functions,auth \
//     "node scripts/phase49_scratch_card_claim_test.js"
// Requires: functions already built (npm run build).
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");

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

// ============================================================
// SECTION A — firestore.rules: users/{userId}.walletBalance coverage
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
      await ctx.firestore().collection("users").doc("p49-owner").set({ role: "user", name: "Phase49 Owner", walletBalance: 0 });
    });
    const ownerDb = testEnv.authenticatedContext("p49-owner", unprivilegedClaims("owner@phase49-test.example")).firestore();
    const strangerDb = testEnv.authenticatedContext("p49-stranger", unprivilegedClaims("stranger@phase49-test.example")).firestore();

    await record("w1a_negative_owner_cannot_update_own_walletBalance",
      assertFails(ownerDb.collection("users").doc("p49-owner").update({ walletBalance: 999999 })));
    await record("w1b_positive_owner_can_still_update_an_unrelated_field",
      assertSucceeds(ownerDb.collection("users").doc("p49-owner").update({ name: "Updated Name" })));
    await record("w1c_negative_stranger_cannot_update_someone_elses_walletBalance",
      assertFails(strangerDb.collection("users").doc("p49-owner").update({ walletBalance: 1 })));
    await record("w1d_negative_self_registering_user_cannot_create_with_nonzero_walletBalance",
      assertFails(strangerDb.collection("users").doc("p49-stranger").set({ role: "user", walletBalance: 500 })));
    await record("w1e_positive_self_registering_user_can_create_with_walletBalance_zero",
      assertSucceeds(strangerDb.collection("users").doc("p49-stranger").set({ role: "user", walletBalance: 0 })));

    console.log("\n=== PHASE 49 SECTION A (rules) SUMMARY ===");
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
// SECTION B — claimScratchCard callable (genuine handler invocation)
// ============================================================
async function runFunctionSection() {
  const admin = require("firebase-admin");
  admin.initializeApp({ projectId: "agrimore-66a4e" });
  const db = admin.firestore();

  const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
  const { claimScratchCard } = require("../lib/customer/claimScratchCard");
  const wrapped = test.wrap(claimScratchCard);

  async function call(payload, auth) {
    try {
      return { ok: true, result: await wrapped({ data: payload, auth }) };
    } catch (e) {
      return { ok: false, code: e.code, message: e.message };
    }
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

  const uid = "p49f-owner";
  const cardId = "p49f-card1";

  await db.collection("users").doc(uid).set({ role: "user", walletBalance: 0 });
  await db.collection("users").doc(uid).collection("scratchCards").doc(cardId).set({
    amount: 75, isScratched: false,
  });

  // s1: unauthenticated call is refused, nothing is written.
  const rUnauth = await call({ cardId }, undefined);
  check("s1_unauthenticated_call_refused", !rUnauth.ok && rUnauth.code === "unauthenticated", rUnauth);

  // s2: missing cardId is refused.
  const rNoCardId = await call({}, { uid, token: {} });
  check("s2_missing_cardId_refused", !rNoCardId.ok && rNoCardId.code === "invalid-argument", rNoCardId);

  // s3: nonexistent card is refused.
  const rNotFound = await call({ cardId: "p49f-does-not-exist" }, { uid, token: {} });
  check("s3_nonexistent_card_refused", !rNotFound.ok && rNotFound.code === "not-found", rNotFound);

  // s4: the real claim — card marked scratched, walletBalance credited by
  // exactly the card's own amount, a transaction logged.
  const rClaim = await call({ cardId }, { uid, token: {} });
  check("s4_claim_succeeds_with_correct_amount", rClaim.ok && rClaim.result.alreadyClaimed === false && rClaim.result.amount === 75, rClaim);

  const cardAfter = await db.collection("users").doc(uid).collection("scratchCards").doc(cardId).get();
  check("s4b_card_marked_scratched", cardAfter.data()?.isScratched === true, cardAfter.data());

  const userAfterClaim = await db.collection("users").doc(uid).get();
  check("s4c_walletBalance_credited_by_exactly_the_card_amount", userAfterClaim.data()?.walletBalance === 75, userAfterClaim.data());

  const txSnap = await db.collection("users").doc(uid).collection("transactions")
    .where("amount", "==", 75).where("type", "==", "credit").get();
  check("s4d_transaction_logged", !txSnap.empty, txSnap.docs.map((d) => d.data()));

  // s5: THE HIGHEST-STAKES SCENARIO — re-claiming the same now-scratched
  // card must never credit twice. This is the exact class of bug the old
  // client-side flow (three separate, non-transactional writes, no
  // already-claimed check at all) had no guard against.
  const rReclaim = await call({ cardId }, { uid, token: {} });
  check("s5_reclaim_reports_alreadyClaimed_not_a_second_credit", rReclaim.ok && rReclaim.result.alreadyClaimed === true && rReclaim.result.amount === 0, rReclaim);

  const userAfterReclaim = await db.collection("users").doc(uid).get();
  check("s5b_walletBalance_unchanged_after_reclaim_attempt", userAfterReclaim.data()?.walletBalance === 75, userAfterReclaim.data());

  return failures === 0;
}

async function main() {
  const rulesPassed = await runRulesSection();
  const functionPassed = await runFunctionSection();

  console.log(`\n=== PHASE 49 OVERALL: ${rulesPassed && functionPassed ? "ALL PASSED" : "FAILED"} ===`);
  process.exit(rulesPassed && functionPassed ? 0 : 1);
}

main().catch((error) => {
  console.error("PHASE 49: harness error", error);
  process.exit(1);
});
