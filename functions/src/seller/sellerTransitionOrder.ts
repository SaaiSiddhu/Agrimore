// ============================================================
//  Callable: sellerTransitionOrder (Phase SELLER-ORDERS-1, ADR-S13)
// ============================================================
//
// The ONLY way a seller changes an order's status. Before this phase the
// seller app wrote orderStatus directly (firestore.rules let a seller write
// ANY status, including 'delivered', which fires commission payouts) and
// ALSO decremented stock on accept — a second time, since createOrder.ts
// already decrements at placement. This callable:
//   - checks the caller is an approved seller who owns the order,
//   - allows only these transitions:
//       accept  pending            → confirmed        (COD or paid only)
//       reject  pending            → cancelled        (reason required)
//       pack    confirmed          → processing
//       ready   processing         → ready_for_pickup
//       cancel  confirmed|processing → cancelled      (reason required)
//   - never touches stock, at all, for any action (Phase ADMR-1). It used to
//     restore stock itself on reject/cancel, base-field-only — wrong for a
//     variant line, and a silent no-op for every OTHER cancellation path (a
//     customer's own cancel, or apps/admin's direct orderStatus write,
//     neither of which ever went through this callable). Restoration is now
//     restoreStockOnCancellation.ts's job: a generic trigger that fires on
//     ANY transition into 'cancelled' and restores the exact unit
//     createOrder.ts took — base or variant — exactly once, regardless of
//     who wrote it. See that file's header for the full rationale.
//   - marks prepaid cancellations refundStatus: 'pending' for the refund
//     process (automation is an open owner decision, D-REFUND-AUTOMATION),
//   - writes the order timeline. The buyer push is sent by the existing
//     onOrderStatusChanged trigger; credit, commission and stock reversals
//     by the existing cancellation triggers.
//
// Generation: v2 onCall, no secrets.

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

export type SellerOrderAction = "accept" | "reject" | "pack" | "ready" | "cancel";

export const REJECT_REASONS = [
  "out_of_stock",
  "cannot_deliver_area",
  "price_error",
  "shop_closed",
  "other",
] as const;

interface Transition {
  from: readonly string[];
  to: string;
  needsReason: boolean;
}

export const TRANSITIONS: Record<SellerOrderAction, Transition> = {
  accept: { from: ["pending"], to: "confirmed", needsReason: false },
  reject: { from: ["pending"], to: "cancelled", needsReason: true },
  pack: { from: ["confirmed"], to: "processing", needsReason: false },
  ready: { from: ["processing"], to: "ready_for_pickup", needsReason: false },
  cancel: { from: ["confirmed", "processing"], to: "cancelled", needsReason: true },
};

const TIMELINE_TITLES: Record<string, string> = {
  confirmed: "Order accepted by seller",
  processing: "Seller is packing your order",
  ready_for_pickup: "Order packed and ready for pickup",
  cancelled: "Order cancelled by seller",
};

const MAX_NOTE = 300;

export function isCashOnDelivery(paymentMethod: unknown): boolean {
  const m = String(paymentMethod ?? "").toLowerCase();
  return m === "cod" || m === "cash_on_delivery" || m.includes("cash");
}

export function isPaid(paymentStatus: unknown): boolean {
  const s = String(paymentStatus ?? "").toLowerCase();
  return s === "paid" || s === "success" || s === "completed" || s === "captured";
}

/** Pure transition check — unit-tested without an emulator. Returns an error code or null. */
export function checkTransition(
  action: string,
  currentStatus: string,
  order: { paymentMethod?: unknown; paymentStatus?: unknown },
  reason: unknown
): { code: "invalid-argument" | "failed-precondition"; message: string } | null {
  const t = TRANSITIONS[action as SellerOrderAction];
  if (!t) return { code: "invalid-argument", message: "Unknown action." };
  if (!t.from.includes(currentStatus)) {
    return { code: "failed-precondition", message: `Cannot ${action} an order that is ${currentStatus}.` };
  }
  if (t.needsReason && !(REJECT_REASONS as readonly string[]).includes(String(reason))) {
    return { code: "invalid-argument", message: "A reason is required." };
  }
  if (action === "accept" && !isCashOnDelivery(order.paymentMethod) && !isPaid(order.paymentStatus)) {
    return { code: "failed-precondition", message: "Payment for this order is not complete." };
  }
  return null;
}

async function requireApprovedSeller(uid: string, token: Record<string, unknown>): Promise<void> {
  if (token.seller === true || token.role === "seller") return;
  const snap = await admin.firestore().collection("sellers").doc(uid).get();
  if (snap.exists && snap.data()?.status === "approved") return;
  throw new HttpsError("permission-denied", "Only approved sellers can update orders.");
}

export const sellerTransitionOrder = onCall(
  { minInstances: 0, memory: "256MiB" },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required");
    const uid = request.auth.uid;
    const { orderId, action, reason, note } = (request.data ?? {}) as Record<string, unknown>;
    if (typeof orderId !== "string" || orderId.length === 0) {
      throw new HttpsError("invalid-argument", "orderId is required.");
    }
    if (typeof action !== "string") throw new HttpsError("invalid-argument", "action is required.");
    if (note !== undefined && (typeof note !== "string" || note.length > MAX_NOTE)) {
      throw new HttpsError("invalid-argument", "Note is too long.");
    }
    await requireApprovedSeller(uid, request.auth.token as Record<string, unknown>);

    const db = admin.firestore();
    const orderRef = db.collection("orders").doc(orderId);

    const result = await db.runTransaction(async (tx) => {
      const snap = await tx.get(orderRef);
      if (!snap.exists) throw new HttpsError("not-found", "Order not found.");
      const order = snap.data()!;
      if (order.sellerId !== uid) throw new HttpsError("permission-denied", "This order belongs to another seller.");

      const current = String(order.orderStatus ?? "pending");
      const problem = checkTransition(action, current, order, reason);
      if (problem) throw new HttpsError(problem.code, problem.message);

      const t = TRANSITIONS[action as SellerOrderAction];
      const cancelling = t.to === "cancelled";

      const now = admin.firestore.FieldValue.serverTimestamp();
      const update: Record<string, unknown> = {
        orderStatus: t.to,
        status: t.to,
        updatedAt: now,
      };
      if (action === "accept") Object.assign(update, { sellerDecision: "accepted", acceptedAt: now });
      if (action === "pack") update.packingStartedAt = now;
      if (action === "ready") update.readyForPickupAt = now;
      if (cancelling) {
        Object.assign(update, {
          sellerDecision: action === "reject" ? "rejected" : "cancelled",
          cancelledBy: "seller",
          cancelledAt: now,
          cancellationReason: reason,
          ...(typeof note === "string" && note.trim() ? { cancellationNote: note.trim() } : {}),
          ...(isPaid(order.paymentStatus) && !isCashOnDelivery(order.paymentMethod)
            ? { refundStatus: "pending" }
            : {}),
        });
      }
      // Stock restoration on cancel/reject is NOT done here — see the
      // header comment above and restoreStockOnCancellation.ts.

      tx.update(orderRef, update);
      tx.set(orderRef.collection("timeline").doc(), {
        status: t.to,
        title: TIMELINE_TITLES[t.to] ?? t.to,
        actor: "seller",
        ...(cancelling ? { reason } : {}),
        timestamp: now,
      });
      return { status: t.to };
    });

    return result;
  }
);
