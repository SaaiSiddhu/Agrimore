// ============================================================
//  Callable: confirmDelivery — server-side delivery verification
// ============================================================
//
// Finding N-5 (P1). Delivery confirmation was not a control at all.
// apps/delivery/lib/screens/orders/active_order_screen.dart:801 read
// `deliveryVerificationCode` out of the order document INTO THE DELIVERY
// PARTNER'S OWN CLIENT and compared it locally, then :868 wrote
// `orderStatus: 'delivered'` directly. The party being authenticated was handed
// the answer, and the dialog could be skipped entirely — the fulfilment rule
// denylists financial fields but not `orderStatus`/`status`, so the direct
// write is permitted.
//
// That matters beyond the status field: payEmployeeCommissionOnDelivery and
// calculateSellerPayout both fire real money on exactly that transition, and
// FIX-4 has just made the payout side reliable. A partner who can self-certify
// can cause a genuine seller payout and a genuine associate commission on goods
// that were never delivered.
//
// This callable is the correct path: the code is compared SERVER-side, inside
// the Admin SDK where the client never sees it, and the transition is performed
// here.
//
// WHAT THIS DOES NOT DO, deliberately. It does not stop the direct write — the
// rules still permit it, and tightening them is phase FIX-5B. Tightening now
// would break every delivery partner still running the currently-released
// apps/delivery build, which is exactly how the 2026-08-31 rules deploy left
// pre-1.0.7 clients unable to order (B2B_PHASE_SEQUENCING). The safe order is:
// ship this, release a client that uses it, confirm adoption, then tighten.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as crypto from "crypto";

interface ConfirmDeliveryData {
  orderId: string;
  code: string;
}

// Mirrors employeeCommission.ts's DELIVERED_EQUIVALENT_STATUSES and
// sellerNotifications.ts's PAYOUT_ELIGIBLE_STATUSES. An order already in one of
// these has been fulfilled; confirming again is a retry, not a new delivery.
const DELIVERED_EQUIVALENT = new Set(["delivered", "completed"]);

/**
 * Constant-time comparison. The codes are six digits from a CSPRNG
 * (createOrder.ts's generateVerificationCode), so a timing oracle is not the
 * realistic attack here — the realistic attack is simply reading the code,
 * which is what this whole callable exists to prevent. Constant-time anyway,
 * because a verification comparison that leaks its progress is the kind of
 * detail that stops being harmless the moment the surrounding code changes.
 */
function codesMatch(a: string, b: string): boolean {
  const bufA = Buffer.from(a, "utf8");
  const bufB = Buffer.from(b, "utf8");
  if (bufA.length !== bufB.length) return false;
  return crypto.timingSafeEqual(bufA, bufB);
}

export const confirmDelivery = onCall(
  { minInstances: 0, memory: "256MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required");
    }
    const uid = request.auth.uid;
    const data = request.data as ConfirmDeliveryData;

    const orderId = typeof data?.orderId === "string" ? data.orderId.trim() : "";
    const code = typeof data?.code === "string" ? data.code.trim() : "";
    if (!orderId) {
      throw new HttpsError("invalid-argument", "orderId is required");
    }
    if (!code) {
      throw new HttpsError("invalid-argument", "A verification code is required");
    }

    const db = admin.firestore();
    const orderRef = db.collection("orders").doc(orderId);

    return db.runTransaction(async (tx) => {
      const snap = await tx.get(orderRef);
      if (!snap.exists) {
        throw new HttpsError("not-found", "Order not found");
      }
      const order = snap.data()!;

      // Only the delivery partner this order is actually assigned to may
      // confirm it. Checked BEFORE the code comparison so that a partner
      // fishing for another order's code cannot use this callable as an oracle
      // — a wrong-partner call is refused identically whether the code is right
      // or wrong.
      if (order.deliveryPartnerId !== uid) {
        throw new HttpsError(
          "permission-denied",
          "This order is not assigned to you"
        );
      }

      // Idempotency. A retried call after a dropped response must read as
      // success, not as a scary failure on an order that is already delivered —
      // the same reasoning activationCore.ts applies to a duplicated activation.
      // Checked before the code comparison so a retry does not depend on the
      // partner still having the code to hand.
      const currentStatus = typeof order.orderStatus === "string" ? order.orderStatus.toLowerCase() : "";
      if (DELIVERED_EQUIVALENT.has(currentStatus)) {
        return { success: true, alreadyDelivered: true };
      }

      const expected = typeof order.deliveryVerificationCode === "string"
        ? order.deliveryVerificationCode
        : null;
      if (!expected) {
        // Fail closed. An order with no code cannot be confirmed through this
        // path; it needs an admin, not a guess.
        throw new HttpsError(
          "failed-precondition",
          "This order has no verification code — please contact support"
        );
      }

      if (!codesMatch(code, expected)) {
        // Deliberately does not say whether the order, the assignment or the
        // code was wrong beyond what is already known to this caller.
        throw new HttpsError("permission-denied", "Incorrect verification code");
      }

      tx.update(orderRef, {
        orderStatus: "delivered",
        status: "delivered",
        deliveredAt: admin.firestore.FieldValue.serverTimestamp(),
        codSettlementStatus: "pending",
        deliveryConfirmedBy: uid,
        deliveryConfirmedVia: "confirmDelivery",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const timelineRef = orderRef.collection("timeline").doc();
      tx.set(timelineRef, {
        id: timelineRef.id,
        status: "delivered",
        title: "Delivered",
        description: "Order delivered and verified with the customer's code",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { success: true, alreadyDelivered: false };
    });
  }
);
