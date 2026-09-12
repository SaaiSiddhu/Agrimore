// Phase HOME-2 — proves the settings/location_settings read-access widening
// (isAuthenticated(), mirroring settings/access and settings/wallet_config
// exactly) against the real rules engine: a signed-in customer can read the
// Home app bar's delivery-promise config, an anonymous caller cannot, and
// the settings/{docId} floor's admin-only write is untouched (this phase
// changed no write rule at all — the catch-all's isAdmin() write already
// covered this document before and after).
//
// Mirrors phase30_rules_hygiene_test.js's @firebase/rules-unit-testing
// pattern. Run with:
//   firebase emulators:exec --only firestore "node scripts/phase52_location_settings_rules_test.js"
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

const SETTINGS_DOC = {
  isHyperlocalEnabled: true,
  maxRadiusKm: 50,
  activeLocations: ["Chennai", "Madurai", "Theni"],
  defaultEtaText: "10-15 mins",
  unserviceableText: "Not currently serviceable",
  cityEtaOverrides: { chennai: "15-20 mins" },
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
      await ctx.firestore().collection("settings").doc("location_settings").set(SETTINGS_DOC);
    });

    const userDb = testEnv.authenticatedContext("home2-user1", unprivilegedClaims("u1@home2-test.example")).firestore();
    const adminDb = testEnv.authenticatedContext("home2-admin1", adminClaims("admin1@home2-test.example")).firestore();
    const anonDb = testEnv.unauthenticatedContext().firestore();

    // 1. The new read widening: any signed-in customer can read it (this is
    // what apps/marketplace's LocationSettingsProvider needs to work at all).
    await record("l1_positive_authenticated_user_can_read_location_settings",
      assertSucceeds(userDb.collection("settings").doc("location_settings").get()));

    // 2. Negative control: anonymous still cannot (Home is behind login;
    // this document is not meant to be public like associate_onboarding).
    await record("l2_negative_anonymous_cannot_read_location_settings",
      assertFails(anonDb.collection("settings").doc("location_settings").get()));

    // 3. Admin can always read it (unaffected either way).
    await record("l3_positive_admin_can_read_location_settings",
      assertSucceeds(adminDb.collection("settings").doc("location_settings").get()));

    // 4. Write side untouched: this phase declared no new write rule, so
    // the settings/{docId} floor's isAdmin()-only write still applies.
    await record("l4a_negative_authenticated_user_cannot_write_location_settings",
      assertFails(userDb.collection("settings").doc("location_settings").update({ defaultEtaText: "5 mins" })));
    await record("l4b_positive_admin_can_write_location_settings",
      assertSucceeds(adminDb.collection("settings").doc("location_settings").update({ defaultEtaText: "5 mins" })));

    // 5. Regression control: a sibling settings/{docId} this phase did NOT
    // touch (wallet_config) keeps its own pre-existing isAuthenticated()
    // read — the new location_settings block must not have widened or
    // narrowed anything else via the catch-all's OR semantics.
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("settings").doc("wallet_config").set({ minTopup: 100 });
    });
    await record("l5_regression_wallet_config_read_unaffected",
      assertSucceeds(userDb.collection("settings").doc("wallet_config").get()));

    console.log("\n=== PHASE 52 SUMMARY ===");
    const total = Object.keys(results).length;
    const passed = Object.values(results).filter((v) => v === "PASSED").length;
    for (const [k, v] of Object.entries(results)) console.log(`  ${v === "PASSED" ? "PASS" : "FAIL"}  ${k}`);
    console.log(`\n${passed}/${total} scenarios passed`);
    if (passed !== total) { console.error("PHASE 52: FAILED"); process.exitCode = 1; }
    else console.log("PHASE 52: ALL PASSED");
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((e) => {
  console.error("PHASE 52: harness error", e);
  process.exit(1);
});
