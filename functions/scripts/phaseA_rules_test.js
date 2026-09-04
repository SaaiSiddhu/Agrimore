// Phase A — Customer Product Benefit Program compliance/feature-flag gate.
// Proves the three new firestore.rules blocks (feature_flags,
// compliance_config, compliance_audit_log) against the real rules engine.
// Mirrors phase14_rules_test.js/phase15_rules_test.js's
// @firebase/rules-unit-testing pattern exactly, including positive
// controls alongside every negative one.
// Run with: node scripts/phaseA_rules_test.js
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

  try {
    // ============================================
    // 1 — unauthenticated user CAN read feature_flags
    // ============================================
    {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("feature_flags").doc("benefit_program").set({
          BENEFIT_PROGRAM_ENABLED: false,
        });
      });
      const db = testEnv.unauthenticatedContext().firestore();
      try {
        await assertSucceeds(db.collection("feature_flags").doc("benefit_program").get());
        results.r1_unauthenticated_can_read_feature_flags =
          "PASSED — an unauthenticated client can read feature_flags/benefit_program";
      } catch (e) {
        results.r1_unauthenticated_can_read_feature_flags = `FAILED — unauthenticated read was rejected: ${e.message}`;
      }
    }

    // ============================================
    // 2 — authenticated non-admin CANNOT read compliance_config
    // ============================================
    {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("compliance_config").doc("benefit_program").set({
          legalReviewStatus: "NOT_STARTED",
        });
      });
      const uid = "phaseA-nonadmin";
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("nonadmin@phaseA-test.example")).firestore();
      try {
        await assertFails(db.collection("compliance_config").doc("benefit_program").get());
        results.r2_nonadmin_cannot_read_compliance_config =
          "PASSED — a non-admin authenticated client cannot read compliance_config";
      } catch (e) {
        results.r2_nonadmin_cannot_read_compliance_config = `FAILED — non-admin read succeeded: ${e.message}`;
      }
    }

    // ============================================
    // 3 — admin CAN read compliance_config
    // ============================================
    {
      const uid = "phaseA-admin-reader";
      const db = testEnv.authenticatedContext(uid, adminClaims("admin-reader@phaseA-test.example")).firestore();
      try {
        await assertSucceeds(db.collection("compliance_config").doc("benefit_program").get());
        results.r3_admin_can_read_compliance_config = "PASSED — an admin can read compliance_config";
      } catch (e) {
        results.r3_admin_can_read_compliance_config = `FAILED — admin read was rejected: ${e.message}`;
      }
    }

    // ============================================
    // 4 — admin CANNOT directly write compliance_config (CF-only)
    // ============================================
    {
      const uid = "phaseA-admin-writer";
      const db = testEnv.authenticatedContext(uid, adminClaims("admin-writer@phaseA-test.example")).firestore();
      try {
        await assertFails(
          db.collection("compliance_config").doc("benefit_program").set({ legalReviewStatus: "APPROVED" })
        );
        results.r4_admin_cannot_directly_write_compliance_config =
          "PASSED — an admin client cannot write compliance_config directly (must go through setComplianceStatus)";
      } catch (e) {
        results.r4_admin_cannot_directly_write_compliance_config = `FAILED — direct admin write succeeded: ${e.message}`;
      }
    }

    // ============================================
    // 5 — admin CANNOT directly write feature_flags (CF-only)
    // ============================================
    {
      const uid = "phaseA-admin-flag-writer";
      const db = testEnv.authenticatedContext(uid, adminClaims("admin-flag-writer@phaseA-test.example")).firestore();
      try {
        await assertFails(
          db.collection("feature_flags").doc("benefit_program").set({ BENEFIT_PROGRAM_ENABLED: true })
        );
        results.r5_admin_cannot_directly_write_feature_flags =
          "PASSED — an admin client cannot write feature_flags directly (must go through setBenefitFeatureFlag)";
      } catch (e) {
        results.r5_admin_cannot_directly_write_feature_flags = `FAILED — direct admin write succeeded: ${e.message}`;
      }
    }

    // ============================================
    // 6 — admin CANNOT write compliance_audit_log
    // ============================================
    {
      const uid = "phaseA-admin-audit-writer";
      const db = testEnv.authenticatedContext(uid, adminClaims("admin-audit-writer@phaseA-test.example")).firestore();
      try {
        await assertFails(
          db.collection("compliance_audit_log").add({ actorUid: uid, action: "forged", target: "x" })
        );
        results.r6_admin_cannot_write_audit_log =
          "PASSED — an admin client cannot create a compliance_audit_log entry directly";
      } catch (e) {
        results.r6_admin_cannot_write_audit_log = `FAILED — direct admin audit-log create succeeded: ${e.message}`;
      }
    }

    // ============================================
    // 7 — admin CANNOT update or delete an existing audit entry
    // ============================================
    {
      const entryId = "phaseA-existing-entry";
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("compliance_audit_log").doc(entryId).set({
          actorUid: "someone",
          action: "setBenefitFeatureFlag",
          target: "BENEFIT_PROGRAM_ENABLED",
          previousValue: false,
          newValue: true,
          reason: "seed",
        });
      });
      const uid = "phaseA-admin-audit-tamperer";
      const db = testEnv.authenticatedContext(uid, adminClaims("admin-tamperer@phaseA-test.example")).firestore();
      try {
        await assertFails(db.collection("compliance_audit_log").doc(entryId).update({ reason: "tampered" }));
        results.r7a_admin_cannot_update_audit_entry = "PASSED — updating an existing audit entry was rejected";
      } catch (e) {
        results.r7a_admin_cannot_update_audit_entry = `FAILED — an admin updated an audit entry: ${e.message}`;
      }
      try {
        await assertFails(db.collection("compliance_audit_log").doc(entryId).delete());
        results.r7b_admin_cannot_delete_audit_entry = "PASSED — deleting an existing audit entry was rejected";
      } catch (e) {
        results.r7b_admin_cannot_delete_audit_entry = `FAILED — an admin deleted an audit entry: ${e.message}`;
      }
    }
  } finally {
    await testEnv.cleanup();
  }

  console.log("=== PHASE A — COMPLIANCE/FEATURE-FLAG RULES TEST ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);

  const allPassed = Object.values(results).every((v) => v.startsWith("PASSED"));
  console.log(allPassed ? "\nALL PASSED" : "\nSOME FAILED");
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phaseA rules test:", e);
  process.exit(1);
});
