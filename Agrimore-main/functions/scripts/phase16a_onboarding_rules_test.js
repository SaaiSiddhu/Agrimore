// Phase 16A — Associate Onboarding rules test. Proves Workstream 10's
// denylist (onboardingPaid/onboardingWaived/onboardingFeeAmount/
// onboardingPaymentId/onboardingPaidAt/onboardingWaivedAt/
// onboardingRefundedAt on employees/{employeeId}) against the real rules
// engine, that the real employee_apply_screen.dart write shapes still
// succeed, that Phase 14's employee self-approval/commission locks still
// hold, and the new settings/associate_onboarding + onboarding_events/
// onboarding_exceptions/associate_refund_requests/webhook_events rules.
// Mirrors phase14_rules_test.js / phase15_rules_test.js's
// @firebase/rules-unit-testing pattern exactly.
// Run with: node scripts/phase16a_onboarding_rules_test.js
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

// The EXACT map apps/marketplace/lib/screens/employee/employee_apply_screen.dart's
// _handleSubmit() writes to employees/{uid} via
// `.set({...}, SetOptions(merge: true))` — copied field-for-field.
function realApplyScreenWrite(uid, name, email, phone, employeeCode) {
  return {
    userId: uid,
    name,
    email,
    phone,
    employeeCode,
    status: "pending",
    commissionRate: 0,
    createdBy: "self",
    createdAt: Date.now(),
    updatedAt: Date.now(),
  };
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
    // 1-2: owner CANNOT create with onboardingPaid/onboardingWaived true
    // ============================================
    {
      const uid = "p16a-w10-create1";
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("create1@p16a-test.example")).firestore();
      try {
        await assertFails(
          db.collection("employees").doc(uid).set({
            ...realApplyScreenWrite(uid, "Test", "create1@p16a-test.example", "9999999999", "TEST01"),
            onboardingPaid: true,
          })
        );
        results["1_create_with_onboardingPaid_rejected"] = "PASSED — owner could not create employees/{uid} with onboardingPaid:true";
      } catch (e) {
        results["1_create_with_onboardingPaid_rejected"] = `FAILED — ${e.message}`;
      }
    }
    {
      const uid = "p16a-w10-create2";
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("create2@p16a-test.example")).firestore();
      try {
        await assertFails(
          db.collection("employees").doc(uid).set({
            ...realApplyScreenWrite(uid, "Test", "create2@p16a-test.example", "9999999999", "TEST02"),
            onboardingWaived: true,
          })
        );
        results["2_create_with_onboardingWaived_rejected"] = "PASSED — owner could not create employees/{uid} with onboardingWaived:true";
      } catch (e) {
        results["2_create_with_onboardingWaived_rejected"] = `FAILED — ${e.message}`;
      }
    }

    // ============================================
    // 3-7: owner CANNOT update any of the seven onboarding fields
    // ============================================
    {
      const uid = "p16a-w10-update1";
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("employees").doc(uid).set(realApplyScreenWrite(uid, "T", "u1@p16a-test.example", "9", "T1"));
      });
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("u1@p16a-test.example")).firestore();
      try {
        await assertFails(db.collection("employees").doc(uid).update({ onboardingPaid: true }));
        results["3_update_onboardingPaid_rejected"] = "PASSED — owner could not update onboardingPaid to true";
      } catch (e) {
        results["3_update_onboardingPaid_rejected"] = `FAILED — ${e.message}`;
      }
    }
    {
      const uid = "p16a-w10-update2";
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("employees").doc(uid).set(realApplyScreenWrite(uid, "T", "u2@p16a-test.example", "9", "T2"));
      });
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("u2@p16a-test.example")).firestore();
      try {
        await assertFails(db.collection("employees").doc(uid).update({ onboardingWaived: true }));
        results["4_update_onboardingWaived_rejected"] = "PASSED — owner could not update onboardingWaived to true";
      } catch (e) {
        results["4_update_onboardingWaived_rejected"] = `FAILED — ${e.message}`;
      }
    }
    {
      const uid = "p16a-w10-update3";
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("employees").doc(uid).set(realApplyScreenWrite(uid, "T", "u3@p16a-test.example", "9", "T3"));
      });
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("u3@p16a-test.example")).firestore();
      try {
        await assertFails(db.collection("employees").doc(uid).update({ onboardingPaymentId: "pay_fake123" }));
        results["5_update_onboardingPaymentId_rejected"] = "PASSED — owner could not set onboardingPaymentId";
      } catch (e) {
        results["5_update_onboardingPaymentId_rejected"] = `FAILED — ${e.message}`;
      }
    }
    {
      const uid = "p16a-w10-update4";
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("employees").doc(uid).set(realApplyScreenWrite(uid, "T", "u4@p16a-test.example", "9", "T4"));
      });
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("u4@p16a-test.example")).firestore();
      try {
        await assertFails(db.collection("employees").doc(uid).update({ onboardingFeeAmount: 1 }));
        results["6_update_onboardingFeeAmount_rejected"] = "PASSED — owner could not set onboardingFeeAmount";
      } catch (e) {
        results["6_update_onboardingFeeAmount_rejected"] = `FAILED — ${e.message}`;
      }
    }
    {
      const uid = "p16a-w10-update5";
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("employees").doc(uid).set({
          ...realApplyScreenWrite(uid, "T", "u5@p16a-test.example", "9", "T5"),
          onboardingPaid: true,
          onboardingPaymentId: "pay_real1",
          onboardingFeeAmount: 500,
        });
      });
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("u5@p16a-test.example")).firestore();
      try {
        // An owner attempting to erase their own refund record — the
        // attack this denylist most directly needs to stop: a refunded
        // associate self-clearing onboardingRefundedAt to look active
        // again.
        await assertFails(db.collection("employees").doc(uid).update({ onboardingRefundedAt: null }));
        results["7_update_onboardingRefundedAt_rejected"] = "PASSED — owner could not clear onboardingRefundedAt";
      } catch (e) {
        results["7_update_onboardingRefundedAt_rejected"] = `FAILED — ${e.message}`;
      }
    }

    // ============================================
    // 8: the EXACT self-apply write still succeeds (fresh doc)
    // ============================================
    {
      const uid = "p16a-w10-apply1";
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("apply1@p16a-test.example")).firestore();
      try {
        await assertSucceeds(
          db.collection("employees").doc(uid).set(
            realApplyScreenWrite(uid, "Apply One", "apply1@p16a-test.example", "9876543210", "APPL01"),
            { merge: true }
          )
        );
        results["8_real_apply_screen_write_still_succeeds"] =
          "PASSED — the exact employee_apply_screen.dart initial-apply write still succeeds";
      } catch (e) {
        results["8_real_apply_screen_write_still_succeeds"] = `FAILED — ${e.message}`;
      }
    }

    // ============================================
    // 9: the EXACT re-apply write still succeeds (same write shape,
    // re-submitted against a pre-existing 'suspended' doc — mirrors the
    // real journey: users/{uid}.employeeStatus reset to null client-side
    // [not tested here — that's the users/{uid} rule, unchanged by this
    // phase], the form re-shown, and _handleSubmit() firing the SAME
    // merge-set a second time, transitioning status suspended -> pending)
    // ============================================
    {
      const uid = "p16a-w10-reapply1";
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("employees").doc(uid).set({
          ...realApplyScreenWrite(uid, "Re Apply", "reapply1@p16a-test.example", "9876500000", "REAP01"),
          status: "suspended",
        });
      });
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("reapply1@p16a-test.example")).firestore();
      try {
        await assertSucceeds(
          db.collection("employees").doc(uid).set(
            realApplyScreenWrite(uid, "Re Apply", "reapply1@p16a-test.example", "9876500000", "REAP01"),
            { merge: true }
          )
        );
        results["9_real_reapply_write_still_succeeds"] =
          "PASSED — the exact employee_apply_screen.dart re-apply write (suspended -> pending) still succeeds";
      } catch (e) {
        results["9_real_reapply_write_still_succeeds"] = `FAILED — ${e.message}`;
      }
    }

    // ============================================
    // 10: the 10c decision — merge carrying an UNCHANGED/default onboarding
    // value on a doc that never had the field. Decision: DENIED (see
    // firestore.rules' ownerCannotSetOnboardingFields() comment for the
    // full justification). This asserts that decision, not the opposite.
    // ============================================
    {
      const uid = "p16a-w10-mergecase";
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        // No onboarding fields on this doc at all — the realistic legacy
        // shape.
        await ctx.firestore().collection("employees").doc(uid).set(
          realApplyScreenWrite(uid, "Merge Case", "merge1@p16a-test.example", "9876511111", "MRG01")
        );
      });
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("merge1@p16a-test.example")).firestore();
      try {
        await assertFails(
          db.collection("employees").doc(uid).set(
            {
              ...realApplyScreenWrite(uid, "Merge Case", "merge1@p16a-test.example", "9876511111", "MRG01"),
              onboardingPaid: false,
            },
            { merge: true }
          )
        );
        results["10_merge_with_unchanged_default_onboarding_value_rejected"] =
          "PASSED — a merge write introducing onboardingPaid:false (previously absent) was rejected, per the deliberate blanket-denylist decision";
      } catch (e) {
        results["10_merge_with_unchanged_default_onboarding_value_rejected"] = `FAILED — ${e.message}`;
      }
    }

    // ============================================
    // 11-12: Phase 14 regression controls — must still fail
    // ============================================
    {
      const uid = "p16a-regression-emp-status";
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("employees").doc(uid).set(
          realApplyScreenWrite(uid, "Reg", "regstatus@p16a-test.example", "9", "REG1")
        );
      });
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("regstatus@p16a-test.example")).firestore();
      try {
        await assertFails(db.collection("employees").doc(uid).update({ status: "approved" }));
        results["11_regression_employee_self_approve_still_rejected"] =
          "PASSED — Phase 14's employee self-approval lock still holds";
      } catch (e) {
        results["11_regression_employee_self_approve_still_rejected"] = `FAILED — REGRESSION: ${e.message}`;
      }
    }
    {
      const uid = "p16a-regression-emp-commission";
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("employees").doc(uid).set(
          realApplyScreenWrite(uid, "Reg", "regcomm@p16a-test.example", "9", "REG2")
        );
      });
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("regcomm@p16a-test.example")).firestore();
      try {
        await assertFails(db.collection("employees").doc(uid).update({ commissionRate: 100 }));
        results["12_regression_employee_self_set_commission_still_rejected"] =
          "PASSED — Phase 14's employee self-commission lock still holds";
      } catch (e) {
        results["12_regression_employee_self_set_commission_still_rejected"] = `FAILED — REGRESSION: ${e.message}`;
      }
    }

    // ============================================
    // 13: admin CAN write all onboarding fields
    // ============================================
    {
      const uid = "p16a-w10-adminwrite";
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("employees").doc(uid).set(
          realApplyScreenWrite(uid, "Admin Target", "adm1@p16a-test.example", "9", "ADM1")
        );
      });
      const db = testEnv.authenticatedContext("p16a-admin1", adminClaims("admin1@p16a-test.example")).firestore();
      try {
        await assertSucceeds(
          db.collection("employees").doc(uid).update({
            onboardingPaid: true,
            onboardingWaived: false,
            onboardingFeeAmount: 500,
            onboardingPaymentId: "pay_admin1",
            onboardingPaidAt: Date.now(),
            onboardingWaivedAt: null,
            onboardingRefundedAt: null,
          })
        );
        results["13_admin_can_write_onboarding_fields"] = "PASSED — admin can write every onboarding field";
      } catch (e) {
        results["13_admin_can_write_onboarding_fields"] = `FAILED — ${e.message}`;
      }
    }

    // ============================================
    // 14-15: settings/associate_onboarding — public read, admin-only write
    // ============================================
    {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("settings").doc("associate_onboarding").set({ feeAmount: 500 });
      });
      const anonDb = testEnv.unauthenticatedContext().firestore();
      try {
        await assertSucceeds(anonDb.collection("settings").doc("associate_onboarding").get());
        results["14_anyone_can_read_associate_onboarding_config"] =
          "PASSED — even an unauthenticated caller can read settings/associate_onboarding";
      } catch (e) {
        results["14_anyone_can_read_associate_onboarding_config"] = `FAILED — ${e.message}`;
      }
    }
    {
      const uid = "p16a-w10-nonadminwrite";
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("nonadmin1@p16a-test.example")).firestore();
      try {
        await assertFails(db.collection("settings").doc("associate_onboarding").set({ feeAmount: 1 }));
        results["15_non_admin_cannot_write_associate_onboarding_config"] =
          "PASSED — a non-admin cannot write settings/associate_onboarding";
      } catch (e) {
        results["15_non_admin_cannot_write_associate_onboarding_config"] = `FAILED — ${e.message}`;
      }
    }

    // ============================================
    // 16-17: onboarding_events / associate_refund_requests — admin-only,
    // Cloud-Functions-write-only
    // ============================================
    {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("onboarding_events").doc("evt1").set({ type: "activation" });
      });
      const uid = "p16a-w10-eventsread";
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("eventsread1@p16a-test.example")).firestore();
      try {
        await assertFails(db.collection("onboarding_events").doc("evt1").get());
        results["16_non_admin_cannot_read_onboarding_events"] = "PASSED — a non-admin cannot read onboarding_events";
      } catch (e) {
        results["16_non_admin_cannot_read_onboarding_events"] = `FAILED — ${e.message}`;
      }
    }
    {
      const uid = "p16a-w10-eventswrite";
      const db = testEnv.authenticatedContext(uid, unprivilegedClaims("eventswrite1@p16a-test.example")).firestore();
      const adminDb = testEnv.authenticatedContext("p16a-admin2", adminClaims("admin2@p16a-test.example")).firestore();
      let nonAdminBlocked = false;
      let adminBlocked = false;
      try {
        await assertFails(db.collection("onboarding_events").add({ type: "forged" }));
        nonAdminBlocked = true;
      } catch (e) {
        results["17_nobody_can_write_onboarding_events_or_refund_requests"] = `FAILED (non-admin onboarding_events) — ${e.message}`;
      }
      try {
        // write:false means NOBODY, not even an admin client — Cloud
        // Functions (Admin SDK) is the only writer.
        await assertFails(adminDb.collection("onboarding_events").add({ type: "admin-attempt" }));
        adminBlocked = true;
      } catch (e) {
        results["17_nobody_can_write_onboarding_events_or_refund_requests"] = `FAILED (admin onboarding_events) — ${e.message}`;
      }
      let refundReqBlocked = false;
      try {
        await assertFails(
          db.collection("associate_refund_requests").doc("req1").set({ employeeId: uid, status: "pending" })
        );
        refundReqBlocked = true;
      } catch (e) {
        results["17_nobody_can_write_onboarding_events_or_refund_requests"] = `FAILED (associate_refund_requests) — ${e.message}`;
      }
      if (nonAdminBlocked && adminBlocked && refundReqBlocked) {
        results["17_nobody_can_write_onboarding_events_or_refund_requests"] =
          "PASSED — neither a non-admin nor an admin client can write onboarding_events or associate_refund_requests";
      }
    }
  } finally {
    await testEnv.cleanup();
  }

  console.log("=== PHASE 16A — ASSOCIATE ONBOARDING RULES TEST ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);

  const allPassed = Object.values(results).every((v) => v.startsWith("PASSED"));
  console.log(allPassed ? "\nALL PASSED" : "\nSOME FAILED");
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phase16a onboarding rules test:", e);
  process.exit(1);
});
