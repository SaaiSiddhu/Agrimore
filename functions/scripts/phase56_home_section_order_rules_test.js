// Phase HOME-9 — proves the settings/home_section_order read-access widening
// (isAuthenticated(), mirroring settings/location_settings and
// settings/home_grocery_strip_config exactly) against the real rules engine:
// a signed-in customer can read the admin-configured mobile/web section
// order, an anonymous caller cannot, and the settings/{docId} floor's
// admin-only write is untouched (this phase declared no new write rule at
// all).
//
// Mirrors phase55_home_grocery_strip_config_rules_test.js's
// @firebase/rules-unit-testing pattern. Run with:
//   firebase emulators:exec --only firestore "node scripts/phase56_home_section_order_rules_test.js"
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

const CONFIG_DOC = {
  mobileOrder: [
    "grocery_kitchen_strip",
    "bestsellers",
    "recently_viewed",
    "dynamic_category_sections",
    "product_sections",
  ],
  webOrder: [
    "categories_grid",
    "recently_viewed",
    "bestsellers",
    "grocery_kitchen_strip",
    "dynamic_category_sections",
    "product_sections",
  ],
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
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("settings").doc("home_section_order").set(CONFIG_DOC);
    });

    const userDb = testEnv.authenticatedContext("home9-user1", unprivilegedClaims("u1@home9-test.example")).firestore();
    const adminDb = testEnv.authenticatedContext("home9-admin1", adminClaims("admin1@home9-test.example")).firestore();
    const anonDb = testEnv.unauthenticatedContext().firestore();

    // 1. The new read widening: any signed-in customer can read it (this is
    // what apps/marketplace's HomeSectionOrderProvider needs to work on
    // both mobile_home_screen.dart and web_home_screen.dart).
    await record("h1_positive_authenticated_user_can_read_config",
      assertSucceeds(userDb.collection("settings").doc("home_section_order").get()));

    // 2. Negative control: anonymous still cannot (Home is behind login;
    // this document is not meant to be public like associate_onboarding).
    await record("h2_negative_anonymous_cannot_read_config",
      assertFails(anonDb.collection("settings").doc("home_section_order").get()));

    // 3. Admin can always read it (unaffected either way).
    await record("h3_positive_admin_can_read_config",
      assertSucceeds(adminDb.collection("settings").doc("home_section_order").get()));

    // 4. Write side untouched: this phase declared no new write rule, so
    // the settings/{docId} floor's isAdmin()-only write still applies.
    await record("h4a_negative_authenticated_user_cannot_write_config",
      assertFails(userDb.collection("settings").doc("home_section_order").update({ mobileOrder: ["bestsellers"] })));
    await record("h4b_positive_admin_can_write_config",
      assertSucceeds(adminDb.collection("settings").doc("home_section_order").update({ mobileOrder: ["bestsellers", "grocery_kitchen_strip", "recently_viewed", "dynamic_category_sections", "product_sections"] })));

    // 5. Regression control: sibling settings/{docId} documents this phase
    // did NOT touch (location_settings, home_grocery_strip_config) keep
    // their own pre-existing isAuthenticated() read — the new block must
    // not have widened or narrowed anything else via the catch-all's OR
    // semantics.
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("settings").doc("location_settings").set({ defaultEtaText: "10 mins" });
      await ctx.firestore().collection("settings").doc("home_grocery_strip_config").set({ titleOverride: "Fresh Picks" });
    });
    await record("h5a_regression_location_settings_read_unaffected",
      assertSucceeds(userDb.collection("settings").doc("location_settings").get()));
    await record("h5b_regression_home_grocery_strip_config_read_unaffected",
      assertSucceeds(userDb.collection("settings").doc("home_grocery_strip_config").get()));

    console.log("\n=== PHASE 56 SUMMARY ===");
    const total = Object.keys(results).length;
    const passed = Object.values(results).filter((v) => v === "PASSED").length;
    for (const [k, v] of Object.entries(results)) console.log(`  ${v === "PASSED" ? "PASS" : "FAIL"}  ${k}`);
    console.log(`\n${passed}/${total} scenarios passed`);
    if (passed !== total) { console.error("PHASE 56: FAILED"); process.exitCode = 1; }
    else console.log("PHASE 56: ALL PASSED");
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((e) => {
  console.error("PHASE 56: harness error", e);
  process.exit(1);
});
