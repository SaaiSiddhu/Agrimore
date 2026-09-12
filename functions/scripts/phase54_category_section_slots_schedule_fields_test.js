// Phase HOME-4 — proves the EXISTING `category_section_slots` rule (public
// read; admin-only write, no field-level validation) is unchanged and
// correctly tolerates the new startsAt/endsAt fields: readable whether a
// doc has them or not (legacy docs have neither), still admin-only to
// write/update, and an admin can both set and clear them. Mirrors
// phase30_rules_hygiene_test.js's @firebase/rules-unit-testing pattern,
// same as phase52/phase53.
//
// Run with: firebase emulators:exec --only firestore
//             "node scripts/phase54_category_section_slots_schedule_fields_test.js"
const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const { Timestamp } = require("firebase/firestore");

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

const LEGACY_DOC = { position: 1, sectionName: "Grocery & Kitchen", categoryIds: ["cat1"], isActive: true };
const SCHEDULED_DOC = {
  ...LEGACY_DOC,
  startsAt: Timestamp.fromDate(new Date("2026-01-01T00:00:00Z")),
  endsAt: Timestamp.fromDate(new Date("2026-12-31T00:00:00Z")),
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
      await ctx.firestore().collection("category_section_slots").doc("legacy1").set(LEGACY_DOC);
      await ctx.firestore().collection("category_section_slots").doc("sched1").set(SCHEDULED_DOC);
    });

    const anonDb = testEnv.unauthenticatedContext().firestore();
    const userDb = testEnv.authenticatedContext("home4-user1", unprivilegedClaims("u1@home4-test.example")).firestore();
    const adminDb = testEnv.authenticatedContext("home4-admin1", adminClaims("admin1@home4-test.example")).firestore();

    // 1. Public read is unaffected by the new fields either way.
    await record("c1_positive_anonymous_can_read_legacy_doc_without_schedule_fields",
      assertSucceeds(anonDb.collection("category_section_slots").doc("legacy1").get()));
    await record("c2_positive_anonymous_can_read_doc_with_schedule_fields",
      assertSucceeds(anonDb.collection("category_section_slots").doc("sched1").get()));
    await record("c3_positive_authenticated_user_can_read_doc_with_schedule_fields",
      assertSucceeds(userDb.collection("category_section_slots").doc("sched1").get()));

    // 2. Write stays admin-only -- adding schedule fields grants no new
    // capability to an ordinary signed-in user.
    await record("c4_negative_authenticated_user_cannot_create_doc_with_schedule_fields",
      assertFails(userDb.collection("category_section_slots").doc("u-created").set(SCHEDULED_DOC)));
    await record("c5_negative_authenticated_user_cannot_set_schedule_fields_on_existing_doc",
      assertFails(userDb.collection("category_section_slots").doc("legacy1").update({
        startsAt: Timestamp.fromDate(new Date("2026-01-01T00:00:00Z")),
      })));

    // 3. Admin can create, set, and clear the new fields -- the exact
    // actions the WS2 admin screen now performs.
    await record("c6_positive_admin_can_create_doc_with_schedule_fields",
      assertSucceeds(adminDb.collection("category_section_slots").doc("admin-created").set(SCHEDULED_DOC)));
    await record("c7_positive_admin_can_add_schedule_fields_to_legacy_doc",
      assertSucceeds(adminDb.collection("category_section_slots").doc("legacy1").update({
        startsAt: Timestamp.fromDate(new Date("2026-06-01T00:00:00Z")),
        endsAt: Timestamp.fromDate(new Date("2026-06-30T00:00:00Z")),
      })));
    await record("c8_positive_admin_can_clear_schedule_fields_back_to_null",
      assertSucceeds(adminDb.collection("category_section_slots").doc("sched1").update({
        startsAt: null,
        endsAt: null,
      })));

    console.log("\n=== PHASE 54 SUMMARY ===");
    const total = Object.keys(results).length;
    const passed = Object.values(results).filter((v) => v === "PASSED").length;
    for (const [k, v] of Object.entries(results)) console.log(`  ${v === "PASSED" ? "PASS" : "FAIL"}  ${k}`);
    console.log(`\n${passed}/${total} scenarios passed`);
    if (passed !== total) { console.error("PHASE 54: FAILED"); process.exitCode = 1; }
    else console.log("PHASE 54: ALL PASSED");
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((e) => {
  console.error("PHASE 54: harness error", e);
  process.exit(1);
});
