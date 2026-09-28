// ============================================================
//  Finance reconciliation — Phase ADMR-80, hardened ADMR-82
// ============================================================
//
// A READ-ONLY admin investigation surface over the three payout paths this
// session's own ADMR-77/78/79 work established real invariants for. Every
// check here compares fields already read and verified during that work —
// nothing invented. No remediation action exists here by design (the
// owner's own prompt: "No generic 'fix balance' or 'force paid' controls" —
// this phase does not decide what a mismatch means or how to correct it,
// only surfaces it with enough context for a human to investigate).
//
// ADMR-82 closed 3 real gaps ADMR-80 itself had:
//  - `scanned` used to be a whole-collection count regardless of status —
//    genuinely misleading against what was actually inspected (paid+requested,
//    RECENT_LIMIT each). `coverage` below is honest: rows actually inspected,
//    the exact statuses covered, and whether more exist in those statuses.
//  - a withdrawal's own payoutIds were read with no aggregate budget — a
//    single withdrawal can legitimately hold up to
//    sellerWallet.ts's own MAX_PAYOUTS_PER_WITHDRAWAL (400) rows, and up to
//    RECENT_LIMIT*2 withdrawals were being scanned, with no bound on the
//    product. CHILD_READ_BUDGET below caps this for real; hitting it marks
//    the scan `incomplete`, never silently drops data while claiming success.
//  - parent and child records were read at slightly different moments with
//    no re-verification, so a legitimate payment committing in that exact
//    window could produce a transient, false mismatch. Every parent/child
//    finding is now revalidated with a fresh, targeted re-read before being
//    reported; one that no longer reproduces is dropped, not reported.
//
// Reconciliation contract:
//   source records    seller_withdrawals (+ their own payoutIds' seller_payouts
//                      rows, budgeted), rider_payouts, employee_payouts
//   authoritative state  whatever Firestore currently holds at the moment of
//                      each read — every finding carries `observedAt`
//                      (the scan's own run time), never claimed as a
//                      real-time guarantee across the whole scan
//   query strategy     bounded: RECENT_LIMIT most-recent rows per status per
//                      collection, ordered by createdAt/paidAt; a hard
//                      CHILD_READ_BUDGET across the whole run
//   operator action    read the finding, follow its own record ids, decide —
//                      this function only ever reads

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { resolveIsAdmin } from "./complianceGate";

type Db = FirebaseFirestore.Firestore;

/** How many most-recent rows per status this scan reads per collection — bounded by design. */
export const RECENT_LIMIT = 200;

/** Hard cap on seller_payouts child-document reads across the WHOLE scan (not per withdrawal) —
 * a single withdrawal can legitimately hold up to sellerWallet.ts's own MAX_PAYOUTS_PER_WITHDRAWAL
 * (400) rows, so this is the real, enforced budget the old per-collection RECENT_LIMIT never was. */
export const CHILD_READ_BUDGET = 2000;

export interface ReconciliationFinding {
  kind:
    | "withdrawal_payout_status_mismatch"
    | "paid_missing_reference"
    | "withdrawal_amount_mismatch"
    | "missing_destination_snapshot"
    | "payout_status_drift"
    | "malformed_amount";
  actorType: "seller" | "rider" | "employee";
  recordId: string;
  actorId: string;
  amountRupees: number;
  summary: string;
  detail: Record<string, unknown>;
}

/** What was actually inspected for one collection — never conflated with the collection's total
 * size. `totalInStatuses` counts only the SAME statuses this scan covers (a cheap aggregate query,
 * not a per-document read), so `truncated` is a real, honest signal, not a guess. */
export interface CoverageReport {
  inspected: number;
  statusesCovered: string[];
  limit: number;
  truncated: boolean;
  totalInStatuses: number;
}

export interface ReconciliationResult {
  observedAt: number;
  coverage: { sellerWithdrawals: CoverageReport; riderPayouts: CoverageReport; employeePayouts: CoverageReport };
  incomplete: boolean;
  incompleteReasons: string[];
  findings: ReconciliationFinding[];
}

const rupees = (paise: unknown) => (typeof paise === "number" ? Math.round(paise) / 100 : 0);
const isFiniteNumber = (v: unknown): v is number => typeof v === "number" && Number.isFinite(v);

/** Pure — whether a withdrawal candidate finding (built from `original`, the first read) is still
 * real against `fresh` (a second, later, targeted re-read of the SAME document). A legitimate
 * markWithdrawalPaidCore/closeWithdrawalCore transaction committing between the two reads changes
 * status/paymentReference/amountPaise; a candidate that no longer reproduces here self-resolved
 * (normal asynchronous processing) and must be dropped, not reported as confirmed corruption. */
export function isCandidateStillReal(
  original: FirebaseFirestore.DocumentData, fresh: FirebaseFirestore.DocumentData | undefined
): boolean {
  return !!fresh && fresh.status === original.status
    && fresh.paymentReference === original.paymentReference && fresh.amountPaise === original.amountPaise;
}

/** One status's own bounded query plus its own honest coverage report. */
async function boundedByStatus(
  db: Db, collection: string, status: string, orderField: string
): Promise<{ docs: FirebaseFirestore.QueryDocumentSnapshot[]; coverage: CoverageReport }> {
  const [snap, countSnap] = await Promise.all([
    db.collection(collection).where("status", "==", status).orderBy(orderField, "desc").limit(RECENT_LIMIT).get(),
    db.collection(collection).where("status", "==", status).count().get(),
  ]);
  const total = countSnap.data().count;
  return {
    docs: snap.docs,
    coverage: { inspected: snap.docs.length, statusesCovered: [status], limit: RECENT_LIMIT, truncated: total > snap.docs.length, totalInStatuses: total },
  };
}

function mergeCoverage(a: CoverageReport, b: CoverageReport): CoverageReport {
  return {
    inspected: a.inspected + b.inspected,
    statusesCovered: [...a.statusesCovered, ...b.statusesCovered],
    limit: RECENT_LIMIT,
    truncated: a.truncated || b.truncated,
    totalInStatuses: a.totalInStatuses + b.totalInStatuses,
  };
}

/** seller_withdrawals: paid rows must have every payoutId paid with the SAME reference; a
 * requested row's payoutIds must all still be requested; amountPaise must equal the sum of its
 * own payoutIds' net amounts (requestWithdrawalCore computes it from exactly those rows — a
 * mismatch here is a strong signal of tampering or corruption, not routine drift); every
 * withdrawal must carry at least a masked `destination`. Every parent/child comparison is
 * revalidated with a fresh withdrawal re-read before being reported, to rule out a transient
 * requested→paid transition committing between the parent and child reads. Bounded by
 * CHILD_READ_BUDGET across the whole scan — a budgetState object shared across collections. */
async function checkSellerWithdrawals(
  db: Db, budget: { remaining: number }, incompleteReasons: string[]
): Promise<{ findings: ReconciliationFinding[]; coverage: CoverageReport }> {
  const initialBudget = budget.remaining;
  const findings: ReconciliationFinding[] = [];
  const [paid, requested] = await Promise.all([
    boundedByStatus(db, "seller_withdrawals", "paid", "paidAt"),
    boundedByStatus(db, "seller_withdrawals", "requested", "createdAt"),
  ]);
  const rows = [...paid.docs, ...requested.docs];
  let budgetExhausted = false;
  for (const w of rows) {
    const d = w.data();
    const sellerId = String(d.sellerId ?? "");
    const amountRupees = rupees(d.amountPaise);
    if (!d.destination && !d.destinationFull) {
      findings.push({
        kind: "missing_destination_snapshot", actorType: "seller", recordId: w.id, actorId: sellerId, amountRupees,
        summary: "This withdrawal has no destination on file at all — should not be reachable via the normal request flow.",
        detail: { status: d.status },
      });
    }
    if (d.status === "paid" && !(typeof d.paymentReference === "string" && d.paymentReference.trim())) {
      findings.push({
        kind: "paid_missing_reference", actorType: "seller", recordId: w.id, actorId: sellerId, amountRupees,
        summary: "Marked paid but has no payment reference on file.",
        detail: {},
      });
    }

    const payoutIds: string[] = Array.isArray(d.payoutIds) ? d.payoutIds.map(String) : [];
    if (payoutIds.length === 0) continue;
    if (budgetExhausted) continue;
    if (payoutIds.length > budget.remaining) {
      budgetExhausted = true;
      incompleteReasons.push(
        `Child-read budget (${initialBudget}) reached while inspecting seller withdrawal ${w.id} and later rows — their own payout rows were not checked this scan.`
      );
      continue;
    }
    budget.remaining -= payoutIds.length;
    const payoutSnaps = await Promise.all(payoutIds.map((id) => db.collection("seller_payouts").doc(id).get()));

    let sumKnown = true;
    let payoutSum = 0;
    for (const p of payoutSnaps) {
      const pd = p.data();
      const net = isFiniteNumber(pd?.netAmount) ? pd!.netAmount : isFiniteNumber(pd?.amount) ? pd!.amount : null;
      if (net === null) {
        sumKnown = false;
        findings.push({
          kind: "malformed_amount", actorType: "seller", recordId: p.id, actorId: sellerId, amountRupees: 0,
          summary: `Payout row referenced by withdrawal ${w.id} has no valid numeric amount — excluded from that withdrawal's own amount check.`,
          detail: { withdrawalId: w.id },
        });
      } else {
        payoutSum += Math.round(net * 100);
      }
    }

    const candidates: ReconciliationFinding[] = [];
    if (sumKnown && typeof d.amountPaise === "number" && Math.abs(payoutSum - d.amountPaise) > 0) {
      candidates.push({
        kind: "withdrawal_amount_mismatch", actorType: "seller", recordId: w.id, actorId: sellerId, amountRupees,
        summary: `Withdrawal amount ₹${amountRupees.toFixed(2)} does not equal the sum of its own payout rows (₹${(payoutSum / 100).toFixed(2)}).`,
        detail: { amountPaise: d.amountPaise, payoutSumPaise: payoutSum, payoutIds },
      });
    }
    if (d.status === "paid") {
      const bad = payoutSnaps.filter((p) => {
        const pd = p.data();
        return !pd || pd.status !== "paid" || pd.paymentReference !== d.paymentReference;
      });
      if (bad.length > 0) {
        candidates.push({
          kind: "withdrawal_payout_status_mismatch", actorType: "seller", recordId: w.id, actorId: sellerId, amountRupees,
          summary: `Withdrawal is paid but ${bad.length} of its ${payoutIds.length} payout rows are not paid with the same reference.`,
          detail: { paymentReference: d.paymentReference ?? null, mismatchedPayoutIds: bad.map((p) => p.id) },
        });
      }
    } else if (d.status === "requested") {
      const drifted = payoutSnaps.filter((p) => p.data()?.status !== "requested");
      if (drifted.length > 0) {
        candidates.push({
          kind: "payout_status_drift", actorType: "seller", recordId: w.id, actorId: sellerId, amountRupees,
          summary: `Withdrawal is still requested but ${drifted.length} of its payout rows have moved to a different status outside this withdrawal.`,
          detail: { driftedPayoutIds: drifted.map((p) => ({ id: p.id, status: p.data()?.status ?? null })) },
        });
      }
    }
    if (candidates.length > 0) {
      // Revalidate: a legitimate transaction could have committed between the parent read above
      // and these child reads. A fresh, targeted re-read of just the withdrawal confirms the
      // candidate is still real before it is reported.
      const fresh = (await db.collection("seller_withdrawals").doc(w.id).get()).data();
      if (isCandidateStillReal(d, fresh)) findings.push(...candidates);
    }
  }
  const coverage = mergeCoverage(paid.coverage, requested.coverage);
  return { findings, coverage };
}

/** rider_payouts (weekly statements): the same paid-missing-reference check — riderMoney.ts's
 * own by-design live-resolution model (ADMR-77's own finding) means there is no per-statement
 * destination snapshot to cross-check here, so that check does not apply to riders. */
async function checkRiderPayouts(db: Db): Promise<{ findings: ReconciliationFinding[]; coverage: CoverageReport }> {
  const { docs, coverage } = await boundedByStatus(db, "rider_payouts", "paid", "paidAt");
  const findings: ReconciliationFinding[] = [];
  for (const p of docs) {
    const d = p.data();
    if (!(typeof d.paymentReference === "string" && d.paymentReference.trim())) {
      findings.push({
        kind: "paid_missing_reference", actorType: "rider", recordId: p.id, actorId: String(d.riderId ?? ""), amountRupees: rupees(d.amountPaise),
        summary: "Marked paid but has no payment reference on file.",
        detail: {},
      });
    }
  }
  return { findings, coverage };
}

/** employee_payouts: same paid-missing-reference check. Amounts here are already in rupees
 * (this collection predates the whole-paise convention seller/rider use — see riderMoney.ts's
 * own header comment on that history), so no paise conversion is applied. */
async function checkEmployeePayouts(db: Db): Promise<{ findings: ReconciliationFinding[]; coverage: CoverageReport }> {
  const { docs, coverage } = await boundedByStatus(db, "employee_payouts", "paid", "paidAt");
  const findings: ReconciliationFinding[] = [];
  for (const p of docs) {
    const d = p.data();
    if (!(typeof d.paymentReference === "string" && d.paymentReference.trim())) {
      findings.push({
        kind: "paid_missing_reference", actorType: "employee", recordId: p.id, actorId: String(d.employeeId ?? ""),
        amountRupees: typeof d.amount === "number" ? d.amount : 0,
        summary: "Marked paid but has no payment reference on file.",
        detail: {},
      });
    }
  }
  return { findings, coverage };
}

/** `childReadBudget` defaults to the real CHILD_READ_BUDGET; overridable only so a test can prove
 * the exhaustion path fires without seeding thousands of documents to reach the real budget. */
export async function financeReconciliationScanCore(
  db: Db, nowMs: number, childReadBudget: number = CHILD_READ_BUDGET
): Promise<ReconciliationResult> {
  const incompleteReasons: string[] = [];
  const budget = { remaining: childReadBudget };
  const [seller, rider, employee] = await Promise.all([
    checkSellerWithdrawals(db, budget, incompleteReasons),
    checkRiderPayouts(db),
    checkEmployeePayouts(db),
  ]);
  return {
    observedAt: nowMs,
    coverage: { sellerWithdrawals: seller.coverage, riderPayouts: rider.coverage, employeePayouts: employee.coverage },
    incomplete: incompleteReasons.length > 0,
    incompleteReasons,
    findings: [...seller.findings, ...rider.findings, ...employee.findings],
  };
}

export const financeReconciliationScan = onCall({ minInstances: 0, memory: "256MiB" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required");
  const ok = await resolveIsAdmin(admin.firestore(), request.auth.uid, request.auth.token.admin === true);
  if (!ok) throw new HttpsError("permission-denied", "Admins only");
  return financeReconciliationScanCore(admin.firestore(), Date.now());
});
