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
//
// Phase DLV-0 added two things. (1) The expected code is read from
// orders/{id}/secrets/delivery first (deliverySecret.ts) — a document no
// delivery partner can read — with the order-doc field as the legacy fallback.
// (2) Five wrong codes from the assigned partner lock the order for 15
// minutes; the correct code is refused during the lock. A six-digit code with
// no attempt limit was guessable by the one party allowed to guess.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as crypto from "crypto";
// Phase DLV-3C: modular FieldValue/Timestamp. Under the functions emulator
// `admin.firestore` is a BOUND copy of the function (firebase-tools
// functionsEmulatorRuntime Proxied.getOriginal) with no static members, so
// `admin.firestore.Timestamp` was undefined and every genuine emulator call
// threw at the lock check — this callable could not be tested end to end
// (phaseDLV3C_dispatch_test g06). Production was unaffected.
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { dropCheck, evidenceFields } from "../delivery/riderSteps";
import {
  deliverySecretRef,
  DELIVERY_LOCK_MS,
  MAX_FAILED_DELIVERY_ATTEMPTS,
} from "../delivery/deliverySecret";

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
    const secretRef = deliverySecretRef(db, orderId);

    // Phase DLV-0. A wrong code now has a side effect — the attempt counter —
    // and a transaction that throws commits nothing. So the transaction never
    // throws for a wrong or locked code: it writes the counter and RETURNS a
    // verdict, and the refusal is thrown only after the commit. Every other
    // refusal (unassigned, not found, not deliverable, no code) writes nothing
    // and still throws from inside, exactly as before.
    type Verdict =
      | { kind: "delivered"; alreadyDelivered: boolean }
      | { kind: "wrong" }
      | { kind: "locked"; retryAfterSec: number };

    const verdict: Verdict = await db.runTransaction(async (tx): Promise<Verdict> => {
      // All reads first.
      const snap = await tx.get(orderRef);
      if (!snap.exists) {
        throw new HttpsError("not-found", "Order not found");
      }
      const order = snap.data()!;
      const secretSnap = await tx.get(secretRef);
      const secret = secretSnap.exists ? secretSnap.data()! : null;

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
      //
      // DLV-0: also BEFORE the lock check and the counter, so another partner's
      // guesses can neither reveal nor trigger this order's lock (scenarios 21,
      // 22) — otherwise a rival could lock someone else's delivery.
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
      // partner still having the code to hand. DLV-0: and before the lock, so a
      // retry after a genuine delivery is never reported as locked (scenario 20).
      if (statusIsIn(order, DELIVERED_EQUIVALENT)) {
        return { kind: "delivered", alreadyDelivered: true };
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

      // DLV-0: the secret document is authoritative whenever it carries a
      // code (scenario 14) — the order-doc copy is partner-readable until
      // DLV-0B removes it. Orders created before DLV-0 have no secret doc (or
      // only a counter, after a wrong guess) and fall back to the order field
      // (scenario 15).
      const expected =
        typeof secret?.code === "string" && secret.code
          ? secret.code
          : typeof order.deliveryVerificationCode === "string"
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

      // DLV-0: the lock. While it holds, even the correct code is refused —
      // otherwise the lock would only pace a guesser (scenario 18).
      const now = Date.now();
      const lockedUntilMs =
        secret?.lockedUntil instanceof Timestamp
          ? secret.lockedUntil.toMillis()
          : 0;
      if (lockedUntilMs > now) {
        return { kind: "locked", retryAfterSec: Math.ceil((lockedUntilMs - now) / 1000) };
      }

      if (!codesMatch(code, expected)) {
        const failed =
          (typeof secret?.failedAttempts === "number" ? secret.failedAttempts : 0) + 1;
        if (failed >= MAX_FAILED_DELIVERY_ATTEMPTS) {
          tx.set(secretRef, {
            failedAttempts: 0,
            lockedUntil: Timestamp.fromMillis(now + DELIVERY_LOCK_MS),
            lastFailedAt: FieldValue.serverTimestamp(),
            lastLockedAt: FieldValue.serverTimestamp(),
          }, { merge: true });
          return { kind: "locked", retryAfterSec: Math.ceil(DELIVERY_LOCK_MS / 1000) };
        }
        tx.set(secretRef, {
          failedAttempts: failed,
          lockedUntil: null,
          lastFailedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
        return { kind: "wrong" };
      }

      // Phase DLV-3C (D-DLV-GEOFENCE): where the rider was when the code was
      // accepted — recorded, and flagged beyond 300 m / mocked / no fix. Never
      // a refusal: the customer's code is the proof of delivery.
      const drop = dropCheck(order, request.data);
      tx.update(orderRef, {
        orderStatus: "delivered",
        status: "delivered",
        deliveredAt: FieldValue.serverTimestamp(),
        codSettlementStatus: "pending",
        deliveryConfirmedBy: uid,
        deliveryConfirmedVia: "confirmDelivery",
        updatedAt: FieldValue.serverTimestamp(),
        ...(drop ? evidenceFields("delivered", drop.fix, drop.check, now) : {}),
      });

      tx.set(secretRef, {
        failedAttempts: 0,
        lockedUntil: null,
        consumedAt: FieldValue.serverTimestamp(),
      }, { merge: true });

      const timelineRef = orderRef.collection("timeline").doc();
      tx.set(timelineRef, {
        id: timelineRef.id,
        status: "delivered",
        title: "Delivered",
        description: "Order delivered and verified with the customer's code",
        ...(drop && drop.check.reasons.length
          ? { flags: drop.check.reasons, distanceMeters: drop.check.distanceMeters }
          : {}),
        timestamp: FieldValue.serverTimestamp(),
      });

      return { kind: "delivered", alreadyDelivered: false };
    });

    if (verdict.kind === "wrong") {
      // Deliberately does not say whether the order, the assignment or the
      // code was wrong beyond what is already known to this caller. Message
      // unchanged from before DLV-0 (scenario 16 asserts it).
      throw new HttpsError("permission-denied", "Incorrect verification code");
    }
    if (verdict.kind === "locked") {
      throw new HttpsError(
        "resource-exhausted",
        "Too many incorrect codes. Try again later.",
        { reason: "locked", retryAfterSec: verdict.retryAfterSec }
      );
    }
    return { success: true, alreadyDelivered: verdict.alreadyDelivered };
  }
);
