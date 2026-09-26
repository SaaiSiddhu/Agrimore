// ============================================================
//  Rider identity change requests (Phase DLVID1)
// ============================================================
//
// A rider's locked identity fields (name, phone, vehicle, licence, Aadhaar)
// have never had any change mechanism at all — the profile screen showed
// them read-only with a static "contact support" line. Modelled directly on
// rider_bank_change_requests (riderMoney.ts's requestBankChangeCore /
// reviewBankChangeCore, firestore.rules' identical read-owner-or-admin /
// write-false shape): a request is created pending, a second request is
// blocked while one is already pending (a field on delivery_partners, not a
// query), review sets approved/rejected + reviewedBy/reviewedAt/
// rejectionReason, approval writes the real field, and the rider is told
// either way via riderNotices.ts's tellRider.
//
// Only "name" is offered: delivery_partners (riderApplication.ts) has no
// dateOfBirth field at all, and the profile screen has never displayed one
// — the mockup's own "Date of birth" change type does not correspond to
// anything real to change. Inventing that field would be a genuine
// product/schema decision (does the business need to collect DOB, and
// why), out of proportion for this phase; flagged for the owner instead.
import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { Timestamp } from "firebase-admin/firestore";
import { resolveIsAdmin } from "../admin/complianceGate";
import { identityChangeNotice, tellRider } from "./riderNotices";

type Db = FirebaseFirestore.Firestore;

export const RIDER_IDENTITY_CHANGE_TYPES = ["name"] as const;
export type RiderIdentityChangeType = (typeof RIDER_IDENTITY_CHANGE_TYPES)[number];

function validateIdentityChange(data: unknown):
  | { ok: true; value: { changeType: RiderIdentityChangeType; proposedValue: string; reason: string } }
  | { ok: false; error: string } {
  const d = (data ?? {}) as Record<string, unknown>;
  const changeType = typeof d.changeType === "string" ? d.changeType.trim() : "";
  if (!(RIDER_IDENTITY_CHANGE_TYPES as readonly string[]).includes(changeType)) return { ok: false, error: "changeType" };
  const proposedValue = typeof d.proposedValue === "string" ? d.proposedValue.trim() : "";
  if (proposedValue.length < 2 || proposedValue.length > 100) return { ok: false, error: "proposedValue" };
  const reason = typeof d.reason === "string" ? d.reason.trim() : "";
  if (reason.length < 3 || reason.length > 250) return { ok: false, error: "reason" };
  return { ok: true, value: { changeType: changeType as RiderIdentityChangeType, proposedValue, reason } };
}

export type IdentityRequestVerdict = { kind: "requested"; id: string } | { kind: "refused"; reason: string };

/** Blocks a second request while one is pending, exactly like bank changes. */
export async function requestIdentityChangeCore(
  db: Db, riderId: string, data: unknown, nowMs: number
): Promise<IdentityRequestVerdict> {
  const v = validateIdentityChange(data);
  if (!v.ok) return { kind: "refused", reason: `invalid_${v.error}` };
  const partnerRef = db.collection("delivery_partners").doc(riderId);
  const reqRef = db.collection("rider_identity_change_requests").doc();
  return db.runTransaction(async (tx): Promise<IdentityRequestVerdict> => {
    const partner = await tx.get(partnerRef);
    if (!partner.exists) return { kind: "refused", reason: "not_a_rider" };
    const p = partner.data() ?? {};
    if (typeof p.identityChangePending === "string" && p.identityChangePending) {
      return { kind: "refused", reason: "already_pending" };
    }
    const at = Timestamp.fromMillis(nowMs);
    tx.create(reqRef, {
      riderId,
      changeType: v.value.changeType,
      currentValue: p[v.value.changeType] ?? null,
      proposedValue: v.value.proposedValue,
      reason: v.value.reason,
      status: "pending",
      createdAt: at,
      updatedAt: at,
    });
    tx.set(partnerRef, { identityChangePending: reqRef.id, updatedAt: at }, { merge: true });
    return { kind: "requested", id: reqRef.id };
  });
}

export type IdentityReviewVerdict =
  | { kind: "approved" | "rejected" }
  | { kind: "refused"; reason: "not_found" | "not_pending" | "reason_required" };

export async function reviewIdentityChangeCore(
  db: Db, adminUid: string, requestId: string, approve: boolean, reason: string | null, nowMs: number
): Promise<IdentityReviewVerdict> {
  if (!approve && (!reason || reason.length < 3 || reason.length > 200)) return { kind: "refused", reason: "reason_required" };
  const reqRef = db.collection("rider_identity_change_requests").doc(requestId);
  return db.runTransaction(async (tx): Promise<IdentityReviewVerdict> => {
    const req = await tx.get(reqRef);
    if (!req.exists) return { kind: "refused", reason: "not_found" };
    const r = req.data()!;
    if (r.status !== "pending") return { kind: "refused", reason: "not_pending" };
    const riderId = r.riderId as string;
    const partnerRef = db.collection("delivery_partners").doc(riderId);
    const at = Timestamp.fromMillis(nowMs);
    tx.update(reqRef, {
      status: approve ? "approved" : "rejected",
      reviewedBy: adminUid,
      reviewedAt: at,
      rejectionReason: approve ? null : reason,
      updatedAt: at,
    });
    const partnerUpdate: Record<string, unknown> = { identityChangePending: null, updatedAt: at };
    if (approve) partnerUpdate[r.changeType as string] = r.proposedValue;
    tx.set(partnerRef, partnerUpdate, { merge: true });
    return { kind: approve ? "approved" : "rejected" };
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
  already_pending: "A change is already waiting for review",
  not_found: "Request not found",
  not_pending: "This request has already been reviewed",
  reason_required: "Give a reason for rejecting (3–200 characters)",
  not_a_rider: "Only delivery partners can request identity changes",
};
function refuse(reason: string): never {
  const message = REFUSAL_TEXT[reason] ?? (reason.startsWith("invalid_") ? `Check the ${reason.slice(8)} field` : "Not possible");
  throw new HttpsError(reason === "not_found" ? "not-found" : "failed-precondition", message, { reason });
}

export const requestRiderIdentityChange = onCall({ minInstances: 0, memory: "256MiB" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required");
  const v = await requestIdentityChangeCore(admin.firestore(), request.auth.uid, request.data, Date.now());
  if (v.kind === "refused") refuse(v.reason);
  return { success: true, requestId: v.id };
});

export const reviewRiderIdentityChange = onCall({ minInstances: 0, memory: "256MiB" }, async (request) => {
  const adminUid = await requireAdmin(request as never);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const requestId = typeof d.requestId === "string" ? d.requestId.trim() : "";
  if (!requestId) throw new HttpsError("invalid-argument", "requestId is required");
  const v = await reviewIdentityChangeCore(
    admin.firestore(), adminUid, requestId, d.approve === true,
    typeof d.reason === "string" ? d.reason.trim() : null, Date.now()
  );
  if (v.kind === "refused") refuse(v.reason);
  const db = admin.firestore();
  const r = (await db.collection("rider_identity_change_requests").doc(requestId).get()).data() ?? {};
  await tellRider(
    db, typeof r.riderId === "string" ? r.riderId : null,
    identityChangeNotice(requestId, v.kind === "approved", typeof r.rejectionReason === "string" ? r.rejectionReason : null),
    Date.now()
  );
  return { success: true, status: v.kind };
});
