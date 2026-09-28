// ============================================================
//  Finance reconciliation — Phase ADMR-80, hardened ADMR-82, extended ADMR-85
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
// ADMR-82 closed 3 real gaps ADMR-80 itself had (honest coverage, a real
// CHILD_READ_BUDGET, and revalidating withdrawal-level candidates against a
// fresh re-read before reporting them).
//
// ADMR-85 found and closed two further gaps a fresh full read of this exact
// file surfaced, plus added real scan continuation:
//  - isCandidateStillReal only ever revalidated 3 PARENT fields, and was only
//    ever called for 3 of the 6 finding kinds — missing_destination_snapshot,
//    paid_missing_reference (all three actor types) and malformed_amount were
//    pushed straight into the result with NO revalidation at all. Every
//    finding kind is now revalidated the same way, via evaluateWithdrawal()
//    below shared identically between first-pass detection, the scan's own
//    confirmation re-read, and on-demand recheck — so confirmation can never
//    silently drift out of sync with what detection actually checks.
//  - no check anywhere re-verified a seller_payouts row's own withdrawalId/
//    sellerId still pointed back at the withdrawal it is listed under — a
//    payout row that drifted to a different withdrawal or seller produced no
//    finding at all. New kind: payout_ownership_mismatch.
//  - RECENT_LIMIT per status per collection had no continuation mechanism —
//    once 200 more-recent rows existed in a status, an older row could never
//    be reached. Every bounded query now supports a cursor (compound-ordered
//    on [orderField desc, documentId desc] for a stable tie-break on equal
//    timestamps) and the result carries `nextCursor`/`hasMore` for real
//    pagination past the page limit.
//
// Reconciliation contract:
//   source records    seller_withdrawals (+ their own payoutIds' seller_payouts
//                      rows, budgeted), rider_payouts, employee_payouts
//   authoritative state  whatever Firestore currently holds at the moment of
//                      each read — every finding carries `confirmation`
//                      (confirmed = an independent second read, using the
//                      SAME logic, on current data, still agrees; unconfirmed
//                      = the child-read budget could not afford that second
//                      look this scan, never a downgrade to "keep it iff we
//                      remember it was bad") and never a real-time guarantee
//                      across the whole scan
//   query strategy     bounded: up to `pageLimit` (default RECENT_LIMIT) rows
//                      per status per collection, ordered by createdAt/paidAt
//                      then documentId; cursor-resumable past that page; a
//                      hard CHILD_READ_BUDGET across the whole run
//   operator action    read the finding, follow its own record ids, decide —
//                      this function only ever reads

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
// Modular import deliberately, not admin.firestore.Timestamp/FieldPath — the namespaced statics
// have been observed undefined under the functions emulator (a bound-proxy gap), v1 and v2 alike.
import { Timestamp, FieldPath } from "firebase-admin/firestore";
import { resolveIsAdmin } from "./complianceGate";

type Db = FirebaseFirestore.Firestore;

/** How many most-recent-per-page rows per status this scan reads per collection by default —
 * bounded by design, but resumable: see ScanCursor/nextCursor below. */
export const RECENT_LIMIT = 200;

/** Hard cap on child-document reads across the WHOLE scan (not per withdrawal) — a single
 * withdrawal can legitimately hold up to sellerWallet.ts's own MAX_PAYOUTS_PER_WITHDRAWAL (400)
 * rows, and confirmation re-reads its children a second time, so this budget covers both passes. */
export const CHILD_READ_BUDGET = 2000;

export type ReconciliationFindingKind =
  | "withdrawal_payout_status_mismatch"
  | "paid_missing_reference"
  | "withdrawal_amount_mismatch"
  | "missing_destination_snapshot"
  | "payout_status_drift"
  | "malformed_amount"
  | "payout_ownership_mismatch";

export interface ReconciliationFinding {
  /** Stable across rescans of the same underlying condition: `${kind}:${recordId}` — lets a
   * support-case link or a UI "recheck" refer to exactly this finding without re-deriving it. */
  id: string;
  kind: ReconciliationFindingKind;
  actorType: "seller" | "rider" | "employee";
  recordId: string;
  actorId: string;
  amountRupees: number;
  summary: string;
  detail: Record<string, unknown>;
  /** "confirmed": an independent, later, targeted re-read reproduced the same condition via the
   * same check used to detect it. "unconfirmed": the child-read budget could not afford that
   * second look this scan — still reported (never silently hidden for a budget reason), but
   * disclosed as not independently re-verified. A finding that DID get re-read and no longer
   * reproduced is dropped entirely, not reported in either state. */
  confirmation: "confirmed" | "unconfirmed";
}

/** What was actually inspected for one collection/status, never conflated with the collection's
 * total size. `totalInStatuses` counts only the SAME status this page covers (a cheap aggregate
 * query, not a per-document read), so `truncated` is a real, honest signal, not a guess. */
export interface CoverageReport {
  inspected: number;
  statusesCovered: string[];
  limit: number;
  truncated: boolean;
  totalInStatuses: number;
}

/** A resume point for one (collection, status) query: the ordered field's own value in
 * milliseconds and the document id, matching the compound [orderField desc, documentId desc]
 * ordering every bounded query now uses — a stable tie-break when many rows share one timestamp. */
export interface StatusCursor {
  value: number;
  id: string;
}

export interface ScanCursor {
  sellerWithdrawals: { paid: StatusCursor | null; requested: StatusCursor | null };
  riderPayouts: StatusCursor | null;
  employeePayouts: StatusCursor | null;
}

/** What a caller passes IN to resume a scan — any subset; an omitted group/status starts from the
 * most recent row, exactly like a first scan. */
export interface ScanCursorInput {
  sellerWithdrawals?: { paid?: StatusCursor; requested?: StatusCursor };
  riderPayouts?: StatusCursor;
  employeePayouts?: StatusCursor;
}

export interface ReconciliationResult {
  observedAt: number;
  coverage: { sellerWithdrawals: CoverageReport; riderPayouts: CoverageReport; employeePayouts: CoverageReport };
  incomplete: boolean;
  incompleteReasons: string[];
  findings: ReconciliationFinding[];
  /** Pass this back as `cursor` to continue past this page; a group with `null` is exhausted. */
  nextCursor: ScanCursor;
  /** True iff any group in `nextCursor` is non-null — a cheap top-level "there is more" signal. */
  hasMore: boolean;
}

const rupees = (paise: unknown) => (typeof paise === "number" ? Math.round(paise) / 100 : 0);
const isFiniteNumber = (v: unknown): v is number => typeof v === "number" && Number.isFinite(v);

export type FindingCandidate = Omit<ReconciliationFinding, "confirmation">;

/** Complete, from-scratch evaluation of ONE seller withdrawal against its OWN current children —
 * never a comparison against a prior read's cached fields. Used identically for first-pass
 * detection, the scan's own confirmation re-read, and on-demand recheck (recheckFindingCore), so
 * confirmation can never silently drift out of sync with detection. `payoutSnaps === null` means
 * the children could not be read this pass (child-read budget): child-derived checks (amount sum,
 * status/ownership consistency, malformed amounts) are skipped, not guessed — parent-only checks
 * (destination snapshot, paid-missing-reference) still run since they cost nothing extra. */
export function evaluateWithdrawal(
  wId: string,
  d: FirebaseFirestore.DocumentData,
  payoutSnaps: FirebaseFirestore.DocumentSnapshot[] | null
): FindingCandidate[] {
  const sellerId = String(d.sellerId ?? "");
  const amountRupees = rupees(d.amountPaise);
  const out: FindingCandidate[] = [];

  if (!d.destination && !d.destinationFull) {
    out.push({
      id: `missing_destination_snapshot:${wId}`,
      kind: "missing_destination_snapshot", actorType: "seller", recordId: wId, actorId: sellerId, amountRupees,
      summary: "This withdrawal has no destination on file at all — should not be reachable via the normal request flow.",
      detail: { status: d.status },
    });
  }
  if (d.status === "paid" && !(typeof d.paymentReference === "string" && d.paymentReference.trim())) {
    out.push({
      id: `paid_missing_reference:${wId}`,
      kind: "paid_missing_reference", actorType: "seller", recordId: wId, actorId: sellerId, amountRupees,
      summary: "Marked paid but has no payment reference on file.", detail: {},
    });
  }
  // No children to compare against — the amount-sum/status/drift/ownership checks below are only
  // meaningful when there is at least one payout row; an empty payoutIds array (should not happen
  // via the normal request flow, but is not itself what these checks exist to catch) would
  // otherwise compare a real amountPaise against the sum of nothing and always "mismatch".
  if (payoutSnaps === null || payoutSnaps.length === 0) return out;

  const payoutIds = payoutSnaps.map((p) => p.id);
  let sumKnown = true;
  let payoutSum = 0;
  for (const p of payoutSnaps) {
    const pd = p.data();
    const net = isFiniteNumber(pd?.netAmount) ? pd!.netAmount : isFiniteNumber(pd?.amount) ? pd!.amount : null;
    if (net === null) {
      sumKnown = false;
      out.push({
        id: `malformed_amount:${p.id}`,
        kind: "malformed_amount", actorType: "seller", recordId: p.id, actorId: sellerId, amountRupees: 0,
        summary: `Payout row referenced by withdrawal ${wId} has no valid numeric amount — excluded from that withdrawal's own amount check.`,
        detail: { withdrawalId: wId },
      });
    } else {
      payoutSum += Math.round(net * 100);
    }
    if (pd && (String(pd.withdrawalId ?? "") !== wId || String(pd.sellerId ?? "") !== sellerId)) {
      out.push({
        id: `payout_ownership_mismatch:${p.id}`,
        kind: "payout_ownership_mismatch", actorType: "seller", recordId: p.id, actorId: sellerId, amountRupees: net ?? 0,
        summary: `Payout row is listed under withdrawal ${wId} but its own withdrawalId/sellerId no longer points back to it.`,
        detail: {
          expectedWithdrawalId: wId, actualWithdrawalId: pd.withdrawalId ?? null,
          expectedSellerId: sellerId, actualSellerId: pd.sellerId ?? null,
        },
      });
    }
  }
  if (sumKnown && typeof d.amountPaise === "number" && Math.abs(payoutSum - d.amountPaise) > 0) {
    out.push({
      id: `withdrawal_amount_mismatch:${wId}`,
      kind: "withdrawal_amount_mismatch", actorType: "seller", recordId: wId, actorId: sellerId, amountRupees,
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
      out.push({
        id: `withdrawal_payout_status_mismatch:${wId}`,
        kind: "withdrawal_payout_status_mismatch", actorType: "seller", recordId: wId, actorId: sellerId, amountRupees,
        summary: `Withdrawal is paid but ${bad.length} of its ${payoutIds.length} payout rows are not paid with the same reference.`,
        detail: { paymentReference: d.paymentReference ?? null, mismatchedPayoutIds: bad.map((p) => p.id) },
      });
    }
  } else if (d.status === "requested") {
    const drifted = payoutSnaps.filter((p) => p.data()?.status !== "requested");
    if (drifted.length > 0) {
      out.push({
        id: `payout_status_drift:${wId}`,
        kind: "payout_status_drift", actorType: "seller", recordId: wId, actorId: sellerId, amountRupees,
        summary: `Withdrawal is still requested but ${drifted.length} of its payout rows have moved to a different status outside this withdrawal.`,
        detail: { driftedPayoutIds: drifted.map((p) => ({ id: p.id, status: p.data()?.status ?? null })) },
      });
    }
  }
  return out;
}

/** One status's own bounded, cursor-resumable query plus its own honest coverage report.
 * Ordered by [orderField desc, documentId desc] — the documentId tiebreak makes paging stable
 * even when many rows share the exact same orderField timestamp, which a single-field order
 * cannot guarantee. `possibleBlindSpot` is a first-page-only, honest signal: this page was NOT
 * full (Firestore says no more rows match the ordered query) yet the status's own total count is
 * higher — most plausibly because some rows are missing `orderField` entirely (Firestore's
 * orderBy silently excludes documents missing the ordered field), which no cursor can ever reach. */
async function boundedByStatus(
  db: Db, collection: string, status: string, orderField: string, limit: number, startAfter?: StatusCursor
): Promise<{
  docs: FirebaseFirestore.QueryDocumentSnapshot[];
  coverage: CoverageReport;
  nextCursor: StatusCursor | null;
  possibleBlindSpot: boolean;
}> {
  let q: FirebaseFirestore.Query = db
    .collection(collection)
    .where("status", "==", status)
    .orderBy(orderField, "desc")
    .orderBy(FieldPath.documentId(), "desc");
  if (startAfter) {
    q = q.startAfter(Timestamp.fromMillis(startAfter.value), startAfter.id);
  }
  const [snap, countSnap] = await Promise.all([
    q.limit(limit).get(),
    db.collection(collection).where("status", "==", status).count().get(),
  ]);
  const total = countSnap.data().count;
  const lastDoc = snap.docs[snap.docs.length - 1];
  const lastRaw = lastDoc ? lastDoc.get(orderField) : undefined;
  const lastMs = lastRaw && typeof lastRaw.toMillis === "function" ? lastRaw.toMillis() : null;
  const nextCursor: StatusCursor | null =
    snap.docs.length === limit && lastDoc && lastMs !== null ? { value: lastMs, id: lastDoc.id } : null;
  return {
    docs: snap.docs,
    coverage: { inspected: snap.docs.length, statusesCovered: [status], limit, truncated: total > snap.docs.length, totalInStatuses: total },
    nextCursor,
    possibleBlindSpot: !startAfter && snap.docs.length < limit && total > snap.docs.length,
  };
}

function mergeCoverage(a: CoverageReport, b: CoverageReport): CoverageReport {
  return {
    inspected: a.inspected + b.inspected,
    statusesCovered: [...a.statusesCovered, ...b.statusesCovered],
    limit: a.limit,
    truncated: a.truncated || b.truncated,
    totalInStatuses: a.totalInStatuses + b.totalInStatuses,
  };
}

/** seller_withdrawals: every finding kind evaluateWithdrawal() can produce. Bounded by
 * CHILD_READ_BUDGET across the whole scan — a budgetState object shared across collections and
 * across BOTH the first pass and the confirmation pass below. */
async function checkSellerWithdrawals(
  db: Db, budget: { remaining: number }, incompleteReasons: string[], pageLimit: number,
  cursorIn: { paid?: StatusCursor; requested?: StatusCursor }
): Promise<{
  findings: ReconciliationFinding[];
  coverage: CoverageReport;
  nextCursor: { paid: StatusCursor | null; requested: StatusCursor | null };
}> {
  const initialBudget = budget.remaining;
  const findings: ReconciliationFinding[] = [];
  const [paid, requested] = await Promise.all([
    boundedByStatus(db, "seller_withdrawals", "paid", "paidAt", pageLimit, cursorIn.paid),
    boundedByStatus(db, "seller_withdrawals", "requested", "createdAt", pageLimit, cursorIn.requested),
  ]);
  if (paid.possibleBlindSpot) {
    incompleteReasons.push(
      `${paid.coverage.totalInStatuses - paid.coverage.inspected} paid seller withdrawal(s) exist but were never returned by this scan's own ordered query — likely missing a paidAt value; not reachable via cursor continuation either.`
    );
  }
  if (requested.possibleBlindSpot) {
    incompleteReasons.push(
      `${requested.coverage.totalInStatuses - requested.coverage.inspected} requested seller withdrawal(s) exist but were never returned by this scan's own ordered query — likely missing a createdAt value; not reachable via cursor continuation either.`
    );
  }
  const rows = [...paid.docs, ...requested.docs];
  let budgetExhausted = false;

  for (const w of rows) {
    const d = w.data();
    const payoutIds: string[] = Array.isArray(d.payoutIds) ? d.payoutIds.map(String) : [];
    let payoutSnaps: FirebaseFirestore.DocumentSnapshot[] | null = null;
    if (payoutIds.length === 0) {
      payoutSnaps = [];
    } else if (!budgetExhausted && payoutIds.length <= budget.remaining) {
      budget.remaining -= payoutIds.length;
      payoutSnaps = await Promise.all(payoutIds.map((id) => db.collection("seller_payouts").doc(id).get()));
    } else {
      budgetExhausted = true;
      incompleteReasons.push(
        `Child-read budget (${initialBudget}) reached while inspecting seller withdrawal ${w.id} and later rows — their own payout rows were not checked this scan.`
      );
    }

    const firstPass = evaluateWithdrawal(w.id, d, payoutSnaps);
    if (firstPass.length === 0) continue;

    // Confirmation: an independent, later, targeted fresh re-read of the SAME withdrawal and its
    // (possibly changed) current children — never a comparison of a few cached fields. Reuses the
    // exact same evaluation used above, so confirmation cannot drift out of sync with detection.
    const freshSnap = await db.collection("seller_withdrawals").doc(w.id).get();
    if (!freshSnap.exists) continue; // the withdrawal itself is gone — nothing left to report
    const freshD = freshSnap.data()!;
    const freshPayoutIds: string[] = Array.isArray(freshD.payoutIds) ? freshD.payoutIds.map(String) : [];
    let freshSnaps: FirebaseFirestore.DocumentSnapshot[] | null = null;
    let childrenUnaffordable = false;
    if (freshPayoutIds.length === 0) {
      freshSnaps = [];
    } else if (freshPayoutIds.length <= budget.remaining) {
      budget.remaining -= freshPayoutIds.length;
      freshSnaps = await Promise.all(freshPayoutIds.map((id) => db.collection("seller_payouts").doc(id).get()));
    } else {
      childrenUnaffordable = true;
      incompleteReasons.push(
        `Child-read budget (${initialBudget}) reached while re-confirming seller withdrawal ${w.id} — its finding(s) are reported as unconfirmed, not independently re-verified this scan.`
      );
    }
    const reconfirmed = new Set(evaluateWithdrawal(w.id, freshD, freshSnaps).map((f) => f.id));

    for (const cand of firstPass) {
      const isParentOnly = cand.kind === "missing_destination_snapshot" || cand.kind === "paid_missing_reference";
      if (!isParentOnly && childrenUnaffordable) {
        findings.push({ ...cand, confirmation: "unconfirmed" });
      } else if (reconfirmed.has(cand.id)) {
        findings.push({ ...cand, confirmation: "confirmed" });
      }
      // else: resolved between the two reads — genuinely no longer true, dropped, not reported.
    }
  }
  const coverage = mergeCoverage(paid.coverage, requested.coverage);
  return { findings, coverage, nextCursor: { paid: paid.nextCursor, requested: requested.nextCursor } };
}

/** rider_payouts (weekly statements): the same paid-missing-reference check — riderMoney.ts's
 * own by-design live-resolution model (ADMR-77's own finding) means there is no per-statement
 * destination snapshot to cross-check here, so that check does not apply to riders. Every
 * candidate is now confirmed against an independent fresh re-read before being reported. */
async function checkRiderPayouts(
  db: Db, pageLimit: number, incompleteReasons: string[], cursorIn?: StatusCursor
): Promise<{ findings: ReconciliationFinding[]; coverage: CoverageReport; nextCursor: StatusCursor | null }> {
  const { docs, coverage, nextCursor, possibleBlindSpot } = await boundedByStatus(db, "rider_payouts", "paid", "paidAt", pageLimit, cursorIn);
  if (possibleBlindSpot) {
    incompleteReasons.push(
      `${coverage.totalInStatuses - coverage.inspected} paid rider payout(s) exist but were never returned by this scan's own ordered query — likely missing a paidAt value.`
    );
  }
  const findings: ReconciliationFinding[] = [];
  for (const p of docs) {
    const d = p.data();
    if (typeof d.paymentReference === "string" && d.paymentReference.trim()) continue;
    const fresh = (await db.collection("rider_payouts").doc(p.id).get()).data();
    if (!fresh) continue; // gone since the first read
    if (typeof fresh.paymentReference === "string" && fresh.paymentReference.trim()) continue; // resolved since
    findings.push({
      id: `paid_missing_reference:${p.id}`,
      kind: "paid_missing_reference", actorType: "rider", recordId: p.id, actorId: String(d.riderId ?? ""), amountRupees: rupees(d.amountPaise),
      summary: "Marked paid but has no payment reference on file.", detail: {}, confirmation: "confirmed",
    });
  }
  return { findings, coverage, nextCursor };
}

/** employee_payouts: same paid-missing-reference check, independently confirmed. Amounts here are
 * already in rupees (this collection predates the whole-paise convention seller/rider use — see
 * riderMoney.ts's own header comment on that history), so no paise conversion is applied. */
async function checkEmployeePayouts(
  db: Db, pageLimit: number, incompleteReasons: string[], cursorIn?: StatusCursor
): Promise<{ findings: ReconciliationFinding[]; coverage: CoverageReport; nextCursor: StatusCursor | null }> {
  const { docs, coverage, nextCursor, possibleBlindSpot } = await boundedByStatus(db, "employee_payouts", "paid", "paidAt", pageLimit, cursorIn);
  if (possibleBlindSpot) {
    incompleteReasons.push(
      `${coverage.totalInStatuses - coverage.inspected} paid associate payout(s) exist but were never returned by this scan's own ordered query — likely missing a paidAt value.`
    );
  }
  const findings: ReconciliationFinding[] = [];
  for (const p of docs) {
    const d = p.data();
    if (typeof d.paymentReference === "string" && d.paymentReference.trim()) continue;
    const fresh = (await db.collection("employee_payouts").doc(p.id).get()).data();
    if (!fresh) continue;
    if (typeof fresh.paymentReference === "string" && fresh.paymentReference.trim()) continue;
    findings.push({
      id: `paid_missing_reference:${p.id}`,
      kind: "paid_missing_reference", actorType: "employee", recordId: p.id, actorId: String(d.employeeId ?? ""),
      amountRupees: typeof d.amount === "number" ? d.amount : 0,
      summary: "Marked paid but has no payment reference on file.", detail: {}, confirmation: "confirmed",
    });
  }
  return { findings, coverage, nextCursor };
}

/** `childReadBudget` defaults to the real CHILD_READ_BUDGET; overridable so a test can prove the
 * exhaustion path fires without seeding thousands of documents. `cursor`/`pageLimit` default to a
 * fresh first page at the real RECENT_LIMIT; overridable the same way, for the same reason. */
export async function financeReconciliationScanCore(
  db: Db,
  nowMs: number,
  childReadBudget: number = CHILD_READ_BUDGET,
  cursor: ScanCursorInput = {},
  pageLimit: number = RECENT_LIMIT
): Promise<ReconciliationResult> {
  const incompleteReasons: string[] = [];
  const budget = { remaining: childReadBudget };
  const [seller, rider, employee] = await Promise.all([
    checkSellerWithdrawals(db, budget, incompleteReasons, pageLimit, cursor.sellerWithdrawals ?? {}),
    checkRiderPayouts(db, pageLimit, incompleteReasons, cursor.riderPayouts),
    checkEmployeePayouts(db, pageLimit, incompleteReasons, cursor.employeePayouts),
  ]);
  const nextCursor: ScanCursor = {
    sellerWithdrawals: { paid: seller.nextCursor.paid, requested: seller.nextCursor.requested },
    riderPayouts: rider.nextCursor,
    employeePayouts: employee.nextCursor,
  };
  const hasMore =
    nextCursor.sellerWithdrawals.paid !== null ||
    nextCursor.sellerWithdrawals.requested !== null ||
    nextCursor.riderPayouts !== null ||
    nextCursor.employeePayouts !== null;
  return {
    observedAt: nowMs,
    coverage: { sellerWithdrawals: seller.coverage, riderPayouts: rider.coverage, employeePayouts: employee.coverage },
    incomplete: incompleteReasons.length > 0,
    incompleteReasons,
    findings: [...seller.findings, ...rider.findings, ...employee.findings],
    nextCursor,
    hasMore,
  };
}

export type RecheckInput = Pick<ReconciliationFinding, "kind" | "actorType" | "recordId" | "detail">;
export type RecheckVerdict =
  | { kind: "confirmed"; finding: ReconciliationFinding }
  | { kind: "resolved" }
  | { kind: "not_found" };

const SELLER_WITHDRAWAL_KINDS = new Set<ReconciliationFindingKind>([
  "missing_destination_snapshot", "paid_missing_reference", "withdrawal_amount_mismatch",
  "withdrawal_payout_status_mismatch", "payout_status_drift",
]);

/** The UI's own "recheck" step (workflow: bounded scan → confirmed finding → ... → recheck →
 * linked support case → return to scan). Given exactly the finding an operator is looking at
 * (kind/actorType/recordId/detail — nothing else, never a client-supplied path), re-derives it
 * completely fresh, live, on demand — via the SAME evaluateWithdrawal() the scan itself uses for
 * the seller-withdrawal-family kinds, or an equivalent single-record fresh check for the rest.
 * Never mutates anything; this is exactly as read-only as the scan itself. */
export async function recheckFindingCore(db: Db, input: RecheckInput): Promise<RecheckVerdict> {
  const { kind, actorType, recordId, detail } = input;

  if (actorType === "seller" && SELLER_WITHDRAWAL_KINDS.has(kind)) {
    const w = await db.collection("seller_withdrawals").doc(recordId).get();
    if (!w.exists) return { kind: "not_found" };
    const d = w.data()!;
    const payoutIds: string[] = Array.isArray(d.payoutIds) ? d.payoutIds.map(String) : [];
    const payoutSnaps = payoutIds.length
      ? await Promise.all(payoutIds.map((id) => db.collection("seller_payouts").doc(id).get()))
      : [];
    const found = evaluateWithdrawal(recordId, d, payoutSnaps).find((f) => f.kind === kind);
    return found ? { kind: "confirmed", finding: { ...found, confirmation: "confirmed" } } : { kind: "resolved" };
  }

  if (actorType === "seller" && kind === "malformed_amount") {
    const p = await db.collection("seller_payouts").doc(recordId).get();
    if (!p.exists) return { kind: "not_found" };
    const pd = p.data()!;
    const net = isFiniteNumber(pd.netAmount) ? pd.netAmount : isFiniteNumber(pd.amount) ? pd.amount : null;
    if (net !== null) return { kind: "resolved" };
    const withdrawalId = String(detail.withdrawalId ?? "");
    return {
      kind: "confirmed",
      finding: {
        id: `malformed_amount:${recordId}`, kind: "malformed_amount", actorType: "seller",
        recordId, actorId: String(pd.sellerId ?? ""), amountRupees: 0,
        summary: `Payout row referenced by withdrawal ${withdrawalId} has no valid numeric amount — excluded from that withdrawal's own amount check.`,
        detail: { withdrawalId }, confirmation: "confirmed",
      },
    };
  }

  if (actorType === "seller" && kind === "payout_ownership_mismatch") {
    const p = await db.collection("seller_payouts").doc(recordId).get();
    if (!p.exists) return { kind: "not_found" };
    const pd = p.data()!;
    const expectedWithdrawalId = String(detail.expectedWithdrawalId ?? "");
    const expectedSellerId = String(detail.expectedSellerId ?? "");
    if (String(pd.withdrawalId ?? "") === expectedWithdrawalId && String(pd.sellerId ?? "") === expectedSellerId) {
      return { kind: "resolved" };
    }
    const net = isFiniteNumber(pd.netAmount) ? pd.netAmount : isFiniteNumber(pd.amount) ? pd.amount : 0;
    return {
      kind: "confirmed",
      finding: {
        id: `payout_ownership_mismatch:${recordId}`, kind: "payout_ownership_mismatch", actorType: "seller",
        recordId, actorId: expectedSellerId, amountRupees: net,
        summary: `Payout row is listed under withdrawal ${expectedWithdrawalId} but its own withdrawalId/sellerId no longer points back to it.`,
        detail: {
          expectedWithdrawalId, actualWithdrawalId: pd.withdrawalId ?? null,
          expectedSellerId, actualSellerId: pd.sellerId ?? null,
        },
        confirmation: "confirmed",
      },
    };
  }

  if ((actorType === "rider" || actorType === "employee") && kind === "paid_missing_reference") {
    const coll = actorType === "rider" ? "rider_payouts" : "employee_payouts";
    const p = await db.collection(coll).doc(recordId).get();
    if (!p.exists) return { kind: "not_found" };
    const pd = p.data()!;
    if (typeof pd.paymentReference === "string" && pd.paymentReference.trim()) return { kind: "resolved" };
    const actorId = String((actorType === "rider" ? pd.riderId : pd.employeeId) ?? "");
    const amountRupees = actorType === "rider" ? rupees(pd.amountPaise) : typeof pd.amount === "number" ? pd.amount : 0;
    return {
      kind: "confirmed",
      finding: {
        id: `paid_missing_reference:${recordId}`, kind: "paid_missing_reference", actorType,
        recordId, actorId, amountRupees,
        summary: "Marked paid but has no payment reference on file.", detail: {}, confirmation: "confirmed",
      },
    };
  }

  return { kind: "not_found" };
}

function parseStatusCursor(v: unknown): StatusCursor | undefined {
  if (!v || typeof v !== "object") return undefined;
  const r = v as Record<string, unknown>;
  if (typeof r.value !== "number" || typeof r.id !== "string" || !r.id.trim()) return undefined;
  return { value: r.value, id: r.id };
}

function parseScanCursorInput(v: unknown): ScanCursorInput {
  if (!v || typeof v !== "object") return {};
  const r = v as Record<string, unknown>;
  const sw = r.sellerWithdrawals && typeof r.sellerWithdrawals === "object" ? (r.sellerWithdrawals as Record<string, unknown>) : {};
  return {
    sellerWithdrawals: { paid: parseStatusCursor(sw.paid), requested: parseStatusCursor(sw.requested) },
    riderPayouts: parseStatusCursor(r.riderPayouts),
    employeePayouts: parseStatusCursor(r.employeePayouts),
  };
}

export const financeReconciliationScan = onCall({ minInstances: 0, memory: "256MiB" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required");
  const ok = await resolveIsAdmin(admin.firestore(), request.auth.uid, request.auth.token.admin === true);
  if (!ok) throw new HttpsError("permission-denied", "Admins only");
  const cursor = parseScanCursorInput(request.data && (request.data as Record<string, unknown>).cursor);
  return financeReconciliationScanCore(admin.firestore(), Date.now(), CHILD_READ_BUDGET, cursor);
});

export const financeReconciliationRecheckFinding = onCall({ minInstances: 0, memory: "256MiB" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required");
  const ok = await resolveIsAdmin(admin.firestore(), request.auth.uid, request.auth.token.admin === true);
  if (!ok) throw new HttpsError("permission-denied", "Admins only");
  const d = (request.data ?? {}) as Record<string, unknown>;
  const kind = typeof d.kind === "string" ? (d.kind as ReconciliationFindingKind) : undefined;
  const actorType = d.actorType === "seller" || d.actorType === "rider" || d.actorType === "employee" ? d.actorType : undefined;
  const recordId = typeof d.recordId === "string" && d.recordId.trim() ? d.recordId : undefined;
  const detail = d.detail && typeof d.detail === "object" ? (d.detail as Record<string, unknown>) : {};
  if (!kind || !actorType || !recordId) {
    throw new HttpsError("invalid-argument", "kind, actorType and recordId are required");
  }
  return recheckFindingCore(admin.firestore(), { kind, actorType, recordId, detail });
});
