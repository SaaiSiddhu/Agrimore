// ============================================================
//  Trigger: syncDeliveryTask — orders/{orderId} → delivery_tasks/{orderId}
// ============================================================
//
// Phase DLV-1A. Every rider leg gets one server-written document that
// dispatch (DLV-2), live tracking (DLV-3) and earnings (DLV-4) hang off,
// in the typed vocabulary of ./states.ts instead of the ~20 free-text order
// statuses.
//
// A PROJECTION, not a new source of truth: it only reads what the released
// apps already write to the order, so it works with every client on Play and
// changes no write path. Consequences, stated so nobody over-reads it:
//  - it records legacy jumps rather than refusing them (admins and old clients
//    can write any status) and flags them in lastTransitionAllowed; DLV-2's
//    callables are where transitions get enforced;
//  - it is lazy: an order that was already past ready_for_pickup when this
//    deployed gets its task on its next update, not before (no backfill);
//  - it never writes the order (no trigger loop) and skips the write when
//    nothing it projects has changed.
//
// Deliberately NO customer name, phone or address text: the drop point is
// coordinates + pincode. delivery_tasks is readable by the assigned rider
// (firestore.rules), and DLV-0 is removing exactly this kind of leak.

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
// Modular import, NOT admin.firestore.FieldValue: in v1 background dispatch the
// namespace member is undefined (P0-FIELDVALUE, src/customer/wallet.ts:557).
// This trigger shipped in DLV-1A with the namespace form; DLV-2A's genuine-
// dispatch suite (phaseDLV2A_trigger_test.js t01/t04) caught it crashing on
// every order update — test.wrap(), used by DLV-1A's own suite, cannot.
import { FieldValue } from "firebase-admin/firestore";
import { isCashOnDelivery } from "../seller/sellerTransitionOrder";
import { canTransition, isTerminal, TaskStatus, taskStatusFromOrder, taskStatusFromWire } from "./states";

type Point = { lat: number; lng: number };
type DropPoint = Point & { pincode?: string };

function num(v: unknown): number | null {
  if (typeof v === "number" && Number.isFinite(v)) return v;
  if (typeof v === "string" && v.trim()) {
    const n = Number(v);
    if (Number.isFinite(n)) return n;
  }
  return null;
}

function pointFrom(data: unknown, latKeys: string[], lngKeys: string[]): Point | null {
  if (!data || typeof data !== "object") return null;
  const d = data as Record<string, unknown>;
  for (const la of latKeys) {
    for (const ln of lngKeys) {
      const lat = num(d[la]);
      const lng = num(d[ln]);
      if (lat !== null && lng !== null) return { lat, lng };
    }
  }
  return null;
}

/** Pickup from the order itself — never from the customer's address. */
export function orderPickupPoint(order: FirebaseFirestore.DocumentData): Point | null {
  return (
    pointFrom(order, ["pickupLat", "sellerLat", "storeLat"], ["pickupLng", "sellerLng", "storeLng"]) ??
    pointFrom(order.pickupLocation, ["lat", "latitude"], ["lng", "longitude"]) ??
    pointFrom(order.sellerLocation, ["lat", "latitude"], ["lng", "longitude"])
  );
}

/** A seller document's store location (sellers/{sellerId}). */
export function sellerPickupPoint(seller: FirebaseFirestore.DocumentData | undefined): Point | null {
  return pointFrom(seller, ["storeLat", "shopLat", "currentLat", "lat", "latitude"],
    ["storeLng", "shopLng", "currentLng", "lng", "longitude"]);
}

export function dropPoint(order: FirebaseFirestore.DocumentData): DropPoint | null {
  const addr = order.deliveryAddress;
  const p = pointFrom(addr, ["latitude", "lat"], ["longitude", "lng"]);
  if (!p) return null;
  const pin = addr?.pincode ?? addr?.zipcode;
  return typeof pin === "string" && pin.trim() ? { ...p, pincode: pin.trim() } : p;
}

const str = (v: unknown): string | null => (typeof v === "string" && v.length > 0 ? v : null);

/** The projected fields, excluding bookkeeping (stepAt, updatedAt, flags). */
export function projectFields(
  orderId: string,
  order: FirebaseFirestore.DocumentData,
  status: TaskStatus,
  pickup: Point | null
): Record<string, unknown> {
  const total = num(order.total) ?? 0;
  return {
    orderId,
    orderNumber: str(order.orderNumber),
    status,
    riderId: str(order.deliveryPartnerId),
    sellerId: str(order.sellerId),
    customerId: str(order.userId),
    pickup,
    drop: dropPoint(order),
    paymentMethod: str(order.paymentMethod),
    codAmount: isCashOnDelivery(order.paymentMethod) ? total : 0,
    legacyStatus: str(order.orderStatus) ?? str(order.status),
  };
}

const PROJECTED_KEYS = [
  "orderId", "orderNumber", "status", "riderId", "sellerId", "customerId",
  "pickup", "drop", "paymentMethod", "codAmount", "legacyStatus",
] as const;

// Key-order-independent: Firestore does not promise map key order back.
function canonical(v: unknown): unknown {
  if (Array.isArray(v)) return v.map(canonical);
  if (v && typeof v === "object") {
    return Object.keys(v as object).sort().reduce((acc, k) => {
      const val = (v as Record<string, unknown>)[k];
      if (val !== undefined) acc[k] = canonical(val);
      return acc;
    }, {} as Record<string, unknown>);
  }
  return v ?? null;
}

function sameValue(a: unknown, b: unknown): boolean {
  return JSON.stringify(canonical(a)) === JSON.stringify(canonical(b));
}

/**
 * Decides the write. Pure given its inputs; null = write nothing.
 * `sellerPickup` is consulted only when neither the order nor the existing
 * task has a pickup point.
 */
export function planTaskWrite(
  orderId: string,
  order: FirebaseFirestore.DocumentData,
  existing: FirebaseFirestore.DocumentData | null,
  sellerPickup: Point | null
): Record<string, unknown> | null {
  const status = taskStatusFromOrder(order);
  // No rider leg (yet). An existing task is left as it was: an admin moving
  // an order back before ready_for_pickup is not a rider-leg event.
  if (status === null) return null;
  // Never open a leg that is already over — an order cancelled or delivered
  // before it ever reached ready_for_pickup had no rider leg.
  if (!existing && isTerminal(status)) return null;

  const pickup = orderPickupPoint(order) ?? (existing?.pickup as Point | undefined) ?? sellerPickup;
  const fields = projectFields(orderId, order, status, pickup ?? null);

  if (existing && PROJECTED_KEYS.every((k) => sameValue(fields[k], existing[k]))) return null;

  const previous = existing ? taskStatusFromWire(existing.status) : null;
  const statusChanged = previous !== status;
  const now = FieldValue.serverTimestamp();
  const write: Record<string, unknown> = { ...fields, updatedAt: now };

  if (!existing) {
    write.createdAt = now;
    write.lastTransitionAllowed = true; // first observation, not a transition
  } else if (statusChanged) {
    write.lastTransitionAllowed = previous === null ? true : canTransition(previous, status);
  }
  // stepAt.<status>: the FIRST time the leg entered it; never overwritten.
  const stepAt = (existing?.stepAt ?? {}) as Record<string, unknown>;
  if (statusChanged && stepAt[status] === undefined) {
    write.stepAt = { [status]: now };
  }
  return write;
}

/** Field paths for set(..., { mergeFields }) — stepAt by its single new key. */
export function taskMergeFields(write: Record<string, unknown>): string[] {
  const paths = Object.keys(write).filter((k) => k !== "stepAt");
  const step = write.stepAt as Record<string, unknown> | undefined;
  if (step) paths.push(...Object.keys(step).map((k) => `stepAt.${k}`));
  return paths;
}

export const syncDeliveryTask = functions.firestore
  .document("orders/{orderId}")
  .onUpdate(async (change, context) => {
    const orderId = context.params.orderId as string;
    const order = change.after.data();
    if (!order) return null;

    // Cheap exit before any read: no rider leg implied.
    if (taskStatusFromOrder(order) === null) return null;

    const db = admin.firestore();
    const taskRef = db.collection("delivery_tasks").doc(orderId);
    const taskSnap = await taskRef.get();
    const existing = taskSnap.exists ? taskSnap.data()! : null;

    let sellerPickup: Point | null = null;
    const sellerId = str(order.sellerId);
    if (!orderPickupPoint(order) && !existing?.pickup && sellerId) {
      const sellerSnap = await db.collection("sellers").doc(sellerId).get();
      sellerPickup = sellerPickupPoint(sellerSnap.data());
    }

    const write = planTaskWrite(orderId, order, existing, sellerPickup);
    if (!write) return null;
    // mergeFields, not merge: every projected field is REPLACED whole (a drop
    // point that loses its pincode must lose it here too, or the comparison
    // above would see a change on every later update), while stepAt gets only
    // its one new key, so earlier steps survive.
    await taskRef.set(write, { mergeFields: taskMergeFields(write) });
    return null;
  });
