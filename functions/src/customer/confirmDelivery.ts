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

// An order in one of these is finished in the other direction. Confirming it as
// delivered would be a real payout and a real associate commission on goods the
// customer is not receiving — calculateSellerPayout and
// payEmployeeCommissionOnDelivery both fire on exactly the transition this
// callable performs. Refused, not silently ignored: a partner standing at a
// door with a cancelled order needs to be told, not to get a success.
const NOT_DELIVERABLE = new Set(["cancelled", "refunded", "returned", "rejected"]);

/**
 * Reads a status signal the way the rest of this codebase already does: as
 * `orderStatus` OR the mirrored `status`, either one.
 *
 * Not a stylistic choice. productCreditReversal.ts:50 and firestore.rules'
 * ownerOrderStatusChangeIsValid() both treat the two fields as one signal for a
 * measured reason — order_provider.dart's cancelOrder() (customer path) writes
 * only `orderStatus`, while seller_panel_screen.dart's _updateOrderStatus and
 * apps/admin's copy write ONLY `status`. A one-field read here would miss every
 * seller- or admin-initiated cancellation, which is exactly the case
 * NOT_DELIVERABLE exists to catch.
 *
 * Measured, not assumed. Narrowing this to `set.has(a)` — the one-field read
 * this function replaced — drops phase29_delivery_confirmation_test.js to
 * 10/12, and the failure is a delivery, not a refusal: a seller-cancelled order
 * comes back `orderStatus=delivered status=delivered` (scenario 10), and a
 * seller-marked-delivered order is re-delivered with a second timeline entry
 * (scenario 11, alreadyDelivered=false).
 */
function statusIsIn(order: FirebaseFirestore.DocumentData, set: Set<string>): boolean {
  const a = typeof order.orderStatus === "string" ? order.orderStatus.toLowerCase() : "";
  const b = typeof order.status === "string" ? order.status.toLowerCase() : "";
  return set.has(a) || set.has(b);
}

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
      //
      // Measured, not assumed: removing these five lines makes
      // phase29_delivery_confirmation_test.js drop to 5/8, and not by failing
      // softly — an UNASSIGNED partner holding the correct code SUCCEEDS
      // (scenario 3, status=delivered), an order with NO assigned partner is
      // deliverable by anyone (scenario 8), and right and wrong guesses become
      // distinguishable (scenario 4, identical=false), which is the oracle this
      // ordering exists to prevent.
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
      if (statusIsIn(order, DELIVERED_EQUIVALENT)) {
        return { success: true, alreadyDelivered: true };
      }

      // A cancelled, refunded, returned or rejected order is not deliverable,
      // and the correct code does not make it so. Checked AFTER the
      // already-delivered branch so that an order which is both is read as the
      // retry it is, and BEFORE the code comparison so that this refusal never
      // depends on the guess — it must not become an oracle either.
      //
      // Measured, not assumed. Removing this block drops
      // phase29_delivery_confirmation_test.js to 9/12: a cancelled order with
      // the correct code is DELIVERED (scenario 9, status=delivered,
      // timeline=1), and the refusal that remains for a wrong code makes the
      // pair distinguishable again (scenario 12, identical=false).
      if (statusIsIn(order, NOT_DELIVERABLE)) {
        throw new HttpsError(
          "failed-precondition",
          "This order is no longer active and cannot be marked delivered",
          { reason: "not_deliverable" }
        );
      }

      const expected = typeof order.deliveryVerificationCode === "string"
        ? order.deliveryVerificationCode
        : null;
      if (!expected) {
        // Fail closed. An order with no code cannot be confirmed through this
        // path; it needs an admin, not a guess.
        throw new HttpsError(
          "failed-precondition",
          "This order has no verification code — please contact support",
          { reason: "no_code" }
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
