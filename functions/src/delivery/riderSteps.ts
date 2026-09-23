// ============================================================
//  Callables: advanceDeliveryStep / releaseDeliveryOrder (Phase DLV-3C)
// ============================================================
//
// Until now every rider step was a client write straight to orders/{id}
// (apps/delivery order_provider.dart updateOrderStatus): no transition check,
// no record of where the rider was. Re-proved at bab71df on the rules
// emulator: the assigned rider could jump to delivered, skip the store, go
// backwards and even write cancelled after pickup. These callables are the
// server-checked path:
//
//  - advanceDeliveryStep moves the order one rider step (arrived at store,
//    picked up, out for delivery) only where delivery/states.ts allows it,
//    and records how far the rider was from the store (D-DLV-GEOFENCE: more
//    than 300 m, a mocked location or no location is FLAGGED for admin, never
//    blocked — a rider with bad GPS must still be able to work).
//  - releaseDeliveryOrder hands an order back ("Seller not ready") before
//    pickup. The old client write deleted deliveryPartnerId, which the rules
//    protect for the assigned rider, so every release was denied.
//
// "delivered" stays with confirmDelivery (the customer's code), which gains
// the same drop-distance flag. The direct client write of delivered remains
// possible until DLV-3D locks it — the released app still depends on it
// (D-DLV-OTPLOCK).
//
// Flags live in orders.deliveryFlags (+ deliveryFlagged), and every step's
// evidence in orders.deliveryStepChecks.<step>. firestore.rules protects all
// three from client writes so a rider cannot erase a flag.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { canTransition, TaskStatus, taskStatusFromOrder } from "./states";
import { dispatchRef, distanceKm } from "./dispatch";
import { dropPoint, orderPickupPoint, sellerPickupPoint } from "./syncDeliveryTask";

type Db = FirebaseFirestore.Firestore;
type Point = { lat: number; lng: number };

/** D-DLV-GEOFENCE: a step tapped further than this from its place is flagged. */
export const GEOFENCE_METERS = 300;

/** The rider steps this callable performs: order wire value → leg state. */
export const RIDER_STEPS = {
  arrived_at_store: "at_pickup",
  picked_up: "picked_up",
  out_for_delivery: "en_route",
} as const satisfies Record<string, TaskStatus>;
export type RiderStep = keyof typeof RIDER_STEPS;

const STEP_FIELDS: Record<RiderStep, { at: string; title: string; description: string }> = {
  arrived_at_store: { at: "arrivedAtStoreAt", title: "Arrived at Store", description: "Delivery partner arrived at the seller store" },
  picked_up: { at: "pickedUpAt", title: "Picked Up", description: "Order has been picked up from seller" },
  out_for_delivery: { at: "outForDeliveryAt", title: "Out for Delivery", description: "Order is now out for delivery" },
};

/** Release reasons a rider may give (DeliveryFailureReason wire values). */
const RELEASE_REASONS: Record<string, string> = {
  seller_not_ready: "Delivery partner reported seller is not ready for pickup",
  vehicle_issue: "Delivery partner had a vehicle issue",
  safety: "Delivery partner reported a safety concern",
  other: "Delivery partner released the order",
};

/** The rider's position at the tap, as the app reports it. */
export type Fix = { lat: number; lng: number; accuracy: number | null; isMocked: boolean };

/** Null when the app sent no usable position (no permission, no signal). */
export function parseFix(data: unknown): Fix | null {
  const d = (data ?? {}) as Record<string, unknown>;
  const lat = d.lat, lng = d.lng;
  if (typeof lat !== "number" || typeof lng !== "number" || !Number.isFinite(lat) || !Number.isFinite(lng)) return null;
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
  const acc = typeof d.accuracy === "number" && Number.isFinite(d.accuracy) && d.accuracy >= 0 ? d.accuracy : null;
  return { lat, lng, accuracy: acc, isMocked: d.isMocked === true };
}

export type FlagReason = "far_from_store" | "far_from_customer" | "mocked_location" | "no_location";

/**
 * Where the rider was relative to the place the step belongs to. `flag` is
 * false for out_for_delivery (riders routinely tap it after leaving the store)
 * — its distance is recorded, not judged. No known place → distance null and
 * no distance flag: a store without coordinates is not the rider's fault.
 */
export function locationCheck(
  fix: Fix | null, place: Point | null, kind: "store" | "customer", flag = true
): { distanceMeters: number | null; reasons: FlagReason[] } {
  const reasons: FlagReason[] = [];
  if (!fix) {
    if (flag) reasons.push("no_location");
    return { distanceMeters: null, reasons };
  }
  if (fix.isMocked) reasons.push("mocked_location");
  const distanceMeters = place ? Math.round(distanceKm(fix, place) * 1000) : null;
  if (flag && distanceMeters !== null && distanceMeters > GEOFENCE_METERS) {
    reasons.push(kind === "store" ? "far_from_store" : "far_from_customer");
  }
  return { distanceMeters, reasons };
}

/** The order fields recording one step's evidence, and a flag when there is one. */
export function evidenceFields(
  step: string, fix: Fix | null, check: { distanceMeters: number | null; reasons: FlagReason[] }, nowMs: number
): Record<string, unknown> {
  const at = Timestamp.fromMillis(nowMs);
  const out: Record<string, unknown> = {
    [`deliveryStepChecks.${step}`]: {
      at,
      lat: fix?.lat ?? null,
      lng: fix?.lng ?? null,
      accuracy: fix?.accuracy ?? null,
      isMocked: fix?.isMocked ?? null,
      distanceMeters: check.distanceMeters,
      flags: check.reasons,
    },
  };
  if (check.reasons.length > 0) {
    // One entry per step; arrayUnion cannot hold serverTimestamp, hence `at`.
    out.deliveryFlags = FieldValue.arrayUnion({ step, reasons: check.reasons, distanceMeters: check.distanceMeters, at });
    out.deliveryFlagged = true;
  }
  return out;
}

function orderIdOf(data: unknown): string {
  const id = (data as { orderId?: unknown })?.orderId;
  if (typeof id !== "string" || !id.trim()) throw new HttpsError("invalid-argument", "orderId is required");
  return id.trim();
}

export type StepVerdict =
  | { kind: "advanced"; from: TaskStatus; to: TaskStatus; distanceMeters: number | null; flags: FlagReason[] }
  | { kind: "already"; to: TaskStatus }
  | { kind: "refused"; reason: "not_found" | "not_assigned" | "bad_transition"; from?: TaskStatus | null; to?: TaskStatus };

export async function advanceStepCore(
  db: Db, uid: string, orderId: string, step: RiderStep, fix: Fix | null, nowMs: number
): Promise<StepVerdict> {
  const orderRef = db.collection("orders").doc(orderId);
  const taskRef = db.collection("delivery_tasks").doc(orderId);
  return db.runTransaction(async (tx): Promise<StepVerdict> => {
    const [orderSnap, taskSnap] = await Promise.all([tx.get(orderRef), tx.get(taskRef)]);
    if (!orderSnap.exists) return { kind: "refused", reason: "not_found" };
    const order = orderSnap.data()!;
    if (order.deliveryPartnerId !== uid) return { kind: "refused", reason: "not_assigned" };

    const to = RIDER_STEPS[step];
    const from = taskStatusFromOrder(order);
    // A retry after a dropped response: already there, nothing to write.
    if (from === to) return { kind: "already", to };
    if (!from || !canTransition(from, to)) return { kind: "refused", reason: "bad_transition", from, to };

    // The store: the task's server-derived point, else the order's, else the seller's.
    let place: Point | null = null;
    const task = taskSnap.exists ? taskSnap.data()! : null;
    if (task?.pickup && typeof task.pickup.lat === "number" && typeof task.pickup.lng === "number") {
      place = { lat: task.pickup.lat, lng: task.pickup.lng };
    } else {
      place = orderPickupPoint(order);
      if (!place && typeof order.sellerId === "string" && order.sellerId) {
        const seller = await tx.get(db.collection("sellers").doc(order.sellerId));
        place = sellerPickupPoint(seller.exists ? seller.data() : undefined);
      }
    }
    const check = locationCheck(fix, place, "store", step !== "out_for_delivery");
    const f = STEP_FIELDS[step];

    tx.update(orderRef, {
      orderStatus: step,
      status: step,
      [f.at]: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      ...evidenceFields(step, fix, check, nowMs),
    });
    const timeline = orderRef.collection("timeline").doc();
    tx.set(timeline, {
      id: timeline.id,
      status: step,
      title: f.title,
      description: f.description,
      partnerId: uid,
      ...(check.reasons.length ? { flags: check.reasons, distanceMeters: check.distanceMeters } : {}),
      timestamp: FieldValue.serverTimestamp(),
    });
    return { kind: "advanced", from, to, distanceMeters: check.distanceMeters, flags: check.reasons };
  });
}

export type ReleaseVerdict =
  | { kind: "released" }
  | { kind: "already" }
  | { kind: "refused"; reason: "not_found" | "not_assigned" | "after_pickup" };

export async function releaseOrderCore(
  db: Db, uid: string, orderId: string, reason: string, nowMs: number
): Promise<ReleaseVerdict> {
  const orderRef = db.collection("orders").doc(orderId);
  const dRef = dispatchRef(db, orderId);
  return db.runTransaction(async (tx): Promise<ReleaseVerdict> => {
    const snap = await tx.get(orderRef);
    if (!snap.exists) return { kind: "refused", reason: "not_found" };
    const order = snap.data()!;
    if (order.deliveryPartnerId !== uid) {
      // A retry after a dropped response.
      return order.deliveryReleasedBy === uid && !order.deliveryPartnerId
        ? { kind: "already" }
        : { kind: "refused", reason: "not_assigned" };
    }
    const from = taskStatusFromOrder(order);
    // Before pickup only: after it the goods are with the rider — that is a
    // return (failed attempt → returning_to_seller), not a release.
    if (from !== "assigned" && from !== "at_pickup") return { kind: "refused", reason: "after_pickup" };

    tx.update(orderRef, {
      deliveryPartnerId: FieldValue.delete(),
      deliveryPartner: FieldValue.delete(),
      orderStatus: "ready_for_pickup",
      status: "ready_for_pickup",
      deliveryIssue: RELEASE_REASONS[reason],
      deliveryIssueAt: FieldValue.serverTimestamp(),
      deliveryReleasedBy: uid,
      updatedAt: FieldValue.serverTimestamp(),
    });
    const timeline = orderRef.collection("timeline").doc();
    tx.set(timeline, {
      id: timeline.id,
      status: "delivery_released",
      title: "Delivery Released",
      description: RELEASE_REASONS[reason],
      partnerId: uid,
      timestamp: FieldValue.serverTimestamp(),
    });
    // The order goes back to ready_for_pickup; onOrderStatusChanged restarts
    // dispatch and keeps declinedBy, so this rider is not offered it again.
    tx.set(dRef, { declinedBy: FieldValue.arrayUnion(uid), updatedAt: Timestamp.fromMillis(nowMs) }, { merge: true });
    return { kind: "released" };
  });
}

const REFUSALS: Record<string, [HttpsError["code"], string]> = {
  not_found: ["not-found", "Order not found"],
  not_assigned: ["permission-denied", "This order is not assigned to you"],
  bad_transition: ["failed-precondition", "This step is not possible from the order's current state"],
  after_pickup: ["failed-precondition", "The order has already been picked up — it can no longer be released"],
};

function refuse(reason: string, details: Record<string, unknown> = {}): never {
  const [code, message] = REFUSALS[reason];
  throw new HttpsError(code, message, { reason, ...details });
}

export const advanceDeliveryStep = onCall({ minInstances: 0, memory: "256MiB" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required");
  const orderId = orderIdOf(request.data);
  const step = (request.data as { step?: unknown })?.step;
  if (typeof step !== "string" || !(step in RIDER_STEPS)) {
    throw new HttpsError("invalid-argument", "step must be arrived_at_store, picked_up or out_for_delivery");
  }
  const v = await advanceStepCore(admin.firestore(), request.auth.uid, orderId, step as RiderStep,
    parseFix(request.data), Date.now());
  if (v.kind === "refused") refuse(v.reason, { from: v.from ?? null, to: v.to ?? null });
  if (v.kind === "already") return { success: true, alreadyAtStep: true, flags: [] };
  return { success: true, alreadyAtStep: false, distanceMeters: v.distanceMeters, flags: v.flags };
});

export const releaseDeliveryOrder = onCall({ minInstances: 0, memory: "256MiB" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required");
  const orderId = orderIdOf(request.data);
  const raw = (request.data as { reason?: unknown })?.reason;
  const reason = typeof raw === "string" && raw in RELEASE_REASONS ? raw : "seller_not_ready";
  const v = await releaseOrderCore(admin.firestore(), request.auth.uid, orderId, reason, Date.now());
  if (v.kind === "refused") refuse(v.reason);
  return { success: true, alreadyReleased: v.kind === "already" };
});

/**
 * confirmDelivery's drop check (same rule, against the customer's address).
 * Null for a released (pre-DLV-3C) app, which sends neither a position nor
 * `locationStatus` — flagging every one of those deliveries "no_location"
 * would bury the real flags until the new app is adopted.
 */
export function dropCheck(order: FirebaseFirestore.DocumentData, data: unknown) {
  const d = (data ?? {}) as Record<string, unknown>;
  if (!("lat" in d) && !("locationStatus" in d)) return null;
  const fix = parseFix(data);
  return { fix, check: locationCheck(fix, dropPoint(order), "customer") };
}
