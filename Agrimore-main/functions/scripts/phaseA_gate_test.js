// Phase A — Customer Product Benefit Program compliance/feature-flag gate.
// Proves functions/src/admin/complianceGate.ts against a real emulator:
// non-admin denial, the approval gate on BENEFIT_PROGRAM_ENABLED, the
// hard block on COMPOUNDING_ENABLED/CASH_REDEMPTION_ENABLED/
// PRINCIPAL_INTAKE_ENABLED even when fully approved, exactly-one-audit-
// entry-per-successful-mutation, and assertProgramLaunchable()'s three
// states. setBenefitFeatureFlag/setComplianceStatus are v2 onCall,
// wrapped and invoked as `wrapped({ data: payload, auth })` — mirrors
// phase15_set_user_role_test.js's pattern exactly.
// Run with: node scripts/phaseA_gate_test.js
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { setBenefitFeatureFlag, setComplianceStatus, assertProgramLaunchable } = require("../lib/admin/complianceGate");

const wrappedSetFlag = test.wrap(setBenefitFeatureFlag);
const wrappedSetCompliance = test.wrap(setComplianceStatus);

const FLAG_DOC = "feature_flags/benefit_program";
const COMPLIANCE_DOC = "compliance_config/benefit_program";

async function callAndCapture(wrapped, payload, auth) {
  try {
    const result = await wrapped({ data: payload, auth });
    return { ok: true, result };
  } catch (e) {
    return { ok: false, code: e.code, message: e.message };
  }
}

async function resetState(db, { clearAuditLog = false } = {}) {
  await db.doc(FLAG_DOC).delete().catch(() => {});
  await db.doc(COMPLIANCE_DOC).delete().catch(() => {});
  if (clearAuditLog) {
    // Other scripts (e.g. phaseA_rules_test.js) run against this same
    // emulator instance and seed their own compliance_audit_log entries —
    // clear the slate so this script's exactly-one-entry assertions in
    // Scenario 7 aren't polluted by cross-script leftovers.
    const existing = await db.collection("compliance_audit_log").get();
    await Promise.all(existing.docs.map((d) => d.ref.delete()));
  }
}

async function main() {
  const db = admin.firestore();
  let allPassed = true;
  const results = {};

  console.log("=== PHASE A — COMPLIANCE GATE TEST ===");

  await resetState(db, { clearAuditLog: true });

  const adminAuth = { uid: "phaseA-gate-admin", token: { admin: true } };
  const nonAdminAuth = { uid: "phaseA-gate-nonadmin", token: {} };
  await db.collection("users").doc(nonAdminAuth.uid).set({ role: "user" });

  // Scenario 1: non-admin calling setBenefitFeatureFlag → permission-denied.
  {
    const r = await callAndCapture(
      wrappedSetFlag,
      { flag: "MONTHLY_CREDIT_ENABLED", value: true, reason: "attempt" },
      nonAdminAuth
    );
    const s = !r.ok && r.code === "permission-denied"
      ? `PASSED — a non-admin caller was rejected. code=${r.code}`
      : `FAILED — a non-admin caller was NOT rejected: ${JSON.stringify(r)}`;
    if (r.ok || r.code !== "permission-denied") allPassed = false;
    results.scenario1_non_admin_rejected = s;
    console.log("Scenario 1:", s);
  }

  // Scenario 2: admin enabling BENEFIT_PROGRAM_ENABLED while approvals are
  // NOT_STARTED (fresh state, deleted above) → rejected.
  {
    const r = await callAndCapture(
      wrappedSetFlag,
      { flag: "BENEFIT_PROGRAM_ENABLED", value: true, reason: "premature launch attempt" },
      adminAuth
    );
    const s = !r.ok && r.code === "failed-precondition"
      ? `PASSED — enabling BENEFIT_PROGRAM_ENABLED without approval was rejected. code=${r.code} message="${r.message}"`
      : `FAILED — was NOT rejected: ${JSON.stringify(r)}`;
    if (r.ok || r.code !== "failed-precondition") allPassed = false;
    results.scenario2_launch_blocked_without_approval = s;
    console.log("Scenario 2:", s);
  }

  // Scenario 3: same call after both approvals are APPROVED → succeeds.
  {
    const rLegal = await callAndCapture(
      wrappedSetCompliance,
      { field: "legalReviewStatus", value: "APPROVED", reason: "legal cleared" },
      adminAuth
    );
    const rCompliance = await callAndCapture(
      wrappedSetCompliance,
      { field: "complianceApprovalStatus", value: "APPROVED", reason: "compliance cleared" },
      adminAuth
    );
    const rFlag = await callAndCapture(
      wrappedSetFlag,
      { flag: "BENEFIT_PROGRAM_ENABLED", value: true, reason: "launch after approval" },
      adminAuth
    );
    let s;
    if (!rLegal.ok || !rCompliance.ok) {
      s = `FAILED — setting up approvals failed: legal=${JSON.stringify(rLegal)} compliance=${JSON.stringify(rCompliance)}`;
      allPassed = false;
    } else if (!rFlag.ok) {
      s = `FAILED — BENEFIT_PROGRAM_ENABLED was rejected after full approval: ${JSON.stringify(rFlag)}`;
      allPassed = false;
    } else {
      const flagDoc = await db.doc(FLAG_DOC).get();
      const written = flagDoc.data()?.BENEFIT_PROGRAM_ENABLED === true;
      s = written
        ? "PASSED — BENEFIT_PROGRAM_ENABLED was enabled after both approvals were APPROVED (verified in Firestore)"
        : `FAILED — callable succeeded but Firestore was not updated: ${JSON.stringify(flagDoc.data())}`;
      if (!written) allPassed = false;
    }
    results.scenario3_launch_succeeds_after_approval = s;
    console.log("Scenario 3:", s);
  }

  // Scenario 4/5/6: hard-blocked flags rejected even when fully approved
  // (approval state from scenario 3 is still in effect).
  for (const [key, flag] of [
    ["scenario4", "COMPOUNDING_ENABLED"],
    ["scenario5", "CASH_REDEMPTION_ENABLED"],
    ["scenario6", "PRINCIPAL_INTAKE_ENABLED"],
  ]) {
    const r = await callAndCapture(
      wrappedSetFlag,
      { flag, value: true, reason: "attempt to enable despite full approval" },
      adminAuth
    );
    const s = !r.ok && r.code === "failed-precondition"
      ? `PASSED — ${flag} was rejected even though the program is fully approved. code=${r.code}`
      : `FAILED — ${flag} was NOT rejected: ${JSON.stringify(r)}`;
    if (r.ok || r.code !== "failed-precondition") allPassed = false;
    results[`${key}_${flag.toLowerCase()}_hard_blocked`] = s;
    console.log(`${key}:`, s);
  }

  // Scenario 7: every successful mutation writes exactly one audit entry
  // with correct previous/new values. Checks the BENEFIT_PROGRAM_ENABLED
  // mutation from scenario 3 — scenario 2 and 4-6 failed before any audit
  // write, so exactly one entry for this target/action is expected.
  {
    const snap = await db
      .collection("compliance_audit_log")
      .where("action", "==", "setBenefitFeatureFlag")
      .where("target", "==", "BENEFIT_PROGRAM_ENABLED")
      .get();
    let s;
    if (snap.size !== 1) {
      s = `FAILED — expected exactly 1 audit entry, found ${snap.size}`;
      allPassed = false;
    } else {
      const entry = snap.docs[0].data();
      const correct =
        entry.previousValue === false &&
        entry.newValue === true &&
        entry.actorUid === adminAuth.uid &&
        typeof entry.reason === "string" &&
        entry.reason.length > 0 &&
        entry.createdAt != null;
      s = correct
        ? `PASSED — exactly one audit entry with previousValue=false, newValue=true, actorUid=${entry.actorUid}`
        : `FAILED — audit entry has unexpected shape: ${JSON.stringify(entry)}`;
      if (!correct) allPassed = false;
    }
    results.scenario7_exactly_one_audit_entry_per_success = s;
    console.log("Scenario 7:", s);
  }

  // Also verify the denied non-admin attempt from scenario 1 was itself
  // audit-logged (edge case explicitly required by this phase's spec).
  {
    const snap = await db
      .collection("compliance_audit_log")
      .where("action", "==", "setBenefitFeatureFlag.denied")
      .where("target", "==", "MONTHLY_CREDIT_ENABLED")
      .get();
    const s = snap.size === 1
      ? "PASSED — the denied non-admin attempt from Scenario 1 was audit-logged"
      : `FAILED — expected exactly 1 denied-attempt audit entry, found ${snap.size}`;
    if (snap.size !== 1) allPassed = false;
    results.scenario1b_denied_attempt_audit_logged = s;
    console.log("Scenario 1b:", s);
  }

  // Scenario 8: assertProgramLaunchable's three states.
  {
    // 8a — current state (post scenario 3): both approvals APPROVED and
    // BENEFIT_PROGRAM_ENABLED true → launchable.
    const launchableNow = await assertProgramLaunchable(db);
    const s8a = launchableNow.launchable === true && launchableNow.reasons.length === 0
      ? "PASSED — launchable=true once both approvals are APPROVED and BENEFIT_PROGRAM_ENABLED is true"
      : `FAILED — expected launchable=true with no reasons, got ${JSON.stringify(launchableNow)}`;
    if (!(launchableNow.launchable === true && launchableNow.reasons.length === 0)) allPassed = false;
    results.scenario8a_launchable_true_when_fully_approved = s8a;
    console.log("Scenario 8a:", s8a);

    // 8b — only legalReviewStatus APPROVED, complianceApprovalStatus
    // reverted to IN_REVIEW → not launchable.
    await callAndCapture(
      wrappedSetCompliance,
      { field: "complianceApprovalStatus", value: "IN_REVIEW", reason: "re-review requested" },
      adminAuth
    );
    const launchablePartial = await assertProgramLaunchable(db);
    const s8b = launchablePartial.launchable === false &&
      launchablePartial.reasons.some((r) => r.includes("complianceApprovalStatus"))
      ? `PASSED — launchable=false when only one approval is APPROVED. reasons=${JSON.stringify(launchablePartial.reasons)}`
      : `FAILED — expected launchable=false citing complianceApprovalStatus, got ${JSON.stringify(launchablePartial)}`;
    if (!(launchablePartial.launchable === false)) allPassed = false;
    results.scenario8b_launchable_false_with_one_approval_missing = s8b;
    console.log("Scenario 8b:", s8b);

    // 8c — fresh/clean state (both approvals NOT_STARTED, flag false) →
    // not launchable, citing all three reasons.
    await resetState(db);
    const launchableClean = await assertProgramLaunchable(db);
    const s8c = launchableClean.launchable === false && launchableClean.reasons.length === 3
      ? `PASSED — launchable=false with all three reasons on a missing/fresh document set. reasons=${JSON.stringify(launchableClean.reasons)}`
      : `FAILED — expected launchable=false with 3 reasons, got ${JSON.stringify(launchableClean)}`;
    if (!(launchableClean.launchable === false && launchableClean.reasons.length === 3)) allPassed = false;
    results.scenario8c_launchable_false_on_fresh_state = s8c;
    console.log("Scenario 8c:", s8c);
  }

  console.log("=== PHASE A GATE TEST SUMMARY ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phaseA gate test:", e);
  process.exit(1);
});
