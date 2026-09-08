// Phase FIX-6B — proves the ten new firestore.rules blocks (D-COLLECTION-
// COVERAGE) against the real rules engine: at least one positive and one
// negative scenario per collection, plus the value-guarded update checks
// (subscriptions.isActive, scratchCards.isScratched) and the sellerRequests
// PII-protection check (the highest-stakes block this phase adds).
//
// Mirrors phase30_rules_hygiene_test.js's @firebase/rules-unit-testing
// pattern exactly.
// Run with: firebase emulators:exec --only firestore
//             "node scripts/phase31_collection_coverage_test.js"
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
    // 1. subscriptions — owner-or-admin read, self-attributed create,
    //    isActive-only value-guarded update
    // ============================================================
    {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("subscriptions").doc("sub1").set({
          userId: "phase31-owner", productId: "p1", isActive: true,
        });
      });
      const ownerDb = testEnv.authenticatedContext("phase31-owner", unprivilegedClaims("owner@phase31-test.example")).firestore();
      const strangerDb = testEnv.authenticatedContext("phase31-stranger", unprivilegedClaims("stranger@phase31-test.example")).firestore();
      const adminDb = testEnv.authenticatedContext("phase31-admin", adminClaims("admin@phase31-test.example")).firestore();

      await record("s1a_positive_owner_can_read_own_subscription",
        assertSucceeds(ownerDb.collection("subscriptions").doc("sub1").get()));
      await record("s1b_negative_stranger_cannot_read_others_subscription",
        assertFails(strangerDb.collection("subscriptions").doc("sub1").get()));
      await record("s1c_positive_admin_can_read_any_subscription",
        assertSucceeds(adminDb.collection("subscriptions").doc("sub1").get()));
      await record("s1d_positive_owner_can_create_self_attributed_subscription",
        assertSucceeds(ownerDb.collection("subscriptions").doc("sub2").set({ userId: "phase31-owner", productId: "p2", isActive: true })));
      await record("s1e_negative_cannot_create_subscription_for_someone_else",
        assertFails(strangerDb.collection("subscriptions").doc("sub3").set({ userId: "phase31-owner", productId: "p3", isActive: true })));
      await record("s1f_positive_owner_can_toggle_isActive_only",
        assertSucceeds(ownerDb.collection("subscriptions").doc("sub1").update({ isActive: false })));
      await record("s1g_negative_owner_cannot_change_other_fields",
        assertFails(ownerDb.collection("subscriptions").doc("sub1").update({ productId: "hacked" })));
      await record("s1h_positive_admin_can_toggle_isActive",
        assertSucceeds(adminDb.collection("subscriptions").doc("sub1").update({ isActive: true })));
    }

    // ============================================================
    // 2. sellerRequests/{uid} — owner-or-admin read ONLY (bank-PII
    //    rigor), self-attributed pending-only create, admin-or-still-
    //    pending-owner update, never self-approving
    // ============================================================
    {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("sellerRequests").doc("phase31-applicant").set({
          userId: "phase31-applicant", status: "pending", bankName: "Test Bank", accountNumber: "12345", ifsc: "TEST0001",
        });
      });
      const applicantDb = testEnv.authenticatedContext("phase31-applicant", unprivilegedClaims("applicant@phase31-test.example")).firestore();
      const strangerDb = testEnv.authenticatedContext("phase31-stranger2", unprivilegedClaims("stranger2@phase31-test.example")).firestore();
      const adminDb = testEnv.authenticatedContext("phase31-admin2", adminClaims("admin2@phase31-test.example")).firestore();

      await record("s2a_positive_applicant_can_read_own_request",
        assertSucceeds(applicantDb.collection("sellerRequests").doc("phase31-applicant").get()));
      await record("s2b_negative_stranger_cannot_read_bank_details_PII",
        assertFails(strangerDb.collection("sellerRequests").doc("phase31-applicant").get()));
      await record("s2c_positive_admin_can_read_any_request",
        assertSucceeds(adminDb.collection("sellerRequests").doc("phase31-applicant").get()));
      await record("s2d_positive_self_attributed_pending_create_succeeds",
        assertSucceeds(testEnv.authenticatedContext("phase31-newapplicant", unprivilegedClaims("new@phase31-test.example")).firestore()
          .collection("sellerRequests").doc("phase31-newapplicant").set({ userId: "phase31-newapplicant", status: "pending", bankName: "B", accountNumber: "1", ifsc: "X" })));
      await record("s2e_negative_cannot_create_already_approved",
        assertFails(strangerDb.collection("sellerRequests").doc("phase31-stranger2").set({ userId: "phase31-stranger2", status: "approved", bankName: "B", accountNumber: "1", ifsc: "X" })));
      await record("s2f_negative_cannot_create_for_someone_else",
        assertFails(strangerDb.collection("sellerRequests").doc("phase31-applicant").set({ userId: "phase31-stranger2", status: "pending" })));
      await record("s2g_negative_applicant_cannot_self_approve",
        assertFails(applicantDb.collection("sellerRequests").doc("phase31-applicant").update({ status: "approved" })));
      await record("s2h_positive_admin_can_approve",
        assertSucceeds(adminDb.collection("sellerRequests").doc("phase31-applicant").update({ status: "approved", reviewedAt: new Date() })));
    }

    // ============================================================
    // 3. users/{uid}/scratchCards — owner read, NO client create,
    //    isScratched-only value-guarded update
    // ============================================================
    {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("users").doc("phase31-cardowner").set({ role: "user" });
        await ctx.firestore().collection("users").doc("phase31-cardowner").collection("scratchCards").doc("card1").set({
          amount: 50, isScratched: false,
        });
      });
      const ownerDb = testEnv.authenticatedContext("phase31-cardowner", unprivilegedClaims("cardowner@phase31-test.example")).firestore();
      const strangerDb = testEnv.authenticatedContext("phase31-cardstranger", unprivilegedClaims("cardstranger@phase31-test.example")).firestore();

      await record("s3a_positive_owner_can_read_own_scratch_card",
        assertSucceeds(ownerDb.collection("users").doc("phase31-cardowner").collection("scratchCards").doc("card1").get()));
      await record("s3b_negative_stranger_cannot_read_others_scratch_card",
        assertFails(strangerDb.collection("users").doc("phase31-cardowner").collection("scratchCards").doc("card1").get()));
      await record("s3c_negative_client_cannot_create_a_scratch_card",
        assertFails(ownerDb.collection("users").doc("phase31-cardowner").collection("scratchCards").doc("card2").set({ amount: 100, isScratched: false })));
      await record("s3d_positive_owner_can_toggle_isScratched",
        assertSucceeds(ownerDb.collection("users").doc("phase31-cardowner").collection("scratchCards").doc("card1").update({ isScratched: true })));
      await record("s3e_negative_owner_cannot_change_amount",
        assertFails(ownerDb.collection("users").doc("phase31-cardowner").collection("scratchCards").doc("card1").update({ amount: 99999 })));
    }

    // ============================================================
    // 4. users/{uid}/transactions — owner read + create (reward-claim
    //    log), no update/delete
    // ============================================================
    {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("users").doc("phase31-txowner").set({ role: "user" });
      });
      const ownerDb = testEnv.authenticatedContext("phase31-txowner", unprivilegedClaims("txowner@phase31-test.example")).firestore();
      const strangerDb = testEnv.authenticatedContext("phase31-txstranger", unprivilegedClaims("txstranger@phase31-test.example")).firestore();

      await record("s4a_positive_owner_can_create_own_transaction",
        assertSucceeds(ownerDb.collection("users").doc("phase31-txowner").collection("transactions").doc("tx1").set({ type: "credit", amount: 50 })));
      await record("s4b_positive_owner_can_read_own_transactions",
        assertSucceeds(ownerDb.collection("users").doc("phase31-txowner").collection("transactions").doc("tx1").get()));
      await record("s4c_negative_stranger_cannot_read_others_transactions",
        assertFails(strangerDb.collection("users").doc("phase31-txowner").collection("transactions").doc("tx1").get()));
      await record("s4d_negative_owner_cannot_update_existing_transaction",
        assertFails(ownerDb.collection("users").doc("phase31-txowner").collection("transactions").doc("tx1").update({ amount: 999999 })));
    }

    // ============================================================
    // 5. users/{uid}/recent_searches — owner read/write (dead widget,
    //    but a real rule regardless per the owner's own decision)
    // ============================================================
    {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("users").doc("phase31-searchowner").set({ role: "user" });
      });
      const ownerDb = testEnv.authenticatedContext("phase31-searchowner", unprivilegedClaims("searchowner@phase31-test.example")).firestore();
      const strangerDb = testEnv.authenticatedContext("phase31-searchstranger", unprivilegedClaims("searchstranger@phase31-test.example")).firestore();

      await record("s5a_positive_owner_can_write_own_recent_search",
        assertSucceeds(ownerDb.collection("users").doc("phase31-searchowner").collection("recent_searches").doc("q1").set({ query: "tomato", timestamp: new Date() })));
      await record("s5b_negative_stranger_cannot_write_others_recent_search",
        assertFails(strangerDb.collection("users").doc("phase31-searchowner").collection("recent_searches").doc("q2").set({ query: "hacked" })));
      await record("s5c_negative_stranger_cannot_read_others_recent_searches",
        assertFails(strangerDb.collection("users").doc("phase31-searchowner").collection("recent_searches").doc("q1").get()));
    }

    // ============================================================
    // 6. trending_searches — public read, no client write
    // ============================================================
    {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("trending_searches").doc("t1").set({ query: "seeds", count: 100 });
      });
      const anonDb = testEnv.unauthenticatedContext().firestore();
      const userDb = testEnv.authenticatedContext("phase31-trenduser", unprivilegedClaims("trenduser@phase31-test.example")).firestore();

      await record("s6a_positive_unauthenticated_can_read_trending_searches",
        assertSucceeds(anonDb.collection("trending_searches").doc("t1").get()));
      await record("s6b_negative_authenticated_user_cannot_write_trending_searches",
        assertFails(userDb.collection("trending_searches").doc("t2").set({ query: "hacked", count: 1 })));
    }

    // ============================================================
    // 7. masterProducts — authenticated read, no client write
    // ============================================================
    {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("masterProducts").doc("mp1").set({ name: "Tomato Seeds" });
      });
      const userDb = testEnv.authenticatedContext("phase31-mpuser", unprivilegedClaims("mpuser@phase31-test.example")).firestore();
      const anonDb = testEnv.unauthenticatedContext().firestore();

      await record("s7a_positive_authenticated_user_can_read_master_products",
        assertSucceeds(userDb.collection("masterProducts").doc("mp1").get()));
      await record("s7b_negative_unauthenticated_cannot_read_master_products",
        assertFails(anonDb.collection("masterProducts").doc("mp1").get()));
      await record("s7c_negative_authenticated_user_cannot_write_master_products",
        assertFails(userDb.collection("masterProducts").doc("mp2").set({ name: "hacked" })));
    }

    // ============================================================
    // 8. centers — authenticated read, no client write
    // ============================================================
    {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("centers").doc("c1").set({ name: "Chennai" });
      });
      const userDb = testEnv.authenticatedContext("phase31-centeruser", unprivilegedClaims("centeruser@phase31-test.example")).firestore();

      await record("s8a_positive_authenticated_user_can_read_centers",
        assertSucceeds(userDb.collection("centers").doc("c1").get()));
      await record("s8b_negative_authenticated_user_cannot_write_centers",
        assertFails(userDb.collection("centers").doc("c2").set({ name: "hacked" })));
    }

    // ============================================================
    // 9. product_price_mappings — authenticated read, seller-self-
    //    attributed create/update; the non-seller-suffixed shared
    //    base-price shape is naturally unwritable by any client
    // ============================================================
    {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("product_price_mappings").doc("mp1_c1").set({ effectivePrice: 40 }); // shared base price, no sellerId
      });
      const sellerDb = testEnv.authenticatedContext("phase31-priceseller", unprivilegedClaims("priceseller@phase31-test.example")).firestore();
      const strangerDb = testEnv.authenticatedContext("phase31-pricestranger", unprivilegedClaims("pricestranger@phase31-test.example")).firestore();
      const anonDb = testEnv.unauthenticatedContext().firestore();

      await record("s9a_positive_authenticated_can_read_price_mappings",
        assertSucceeds(sellerDb.collection("product_price_mappings").doc("mp1_c1").get()));
      await record("s9b_negative_unauthenticated_cannot_read_price_mappings",
        assertFails(anonDb.collection("product_price_mappings").doc("mp1_c1").get()));
      await record("s9c_positive_seller_can_create_self_attributed_mapping",
        assertSucceeds(sellerDb.collection("product_price_mappings").doc("mp1_c1_phase31-priceseller").set({ sellerId: "phase31-priceseller", effectivePrice: 35 })));
      await record("s9d_negative_seller_cannot_create_mapping_for_another_seller",
        assertFails(strangerDb.collection("product_price_mappings").doc("mp1_c1_phase31-priceseller").set({ sellerId: "phase31-priceseller", effectivePrice: 1 })));
      await record("s9e_negative_client_cannot_write_the_shared_base_price_doc",
        assertFails(sellerDb.collection("product_price_mappings").doc("mp1_c1").set({ effectivePrice: 999 })));
    }

    // ============================================================
    // 10. subscription_plans — admin-only read and write
    // ============================================================
    {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("subscription_plans").doc("plan1").set({ name: "Weekly", price: 100 });
      });
      const adminDb = testEnv.authenticatedContext("phase31-planadmin", adminClaims("planadmin@phase31-test.example")).firestore();
      const userDb = testEnv.authenticatedContext("phase31-planuser", unprivilegedClaims("planuser@phase31-test.example")).firestore();

      await record("s10a_positive_admin_can_read_subscription_plans",
        assertSucceeds(adminDb.collection("subscription_plans").doc("plan1").get()));
      await record("s10b_negative_authenticated_user_cannot_read_subscription_plans",
        assertFails(userDb.collection("subscription_plans").doc("plan1").get()));
      await record("s10c_positive_admin_can_create_subscription_plans",
        assertSucceeds(adminDb.collection("subscription_plans").doc("plan2").set({ name: "Monthly", price: 300 })));
      await record("s10d_negative_authenticated_user_cannot_create_subscription_plans",
        assertFails(userDb.collection("subscription_plans").doc("plan3").set({ name: "hacked", price: 0 })));
    }

    console.log("\n=== PHASE 31 SUMMARY ===");
    const total = Object.keys(results).length;
    const passed = Object.values(results).filter((v) => v === "PASSED").length;
    for (const [k, v] of Object.entries(results)) console.log(`  ${v === "PASSED" ? "PASS" : "FAIL"}  ${k}`);
    console.log(`\n${passed}/${total} scenarios passed`);
    if (passed !== total) { console.error("PHASE 31: FAILED"); process.exitCode = 1; }
    else console.log("PHASE 31: ALL PASSED");
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((e) => {
  console.error("PHASE 31: harness error", e);
  process.exit(1);
});
