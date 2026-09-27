// ============================================================
//  Per-document review status (Phase DLVDOC2)
// ============================================================
//
// Distinct from the whole-application status (riderApplication.ts /
// rider_review.dart's RiderReviewAction) and from identity/vehicle field
// changes (riderIdentity.ts): this is a rider correcting or replacing one
// of the four existing KYC document photos (RIDER_DOCUMENTS) after their
// application has already been decided, without that correction implicitly
// changing whether they can currently work -- that remains a separate,
// undecided policy question, not touched here.
//
// Modelled directly on riderIdentity.ts's own request/review shape: a
// top-level collection, Admin-SDK-only mutation, a *Pending field on
// delivery_partners blocking a second in-flight submission for the same
// document. The one real difference is the staged file: a rider approved
// (or suspended) cannot write directly to delivery_documents/{uid}/{docType}
// (storage.rules' own riderKycEditable is a deliberate fraud-prevention
// gate this phase does not loosen) -- so the client instead uploads to a
// separate, always-writable staging path, and only an admin's approval,
// executed here with the Admin SDK, promotes it onto the live path.
import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { resolveIsAdmin } from "../admin/complianceGate";
import { documentReviewNotice, tellRider } from "./riderNotices";
import { RIDER_DOCUMENTS, RiderDocument, riderDocumentPath, MAX_DOCUMENT_BYTES, ObjectLookup, storageLookup } from "./riderApplication";

type Db = FirebaseFirestore.Firestore;

export const stagingPath = (uid: string, submissionId: string) => `delivery_document_submissions/${uid}/${submissionId}`;

/** Copies one Storage object onto another path. Injectable so tests never touch real Storage. */
export type ObjectCopy = (src: string, dest: string) => Promise<void>;
export const storageCopy: ObjectCopy = async (src, dest) => {
  await admin.storage().bucket().file(src).copy(admin.storage().bucket().file(dest));
};

const SUBMISSION_ID = /^[A-Za-z0-9_-]{6,64}$/;

export type SubmitReplacementVerdict = { kind: "submitted"; id: string } | { kind: "refused"; reason: string };

/** Blocks a second submission for the SAME document while one is pending, exactly like identity changes. */
export async function submitDocumentReplacementCore(
  db: Db, riderId: string, data: unknown, lookup: ObjectLookup, nowMs: number
): Promise<SubmitReplacementVerdict> {
  const d = (data ?? {}) as Record<string, unknown>;
  const docType = typeof d.docType === "string" ? d.docType.trim() : "";
  if (!(RIDER_DOCUMENTS as readonly string[]).includes(docType)) return { kind: "refused", reason: "invalid_docType" };
  const submissionId = typeof d.submissionId === "string" ? d.submissionId.trim() : "";
  if (!SUBMISSION_ID.test(submissionId)) return { kind: "refused", reason: "invalid_submissionId" };

  // Never trust the client's own claim that it uploaded something.
  const path = stagingPath(riderId, submissionId);
  const info = await lookup(path);
  if (!info || !info.contentType.startsWith("image/") || info.size <= 0 || info.size >= MAX_DOCUMENT_BYTES) {
    return { kind: "refused", reason: "upload_missing" };
  }

  const partnerRef = db.collection("delivery_partners").doc(riderId);
  const subRef = db.collection("document_review_submissions").doc(submissionId);
  return db.runTransaction(async (tx): Promise<SubmitReplacementVerdict> => {
    const partner = await tx.get(partnerRef);
    if (!partner.exists) return { kind: "refused", reason: "not_a_rider" };
    const p = partner.data() ?? {};
    const pending = (p.documentReviewPending ?? {}) as Record<string, unknown>;
    if (typeof pending[docType] === "string" && pending[docType]) {
      return { kind: "refused", reason: "already_pending" };
    }
    const existing = await tx.get(subRef);
    if (existing.exists) return { kind: "refused", reason: "duplicate_submission" };
    const at = Timestamp.fromMillis(nowMs);
    tx.create(subRef, {
      riderId, docType, stagingPath: path, status: "pending",
      submittedAt: at, reviewedAt: null, reviewedBy: null, rejectionReason: null,
    });
    // tx.update() (not set-with-merge, riderSteps.ts's own evidenceFields
    // precedent) interprets a dotted string key as a nested field path,
    // touching just this one key of the map rather than the whole field.
    tx.update(partnerRef, {
      [`documentReviewPending.${docType}`]: submissionId,
      [`documentReview.${docType}`]: { status: "pending", submissionId },
      updatedAt: at,
    });
    return { kind: "submitted", id: submissionId };
  });
}

export type ReviewSubmissionVerdict =
  | { kind: "approved" | "rejected" }
  | { kind: "refused"; reason: "not_found" | "not_pending" | "reason_required" };

/**
 * Approval copies the staged file onto the fixed live path BEFORE any
 * Firestore state changes -- if the copy fails, nothing here is left
 * inconsistent (the submission stays pending, safe to retry). The
 * Firestore write then re-checks `pending` status inside its own
 * transaction, so a genuine concurrent double-review still lands exactly
 * one verdict (the second reviewer sees not_pending and is refused, even
 * though an already-idempotent copy may have run twice).
 */
export async function reviewDocumentSubmissionCore(
  db: Db, adminUid: string, submissionId: string, approve: boolean, reason: string | null, copy: ObjectCopy, nowMs: number
): Promise<ReviewSubmissionVerdict> {
  if (!approve && (!reason || reason.length < 3 || reason.length > 200)) return { kind: "refused", reason: "reason_required" };

  const subRef = db.collection("document_review_submissions").doc(submissionId);
  const sub = await subRef.get();
  if (!sub.exists) return { kind: "refused", reason: "not_found" };
  const s = sub.data()!;
  if (s.status !== "pending") return { kind: "refused", reason: "not_pending" };
  const riderId = s.riderId as string;
  const docType = s.docType as RiderDocument;

  if (approve) await copy(s.stagingPath as string, riderDocumentPath(riderId, docType));

  return db.runTransaction(async (tx): Promise<ReviewSubmissionVerdict> => {
    const fresh = await tx.get(subRef);
    if (!fresh.exists) return { kind: "refused", reason: "not_found" };
    const fs = fresh.data()!;
    if (fs.status !== "pending") return { kind: "refused", reason: "not_pending" };
    const partnerRef = db.collection("delivery_partners").doc(riderId);
    const at = Timestamp.fromMillis(nowMs);
    tx.update(subRef, {
      status: approve ? "approved" : "rejected",
      reviewedBy: adminUid, reviewedAt: at,
      rejectionReason: approve ? null : reason,
    });
    // Same tx.update()-for-dotted-keys reasoning as submitDocumentReplacementCore.
    tx.update(partnerRef, {
      [`documentReviewPending.${docType}`]: FieldValue.delete(),
      [`documentReview.${docType}`]: approve ? { status: "approved", submissionId } : { status: "rejected", submissionId, rejectionReason: reason },
      updatedAt: at,
    });
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
  already_pending: "A replacement for this document is already waiting for review",
  duplicate_submission: "This submission was already recorded",
  upload_missing: "Upload the photo before submitting",
  not_a_rider: "Only delivery partners can replace documents",
  not_found: "Submission not found",
  not_pending: "This submission has already been reviewed",
  reason_required: "Give a reason for rejecting (3-200 characters)",
};
function refuse(reason: string): never {
  const message = REFUSAL_TEXT[reason] ?? (reason.startsWith("invalid_") ? `Check the ${reason.slice(8)} field` : "Not possible");
  throw new HttpsError(reason === "not_found" ? "not-found" : "failed-precondition", message, { reason });
}

export const submitDocumentReplacement = onCall({ minInstances: 0, memory: "256MiB" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required");
  const v = await submitDocumentReplacementCore(admin.firestore(), request.auth.uid, request.data, storageLookup, Date.now());
  if (v.kind === "refused") refuse(v.reason);
  return { success: true, submissionId: v.id };
});

export const reviewDocumentSubmission = onCall({ minInstances: 0, memory: "256MiB" }, async (request) => {
  const adminUid = await requireAdmin(request as never);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const submissionId = typeof d.submissionId === "string" ? d.submissionId.trim() : "";
  if (!submissionId) throw new HttpsError("invalid-argument", "submissionId is required");
  const v = await reviewDocumentSubmissionCore(
    admin.firestore(), adminUid, submissionId, d.approve === true,
    typeof d.reason === "string" ? d.reason.trim() : null, storageCopy, Date.now()
  );
  if (v.kind === "refused") refuse(v.reason);
  const db = admin.firestore();
  const s = (await db.collection("document_review_submissions").doc(submissionId).get()).data() ?? {};
  await tellRider(
    db, typeof s.riderId === "string" ? s.riderId : null,
    documentReviewNotice(
      submissionId,
      typeof s.docType === "string" ? s.docType : "",
      v.kind === "approved",
      typeof s.rejectionReason === "string" ? s.rejectionReason : null
    ),
    Date.now()
  );
  return { success: true, status: v.kind };
});
