// Phase 9, Workstream 3: proves the locked-down wallets rule against the
// real rules engine — a direct client update({balance: ...}) on the
// caller's OWN wallet doc must now be rejected (this exact write succeeded
// under the old `allow read, write: if isOwner(userId)` rule, which was
// finding #3 itself). Also proves the create-time zero-value constraint and
// the full delete block. Mirrors phase5b_rules_test.js's
// @firebase/rules-unit-testing pattern.
// Run with: node scripts/phase9_wallet_rules_test.js
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

// Phase FIX-N6F amendment (finding N-6F): referralCode changed from a
// fixed nonempty test value to '' — walletBalanceFieldsAreZero() now
// requires it to be exactly '' at create time (the real code is assigned
// server-side afterward by assignReferralCode), so a fixture asserting a
// LEGITIMATE create must match that contract, not the old one.
const ZERO_WALLET = {
  userId: "phase9-rules-user",
  balance: 0,
  coins: 0,
  lifetimeEarnings: 0,
  lifetimeSpent: 0,
  lifetimeCoinsEarned: 0,
  lifetimeCoinsUsed: 0,
  referralCode: "",
  referredBy: null,
  referralCount: 0,
  isActive: true,
  signupBonusCredited: false,
};

async function main() {
  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
  const testEnv = await initializeTestEnvironment({
    projectId: "agrimore-66a4e",
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });

  const results = {};

  try {
    // Scenario 1: creating a wallet doc at all-zero values succeeds (the
    // legitimate client bootstrap path, WalletModel.empty()'s exact shape).
    {
      const db = testEnv
        .authenticatedContext("phase9-rules-user", unprivilegedClaims("rules-user@phase9-test.example"))
        .firestore();
      try {
        await assertSucceeds(db.collection("wallets").doc("phase9-rules-user").set(ZERO_WALLET));
        results.scenario1_zero_value_create = "PASSED — creating a wallet doc with all balance-bearing fields at zero succeeded as expected";
      } catch (e) {
        results.scenario1_zero_value_create = `FAILED — legitimate zero-value wallet creation was rejected: ${e.message}`;
      }
    }

    // Scenario 2: creating a wallet doc with a nonzero balance is rejected
    // — this is finding #3's exploit, attempted at create time instead of
    // update time.
    {
      const db = testEnv
        .authenticatedContext("phase9-rules-attacker1", unprivilegedClaims("attacker1@phase9-test.example"))
        .firestore();
      try {
        await assertFails(
          db.collection("wallets").doc("phase9-rules-attacker1").set({
            ...ZERO_WALLET,
            userId: "phase9-rules-attacker1",
            balance: 999999,
          })
        );
        results.scenario2_nonzero_create_rejected = "PASSED — creating a wallet doc with a nonzero starting balance was rejected as expected";
      } catch (e) {
        results.scenario2_nonzero_create_rejected = `FAILED — a self-created wallet with a ₹999999 starting balance was NOT rejected: ${e.message} — THIS WOULD BE FINDING #3 STILL OPEN AT CREATE TIME`;
      }
    }

    // Scenario 3 — THE key proof: a direct client update({balance: ...})
    // on the caller's OWN wallet doc, exactly the write that was finding #3
    // itself, must now be rejected.
    {
      const uid = "phase9-rules-attacker2";
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection("wallets").doc(uid).set({ ...ZERO_WALLET, userId: uid });
      });
      const db = testEnv
        .authenticatedContext(uid, unprivilegedClaims("attacker2@phase9-test.example"))
        .firestore();
      try {
        await assertFails(
          db.collection("wallets").doc(uid).update({ balance: 999999, coins: 999999 })
        );
        results.scenario3_direct_balance_update_rejected =
          "PASSED — a direct client update({balance: 999999, coins: 999999}) on the caller's OWN wallet doc was rejected. This is the exact write pattern that was finding #3 before this phase.";
      } catch (e) {
        results.scenario3_direct_balance_update_rejected = `FAILED — the direct balance/coins self-credit update was NOT rejected: ${e.message} — FINDING #3 STILL OPEN`;
      }
    }

    // Scenario 4: updating a non-balance field (isActive) on the caller's
    // own wallet still succeeds — the lockdown is field-scoped, not a
    // blanket update ban.
    {
      const uid = "phase9-rules-user";
      const db = testEnv
        .authenticatedContext(uid, unprivilegedClaims("rules-user@phase9-test.example"))
        .firestore();
      try {
        await assertSucceeds(db.collection("wallets").doc(uid).update({ isActive: false }));
        results.scenario4_non_balance_update_succeeds = "PASSED — updating a non-balance field (isActive) on the caller's own wallet still succeeded";
      } catch (e) {
        results.scenario4_non_balance_update_succeeds = `FAILED — a harmless non-balance field update was incorrectly rejected: ${e.message}`;
      }
    }

    // Scenario 5: deleting the caller's own wallet doc is rejected — closes
    // the delete-then-reload signup-bonus-farming path.
    {
      const uid = "phase9-rules-user";
      const db = testEnv
        .authenticatedContext(uid, unprivilegedClaims("rules-user@phase9-test.example"))
        .firestore();
      try {
        await assertFails(db.collection("wallets").doc(uid).delete());
        results.scenario5_delete_rejected = "PASSED — deleting the caller's own wallet document was rejected as expected";
      } catch (e) {
        results.scenario5_delete_rejected = `FAILED — a client was able to delete their own wallet document: ${e.message} — THE SIGNUP-BONUS-FARMING PATH IS STILL OPEN`;
      }
    }

    // Scenario 6: creating a client-authored referrals/ document directly
    // is rejected — only redeemReferralCode (Admin SDK) may write it now.
    {
      const db = testEnv
        .authenticatedContext("phase9-rules-user", unprivilegedClaims("rules-user@phase9-test.example"))
        .firestore();
      try {
        await assertFails(
          db.collection("referrals").add({
            referrerUserId: "someone-else",
            referredUserId: "phase9-rules-user",
            referralCode: "FAKE",
            referrerBonus: 999999,
            referredBonus: 999999,
            isCompleted: false,
          })
        );
        results.scenario6_client_referral_create_rejected = "PASSED — a client-authored referrals/ document was rejected as expected";
      } catch (e) {
        results.scenario6_client_referral_create_rejected = `FAILED — a client was able to fabricate a referrals/ document directly: ${e.message}`;
      }
    }
  } finally {
    await testEnv.cleanup();
  }

  console.log("=== PHASE 9, WORKSTREAM 3 — wallets/referrals rules lockdown ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);

  const allPassed = Object.values(results).every((v) => v.startsWith("PASSED"));
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phase9 wallet rules test:", e);
  process.exit(1);
});
