// Phase B — Customer Product Benefit Program ledger & accrual engine.
// Proves functions/src/customer/benefitAccrual.ts and
// productCreditLedger.ts against a real emulator: the launchability gate,
// exactly-one-CREDIT-per-successful-run, the CRITICAL same-period
// idempotency proof, exact percentage-rule arithmetic, the `none` rule,
// matured/suspended skip conditions, projection-equals-ledger-sum, and the
// negative-balance guard. runBenefitAccrualNow is a v2 onCall, wrapped and
// invoked as `wrapped({ data: payload, auth })` — mirrors
// phaseA_gate_test.js's pattern exactly.
// Run with: node scripts/phaseB_accrual_test.js
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { runBenefitAccrualNow } = require("../lib/customer/benefitAccrual");
const { appendLedgerEntry, toProjectionFields } = require("../lib/customer/productCreditLedger");

const wrappedRunAccrual = test.wrap(runBenefitAccrualNow);
const db = admin.firestore();
const adminAuth = { uid: "phaseB-accrual-admin", token: { admin: true } };

async function callAndCapture(wrapped, payload, auth) {
  try {
    const result = await wrapped({ data: payload, auth });
    return { ok: true, result };
  } catch (e) {
    return { ok: false, code: e.code, message: e.message };
  }
}

async function resetGlobalState() {
  await db.doc("feature_flags/benefit_program").delete().catch(() => {});
  await db.doc("compliance_config/benefit_program").delete().catch(() => {});
}

async function approveAndEnableAccrual() {
  await db.doc("compliance_config/benefit_program").set(
    { legalReviewStatus: "APPROVED", complianceApprovalStatus: "APPROVED" },
    { merge: true }
  );
  await db.doc("feature_flags/benefit_program").set(
    { BENEFIT_PROGRAM_ENABLED: true, MONTHLY_CREDIT_ENABLED: true },
    { merge: true }
  );
}

async function clearAccrualCollections() {
  for (const col of [
    "benefit_programs",
    "benefit_enrollments",
    "benefit_accruals",
    "product_credit_ledger",
    "product_credit_balances",
  ]) {
    const snap = await db.collection(col).get();
    await Promise.all(snap.docs.map((d) => d.ref.delete()));
  }
}

function ts(dateString) {
  return admin.firestore.Timestamp.fromDate(new Date(dateString));
}

async function main() {
  let allPassed = true;
  const results = {};

  await resetGlobalState();
  await clearAccrualCollections();

  // Scenario 1: accrual with the program NOT launchable -> no ledger entry written
  {
    await db.collection("benefit_programs").doc("prog-s1").set({
      name: "S1",
      status: "active",
      durationMonths: 12,
      rulesVersion: 1,
      benefitRuleType: "flatRupee",
      benefitRateValue: 500,
      creditFrequency: "monthly",
      minProgramAmount: 0,
      maxProgramAmount: 0,
    });
    await db.collection("benefit_enrollments").doc("enroll-s1").set({
      customerId: "cust-s1",
      programId: "prog-s1",
      status: "active",
      programAmount: 100000,
      rulesVersionAtEnrollment: 1,
      startDate: ts("2026-01-01"),
      maturityDate: ts("2027-01-01"),
    });

    const r = await callAndCapture(wrappedRunAccrual, { period: "2026-08", reason: "test s1" }, adminAuth);
    const ledgerSnap = await db.collection("product_credit_ledger").where("enrollmentId", "==", "enroll-s1").get();
    const pass = r.ok && r.result.notLaunchable === true && r.result.processed === 0 && ledgerSnap.empty;
    results.scenario1_not_launchable_no_ledger_entry = pass
      ? "PASSED — accrual no-op'd (notLaunchable) and wrote no ledger entry"
      : `FAILED — ${JSON.stringify(r)}, ledgerCount=${ledgerSnap.size}`;
    if (!pass) allPassed = false;
  }

  await approveAndEnableAccrual();

  // Scenario 2: launchable + MONTHLY_CREDIT_ENABLED -> exactly one CREDIT entry
  {
    const r = await callAndCapture(wrappedRunAccrual, { period: "2026-08", reason: "test s2" }, adminAuth);
    const ledgerSnap = await db
      .collection("product_credit_ledger")
      .where("enrollmentId", "==", "enroll-s1")
      .where("type", "==", "CREDIT")
      .get();
    const pass = r.ok && r.result.credited === 1 && ledgerSnap.size === 1;
    results.scenario2_credited_when_launchable = pass
      ? `PASSED — exactly one CREDIT entry written (amount=${ledgerSnap.docs[0]?.data().amount})`
      : `FAILED — ${JSON.stringify(r)}, ledgerCount=${ledgerSnap.size}`;
    if (!pass) allPassed = false;
  }

  // Scenario 3: running the SAME period twice -> still exactly one entry (CRITICAL)
  {
    const r = await callAndCapture(wrappedRunAccrual, { period: "2026-08", reason: "test s3 rerun" }, adminAuth);
    const ledgerSnap = await db
      .collection("product_credit_ledger")
      .where("enrollmentId", "==", "enroll-s1")
      .where("type", "==", "CREDIT")
      .get();
    const pass = r.ok && r.result.credited === 0 && r.result.skipped === 1 && ledgerSnap.size === 1;
    results.scenario3_idempotent_same_period_rerun = pass
      ? "PASSED (CRITICAL) — re-running the same period produced zero new credits; still exactly 1 ledger entry"
      : `FAILED — ${JSON.stringify(r)}, ledgerCount=${ledgerSnap.size}`;
    if (!pass) allPassed = false;
  }

  // Scenario 4: percentage rule: programAmount 100000 @ 12% monthly -> exactly 1000.00
  {
    await db.collection("benefit_programs").doc("prog-s4").set({
      name: "S4",
      status: "active",
      durationMonths: 12,
      rulesVersion: 1,
      benefitRuleType: "percentage",
      benefitRateValue: 12,
      creditFrequency: "monthly",
      minProgramAmount: 0,
      maxProgramAmount: 0,
    });
    await db.collection("benefit_enrollments").doc("enroll-s4").set({
      customerId: "cust-s4",
      programId: "prog-s4",
      status: "active",
      programAmount: 100000,
      rulesVersionAtEnrollment: 1,
      startDate: ts("2026-01-01"),
      maturityDate: ts("2027-01-01"),
    });
    const r = await callAndCapture(wrappedRunAccrual, { period: "2026-09", reason: "test s4" }, adminAuth);
    const ledgerSnap = await db
      .collection("product_credit_ledger")
      .where("enrollmentId", "==", "enroll-s4")
      .where("type", "==", "CREDIT")
      .get();
    const amount = ledgerSnap.docs[0]?.data().amount;
    const pass = r.ok && ledgerSnap.size === 1 && amount === 1000;
    results.scenario4_percentage_rule_exact_amount = pass
      ? `PASSED — 100000 @ 12% monthly = exactly Rs.${amount}`
      : `FAILED — amount=${amount}, ${JSON.stringify(r)}`;
    if (!pass) allPassed = false;
  }

  // Scenario 5: `none` rule -> 0, and no ledger entry
  {
    await db.collection("benefit_programs").doc("prog-s5").set({
      name: "S5",
      status: "active",
      durationMonths: 12,
      rulesVersion: 1,
      benefitRuleType: "none",
      benefitRateValue: 0,
      creditFrequency: "monthly",
      minProgramAmount: 0,
      maxProgramAmount: 0,
    });
    await db.collection("benefit_enrollments").doc("enroll-s5").set({
      customerId: "cust-s5",
      programId: "prog-s5",
      status: "active",
      programAmount: 100000,
      rulesVersionAtEnrollment: 1,
      startDate: ts("2026-01-01"),
      maturityDate: ts("2027-01-01"),
    });
    const r = await callAndCapture(wrappedRunAccrual, { period: "2026-09", reason: "test s5" }, adminAuth);
    const ledgerSnap = await db.collection("product_credit_ledger").where("enrollmentId", "==", "enroll-s5").get();
    const anchorSnap = await db.collection("benefit_accruals").doc("enroll-s5_2026-09").get();
    const pass = r.ok && ledgerSnap.empty && anchorSnap.exists && anchorSnap.data().calculatedAmount === 0;
    results.scenario5_none_rule_zero_no_ledger_entry = pass
      ? "PASSED — none rule produced 0 and wrote no ledger entry (anchor recorded the zero outcome)"
      : `FAILED — ${JSON.stringify(r)}, ledgerCount=${ledgerSnap.size}, anchor=${JSON.stringify(anchorSnap.data())}`;
    if (!pass) allPassed = false;
  }

  // Scenario 6: matured enrollment -> no accrual
  {
    await db.collection("benefit_programs").doc("prog-s6").set({
      name: "S6",
      status: "active",
      durationMonths: 12,
      rulesVersion: 1,
      benefitRuleType: "flatRupee",
      benefitRateValue: 500,
      creditFrequency: "monthly",
      minProgramAmount: 0,
      maxProgramAmount: 0,
    });
    await db.collection("benefit_enrollments").doc("enroll-s6").set({
      customerId: "cust-s6",
      programId: "prog-s6",
      status: "active",
      programAmount: 100000,
      rulesVersionAtEnrollment: 1,
      startDate: ts("2020-01-01"),
      maturityDate: ts("2021-01-01"),
    });
    const r = await callAndCapture(wrappedRunAccrual, { period: "2026-09", reason: "test s6" }, adminAuth);
    const ledgerSnap = await db.collection("product_credit_ledger").where("enrollmentId", "==", "enroll-s6").get();
    const anchorSnap = await db.collection("benefit_accruals").doc("enroll-s6_2026-09").get();
    const pass = r.ok && ledgerSnap.empty && !anchorSnap.exists;
    results.scenario6_matured_enrollment_no_accrual = pass
      ? "PASSED — a matured enrollment was skipped entirely (no anchor written, no ledger entry)"
      : `FAILED — ${JSON.stringify(r)}, ledgerCount=${ledgerSnap.size}, anchorExists=${anchorSnap.exists}`;
    if (!pass) allPassed = false;
  }

  // Scenario 7: suspended program -> no accrual
  {
    await db.collection("benefit_programs").doc("prog-s7").set({
      name: "S7",
      status: "suspended",
      durationMonths: 12,
      rulesVersion: 1,
      benefitRuleType: "flatRupee",
      benefitRateValue: 500,
      creditFrequency: "monthly",
      minProgramAmount: 0,
      maxProgramAmount: 0,
    });
    await db.collection("benefit_enrollments").doc("enroll-s7").set({
      customerId: "cust-s7",
      programId: "prog-s7",
      status: "active",
      programAmount: 100000,
      rulesVersionAtEnrollment: 1,
      startDate: ts("2026-01-01"),
      maturityDate: ts("2027-01-01"),
    });
    const r = await callAndCapture(wrappedRunAccrual, { period: "2026-09", reason: "test s7" }, adminAuth);
    const ledgerSnap = await db.collection("product_credit_ledger").where("enrollmentId", "==", "enroll-s7").get();
    const anchorSnap = await db.collection("benefit_accruals").doc("enroll-s7_2026-09").get();
    const pass = r.ok && ledgerSnap.empty && !anchorSnap.exists;
    results.scenario7_suspended_program_no_accrual = pass
      ? "PASSED — a suspended program's enrollment was skipped entirely (no anchor written, no ledger entry)"
      : `FAILED — ${JSON.stringify(r)}, ledgerCount=${ledgerSnap.size}, anchorExists=${anchorSnap.exists}`;
    if (!pass) allPassed = false;
  }

  // Scenario 8: projection.available equals the sum of ledger CREDIT entries
  // after N accruals — checked for every customer credited above, so this
  // is a whole-system proof, not just a single-case check.
  {
    for (const cust of ["cust-s1", "cust-s4"]) {
      const ledgerSnap = await db
        .collection("product_credit_ledger")
        .where("customerId", "==", cust)
        .where("type", "==", "CREDIT")
        .get();
      const ledgerSum = ledgerSnap.docs.reduce((sum, d) => sum + d.data().amount, 0);
      const projectionSnap = await db.collection("product_credit_balances").doc(cust).get();
      const available = projectionSnap.data()?.available ?? 0;
      const pass = Math.abs(available - ledgerSum) < 0.001;
      results[`scenario8_projection_matches_ledger_sum_${cust}`] = pass
        ? `PASSED — projection.available (${available}) equals the ledger CREDIT sum (${ledgerSum}) for ${cust}`
        : `FAILED — projection.available=${available}, ledgerSum=${ledgerSum} for ${cust}`;
      if (!pass) allPassed = false;
    }
  }

  // Scenario 9: a negative-balance-producing operation throws and writes nothing
  {
    const customerId = "phaseB-negative-balance-customer";
    await db.collection("product_credit_balances").doc(customerId).set({ available: 50 });

    let threw = false;
    let errorMessage = "";
    try {
      await db.runTransaction(async (tx) => {
        const projectionSnap = await tx.get(db.collection("product_credit_balances").doc(customerId));
        const currentProjection = toProjectionFields(projectionSnap.data());
        appendLedgerEntry(tx, db, {
          customerId,
          enrollmentId: "",
          type: "EXPIRY",
          amount: 100, // more than the 50 available
          currentProjection,
          description: "test negative balance",
        });
      });
    } catch (e) {
      threw = true;
      errorMessage = e.message;
    }

    const afterSnap = await db.collection("product_credit_balances").doc(customerId).get();
    const afterLedgerSnap = await db.collection("product_credit_ledger").where("customerId", "==", customerId).get();
    const pass = threw && afterSnap.data()?.available === 50 && afterLedgerSnap.empty;
    results.scenario9_negative_balance_throws_writes_nothing = pass
      ? `PASSED — the operation threw ("${errorMessage}") and neither the projection nor a ledger entry was written`
      : `FAILED — threw=${threw}, available=${afterSnap.data()?.available}, ledgerCount=${afterLedgerSnap.size}`;
    if (!pass) allPassed = false;
  }

  console.log("=== PHASE B — ACCRUAL ENGINE TEST ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);
  console.log(allPassed ? "\nALL PASSED" : "\nSOME FAILED");
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phaseB accrual test:", e);
  process.exit(1);
});
