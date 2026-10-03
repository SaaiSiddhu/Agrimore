// ============================================================
//  Associate (employee_payouts) admin review — Phase ADMR-3
// ============================================================
//
// Before this phase, apps/admin's employee_payout_detail_screen.dart wrote
// directly to Firestore for both admin actions, and both were broken:
//
//   - "Reject Payout" wrote {status:'rejected', rejectedAt, rejectionReason}.
//     firestore.rules' employee_payouts update rule only ever permitted a
//     transition INTO 'paid' (`request.resource.data.status == 'paid'`) —
//     there was no branch for 'rejected' at all, so this write has ALWAYS
//     failed with permission-denied. Worse: requestEmployeePayout.ts debits
//     the associate's wallet balance IMMEDIATELY at request time (mirroring
//     employeeCommission.ts's transactional style), so even if the write had
//     succeeded, nothing anywhere recredited that debit — a rejected
//     associate would have permanently lost the requested amount.
//   - "Mark as Paid" wrote {status:'paid', paidAt, transactionRef}. The
//     rules' `hasOnly([... 'paymentReference' ...])` allowlist does not
//     include 'transactionRef' — so entering a UTR reference (the correct,
//     careful thing to do) made request.resource.data.diff(...).affectedKeys()
//     include a disallowed key, failing the ENTIRE update. Leaving the
//     reference blank happened to satisfy hasOnly and succeeded, silently
//     encouraging admins toward the one path that records no payment
//     evidence at all.
//
// This callable replaces both direct writes with one canonical, idempotent
// operation per outcome, mirroring functions/src/seller/sellerWallet.ts's
// markWithdrawalPaidCore/closeWithdrawalCore shape exactly — the closest
// sibling this codebase already has for "admin reviews a payout request".
// The one material difference from the seller case: a seller withdrawal
// only REGROUPS already-earned seller_payouts rows (nothing was debited, so
// rejecting just ungroups them), while an employee_payouts row already
// removed real money from wallets/{employeeId}.balance at request time — so
// rejecting here must ACTIVELY credit it back, once, inside the same
// transaction that flips status, the same idempotency shape
// requestEmployeePayout.ts's own debit already established.
//
// Generation: v2 onCall, no secrets.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { resolveIsAdmin } from "../admin/complianceGate";
import { employeeWalletRef } from "../employee/employeePayoutAccount";
import { isExactMoneyAmount } from "../common/paymentIntegrity";
import { payoutBalancePaise, payoutAmountFromPaise } from "../employee/employeePayoutMoney";

type Db = FirebaseFirestore.Firestore;

type ReviewVerdict =
  | { kind: "paid" | "rejected" | "already"; employeeId: string; amount: number }
  | { kind: "refused"; reason: "not_found" | "not_requested" | "bad_reference" | "reason_required" | "payout_change_pending" | "bad_money_state" };

/** Admin: the money was sent. Idempotent on an identical (payoutId, reference) retry.
 * Phase ADMR-5: refuses while a bank/UPI change is pending review — the same
 * protection markWithdrawalPaidCore already gives sellers, so a stale admin
 * tab cannot pay out to a destination that is about to change. */
async function markEmployeePayoutPaidCore(
  db: Db, adminUid: string, payoutId: string, reference: string, nowMs: number
): Promise<ReviewVerdict> {
  const ref = reference.trim();
  if (ref.length < 4 || ref.length > 64) return { kind: "refused", reason: "bad_reference" };
  const payoutRef = db.collection("employee_payouts").doc(payoutId);
  return db.runTransaction(async (tx): Promise<ReviewVerdict> => {
    const snap = await tx.get(payoutRef);
    if (!snap.exists) return { kind: "refused", reason: "not_found" };
    const d = snap.data()!;
    const employeeId = d.employeeId;
    const storedAmount = d.amount;
    if (typeof employeeId !== "string" || !employeeId || employeeId.length > 128 ||
        employeeId.includes("/") || !isExactMoneyAmount(storedAmount)) {
      return { kind: "refused", reason: "bad_money_state" };
    }
    const amount = Math.round(storedAmount * 100) / 100;
    if (d.status === "paid" && d.paymentReference === ref) return { kind: "already", employeeId, amount };
    if (d.status !== "requested") return { kind: "refused", reason: "not_requested" };
    const wallet = await tx.get(employeeWalletRef(db, employeeId));
    if (typeof wallet.data()?.payoutChangePending === "string" && wallet.data()?.payoutChangePending) {
      return { kind: "refused", reason: "payout_change_pending" };
    }
    const at = Timestamp.fromMillis(nowMs);
    tx.update(payoutRef, {
      status: "paid", paidAt: at, paidBy: adminUid, paymentReference: ref, updatedAt: at,
    });
    return { kind: "paid", employeeId, amount };
  });
}

/** Admin rejects (a reason is required): the debited amount is credited back exactly once. */
async function rejectEmployeePayoutCore(
  db: Db, adminUid: string, payoutId: string, reason: string, nowMs: number
): Promise<ReviewVerdict> {
  const r = reason.trim();
  if (r.length < 3 || r.length > 200) return { kind: "refused", reason: "reason_required" };
  const payoutRef = db.collection("employee_payouts").doc(payoutId);
  return db.runTransaction(async (tx): Promise<ReviewVerdict> => {
    const snap = await tx.get(payoutRef);
    if (!snap.exists) return { kind: "refused", reason: "not_found" };
    const d = snap.data()!;
    const employeeId = d.employeeId;
    const storedAmount = d.amount;
    if (typeof employeeId !== "string" || !employeeId || employeeId.length > 128 ||
        employeeId.includes("/") || !isExactMoneyAmount(storedAmount)) {
      return { kind: "refused", reason: "bad_money_state" };
    }
    const amount = Math.round(storedAmount * 100) / 100;
    if (d.status === "rejected") return { kind: "already", employeeId, amount };
    if (d.status !== "requested") return { kind: "refused", reason: "not_requested" };
    const at = Timestamp.fromMillis(nowMs);
    const walletRef = db.collection("wallets").doc(employeeId);
    const walletTxRef = db.collection("wallet_transactions").doc();
    const walletSnap = await tx.get(walletRef);
    const currentPaise = payoutBalancePaise(walletSnap.data()?.balance);
    if (!walletSnap.exists || currentPaise === null) return { kind: "refused", reason: "bad_money_state" };
    const balancePaise = currentPaise + Math.round(amount * 100);
    if (!Number.isSafeInteger(balancePaise)) return { kind: "refused", reason: "bad_money_state" };
    const balanceAfter = payoutAmountFromPaise(balancePaise);
    if (balanceAfter === null) return { kind: "refused", reason: "bad_money_state" };
    tx.set(walletRef, { balance: balanceAfter, updatedAt: at }, { merge: true });
    tx.set(walletTxRef, {
      walletId: employeeId,
      userId: employeeId,
      type: "credit",
      source: "adjustment", // mirrors requestEmployeePayout.ts's own debit — see that file's comment
      amount,
      coins: 0,
      balanceAfter,
      coinsAfter: walletSnap.data()?.coins ?? 0,
      orderId: null,
      description: "Payout request rejected — amount returned to wallet",
      referenceId: payoutId,
      createdAt: at,
      expiresAt: null,
      metadata: { payoutId, reversalOf: "employee_payout_request", rejectionReason: r },
    });
    tx.update(payoutRef, {
      status: "rejected", rejectedAt: at, rejectedBy: adminUid, rejectionReason: r, updatedAt: at,
    });
    return { kind: "rejected", employeeId, amount };
  });
}

async function requireAdmin(request: { auth?: { uid: string; token: Record<string, unknown> } }): Promise<string> {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required");
  const ok = await resolveIsAdmin(admin.firestore(), request.auth.uid, request.auth.token.admin === true);
  if (!ok) throw new HttpsError("permission-denied", "Admins only");
  return request.auth.uid;
}

const REFUSAL_TEXT: Record<string, string> = {
  not_found: "Payout request not found",
  bad_money_state: "Payout or wallet details need review before continuing",
  not_requested: "This payout has already been reviewed",
  bad_reference: "Enter a payment reference (4–64 characters)",
  reason_required: "Give a reason (3–200 characters)",
  payout_change_pending: "This associate has a bank/UPI change waiting for review. Review it first.",
};
function refuse(reason: string): never {
  const message = REFUSAL_TEXT[reason] ?? "Not possible";
  throw new HttpsError(reason === "not_found" ? "not-found" : "failed-precondition", message, { reason });
}
const str = (v: unknown) => (typeof v === "string" ? v.trim() : "");
const opts = { minInstances: 0, memory: "256MiB" as const };

export const markEmployeePayoutPaid = onCall(opts, async (request) => {
  const adminUid = await requireAdmin(request as never);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const payoutId = str(d.payoutId);
  if (!payoutId) throw new HttpsError("invalid-argument", "payoutId is required");
  const v = await markEmployeePayoutPaidCore(admin.firestore(), adminUid, payoutId, str(d.paymentReference), Date.now());
  if (v.kind === "refused") refuse(v.reason);
  return { success: true, alreadyPaid: v.kind === "already" };
});

export const rejectEmployeePayout = onCall(opts, async (request) => {
  const adminUid = await requireAdmin(request as never);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const payoutId = str(d.payoutId);
  if (!payoutId) throw new HttpsError("invalid-argument", "payoutId is required");
  const v = await rejectEmployeePayoutCore(admin.firestore(), adminUid, payoutId, str(d.reason), Date.now());
  if (v.kind === "refused") refuse(v.reason);
  return { success: true, alreadyRejected: v.kind === "already", amountReturned: v.kind === "rejected" ? v.amount : 0 };
});
