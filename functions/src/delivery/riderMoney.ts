// ============================================================
//  Rider money (Phase DLV-4A): pay per order, COD cash held, weekly
//  statements, cash deposits, bank-detail changes.
// ============================================================
//
// Until now a rider's "earnings" were computed on the phone
// (apps/delivery order_provider.dart _deliveryEarningFor: the order's
// deliveryCharge or an invented ₹15) and nothing on the server knew what a
// rider was owed or how much COD cash they were holding. Owner decisions
// 2026-09-23:
//   D-DLV-PAY    base + per-km + waiting, computed here at delivery
//   D-DLV-COD    cash held is netted from the weekly payout; at the cash
//                limit a rider gets no COD offers (dispatch.ts)
//   D-DLV-PAYOUT weekly statements; admin pays by bank/UPI and records the
//                reference (firestore.rules, the seller_payouts pattern)
//   D-DLV-BANK   bank changes are requested by the rider and approved by
//                admin; a payout waits while a change is pending
//
// Collections (all server-written; firestore.rules: rider + admin read):
//   rider_earnings/{orderId}        one per delivered order — the id IS the
//                                   idempotency key (a retried trigger
//                                   creates nothing)
//   rider_accounts/{riderId}        cashHeld, earningsUnsettled, bankChangePending
//   rider_cash_ledger/{id}          every change to cashHeld
//   rider_payouts/{riderId_weekKey} weekly statements
//   rider_bank_change_requests/{id} pending → approved | rejected
//
// Modular FieldValue/Timestamp throughout (see confirmDelivery.ts: under the
// functions emulator admin.firestore has no static members).

import * as functions from "firebase-functions/v1";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { taskStatusFromOrder } from "./states";
import { dropPoint, orderPickupPoint, sellerPickupPoint } from "./syncDeliveryTask";
import { isCashOnDelivery, isPaid } from "../seller/sellerTransitionOrder";
import { bankReviewNotice, payoutSentNotice, statementNotice, tellRider } from "./riderNotices";
import { resolveIsAdmin } from "../admin/complianceGate";
import {
  billableWaitMinutes, hasPayoutDestination, riderPay, RiderPayRates, settle,
  statementCutoff, tripKm, validateBankDetails,
} from "./riderPay";
import { loadRiderPayRates } from "./riderRates";

type Db = FirebaseFirestore.Firestore;

export const riderAccountRef = (db: Db, riderId: string) => db.collection("rider_accounts").doc(riderId);

function millis(v: unknown): number | null {
  if (v instanceof Timestamp) return v.toMillis();
  if (v && typeof (v as { toMillis?: unknown }).toMillis === "function") return (v as { toMillis: () => number }).toMillis();
  return null;
}
const num = (v: unknown) => (typeof v === "number" && Number.isFinite(v) ? v : null);
const rupees = (x: number) => Math.round(x * 100) / 100;

// ── DLV-M1: exact money ──
// Balances used to move by FieldValue.increment of rupee floats and drifted
// (430.70000000000005 was seen in DLV-4B). Every balance change now happens
// inside a transaction that reads the account, adds in whole paise, and
// writes exact absolute values: the paise field is authoritative, the rupee
// field is derived from it (kept for existing readers). An account written
// before this has only rupee fields; it is converted on its next write.
export const toPaise = (rupeeAmount: number) => Math.round(rupeeAmount * 100);
export const fromPaise = (paise: number) => paise / 100;

/** The account's balances in paise: the paise fields, else the legacy rupee fields. */
export function accountPaise(a: FirebaseFirestore.DocumentData | undefined): { cashP: number; earnedP: number } {
  const cashP = Number.isInteger(a?.cashHeldPaise) ? (a!.cashHeldPaise as number) : toPaise(num(a?.cashHeld) ?? 0);
  const earnedP = Number.isInteger(a?.earningsUnsettledPaise)
    ? (a!.earningsUnsettledPaise as number) : toPaise(num(a?.earningsUnsettled) ?? 0);
  return { cashP, earnedP };
}

/** The exact balance fields to write (paise authoritative, rupees derived). */
export const balanceFields = (cashP: number, earnedP: number) => ({
  cashHeld: fromPaise(cashP), cashHeldPaise: cashP,
  earningsUnsettled: fromPaise(earnedP), earningsUnsettledPaise: earnedP,
});

/** An earning's pay in paise (totalPaise when recorded, else its rupee total). */
const earningPaise = (d: FirebaseFirestore.DocumentData) =>
  Number.isInteger(d.totalPaise) ? (d.totalPaise as number) : toPaise(num(d.total) ?? 0);

export type EarningVerdict =
  | { kind: "created"; total: number; cod: number }
  | { kind: "already" }
  | { kind: "skipped"; reason: "not_delivered" | "no_rider" };

/**
 * Records the pay (and, for a cash order, the cash now held) for one
 * delivered order. Reads the order inside the transaction — never the
 * trigger payload — so what is paid is what the order says now.
 */
export async function recordDeliveryEarningCore(db: Db, orderId: string, nowMs: number, rates?: RiderPayRates): Promise<EarningVerdict> {
  const r = rates ?? await loadRiderPayRates(db);
  const orderRef = db.collection("orders").doc(orderId);
  const earnRef = db.collection("rider_earnings").doc(orderId);
  const taskRef = db.collection("delivery_tasks").doc(orderId);
  return db.runTransaction(async (tx): Promise<EarningVerdict> => {
    const [earn, orderSnap, taskSnap] = await Promise.all([tx.get(earnRef), tx.get(orderRef), tx.get(taskRef)]);
    if (earn.exists) return { kind: "already" };
    const o = orderSnap.data();
    if (!o || taskStatusFromOrder(o) !== "delivered") return { kind: "skipped", reason: "not_delivered" };
    const riderId = typeof o.deliveryPartnerId === "string" && o.deliveryPartnerId ? o.deliveryPartnerId : null;
    if (!riderId) return { kind: "skipped", reason: "no_rider" };

    const task = taskSnap.exists ? taskSnap.data()! : {};
    // The store: the task's point, else the order's own, else the seller's
    // store location — the task may not exist yet when the delivered write
    // is the order's first update since syncDeliveryTask was deployed, or
    // is still being written in parallel (phaseDLV4A_trigger_test t01 paid
    // base only, 0 km, before this fallback).
    let pickup = task.pickup ?? orderPickupPoint(o);
    if (!pickup && typeof o.sellerId === "string" && o.sellerId) {
      const seller = await tx.get(db.collection("sellers").doc(o.sellerId));
      pickup = sellerPickupPoint(seller.exists ? seller.data() : undefined);
    }
    const trip = tripKm({ pickup, drop: task.drop ?? dropPoint(o), route: task.route });
    const stepAt = (task.stepAt ?? {}) as Record<string, unknown>;
    const wait = billableWaitMinutes(
      millis(o.arrivedAtStoreAt) ?? millis(stepAt.at_pickup),
      millis(o.pickedUpAt) ?? millis(stepAt.picked_up),
      r,
    );
    const pay = riderPay(r, trip.km, wait);
    const cod = isCashOnDelivery(o.paymentMethod) && !isPaid(o.paymentStatus) ? rupees(num(o.total) ?? 0) : 0;
    const at = Timestamp.fromMillis(nowMs);
    const accRef = riderAccountRef(db, riderId);
    const acc = await tx.get(accRef);
    const { cashP, earnedP } = accountPaise(acc.data());
    const payP = toPaise(pay.total);
    const codP = toPaise(cod);

    tx.create(earnRef, {
      orderId,
      riderId,
      orderNumber: o.orderNumber ?? null,
      lines: pay.lines,
      total: pay.total,
      totalPaise: payP,
      km: Math.round(trip.km * 100) / 100,
      kmSource: trip.source,
      waitMinutes: wait,
      rates: r,
      codCollected: cod,
      codCollectedPaise: codP,
      statementId: null,
      createdAt: at,
    });
    tx.set(accRef, { riderId, ...balanceFields(cashP + codP, earnedP + payP), updatedAt: at }, { merge: true });
    if (cod > 0) {
      tx.set(db.collection("rider_cash_ledger").doc(), {
        riderId, type: "cash_collected", amount: cod, amountPaise: codP, orderId, at,
      });
      tx.update(orderRef, { codSettlementStatus: "collected", codCollectedBy: riderId, codCollectedAt: at });
    }
    return { kind: "created", total: pay.total, cod };
  });
}

/** Orders whose leg just became delivered — however it happened (confirmDelivery, the released app's direct write, admin). */
export const onRiderDelivery = functions.firestore
  .document("orders/{orderId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    if (taskStatusFromOrder(before) === "delivered" || taskStatusFromOrder(after) !== "delivered") return null;
    const v = await recordDeliveryEarningCore(admin.firestore(), context.params.orderId, Date.now());
    if (v.kind === "created") console.log(`[onRiderDelivery] ${context.params.orderId}: ₹${v.total} pay, ₹${v.cod} cash`);
    else if (v.kind === "skipped") console.warn(`[onRiderDelivery] ${context.params.orderId}: skipped (${v.reason})`);
    return null;
  });

// ── cash deposits (admin) ──

export type DepositVerdict =
  | { kind: "recorded"; cashHeld: number; already?: boolean }
  | { kind: "refused"; reason: "more_than_held" | "bad_amount" | "bad_reference" | "bad_request_id" | "request_reused" };

const DEPOSIT_REQUEST_ID = /^[A-Za-z0-9_-]{8,64}$/;

/**
 * An admin records cash a rider handed over. DLV-M1: exact paise; an amount
 * that rounds to zero paise is refused; with a request id (the admin app
 * sends one per deposit dialog) a retried call returns the first result
 * instead of recording the deposit twice, and the same id with a different
 * rider, amount or reference is refused.
 */
export async function recordCashDepositCore(
  db: Db, adminUid: string, riderId: string, amount: number, reference: string, nowMs: number,
  requestId: string | null = null
): Promise<DepositVerdict> {
  if (!Number.isFinite(amount) || amount <= 0 || amount > 1000000) return { kind: "refused", reason: "bad_amount" };
  const amtP = toPaise(amount);
  if (amtP <= 0) return { kind: "refused", reason: "bad_amount" };
  if (reference.length < 2 || reference.length > 64) return { kind: "refused", reason: "bad_reference" };
  if (requestId !== null && !DEPOSIT_REQUEST_ID.test(requestId)) return { kind: "refused", reason: "bad_request_id" };
  const accRef = riderAccountRef(db, riderId);
  const ledgerRef = requestId
    ? db.collection("rider_cash_ledger").doc(`deposit_${requestId}`)
    : db.collection("rider_cash_ledger").doc();
  return db.runTransaction(async (tx): Promise<DepositVerdict> => {
    const [acc, prior] = await Promise.all([tx.get(accRef), requestId ? tx.get(ledgerRef) : Promise.resolve(null)]);
    const { cashP, earnedP } = accountPaise(acc.data());
    if (prior?.exists) {
      const p = prior.data()!;
      const same = p.riderId === riderId && p.amountPaise === amtP && p.reference === reference;
      return same ? { kind: "recorded", cashHeld: fromPaise(cashP), already: true } : { kind: "refused", reason: "request_reused" };
    }
    if (amtP > cashP) return { kind: "refused", reason: "more_than_held" };
    const at = Timestamp.fromMillis(nowMs);
    tx.set(accRef, { riderId, ...balanceFields(cashP - amtP, earnedP), lastDepositAt: at, updatedAt: at }, { merge: true });
    tx.set(ledgerRef, {
      riderId, type: "deposit", amount: fromPaise(amtP), amountPaise: amtP, reference,
      recordedBy: adminUid, requestId: requestId ?? null, at,
    });
    return { kind: "recorded", cashHeld: fromPaise(cashP - amtP) };
  });
}

// ── weekly statements ──

export type StatementVerdict =
  | { kind: "created"; id: string; status: string; amount: number; netted: number; more: boolean }
  | { kind: "exists" }
  | { kind: "nothing" };

/** Max earnings lines settled by one statement part (transaction write budget). */
export const MAX_LINES_PER_STATEMENT = 400;
/** A safety bound on parts per rider per week (400 × 50 = 20,000 deliveries). */
export const MAX_STATEMENT_PARTS = 50;

/** The statement id for a rider, week and part (part 1 keeps the old id). */
export const statementId = (riderId: string, weekKey: string, part: number) =>
  part === 1 ? `${riderId}_${weekKey}` : `${riderId}_${weekKey}_p${part}`;

/**
 * Builds one part of a rider's weekly statement: up to 400 of the oldest
 * unsettled earnings before the cutoff, netted against cash held, in exact
 * paise. DLV-M1: when more lines remain, `more` is true and the caller builds
 * the next part now — they used to wait a whole week (and fall further behind
 * every week for a rider with over 400 deliveries).
 */
export async function buildStatementCore(db: Db, riderId: string, nowMs: number, part = 1): Promise<StatementVerdict> {
  const { cutoffMs, weekKey } = statementCutoff(nowMs);
  const id = statementId(riderId, weekKey, part);
  const payoutRef = db.collection("rider_payouts").doc(id);
  const accRef = riderAccountRef(db, riderId);
  const partnerRef = db.collection("delivery_partners").doc(riderId);
  const unsettled = db.collection("rider_earnings").where("riderId", "==", riderId).where("statementId", "==", null);
  return db.runTransaction(async (tx): Promise<StatementVerdict> => {
    const [existing, acc, partner, lines] = await Promise.all([tx.get(payoutRef), tx.get(accRef), tx.get(partnerRef), tx.get(unsettled)]);
    if (existing.exists) return { kind: "exists" };
    const eligible = lines.docs
      .filter((d) => (millis(d.data().createdAt) ?? Infinity) < cutoffMs)
      .sort((x, y) => (millis(x.data().createdAt) ?? 0) - (millis(y.data().createdAt) ?? 0));
    const covered = eligible.slice(0, MAX_LINES_PER_STATEMENT);
    const more = eligible.length > covered.length;
    const earnedP = covered.reduce((sum, d) => sum + earningPaise(d.data()), 0);
    const a = acc.data() ?? {};
    const { cashP, earnedP: unsettledP } = accountPaise(a);
    if (earnedP <= 0 && (part > 1 || cashP <= 0)) return { kind: "nothing" };
    const nettedP = Math.min(Math.max(earnedP, 0), Math.max(cashP, 0));
    const payoutP = earnedP - nettedP;
    const cashAfterP = cashP - nettedP;
    let status = "nothing_to_pay";
    let holdReason: string | null = null;
    if (payoutP > 0) {
      if (typeof a.bankChangePending === "string" && a.bankChangePending) { status = "on_hold"; holdReason = "bank_change_pending"; }
      else if (!hasPayoutDestination(partner.data())) { status = "on_hold"; holdReason = "no_bank_details"; }
      else status = "pending";
    }
    const at = Timestamp.fromMillis(nowMs);
    tx.create(payoutRef, {
      riderId, weekKey, part, periodEnd: Timestamp.fromMillis(cutoffMs),
      earned: fromPaise(earnedP), earnedPaise: earnedP,
      cashHeldBefore: fromPaise(cashP), cashHeldBeforePaise: cashP,
      netted: fromPaise(nettedP), nettedPaise: nettedP,
      amount: fromPaise(payoutP), amountPaise: payoutP,
      cashHeldAfter: fromPaise(cashAfterP), cashHeldAfterPaise: cashAfterP,
      orderCount: covered.length, status, holdReason, createdAt: at, updatedAt: at,
    });
    for (const d of covered) tx.update(d.ref, { statementId: id, settledAt: at });
    tx.set(accRef, { riderId, ...balanceFields(cashAfterP, unsettledP - earnedP), lastStatementId: id, updatedAt: at }, { merge: true });
    if (nettedP > 0) {
      tx.set(db.collection("rider_cash_ledger").doc(), {
        riderId, type: "netted_against_payout", amount: fromPaise(nettedP), amountPaise: nettedP, statementId: id, at,
      });
    }
    return { kind: "created", id, status, amount: fromPaise(payoutP), netted: fromPaise(nettedP), more };
  });
}

/** Every part a rider needs this week (retry-safe: an existing part is skipped). */
export async function buildRiderStatementParts(db: Db, riderId: string, nowMs: number): Promise<StatementVerdict[]> {
  const out: StatementVerdict[] = [];
  for (let part = 1; part <= MAX_STATEMENT_PARTS; part++) {
    const v = await buildStatementCore(db, riderId, nowMs, part);
    out.push(v);
    if (v.kind === "nothing" || (v.kind === "created" && !v.more)) break;
  }
  return out;
}

export async function buildAllStatements(db: Db, nowMs: number) {
  const accounts = await db.collection("rider_accounts").get();
  const out = { created: 0, exists: 0, nothing: 0, failed: 0 };
  for (const a of accounts.docs) {
    try {
      for (const v of await buildRiderStatementParts(db, a.id, nowMs)) {
        out[v.kind === "created" ? "created" : v.kind] += 1;
        if (v.kind === "created") {
          // DLV-N1: the inbox says a statement was made — not that money was sent.
          const p = (await db.collection("rider_payouts").doc(v.id).get()).data() ?? {};
          await tellRider(db, a.id, statementNotice({ id: v.id, amountPaise: Number(p.amountPaise ?? 0),
            status: String(p.status ?? ""), holdReason: p.holdReason ?? null }), nowMs);
        }
      }
    } catch (e) {
      out.failed += 1;
      console.error(`[buildRiderStatements] ${a.id}: ${(e as Error)?.message ?? e}`);
    }
  }
  return out;
}

export const buildRiderStatements = onSchedule(
  { schedule: "30 0 * * 1", timeZone: "Asia/Kolkata", memory: "256MiB" },
  async () => {
    const r = await buildAllStatements(admin.firestore(), Date.now());
    console.log(`[buildRiderStatements] ${JSON.stringify(r)}`);
  }
);

// ── bank details (D-DLV-BANK) ──

export type BankRequestVerdict = { kind: "requested"; id: string } | { kind: "refused"; reason: "not_a_rider" | "already_pending" | string };

export async function requestBankChangeCore(db: Db, riderId: string, data: unknown, nowMs: number): Promise<BankRequestVerdict> {
  const v = validateBankDetails(data);
  if (!v.ok) return { kind: "refused", reason: `invalid_${v.error}` };
  const partnerRef = db.collection("delivery_partners").doc(riderId);
  const accRef = riderAccountRef(db, riderId);
  const reqRef = db.collection("rider_bank_change_requests").doc();
  // DLV-M1: statements already waiting to be paid are held too — before, a
  // change requested after a statement became pending did not stop an
  // admin paying the old destination.
  const pendingPayouts = db.collection("rider_payouts").where("riderId", "==", riderId).where("status", "==", "pending");
  return db.runTransaction(async (tx): Promise<BankRequestVerdict> => {
    const [partner, acc, pending] = await Promise.all([tx.get(partnerRef), tx.get(accRef), tx.get(pendingPayouts)]);
    if (!partner.exists) return { kind: "refused", reason: "not_a_rider" };
    if (typeof acc.data()?.bankChangePending === "string" && acc.data()!.bankChangePending) return { kind: "refused", reason: "already_pending" };
    const at = Timestamp.fromMillis(nowMs);
    tx.create(reqRef, { riderId, ...v.value, status: "pending", createdAt: at, updatedAt: at });
    tx.set(accRef, { riderId, bankChangePending: reqRef.id, updatedAt: at }, { merge: true });
    for (const p of pending.docs) {
      tx.update(p.ref, { status: "on_hold", holdReason: "bank_change_pending", heldAt: at, updatedAt: at });
    }
    return { kind: "requested", id: reqRef.id };
  });
}

export type BankReviewVerdict = { kind: "approved" | "rejected"; released: number } | { kind: "refused"; reason: "not_found" | "not_pending" | "reason_required" };

export async function reviewBankChangeCore(
  db: Db, adminUid: string, requestId: string, approve: boolean, reason: string | null, nowMs: number
): Promise<BankReviewVerdict> {
  if (!approve && (!reason || reason.length < 3 || reason.length > 200)) return { kind: "refused", reason: "reason_required" };
  const reqRef = db.collection("rider_bank_change_requests").doc(requestId);
  return db.runTransaction(async (tx): Promise<BankReviewVerdict> => {
    const req = await tx.get(reqRef);
    if (!req.exists) return { kind: "refused", reason: "not_found" };
    const r = req.data()!;
    if (r.status !== "pending") return { kind: "refused", reason: "not_pending" };
    const riderId = r.riderId as string;
    const partnerRef = db.collection("delivery_partners").doc(riderId);
    const held = db.collection("rider_payouts").where("riderId", "==", riderId).where("status", "==", "on_hold");
    const [partner, holds] = await Promise.all([tx.get(partnerRef), tx.get(held)]);
    const at = Timestamp.fromMillis(nowMs);
    const details = {
      accountHolderName: r.accountHolderName ?? null,
      bankAccountNumber: r.bankAccountNumber ?? null,
      ifscCode: r.ifscCode ?? null,
      upiId: r.upiId ?? null,
    };
    // Where the payout goes after this review.
    const destination = approve ? { ...partner.data(), ...details } : partner.data();
    tx.update(reqRef, {
      status: approve ? "approved" : "rejected",
      reviewedBy: adminUid, reviewedAt: at, rejectionReason: approve ? null : reason, updatedAt: at,
    });
    if (approve) tx.update(partnerRef, { ...details, bankDetailsUpdatedAt: at });
    tx.set(riderAccountRef(db, riderId), { riderId, bankChangePending: null, updatedAt: at }, { merge: true });
    let released = 0;
    if (hasPayoutDestination(destination)) {
      for (const h of holds.docs) {
        if (["bank_change_pending", "no_bank_details"].includes(h.data().holdReason)) {
          tx.update(h.ref, { status: "pending", holdReason: null, releasedAt: at, updatedAt: at });
          released += 1;
        }
      }
    }
    return { kind: approve ? "approved" : "rejected", released };
  });
}

// ── paying a statement (admin) ──

export type PaidVerdict =
  | { kind: "paid" | "already"; paidTo: Record<string, unknown> }
  | { kind: "refused"; reason: "not_found" | "payout_not_pending" | "bank_change_pending" | "no_destination" | "bad_reference" | "bad_method" };

/**
 * DLV-M1: an admin marks a pending statement paid, in a transaction that
 * refuses while the rider has a bank change pending and records the
 * destination actually used (masked account + IFSC, or the UPI id) on the
 * statement. The rules-level paid transition is kept for older admin
 * clients but now refuses while a change is pending too.
 */
export async function markPayoutPaidCore(
  db: Db, adminUid: string, payoutId: string, reference: string, method: unknown, nowMs: number
): Promise<PaidVerdict> {
  const ref = reference.trim();
  if (ref.length < 4 || ref.length > 64) return { kind: "refused", reason: "bad_reference" };
  if (method !== "bank" && method !== "upi") return { kind: "refused", reason: "bad_method" };
  const payoutRef = db.collection("rider_payouts").doc(payoutId);
  return db.runTransaction(async (tx): Promise<PaidVerdict> => {
    const payout = await tx.get(payoutRef);
    if (!payout.exists) return { kind: "refused", reason: "not_found" };
    const p = payout.data()!;
    if (p.status === "paid" && p.paymentReference === ref) return { kind: "already", paidTo: p.paidTo ?? {} };
    if (p.status !== "pending") return { kind: "refused", reason: "payout_not_pending" };
    const riderId = String(p.riderId);
    const [acc, partner] = await Promise.all([tx.get(riderAccountRef(db, riderId)), tx.get(db.collection("delivery_partners").doc(riderId))]);
    if (typeof acc.data()?.bankChangePending === "string" && acc.data()!.bankChangePending) {
      return { kind: "refused", reason: "bank_change_pending" };
    }
    const d = partner.data() ?? {};
    const acct = typeof d.bankAccountNumber === "string" ? d.bankAccountNumber.replace(/\s/g, "") : "";
    const upi = typeof d.upiId === "string" ? d.upiId.trim() : "";
    let paidTo: Record<string, unknown>;
    if (method === "bank") {
      if (!acct || typeof d.ifscCode !== "string" || !d.ifscCode) return { kind: "refused", reason: "no_destination" };
      paidTo = { method: "bank", accountLast4: acct.slice(-4), ifscCode: d.ifscCode, accountHolderName: d.accountHolderName ?? null };
    } else {
      if (!upi) return { kind: "refused", reason: "no_destination" };
      paidTo = { method: "upi", upiId: upi };
    }
    const at = Timestamp.fromMillis(nowMs);
    tx.update(payoutRef, {
      status: "paid", paidAt: at, paidBy: adminUid, paymentReference: ref, payoutMethod: method, paidTo, updatedAt: at,
    });
    return { kind: "paid", paidTo };
  });
}

// ── callables ──

async function requireAdmin(request: { auth?: { uid: string; token: Record<string, unknown> } }): Promise<string> {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required");
  const ok = await resolveIsAdmin(admin.firestore(), request.auth.uid, request.auth.token.admin === true);
  if (!ok) throw new HttpsError("permission-denied", "Admins only");
  return request.auth.uid;
}

const REFUSAL_TEXT: Record<string, string> = {
  more_than_held: "That is more cash than the rider holds",
  bad_amount: "Enter an amount greater than zero",
  bad_reference: "Enter a receipt or reference (2–64 characters)",
  bad_request_id: "The request could not be read",
  request_reused: "This deposit was already recorded with different details",
  payout_not_pending: "This statement is not waiting to be paid",
  bank_change_pending: "The rider has a payout-detail change waiting for review",
  no_destination: "The rider has no payout details for that method",
  bad_method: "Choose bank or UPI",
  not_a_rider: "Only delivery partners can change payout details",
  already_pending: "A change is already waiting for review",
  not_found: "Request not found",
  not_pending: "This request has already been reviewed",
  reason_required: "Give a reason for rejecting (3–200 characters)",
};
function refuse(reason: string): never {
  const message = REFUSAL_TEXT[reason] ?? (reason.startsWith("invalid_") ? `Check the ${reason.slice(8)} field` : "Not possible");
  throw new HttpsError(reason === "not_found" ? "not-found" : "failed-precondition", message, { reason });
}

export const recordRiderCashDeposit = onCall({ minInstances: 0, memory: "256MiB" }, async (request) => {
  const adminUid = await requireAdmin(request as never);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const riderId = typeof d.riderId === "string" ? d.riderId.trim() : "";
  if (!riderId) throw new HttpsError("invalid-argument", "riderId is required");
  const v = await recordCashDepositCore(admin.firestore(), adminUid, riderId, Number(d.amount),
    typeof d.reference === "string" ? d.reference.trim() : "", Date.now(),
    typeof d.requestId === "string" ? d.requestId : null);
  if (v.kind === "refused") refuse(v.reason);
  return { success: true, cashHeld: v.cashHeld, alreadyRecorded: v.already === true };
});

export const markRiderPayoutPaid = onCall({ minInstances: 0, memory: "256MiB" }, async (request) => {
  const adminUid = await requireAdmin(request as never);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const payoutId = typeof d.payoutId === "string" ? d.payoutId.trim() : "";
  if (!payoutId) throw new HttpsError("invalid-argument", "payoutId is required");
  const v = await markPayoutPaidCore(admin.firestore(), adminUid, payoutId,
    typeof d.reference === "string" ? d.reference : "", d.method, Date.now());
  if (v.kind === "refused") refuse(v.reason);
  if (v.kind === "paid") {
    const db = admin.firestore();
    const p = (await db.collection("rider_payouts").doc(payoutId).get()).data() ?? {};
    const to = (p.paidTo ?? {}) as Record<string, unknown>;
    await tellRider(db, typeof p.riderId === "string" ? p.riderId : null, payoutSentNotice({
      id: payoutId, amountPaise: Number(p.amountPaise ?? 0), reference: String(p.paymentReference ?? ""),
      method: String(to.method ?? ""), accountLast4: (to.accountLast4 as string) ?? null, upiId: (to.upiId as string) ?? null,
    }), Date.now());
  }
  return { success: true, paidTo: v.paidTo, alreadyPaid: v.kind === "already" };
});

/** DLV-M1: what the rider may know about their own cash position (not the whole settings doc). */
export const riderMoneySummary = onCall({ minInstances: 0, memory: "256MiB" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required");
  const db = admin.firestore();
  const partner = await db.collection("delivery_partners").doc(request.auth.uid).get();
  if (!partner.exists) throw new HttpsError("permission-denied", "Only delivery partners", { reason: "not_a_rider" });
  const rates = await loadRiderPayRates(db);
  return { codCashLimit: rates.codCashLimit };
});

export const requestRiderBankChange = onCall({ minInstances: 0, memory: "256MiB" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required");
  const v = await requestBankChangeCore(admin.firestore(), request.auth.uid, request.data, Date.now());
  if (v.kind === "refused") refuse(v.reason);
  return { success: true, requestId: v.id };
});

export const reviewRiderBankChange = onCall({ minInstances: 0, memory: "256MiB" }, async (request) => {
  const adminUid = await requireAdmin(request as never);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const requestId = typeof d.requestId === "string" ? d.requestId.trim() : "";
  if (!requestId) throw new HttpsError("invalid-argument", "requestId is required");
  const v = await reviewBankChangeCore(admin.firestore(), adminUid, requestId, d.approve === true,
    typeof d.reason === "string" ? d.reason.trim() : null, Date.now());
  if (v.kind === "refused") refuse(v.reason);
  const db = admin.firestore();
  const r = (await db.collection("rider_bank_change_requests").doc(requestId).get()).data() ?? {};
  await tellRider(db, typeof r.riderId === "string" ? r.riderId : null,
    bankReviewNotice(requestId, v.kind === "approved", typeof r.rejectionReason === "string" ? r.rejectionReason : null), Date.now());
  return { success: true, status: v.kind, released: v.released };
});
