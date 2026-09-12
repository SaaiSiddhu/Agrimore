// Phase HOME-3 — proves the new `home_product_sections` collection rules
// (public read like its siblings banners/section_banners/category_section_
// slots; admin-only write). Mirrors phase30_rules_hygiene_test.js's
// @firebase/rules-unit-testing pattern.
//
// Run with: firebase emulators:exec --only firestore
//             "node scripts/phase53_home_product_sections_rules_test.js"
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

const SECTION_DOC = {
  categoryId: "cat-dairy",
  titleOverride: null,
  maxItems: 10,
  position: 1,
  isActive: true,
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
      await ctx.firestore().collection("home_product_sections").doc("s1").set(SECTION_DOC);
    });

    const anonDb = testEnv.unauthenticatedContext().firestore();
    const userDb = testEnv.authenticatedContext("home3-user1", unprivilegedClaims("u1@home3-test.example")).firestore();
    const adminDb = testEnv.authenticatedContext("home3-admin1", adminClaims("admin1@home3-test.example")).firestore();

    // 1. Public read (matches banners/section_banners/category_section_slots)
    await record("h1_positive_anonymous_can_read_section",
      assertSucceeds(anonDb.collection("home_product_sections").doc("s1").get()));
    await record("h2_positive_authenticated_user_can_read_section",
      assertSucceeds(userDb.collection("home_product_sections").doc("s1").get()));

    // 2. Write is admin-only
    await record("h3_negative_authenticated_user_cannot_create_section",
      assertFails(userDb.collection("home_product_sections").doc("s2").set(SECTION_DOC)));
    await record("h4_negative_authenticated_user_cannot_update_section",
      assertFails(userDb.collection("home_product_sections").doc("s1").update({ maxItems: 99 })));
    await record("h5_negative_authenticated_user_cannot_delete_section",
      assertFails(userDb.collection("home_product_sections").doc("s1").delete()));
    await record("h6_positive_admin_can_create_section",
      assertSucceeds(adminDb.collection("home_product_sections").doc("s2").set(SECTION_DOC)));
    await record("h7_positive_admin_can_update_section",
      assertSucceeds(adminDb.collection("home_product_sections").doc("s1").update({ maxItems: 12 })));
    await record("h8_positive_admin_can_delete_section",
      assertSucceeds(adminDb.collection("home_product_sections").doc("s2").delete()));

    // 3. Regression control: an unrelated sibling collection's own rules
    // (category_section_slots) are unaffected by this new block.
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("category_section_slots").doc("cs1").set({ position: 1, sectionName: "Test" });
    });
    await record("h9_regression_category_section_slots_read_unaffected",
      assertSucceeds(anonDb.collection("category_section_slots").doc("cs1").get()));

    console.log("\n=== PHASE 53 SUMMARY ===");
    const total = Object.keys(results).length;
    const passed = Object.values(results).filter((v) => v === "PASSED").length;
    for (const [k, v] of Object.entries(results)) console.log(`  ${v === "PASSED" ? "PASS" : "FAIL"}  ${k}`);
    console.log(`\n${passed}/${total} scenarios passed`);
    if (passed !== total) { console.error("PHASE 53: FAILED"); process.exitCode = 1; }
    else console.log("PHASE 53: ALL PASSED");
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((e) => {
  console.error("PHASE 53: harness error", e);
  process.exit(1);
});
