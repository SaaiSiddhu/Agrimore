// ============================================================
//  Callables: acceptDeliveryOffer / declineDeliveryOffer (Phase DLV-2A)
// ============================================================
//
// The only server-checked way to take an order. Until now a rider "accepted"
// by a client transaction on orders/{id} (apps/delivery order_provider.dart
// acceptOrder) that checked nothing but "still unassigned": no offer, no
// eligibility, no busy check. That legacy path stays open for the released
// May-6 build (firestore.rules deliveryPartnerCanClaimOrder) and is closed in
// a later phase once DLV-2B's build is adopted — the same order FIX-5 used.
//
// Refusals come back as failed-precondition with details.reason, one of:
//   no_offer · expired · taken · not_eligible · busy   (accept)
// A refusal that changes an offer (expired, taken) is recorded in the same
// transaction, which therefore RETURNS a verdict and the error is thrown only
// after the commit (a throwing transaction commits nothing) — the pattern
// confirmDelivery.ts uses for its attempt counter.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import {
  closeDispatch, dispatchRef, hasPartner, isReadyForPickup, offerRef,
  RIDER_ACTIVE_ORDER_STATUSES, runNextWave,
} from "./dispatch";

/** DeliveryFailureReason wire values (packages/agrimore_core delivery_enums.dart). */
const DECLINE_REASONS = new Set([
  "customer_unreachable", "customer_refused", "wrong_address", "address_not_found",
  "payment_issue", "seller_not_ready", "vehicle_issue", "safety", "other",
]);

function orderIdOf(data: unknown): string {
  const id = (data as { orderId?: unknown })?.orderId;
  if (typeof id !== "string" || !id.trim()) {
    throw new HttpsError("invalid-argument", "orderId is required");
  }
  return id.trim();
}

function refuse(reason: string, message: string): never {
  throw new HttpsError("failed-precondition", message, { reason });
}

type AcceptVerdict =
  | { kind: "accepted"; alreadyAccepted?: boolean }
  | { kind: "refused"; reason: "no_offer" | "expired" | "taken" | "not_eligible" | "busy" };

export async function acceptOfferCore(db: FirebaseFirestore.Firestore, uid: string, orderId: string, nowMs: number) {
  const oRef = offerRef(db, orderId, uid);
  const orderRef = db.collection("orders").doc(orderId);
  const partnerRef = db.collection("delivery_partners").doc(uid);
  const busyQuery = db.collection("orders")
    .where("deliveryPartnerId", "==", uid)
    .where("orderStatus", "in", RIDER_ACTIVE_ORDER_STATUSES)
    .limit(1);

  const verdict: AcceptVerdict = await db.runTransaction(async (tx): Promise<AcceptVerdict> => {
    const [offer, order, partner, busy] = await Promise.all([
      tx.get(oRef), tx.get(orderRef), tx.get(partnerRef), tx.get(busyQuery),
    ]);
    if (!offer.exists) return { kind: "refused", reason: "no_offer" };
    const o = offer.data()!;
    const rider = o.riderId ?? o.partnerId;
    if (rider !== uid) return { kind: "refused", reason: "no_offer" };
    if (o.status === "expired") return { kind: "refused", reason: "expired" };
    if (o.status === "accepted") {
      // A retry after a dropped response: already this rider's order.
      const ord = order.exists ? order.data()! : {};
      return ord.deliveryPartnerId === uid
        ? { kind: "accepted", alreadyAccepted: true }
        : { kind: "refused", reason: "taken" };
    }
    if (o.status !== "offered") return { kind: "refused", reason: "taken" };

    const expiresAt = o.expiresAt instanceof Timestamp ? o.expiresAt.toMillis() : 0;
    if (expiresAt <= nowMs) {
      tx.update(oRef, { status: "expired", updatedAt: FieldValue.serverTimestamp() });
      return { kind: "refused", reason: "expired" };
    }
    if (!order.exists) {
      tx.update(oRef, { status: "withdrawn", updatedAt: FieldValue.serverTimestamp() });
      return { kind: "refused", reason: "taken" };
    }
    const ord = order.data()!;
    if (hasPartner(ord) || !isReadyForPickup(ord)) {
      tx.update(oRef, { status: "withdrawn", updatedAt: FieldValue.serverTimestamp() });
      return { kind: "refused", reason: "taken" };
    }
    const p = partner.exists ? partner.data()! : null;
    if (!p || p.status !== "approved") return { kind: "refused", reason: "not_eligible" };
    if (!busy.empty) return { kind: "refused", reason: "busy" };

    tx.update(orderRef, {
      deliveryPartnerId: uid,
      orderStatus: "delivery_accepted",
      status: "delivery_accepted",
      deliveryAcceptedAt: FieldValue.serverTimestamp(),
      deliveryAcceptedVia: "acceptDeliveryOffer",
      updatedAt: FieldValue.serverTimestamp(),
    });
    const timeline = orderRef.collection("timeline").doc();
    tx.set(timeline, {
      id: timeline.id,
      status: "delivery_accepted",
      title: "Delivery Accepted",
      description: "Delivery partner accepted this order",
      partnerId: uid,
      timestamp: FieldValue.serverTimestamp(),
    });
    tx.update(oRef, {
      status: "accepted",
      acceptedAt: Timestamp.fromMillis(nowMs),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { kind: "accepted" };
  });

  if (verdict.kind === "refused" || verdict.alreadyAccepted) return verdict;
  // Withdraw everyone else's offer and mark the dispatch assigned. Idempotent;
  // onOrderStatusChanged calls it again on delivery_accepted.
  await closeDispatch(db, orderId, uid, nowMs, "accepted");
  return verdict;
}

export const acceptDeliveryOffer = onCall({ minInstances: 0, memory: "256MiB" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required");
  const orderId = orderIdOf(request.data);
  const v = await acceptOfferCore(admin.firestore(), request.auth.uid, orderId, Date.now());
  if (v.kind === "accepted") return { success: true, alreadyAccepted: v.alreadyAccepted === true };
  switch (v.reason) {
    case "no_offer": return refuse(v.reason, "This order was not offered to you");
    case "expired": return refuse(v.reason, "This offer has expired");
    case "taken": return refuse(v.reason, "Another delivery partner took this order");
    case "busy": return refuse(v.reason, "Finish your current delivery first");
    case "not_eligible": return refuse(v.reason, "Your account cannot take orders right now");
  }
});

export async function declineOfferCore(
  db: FirebaseFirestore.Firestore, uid: string, orderId: string, reason: string | null, nowMs: number
) {
  const oRef = offerRef(db, orderId, uid);
  const orderRef = db.collection("orders").doc(orderId);
  const dRef = dispatchRef(db, orderId);
  const declined = await db.runTransaction(async (tx): Promise<{ wave: number } | null> => {
    const [offer, order, disp] = await Promise.all([tx.get(oRef), tx.get(orderRef), tx.get(dRef)]);
    if (!offer.exists) return null;
    const o = offer.data()!;
    if ((o.riderId ?? o.partnerId) !== uid || o.status !== "offered") return null;
    tx.update(oRef, {
      status: "declined",
      declineReason: reason && DECLINE_REASONS.has(reason) ? reason : null,
      declinedAt: Timestamp.fromMillis(nowMs),
      updatedAt: FieldValue.serverTimestamp(),
    });
    // The field the rider app's denyOrder already appends to (FIX-13).
    if (order.exists) {
      tx.update(orderRef, {
        deliveryRejectedBy: FieldValue.arrayUnion(uid),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    tx.set(dRef, {
      declinedBy: FieldValue.arrayUnion(uid),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    // The wave this decline belongs to — the compare-and-swap key below.
    return { wave: disp.exists && typeof disp.data()!.wave === "number" ? disp.data()!.wave : 0 };
  });
  if (!declined) return { declined: false };

  // Everyone in this wave has answered (declined or expired): offer the next
  // wave now rather than waiting for the scheduler.
  const open = await db.collection("delivery_requests")
    .where("orderId", "==", orderId).where("status", "==", "offered").get();
  const stillOpen = open.docs.some((d) => {
    const exp = d.data().expiresAt;
    return exp instanceof Timestamp && exp.toMillis() > nowMs;
  });
  if (!stillOpen) await runNextWave(db, orderId, nowMs, { force: true, expectWave: declined.wave });
  return { declined: true, advanced: !stillOpen };
}

export const declineDeliveryOffer = onCall({ minInstances: 0, memory: "256MiB" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required");
  const orderId = orderIdOf(request.data);
  const reasonRaw = (request.data as { reason?: unknown })?.reason;
  const reason = typeof reasonRaw === "string" ? reasonRaw.trim() : null;
  // Idempotent: declining an offer that already closed is not an error.
  const r = await declineOfferCore(admin.firestore(), request.auth.uid, orderId, reason, Date.now());
  return { success: true, alreadyClosed: !r.declined };
});
