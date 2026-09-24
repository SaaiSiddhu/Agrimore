// ============================================================
//  Delivery exceptions and proof of delivery (Phase DLV-E1)
// ============================================================
//
// PROOF. The rider app used to upload a photo under a new timestamped name,
// then — after confirmDelivery succeeded — write its download URL onto the
// order from the client, with nothing catching a failure: a failed write made
// a successful delivery look failed. Now the photo goes to ONE fixed object,
// delivery_proofs/{orderId}_proof (storage.rules: the assigned rider only,
// image, size-limited), and attachDeliveryProof checks that object and stores
// its PATH on the order. The path names the order, so a photo cannot be
// attached to another order; a retry overwrites the same object.
//
// EXCEPTIONS. After pickup a rider can report a failed attempt: customer
// unreachable or refused, wrong or unfindable address, a COD problem, damaged
// goods, a vehicle or safety issue. The report is a record in
// delivery_exceptions (never written by a client) with the rider's position
// evidence and custody "rider" (the rider still holds the goods). An admin
// acknowledges it, then resolves it as:
//   reattempt            the rider continues this delivery
//   returned_to_seller   the goods are back with the seller (custody seller)
// Resolving never changes the order's money: whether a failed or returned
// delivery is refunded, and whether the rider is still paid, is an OPEN OWNER
// DECISION. The admin changes the order itself (cancel, reassign) through the
// existing order tools, which this record points them to.
//
// Before pickup the rider uses releaseDeliveryOrder (seller not ready,
// vehicle, safety) — unchanged.
//
// Modular Firestore imports (functions-emulator safe).

import * as admin from "firebase-admin";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { resolveIsAdmin } from "../admin/complianceGate";
import { parseFix } from "./riderSteps";

if (admin.apps.length === 0) admin.initializeApp();

type Db = FirebaseFirestore.Firestore;

export const proofPath = (orderId: string) => `delivery_proofs/${orderId}_proof`;
export const MAX_PROOF_BYTES = 10 * 1024 * 1024;
/** A proof may be attached this long after delivery (a retry later is refused). */
export const PROOF_WINDOW_MS = 24 * 60 * 60 * 1000;

/** Rider exception reasons after pickup (DeliveryFailureReason wire values). */
export const EXCEPTION_REASONS = [
  "customer_unreachable", "customer_refused", "wrong_address", "address_not_found",
  "payment_issue", "damaged_goods", "vehicle_issue", "safety", "other",
] as const;

/** Order statuses in which the rider holds the goods (after pickup). */
export const AFTER_PICKUP_STATUSES = ["picked_up", "parcel_picked", "out_for_delivery", "outfordelivery", "outForDelivery"];

const REQUEST_ID = /^[A-Za-z0-9_-]{8,64}$/;
const MAX_NOTE = 500;

const millis = (v: unknown): number | null =>
  v instanceof Timestamp ? v.toMillis()
    : v && typeof (v as { toMillis?: unknown }).toMillis === "function" ? (v as { toMillis: () => number }).toMillis() : null;

export type ObjectInfo = { size: number; contentType: string } | null;
export type ObjectLookup = (path: string) => Promise<ObjectInfo>;

export const storageLookup: ObjectLookup = async (path) => {
  const file = admin.storage().bucket().file(path);
  const [exists] = await file.exists();
  if (!exists) return null;
  const [meta] = await file.getMetadata();
  return { size: Number(meta.size ?? 0), contentType: String(meta.contentType ?? "") };
};

// ── Proof ───────────────────────────────────────────────────

export type ProofVerdict =
  | { kind: "attached" | "already"; path: string }
  | { kind: "refused"; reason: "not_found" | "not_assigned" | "not_delivered" | "too_late" | "no_photo" | "not_image" | "too_large" };

export async function attachProofCore(db: Db, uid: string, orderId: string, lookup: ObjectLookup, nowMs: number): Promise<ProofVerdict> {
  const ref = db.collection("orders").doc(orderId);
  const snap = await ref.get();
  if (!snap.exists) return { kind: "refused", reason: "not_found" };
  const o = snap.data()!;
  if (o.deliveryPartnerId !== uid) return { kind: "refused", reason: "not_assigned" };
  const delivered = String(o.orderStatus ?? "").toLowerCase() === "delivered" || String(o.status ?? "").toLowerCase() === "delivered";
  if (!delivered) return { kind: "refused", reason: "not_delivered" };
  const path = proofPath(orderId);
  if (o.deliveryProofPath === path) return { kind: "already", path };
  const at = millis(o.deliveredAt);
  if (at !== null && nowMs - at > PROOF_WINDOW_MS) return { kind: "refused", reason: "too_late" };
  const info = await lookup(path);
  if (!info) return { kind: "refused", reason: "no_photo" };
  if (!info.contentType.startsWith("image/")) return { kind: "refused", reason: "not_image" };
  if (info.size <= 0 || info.size >= MAX_PROOF_BYTES) return { kind: "refused", reason: "too_large" };
  await ref.update({
    deliveryProofPath: path,
    deliveryProofAttachedAt: Timestamp.fromMillis(nowMs),
    deliveryProofAttachedBy: uid,
  });
  return { kind: "attached", path };
}

// ── Exceptions ──────────────────────────────────────────────

export type ReportVerdict =
  | { kind: "reported" | "already"; exceptionId: string }
  | { kind: "refused"; reason: "bad_request" | "not_found" | "not_assigned" | "not_after_pickup" | "open_exception" };

export async function reportExceptionCore(db: Db, uid: string, data: unknown, nowMs: number): Promise<ReportVerdict> {
  const d = (data ?? {}) as Record<string, unknown>;
  const orderId = typeof d.orderId === "string" ? d.orderId.trim() : "";
  const requestId = typeof d.requestId === "string" ? d.requestId : "";
  const reason = typeof d.reason === "string" ? d.reason : "";
  const note = d.note === undefined || d.note === null ? "" : typeof d.note === "string" ? d.note.trim() : null;
  if (!orderId || !REQUEST_ID.test(requestId) || !(EXCEPTION_REASONS as readonly string[]).includes(reason) ||
      note === null || note.length > MAX_NOTE) {
    return { kind: "refused", reason: "bad_request" };
  }
  const exceptionId = `${orderId}_${requestId}`;
  const exRef = db.collection("delivery_exceptions").doc(exceptionId);
  const orderRef = db.collection("orders").doc(orderId);
  const fix = parseFix(d);
  return db.runTransaction(async (tx): Promise<ReportVerdict> => {
    const [ex, order] = await Promise.all([tx.get(exRef), tx.get(orderRef)]);
    if (ex.exists) return { kind: "already", exceptionId };
    if (!order.exists) return { kind: "refused", reason: "not_found" };
    const o = order.data()!;
    if (o.deliveryPartnerId !== uid) return { kind: "refused", reason: "not_assigned" };
    if (!AFTER_PICKUP_STATUSES.includes(String(o.orderStatus ?? ""))) return { kind: "refused", reason: "not_after_pickup" };
    const open = o.openDeliveryException;
    if (open && typeof open === "object" && typeof open.id === "string") return { kind: "refused", reason: "open_exception" };
    const at = Timestamp.fromMillis(nowMs);
    tx.create(exRef, {
      exceptionId, orderId, orderNumber: o.orderNumber ?? null, riderId: uid,
      sellerId: o.sellerId ?? null, customerId: o.userId ?? null,
      reason, note: note || null,
      orderStatusAtReport: o.orderStatus ?? null,
      paymentMethod: o.paymentMethod ?? null,
      location: fix ? { lat: fix.lat, lng: fix.lng, accuracy: fix.accuracy, isMocked: fix.isMocked, at } : null,
      custody: "rider",
      status: "reported",
      disposition: null, resolution: null,
      createdAt: at, updatedAt: at,
      acknowledgedAt: null, acknowledgedBy: null, resolvedAt: null, resolvedBy: null,
    });
    tx.update(orderRef, {
      openDeliveryException: { id: exceptionId, reason, at },
      updatedAt: FieldValue.serverTimestamp(),
    });
    const timeline = orderRef.collection("timeline").doc();
    tx.set(timeline, {
      id: timeline.id, status: "delivery_problem", title: "Delivery problem reported",
      description: `The delivery partner reported a problem (${reason.replace(/_/g, " ")}). Agrimore is looking into it.`,
      partnerId: uid, timestamp: FieldValue.serverTimestamp(),
    });
    return { kind: "reported", exceptionId };
  });
}

export const DISPOSITIONS = ["reattempt", "returned_to_seller"] as const;

export type UpdateVerdict =
  | { kind: "updated" | "unchanged"; status: string }
  | { kind: "refused"; reason: "bad_request" | "not_found" | "already_resolved" | "resolution_required" };

export async function updateExceptionCore(
  db: Db, adminUid: string, exceptionId: string, action: unknown, disposition: unknown, resolution: unknown, nowMs: number
): Promise<UpdateVerdict> {
  if (action !== "acknowledge" && action !== "resolve") return { kind: "refused", reason: "bad_request" };
  if (action === "resolve" && !(DISPOSITIONS as readonly unknown[]).includes(disposition)) return { kind: "refused", reason: "bad_request" };
  const text = typeof resolution === "string" ? resolution.trim() : "";
  if (action === "resolve" && (text.length < 3 || text.length > MAX_NOTE)) return { kind: "refused", reason: "resolution_required" };
  const ref = db.collection("delivery_exceptions").doc(exceptionId);
  return db.runTransaction(async (tx): Promise<UpdateVerdict> => {
    const snap = await tx.get(ref);
    if (!snap.exists) return { kind: "refused", reason: "not_found" };
    const e = snap.data()!;
    const orderRef = db.collection("orders").doc(String(e.orderId));
    const order = await tx.get(orderRef);
    const at = Timestamp.fromMillis(nowMs);
    if (action === "acknowledge") {
      if (e.status !== "reported") return { kind: "unchanged", status: e.status };
      tx.update(ref, { status: "acknowledged", acknowledgedAt: at, acknowledgedBy: adminUid, updatedAt: at });
      return { kind: "updated", status: "acknowledged" };
    }
    if (e.status === "resolved") return { kind: "refused", reason: "already_resolved" };
    tx.update(ref, {
      status: "resolved", disposition, resolution: text,
      custody: disposition === "returned_to_seller" ? "seller" : "rider",
      resolvedAt: at, resolvedBy: adminUid,
      ...(e.status === "reported" ? { acknowledgedAt: at, acknowledgedBy: adminUid } : {}),
      updatedAt: at,
    });
    // The order's open marker closes with its exception (money untouched).
    if (order.exists && order.data()?.openDeliveryException?.id === exceptionId) {
      tx.update(orderRef, {
        openDeliveryException: FieldValue.delete(),
        lastDeliveryException: { id: exceptionId, disposition, resolvedAt: at },
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    return { kind: "updated", status: "resolved" };
  });
}

// ── Callables ───────────────────────────────────────────────

function refuse(code: HttpsError["code"], message: string, reason: string): never {
  throw new HttpsError(code, message, { reason });
}

export const attachDeliveryProof = onCall({ minInstances: 0, memory: "256MiB" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required");
  const orderId = typeof request.data?.orderId === "string" ? request.data.orderId.trim() : "";
  if (!orderId) throw new HttpsError("invalid-argument", "orderId is required");
  const v = await attachProofCore(admin.firestore(), request.auth.uid, orderId, storageLookup, Date.now());
  if (v.kind === "refused") {
    const code: HttpsError["code"] = v.reason === "not_found" ? "not-found" : v.reason === "not_assigned" ? "permission-denied" : "failed-precondition";
    refuse(code, "The proof photo could not be attached", v.reason);
  }
  return { success: true, path: v.path, alreadyAttached: v.kind === "already" };
});

export const reportDeliveryException = onCall({ minInstances: 0, memory: "256MiB" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required");
  const v = await reportExceptionCore(admin.firestore(), request.auth.uid, request.data, Date.now());
  if (v.kind === "refused") {
    const code: HttpsError["code"] = v.reason === "bad_request" ? "invalid-argument"
      : v.reason === "not_found" ? "not-found" : v.reason === "not_assigned" ? "permission-denied" : "failed-precondition";
    refuse(code, "The problem could not be reported", v.reason);
  }
  console.log(`[reportDeliveryException] ${v.exceptionId} ${v.kind}`);
  return { success: true, exceptionId: v.exceptionId, alreadyReported: v.kind === "already" };
});

export const updateDeliveryException = onCall({ minInstances: 0, memory: "256MiB" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required");
  const isAdmin = await resolveIsAdmin(admin.firestore(), request.auth.uid, request.auth.token.admin === true);
  if (!isAdmin) throw new HttpsError("permission-denied", "Admins only");
  const d = (request.data ?? {}) as Record<string, unknown>;
  const id = typeof d.exceptionId === "string" ? d.exceptionId.trim() : "";
  if (!id) throw new HttpsError("invalid-argument", "exceptionId is required");
  const v = await updateExceptionCore(admin.firestore(), request.auth.uid, id, d.action, d.disposition, d.resolution, Date.now());
  if (v.kind === "refused") {
    refuse(v.reason === "not_found" ? "not-found" : v.reason === "already_resolved" ? "failed-precondition" : "invalid-argument",
      "The problem could not be updated", v.reason);
  }
  return { success: true, status: v.status, changed: v.kind === "updated" };
});
