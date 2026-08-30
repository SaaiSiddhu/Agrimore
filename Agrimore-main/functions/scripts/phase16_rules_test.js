// Phase 16, Workstream 5 — proves the new profileCompleted/phoneVerified/
// emailVerified/email/dateOfBirth locks against the real rules engine, a
// positive control for the real profile-edit flow, and regression controls
// for every prior phase's lock this repo has accumulated. Mirrors
// phase15_rules_test.js's @firebase/rules-unit-testing pattern exactly.
// Run with: node scripts/phase16_rules_test.js
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

function sellerClaims(email) {
  return { ...unprivilegedClaims(email), role: "seller", seller: true, sellerApproved: true };
}

function deliveryPartnerClaims(email) {
  return { ...unprivilegedClaims(email), role: "delivery_partner", delivery_partner: true, deliveryApproved: true };
}

const ZERO_WALLET = {
  userId: "phase16-rules-wallet-user",
  balance: 0,
  coins: 0,
  lifetimeEarnings: 0,
  lifetimeSpent: 0,
  lifetimeCoinsEarned: 0,
  lifetimeCoinsUsed: 0,
  referralCode: "PHASE16A",
  referredBy: null,
  referralCount: 0,
  isActive: true,
  signupBonusCredited: false,
};

// A fully complete Phase-16 user doc — every field UserModel.toMap() now
// writes, matching what edit_profile_screen.dart's real update() call
// carries over.
function completeUserDoc(uid, overrides = {}) {
  return {
    uid,
    email: "phase16-rules-user@example.com",
    name: "Original Name",
    phone: "+919876500020",
    photoUrl: null,
    role: "user",
    isActive: true,
    metadata: null,
    dateOfBirth: new Date("1995-06-15").getTime(),
    gender: "male",
    profileCompleted: true,
    phoneVerified: true,
    emailVerified: true,
    profileCompletedAt: Date.now(),
    ...overrides,
  };
}

async function main() {
  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
  const testEnv = await initializeTestEnvironment({
    projectId: "agrimore-66a4e",
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });

  const results = {};

  try {
    // ============================================
    // profileCompleted / phoneVerified / emailVerified — CREATE
    // ============================================
    {
      const uid = "phase16-w5-create-privileged";
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("w5-create@phase16-test.example")).firestore();
      try {
        await assertFails(
          db.collection("users").doc(uid).set({
            uid,
            email: "",
            name: "New User",
            role: "user",
            profileCompleted: true,
          })
        );
        results.create_profile_completed_true_rejected = "PASSED — a self-registering user could not create their doc already profileCompleted:true";
      } catch (e) {
        results.create_profile_completed_true_rejected = `FAILED — a client created a pre-completed profile: ${e.message}`;
      }
      try {
        // Mirrors the REAL client create shape (registerWithEmail/
        // signInWithGoogle in auth_service.dart, via UserModel.toMap()) —
        // phoneVerified/emailVerified default to false; only the Admin-SDK
        // verifyPhoneOTP.ts path (which bypasses these rules entirely) ever
        // writes phoneVerified:true at create.
        await assertSucceeds(
          db.collection("users").doc(uid).set({
            uid,
            email: "",
            name: "New User",
            phone: "+919876500021",
            role: "user",
            phoneVerified: false,
            emailVerified: false,
            profileCompleted: false,
          })
        );
        results.create_profile_completed_false_succeeds = "PASSED — the real signup shape (profileCompleted:false) still creates successfully";
      } catch (e) {
        results.create_profile_completed_false_succeeds = `FAILED — a legitimate signup create was rejected: ${e.message}`;
      }
    }

    // ============================================
    // profileCompleted / phoneVerified / emailVerified / email / dateOfBirth — UPDATE
    // ============================================
    {
      const uid = "phase16-w5-update-privileged";
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx
          .firestore()
          .collection("users")
          .doc(uid)
          .set(completeUserDoc(uid, { profileCompleted: false, phoneVerified: false, emailVerified: false }));
      });
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("w5-update@phase16-test.example")).firestore();

      const attempts = [
        ["profileCompleted", { profileCompleted: true }],
        ["phoneVerified", { phoneVerified: true }],
        ["emailVerified", { emailVerified: true }],
        ["email", { email: "someone-else@example.com" }],
        ["dateOfBirth", { dateOfBirth: new Date("2000-01-01").getTime() }],
      ];
      for (const [label, patch] of attempts) {
        try {
          await assertFails(db.collection("users").doc(uid).update(patch));
          results[`update_${label}_rejected`] = `PASSED — a client could not change ${label} on its own doc`;
        } catch (e) {
          results[`update_${label}_rejected`] = `FAILED — a client changed ${label}: ${e.message}`;
        }
      }
    }

    // ============================================
    // POSITIVE CONTROL — the real profile-edit flow
    // (edit_profile_screen.dart -> AuthProvider.updateUserProfile ->
    // .update(updatedUser.toMap())) must still succeed: name/phone changed,
    // every Phase 16 field carried over UNCHANGED.
    // ============================================
    {
      const uid = "phase16-w5-real-edit-flow";
      const original = completeUserDoc(uid);
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("users").doc(uid).set(original);
      });
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("w5-edit@phase16-test.example")).firestore();
      try {
        // Mirrors updatedUser.toMap() exactly: name/phone/photoUrl changed,
        // every other field (including all Phase 16 additions) identical to
        // what's already on the document.
        await assertSucceeds(
          db.collection("users").doc(uid).update({
            ...original,
            name: "Updated Name",
            phone: "+919876500099",
            photoUrl: "https://example.com/new-photo.jpg",
          })
        );
        results.positive_control_real_edit_flow_succeeds =
          "PASSED — the real profile-edit flow (name/phone/photoUrl changed, all Phase 16 fields carried over unchanged) still succeeds";
      } catch (e) {
        results.positive_control_real_edit_flow_succeeds = `FAILED — the real edit_profile_screen.dart flow was rejected: ${e.message}`;
      }
    }

    // ============================================
    // REGRESSION — Phase 14 role self-promotion
    // ============================================
    {
      const uid = "phase16-regression-role";
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("users").doc(uid).set({ uid, role: "user", email: "x@x.com" });
      });
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("regression-role@phase16-test.example")).firestore();
      try {
        await assertFails(db.collection("users").doc(uid).update({ role: "admin" }));
        results.regression_role_self_promotion_still_rejected = "PASSED — Phase 14's role self-promotion lock still holds";
      } catch (e) {
        results.regression_role_self_promotion_still_rejected = `FAILED — REGRESSION: role self-promotion succeeded: ${e.message}`;
      }
    }

    // ============================================
    // REGRESSION — Phase 14 seller self-approval
    // ============================================
    {
      const uid = "phase16-regression-seller";
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("sellers").doc(uid).set({ userId: uid, status: "pending" });
      });
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("regression-seller@phase16-test.example")).firestore();
      try {
        await assertFails(db.collection("sellers").doc(uid).update({ status: "approved" }));
        results.regression_seller_self_approval_still_rejected = "PASSED — Phase 14's seller self-approval lock still holds";
      } catch (e) {
        results.regression_seller_self_approval_still_rejected = `FAILED — REGRESSION: seller self-approval succeeded: ${e.message}`;
      }
    }

    // ============================================
    // REGRESSION — Phase 9 wallet balance lock
    // ============================================
    {
      const uid = "phase16-regression-wallet";
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("wallets").doc(uid).set({ ...ZERO_WALLET, userId: uid, referralCode: "PHASE16B" });
      });
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("regression-wallet@phase16-test.example")).firestore();
      try {
        await assertFails(db.collection("wallets").doc(uid).update({ balance: 999999 }));
        results.regression_wallet_balance_lock_still_holds = "PASSED — Phase 9's wallet balance lock still holds";
      } catch (e) {
        results.regression_wallet_balance_lock_still_holds = `FAILED — REGRESSION: direct wallet balance write succeeded: ${e.message}`;
      }
    }

    // ============================================
    // REGRESSION — Phase 15 deliveryPartnerId redirect lock
    // ============================================
    {
      const orderId = "phase16-regression-order";
      const sellerId = "phase16-regression-seller-order";
      const accomplice = "phase16-regression-accomplice";
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx
          .firestore()
          .collection("orders")
          .doc(orderId)
          .set({
            userId: "phase16-regression-customer",
            sellerId,
            orderNumber: "ORD-PHASE16-REG",
            items: [{ productId: "p1", quantity: 1, price: 100 }],
            subtotal: 100,
            discount: 0,
            deliveryCharge: 0,
            tax: 0,
            total: 100,
            paymentMethod: "cod",
            paymentStatus: "pending",
            orderStatus: "ready_for_pickup",
            status: "ready_for_pickup",
            deliveryPartnerId: "phase16-regression-real-partner",
          });
      });
      const db = testEnv.authenticatedContext(sellerId, sellerClaims("regression-seller-order@phase16-test.example")).firestore();
      try {
        await assertFails(db.collection("orders").doc(orderId).update({ deliveryPartnerId: accomplice }));
        results.regression_delivery_partner_redirect_still_rejected = "PASSED — Phase 15's deliveryPartnerId redirect lock still holds";
      } catch (e) {
        results.regression_delivery_partner_redirect_still_rejected = `FAILED — REGRESSION: deliveryPartnerId redirect succeeded: ${e.message}`;
      }
    }

    // ============================================
    // REGRESSION — Phase 15 logs/auth_logs/referralCode/sponsored_banners
    // ============================================
    {
      const uid = "phase16-regression-logs";
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("regression-logs@phase16-test.example")).firestore();
      try {
        await assertFails(db.collection("logs").doc("phase16-reg-log").update({ event: "tampered" }));
        results.regression_logs_update_still_rejected = "PASSED — Phase 15's logs update lock still holds";
      } catch (e) {
        results.regression_logs_update_still_rejected = `FAILED — REGRESSION: logs update succeeded: ${e.message}`;
      }
      try {
        await assertFails(
          db.collection("auth_logs").add({ uid: "someone-else", event: "login", success: true, timestamp: Date.now() })
        );
        results.regression_auth_log_forgery_still_rejected = "PASSED — Phase 15's auth_logs forgery lock still holds";
      } catch (e) {
        results.regression_auth_log_forgery_still_rejected = `FAILED — REGRESSION: auth_logs forgery succeeded: ${e.message}`;
      }
    }
    {
      const uid = "phase16-regression-referral";
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("wallets").doc(uid).set({ ...ZERO_WALLET, userId: uid, referralCode: "PHASE16C" });
      });
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("regression-referral@phase16-test.example")).firestore();
      try {
        await assertFails(db.collection("wallets").doc(uid).update({ referralCode: "SQUATTED16" }));
        results.regression_referral_code_squat_still_rejected = "PASSED — Phase 15's referralCode lock still holds";
      } catch (e) {
        results.regression_referral_code_squat_still_rejected = `FAILED — REGRESSION: referralCode rewrite succeeded: ${e.message}`;
      }
    }
    {
      const attacker = "phase16-regression-banner-attacker";
      const victimSellerId = "phase16-regression-banner-victim";
      const db = testEnv.authenticatedContext(attacker, sellerClaims("regression-banner@phase16-test.example")).firestore();
      try {
        await assertFails(
          db.collection("sponsored_banners").add({ sellerId: victimSellerId, productId: "p1", title: "hijacked" })
        );
        results.regression_sponsored_banner_impersonation_still_rejected = "PASSED — Phase 15's sponsored_banners impersonation lock still holds";
      } catch (e) {
        results.regression_sponsored_banner_impersonation_still_rejected = `FAILED — REGRESSION: sponsored-banner impersonation succeeded: ${e.message}`;
      }
    }
  } finally {
    await testEnv.cleanup();
  }

  console.log("=== PHASE 16 — RULES LOCKDOWN TEST ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);

  const allPassed = Object.values(results).every((v) => v.startsWith("PASSED"));
  console.log(allPassed ? "\nALL PASSED" : "\nSOME FAILED");
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phase16 rules test:", e);
  process.exit(1);
});
