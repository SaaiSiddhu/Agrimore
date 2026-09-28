// PHASE ADMR-80, hardened ADMR-82 — finance reconciliation scan
// (functions/src/admin/financeReconciliation.ts) on the Firestore emulator.
//
// Each scenario seeds ONE specific bad state directly (Admin SDK, bypassing
// every normal command — this is deliberately testing the SCAN's own
// detection logic in isolation, not the commands that would normally
// prevent these states) and confirms the scan finds it with the right
// kind/recordId, while a parallel CLEAN record of the same shape produces
// no finding at all (a positive control — a scan that flags everything
// proves nothing).
//  r1 a paid withdrawal whose own payout row was never actually marked paid
//  r2 a paid withdrawal missing its payment reference
//  r3 a withdrawal whose amountPaise does not match the sum of its own
//     payout rows (tamper/corruption signal, not reachable via the normal flow)
//  r4 a withdrawal with neither destination nor destinationFull at all
//  r5 a requested withdrawal whose own payout row drifted to a different
//     status outside the withdrawal (e.g. touched directly elsewhere)
//  r6 a paid rider statement missing its payment reference
//  r7 a paid employee payout missing its payment reference
//  r8 a fully clean, ordinary paid withdrawal produces ZERO findings
//  r9 (ADMR-82) a payout row with no valid numeric amount is its own
//     malformed_amount finding, excluded from its withdrawal's own sum
//     check rather than silently defaulted to zero
//  r10 (ADMR-82) coverage is honest: inspected count, statuses covered and
//     totalInStatuses reflect what was ACTUALLY scanned, never a whole-
//     collection count regardless of status
//  r11 (ADMR-82) a tiny injected child-read budget makes the scan report
//     incomplete:true with a clear reason, rather than silently continuing
//  r12 (ADMR-82) isCandidateStillReal — the pure revalidation check itself:
//     a genuine, persistent mismatch stays real; a candidate whose status
//     changed since the first read is correctly recognized as stale
// Run with: firebase emulators:exec --only firestore "node scripts/phaseADMR80_finance_reconciliation_test.js"
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
const PROJECT = process.env.GCLOUD_PROJECT || "demo-admr80-reconciliation";
if (!PROJECT.startsWith("demo-")) { console.error(`REFUSING: ${PROJECT} is not a demo- project`); process.exit(2); }
const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: PROJECT });
const db = admin.firestore();
const { Timestamp } = require("firebase-admin/firestore");
const { financeReconciliationScanCore, isCandidateStillReal } = require("../lib/admin/financeReconciliation");

const results = [];
const record = (label, pass, detail) => { results.push(pass); console.log(`${pass ? "PASSED" : "FAILED"} — ${label}${pass ? "" : ` :: ${detail}`}`); };
const NOW = Date.UTC(2026, 8, 28, 6, 0, 0);
const DEST = { method: "bank", accountLast4: "4821", ifsc: "EXMP0001234" };

async function main() {
  console.log("=== PHASE ADMR-80 — finance reconciliation scan ===");

  // r1
  await db.doc("seller_payouts/r1-p1").set({ sellerId: "r1s", netAmount: 100, status: "requested", withdrawalId: "r1w" });
  await db.doc("seller_withdrawals/r1w").set({
    sellerId: "r1s", status: "paid", amountPaise: 10000, payoutIds: ["r1-p1"], paymentReference: "UTR-R1",
    destination: DEST, createdAt: Timestamp.fromMillis(NOW), paidAt: Timestamp.fromMillis(NOW),
  });

  // r2
  await db.doc("seller_payouts/r2-p1").set({ sellerId: "r2s", netAmount: 50, status: "paid", withdrawalId: "r2w", paymentReference: "" });
  await db.doc("seller_withdrawals/r2w").set({
    sellerId: "r2s", status: "paid", amountPaise: 5000, payoutIds: ["r2-p1"], paymentReference: "",
    destination: DEST, createdAt: Timestamp.fromMillis(NOW), paidAt: Timestamp.fromMillis(NOW),
  });

  // r3
  await db.doc("seller_payouts/r3-p1").set({ sellerId: "r3s", netAmount: 100, status: "requested", withdrawalId: "r3w" });
  await db.doc("seller_withdrawals/r3w").set({
    sellerId: "r3s", status: "requested", amountPaise: 99999, payoutIds: ["r3-p1"],
    destination: DEST, createdAt: Timestamp.fromMillis(NOW),
  });

  // r4
  await db.doc("seller_withdrawals/r4w").set({
    sellerId: "r4s", status: "requested", amountPaise: 10000, payoutIds: [],
    createdAt: Timestamp.fromMillis(NOW),
  });

  // r5
  await db.doc("seller_payouts/r5-p1").set({ sellerId: "r5s", netAmount: 100, status: "pending", withdrawalId: "r5w" });
  await db.doc("seller_withdrawals/r5w").set({
    sellerId: "r5s", status: "requested", amountPaise: 10000, payoutIds: ["r5-p1"],
    destination: DEST, createdAt: Timestamp.fromMillis(NOW),
  });

  // r6
  await db.doc("rider_payouts/r6rp").set({
    riderId: "r6r", status: "paid", amountPaise: 20000, paymentReference: null,
    paidAt: Timestamp.fromMillis(NOW), createdAt: Timestamp.fromMillis(NOW),
  });

  // r7
  await db.doc("employee_payouts/r7ep").set({
    employeeId: "r7e", status: "paid", amount: 300, paymentReference: "   ",
    paidAt: Timestamp.fromMillis(NOW), createdAt: Timestamp.fromMillis(NOW),
  });

  // r8 — a fully clean control
  await db.doc("seller_payouts/r8-p1").set({ sellerId: "r8s", netAmount: 75, status: "paid", withdrawalId: "r8w", paymentReference: "UTR-R8" });
  await db.doc("seller_withdrawals/r8w").set({
    sellerId: "r8s", status: "paid", amountPaise: 7500, payoutIds: ["r8-p1"], paymentReference: "UTR-R8",
    destination: DEST, destinationFull: { payoutMethod: "bank", accountNumber: "123456784821" },
    createdAt: Timestamp.fromMillis(NOW), paidAt: Timestamp.fromMillis(NOW),
  });

  // r9 — a payout row with no valid numeric amount at all
  await db.doc("seller_payouts/r9-p1").set({ sellerId: "r9s", status: "requested", withdrawalId: "r9w" }); // no netAmount/amount
  await db.doc("seller_withdrawals/r9w").set({
    sellerId: "r9s", status: "requested", amountPaise: 10000, payoutIds: ["r9-p1"],
    destination: DEST, createdAt: Timestamp.fromMillis(NOW),
  });

  const result = await financeReconciliationScanCore(db, NOW + 1000);

  // r11 — a separate scan with a tiny injected budget (this withdrawal alone exceeds it)
  await db.doc("seller_payouts/r11-p1").set({ sellerId: "r11s", netAmount: 10, status: "requested", withdrawalId: "r11w" });
  await db.doc("seller_payouts/r11-p2").set({ sellerId: "r11s", netAmount: 10, status: "requested", withdrawalId: "r11w" });
  await db.doc("seller_withdrawals/r11w").set({
    sellerId: "r11s", status: "requested", amountPaise: 2000, payoutIds: ["r11-p1", "r11-p2"],
    destination: DEST, createdAt: Timestamp.fromMillis(NOW),
  });
  const budgetedResult = await financeReconciliationScanCore(db, NOW + 2000, 1);
  const byKindAndId = (kind, id) => result.findings.filter((f) => f.kind === kind && f.recordId === id);

  record("r1_paid_withdrawal_with_unpaid_payout_row", byKindAndId("withdrawal_payout_status_mismatch", "r1w").length === 1,
    JSON.stringify(byKindAndId("withdrawal_payout_status_mismatch", "r1w")));
  record("r2_paid_withdrawal_missing_reference", byKindAndId("paid_missing_reference", "r2w").length === 1,
    JSON.stringify(byKindAndId("paid_missing_reference", "r2w")));
  record("r3_amount_mismatch_detected", byKindAndId("withdrawal_amount_mismatch", "r3w").length === 1,
    JSON.stringify(byKindAndId("withdrawal_amount_mismatch", "r3w")));
  record("r4_missing_destination_snapshot", byKindAndId("missing_destination_snapshot", "r4w").length === 1,
    JSON.stringify(byKindAndId("missing_destination_snapshot", "r4w")));
  record("r5_payout_status_drift_on_requested_withdrawal", byKindAndId("payout_status_drift", "r5w").length === 1,
    JSON.stringify(byKindAndId("payout_status_drift", "r5w")));
  record("r6_paid_rider_statement_missing_reference",
    result.findings.some((f) => f.kind === "paid_missing_reference" && f.actorType === "rider" && f.recordId === "r6rp"),
    JSON.stringify(result.findings.filter((f) => f.actorType === "rider")));
  record("r7_paid_employee_payout_missing_reference",
    result.findings.some((f) => f.kind === "paid_missing_reference" && f.actorType === "employee" && f.recordId === "r7ep" && f.amountRupees === 300),
    JSON.stringify(result.findings.filter((f) => f.actorType === "employee")));
  const r8Findings = result.findings.filter((f) => f.recordId === "r8w" || f.recordId === "r8-p1");
  record("r8_clean_withdrawal_produces_zero_findings", r8Findings.length === 0, JSON.stringify(r8Findings));

  // r9
  const malformed = result.findings.filter((f) => f.kind === "malformed_amount" && f.recordId === "r9-p1");
  const r9AmountMismatch = byKindAndId("withdrawal_amount_mismatch", "r9w");
  record("r9_malformed_payout_amount_is_its_own_finding_not_silent_zero",
    malformed.length === 1 && r9AmountMismatch.length === 0,
    JSON.stringify({ malformed, r9AmountMismatch }));

  // r10 — coverage honesty
  const cov = result.coverage.sellerWithdrawals;
  record("r10_coverage_is_honest_not_a_whole_collection_count",
    cov.statusesCovered.includes("paid") && cov.statusesCovered.includes("requested") &&
      cov.limit === 200 && cov.inspected >= 7 && cov.totalInStatuses >= cov.inspected && typeof cov.truncated === "boolean",
    JSON.stringify(cov));
  record("r10b_result_has_no_stale_scanned_field", result.scanned === undefined, JSON.stringify({ hasScanned: "scanned" in result }));

  // r11 — budget exhaustion
  record("r11_tiny_budget_marks_scan_incomplete_with_reason",
    budgetedResult.incomplete === true && budgetedResult.incompleteReasons.length > 0 &&
      budgetedResult.incompleteReasons[0].includes("Child-read budget"),
    JSON.stringify(budgetedResult.incompleteReasons));
  record("r11b_normal_unbudgeted_scan_is_complete", result.incomplete === false, JSON.stringify({ incomplete: result.incomplete }));

  // r12 — isCandidateStillReal, the pure revalidation check
  const original = { status: "paid", paymentReference: "UTR-X", amountPaise: 5000 };
  record("r12a_unchanged_state_is_still_real", isCandidateStillReal(original, { status: "paid", paymentReference: "UTR-X", amountPaise: 5000 }) === true, "");
  record("r12b_status_changed_since_is_not_real", isCandidateStillReal(original, { status: "rejected", paymentReference: "UTR-X", amountPaise: 5000 }) === false, "");
  record("r12c_reference_changed_since_is_not_real", isCandidateStillReal(original, { status: "paid", paymentReference: "UTR-Y", amountPaise: 5000 }) === false, "");
  record("r12d_amount_changed_since_is_not_real", isCandidateStillReal(original, { status: "paid", paymentReference: "UTR-X", amountPaise: 6000 }) === false, "");
  record("r12e_document_deleted_since_is_not_real", isCandidateStillReal(original, undefined) === false, "");

  const failed = results.filter((x) => !x).length;
  console.log(`\n${results.length - failed}/${results.length} passed`);
  if (failed) { console.log("PHASE ADMR-80 reconciliation: FAILED"); process.exit(1); }
  console.log("PHASE ADMR-80 reconciliation: ALL PASSED"); process.exit(0);
}
main().catch((e) => { console.error(e); process.exit(1); });
