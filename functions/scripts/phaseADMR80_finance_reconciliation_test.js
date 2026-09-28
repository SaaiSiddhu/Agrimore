// PHASE ADMR-80 — finance reconciliation scan
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
// Run with: firebase emulators:exec --only firestore "node scripts/phaseADMR80_finance_reconciliation_test.js"
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
const PROJECT = process.env.GCLOUD_PROJECT || "demo-admr80-reconciliation";
if (!PROJECT.startsWith("demo-")) { console.error(`REFUSING: ${PROJECT} is not a demo- project`); process.exit(2); }
const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: PROJECT });
const db = admin.firestore();
const { Timestamp } = require("firebase-admin/firestore");
const { financeReconciliationScanCore } = require("../lib/admin/financeReconciliation");

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

  const result = await financeReconciliationScanCore(db, NOW + 1000);
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
  record("scan_metadata_present", typeof result.observedAt === "number" && typeof result.scanned.sellerWithdrawals === "number",
    JSON.stringify(result.scanned));

  const failed = results.filter((x) => !x).length;
  console.log(`\n${results.length - failed}/${results.length} passed`);
  if (failed) { console.log("PHASE ADMR-80 reconciliation: FAILED"); process.exit(1); }
  console.log("PHASE ADMR-80 reconciliation: ALL PASSED"); process.exit(0);
}
main().catch((e) => { console.error(e); process.exit(1); });
