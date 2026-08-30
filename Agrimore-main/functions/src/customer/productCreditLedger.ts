// ============================================================
//  Product Credit ledger — the immutable source of truth
//  (Phase B: benefit ledger & accrual engine)
// ============================================================
//
// /product_credit_ledger/{entryId} is append-only and Cloud-Function
// write-only (create/update/delete: if false for every client — see
// firestore.rules). /product_credit_balances/{customerId} is a PROJECTION,
// not the truth: it exists only so a client doesn't have to sum the ledger
// on every read.
//
// appendLedgerEntry() is the ONLY place either collection is ever written.
// Every future writer — this phase's accrual/expiry/reconciliation code,
// and Phase C's redemption — must go through it, so the ledger and its
// projection can never diverge (reconcileProductCreditBalances.ts still
// checks for drift, but appendLedgerEntry is what prevents it from
// happening in the first place).
//
// Deliberately NOT itself async: it performs zero reads, only tx.set()
// calls, so it can be called freely from anywhere inside an already-open
// transaction's write phase without disturbing that transaction's own
// reads-before-writes ordering. The caller is responsible for reading
// `product_credit_balances/{customerId}` (via toProjectionFields) BEFORE
// any write in its own transaction and passing the result in as
// `currentProjection` — this function never reads Firestore itself.

import { HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

export const LEDGER_ENTRY_TYPES = [
  "CREDIT",
  "REDEMPTION",
  "REVERSAL",
  "EXPIRY",
  "ADJUSTMENT",
  "HOLD",
  "RELEASE",
] as const;
export type LedgerEntryType = (typeof LEDGER_ENTRY_TYPES)[number];

export interface ProjectionFields {
  available: number;
  pending: number;
  onHold: number;
  lifetimeEarned: number;
  lifetimeUsed: number;
  lifetimeExpired: number;
}

function zeroProjection(): ProjectionFields {
  return { available: 0, pending: 0, onHold: 0, lifetimeEarned: 0, lifetimeUsed: 0, lifetimeExpired: 0 };
}

// Fail-closed, mirroring ProductCreditBalanceModel.fromMap's exact
// defaults (packages/agrimore_core/lib/models/product_credit_balance_model.dart):
// a missing document or a non-numeric field both resolve to 0, never to a
// throw or an inferred nonzero value.
export function toProjectionFields(data: FirebaseFirestore.DocumentData | undefined): ProjectionFields {
  const zero = zeroProjection();
  if (!data) return zero;
  return {
    available: typeof data.available === "number" ? data.available : zero.available,
    pending: typeof data.pending === "number" ? data.pending : zero.pending,
    onHold: typeof data.onHold === "number" ? data.onHold : zero.onHold,
    lifetimeEarned: typeof data.lifetimeEarned === "number" ? data.lifetimeEarned : zero.lifetimeEarned,
    lifetimeUsed: typeof data.lifetimeUsed === "number" ? data.lifetimeUsed : zero.lifetimeUsed,
    lifetimeExpired: typeof data.lifetimeExpired === "number" ? data.lifetimeExpired : zero.lifetimeExpired,
  };
}

// Balance arithmetic (D3/Workstream 4), applied verbatim as specified:
//   available   += CREDIT, RELEASE, REVERSAL(of a REDEMPTION)
//   available   -= REDEMPTION, EXPIRY, HOLD
//   onHold      += HOLD ; onHold -= RELEASE, REDEMPTION
//   ADJUSTMENT  moves `available` by metadata.direction ('credit'|'debit')
//               — never inferred from sign.
//
// ⚠️ Flagged honestly, not silently resolved: read literally, a REDEMPTION
// decrements BOTH `available` and `onHold` by the same amount. If Phase C's
// checkout flow always precedes a REDEMPTION with a HOLD for that exact
// amount (HOLD: available -= X, onHold += X), then a subsequent REDEMPTION
// for the same X would decrement `available` a SECOND time — a double
// decrement relative to what was actually reserved. This file implements
// the rule exactly as specified in this phase's instructions ("stated
// explicitly so Phase C inherits it unambiguously"); it does not attempt
// to silently reinterpret it. Phase C's author must resolve this with the
// owner before wiring a real HOLD → REDEMPTION sequence — either by never
// following a HOLD with a REDEMPTION for the same amount (treat them as
// alternative, not sequential, flows), or by having the "finalize a hold
// into a spend" step emit something that only clears `onHold` without a
// second `available` decrement. No redemption code exists in this phase
// (Q1), so this ambiguity has no live effect yet.
function applyEntryToProjection(
  current: ProjectionFields,
  type: LedgerEntryType,
  amount: number,
  metadata: Record<string, unknown> | null | undefined
): ProjectionFields {
  const next: ProjectionFields = { ...current };

  switch (type) {
    case "CREDIT":
      next.available += amount;
      next.lifetimeEarned += amount;
      break;
    case "RELEASE":
      next.available += amount;
      next.onHold -= amount;
      break;
    case "REVERSAL":
      // The only reversal shape this phase's arithmetic table defines:
      // reversing a REDEMPTION credits `available` back.
      next.available += amount;
      break;
    case "REDEMPTION":
      next.available -= amount;
      next.onHold -= amount;
      next.lifetimeUsed += amount;
      break;
    case "EXPIRY":
      next.available -= amount;
      next.lifetimeExpired += amount;
      break;
    case "HOLD":
      next.available -= amount;
      next.onHold += amount;
      break;
    case "ADJUSTMENT": {
      const direction = metadata?.direction;
      if (direction !== "credit" && direction !== "debit") {
        throw new HttpsError(
          "invalid-argument",
          "ADJUSTMENT entries require metadata.direction of 'credit' or 'debit' — direction is never inferred from amount sign"
        );
      }
      next.available += direction === "credit" ? amount : -amount;
      break;
    }
  }

  if (next.available < 0) {
    throw new HttpsError(
      "failed-precondition",
      `Ledger entry (type=${type}, amount=${amount}) would make available balance negative ` +
        `(${current.available} -> ${next.available}) — rejected, nothing written`
    );
  }
  if (next.onHold < 0) {
    throw new HttpsError(
      "failed-precondition",
      `Ledger entry (type=${type}, amount=${amount}) would make onHold balance negative ` +
        `(${current.onHold} -> ${next.onHold}) — rejected, nothing written`
    );
  }

  return next;
}

export interface AppendLedgerEntryParams {
  customerId: string;
  /** Empty string permitted for entries not tied to one specific
   *  enrollment (e.g. a reconciliation ADJUSTMENT). */
  enrollmentId: string;
  type: LedgerEntryType;
  /** Always >= 0 — direction is carried entirely by `type`/metadata. */
  amount: number;
  /** Read by the caller (via toProjectionFields) BEFORE any write in its
   *  own transaction — this function performs no reads. */
  currentProjection: ProjectionFields;
  /** Pre-generated ref (e.g. so a caller can embed its id in a sibling
   *  document written in the same transaction) — a fresh one is created
   *  if omitted. */
  entryRef?: FirebaseFirestore.DocumentReference;
  period?: string | null;
  referenceId?: string | null;
  relatedEntryId?: string | null;
  orderId?: string | null;
  expiresAt?: FirebaseFirestore.Timestamp | null;
  description: string;
  metadata?: Record<string, unknown> | null;
  /** Overwrites the projection's nextCreditDate when provided; omitted
   *  entirely (not set to null) otherwise, so it is never clobbered. */
  nextCreditDate?: FirebaseFirestore.Timestamp | null;
}

export function appendLedgerEntry(
  tx: FirebaseFirestore.Transaction,
  db: FirebaseFirestore.Firestore,
  params: AppendLedgerEntryParams
): { entryRef: FirebaseFirestore.DocumentReference; newProjection: ProjectionFields } {
  if (typeof params.amount !== "number" || !Number.isFinite(params.amount) || params.amount < 0) {
    throw new HttpsError(
      "invalid-argument",
      `amount must be a non-negative finite number, got ${params.amount}`
    );
  }

  const newProjection = applyEntryToProjection(
    params.currentProjection,
    params.type,
    params.amount,
    params.metadata
  );

  const entryRef = params.entryRef ?? db.collection("product_credit_ledger").doc();
  tx.set(entryRef, {
    id: entryRef.id,
    customerId: params.customerId,
    enrollmentId: params.enrollmentId,
    type: params.type,
    amount: params.amount,
    period: params.period ?? null,
    status: "posted",
    referenceId: params.referenceId ?? null,
    relatedEntryId: params.relatedEntryId ?? null,
    orderId: params.orderId ?? null,
    expiresAt: params.expiresAt ?? null,
    description: params.description,
    metadata: params.metadata ?? null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  const projectionRef = db.collection("product_credit_balances").doc(params.customerId);
  const projectionUpdate: Record<string, unknown> = {
    ...newProjection,
    lastLedgerEntryId: entryRef.id,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  if (params.nextCreditDate !== undefined) {
    projectionUpdate.nextCreditDate = params.nextCreditDate;
  }
  tx.set(projectionRef, projectionUpdate, { merge: true });

  return { entryRef, newProjection };
}
