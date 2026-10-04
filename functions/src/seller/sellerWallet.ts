// ============================================================
//  Seller wallet + payout-account changes (SELLER-WALLET-1)
// ============================================================
//
// OWNER_DECISION 2026-09-24 (chat, "Both … end to end on both seller and
// admin app") reverses the redesign brief's "no wallet / no payout request".
//
// The wallet is NOT a second store of money. The seller's balance is exactly
// the server-written seller_payouts rows (sellerNotifications.ts creates one
// per delivered order, net of commission) that are still `pending`. A
// withdrawal gathers those rows into one request the admin pays by bank/UPI:
//
//   seller_payouts   pending ──withdraw──▶ requested ──admin paid──▶ paid
//                                   ▲            │
//                                   └─reject/cancel┘
//
//   seller_withdrawals/{id}              requested → paid | rejected | cancelled
//   seller_payout_change_requests/{id}   pending → approved | rejected | cancelled
//   seller_wallets/{sellerId}            openWithdrawal, payoutChangePending
//
// Payout-account changes follow the rider pattern (riderMoney.ts, DLV-M1): the
// seller requests, an admin approves, and while a change is pending no payout
// can be paid to the old destination (callable here, and firestore.rules for
// the legacy per-payout path). Before this, sellers could not add or change
// their bank/UPI at all after approval — seller_payout_details is admin-write
// only (FIX-2) and no screen offered it.
//
// All three collections are server-written; firestore.rules give the seller
// read of their own rows and admins read of all. Amounts are summed in whole
// paise. Modular FieldValue/Timestamp (see riderMoney.ts).

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { resolveIsAdmin } from "../admin/complianceGate";
import { notifyUser } from "../customer/orderNotifications";

type Db = FirebaseFirestore.Firestore;

export const toPaise = (rupees: number) => Math.round(rupees * 100);
export const fromPaise = (paise: number) => paise / 100;

/** At most this many payouts in one withdrawal (a transaction writes each). */
export const MAX_PAYOUTS_PER_WITHDRAWAL = 400;
export const DEFAULT_MIN_WITHDRAWAL_PAISE = 10000; // ₹100
export const DEFAULT_HOLD_DAYS = 0;

const IFSC = /^[A-Z]{4}0[A-Z0-9]{6}$/;
const UPI = /^[a-z0-9._-]{2,256}@[a-z]{2,64}$/;
const ACCOUNT = /^\d{9,18}$/;

export const walletRef = (db: Db, sellerId: string) => db.collection("seller_wallets").doc(sellerId);

export interface WalletSettings { minWithdrawalPaise: number; holdDays: number }

/** settings/seller_wallet: { minWithdrawal (rupees), holdDays } — both optional. */
export async function loadWalletSettings(db: Db): Promise<WalletSettings> {
  const d = (await db.collection("settings").doc("seller_wallet").get()).data() ?? {};
  const min = typeof d.minWithdrawal === "number" && Number.isFinite(d.minWithdrawal) && d.minWithdrawal >= 0
    ? toPaise(d.minWithdrawal) : DEFAULT_MIN_WITHDRAWAL_PAISE;
  const hold = typeof d.holdDays === "number" && Number.isInteger(d.holdDays) && d.holdDays >= 0 && d.holdDays <= 60
    ? d.holdDays : DEFAULT_HOLD_DAYS;
  return { minWithdrawalPaise: min, holdDays: hold };
}

const millis = (v: unknown): number | null =>
  v instanceof Timestamp ? v.toMillis()
    : v && typeof (v as { toMillis?: unknown }).toMillis === "function" ? (v as { toMillis: () => number }).toMillis() : null;

const netPaise = (d: FirebaseFirestore.DocumentData) => {
  const n = typeof d.netAmount === "number" ? d.netAmount : typeof d.amount === "number" ? d.amount : 0;
  return Number.isFinite(n) && n > 0 ? toPaise(n) : 0;
};

/** Whether a payout row can go into a withdrawal now. */
export function isWithdrawable(d: FirebaseFirestore.DocumentData, cutoffMs: number): boolean {
  if (d.status !== "pending" || d.withdrawalId) return false;
  const at = millis(d.createdAt);
  return at !== null && at <= cutoffMs && netPaise(d) > 0;
}

// ── payout destination ──

export interface PayoutDetails {
  payoutMethod: "bank" | "upi";
  accountHolder: string | null;
  bankName: string | null;
  accountNumber: string | null;
  ifsc: string | null;
  upiId: string | null;
}

/** Validates what the seller typed. Only the chosen method's fields are kept. */
export function validatePayoutDetails(raw: unknown): { ok: true; value: PayoutDetails } | { ok: false; error: string } {
  const d = (raw ?? {}) as Record<string, unknown>;
  const s = (v: unknown) => (typeof v === "string" && v.trim() ? v.trim() : null);
  const holder = s(d.accountHolder);
  if (holder !== null && (holder.length < 2 || holder.length > 100)) return { ok: false, error: "accountHolder" };
  if (d.payoutMethod === "bank") {
    const bank = s(d.bankName);
    const acct = s(d.accountNumber)?.replace(/\s+/g, "") ?? null;
    const ifsc = s(d.ifsc)?.toUpperCase() ?? null;
    if (!holder) return { ok: false, error: "accountHolder" };
    if (!bank || bank.length < 2 || bank.length > 100) return { ok: false, error: "bankName" };
    if (!acct || !ACCOUNT.test(acct)) return { ok: false, error: "accountNumber" };
    if (!ifsc || !IFSC.test(ifsc)) return { ok: false, error: "ifsc" };
    return { ok: true, value: { payoutMethod: "bank", accountHolder: holder, bankName: bank, accountNumber: acct, ifsc, upiId: null } };
  }
  if (d.payoutMethod === "upi") {
    const upi = s(d.upiId)?.toLowerCase() ?? null;
    if (!upi || !UPI.test(upi)) return { ok: false, error: "upiId" };
    return { ok: true, value: { payoutMethod: "upi", accountHolder: holder, bankName: null, accountNumber: null, ifsc: null, upiId: upi } };
  }
  return { ok: false, error: "payoutMethod" };
}

/** Where a payout would go today, masked — or null when the details are incomplete. */
export function payoutDestination(d: FirebaseFirestore.DocumentData | undefined): Record<string, unknown> | null {
  if (!d) return null;
  const str = (v: unknown) => (typeof v === "string" ? v.trim() : "");
  const acct = str(d.accountNumber).replace(/\s+/g, "");
  const method = d.payoutMethod === "upi" ? "upi" : "bank";
  if (method === "bank") {
    if (!acct || !str(d.ifsc)) return null;
    return { method, accountLast4: acct.slice(-4), ifsc: str(d.ifsc), bankName: str(d.bankName) || null, accountHolder: str(d.accountHolder) || null };
  }
  const upi = str(d.upiId);
  if (!upi) return null;
  return { method, upiId: upi };
}

/**
 * The full (unmasked) payout details behind `payoutDestination`'s masked view — same field
 * names as seller_payout_details itself (payoutMethod/accountNumber/ifsc/bankName/
 * accountHolder/upiId), same completeness rule (delegates to payoutDestination so the two can
 * never disagree on when a destination is "on file"). Frozen onto a withdrawal at request time
 * (requestWithdrawalCore) so an admin has the real account number to act on without a live
 * re-read of seller_payout_details that a later bank/UPI change could have altered. Admin +
 * owning-seller read only — the same access level seller_payout_details and
 * seller_payout_change_requests already give a full account number at.
 */
export function payoutDestinationFull(d: FirebaseFirestore.DocumentData | undefined): Record<string, unknown> | null {
  if (payoutDestination(d) === null) return null;
  const str = (v: unknown) => (typeof v === "string" ? v.trim() : "");
  const method = d!.payoutMethod === "upi" ? "upi" : "bank";
  return {
    payoutMethod: method,
    accountHolder: str(d!.accountHolder) || null,
    bankName: method === "bank" ? str(d!.bankName) || null : null,
    accountNumber: method === "bank" ? str(d!.accountNumber).replace(/\s+/g, "") : null,
    ifsc: method === "bank" ? str(d!.ifsc) || null : null,
    upiId: method === "upi" ? str(d!.upiId) : null,
  };
}

// ── summary (what the seller sees) ──

export interface WalletSummary {
  availablePaise: number;
  availableCount: number;
  heldPaise: number;
  minWithdrawalPaise: number;
  holdDays: number;
  openWithdrawalId: string | null;
  payoutChangePendingId: string | null;
  hasDestination: boolean;
}

export async function walletSummaryCore(db: Db, sellerId: string, nowMs: number): Promise<WalletSummary> {
  const settings = await loadWalletSettings(db);
  const cutoff = nowMs - settings.holdDays * 86400000;
  const [pending, wallet, details] = await Promise.all([
    db.collection("seller_payouts").where("sellerId", "==", sellerId).where("status", "==", "pending").get(),
    walletRef(db, sellerId).get(),
    db.collection("seller_payout_details").doc(sellerId).get(),
  ]);
  let available = 0, count = 0, held = 0;
  for (const p of pending.docs) {
    const d = p.data();
    if (d.withdrawalId) continue;
    if (isWithdrawable(d, cutoff)) { available += netPaise(d); count += 1; } else held += netPaise(d);
  }
  const w = wallet.data() ?? {};
  return {
    availablePaise: available,
    availableCount: count,
    heldPaise: held,
    minWithdrawalPaise: settings.minWithdrawalPaise,
    holdDays: settings.holdDays,
    openWithdrawalId: typeof w.openWithdrawal === "string" ? w.openWithdrawal : null,
    payoutChangePendingId: typeof w.payoutChangePending === "string" ? w.payoutChangePending : null,
    hasDestination: payoutDestination(details.data()) !== null,
  };
}

// ── withdrawals ──

export type WithdrawVerdict =
  | { kind: "requested" | "already"; id: string; amountPaise: number; count: number }
  | { kind: "refused"; reason: "not_a_seller" | "bad_request_id" | "withdrawal_open" | "payout_change_pending"
      | "no_destination" | "nothing_to_withdraw" | "below_minimum" };

/**
 * The seller asks to be paid everything withdrawable now. `requestId` is made
 * by the phone once per tap, so a retried call returns the first result.
 */
export async function requestWithdrawalCore(db: Db, sellerId: string, requestId: unknown, nowMs: number): Promise<WithdrawVerdict> {
  if (typeof requestId !== "string" || !/^[A-Za-z0-9_-]{8,64}$/.test(requestId)) return { kind: "refused", reason: "bad_request_id" };
  const settings = await loadWalletSettings(db);
  const cutoff = nowMs - settings.holdDays * 86400000;
  const id = `${sellerId}_${requestId}`;
  const wRef = db.collection("seller_withdrawals").doc(id);
  const accRef = walletRef(db, sellerId);
  const pendingQ = db.collection("seller_payouts").where("sellerId", "==", sellerId).where("status", "==", "pending");
  return db.runTransaction(async (tx): Promise<WithdrawVerdict> => {
    // A historical request is its own replay anchor. Later seller, wallet,
    // destination or pending-payout changes must not add reads to that retry.
    const existing = await tx.get(wRef);
    if (existing.exists) {
      const e = existing.data()!;
      if (e.sellerId !== sellerId) return { kind: "refused", reason: "bad_request_id" };
      return { kind: "already", id, amountPaise: Number(e.amountPaise ?? 0), count: Number(e.payoutCount ?? 0) };
    }
    const [seller, acc, details, pending] = await Promise.all([
      tx.get(db.collection("sellers").doc(sellerId)), tx.get(accRef),
      tx.get(db.collection("seller_payout_details").doc(sellerId)), tx.get(pendingQ),
    ]);
    if (!seller.exists) return { kind: "refused", reason: "not_a_seller" };
    const a = acc.data() ?? {};
    if (typeof a.payoutChangePending === "string" && a.payoutChangePending) return { kind: "refused", reason: "payout_change_pending" };
    if (typeof a.openWithdrawal === "string" && a.openWithdrawal) return { kind: "refused", reason: "withdrawal_open" };
    const destination = payoutDestination(details.data());
    if (!destination) return { kind: "refused", reason: "no_destination" };
    const destinationFull = payoutDestinationFull(details.data());

    const rows = pending.docs
      .filter((p) => isWithdrawable(p.data(), cutoff))
      .sort((x, y) => (millis(x.data().createdAt) ?? 0) - (millis(y.data().createdAt) ?? 0))
      .slice(0, MAX_PAYOUTS_PER_WITHDRAWAL);
    const amountPaise = rows.reduce((sum, p) => sum + netPaise(p.data()), 0);
    if (amountPaise <= 0) return { kind: "refused", reason: "nothing_to_withdraw" };
    if (amountPaise < settings.minWithdrawalPaise) return { kind: "refused", reason: "below_minimum" };

    const at = Timestamp.fromMillis(nowMs);
    tx.create(wRef, {
      sellerId, status: "requested", amountPaise, amount: fromPaise(amountPaise),
      payoutIds: rows.map((p) => p.id), payoutCount: rows.length,
      orderNumbers: rows.map((p) => String(p.data().orderNumber || p.data().orderId || "")),
      destination, destinationFull, createdAt: at, updatedAt: at,
    });
    for (const p of rows) tx.update(p.ref, { status: "requested", withdrawalId: id, updatedAt: at });
    tx.set(accRef, { sellerId, openWithdrawal: id, updatedAt: at }, { merge: true });
    return { kind: "requested", id, amountPaise, count: rows.length };
  });
}

export type CloseVerdict =
  | { kind: "paid" | "rejected" | "cancelled" | "already"; sellerId: string; amountPaise: number; paidTo?: Record<string, unknown> }
  | { kind: "refused"; reason: "not_found" | "not_requested" | "not_yours" | "payout_change_pending" | "no_destination"
      | "bad_reference" | "bad_method" | "reason_required" | "payout_mismatch" | "method_mismatch" | "legacy_destination_unresolved" };

/**
 * ADMR-84: whether `full` is a genuinely complete, internally consistent destinationFull
 * snapshot — never just "is it a non-null object". A withdrawal predating ADMR-77 (or one with a
 * malformed snapshot) has no full destination that can be trusted to pay from; per ADMR-83, no
 * reconstruction from any other record is ever attempted here either.
 */
function isValidDestinationFull(full: unknown, maskedMethod: unknown): full is Record<string, unknown> {
  if (!full || typeof full !== "object" || Array.isArray(full)) return false;
  const f = full as Record<string, unknown>;
  const method = f.payoutMethod === "upi" ? "upi" : f.payoutMethod === "bank" ? "bank" : null;
  if (!method || method !== maskedMethod) return false;
  const str = (v: unknown) => typeof v === "string" && v.trim().length > 0;
  if (method === "bank") return str(f.accountNumber) && str(f.ifsc);
  return str(f.upiId);
}

/**
 * Admin: the money was sent. Refused while a payout-account change is pending. Pays to the
 * destination frozen on the withdrawal at request time (requestWithdrawalCore) — never a live
 * re-read of seller_payout_details — so a bank/UPI change approved after this withdrawal was
 * already requested can never silently redirect it. `method` must match the frozen
 * destination's own method; a mismatch is refused (method_mismatch), not silently reconciled.
 *
 * ADMR-84: a withdrawal predating ADMR-77 (no destinationFull, or a malformed one) is refused
 * outright (legacy_destination_unresolved) for a requested→paid transition — this is a
 * server-authoritative gate, not merely the admin app's own "Mark paid" button being disabled;
 * a direct call cannot bypass it. Placed AFTER the already-paid idempotent-replay check, so a
 * withdrawal paid before this gate existed remains fully readable and its own replay semantics
 * are completely unaffected — this only gates a NEW requested→paid transition, never a
 * historical result. No reconstruction is attempted here (ADMR-83's own conclusion): if
 * destinationFull is absent or invalid, this simply refuses.
 */
export async function markWithdrawalPaidCore(
  db: Db, adminUid: string, withdrawalId: string, reference: string, method: unknown, nowMs: number
): Promise<CloseVerdict> {
  const ref = reference.trim();
  if (ref.length < 4 || ref.length > 64) return { kind: "refused", reason: "bad_reference" };
  if (method !== "bank" && method !== "upi") return { kind: "refused", reason: "bad_method" };
  const wRef = db.collection("seller_withdrawals").doc(withdrawalId);
  return db.runTransaction(async (tx): Promise<CloseVerdict> => {
    const w = await tx.get(wRef);
    if (!w.exists) return { kind: "refused", reason: "not_found" };
    const d = w.data()!;
    const sellerId = String(d.sellerId);
    const amountPaise = Number(d.amountPaise ?? 0);
    if (d.status === "paid" && d.paymentReference === ref) return { kind: "already", sellerId, amountPaise, paidTo: d.paidTo ?? {} };
    if (d.status !== "requested") return { kind: "refused", reason: "not_requested" };
    const ids: string[] = Array.isArray(d.payoutIds) ? d.payoutIds.map(String) : [];
    const [acc, ...payouts] = await Promise.all([
      tx.get(walletRef(db, sellerId)),
      ...ids.map((pid) => tx.get(db.collection("seller_payouts").doc(pid))),
    ]);
    const a = acc.data() ?? {};
    if (typeof a.payoutChangePending === "string" && a.payoutChangePending) return { kind: "refused", reason: "payout_change_pending" };
    for (const p of payouts) {
      const pd = p.data();
      if (!pd || pd.withdrawalId !== withdrawalId || pd.status !== "requested") return { kind: "refused", reason: "payout_mismatch" };
    }
    const dest = d.destination as Record<string, unknown> | undefined;
    if (!dest) return { kind: "refused", reason: "no_destination" };
    if (dest.method !== method) return { kind: "refused", reason: "method_mismatch" };
    if (!isValidDestinationFull(d.destinationFull, dest.method)) return { kind: "refused", reason: "legacy_destination_unresolved" };
    const at = Timestamp.fromMillis(nowMs);
    for (const p of payouts) {
      tx.update(p.ref, { status: "paid", paidAt: at, paidBy: adminUid, paymentReference: ref, payoutMethod: method, updatedAt: at });
    }
    tx.update(wRef, { status: "paid", paidAt: at, paidBy: adminUid, paymentReference: ref, payoutMethod: method, paidTo: dest, updatedAt: at });
    if (a.openWithdrawal === withdrawalId) tx.set(walletRef(db, sellerId), { openWithdrawal: null, updatedAt: at }, { merge: true });
    return { kind: "paid", sellerId, amountPaise, paidTo: dest };
  });
}

/** Admin rejects (with a reason) or the seller cancels: the payouts go back to the balance. */
export async function closeWithdrawalCore(
  db: Db, actor: { adminUid?: string; sellerId?: string }, withdrawalId: string, reason: string | null, nowMs: number
): Promise<CloseVerdict> {
  const byAdmin = typeof actor.adminUid === "string";
  if (byAdmin && (!reason || reason.length < 3 || reason.length > 200)) return { kind: "refused", reason: "reason_required" };
  const wRef = db.collection("seller_withdrawals").doc(withdrawalId);
  return db.runTransaction(async (tx): Promise<CloseVerdict> => {
    const w = await tx.get(wRef);
    if (!w.exists) return { kind: "refused", reason: "not_found" };
    const d = w.data()!;
    const sellerId = String(d.sellerId);
    if (!byAdmin && sellerId !== actor.sellerId) return { kind: "refused", reason: "not_yours" };
    const target = byAdmin ? "rejected" : "cancelled";
    if (d.status === target) return { kind: "already", sellerId, amountPaise: Number(d.amountPaise ?? 0) };
    if (d.status !== "requested") return { kind: "refused", reason: "not_requested" };
    const ids: string[] = Array.isArray(d.payoutIds) ? d.payoutIds.map(String) : [];
    const [acc, ...payouts] = await Promise.all([
      tx.get(walletRef(db, sellerId)), ...ids.map((pid) => tx.get(db.collection("seller_payouts").doc(pid))),
    ]);
    const at = Timestamp.fromMillis(nowMs);
    for (const p of payouts) {
      const pd = p.data();
      if (pd && pd.withdrawalId === withdrawalId && pd.status === "requested") {
        tx.update(p.ref, { status: "pending", withdrawalId: FieldValue.delete(), updatedAt: at });
      }
    }
    tx.update(wRef, byAdmin
      ? { status: "rejected", rejectedAt: at, reviewedBy: actor.adminUid, rejectionReason: reason, updatedAt: at }
      : { status: "cancelled", cancelledAt: at, updatedAt: at });
    if (acc.data()?.openWithdrawal === withdrawalId) tx.set(walletRef(db, sellerId), { openWithdrawal: null, updatedAt: at }, { merge: true });
    return { kind: target, sellerId, amountPaise: Number(d.amountPaise ?? 0) };
  });
}

// ── payout-account changes ──

export type ChangeVerdict = { kind: "requested"; id: string } | { kind: "refused"; reason: "not_a_seller" | "already_pending" | string };

export async function requestPayoutChangeCore(db: Db, sellerId: string, data: unknown, nowMs: number): Promise<ChangeVerdict> {
  const v = validatePayoutDetails(data);
  if (!v.ok) return { kind: "refused", reason: `invalid_${v.error}` };
  const reqRef = db.collection("seller_payout_change_requests").doc();
  const accRef = walletRef(db, sellerId);
  return db.runTransaction(async (tx): Promise<ChangeVerdict> => {
    const [seller, acc, current] = await Promise.all([
      tx.get(db.collection("sellers").doc(sellerId)), tx.get(accRef), tx.get(db.collection("seller_payout_details").doc(sellerId)),
    ]);
    if (!seller.exists) return { kind: "refused", reason: "not_a_seller" };
    const a = acc.data() ?? {};
    if (typeof a.payoutChangePending === "string" && a.payoutChangePending) return { kind: "refused", reason: "already_pending" };
    const at = Timestamp.fromMillis(nowMs);
    tx.create(reqRef, {
      sellerId, ...v.value, previous: payoutDestination(current.data()), status: "pending", createdAt: at, updatedAt: at,
    });
    tx.set(accRef, { sellerId, payoutChangePending: reqRef.id, updatedAt: at }, { merge: true });
    return { kind: "requested", id: reqRef.id };
  });
}

export type ChangeReviewVerdict =
  | { kind: "approved" | "rejected" | "cancelled"; sellerId: string }
  | { kind: "refused"; reason: "not_found" | "not_pending" | "reason_required" | "not_yours" };

export async function reviewPayoutChangeCore(
  db: Db, actor: { adminUid?: string; sellerId?: string }, requestId: string, approve: boolean, reason: string | null, nowMs: number
): Promise<ChangeReviewVerdict> {
  const byAdmin = typeof actor.adminUid === "string";
  if (byAdmin && !approve && (!reason || reason.length < 3 || reason.length > 200)) return { kind: "refused", reason: "reason_required" };
  const reqRef = db.collection("seller_payout_change_requests").doc(requestId);
  return db.runTransaction(async (tx): Promise<ChangeReviewVerdict> => {
    const req = await tx.get(reqRef);
    if (!req.exists) return { kind: "refused", reason: "not_found" };
    const r = req.data()!;
    const sellerId = String(r.sellerId);
    if (!byAdmin && sellerId !== actor.sellerId) return { kind: "refused", reason: "not_yours" };
    if (r.status !== "pending") return { kind: "refused", reason: "not_pending" };
    const acc = await tx.get(walletRef(db, sellerId));
    const at = Timestamp.fromMillis(nowMs);
    const outcome: "approved" | "rejected" | "cancelled" = !byAdmin ? "cancelled" : approve ? "approved" : "rejected";
    tx.update(reqRef, {
      status: outcome, updatedAt: at,
      ...(byAdmin ? { reviewedBy: actor.adminUid, reviewedAt: at, rejectionReason: approve ? null : reason } : { cancelledAt: at }),
    });
    if (outcome === "approved") {
      tx.set(db.collection("seller_payout_details").doc(sellerId), {
        sellerId,
        payoutMethod: r.payoutMethod, accountHolder: r.accountHolder ?? null, bankName: r.bankName ?? null,
        accountNumber: r.accountNumber ?? null, ifsc: r.ifsc ?? null, upiId: r.upiId ?? null,
        verifiedBy: actor.adminUid, verifiedAt: at, updatedAt: at,
      }, { merge: true });
    }
    if (acc.data()?.payoutChangePending === requestId) tx.set(walletRef(db, sellerId), { payoutChangePending: null, updatedAt: at }, { merge: true });
    return { kind: outcome, sellerId };
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
  not_a_seller: "Only sellers can do this",
  bad_request_id: "The request could not be read — try again",
  withdrawal_open: "A withdrawal is already waiting to be paid",
  payout_change_pending: "A bank/UPI change is waiting for review",
  no_destination: "Add a bank account or UPI ID first",
  nothing_to_withdraw: "There is nothing to withdraw yet",
  below_minimum: "The balance is below the minimum withdrawal",
  not_found: "Not found",
  not_requested: "This withdrawal is no longer waiting to be paid",
  not_yours: "Not your request",
  bad_reference: "Enter a payment reference (4–64 characters)",
  bad_method: "Choose bank or UPI",
  method_mismatch: "This withdrawal was requested for a different payment method — refresh and check",
  legacy_destination_unresolved: "This request predates full destination records and cannot be paid from here — confirm the account with the seller/owner first",
  reason_required: "Give a reason (3–200 characters)",
  payout_mismatch: "The payouts in this withdrawal changed — refresh and try again",
  already_pending: "A change is already waiting for review",
  not_pending: "This request has already been reviewed",
};
function refuse(reason: string): never {
  const message = REFUSAL_TEXT[reason] ?? (reason.startsWith("invalid_") ? `Check the ${reason.slice(8)} field` : "Not possible");
  throw new HttpsError(reason === "not_found" ? "not-found" : "failed-precondition", message, { reason });
}
const str = (v: unknown) => (typeof v === "string" ? v.trim() : "");
const rupeeText = (paise: number) => `Rs.${fromPaise(paise).toFixed(2)}`;
const opts = { minInstances: 0, memory: "256MiB" as const };

export const sellerWalletSummary = onCall(opts, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required");
  return walletSummaryCore(admin.firestore(), request.auth.uid, Date.now());
});

export const requestSellerWithdrawal = onCall(opts, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required");
  const v = await requestWithdrawalCore(admin.firestore(), request.auth.uid, (request.data ?? {}).requestId, Date.now());
  if (v.kind === "refused") refuse(v.reason);
  return { success: true, withdrawalId: v.id, amountPaise: v.amountPaise, payoutCount: v.count, alreadyRequested: v.kind === "already" };
});

export const cancelSellerWithdrawal = onCall(opts, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required");
  const id = str((request.data ?? {}).withdrawalId);
  if (!id) throw new HttpsError("invalid-argument", "withdrawalId is required");
  const v = await closeWithdrawalCore(admin.firestore(), { sellerId: request.auth.uid }, id, null, Date.now());
  if (v.kind === "refused") refuse(v.reason);
  return { success: true, status: v.kind };
});

export const markSellerWithdrawalPaid = onCall(opts, async (request) => {
  const adminUid = await requireAdmin(request as never);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const id = str(d.withdrawalId);
  if (!id) throw new HttpsError("invalid-argument", "withdrawalId is required");
  const v = await markWithdrawalPaidCore(admin.firestore(), adminUid, id, str(d.reference), d.method, Date.now());
  if (v.kind === "refused") refuse(v.reason);
  if (v.kind === "paid") {
    await notifyUser(v.sellerId, "Withdrawal paid", `${rupeeText(v.amountPaise)} has been sent to your account (ref ${str(d.reference)}).`,
      "withdrawal_paid", { withdrawalId: id, type: "payout", actionUrl: `withdrawal/${id}` }, "💸");
  }
  return { success: true, paidTo: v.paidTo ?? null, alreadyPaid: v.kind === "already" };
});

export const rejectSellerWithdrawal = onCall(opts, async (request) => {
  const adminUid = await requireAdmin(request as never);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const id = str(d.withdrawalId);
  if (!id) throw new HttpsError("invalid-argument", "withdrawalId is required");
  const reason = str(d.reason);
  const v = await closeWithdrawalCore(admin.firestore(), { adminUid }, id, reason, Date.now());
  if (v.kind === "refused") refuse(v.reason);
  if (v.kind === "rejected") {
    await notifyUser(v.sellerId, "Withdrawal not paid", `Your withdrawal of ${rupeeText(v.amountPaise)} was not paid: ${reason}. The amount is back in your balance.`,
      "withdrawal_rejected", { withdrawalId: id, type: "payout", actionUrl: `withdrawal/${id}` }, "⚠️");
  }
  return { success: true, status: v.kind };
});

export const requestSellerPayoutChange = onCall(opts, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required");
  const v = await requestPayoutChangeCore(admin.firestore(), request.auth.uid, request.data, Date.now());
  if (v.kind === "refused") refuse(v.reason);
  return { success: true, requestId: v.id };
});

export const cancelSellerPayoutChange = onCall(opts, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required");
  const id = str((request.data ?? {}).requestId);
  if (!id) throw new HttpsError("invalid-argument", "requestId is required");
  const v = await reviewPayoutChangeCore(admin.firestore(), { sellerId: request.auth.uid }, id, false, null, Date.now());
  if (v.kind === "refused") refuse(v.reason);
  return { success: true, status: v.kind };
});

export const reviewSellerPayoutChange = onCall(opts, async (request) => {
  const adminUid = await requireAdmin(request as never);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const id = str(d.requestId);
  if (!id) throw new HttpsError("invalid-argument", "requestId is required");
  const approve = d.approve === true;
  const reason = str(d.reason) || null;
  const v = await reviewPayoutChangeCore(admin.firestore(), { adminUid }, id, approve, reason, Date.now());
  if (v.kind === "refused") refuse(v.reason);
  await notifyUser(v.sellerId,
    approve ? "Payout account updated" : "Payout account change not approved",
    approve ? "Your new bank/UPI details are verified. Payouts will go there from now on." : `Your bank/UPI change was not approved: ${reason}.`,
    approve ? "payout_change_approved" : "payout_change_rejected", { requestId: id, type: "payout" }, approve ? "✅" : "⚠️");
  return { success: true, status: v.kind };
});
