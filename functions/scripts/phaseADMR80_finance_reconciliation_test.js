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
//  r12 (ADMR-85) evaluateWithdrawal — the pure, from-scratch evaluation that
//     replaced isCandidateStillReal: a bad state produces its finding; the
//     SAME data with the bad field fixed produces none — this IS what
//     "resolved since the first read" means, proven directly, no timing race
//  r13 (ADMR-85) a seller_payouts row whose own withdrawalId/sellerId no
//     longer points back at the withdrawal listing it — payout_ownership_mismatch
//  r14 (ADMR-85) an ordinary persistent finding (r1's) carries confirmation:
//     "confirmed" — the two-pass wiring must not silently drop real findings
//  r15 (ADMR-85) a budget that covers the first pass but not the
//     confirmation re-read marks that withdrawal's child-derived finding(s)
//     confirmation:"unconfirmed", never drops them and never claims "confirmed"
//  r16 (ADMR-85) cursor continuation: 3 paid withdrawals, pageLimit 2 —
//     page 1 returns the 2 most recent + a cursor; page 2 (that cursor)
//     returns exactly the 3rd, with no overlap and no gap
//  r17 (ADMR-85) stable tie-break: 2 withdrawals sharing the exact same
//     paidAt, pageLimit 1 — paging by cursor reaches both exactly once
//  r18 (ADMR-85) recheckFindingCore: confirmed now, resolved after the
//     underlying record is legitimately fixed; not_found for a vanished one
//  r19 (ADMR-85) recheckFindingCore for a rider paid_missing_reference —
//     same confirmed → resolved transition, the non-seller path
// Run with: firebase emulators:exec --only firestore "node scripts/phaseADMR80_finance_reconciliation_test.js"
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
const PROJECT = process.env.GCLOUD_PROJECT || "demo-admr80-reconciliation";
if (!PROJECT.startsWith("demo-")) { console.error(`REFUSING: ${PROJECT} is not a demo- project`); process.exit(2); }
const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: PROJECT });
const db = admin.firestore();
const { Timestamp } = require("firebase-admin/firestore");
const { financeReconciliationScanCore, evaluateWithdrawal, recheckFindingCore, CHILD_READ_BUDGET } = require("../lib/admin/financeReconciliation");

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

  // r13 (ADMR-85) — a payout row listed under r13w but its own withdrawalId
  // points at a DIFFERENT withdrawal entirely (simulating a direct edit
  // elsewhere, exactly the class of drift no prior check ever caught)
  await db.doc("seller_payouts/r13-p1").set({ sellerId: "r13s", netAmount: 40, status: "requested", withdrawalId: "r13w-OTHER" });
  await db.doc("seller_withdrawals/r13w").set({
    sellerId: "r13s", status: "requested", amountPaise: 4000, payoutIds: ["r13-p1"],
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
  // r4b (ADMR-85) — an empty payoutIds array must NOT also produce a spurious
  // withdrawal_amount_mismatch (a real amountPaise compared against the sum
  // of zero children always "mismatches" and means nothing) — r4w's only
  // finding is the destination one asserted above, nothing else.
  record("r4b_empty_payoutids_produces_no_spurious_amount_mismatch",
    result.findings.filter((f) => f.recordId === "r4w").length === 1,
    JSON.stringify(result.findings.filter((f) => f.recordId === "r4w")));
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

  // r12 — evaluateWithdrawal, the pure from-scratch evaluator that replaced
  // isCandidateStillReal. Proves both detection AND what "resolved since the
  // first read" means: the SAME withdrawal with the bad field fixed produces
  // nothing, with no timing race needed to demonstrate it.
  {
    const badDest = { sellerId: "r12s", status: "requested", amountPaise: 1000 }; // no destination/destinationFull, no children
    const fixedDest = { ...badDest, destination: DEST };
    const badDestOut = evaluateWithdrawal("r12w", badDest, []);
    record("r12a_missing_destination_detected_and_nothing_else",
      badDestOut.length === 1 && badDestOut[0].kind === "missing_destination_snapshot", JSON.stringify(badDestOut));
    record("r12b_fixed_destination_produces_nothing", evaluateWithdrawal("r12w", fixedDest, []).length === 0, JSON.stringify(evaluateWithdrawal("r12w", fixedDest, [])));

    const fakeSnap = (id, data) => ({ id, data: () => data });
    const badChild = [fakeSnap("r12-p1", { sellerId: "r12s", netAmount: 10, status: "requested", withdrawalId: "SOME-OTHER-WITHDRAWAL" })];
    const fixedChild = [fakeSnap("r12-p1", { sellerId: "r12s", netAmount: 10, status: "requested", withdrawalId: "r12w" })];
    const wData = { sellerId: "r12s", status: "requested", amountPaise: 1000, destination: DEST };
    record("r12c_ownership_mismatch_detected", evaluateWithdrawal("r12w", wData, badChild).some((f) => f.kind === "payout_ownership_mismatch"), "");
    record("r12d_fixed_ownership_produces_no_mismatch", !evaluateWithdrawal("r12w", wData, fixedChild).some((f) => f.kind === "payout_ownership_mismatch"), "");
  }

  // r13 — payout_ownership_mismatch, via the real scan
  {
    const f = result.findings.filter((x) => x.kind === "payout_ownership_mismatch" && x.recordId === "r13-p1");
    record("r13_payout_ownership_mismatch_detected",
      f.length === 1 && f[0].detail.expectedWithdrawalId === "r13w" && f[0].detail.actualWithdrawalId === "r13w-OTHER",
      JSON.stringify(f));
  }

  // r14 — an ordinary persistent finding carries confirmation:"confirmed" —
  // the two-pass wiring must not silently drop a real, unchanging finding
  {
    const f = byKindAndId("withdrawal_payout_status_mismatch", "r1w");
    record("r14_persistent_finding_is_confirmed", f.length === 1 && f[0].confirmation === "confirmed", JSON.stringify(f));
    record("r14b_every_finding_this_scan_has_a_confirmation_state",
      result.findings.every((x) => x.confirmation === "confirmed" || x.confirmation === "unconfirmed"),
      JSON.stringify(result.findings.map((x) => ({ id: x.id, confirmation: x.confirmation }))));
    record("r14c_every_finding_has_a_stable_id",
      result.findings.every((x) => x.id === `${x.kind}:${x.recordId}`), JSON.stringify(result.findings.map((x) => x.id)));
  }

  // r15 — a budget that covers the first pass but not the confirmation
  // re-read reports that withdrawal's finding as unconfirmed, never drops it
  // and never claims "confirmed". r15w is given a paidAt far in the future
  // so it is the FIRST row this scan's own paid-status query processes,
  // before any other seeded withdrawal has a chance to consume the shared
  // budget — this makes the arithmetic exact regardless of what else exists.
  {
    await db.doc("seller_payouts/r15-p1").set({ sellerId: "r15s", netAmount: 50, status: "requested", withdrawalId: "r15w" });
    await db.doc("seller_payouts/r15-p2").set({ sellerId: "r15s", netAmount: 50, status: "requested", withdrawalId: "r15w" });
    await db.doc("seller_withdrawals/r15w").set({
      sellerId: "r15s", status: "paid", amountPaise: 10000, payoutIds: ["r15-p1", "r15-p2"], paymentReference: "UTR-R15",
      destination: DEST, createdAt: Timestamp.fromMillis(NOW), paidAt: Timestamp.fromMillis(NOW + 10_000_000),
    });
    const r15Result = await financeReconciliationScanCore(db, NOW + 3000, 2); // exactly enough for pass 1 (2 payouts), 0 left for pass 2
    const f = r15Result.findings.filter((x) => x.recordId === "r15w");
    record("r15_confirmation_budget_exhaustion_marks_unconfirmed_not_dropped",
      f.length === 1 && f[0].kind === "withdrawal_payout_status_mismatch" && f[0].confirmation === "unconfirmed",
      JSON.stringify({ findings: f, incompleteReasons: r15Result.incompleteReasons }));
  }

  // r16 — cursor continuation past the page limit. Each withdrawal is given
  // a real, cheap-to-detect finding (missing destination) so each page's
  // OWN findings array — the actual thing under test, not a parallel
  // hand-rolled query — directly says which of these 3 it covered.
  // Far-future timestamps make them unambiguously the top rows regardless
  // of anything else seeded above.
  {
    const mk = async (id, ms) => db.doc(`seller_withdrawals/${id}`).set({
      sellerId: "r16s", status: "paid", amountPaise: 100, payoutIds: [], paymentReference: "UTR-OK",
      createdAt: Timestamp.fromMillis(NOW), paidAt: Timestamp.fromMillis(ms), // no destination/destinationFull — a guaranteed finding
    });
    await mk("r16w-a", NOW + 30_000_000);
    await mk("r16w-b", NOW + 29_000_000);
    await mk("r16w-c", NOW + 28_000_000);
    const seenOn = (res) => res.findings.filter((f) => f.kind === "missing_destination_snapshot" && f.recordId.startsWith("r16w-")).map((f) => f.recordId);

    const page1 = await financeReconciliationScanCore(db, NOW + 5000, CHILD_READ_BUDGET, {}, 2);
    const page1Ids = seenOn(page1);
    const cursor = page1.nextCursor.sellerWithdrawals.paid;
    record("r16a_page1_has_a_cursor", cursor !== null && typeof cursor.value === "number" && typeof cursor.id === "string", JSON.stringify(page1.nextCursor));
    record("r16b_page1_is_the_two_newest", page1Ids.includes("r16w-a") && page1Ids.includes("r16w-b") && !page1Ids.includes("r16w-c"), JSON.stringify(page1Ids));

    const page2 = await financeReconciliationScanCore(db, NOW + 5001, CHILD_READ_BUDGET, { sellerWithdrawals: { paid: cursor } }, 2);
    const page2Ids = seenOn(page2);
    record("r16c_page2_reaches_the_third_with_no_overlap", page2Ids.includes("r16w-c") && !page2Ids.includes("r16w-a") && !page2Ids.includes("r16w-b"), JSON.stringify(page2Ids));
  }

  // r17 — stable tie-break: two withdrawals sharing the EXACT same paidAt.
  // Without a documentId tiebreak, paging by cursor could duplicate or skip
  // one of them; both far-future so they are unambiguously the top of the
  // whole collection.
  {
    const TIE = NOW + 40_000_000;
    const mkTied = async (id) => db.doc(`seller_withdrawals/${id}`).set({
      sellerId: "r17s", status: "paid", amountPaise: 100, payoutIds: [], paymentReference: "UTR-OK",
      createdAt: Timestamp.fromMillis(NOW), paidAt: Timestamp.fromMillis(TIE), // no destination — a guaranteed finding
    });
    await mkTied("r17w-a");
    await mkTied("r17w-b");
    const seenOn = (res) => res.findings.filter((f) => f.kind === "missing_destination_snapshot" && f.recordId.startsWith("r17w-")).map((f) => f.recordId);

    const page1 = await financeReconciliationScanCore(db, NOW + 6000, CHILD_READ_BUDGET, {}, 1);
    const page1Ids = seenOn(page1);
    const cursor = page1.nextCursor.sellerWithdrawals.paid;
    const page2 = await financeReconciliationScanCore(db, NOW + 6001, CHILD_READ_BUDGET, { sellerWithdrawals: { paid: cursor } }, 1);
    const page2Ids = seenOn(page2);
    const seen = [...page1Ids, ...page2Ids];
    record("r17_tiebreak_reaches_both_exactly_once",
      page1Ids.length === 1 && page2Ids.length === 1 && seen.includes("r17w-a") && seen.includes("r17w-b") && page1Ids[0] !== page2Ids[0],
      JSON.stringify({ page1Ids, page2Ids }));
  }

  // r18 — recheckFindingCore: confirmed now, resolved after a legitimate fix, not_found for a vanished record
  {
    await db.doc("seller_withdrawals/r18w").set({
      sellerId: "r18s", status: "requested", amountPaise: 1000, payoutIds: [], createdAt: Timestamp.fromMillis(NOW),
    }); // no destination
    const before = await recheckFindingCore(db, { kind: "missing_destination_snapshot", actorType: "seller", recordId: "r18w", detail: {} });
    record("r18a_recheck_confirms_a_real_finding", before.kind === "confirmed" && before.finding.kind === "missing_destination_snapshot", JSON.stringify(before));

    await db.doc("seller_withdrawals/r18w").update({ destination: DEST });
    const after = await recheckFindingCore(db, { kind: "missing_destination_snapshot", actorType: "seller", recordId: "r18w", detail: {} });
    record("r18b_recheck_resolves_after_a_legitimate_fix", after.kind === "resolved", JSON.stringify(after));

    const gone = await recheckFindingCore(db, { kind: "missing_destination_snapshot", actorType: "seller", recordId: "r18w-does-not-exist", detail: {} });
    record("r18c_recheck_not_found_for_a_vanished_record", gone.kind === "not_found", JSON.stringify(gone));
  }

  // r19 — recheckFindingCore for the non-seller path (rider paid_missing_reference)
  {
    await db.doc("rider_payouts/r19rp").set({ riderId: "r19r", status: "paid", amountPaise: 500, paymentReference: "", paidAt: Timestamp.fromMillis(NOW) });
    const before = await recheckFindingCore(db, { kind: "paid_missing_reference", actorType: "rider", recordId: "r19rp", detail: {} });
    record("r19a_recheck_confirms_rider_missing_reference", before.kind === "confirmed" && before.finding.actorType === "rider", JSON.stringify(before));
    await db.doc("rider_payouts/r19rp").update({ paymentReference: "UTR-R19" });
    const after = await recheckFindingCore(db, { kind: "paid_missing_reference", actorType: "rider", recordId: "r19rp", detail: {} });
    record("r19b_recheck_resolves_after_reference_added", after.kind === "resolved", JSON.stringify(after));
  }

  const failed = results.filter((x) => !x).length;
  console.log(`\n${results.length - failed}/${results.length} passed`);
  if (failed) { console.log("PHASE ADMR-80 reconciliation: FAILED"); process.exit(1); }
  console.log("PHASE ADMR-80 reconciliation: ALL PASSED"); process.exit(0);
}
main().catch((e) => { console.error(e); process.exit(1); });
