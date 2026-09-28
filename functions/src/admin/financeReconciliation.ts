// ============================================================
//  Finance reconciliation — Phase ADMR-80, hardened ADMR-82,
//  extended ADMR-85, cursor contract fixed ADMR-88
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
// file surfaced, plus added scan continuation — but that continuation
// contract itself had a real bug, found and fixed here:
//  - isCandidateStillReal only ever revalidated 3 PARENT fields, and was only
//    ever called for 3 of the 6 finding kinds. Every finding kind is now
//    revalidated the same way, via evaluateWithdrawal() below shared
//    identically between first-pass detection, the scan's own confirmation
//    re-read, and on-demand recheck.
//  - no check anywhere re-verified a seller_payouts row's own withdrawalId/
//    sellerId still pointed back at the withdrawal it is listed under.
//    New kind: payout_ownership_mismatch.
//  - RECENT_LIMIT per status per collection had no continuation mechanism.
//
// ADMR-88 fixed the continuation contract ADMR-85 itself shipped with a real
// bug: the scan's own OUTPUT used `null` for "this group is exhausted", but
// the INPUT parser (`parseStatusCursor`) returned `undefined` for BOTH
// v===undefined (a key genuinely absent) AND v===null — `!v` is true for
// both. A client that takes a scan result's own nextCursor and passes it
// straight back as the next call's cursor (the only sane way to "continue" —
// and exactly what finance_reconciliation_screen.dart's own _loadMore does)
// therefore had every already-exhausted group's `null` silently
// reinterpreted as "absent", restarting that group's query from the very
// top on every subsequent page — not a rare edge case, but the NORMAL
// outcome the very first time a scan spans groups of different lengths,
// which is the ordinary case, not an unusual one. The root cause was never
// really "a missed null check": JS's null/undefined distinction does not
// survive a callable's own JSON marshalling reliably in the first place, so
// encoding a THIRD, load-bearing meaning ("exhausted") into that distinction
// was unsound from the start. Fixed by replacing the inferred null/undefined
// encoding with an explicit tagged GroupCursorState — {state:"start"} /
// {state:"continue", cursor} / {state:"exhausted"} — for both input and
// output, so "exhausted" can never be silently reinterpreted as "absent"
// again. The same pass fixed a second, related precision bug: StatusCursor
// stored only `Timestamp.toMillis()`, which truncates Firestore's own
// sub-millisecond nanosecond precision (verified empirically: a Timestamp
// round-tripped through toMillis()/fromMillis() is NOT isEqual() to the
// original) — StatusCursor now stores {seconds, nanoseconds} directly,
// Firestore's own lossless representation. A cursor schema version is
// validated and rejected outright on mismatch, and any other malformed
// cursor shape is rejected the same way — never silently treated as
// "start", which would have quietly re-scanned already-covered rows without
// even the (buggy) intent of resuming them. The same pass also tightened
// confirmation's own read coherence: a withdrawal's parent and its children
// used to be re-read via separate, sequential calls (a parent .get(), then
// a Promise.all of child .get()s) — each could observe a different instant,
// so "confirmed" was never quite the snapshot-consistent guarantee its own
// name implied. Both the scan's own confirmation pass and recheckFindingCore
// now read parent and children together via db.getAll(), a single Firestore
// call returning a consistent snapshot across multiple documents — sound
// because payoutIds is set once at request time and never mutated
// afterward, so the ids already known are still the right ones to read
// alongside their parent.
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
//                      then documentId; cursor-resumable past that page via
//                      an explicit, versioned, tagged per-group state; a
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

/** Bumped whenever the query/ordering contract changes in a way that would make an old cursor
 * unsafe to resume from (a different sort, a different compound index, …). A cursor citing a
 * different version is REJECTED outright (HttpsError), never silently treated as "start" — a
 * silent restart would quietly re-scan rows the caller already believed were covered, which is
 * exactly the class of bug this whole phase exists to close. */
export const CURSOR_VERSION = 1;

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
 * query, not a per-document read), so `truncated` is a real, honest signal, not a guess. Empty
 * (inspected 0, statusesCovered []) for a group this page skipped entirely because it was already
 * exhausted — that skip is itself informative (no cost was spent re-confirming nothing changed). */
export interface CoverageReport {
  inspected: number;
  statusesCovered: string[];
  limit: number;
  truncated: boolean;
  totalInStatuses: number;
}

/** A resume point for one (collection, status) query: the ordered field's own value, stored
 * losslessly (Firestore Timestamps carry sub-millisecond nanosecond precision that a single
 * milliseconds number cannot represent — ADMR-88's own fix), plus the document id, matching the
 * compound [orderField desc, documentId desc] ordering every bounded query uses — a stable
 * tie-break when many rows share one timestamp. */
export interface StatusCursor {
  seconds: number;
  nanoseconds: number;
  id: string;
}

/** One group's own continuation state, ALWAYS one of exactly three explicit, tagged
 * possibilities — never inferred from whether a field is present, null or undefined, which is
 * the distinction ADMR-85's own bug silently collapsed. "start": no progress yet (a fresh scan,
 * or the caller explicitly wants to re-scan this group from the top). "continue": resume strictly
 * after this exact point. "exhausted": every row in this status has already been seen; do not
 * query it again — this state, once reached, is a fixed point: round-tripping it back in must
 * reproduce it, never regress to "start". */
export type GroupCursorState =
  | { state: "start" }
  | { state: "continue"; cursor: StatusCursor }
  | { state: "exhausted" };

export interface ScanCursor {
  version: number;
  sellerWithdrawals: { paid: GroupCursorState; requested: GroupCursorState };
  riderPayouts: GroupCursorState;
  employeePayouts: GroupCursorState;
}

/** What a caller passes IN to resume a scan — any group may be omitted entirely, which means
 * "start" for that group (a fresh first scan sends `{}`, or omits sub-fields it has no opinion
 * on yet). A group that IS present must be a fully-shaped GroupCursorState — never a bare
 * StatusCursor and never null; either is rejected as malformed, not silently reinterpreted. */
export interface ScanCursorInput {
  version?: number;
  sellerWithdrawals?: { paid?: GroupCursorState; requested?: GroupCursorState };
  riderPayouts?: GroupCursorState;
  employeePayouts?: GroupCursorState;
}

export interface ReconciliationResult {
  observedAt: number;
  coverage: { sellerWithdrawals: CoverageReport; riderPayouts: CoverageReport; employeePayouts: CoverageReport };
  incomplete: boolean;
  incompleteReasons: string[];
  findings: ReconciliationFinding[];
  /** Pass this back VERBATIM, opaquely, as `cursor` to continue past this page — a caller must
   * never reconstruct or reinterpret it. A group in the "exhausted" state MUST still be included
   * (not stripped) when passed back; that is precisely the state the fixed parser now honors
   * instead of silently discarding. */
  nextCursor: ScanCursor;
  /** True iff any group in `nextCursor` is NOT "exhausted" — a cheap top-level "there is more"
   * signal. */
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

function timestampToCursor(t: unknown, id: string): StatusCursor | null {
  if (!t || typeof t !== "object") return null;
  const maybe = t as { seconds?: unknown; nanoseconds?: unknown };
  if (typeof maybe.seconds !== "number" || typeof maybe.nanoseconds !== "number") return null;
  return { seconds: maybe.seconds, nanoseconds: maybe.nanoseconds, id };
}

/** One status's own bounded, cursor-resumable query plus its own honest coverage report.
 * Ordered by [orderField desc, documentId desc] — the documentId tiebreak makes paging stable
 * even when many rows share the exact same orderField timestamp, which a single-field order
 * cannot guarantee. An "exhausted" groupState short-circuits to a zero-cost result — no query,
 * no count, nothing to confirm — matching the whole point of marking a group exhausted in the
 * first place. `possibleBlindSpot` is a first-page-only, honest signal: this page was NOT full
 * (Firestore says no more rows match the ordered query) yet the status's own total count is
 * higher — most plausibly because some rows are missing `orderField` entirely (Firestore's
 * orderBy silently excludes documents missing the ordered field), which no cursor can ever reach. */
async function boundedByStatus(
  db: Db, collection: string, status: string, orderField: string, limit: number, groupState: GroupCursorState
): Promise<{
  docs: FirebaseFirestore.QueryDocumentSnapshot[];
  coverage: CoverageReport;
  nextCursor: GroupCursorState;
  possibleBlindSpot: boolean;
}> {
  if (groupState.state === "exhausted") {
    return {
      docs: [],
      coverage: { inspected: 0, statusesCovered: [], limit, truncated: false, totalInStatuses: 0 },
      nextCursor: { state: "exhausted" },
      possibleBlindSpot: false,
    };
  }
  let q: FirebaseFirestore.Query = db
    .collection(collection)
    .where("status", "==", status)
    .orderBy(orderField, "desc")
    .orderBy(FieldPath.documentId(), "desc");
  if (groupState.state === "continue") {
    q = q.startAfter(new Timestamp(groupState.cursor.seconds, groupState.cursor.nanoseconds), groupState.cursor.id);
  }
  const [snap, countSnap] = await Promise.all([
    q.limit(limit).get(),
    db.collection(collection).where("status", "==", status).count().get(),
  ]);
  const total = countSnap.data().count;
  const lastDoc = snap.docs[snap.docs.length - 1];
  const lastCursor = lastDoc ? timestampToCursor(lastDoc.get(orderField), lastDoc.id) : null;
  const nextCursor: GroupCursorState =
    snap.docs.length === limit && lastCursor ? { state: "continue", cursor: lastCursor } : { state: "exhausted" };
  return {
    docs: snap.docs,
    coverage: { inspected: snap.docs.length, statusesCovered: [status], limit, truncated: total > snap.docs.length, totalInStatuses: total },
    nextCursor,
    possibleBlindSpot: groupState.state === "start" && snap.docs.length < limit && total > snap.docs.length,
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
  cursorIn: { paid: GroupCursorState; requested: GroupCursorState }
): Promise<{
  findings: ReconciliationFinding[];
  coverage: CoverageReport;
  nextCursor: { paid: GroupCursorState; requested: GroupCursorState };
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

    // Confirmation: an independent, later, SNAPSHOT-CONSISTENT re-read of the SAME withdrawal and
    // its children via getAll() — one Firestore call reading multiple documents as of a single
    // consistent moment, strictly stronger than the parent and each child being read by separate
    // .get() calls that could each observe a different instant. Reuses the exact same evaluation
    // used above, so confirmation cannot drift out of sync with detection. Reuses THIS withdrawal's
    // own already-known payoutIds (not a fresh read of them first) rather than reading the parent
    // alone to discover its current payoutIds before deciding what else to read — sound because
    // payoutIds is written once at request time and never mutated afterward (requestWithdrawalCore's
    // own contract; no other write path in this codebase touches it), so the SAME ids the first pass
    // already has are still the right children to re-read, and reading parent+children together in
    // one getAll() call is exactly what makes this a genuine snapshot rather than two reads that
    // could straddle a real write landing in between them.
    let freshD: FirebaseFirestore.DocumentData | undefined;
    let freshSnaps: FirebaseFirestore.DocumentSnapshot[] | null = null;
    let childrenUnaffordable = false;
    if (payoutIds.length === 0) {
      const freshSnap = await db.collection("seller_withdrawals").doc(w.id).get();
      freshD = freshSnap.exists ? freshSnap.data() : undefined;
      freshSnaps = [];
    } else if (payoutIds.length <= budget.remaining) {
      budget.remaining -= payoutIds.length;
      const refs = [db.collection("seller_withdrawals").doc(w.id), ...payoutIds.map((id) => db.collection("seller_payouts").doc(id))];
      const snaps = await db.getAll(...refs);
      const [freshWSnap, ...freshChildSnaps] = snaps;
      freshD = freshWSnap.exists ? freshWSnap.data() : undefined;
      freshSnaps = freshChildSnaps;
    } else {
      const freshSnap = await db.collection("seller_withdrawals").doc(w.id).get();
      freshD = freshSnap.exists ? freshSnap.data() : undefined;
      childrenUnaffordable = true;
      incompleteReasons.push(
        `Child-read budget (${initialBudget}) reached while re-confirming seller withdrawal ${w.id} — its finding(s) are reported as unconfirmed, not independently re-verified this scan.`
      );
    }
    if (freshD === undefined) continue; // the withdrawal itself is gone — nothing left to report
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
  db: Db, pageLimit: number, incompleteReasons: string[], groupState: GroupCursorState
): Promise<{ findings: ReconciliationFinding[]; coverage: CoverageReport; nextCursor: GroupCursorState }> {
  const { docs, coverage, nextCursor, possibleBlindSpot } = await boundedByStatus(db, "rider_payouts", "paid", "paidAt", pageLimit, groupState);
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
  db: Db, pageLimit: number, incompleteReasons: string[], groupState: GroupCursorState
): Promise<{ findings: ReconciliationFinding[]; coverage: CoverageReport; nextCursor: GroupCursorState }> {
  const { docs, coverage, nextCursor, possibleBlindSpot } = await boundedByStatus(db, "employee_payouts", "paid", "paidAt", pageLimit, groupState);
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
 * fresh first page at the real RECENT_LIMIT; overridable the same way, for the same reason. This
 * function does NOT validate cursor shape (that is parseScanCursorInput's job, at the onCall
 * boundary, where a malformed cursor becomes a clear client-facing error) — it only resolves an
 * omitted group to "start", which is the documented, correct meaning of omission. */
export async function financeReconciliationScanCore(
  db: Db,
  nowMs: number,
  childReadBudget: number = CHILD_READ_BUDGET,
  cursor: ScanCursorInput = {},
  pageLimit: number = RECENT_LIMIT
): Promise<ReconciliationResult> {
  const incompleteReasons: string[] = [];
  const budget = { remaining: childReadBudget };
  const swPaid: GroupCursorState = cursor.sellerWithdrawals?.paid ?? { state: "start" };
  const swRequested: GroupCursorState = cursor.sellerWithdrawals?.requested ?? { state: "start" };
  const riderState: GroupCursorState = cursor.riderPayouts ?? { state: "start" };
  const employeeState: GroupCursorState = cursor.employeePayouts ?? { state: "start" };
  const [seller, rider, employee] = await Promise.all([
    checkSellerWithdrawals(db, budget, incompleteReasons, pageLimit, { paid: swPaid, requested: swRequested }),
    checkRiderPayouts(db, pageLimit, incompleteReasons, riderState),
    checkEmployeePayouts(db, pageLimit, incompleteReasons, employeeState),
  ]);
  const nextCursor: ScanCursor = {
    version: CURSOR_VERSION,
    sellerWithdrawals: { paid: seller.nextCursor.paid, requested: seller.nextCursor.requested },
    riderPayouts: rider.nextCursor,
    employeePayouts: employee.nextCursor,
  };
  const hasMore =
    nextCursor.sellerWithdrawals.paid.state !== "exhausted" ||
    nextCursor.sellerWithdrawals.requested.state !== "exhausted" ||
    nextCursor.riderPayouts.state !== "exhausted" ||
    nextCursor.employeePayouts.state !== "exhausted";
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
    const payoutIds: string[] = Array.isArray(w.data()!.payoutIds) ? w.data()!.payoutIds.map(String) : [];
    // payoutIds is set once at request time and never mutated afterward (see the scan's own
    // confirmation pass for the same reasoning), so re-reading the withdrawal TOGETHER with its
    // children in one getAll() call gives a genuine snapshot of both as of one consistent moment,
    // rather than evaluating against the parent and each child each read at a possibly different
    // instant — the evaluation below always uses this second, snapshot-consistent read, never the
    // first (which existed only to discover which children to read alongside it).
    let d = w.data()!;
    let payoutSnaps: FirebaseFirestore.DocumentSnapshot[] = [];
    if (payoutIds.length > 0) {
      const refs = [db.collection("seller_withdrawals").doc(recordId), ...payoutIds.map((id) => db.collection("seller_payouts").doc(id))];
      const [wSnap2, ...childSnaps] = await db.getAll(...refs);
      if (!wSnap2.exists) return { kind: "not_found" };
      d = wSnap2.data()!;
      payoutSnaps = childSnaps;
    }
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

/** Parses ONE group's cursor from raw callable input. `undefined` (the key genuinely absent) is
 * the only value that resolves to "start" implicitly — every other shape must be a fully-formed,
 * explicitly-tagged GroupCursorState, or this throws. This is the fix for the ADMR-85 bug: a
 * `null` value (which is what a JSON round-trip of this SAME module's own "exhausted" sentinel
 * used to produce) is no longer silently accepted as "absent" — it is now simply not a valid
 * GroupCursorState shape at all, and is rejected with a clear message instead of being
 * misinterpreted as "start". */
export function parseGroupCursorState(v: unknown, label: string): GroupCursorState {
  if (v === undefined) return { state: "start" };
  if (v && typeof v === "object") {
    const r = v as Record<string, unknown>;
    if (r.state === "start") return { state: "start" };
    if (r.state === "exhausted") return { state: "exhausted" };
    if (r.state === "continue" && r.cursor && typeof r.cursor === "object") {
      const c = r.cursor as Record<string, unknown>;
      if (typeof c.seconds === "number" && typeof c.nanoseconds === "number" && typeof c.id === "string" && c.id.trim()) {
        return { state: "continue", cursor: { seconds: c.seconds, nanoseconds: c.nanoseconds, id: c.id } };
      }
    }
  }
  throw new HttpsError(
    "invalid-argument",
    `Malformed scan cursor for ${label} — expected {state:"start"}, {state:"exhausted"} or {state:"continue", cursor:{seconds, nanoseconds, id}}.`
  );
}

function parseObjectField(v: unknown, label: string): Record<string, unknown> {
  if (v === undefined) return {};
  if (v !== null && typeof v === "object") return v as Record<string, unknown>;
  throw new HttpsError("invalid-argument", `Malformed scan cursor for ${label}.`);
}

/** Parses and validates a WHOLE cursor from raw callable input — the only place a malformed or
 * version-mismatched cursor is ever accepted or rejected; financeReconciliationScanCore itself
 * trusts its own `cursor` parameter completely, exactly like every other already-validated
 * core-function input in this codebase. Rejects (never silently restarts) a cursor whose own
 * `version` does not match CURSOR_VERSION — resuming against a query/ordering contract the cursor
 * was not produced under is unsafe, not merely inconvenient. */
export function parseScanCursorInput(v: unknown): ScanCursorInput {
  if (v === undefined || v === null) return {};
  if (typeof v !== "object") throw new HttpsError("invalid-argument", "Malformed scan cursor.");
  const r = v as Record<string, unknown>;
  if (r.version !== undefined && r.version !== CURSOR_VERSION) {
    throw new HttpsError(
      "invalid-argument",
      `This cursor was produced by a different scan version (${String(r.version)}) than this server runs (${CURSOR_VERSION}) — start a new scan instead of continuing this one.`
    );
  }
  const sw = parseObjectField(r.sellerWithdrawals, "sellerWithdrawals");
  return {
    sellerWithdrawals: {
      paid: parseGroupCursorState(sw.paid, "sellerWithdrawals.paid"),
      requested: parseGroupCursorState(sw.requested, "sellerWithdrawals.requested"),
    },
    riderPayouts: parseGroupCursorState(r.riderPayouts, "riderPayouts"),
    employeePayouts: parseGroupCursorState(r.employeePayouts, "employeePayouts"),
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
