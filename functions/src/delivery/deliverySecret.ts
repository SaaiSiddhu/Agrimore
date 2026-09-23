// ============================================================
//  Delivery verification secret — orders/{orderId}/secrets/delivery
// ============================================================
//
// Phase DLV-0. The 6-digit delivery code used to live ONLY on orders/{id},
// and the orders read rule is whole-document: every approved delivery partner
// could read the code of every unassigned ready_for_pickup order and of its
// own order — the party being verified held the answer. This document holds
// the code (and confirmDelivery's wrong-attempt counter) where firestore.rules
// lets only the order's customer and an admin read it, and no client write it.
//
// Stage A (this phase): createOrder/createOrderFromRfq write the code BOTH
// here and on the order, because the released marketplace build reads it from
// the order. Stage B (DLV-0B) stops writing the order-doc copy once a
// marketplace build reading this location is released and adopted.

import * as admin from "firebase-admin";

/** Wrong codes allowed before the order is locked. */
export const MAX_FAILED_DELIVERY_ATTEMPTS = 5;

/** How long a lock lasts once MAX_FAILED_DELIVERY_ATTEMPTS is reached. */
export const DELIVERY_LOCK_MS = 15 * 60 * 1000;

export function deliverySecretRef(
  db: FirebaseFirestore.Firestore,
  orderId: string
): FirebaseFirestore.DocumentReference {
  return db.collection("orders").doc(orderId).collection("secrets").doc("delivery");
}

/** The document createOrder writes next to a new order. */
export function newDeliverySecret(code: string): FirebaseFirestore.DocumentData {
  return {
    code,
    failedAttempts: 0,
    lockedUntil: null,
    consumedAt: null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}
