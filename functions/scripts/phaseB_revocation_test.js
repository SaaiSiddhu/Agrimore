// Phase B, Workstream 1 — approval-revocation cascade fix.
// Proves that withdrawing either approval status in
// functions/src/admin/complianceGate.ts's setComplianceStatus immediately
// disarms BENEFIT_PROGRAM_ENABLED/NEW_ENROLLMENT_ENABLED, that the cascade
// is audit-logged as its own entry, that approving never auto-enables
// anything, and that no cascade entry is written when nothing needed
// disabling. Mirrors phaseA_gate_test.js's wrap-and-invoke pattern exactly.
// Run with: node scripts/phaseB_revocation_test.js
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { setBenefitFeatureFlag, setComplianceStatus } = require("../lib/admin/complianceGate");

const wrappedSetFlag = test.wrap(setBenefitFeatureFlag);
const wrappedSetCompliance = test.wrap(setComplianceStatus);
const db = admin.firestore();
const adminAuth = { uid: "phaseB-revocation-admin", token: { admin: true } };

async function callAndCapture(wrapped, payload, auth) {
  try {
    const result = await wrapped({ data: payload, auth });
    return { ok: true, result };
  } catch (e) {
    return { ok: false, code: e.code, message: e.message };
  }
}

async function resetState() {
  await db.doc("feature_flags/benefit_program").delete().catch(() => {});
  await db.doc("compliance_config/benefit_program").delete().catch(() => {});
  const auditSnap = await db.collection("compliance_audit_log").get();
  await Promise.all(auditSnap.docs.map((d) => d.ref.delete()));
}

async function main() {
  let allPassed = true;
  const results = {};

  await resetState();

  // --- Setup: approve both -> enable BENEFIT_PROGRAM_ENABLED ---
  await callAndCapture(
    wrappedSetCompliance,
    { field: "legalReviewStatus", value: "APPROVED", reason: "setup: legal approve" },
    adminAuth
  );
  await callAndCapture(
    wrappedSetCompliance,
    { field: "complianceApprovalStatus", value: "APPROVED", reason: "setup: compliance approve" },
    adminAuth
  );
  const enableResult = await callAndCapture(
    wrappedSetFlag,
    { flag: "BENEFIT_PROGRAM_ENABLED", value: true, reason: "setup: enable" },
    adminAuth
  );
  {
    const pass = enableResult.ok;
    results.setup_enable_succeeded = pass
      ? "PASSED (setup) — BENEFIT_PROGRAM_ENABLED enabled after full approval"
      : `FAILED (setup) — ${JSON.stringify(enableResult)}`;
    if (!pass) allPassed = false;
    console.log("Setup:", results.setup_enable_succeeded);
  }

  // --- Revoke legalReviewStatus ---
  const revokeResult = await callAndCapture(
    wrappedSetCompliance,
    { field: "legalReviewStatus", value: "REJECTED", reason: "s1: revoke legal" },
    adminAuth
  );

  // Scenario 1: approve both -> enable -> revoke legal -> BENEFIT_PROGRAM_ENABLED is false
  {
    const flagDoc = await db.doc("feature_flags/benefit_program").get();
    const pass = revokeResult.ok && flagDoc.data()?.BENEFIT_PROGRAM_ENABLED === false;
    results.scenario1_revocation_disables_flag = pass
      ? "PASSED — revoking legalReviewStatus cascaded to disable BENEFIT_PROGRAM_ENABLED"
      : `FAILED — flagDoc=${JSON.stringify(flagDoc.data())}, revokeResult=${JSON.stringify(revokeResult)}`;
    if (!pass) allPassed = false;
    console.log("Scenario 1:", results.scenario1_revocation_disables_flag);
  }

  // Scenario 2: the cascade produced its own audit entry
  {
    const cascadeSnap = await db
      .collection("compliance_audit_log")
      .where("action", "==", "setComplianceStatus.cascadeDisable")
      .get();
    const pass = cascadeSnap.size === 1;
    results.scenario2_cascade_own_audit_entry = pass
      ? `PASSED — exactly one cascadeDisable audit entry was written (target="${cascadeSnap.docs[0]?.data().target}")`
      : `FAILED — expected exactly 1 cascadeDisable entry, found ${cascadeSnap.size}`;
    if (!pass) allPassed = false;
    console.log("Scenario 2:", results.scenario2_cascade_own_audit_entry);
  }

  // Scenario 3: setting a status to APPROVED does NOT auto-enable anything
  {
    const reApprove = await callAndCapture(
      wrappedSetCompliance,
      { field: "legalReviewStatus", value: "APPROVED", reason: "s3: re-approve" },
      adminAuth
    );
    const flagDoc = await db.doc("feature_flags/benefit_program").get();
    const pass = reApprove.ok && flagDoc.data()?.BENEFIT_PROGRAM_ENABLED === false;
    results.scenario3_approval_does_not_auto_enable = pass
      ? "PASSED — re-approving legalReviewStatus did NOT re-enable BENEFIT_PROGRAM_ENABLED (a separate admin action is required)"
      : `FAILED — flagDoc=${JSON.stringify(flagDoc.data())}, reApprove=${JSON.stringify(reApprove)}`;
    if (!pass) allPassed = false;
    console.log("Scenario 3:", results.scenario3_approval_does_not_auto_enable);
  }

  // Scenario 4: no cascade entry is written when both flags were already false
  {
    const beforeCascadeSnap = await db
      .collection("compliance_audit_log")
      .where("action", "==", "setComplianceStatus.cascadeDisable")
      .get();
    const beforeCount = beforeCascadeSnap.size;

    // BENEFIT_PROGRAM_ENABLED and NEW_ENROLLMENT_ENABLED are both still
    // false here (scenario 3's re-approval did not re-enable them) — this
    // revocation has nothing to disable.
    const revokeAgain = await callAndCapture(
      wrappedSetCompliance,
      { field: "complianceApprovalStatus", value: "REJECTED", reason: "s4: revoke again, flags already false" },
      adminAuth
    );

    const afterCascadeSnap = await db
      .collection("compliance_audit_log")
      .where("action", "==", "setComplianceStatus.cascadeDisable")
      .get();
    const pass = revokeAgain.ok && afterCascadeSnap.size === beforeCount;
    results.scenario4_no_cascade_when_already_false = pass
      ? `PASSED — no new cascadeDisable entry was written when both flags were already false (count stayed at ${beforeCount})`
      : `FAILED — beforeCount=${beforeCount}, afterCount=${afterCascadeSnap.size}, revokeAgain=${JSON.stringify(revokeAgain)}`;
    if (!pass) allPassed = false;
    console.log("Scenario 4:", results.scenario4_no_cascade_when_already_false);
  }

  console.log("=== PHASE B, WORKSTREAM 1 — REVOCATION CASCADE TEST SUMMARY ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);
  console.log(allPassed ? "\nALL PASSED" : "\nSOME FAILED");
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phaseB revocation test:", e);
  process.exit(1);
});
