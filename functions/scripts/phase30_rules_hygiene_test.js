// Phase FIX-6, Workstream 4 — proves five firestore.rules hygiene fixes
// against the real rules engine, one positive + one negative scenario per
// changed block, plus a regression control for each protected invariant
// this phase deliberately did NOT touch (settings/access,
// settings/wallet_config, settings/associate_onboarding, logs create).
//
// Mirrors phase15_rules_test.js's @firebase/rules-unit-testing pattern.
// Run with: firebase emulators:exec --only firestore
//             "node scripts/phase30_rules_hygiene_test.js"
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

function adminClaims(email) {
  return { ...unprivilegedClaims(email), role: "admin", admin: true };
}

const BASE_ORDER = {
  userId: "phase30-customer",
  sellerId: "phase30-seller",
  deliveryPartnerId: "phase30-delivery",
  orderNumber: "ORD-PHASE30-1",
  orderStatus: "out_for_delivery",
  status: "out_for_delivery",
};

async function main() {
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
    // ============================================================
    // 1. settings/commission — locked to isAdmin() (no widening block)
    // ============================================================
    {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("settings").doc("commission").set({ defaultCommission: 8 });
      });
      const userDb = testEnv.authenticatedContext("phase30-user1", unprivilegedClaims("u1@phase30-test.example")).firestore();
      const adminDb = testEnv.authenticatedContext("phase30-admin1", adminClaims("admin1@phase30-test.example")).firestore();
      const anonDb = testEnv.unauthenticatedContext().firestore();

      await record("s1a_negative_authenticated_user_cannot_read_commission",
        assertFails(userDb.collection("settings").doc("commission").get()));
      await record("s1b_negative_anonymous_cannot_read_commission",
        assertFails(anonDb.collection("settings").doc("commission").get()));
      await record("s1c_positive_admin_can_read_commission",
        assertSucceeds(adminDb.collection("settings").doc("commission").get()));
    }

    // ============================================================
    // 2. settings/access — widened to isAuthenticated() (regression control:
    //    this phase must NOT lock this one down further)
    // ============================================================
    {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("settings").doc("access").set({ adminEmails: ["admin@agrimore.in"] });
      });
      const userDb = testEnv.authenticatedContext("phase30-user2", unprivilegedClaims("u2@phase30-test.example")).firestore();
      const anonDb = testEnv.unauthenticatedContext().firestore();

      await record("s2a_positive_authenticated_user_can_read_access_allowlist",
        assertSucceeds(userDb.collection("settings").doc("access").get()));
      await record("s2b_negative_anonymous_cannot_read_access_allowlist",
        assertFails(anonDb.collection("settings").doc("access").get()));
    }

    // ============================================================
    // 3. settings/associate_onboarding — regression control: public read
    //    must still work (this is the invariant FIX-6's first draft broke)
    // ============================================================
    {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("settings").doc("associate_onboarding").set({ feeAmount: 500 });
      });
      const anonDb = testEnv.unauthenticatedContext().firestore();
      await record("s3_regression_anonymous_can_still_read_associate_onboarding",
        assertSucceeds(anonDb.collection("settings").doc("associate_onboarding").get()));
    }

    // ============================================================
    // 4. top-level notifications/{id} — locked to isAdmin()
    // ============================================================
    {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("notifications").doc("n1").set({ userId: "phase30-other-user", title: "New Order" });
      });
      const userDb = testEnv.authenticatedContext("phase30-user4", unprivilegedClaims("u4@phase30-test.example")).firestore();
      const adminDb = testEnv.authenticatedContext("phase30-admin4", adminClaims("admin4@phase30-test.example")).firestore();

      await record("s4a_negative_signed_in_user_cannot_read_others_notification",
        assertFails(userDb.collection("notifications").doc("n1").get()));
      await record("s4b_positive_admin_can_read_notification",
        assertSucceeds(adminDb.collection("notifications").doc("n1").get()));
    }

    // ============================================================
    // 5. referrals — locked to isAdmin()
    // ============================================================
    {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("referrals").doc("r1").set({ referrerId: "phase30-referrer", referredId: "phase30-referred" });
      });
      const userDb = testEnv.authenticatedContext("phase30-user5", unprivilegedClaims("u5@phase30-test.example")).firestore();
      const adminDb = testEnv.authenticatedContext("phase30-admin5", adminClaims("admin5@phase30-test.example")).firestore();

      await record("s5a_negative_signed_in_user_cannot_read_others_referral",
        assertFails(userDb.collection("referrals").doc("r1").get()));
      await record("s5b_positive_admin_can_read_referral",
        assertSucceeds(adminDb.collection("referrals").doc("r1").get()));
    }

    // ============================================================
    // 6. logs create — regression control: authenticated create must still
    //    work (Phase 15 Workstream 4a's own tested design; FIX-6's first
    //    draft broke it, then reverted)
    // ============================================================
    {
      const userDb = testEnv.authenticatedContext("phase30-user6", unprivilegedClaims("u6@phase30-test.example")).firestore();
      await record("s6_regression_signed_in_user_can_still_create_a_log",
        assertSucceeds(userDb.collection("logs").doc().set({ uid: "phase30-user6", event: "test_event", createdAt: Date.now() })));
    }

    // ============================================================
    // 7. orders/{orderId}/timeline — allow create for the order's own
    //    parties, but only admin may update or delete an existing entry
    // ============================================================
    {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("orders").doc("o7").set(BASE_ORDER);
        await ctx.firestore().collection("orders").doc("o7").collection("timeline").doc("t1").set({ status: "out_for_delivery" });
      });
      const ownerDb = testEnv.authenticatedContext("phase30-customer", unprivilegedClaims("customer@phase30-test.example")).firestore();
      const adminDb = testEnv.authenticatedContext("phase30-admin7", adminClaims("admin7@phase30-test.example")).firestore();

      await record("s7a_positive_owner_can_create_a_new_timeline_entry",
        assertSucceeds(ownerDb.collection("orders").doc("o7").collection("timeline").doc().set({ status: "delivered" })));
      await record("s7b_negative_owner_cannot_delete_an_existing_timeline_entry",
        assertFails(ownerDb.collection("orders").doc("o7").collection("timeline").doc("t1").delete()));
      await record("s7c_negative_owner_cannot_update_an_existing_timeline_entry",
        assertFails(ownerDb.collection("orders").doc("o7").collection("timeline").doc("t1").update({ status: "tampered" })));
      await record("s7d_positive_admin_can_delete_an_existing_timeline_entry",
        assertSucceeds(adminDb.collection("orders").doc("o7").collection("timeline").doc("t1").delete()));
    }

    // ============================================================
    // 8. reviews (both the top-level collection and the products/{id}/
    //    reviews subcollection) — update may not change who a review is
    //    attributed to
    // ============================================================
    {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("reviews").doc("rev1").set({ userId: "phase30-reviewer", rating: 5, text: "great" });
        await ctx.firestore().collection("products").doc("p1").set({ sellerId: "phase30-seller", name: "Test Product" });
        await ctx.firestore().collection("products").doc("p1").collection("reviews").doc("rev1").set({ userId: "phase30-reviewer", rating: 5, text: "great" });
      });
      const reviewerDb = testEnv.authenticatedContext("phase30-reviewer", unprivilegedClaims("reviewer@phase30-test.example")).firestore();

      await record("s8a_positive_reviewer_can_edit_their_own_top_level_review",
        assertSucceeds(reviewerDb.collection("reviews").doc("rev1").update({ rating: 4 })));
      await record("s8b_negative_reviewer_cannot_reattribute_top_level_review",
        assertFails(reviewerDb.collection("reviews").doc("rev1").update({ userId: "phase30-someone-else" })));
      await record("s8c_positive_reviewer_can_edit_their_own_subcollection_review",
        assertSucceeds(reviewerDb.collection("products").doc("p1").collection("reviews").doc("rev1").update({ rating: 3 })));
      await record("s8d_negative_reviewer_cannot_reattribute_subcollection_review",
        assertFails(reviewerDb.collection("products").doc("p1").collection("reviews").doc("rev1").update({ userId: "phase30-someone-else" })));
    }

    console.log("\n=== PHASE 30 SUMMARY ===");
    const total = Object.keys(results).length;
    const passed = Object.values(results).filter((v) => v === "PASSED").length;
    for (const [k, v] of Object.entries(results)) console.log(`  ${v === "PASSED" ? "PASS" : "FAIL"}  ${k}`);
    console.log(`\n${passed}/${total} scenarios passed`);
    if (passed !== total) { console.error("PHASE 30: FAILED"); process.exitCode = 1; }
    else console.log("PHASE 30: ALL PASSED");
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((e) => {
  console.error("PHASE 30: harness error", e);
  process.exit(1);
});
