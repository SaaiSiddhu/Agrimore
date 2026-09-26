// ============================================================
//  Associate bank/UPI account changes — Phase ADMR-5
// ============================================================
//
// Before this phase, apps/employee's payout_account_screen.dart wrote
// accountNumber/ifscCode/bankName/upiId/payoutMethod DIRECTLY onto
// employees/{uid} — no review, no hold, no version, no audit trail. An
// associate could redirect their own payout destination the instant before
// an admin pays them out (functions/src/customer/reviewEmployeePayout.ts,
// Phase ADMR-3).
//
// This mirrors functions/src/seller/sellerWallet.ts's own
// requestPayoutChangeCore/reviewPayoutChangeCore shape exactly — the
// closest existing sibling for "an actor proposes a payout-destination
// change, an admin reviews it" — and reuses that file's exported
// validatePayoutDetails()/payoutDestination() directly rather than
// re-implementing bank/UPI validation a second time. Two differences from
// the seller case, both deliberate:
//   - The pending-change marker lives on a NEW, minimal, Cloud-Functions-only
//     employee_wallets/{employeeId} doc — mirroring seller_wallets' own role
//     exactly (a control-plane doc holding just payoutChangePending, never
//     money; an associate's real balance stays in the shared wallets/{uid}).
//   - On approval, the new destination is written using employees/{uid}'s
//     OWN existing field names (accountHolderName, ifscCode) — not
//     validatePayoutDetails()'s seller-shaped ones (accountHolder, ifsc) —
//     so employee_payout_detail_screen.dart (ADMR-3) and this same screen's
//     own read path keep working unchanged.
//
// Generation: v2 onCall, no secrets.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { Timestamp } from "firebase-admin/firestore";
import { resolveIsAdmin } from "../admin/complianceGate";
import { validatePayoutDetails, payoutDestination } from "../seller/sellerWallet";

type Db = FirebaseFirestore.Firestore;

// Exported so reviewEmployeePayout.ts (ADMR-3) can read this INSIDE its own
// payout transaction — never as a separate pre-check, which could race a
// brand-new pending request created between the check and the payout write.
export const employeeWalletRef = (db: Db, employeeId: string) => db.collection("employee_wallets").doc(employeeId);

export type ChangeVerdict = { kind: "requested"; id: string } | { kind: "refused"; reason: string };

export async function requestEmployeePayoutChangeCore(
  db: Db, employeeId: string, data: unknown, nowMs: number
): Promise<ChangeVerdict> {
  const v = validatePayoutDetails(data);
  if (!v.ok) return { kind: "refused", reason: `invalid_${v.error}` };
  const reqRef = db.collection("employee_payout_change_requests").doc();
  const walletRef = employeeWalletRef(db, employeeId);
  return db.runTransaction(async (tx): Promise<ChangeVerdict> => {
    const [emp, wallet] = await Promise.all([
      tx.get(db.collection("employees").doc(employeeId)),
      tx.get(walletRef),
    ]);
    if (!emp.exists) return { kind: "refused", reason: "not_an_employee" };
    const w = wallet.data() ?? {};
    if (typeof w.payoutChangePending === "string" && w.payoutChangePending) {
      return { kind: "refused", reason: "already_pending" };
    }
    const at = Timestamp.fromMillis(nowMs);
    tx.create(reqRef, {
      employeeId,
      payoutMethod: v.value.payoutMethod,
      accountHolder: v.value.accountHolder,
      bankName: v.value.bankName,
      accountNumber: v.value.accountNumber,
      ifsc: v.value.ifsc,
      upiId: v.value.upiId,
      previous: payoutDestination(emp.data()),
      status: "pending",
      createdAt: at,
      updatedAt: at,
    });
    tx.set(walletRef, { employeeId, payoutChangePending: reqRef.id, updatedAt: at }, { merge: true });
    return { kind: "requested", id: reqRef.id };
  });
}

export type ChangeReviewVerdict =
  | { kind: "approved" | "rejected" | "cancelled"; employeeId: string }
  | { kind: "refused"; reason: string };

export async function reviewEmployeePayoutChangeCore(
  db: Db,
  actor: { adminUid?: string; employeeId?: string },
  requestId: string,
  approve: boolean,
  reason: string | null,
  nowMs: number
): Promise<ChangeReviewVerdict> {
  const byAdmin = typeof actor.adminUid === "string";
  if (byAdmin && !approve && (!reason || reason.length < 3 || reason.length > 200)) {
    return { kind: "refused", reason: "reason_required" };
  }
  const reqRef = db.collection("employee_payout_change_requests").doc(requestId);
  return db.runTransaction(async (tx): Promise<ChangeReviewVerdict> => {
    const req = await tx.get(reqRef);
    if (!req.exists) return { kind: "refused", reason: "not_found" };
    const r = req.data()!;
    const employeeId = String(r.employeeId);
    if (!byAdmin && employeeId !== actor.employeeId) return { kind: "refused", reason: "not_yours" };
    if (r.status !== "pending") return { kind: "refused", reason: "not_pending" };

    const walletRef = employeeWalletRef(db, employeeId);
    const wallet = await tx.get(walletRef);
    const at = Timestamp.fromMillis(nowMs);
    const outcome: "approved" | "rejected" | "cancelled" = !byAdmin ? "cancelled" : approve ? "approved" : "rejected";

    tx.update(reqRef, {
      status: outcome,
      updatedAt: at,
      ...(byAdmin
        ? { reviewedBy: actor.adminUid, reviewedAt: at, rejectionReason: approve ? null : reason }
        : { cancelledAt: at }),
    });

    if (outcome === "approved") {
      // employees/{uid}'s OWN field names — see this file's header.
      tx.update(db.collection("employees").doc(employeeId), {
        payoutMethod: r.payoutMethod,
        accountHolderName: r.accountHolder ?? null,
        bankName: r.bankName ?? null,
        accountNumber: r.accountNumber ?? null,
        ifscCode: r.ifsc ?? null,
        upiId: r.upiId ?? null,
        payoutAccountUpdatedAt: at,
        payoutAccountVerifiedBy: actor.adminUid,
      });
    }
    if (wallet.data()?.payoutChangePending === requestId) {
      tx.set(walletRef, { payoutChangePending: null, updatedAt: at }, { merge: true });
    }
    return { kind: outcome, employeeId };
  });
}

async function requireAdmin(request: { auth?: { uid: string; token: Record<string, unknown> } }): Promise<string> {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required");
  const ok = await resolveIsAdmin(admin.firestore(), request.auth.uid, request.auth.token.admin === true);
  if (!ok) throw new HttpsError("permission-denied", "Admins only");
  return request.auth.uid;
}

const REFUSAL_TEXT: Record<string, string> = {
  not_an_employee: "Only an approved associate can do this",
  already_pending: "A bank/UPI change is already waiting for review",
  not_found: "Not found",
  not_pending: "This request has already been reviewed",
  not_yours: "Not your request",
  reason_required: "Give a reason (3–200 characters)",
};
function refuse(reason: string): never {
  const message = REFUSAL_TEXT[reason] ?? (reason.startsWith("invalid_") ? `Check the ${reason.slice(8)} field` : "Not possible");
  throw new HttpsError(reason === "not_found" ? "not-found" : "failed-precondition", message, { reason });
}
const str = (v: unknown) => (typeof v === "string" ? v.trim() : "");
const opts = { minInstances: 0, memory: "256MiB" as const };

export const requestEmployeePayoutChange = onCall(opts, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required");
  const v = await requestEmployeePayoutChangeCore(admin.firestore(), request.auth.uid, request.data, Date.now());
  if (v.kind === "refused") refuse(v.reason);
  return { success: true, requestId: v.id };
});

export const cancelEmployeePayoutChange = onCall(opts, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required");
  const id = str((request.data ?? {}).requestId);
  if (!id) throw new HttpsError("invalid-argument", "requestId is required");
  const v = await reviewEmployeePayoutChangeCore(admin.firestore(), { employeeId: request.auth.uid }, id, false, null, Date.now());
  if (v.kind === "refused") refuse(v.reason);
  return { success: true, status: v.kind };
});

export const reviewEmployeePayoutChange = onCall(opts, async (request) => {
  const adminUid = await requireAdmin(request as never);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const id = str(d.requestId);
  if (!id) throw new HttpsError("invalid-argument", "requestId is required");
  const approve = d.approve === true;
  const reason = str(d.reason) || null;
  const v = await reviewEmployeePayoutChangeCore(admin.firestore(), { adminUid }, id, approve, reason, Date.now());
  if (v.kind === "refused") refuse(v.reason);
  return { success: true, status: v.kind };
});
