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
import { dropPoint, orderPickupPoint } from "./syncDeliveryTask";
import { isCashOnDelivery, isPaid } from "../seller/sellerTransitionOrder";
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
    const trip = tripKm({
      pickup: task.pickup ?? orderPickupPoint(o),
      drop: task.drop ?? dropPoint(o),
      route: task.route,
    });
    const stepAt = (task.stepAt ?? {}) as Record<string, unknown>;
    const wait = billableWaitMinutes(
      millis(o.arrivedAtStoreAt) ?? millis(stepAt.at_pickup),
      millis(o.pickedUpAt) ?? millis(stepAt.picked_up),
      r,
    );
    const pay = riderPay(r, trip.km, wait);
    const cod = isCashOnDelivery(o.paymentMethod) && !isPaid(o.paymentStatus) ? rupees(num(o.total) ?? 0) : 0;
    const at = Timestamp.fromMillis(nowMs);

    tx.create(earnRef, {
      orderId,
      riderId,
      orderNumber: o.orderNumber ?? null,
      lines: pay.lines,
      total: pay.total,
      km: Math.round(trip.km * 100) / 100,
      kmSource: trip.source,
      waitMinutes: wait,
      rates: r,
      codCollected: cod,
      statementId: null,
      createdAt: at,
    });
    tx.set(riderAccountRef(db, riderId), {
      riderId,
      earningsUnsettled: FieldValue.increment(pay.total),
      ...(cod > 0 ? { cashHeld: FieldValue.increment(cod) } : {}),
      updatedAt: at,
    }, { merge: true });
    if (cod > 0) {
      tx.set(db.collection("rider_cash_ledger").doc(), {
        riderId, type: "cash_collected", amount: cod, orderId, at,
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

export type DepositVerdict = { kind: "recorded"; cashHeld: number } | { kind: "refused"; reason: "more_than_held" | "bad_amount" | "bad_reference" };

export async function recordCashDepositCore(
  db: Db, adminUid: string, riderId: string, amount: number, reference: string, nowMs: number
): Promise<DepositVerdict> {
  if (!Number.isFinite(amount) || amount <= 0 || amount > 1000000) return { kind: "refused", reason: "bad_amount" };
  if (reference.length < 2 || reference.length > 64) return { kind: "refused", reason: "bad_reference" };
  const accRef = riderAccountRef(db, riderId);
  return db.runTransaction(async (tx): Promise<DepositVerdict> => {
    const acc = await tx.get(accRef);
    const held = num(acc.data()?.cashHeld) ?? 0;
    const amt = rupees(amount);
    if (amt > held + 0.005) return { kind: "refused", reason: "more_than_held" };
    const at = Timestamp.fromMillis(nowMs);
    tx.set(accRef, { riderId, cashHeld: FieldValue.increment(-amt), lastDepositAt: at, updatedAt: at }, { merge: true });
    tx.set(db.collection("rider_cash_ledger").doc(), { riderId, type: "deposit", amount: amt, reference, recordedBy: adminUid, at });
    return { kind: "recorded", cashHeld: rupees(held - amt) };
  });
}

// ── weekly statements ──

export type StatementVerdict =
  | { kind: "created"; id: string; status: string; amount: number; netted: number }
  | { kind: "exists" }
  | { kind: "nothing" };

/** Max earnings lines settled by one statement (transaction write budget). */
export const MAX_LINES_PER_STATEMENT = 400;

export async function buildStatementCore(db: Db, riderId: string, nowMs: number): Promise<StatementVerdict> {
  const { cutoffMs, weekKey } = statementCutoff(nowMs);
  const id = `${riderId}_${weekKey}`;
  const payoutRef = db.collection("rider_payouts").doc(id);
  const accRef = riderAccountRef(db, riderId);
  const partnerRef = db.collection("delivery_partners").doc(riderId);
  const unsettled = db.collection("rider_earnings").where("riderId", "==", riderId).where("statementId", "==", null);
  return db.runTransaction(async (tx): Promise<StatementVerdict> => {
    const [existing, acc, partner, lines] = await Promise.all([tx.get(payoutRef), tx.get(accRef), tx.get(partnerRef), tx.get(unsettled)]);
    if (existing.exists) return { kind: "exists" };
    const covered = lines.docs
      .filter((d) => (millis(d.data().createdAt) ?? Infinity) < cutoffMs)
      .slice(0, MAX_LINES_PER_STATEMENT);
    const earned = rupees(covered.reduce((s, d) => s + (num(d.data().total) ?? 0), 0));
    const a = acc.data() ?? {};
    const cashHeld = num(a.cashHeld) ?? 0;
    if (earned <= 0 && cashHeld <= 0) return { kind: "nothing" };
    const { netted, payout, cashAfter } = settle(earned, cashHeld);
    let status = "nothing_to_pay";
    let holdReason: string | null = null;
    if (payout > 0) {
      if (typeof a.bankChangePending === "string" && a.bankChangePending) { status = "on_hold"; holdReason = "bank_change_pending"; }
      else if (!hasPayoutDestination(partner.data())) { status = "on_hold"; holdReason = "no_bank_details"; }
      else status = "pending";
    }
    const at = Timestamp.fromMillis(nowMs);
    tx.create(payoutRef, {
      riderId, weekKey, periodEnd: Timestamp.fromMillis(cutoffMs),
      earned, cashHeldBefore: rupees(cashHeld), netted, amount: payout, cashHeldAfter: cashAfter,
      orderCount: covered.length, status, holdReason, createdAt: at, updatedAt: at,
    });
    for (const d of covered) tx.update(d.ref, { statementId: id, settledAt: at });
    tx.set(accRef, {
      riderId,
      earningsUnsettled: FieldValue.increment(-earned),
      ...(netted > 0 ? { cashHeld: FieldValue.increment(-netted) } : {}),
      lastStatementId: id,
      updatedAt: at,
    }, { merge: true });
    if (netted > 0) {
      tx.set(db.collection("rider_cash_ledger").doc(), { riderId, type: "netted_against_payout", amount: netted, statementId: id, at });
    }
    return { kind: "created", id, status, amount: payout, netted };
  });
}

export async function buildAllStatements(db: Db, nowMs: number) {
  const accounts = await db.collection("rider_accounts").get();
  const out = { created: 0, exists: 0, nothing: 0, failed: 0 };
  for (const a of accounts.docs) {
    try {
      const v = await buildStatementCore(db, a.id, nowMs);
      out[v.kind === "created" ? "created" : v.kind] += 1;
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
  return db.runTransaction(async (tx): Promise<BankRequestVerdict> => {
    const [partner, acc] = await Promise.all([tx.get(partnerRef), tx.get(accRef)]);
    if (!partner.exists) return { kind: "refused", reason: "not_a_rider" };
    if (typeof acc.data()?.bankChangePending === "string" && acc.data()!.bankChangePending) return { kind: "refused", reason: "already_pending" };
    const at = Timestamp.fromMillis(nowMs);
    tx.create(reqRef, { riderId, ...v.value, status: "pending", createdAt: at, updatedAt: at });
    tx.set(accRef, { riderId, bankChangePending: reqRef.id, updatedAt: at }, { merge: true });
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
    typeof d.reference === "string" ? d.reference.trim() : "", Date.now());
  if (v.kind === "refused") refuse(v.reason);
  return { success: true, cashHeld: v.cashHeld };
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
  return { success: true, status: v.kind, released: v.released };
});
