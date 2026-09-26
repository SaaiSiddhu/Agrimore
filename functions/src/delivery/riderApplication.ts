// ============================================================
//  Callable: submitRiderApplication (Phase DLV-A1)
// ============================================================
//
// The rider app's registration used to create the Auth account, upload four
// KYC photos, then write users/{uid} and delivery_partners/{uid} from the
// client in two separate writes — trimming the password, naming the user
// "<name> Partner", storing token-bearing download URLs for Aadhaar and the
// licence, and deleting the Auth account if anything after it failed.
//
// Now (same shape as submitSellerApplication):
//   1. the app creates the Auth account once (a retry reuses it; the account
//      is never deleted as "compensation");
//   2. it uploads the photos to fixed paths under delivery_documents/{uid}/
//      (a retry overwrites; storage.rules freeze them once approved);
//   3. it calls this, which re-validates every field, confirms each photo
//      exists, is an image and within the size limit, and writes users/{uid}
//      and delivery_partners/{uid} in ONE transaction — status 'pending',
//      storage PATHS (the admin app resolves them at view time), never URLs.
// Resubmitting while pending or after a rejection updates the same record
// (back to pending); an approved, suspended or deactivated rider cannot
// resubmit. Only an account with no role yet, or already a delivery partner,
// may register — a customer, seller or admin account keeps its role.
//
// Generation: v2 onCall, no secrets. Modular Firestore imports (emulator-safe).

import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";

if (admin.apps.length === 0) admin.initializeApp();

type Db = FirebaseFirestore.Firestore;

export const RIDER_DOCUMENTS = ["aadhaarFront", "aadhaarBack", "selfie", "license"] as const;
export type RiderDocument = typeof RIDER_DOCUMENTS[number];

/** The fixed object path of one KYC photo. */
export const riderDocumentPath = (uid: string, doc: RiderDocument) => `delivery_documents/${uid}/${doc}`;

/** Same bound as storage.rules isValidFileSize(). */
export const MAX_DOCUMENT_BYTES = 10 * 1024 * 1024;

/** VehicleType wire values (packages/agrimore_core delivery_enums.dart). */
export const VEHICLE_TYPES = ["bicycle", "bike", "scooter", "ev", "three_wheeler", "car", "van"] as const;

const PHONE = /^[6-9]\d{9}$/;
const AADHAAR = /^[2-9]\d{11}$/;
const PINCODE = /^[1-9]\d{5}$/;
const IFSC = /^[A-Z]{4}0[A-Z0-9]{6}$/;
const ACCOUNT = /^\d{9,18}$/;
const UPI = /^[a-zA-Z0-9._-]{2,256}@[a-zA-Z]{2,64}$/;
export const VEHICLE_NO = /^[A-Z0-9]{4,12}$/;
const LICENCE_NO = /^[A-Z0-9-]{6,20}$/;

/** Statuses from which a rider may (re)submit. */
const RESUBMITTABLE = new Set(["pending", "rejected"]);

const str = (v: unknown) => (typeof v === "string" ? v.trim() : "");
const text = (v: unknown, min: number, max: number) => {
  const s = str(v);
  return s.length >= min && s.length <= max ? s : null;
};
/** "+91 98765-43210" → "9876543210". */
export const normPhone = (v: unknown) => str(v).replace(/[\s-]/g, "").replace(/^(\+91|0091|91(?=\d{10}$)|0(?=\d{10}$))/, "");
const upper = (v: unknown) => str(v).replace(/[\s-]/g, "").toUpperCase();

export type RiderApplication = {
  name: string;
  phone: string;
  altPhone: string | null;
  vehicleType: string;
  vehicleNumber: string | null;
  licenseNumber: string;
  aadhaarNumber: string;
  address: string;
  city: string;
  pincode: string;
  accountHolderName: string | null;
  bankAccountNumber: string | null;
  ifscCode: string | null;
  upiId: string | null;
};

/**
 * Every problem with an application as stable field keys (the app maps them
 * to localised copy); the cleaned application when there are none. Pure.
 */
export function validateRiderApplication(d: Record<string, unknown>):
  { problems: string[]; application: RiderApplication | null } {
  const problems: string[] = [];
  const name = text(d.name, 2, 80);
  if (!name) problems.push("name");
  const phone = normPhone(d.phone);
  if (!PHONE.test(phone)) problems.push("phone");
  const alt = d.altPhone === undefined || d.altPhone === null || str(d.altPhone) === "" ? null : normPhone(d.altPhone);
  if (alt !== null && (!PHONE.test(alt) || alt === phone)) problems.push("altPhone");
  const vehicleType = str(d.vehicleType).toLowerCase();
  if (!(VEHICLE_TYPES as readonly string[]).includes(vehicleType)) problems.push("vehicleType");
  // A registration number for every motor vehicle; none for a bicycle.
  const vehicleNumber = upper(d.vehicleNumber);
  const needsPlate = vehicleType !== "bicycle";
  if (needsPlate && !VEHICLE_NO.test(vehicleNumber)) problems.push("vehicleNumber");
  // Current policy (unchanged by this phase): a driving licence for every
  // rider. Whether bicycle riders need one is an open owner decision.
  const licenseNumber = upper(d.licenseNumber);
  if (!LICENCE_NO.test(licenseNumber)) problems.push("licenseNumber");
  const aadhaar = str(d.aadhaarNumber).replace(/[\s-]/g, "");
  if (!AADHAAR.test(aadhaar)) problems.push("aadhaarNumber");
  const address = text(d.address, 5, 300);
  if (!address) problems.push("address");
  const city = text(d.city, 2, 60);
  if (!city) problems.push("city");
  const pincode = str(d.pincode);
  if (!PINCODE.test(pincode)) problems.push("pincode");

  // Payout details are optional here (the rider can add them later through
  // the reviewed bank-change flow); if any bank field is given, all must be.
  const holder = str(d.accountHolderName), account = str(d.bankAccountNumber).replace(/\s/g, ""), ifsc = upper(d.ifscCode);
  const anyBank = holder !== "" || account !== "" || ifsc !== "";
  if (anyBank) {
    if (!text(holder, 2, 80)) problems.push("accountHolderName");
    if (!ACCOUNT.test(account)) problems.push("bankAccountNumber");
    if (!IFSC.test(ifsc)) problems.push("ifscCode");
  }
  const upi = str(d.upiId);
  if (upi !== "" && !UPI.test(upi)) problems.push("upiId");

  if (problems.length) return { problems, application: null };
  return {
    problems,
    application: {
      name: name!, phone, altPhone: alt, vehicleType,
      vehicleNumber: needsPlate ? vehicleNumber : (vehicleNumber || null),
      licenseNumber, aadhaarNumber: aadhaar, address: address!, city: city!, pincode,
      accountHolderName: anyBank ? holder : null,
      bankAccountNumber: anyBank ? account : null,
      ifscCode: anyBank ? ifsc : null,
      upiId: upi || null,
    },
  };
}

/** One uploaded object's metadata, or null if absent. */
export type ObjectInfo = { size: number; contentType: string } | null;
export type ObjectLookup = (path: string) => Promise<ObjectInfo>;

export const storageLookup: ObjectLookup = async (path) => {
  const file = admin.storage().bucket().file(path);
  const [exists] = await file.exists();
  if (!exists) return null;
  const [meta] = await file.getMetadata();
  return { size: Number(meta.size ?? 0), contentType: String(meta.contentType ?? "") };
};

/** Problems with the uploaded photos (missing, not an image, too large). */
export async function checkDocuments(uid: string, lookup: ObjectLookup): Promise<string[]> {
  const problems: string[] = [];
  for (const doc of RIDER_DOCUMENTS) {
    const info = await lookup(riderDocumentPath(uid, doc));
    if (!info || !info.contentType.startsWith("image/") || info.size <= 0 || info.size >= MAX_DOCUMENT_BYTES) {
      problems.push(`documents.${doc}`);
    }
  }
  return problems;
}

export type SubmitVerdict =
  | { kind: "submitted"; resubmitted: boolean }
  | { kind: "refused"; reason: "invalid" | "documents" | "already_registered" | "other_account_role"; problems?: string[] };

export async function submitRiderApplicationCore(
  db: Db, uid: string, email: string | null, data: unknown, lookup: ObjectLookup
): Promise<SubmitVerdict> {
  const { problems, application } = validateRiderApplication((data ?? {}) as Record<string, unknown>);
  if (!application) return { kind: "refused", reason: "invalid", problems };
  const missing = await checkDocuments(uid, lookup);
  if (missing.length) return { kind: "refused", reason: "documents", problems: missing };

  const userRef = db.collection("users").doc(uid);
  const partnerRef = db.collection("delivery_partners").doc(uid);
  return db.runTransaction(async (tx): Promise<SubmitVerdict> => {
    const [user, partner] = await Promise.all([tx.get(userRef), tx.get(partnerRef)]);
    const role = user.data()?.role;
    if (user.exists && role !== undefined && role !== null && role !== "delivery_partner") {
      return { kind: "refused", reason: "other_account_role" };
    }
    const status = partner.data()?.status;
    const resubmitted = partner.exists;
    if (partner.exists && !RESUBMITTABLE.has(String(status ?? "pending"))) {
      return { kind: "refused", reason: "already_registered" };
    }
    const now = FieldValue.serverTimestamp();
    const documents = Object.fromEntries(RIDER_DOCUMENTS.map((d) => [d, riderDocumentPath(uid, d)]));

    tx.set(userRef, {
      uid,
      email: email ?? user.data()?.email ?? null,
      name: application.name,
      phone: application.phone,
      role: "delivery_partner",
      ...(user.exists ? {} : { createdAt: now }),
      updatedAt: now,
    }, { merge: true });

    tx.set(partnerRef, {
      id: uid,
      name: application.name,
      phone: application.phone,
      altPhone: application.altPhone,
      vehicleType: application.vehicleType,
      vehicleNumber: application.vehicleNumber,
      licenseNumber: application.licenseNumber,
      aadhaarNumber: application.aadhaarNumber,
      address: application.address,
      city: application.city,
      pincode: application.pincode,
      accountHolderName: application.accountHolderName,
      bankAccountNumber: application.bankAccountNumber,
      ifscCode: application.ifscCode,
      upiId: application.upiId,
      // KYC by storage path; the legacy URL fields are cleared so a
      // resubmission never leaves an old public URL behind.
      kycDocuments: documents,
      aadhaarFrontImage: FieldValue.delete(),
      aadhaarBackImage: FieldValue.delete(),
      selfieImage: FieldValue.delete(),
      licenseImage: FieldValue.delete(),
      photoUrl: FieldValue.delete(),
      status: "pending",
      isOnline: false,
      submittedAt: now,
      ...(resubmitted
        ? { resubmissionCount: FieldValue.increment(1), previousStatus: status ?? null }
        : { createdAt: now }),
      updatedAt: now,
    }, { merge: true });
    return { kind: "submitted", resubmitted };
  });
}

const REFUSALS: Record<string, [HttpsError["code"], string]> = {
  invalid: ["invalid-argument", "Some details are missing or invalid"],
  documents: ["invalid-argument", "Some documents did not finish uploading"],
  already_registered: ["failed-precondition", "This account is already registered"],
  other_account_role: ["permission-denied", "This account is used for another Agrimore app"],
};

export const submitRiderApplication = onCall({ minInstances: 0, memory: "256MiB" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required");
  const v = await submitRiderApplicationCore(
    admin.firestore(), request.auth.uid, request.auth.token.email ?? null, request.data, storageLookup);
  if (v.kind === "refused") {
    const [code, message] = REFUSALS[v.reason];
    throw new HttpsError(code, message, { reason: v.reason, problems: v.problems ?? [] });
  }
  // No personal data in logs.
  console.log(`[submitRiderApplication] ${request.auth.uid} ${v.resubmitted ? "resubmitted" : "submitted"}`);
  return { status: "pending", resubmitted: v.resubmitted };
});
