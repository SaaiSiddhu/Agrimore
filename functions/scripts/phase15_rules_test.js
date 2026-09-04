// Phase 15 — Second-Tier Hardening. Proves Workstream 3a (deliveryPartnerId
// field lock) and Workstream 4 (logs/auth_logs/wallets.referralCode/
// sponsored_banners+campaigns) against the real rules engine, plus
// regression controls proving Phase 9/Phase 14's locks still hold. Mirrors
// phase14_rules_test.js's @firebase/rules-unit-testing pattern exactly,
// including its use of positive controls alongside every negative one.
// Run with: node scripts/phase15_rules_test.js
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

const BASE_ORDER = {
  userId: "phase15-customer",
  sellerId: "phase15-seller",
  orderNumber: "ORD-PHASE15-1",
  items: [{ productId: "p1", quantity: 1, price: 100 }],
  subtotal: 100,
  discount: 0,
  deliveryCharge: 0,
  tax: 0,
  total: 100,
  paymentMethod: "cod",
  paymentStatus: "pending",
  orderStatus: "pending",
  status: "pending",
  employeeUid: null,
  employeeCode: null,
  orderMode: "B2C",
  commissionPaid: false,
};

const ZERO_WALLET = {
  userId: "phase15-rules-user",
  balance: 0,
  coins: 0,
  lifetimeEarnings: 0,
  lifetimeSpent: 0,
  lifetimeCoinsEarned: 0,
  lifetimeCoinsUsed: 0,
  referralCode: "PHASE15A",
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
    // ============================================
    // WORKSTREAM 4a — logs
    // ============================================
    {
      const uid = "phase15-w4a-user";
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("w4a@phase15-test.example")).firestore();
      const logRef = db.collection("logs").doc();
      try {
        await assertSucceeds(logRef.set({ uid, event: "test_event", createdAt: Date.now() }));
        results.w4a_log_create_succeeds = "PASSED — a signed-in user can still create a log document";
      } catch (e) {
        results.w4a_log_create_succeeds = `FAILED — legitimate log creation was rejected: ${e.message}`;
      }
      try {
        await assertFails(logRef.update({ event: "tampered" }));
        results.w4a_log_update_rejected = "PASSED — updating an existing log document was rejected";
      } catch (e) {
        results.w4a_log_update_rejected = `FAILED — a client updated an existing log document: ${e.message}`;
      }
      try {
        await assertFails(logRef.delete());
        results.w4a_log_delete_rejected = "PASSED — deleting a log document was rejected";
      } catch (e) {
        results.w4a_log_delete_rejected = `FAILED — a client deleted a log document: ${e.message}`;
      }
    }

    // ============================================
    // WORKSTREAM 4b — auth_logs
    // ============================================
    {
      const uid = "phase15-w4b-user";
      const victim = "phase15-w4b-victim";
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("w4b@phase15-test.example")).firestore();
      try {
        await assertFails(
          db.collection("auth_logs").add({ uid: victim, event: "login", success: true, timestamp: Date.now() })
        );
        results.w4b_auth_log_forgery_rejected = "PASSED — a user could not create an auth_logs entry attributed to a different uid";
      } catch (e) {
        results.w4b_auth_log_forgery_rejected = `FAILED — auth_logs forgery succeeded: ${e.message}`;
      }
      try {
        // Mirrors the REAL write shape from apps/marketplace/lib/providers/
        // auth_provider.dart's _logAuthEvent (field is literally `uid`, not
        // `userId`) — the exact scenario a login/registration success event
        // exercises, with the caller still genuinely authenticated.
        await assertSucceeds(
          db.collection("auth_logs").add({
            event: "login",
            success: true,
            email: "w4b@phase15-test.example",
            error: null,
            timestamp: Date.now(),
            platform: "flutter",
            uid,
          })
        );
        results.w4b_real_auth_log_shape_succeeds = "PASSED — the real client shape (field `uid`, matching the caller) still succeeds";
      } catch (e) {
        results.w4b_real_auth_log_shape_succeeds = `FAILED — the real auth_provider.dart write shape was rejected: ${e.message}`;
      }
    }

    // ============================================
    // WORKSTREAM 4c — wallets.referralCode
    // ============================================
    {
      const uid = "phase15-rules-user";
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("w4c@phase15-test.example")).firestore();
      try {
        await assertSucceeds(db.collection("wallets").doc(uid).set(ZERO_WALLET));
        results.w4c_wallet_create_with_referral_code_succeeds =
          "PASSED — creating a wallet doc with a freshly-generated referralCode still succeeds";
      } catch (e) {
        results.w4c_wallet_create_with_referral_code_succeeds = `FAILED — legitimate wallet creation was rejected: ${e.message}`;
      }
      try {
        await assertFails(db.collection("wallets").doc(uid).update({ referralCode: "SQUATTED" }));
        results.w4c_referral_code_rewrite_rejected = "PASSED — rewriting referralCode post-creation was rejected";
      } catch (e) {
        results.w4c_referral_code_rewrite_rejected = `FAILED — a user rewrote their own referralCode: ${e.message}`;
      }
    }

    // ============================================
    // WORKSTREAM 4d — sponsored_banners / campaigns
    // ============================================
    {
      const attacker = "phase15-w4d-attacker";
      const victimSellerId = "phase15-w4d-victim-seller";
      const db = testEnv.authenticatedContext(attacker, sellerClaims("w4d-attacker@phase15-test.example")).firestore();
      try {
        await assertFails(
          db.collection("sponsored_banners").add({ sellerId: victimSellerId, productId: "p1", title: "hijacked" })
        );
        results.w4d_sponsored_banner_impersonation_rejected =
          "PASSED — a seller could not create a sponsored banner attributed to a different seller's id";
      } catch (e) {
        results.w4d_sponsored_banner_impersonation_rejected = `FAILED — sponsored-banner impersonation succeeded: ${e.message}`;
      }
      try {
        await assertSucceeds(
          db.collection("sponsored_banners").add({ sellerId: attacker, productId: "p1", title: "own banner" })
        );
        results.w4d_sponsored_banner_own_create_succeeds = "PASSED — a seller can still create a banner attributed to their own uid";
      } catch (e) {
        results.w4d_sponsored_banner_own_create_succeeds = `FAILED — a seller's own banner creation was rejected: ${e.message}`;
      }
      try {
        await assertFails(
          db.collection("campaigns").add({ sellerId: victimSellerId, title: "hijacked campaign" })
        );
        results.w4d_campaign_impersonation_rejected =
          "PASSED — a seller could not create a campaign attributed to a different seller's id";
      } catch (e) {
        results.w4d_campaign_impersonation_rejected = `FAILED — campaign impersonation succeeded: ${e.message}`;
      }
      try {
        await assertSucceeds(db.collection("campaigns").add({ sellerId: attacker, title: "own campaign" }));
        results.w4d_campaign_own_create_succeeds = "PASSED — a seller can still create a campaign attributed to their own uid";
      } catch (e) {
        results.w4d_campaign_own_create_succeeds = `FAILED — a seller's own campaign creation was rejected: ${e.message}`;
      }
    }

    // ============================================
    // WORKSTREAM 3a — deliveryPartnerId field lock
    // ============================================
    {
      const orderId = "phase15-w3a-order1";
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("orders").doc(orderId).set(BASE_ORDER);
      });
      const db = testEnv.authenticatedContext("phase15-seller", sellerClaims("w3a-seller@phase15-test.example")).firestore();
      try {
        await assertFails(db.collection("orders").doc(orderId).update({ deliveryPartnerId: "phase15-accomplice" }));
        results.w3a_seller_cannot_redirect_delivery =
          "PASSED — a seller could not rewrite deliveryPartnerId to redirect delivery to an accomplice";
      } catch (e) {
        results.w3a_seller_cannot_redirect_delivery = `FAILED — a seller redirected delivery: ${e.message}`;
      }
    }

    {
      // POSITIVE CONTROL — the exact control this workstream mandates
      // keeping green: a delivery partner can still claim an unassigned
      // ready-for-pickup order.
      const orderId = "phase15-w3a-order2";
      const partnerId = "phase15-w3a-partner";
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("orders").doc(orderId).set({
          ...BASE_ORDER,
          orderStatus: "ready_for_pickup",
          status: "ready_for_pickup",
        });
      });
      const db = testEnv.authenticatedContext(partnerId, deliveryPartnerClaims("w3a-partner@phase15-test.example")).firestore();
      try {
        await assertSucceeds(
          db.collection("orders").doc(orderId).update({
            deliveryPartnerId: partnerId,
            orderStatus: "delivery_accepted",
            status: "delivery_accepted",
          })
        );
        results.w3a_delivery_partner_can_still_claim_unassigned_order =
          "PASSED — an unassigned delivery partner can still claim a ready-for-pickup order (w7_delivery_partner_claim_unassigned_order_still_works's Phase 15 equivalent)";
      } catch (e) {
        results.w3a_delivery_partner_can_still_claim_unassigned_order = `FAILED — claiming an unassigned order was rejected: ${e.message}`;
      }
    }

    // ============================================
    // REGRESSION CONTROLS — Phase 14 role/self-approval locks, Phase 9
    // wallet lock
    // ============================================
    {
      const uid = "phase15-regression-role";
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("users").doc(uid).set({ email: "regression-role@phase15-test.example", role: "user" });
      });
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("regression-role@phase15-test.example")).firestore();
      try {
        await assertFails(db.collection("users").doc(uid).update({ role: "admin" }));
        results.regression_role_self_promotion_still_rejected = "PASSED — Phase 14's role self-promotion lock still holds";
      } catch (e) {
        results.regression_role_self_promotion_still_rejected = `FAILED — REGRESSION: role self-promotion succeeded: ${e.message}`;
      }
    }

    {
      const uid = "phase15-regression-seller";
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("sellers").doc(uid).set({ userId: uid, status: "pending" });
      });
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("regression-seller@phase15-test.example")).firestore();
      try {
        await assertFails(db.collection("sellers").doc(uid).update({ status: "approved" }));
        results.regression_seller_self_approval_still_rejected = "PASSED — Phase 14's seller self-approval lock still holds";
      } catch (e) {
        results.regression_seller_self_approval_still_rejected = `FAILED — REGRESSION: seller self-approval succeeded: ${e.message}`;
      }
    }

    {
      const uid = "phase15-regression-wallet";
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("wallets").doc(uid).set({ ...ZERO_WALLET, userId: uid, referralCode: "PHASE15B" });
      });
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("regression-wallet@phase15-test.example")).firestore();
      try {
        await assertFails(db.collection("wallets").doc(uid).update({ balance: 999999 }));
        results.regression_wallet_balance_lock_still_holds = "PASSED — Phase 9's wallet balance lock still holds";
      } catch (e) {
        results.regression_wallet_balance_lock_still_holds = `FAILED — REGRESSION: direct wallet balance write succeeded: ${e.message}`;
      }
    }
  } finally {
    await testEnv.cleanup();
  }

  console.log("=== PHASE 15 — RULES LOCKDOWN TEST ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);

  const allPassed = Object.values(results).every((v) => v.startsWith("PASSED"));
  console.log(allPassed ? "\nALL PASSED" : "\nSOME FAILED");
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phase15 rules test:", e);
  process.exit(1);
});
