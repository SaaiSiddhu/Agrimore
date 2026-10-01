import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { createHash } from "crypto";
import { checkoutRequestDocId, isCheckoutOrderReceipt } from "./checkoutRequest";
import { MAX_CART_LINES } from "./orderPricing";

function needsReview(): never {
  throw new HttpsError("failed-precondition", "Auto-Delivery setup needs review");
}

function validIds(value: unknown): value is string[] {
  return Array.isArray(value) && value.length > 0 && value.length <= MAX_CART_LINES &&
    value.every(id => typeof id === "string" && /^[a-f0-9]{64}$/.test(id)) &&
    new Set(value).size === value.length;
}

// Retryable setup only. Recurring fulfilment remains the deployed orphan
// subscriptionChecker's responsibility; its source is not in this repository.
// Prices and quantities come from CF-created orders, never caller input.
export const ensureCheckoutSubscriptions = onCall(
  { minInstances: 0, memory: "256MiB" },
  async request => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Sign in to finish checkout");
    const uid = request.auth.uid;
    const { checkoutOwnerId, checkoutRequestId } = request.data || {};
    if (typeof checkoutOwnerId !== "string" || !checkoutOwnerId || checkoutOwnerId.length > 128 ||
        typeof checkoutRequestId !== "string" || !/^[A-Za-z0-9_-]{8,128}$/.test(checkoutRequestId)) {
      throw new HttpsError("invalid-argument", "Missing checkout details");
    }
    if (checkoutOwnerId !== uid) throw new HttpsError("permission-denied", "Checkout does not belong to this account");
    const db = admin.firestore();
    const anchorRef = db.collection("checkout_requests").doc(checkoutRequestDocId(uid, checkoutRequestId));
    const subscriptionIds = await db.runTransaction(async tx => {
      const anchor = (await tx.get(anchorRef)).data();
      if (!anchor || anchor.uid !== uid || anchor.requestId !== checkoutRequestId ||
          anchor.status !== "completed" || !isCheckoutOrderReceipt(anchor.orders)) needsReview();
      // The marker is server-only and is atomic with the original creates.
      // Return it without recreating a subscription the customer deleted,
      // reactivating a paused one, or resetting a scheduler's nextRunDate.
      if (anchor.subscriptionIds !== undefined) {
        if (!validIds(anchor.subscriptionIds)) needsReview();
        return anchor.subscriptionIds;
      }
      const snapshots = await tx.getAll(...anchor.orders.map(order => db.collection("orders").doc(order.orderId)));
      const entries: { id: string; data: admin.firestore.DocumentData }[] = [];
      for (let i = 0; i < snapshots.length; i++) {
        const order = snapshots[i].data(), receipt = anchor.orders[i];
        if (!order || order.userId !== uid || order.id !== receipt.orderId ||
            order.orderNumber !== receipt.orderNumber || (order.sellerId ?? "") !== receipt.sellerId ||
            order.total !== receipt.total || order.orderMode !== "B2C" || order.orderType !== "Auto Delivery" ||
            !["Daily", "Weekly"].includes(order.autoFrequency) ||
            !["cod", "razorpay"].includes(order.paymentMethod) ||
            (order.paymentMethod === "razorpay" && order.paymentStatus !== "paid") ||
            order.orderStatus === "cancelled" || order.status === "cancelled" ||
            ["refunded", "refund_pending"].includes(order.paymentStatus) ||
            !Array.isArray(order.items) || order.items.length === 0 || order.items.length > MAX_CART_LINES) needsReview();
        const address = order.deliveryAddress;
        if (!address || typeof address !== "object" || Array.isArray(address) ||
            typeof address.name !== "string" || typeof address.phone !== "string" ||
            typeof address.addressLine1 !== "string") needsReview();
        for (let j = 0; j < order.items.length; j++) {
          const item = order.items[j];
          if (!item || typeof item.productId !== "string" || !item.productId ||
              !Number.isSafeInteger(item.quantity) || item.quantity <= 0 ||
              typeof item.price !== "number" || !Number.isFinite(item.price) || item.price < 0 ||
              !Number.isSafeInteger(Math.round(item.price * 100)) ||
              typeof item.productName !== "string" || typeof item.productImage !== "string") needsReview();
          const id = createHash("sha256").update(JSON.stringify([uid, checkoutRequestId, order.id, j])).digest("hex");
          entries.push({ id, data: {
            userId: uid, userName: address.name, userPhone: address.phone,
            productId: item.productId, productName: item.productName,
            price: item.price, quantity: item.quantity, productImage: item.productImage,
            unit: typeof item.variant === "string" && item.variant ? item.variant : "nos",
            address: address.addressLine1,
            location: { lat: address.latitude ?? null, lng: address.longitude ?? null },
            frequency: order.autoFrequency.toLowerCase(), deliverySlot: order.deliverySlot ?? "",
            isActive: true, paymentMethod: order.paymentMethod,
            sourceCheckoutRequestId: checkoutRequestId, sourceOrderId: order.id,
          } });
        }
      }
      if (entries.length === 0 || entries.length > MAX_CART_LINES) needsReview();
      const refs = entries.map(entry => db.collection("subscriptions").doc(entry.id));
      const existing = await tx.getAll(...refs);
      // Client subscription creation is still permitted for legacy builds.
      // A pre-existing deterministic ID must never be silently trusted or
      // overwritten; no partial subscription set/marker is committed.
      if (existing.some(snapshot => snapshot.exists)) needsReview();
      const nextRunDate = admin.firestore.Timestamp.fromMillis(Date.now() + 24 * 60 * 60 * 1000);
      for (let i = 0; i < entries.length; i++) {
        tx.create(refs[i], { ...entries[i].data, nextRunDate,
          createdAt: admin.firestore.FieldValue.serverTimestamp() });
      }
      const ids = entries.map(entry => entry.id);
      tx.update(anchorRef, { subscriptionIds: ids,
        subscriptionsInitializedAt: admin.firestore.FieldValue.serverTimestamp() });
      return ids;
    });
    return { success: true, checkoutRequestId, subscriptionIds };
  }
);
