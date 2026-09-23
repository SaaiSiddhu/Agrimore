// ============================================================
//  Callable: submitSellerApplication (Phase SELLER-AUTH-1b)
// ============================================================
//
// ONE onboarding path (ADR-S12). The seller app saves the application as a
// `draft` in sellerRequests/{uid} step by step (firestore.rules: the owner can
// only ever write status == 'draft'). This callable is the ONLY way a draft
// becomes `pending`: it re-validates every field server-side, confirms the
// KYC photos really exist under the caller's own seller_documents/{uid}/
// folder, then flips the status. Approval stays an admin action
// (apps/admin seller_requests_management_screen.dart), which copies the
// payout fields into the private seller_payout_details/{uid} (FIX-2).
//
// Generation: v2 onCall, no secrets.

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

export const REQUIRED_DOCUMENTS = ["idProof", "shopPhoto"] as const;
export const OPTIONAL_DOCUMENTS = ["gstCertificate"] as const;

const IFSC = /^[A-Z]{4}0[A-Z0-9]{6}$/;
const UPI = /^[a-zA-Z0-9._-]{2,256}@[a-zA-Z]{2,64}$/;
const GSTIN = /^\d{2}[A-Z]{5}\d{4}[A-Z][1-9A-Z]Z[0-9A-Z]$/;
const PINCODE = /^[1-9]\d{5}$/;
const ACCOUNT = /^\d{9,18}$/;
const MAX_RADIUS_KM = 100;

function nonEmpty(v: unknown, min = 2, max = 200): boolean {
  return typeof v === "string" && v.trim().length >= min && v.trim().length <= max;
}

/**
 * Every problem with an application, as stable field keys (the app maps
 * them to localised copy). Empty array = ready to submit. Pure, so it is
 * unit-tested without an emulator.
 */
export function validateSellerApplication(d: Record<string, unknown>, uid: string): string[] {
  const problems: string[] = [];

  // Step 1 — business
  if (!nonEmpty(d.name)) problems.push("name");
  if (!nonEmpty(d.shopName)) problems.push("shopName");
  if (!nonEmpty(d.businessCategory)) problems.push("businessCategory");
  if (d.gstin !== undefined && d.gstin !== null && d.gstin !== "") {
    if (typeof d.gstin !== "string" || !GSTIN.test(d.gstin.toUpperCase())) problems.push("gstin");
  }

  // Step 2 — location & coverage
  if (!nonEmpty(d.shopAddress, 5, 400)) problems.push("shopAddress");
  if (!nonEmpty(d.city)) problems.push("city");
  if (!nonEmpty(d.state)) problems.push("state");
  if (typeof d.pincode !== "string" || !PINCODE.test(d.pincode)) problems.push("pincode");
  const radius = d.deliveryRadiusKm;
  if (typeof radius !== "number" || !Number.isFinite(radius) || radius <= 0 || radius > MAX_RADIUS_KM) {
    problems.push("deliveryRadiusKm");
  }

  // Step 3 — KYC documents: storage paths under the caller's own folder
  const docs = (d.documents ?? {}) as Record<string, unknown>;
  for (const key of REQUIRED_DOCUMENTS) {
    const path = docs[key];
    if (typeof path !== "string" || !path.startsWith(`seller_documents/${uid}/`)) problems.push(`documents.${key}`);
  }
  for (const key of OPTIONAL_DOCUMENTS) {
    const path = docs[key];
    if (path !== undefined && path !== null && path !== "" &&
        (typeof path !== "string" || !path.startsWith(`seller_documents/${uid}/`))) {
      problems.push(`documents.${key}`);
    }
  }

  // Step 4 — payout
  if (d.payoutMethod === "bank") {
    if (!nonEmpty(d.accountHolder)) problems.push("accountHolder");
    if (!nonEmpty(d.bankName)) problems.push("bankName");
    if (typeof d.accountNumber !== "string" || !ACCOUNT.test(d.accountNumber)) problems.push("accountNumber");
    if (typeof d.ifsc !== "string" || !IFSC.test(d.ifsc)) problems.push("ifsc");
  } else if (d.payoutMethod === "upi") {
    if (typeof d.upiId !== "string" || !UPI.test(d.upiId)) problems.push("upiId");
  } else {
    problems.push("payoutMethod");
  }

  if (d.acceptedTerms !== true) problems.push("acceptedTerms");
  return problems;
}

export const submitSellerApplication = onCall(
  { minInstances: 0, memory: "256MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required");
    }
    const uid = request.auth.uid;
    const db = admin.firestore();
    const ref = db.collection("sellerRequests").doc(uid);

    const snap = await ref.get();
    if (!snap.exists) {
      throw new HttpsError("not-found", "No application found. Start your application first.");
    }
    const data = snap.data()!;
    if (data.status === "pending") {
      return { status: "pending", alreadySubmitted: true };
    }
    if (data.status !== "draft") {
      throw new HttpsError("failed-precondition", `This application is ${data.status}.`);
    }
    if (data.userId !== uid) {
      throw new HttpsError("permission-denied", "This application belongs to another account.");
    }

    const problems = validateSellerApplication(data, uid);
    if (problems.length > 0) {
      throw new HttpsError("invalid-argument", "Some details are missing or invalid.", { problems });
    }

    // The KYC photos must really exist — a path alone proves nothing.
    const bucket = admin.storage().bucket();
    const docs = data.documents as Record<string, string>;
    const missing: string[] = [];
    for (const key of [...REQUIRED_DOCUMENTS, ...OPTIONAL_DOCUMENTS]) {
      const path = docs[key];
      if (!path) continue;
      const [exists] = await bucket.file(path).exists();
      if (!exists) missing.push(`documents.${key}`);
    }
    if (missing.length > 0) {
      throw new HttpsError("invalid-argument", "Some documents did not finish uploading.", { problems: missing });
    }

    const batch = db.batch();
    batch.update(ref, {
      status: "pending",
      appliedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    batch.set(db.collection("users").doc(uid), { sellerStatus: "pending" }, { merge: true });
    await batch.commit();

    return { status: "pending", alreadySubmitted: false };
  }
);
