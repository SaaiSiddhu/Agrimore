// Phase 14 — Critical Security Containment (Identity & Payment Trust
// Boundary). Proves the Workstream 2 (self-promotion/self-approval) and
// Workstream 7 (orders fulfilment field lock) rules fixes against the real
// rules engine, plus the pre-existing regression controls that must still
// hold. Mirrors phase9_wallet_rules_test.js's @firebase/rules-unit-testing
// pattern exactly.
// Run with: node scripts/phase14_rules_test.js
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
  userId: "phase14-customer",
  sellerId: "phase14-seller",
  orderNumber: "ORD-PHASE14-1",
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

async function main() {
  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
  const testEnv = await initializeTestEnvironment({
    projectId: "agrimore-66a4e",
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });

  const results = {};

  try {
    // ============================================
    // WORKSTREAM 2 — users/{uid} self-promotion
    // ============================================
    {
      const uid = "phase14-w2-user1";
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("users").doc(uid).set({ email: "w2-user1@phase14-test.example", role: "user" });
      });
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("w2-user1@phase14-test.example")).firestore();
      try {
        await assertFails(db.collection("users").doc(uid).update({ role: "admin" }));
        results.w2_role_self_promotion_rejected = "PASSED — an unprivileged user could not set role:'admin' on their own user doc";
      } catch (e) {
        results.w2_role_self_promotion_rejected = `FAILED — self-promotion to admin succeeded: ${e.message}`;
      }
    }

    {
      const uid = "phase14-w2-user2";
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("w2-user2@phase14-test.example")).firestore();
      try {
        await assertFails(db.collection("users").doc(uid).set({ email: "w2-user2@phase14-test.example", role: "admin" }));
        results.w2_create_with_privileged_role_rejected = "PASSED — a self-registering user could not create their own doc with role:'admin'";
      } catch (e) {
        results.w2_create_with_privileged_role_rejected = `FAILED — creating a user doc with role:'admin' succeeded: ${e.message}`;
      }
    }

    {
      const uid = "phase14-w2-user3";
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("w2-user3@phase14-test.example")).firestore();
      try {
        await assertSucceeds(db.collection("users").doc(uid).set({ email: "w2-user3@phase14-test.example", role: "user" }));
        results.w2_create_with_role_user_succeeds = "PASSED — real signup shape (role:'user') still creates successfully";
      } catch (e) {
        results.w2_create_with_role_user_succeeds = `FAILED — legitimate signup (role:'user') was rejected: ${e.message}`;
      }
    }

    {
      const uid = "phase14-w2-user4";
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("w2-user4@phase14-test.example")).firestore();
      try {
        await assertSucceeds(
          db.collection("users").doc(uid).set({ email: "w2-user4@phase14-test.example", role: "delivery_partner" })
        );
        results.w2_create_with_role_delivery_partner_succeeds =
          "PASSED — apps/delivery's real signup shape (role:'delivery_partner' at create) still creates successfully";
      } catch (e) {
        results.w2_create_with_role_delivery_partner_succeeds = `FAILED — the delivery-partner signup shape was rejected: ${e.message}`;
      }
    }

    {
      const uid = "phase14-w2-user5";
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("users").doc(uid).set({ email: "w2-user5@phase14-test.example", role: "user" });
      });
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("w2-user5@phase14-test.example")).firestore();
      try {
        await assertSucceeds(db.collection("users").doc(uid).set({ sellerStatus: "pending" }, { merge: true }));
        results.w2_seller_apply_pending_still_works =
          "PASSED — the real seller_apply_screen.dart/employee_apply_screen.dart shape (sellerStatus:'pending' on an existing doc) still succeeds";
      } catch (e) {
        results.w2_seller_apply_pending_still_works = `FAILED — writing sellerStatus:'pending' on the owner's own doc was rejected: ${e.message}`;
      }
      try {
        await assertFails(db.collection("users").doc(uid).set({ sellerStatus: "approved" }, { merge: true }));
        results.w2_seller_status_approved_on_users_doc_rejected =
          "PASSED — an unprivileged user could not set sellerStatus:'approved' on their own user doc";
      } catch (e) {
        results.w2_seller_status_approved_on_users_doc_rejected = `FAILED — self-approving via users/{uid}.sellerStatus succeeded: ${e.message}`;
      }
    }

    // ============================================
    // WORKSTREAM 2 — sellers/{sellerId}
    // ============================================
    {
      const uid = "phase14-w2-seller1";
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("w2-seller1@phase14-test.example")).firestore();
      try {
        await assertSucceeds(db.collection("sellers").doc(uid).set({ userId: uid, status: "pending", shopName: "Test Shop" }));
        results.w2_seller_create_pending_succeeds = "PASSED — creating a seller doc at status:'pending' (own id) succeeded";
      } catch (e) {
        results.w2_seller_create_pending_succeeds = `FAILED — legitimate pending seller application was rejected: ${e.message}`;
      }
    }

    {
      const uid = "phase14-w2-seller2";
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("w2-seller2@phase14-test.example")).firestore();
      try {
        await assertFails(db.collection("sellers").doc(uid).set({ userId: uid, status: "approved", shopName: "Test Shop" }));
        results.w2_seller_create_approved_rejected = "PASSED — creating a seller doc pre-approved (status:'approved') was rejected";
      } catch (e) {
        results.w2_seller_create_approved_rejected = `FAILED — self-creating an already-approved seller doc succeeded: ${e.message}`;
      }
    }

    {
      const attacker = "phase14-w2-seller3-attacker";
      const victimId = "phase14-w2-seller3-victim";
      const db = testEnv.authenticatedContext(attacker, unprivilegedClaims("w2-seller3@phase14-test.example")).firestore();
      try {
        await assertFails(db.collection("sellers").doc(victimId).set({ userId: attacker, status: "pending" }));
        results.w2_seller_id_squatting_rejected = "PASSED — creating a seller doc at another user's id was rejected";
      } catch (e) {
        results.w2_seller_id_squatting_rejected = `FAILED — id-squatting another seller's account succeeded: ${e.message}`;
      }
    }

    {
      const uid = "phase14-w2-seller4";
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("sellers").doc(uid).set({ userId: uid, status: "pending", shopName: "Test Shop" });
      });
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("w2-seller4@phase14-test.example")).firestore();
      try {
        await assertFails(db.collection("sellers").doc(uid).update({ status: "approved" }));
        results.w2_seller_self_approve_via_update_rejected = "PASSED — self-approving an existing pending seller doc was rejected";
      } catch (e) {
        results.w2_seller_self_approve_via_update_rejected = `FAILED — self-approval via update succeeded: ${e.message}`;
      }
    }

    {
      const uid = "phase14-w2-seller5";
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("sellers").doc(uid).set({ userId: uid, status: "approved", shopName: "Old Name" });
      });
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("w2-seller5@phase14-test.example")).firestore();
      try {
        await assertSucceeds(
          db.collection("sellers").doc(uid).set({ userId: uid, status: "approved", shopName: "New Name" })
        );
        results.w2_approved_seller_can_still_edit_profile =
          "PASSED — an already-approved seller's own unrelated profile edit (status carried over unchanged) still succeeds";
      } catch (e) {
        results.w2_approved_seller_can_still_edit_profile = `FAILED — an approved seller's own harmless profile edit was rejected: ${e.message}`;
      }
    }

    // ============================================
    // WORKSTREAM 2 — employees/{employeeId}
    // ============================================
    {
      const uid = "phase14-w2-emp1";
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("w2-emp1@phase14-test.example")).firestore();
      try {
        await assertSucceeds(
          db.collection("employees").doc(uid).set({ userId: uid, status: "pending", commissionRate: 0, employeeCode: "TEST01" })
        );
        results.w2_employee_self_apply_pending_succeeds = "PASSED — the real self-apply shape (status:'pending', commissionRate:0) succeeded";
      } catch (e) {
        results.w2_employee_self_apply_pending_succeeds = `FAILED — legitimate employee self-apply was rejected: ${e.message}`;
      }
    }

    {
      const uid = "phase14-w2-emp2";
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("w2-emp2@phase14-test.example")).firestore();
      try {
        await assertFails(
          db.collection("employees").doc(uid).set({ userId: uid, status: "approved", commissionRate: 100, employeeCode: "TEST02" })
        );
        results.w2_employee_self_create_approved_rejected = "PASSED — self-creating an approved, 100%-commission employee doc was rejected";
      } catch (e) {
        results.w2_employee_self_create_approved_rejected = `FAILED — self-creating an approved employee doc succeeded: ${e.message}`;
      }
    }

    {
      const uid = "phase14-w2-emp3";
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("employees").doc(uid).set({ userId: uid, status: "pending", commissionRate: 0 });
      });
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("w2-emp3@phase14-test.example")).firestore();
      try {
        await assertFails(db.collection("employees").doc(uid).update({ status: "approved" }));
        results.w2_employee_self_approve_via_update_rejected = "PASSED — self-approving an existing pending employee doc was rejected";
      } catch (e) {
        results.w2_employee_self_approve_via_update_rejected = `FAILED — self-approval via update succeeded: ${e.message}`;
      }
      try {
        await assertFails(db.collection("employees").doc(uid).update({ commissionRate: 100 }));
        results.w2_employee_self_set_commission_rejected =
          "PASSED — self-setting commissionRate:100 on an existing employee doc was rejected (the exact unlimited-wallet-mint chain this closes)";
      } catch (e) {
        results.w2_employee_self_set_commission_rejected = `FAILED — self-setting a 100% commission rate succeeded: ${e.message}`;
      }
    }

    {
      const uid = "phase14-w2-emp4";
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("employees").doc(uid).set({ userId: uid, status: "suspended", commissionRate: 0 });
      });
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("w2-emp4@phase14-test.example")).firestore();
      try {
        await assertSucceeds(db.collection("employees").doc(uid).update({ status: "pending" }));
        results.w2_employee_reapply_after_suspension_still_works =
          "PASSED — the real 'Re-Apply after suspension' flow (status: suspended -> pending) still succeeds";
      } catch (e) {
        results.w2_employee_reapply_after_suspension_still_works = `FAILED — the legitimate re-apply-after-suspension flow was rejected: ${e.message}`;
      }
    }

    // ============================================
    // WORKSTREAM 2 — delivery_partners/{partnerId}
    // ============================================
    {
      const uid = "phase14-w2-dp1";
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("w2-dp1@phase14-test.example")).firestore();
      try {
        await assertSucceeds(db.collection("delivery_partners").doc(uid).set({ userId: uid, status: "pending" }));
        results.w2_delivery_partner_create_pending_succeeds = "PASSED — the real registration shape (status:'pending') succeeded";
      } catch (e) {
        results.w2_delivery_partner_create_pending_succeeds = `FAILED — legitimate delivery-partner registration was rejected: ${e.message}`;
      }
    }

    {
      const uid = "phase14-w2-dp2";
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("w2-dp2@phase14-test.example")).firestore();
      try {
        await assertFails(db.collection("delivery_partners").doc(uid).set({ userId: uid, status: "approved" }));
        results.w2_delivery_partner_create_approved_rejected = "PASSED — self-creating an approved delivery-partner doc was rejected";
      } catch (e) {
        results.w2_delivery_partner_create_approved_rejected = `FAILED — self-creating an approved delivery-partner doc succeeded: ${e.message}`;
      }
    }

    {
      const uid = "phase14-w2-dp3";
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("delivery_partners").doc(uid).set({ userId: uid, status: "pending" });
      });
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("w2-dp3@phase14-test.example")).firestore();
      try {
        await assertFails(db.collection("delivery_partners").doc(uid).update({ status: "approved" }));
        results.w2_delivery_partner_self_approve_via_update_rejected =
          "PASSED — self-approving an existing pending delivery-partner doc was rejected";
      } catch (e) {
        results.w2_delivery_partner_self_approve_via_update_rejected = `FAILED — self-approval via update succeeded: ${e.message}`;
      }
      try {
        await assertSucceeds(
          db.collection("delivery_partners").doc(uid).update({ currentLat: 12.9, currentLng: 77.6 })
        );
        results.w2_delivery_partner_location_update_still_works =
          "PASSED — the real location_provider.dart shape (currentLat/currentLng, no status touch) still succeeds";
      } catch (e) {
        results.w2_delivery_partner_location_update_still_works = `FAILED — a harmless location update was rejected: ${e.message}`;
      }
    }

    // ============================================
    // WORKSTREAM 7 — orders update field lock
    // ============================================
    {
      const orderId = "phase14-w7-order1";
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("orders").doc(orderId).set(BASE_ORDER);
      });
      const db = testEnv.authenticatedContext("phase14-seller", sellerClaims("seller1@phase14-test.example")).firestore();
      try {
        await assertFails(
          db.collection("orders").doc(orderId).update({
            total: 1,
            paymentStatus: "paid",
            employeeUid: "phase14-seller",
            orderStatus: "delivered",
            status: "delivered",
          })
        );
        results.w7_seller_cannot_change_financials_or_attribution =
          "PASSED — the named seller could not rewrite total/paymentStatus/employeeUid (and force delivered) in one update — the CTO-proven exploit";
      } catch (e) {
        results.w7_seller_cannot_change_financials_or_attribution = `FAILED — the seller rewrote protected order fields: ${e.message}`;
      }
    }

    {
      const orderId = "phase14-w7-order2";
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("orders").doc(orderId).set(BASE_ORDER);
      });
      const db = testEnv.authenticatedContext("phase14-seller", sellerClaims("seller2@phase14-test.example")).firestore();
      try {
        await assertSucceeds(
          db.collection("orders").doc(orderId).update({ orderStatus: "processing", status: "processing" })
        );
        results.w7_seller_normal_fulfilment_update_succeeds =
          "PASSED — a real fulfilment status advance (orderStatus/status only, matching seller_order_provider.dart) still succeeds — proves live fulfilment isn't broken";
      } catch (e) {
        results.w7_seller_normal_fulfilment_update_succeeds = `FAILED — a legitimate fulfilment status update was rejected: ${e.message}`;
      }
    }

    {
      const orderId = "phase14-w7-order3";
      const partnerId = "phase14-w7-partner1";
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("orders").doc(orderId).set({ ...BASE_ORDER, deliveryPartnerId: partnerId });
      });
      const db = testEnv.authenticatedContext(partnerId, deliveryPartnerClaims("partner1@phase14-test.example")).firestore();
      try {
        await assertFails(db.collection("orders").doc(orderId).update({ total: 1 }));
        results.w7_delivery_partner_cannot_change_financials =
          "PASSED — the assigned delivery partner could not rewrite `total`";
      } catch (e) {
        results.w7_delivery_partner_cannot_change_financials = `FAILED — the delivery partner rewrote a protected field: ${e.message}`;
      }
    }

    {
      const orderId = "phase14-w7-order4";
      const partnerId = "phase14-w7-partner2";
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("orders").doc(orderId).set({ ...BASE_ORDER, orderStatus: "ready_for_pickup", status: "ready_for_pickup" });
      });
      const db = testEnv.authenticatedContext(partnerId, deliveryPartnerClaims("partner2@phase14-test.example")).firestore();
      try {
        await assertSucceeds(
          db.collection("orders").doc(orderId).update({
            deliveryPartnerId: partnerId,
            orderStatus: "delivery_accepted",
            status: "delivery_accepted",
          })
        );
        results.w7_delivery_partner_claim_unassigned_order_still_works =
          "PASSED — an unassigned delivery partner claiming a ready-for-pickup order (writing deliveryPartnerId + status) still succeeds";
      } catch (e) {
        results.w7_delivery_partner_claim_unassigned_order_still_works = `FAILED — claiming an unassigned order was rejected: ${e.message}`;
      }
    }

    // ============================================
    // REGRESSION CONTROLS — must still pass unchanged from prior phases
    // ============================================
    {
      const uid = "phase14-regression-wallet";
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("wallets").doc(uid).set({
          userId: uid, balance: 0, coins: 0, lifetimeEarnings: 0, lifetimeSpent: 0,
          lifetimeCoinsEarned: 0, lifetimeCoinsUsed: 0, referralCode: "R1", referredBy: null,
          referralCount: 0, isActive: true, signupBonusCredited: false,
        });
      });
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("regression-wallet@phase14-test.example")).firestore();
      try {
        await assertFails(db.collection("wallets").doc(uid).update({ balance: 999999 }));
        results.regression_wallet_direct_balance_write_rejected = "PASSED — direct wallet balance self-credit is still rejected (Phase 9)";
      } catch (e) {
        results.regression_wallet_direct_balance_write_rejected = `FAILED — REGRESSION: direct wallet balance write succeeded: ${e.message}`;
      }
    }

    {
      const uid = "phase14-regression-order-create";
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("regression-order-create@phase14-test.example")).firestore();
      try {
        await assertFails(db.collection("orders").doc().set({ ...BASE_ORDER, userId: uid }));
        results.regression_raw_client_order_create_rejected = "PASSED — a raw client order create is still rejected (orders create: if false)";
      } catch (e) {
        results.regression_raw_client_order_create_rejected = `FAILED — REGRESSION: a raw client order create succeeded: ${e.message}`;
      }
    }

    {
      const orderId = "phase14-regression-cancel";
      const uid = "phase14-regression-owner";
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("orders").doc(orderId).set({ ...BASE_ORDER, userId: uid });
      });
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("regression-owner@phase14-test.example")).firestore();
      try {
        await assertSucceeds(db.collection("orders").doc(orderId).update({ orderStatus: "cancelled" }));
        results.regression_owner_cancellation_still_works = "PASSED — a legitimate owner cancellation (Phase 5b) still succeeds";
      } catch (e) {
        results.regression_owner_cancellation_still_works = `FAILED — REGRESSION: legitimate owner cancellation was rejected: ${e.message}`;
      }
    }
  } finally {
    await testEnv.cleanup();
  }

  console.log("=== PHASE 14 — RULES LOCKDOWN TEST ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);

  const allPassed = Object.values(results).every((v) => v.startsWith("PASSED"));
  console.log(allPassed ? "\nALL PASSED" : "\nSOME FAILED");
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phase14 rules test:", e);
  process.exit(1);
});
