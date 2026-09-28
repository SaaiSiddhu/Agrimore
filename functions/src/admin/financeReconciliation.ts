// ============================================================
//  Finance reconciliation — Phase ADMR-80
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
// Bounded by design: each collection is scanned by its own most-recent-N
// query (paid, then requested/pending), never a full-collection read — this
// stays cheap regardless of how large these collections grow, and a finding
// always carries the exact record id so a human can look deeper themselves.
//
// Reconciliation contract:
//   source records    seller_withdrawals (+ their own payoutIds' seller_payouts
//                      rows), rider_payouts, employee_payouts
//   authoritative state  whatever Firestore currently holds — every finding
//                      carries `observedAt` (the scan's own run time), never
//                      claimed as a real-time guarantee
//   query strategy     bounded: RECENT_LIMIT most-recent rows per status per
//                      collection, ordered by createdAt/requested time
//   operator action    read the finding, follow its own record ids, decide —
//                      this function only ever reads

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { resolveIsAdmin } from "./complianceGate";

type Db = FirebaseFirestore.Firestore;

/** How many most-recent rows per status this scan reads per collection — bounded by design. */
export const RECENT_LIMIT = 200;

export interface ReconciliationFinding {
  kind:
    | "withdrawal_payout_status_mismatch"
    | "paid_missing_reference"
    | "withdrawal_amount_mismatch"
    | "missing_destination_snapshot"
    | "payout_status_drift";
  actorType: "seller" | "rider" | "employee";
  recordId: string;
  actorId: string;
  amountRupees: number;
  summary: string;
  detail: Record<string, unknown>;
}

const rupees = (paise: unknown) => (typeof paise === "number" ? Math.round(paise) / 100 : 0);

/** seller_withdrawals: paid rows must have every payoutId paid with the SAME reference; a
 * requested row's payoutIds must all still be requested; amountPaise must equal the sum of
 * its own payoutIds' net amounts (requestWithdrawalCore computes it from exactly those rows —
 * a mismatch here is a strong signal of tampering or corruption, not routine drift); every
 * withdrawal must carry at least a masked `destination`. */
async function checkSellerWithdrawals(db: Db, nowMs: number): Promise<ReconciliationFinding[]> {
  const findings: ReconciliationFinding[] = [];
  const [paidQ, requestedQ] = await Promise.all([
    db.collection("seller_withdrawals").where("status", "==", "paid").orderBy("paidAt", "desc").limit(RECENT_LIMIT).get(),
    db.collection("seller_withdrawals").where("status", "==", "requested").orderBy("createdAt", "desc").limit(RECENT_LIMIT).get(),
  ]);
  const rows = [...paidQ.docs, ...requestedQ.docs];
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
    const payoutIds: string[] = Array.isArray(d.payoutIds) ? d.payoutIds.map(String) : [];
    if (payoutIds.length === 0) continue;
    const payoutSnaps = await Promise.all(payoutIds.map((id) => db.collection("seller_payouts").doc(id).get()));
    const payoutSum = payoutSnaps.reduce((sum, p) => {
      const pd = p.data();
      const net = typeof pd?.netAmount === "number" ? pd.netAmount : typeof pd?.amount === "number" ? pd.amount : 0;
      return sum + Math.round(net * 100);
    }, 0);
    if (typeof d.amountPaise === "number" && Math.abs(payoutSum - d.amountPaise) > 0) {
      findings.push({
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
        findings.push({
          kind: "withdrawal_payout_status_mismatch", actorType: "seller", recordId: w.id, actorId: sellerId, amountRupees,
          summary: `Withdrawal is paid but ${bad.length} of its ${payoutIds.length} payout rows are not paid with the same reference.`,
          detail: { paymentReference: d.paymentReference ?? null, mismatchedPayoutIds: bad.map((p) => p.id) },
        });
      }
    } else if (d.status === "requested") {
      const drifted = payoutSnaps.filter((p) => p.data()?.status !== "requested");
      if (drifted.length > 0) {
        findings.push({
          kind: "payout_status_drift", actorType: "seller", recordId: w.id, actorId: sellerId, amountRupees,
          summary: `Withdrawal is still requested but ${drifted.length} of its payout rows have moved to a different status outside this withdrawal.`,
          detail: { driftedPayoutIds: drifted.map((p) => ({ id: p.id, status: p.data()?.status ?? null })) },
        });
      }
    }
  }
  for (const w of rows) {
    const d = w.data();
    if (d.status === "paid" && !(typeof d.paymentReference === "string" && d.paymentReference.trim())) {
      findings.push({
        kind: "paid_missing_reference", actorType: "seller", recordId: w.id, actorId: String(d.sellerId ?? ""), amountRupees: rupees(d.amountPaise),
        summary: "Marked paid but has no payment reference on file.",
        detail: {},
      });
    }
  }
  return findings;
}

/** rider_payouts (weekly statements): the same paid-missing-reference check — riderMoney.ts's
 * own by-design live-resolution model (ADMR-77's own finding) means there is no per-statement
 * destination snapshot to cross-check here, so that check does not apply to riders. */
async function checkRiderPayouts(db: Db): Promise<ReconciliationFinding[]> {
  const paidQ = await db.collection("rider_payouts").where("status", "==", "paid").orderBy("paidAt", "desc").limit(RECENT_LIMIT).get();
  const findings: ReconciliationFinding[] = [];
  for (const p of paidQ.docs) {
    const d = p.data();
    if (!(typeof d.paymentReference === "string" && d.paymentReference.trim())) {
      findings.push({
        kind: "paid_missing_reference", actorType: "rider", recordId: p.id, actorId: String(d.riderId ?? ""), amountRupees: rupees(d.amountPaise),
        summary: "Marked paid but has no payment reference on file.",
        detail: {},
      });
    }
  }
  return findings;
}

/** employee_payouts: same paid-missing-reference check. Amounts here are already in rupees
 * (this collection predates the whole-paise convention seller/rider use — see riderMoney.ts's
 * own header comment on that history), so no paise conversion is applied. */
async function checkEmployeePayouts(db: Db): Promise<ReconciliationFinding[]> {
  const paidQ = await db.collection("employee_payouts").where("status", "==", "paid").orderBy("paidAt", "desc").limit(RECENT_LIMIT).get();
  const findings: ReconciliationFinding[] = [];
  for (const p of paidQ.docs) {
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
  return findings;
}

export interface ReconciliationResult {
  observedAt: number;
  scanned: { sellerWithdrawals: number; riderPayouts: number; employeePayouts: number };
  findings: ReconciliationFinding[];
}

export async function financeReconciliationScanCore(db: Db, nowMs: number): Promise<ReconciliationResult> {
  const [sellerFindings, riderFindings, employeeFindings, sellerCount, riderCount, employeeCount] = await Promise.all([
    checkSellerWithdrawals(db, nowMs),
    checkRiderPayouts(db),
    checkEmployeePayouts(db),
    db.collection("seller_withdrawals").count().get().then((s) => s.data().count),
    db.collection("rider_payouts").where("status", "==", "paid").count().get().then((s) => s.data().count),
    db.collection("employee_payouts").where("status", "==", "paid").count().get().then((s) => s.data().count),
  ]);
  return {
    observedAt: nowMs,
    scanned: { sellerWithdrawals: sellerCount, riderPayouts: riderCount, employeePayouts: employeeCount },
    findings: [...sellerFindings, ...riderFindings, ...employeeFindings],
  };
}

export const financeReconciliationScan = onCall({ minInstances: 0, memory: "256MiB" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required");
  const ok = await resolveIsAdmin(admin.firestore(), request.auth.uid, request.auth.token.admin === true);
  if (!ok) throw new HttpsError("permission-denied", "Admins only");
  return financeReconciliationScanCore(admin.firestore(), Date.now());
});
