// Phase HOME-5 — proves the settings/home_grocery_strip_config read-access
// widening (isAuthenticated(), mirroring settings/location_settings exactly)
// against the real rules engine: a signed-in customer can read
// GroceryKitchenHomeStrip's title/category override, an anonymous caller
// cannot, and the settings/{docId} floor's admin-only write is untouched
// (this phase declared no new write rule at all).
//
// Mirrors phase52_location_settings_rules_test.js's
// @firebase/rules-unit-testing pattern. Run with:
//   firebase emulators:exec --only firestore "node scripts/phase55_home_grocery_strip_config_rules_test.js"
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
  categoryIds: ["cat-snacks", "cat-beauty"],
  titleOverride: "Handpicked For You",
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
      await ctx.firestore().collection("settings").doc("home_grocery_strip_config").set(CONFIG_DOC);
    });

    const userDb = testEnv.authenticatedContext("home5-user1", unprivilegedClaims("u1@home5-test.example")).firestore();
    const adminDb = testEnv.authenticatedContext("home5-admin1", adminClaims("admin1@home5-test.example")).firestore();
    const anonDb = testEnv.unauthenticatedContext().firestore();

    // 1. The new read widening: any signed-in customer can read it (this is
    // what apps/marketplace's HomeGroceryStripConfigProvider needs to work).
    await record("g1_positive_authenticated_user_can_read_config",
      assertSucceeds(userDb.collection("settings").doc("home_grocery_strip_config").get()));

    // 2. Negative control: anonymous still cannot (Home is behind login;
    // this document is not meant to be public like associate_onboarding).
    await record("g2_negative_anonymous_cannot_read_config",
      assertFails(anonDb.collection("settings").doc("home_grocery_strip_config").get()));

    // 3. Admin can always read it (unaffected either way).
    await record("g3_positive_admin_can_read_config",
      assertSucceeds(adminDb.collection("settings").doc("home_grocery_strip_config").get()));

    // 4. Write side untouched: this phase declared no new write rule, so
    // the settings/{docId} floor's isAdmin()-only write still applies.
    await record("g4a_negative_authenticated_user_cannot_write_config",
      assertFails(userDb.collection("settings").doc("home_grocery_strip_config").update({ titleOverride: "Hacked" })));
    await record("g4b_positive_admin_can_write_config",
      assertSucceeds(adminDb.collection("settings").doc("home_grocery_strip_config").update({ titleOverride: "Fresh Picks" })));

    // 5. Regression control: a sibling settings/{docId} this phase did NOT
    // touch (location_settings) keeps its own pre-existing isAuthenticated()
    // read — the new block must not have widened or narrowed anything else
    // via the catch-all's OR semantics.
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("settings").doc("location_settings").set({ defaultEtaText: "10 mins" });
    });
    await record("g5_regression_location_settings_read_unaffected",
      assertSucceeds(userDb.collection("settings").doc("location_settings").get()));

    console.log("\n=== PHASE 55 SUMMARY ===");
    const total = Object.keys(results).length;
    const passed = Object.values(results).filter((v) => v === "PASSED").length;
    for (const [k, v] of Object.entries(results)) console.log(`  ${v === "PASSED" ? "PASS" : "FAIL"}  ${k}`);
    console.log(`\n${passed}/${total} scenarios passed`);
    if (passed !== total) { console.error("PHASE 55: FAILED"); process.exitCode = 1; }
    else console.log("PHASE 55: ALL PASSED");
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((e) => {
  console.error("PHASE 55: harness error", e);
  process.exit(1);
});
