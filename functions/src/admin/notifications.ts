import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import { FieldValue, FieldPath } from "firebase-admin/firestore";
import { log, NotificationData, validateNotificationData, createNotificationMessage } from "../common/helpers";
import { closeDispatch, startDispatch } from "../delivery/dispatch";

// Phase 14, Workstream 3 fix: this used to contain a
// BOOTSTRAP_ADMIN_EMAILS allowlist and, on a match, WROTE role:"admin" onto
// the caller's own user doc via the Admin SDK (bypassing firestore.rules
// entirely) before returning success — an authorisation check that mutates
// state is itself the bug, independent of which emails were listed. Of the
// three addresses previously here, only admin@agrimore.com had a live Auth
// account; the other two were unregistered and claimable by anyone through
// open signup. requireAdmin() is now read-only: custom claim first, then
// the Firestore role, never a write.
async function requireAdmin(context: functions.https.CallableContext) {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "User must be authenticated");
  }

  if (context.auth.token.admin === true) return;

  const uid = context.auth.uid;
  const userDoc = await admin.firestore().collection("users").doc(uid).get();
  if (userDoc.data()?.role !== "admin") {
    throw new functions.https.HttpsError("permission-denied", "Admin only");
  }
}

function rethrowHttpsError(error: any): never {
  if (error instanceof functions.https.HttpsError) {
    throw error;
  }
  throw new functions.https.HttpsError("internal", error?.message || String(error));
}

function uniqueTokens(data: admin.firestore.DocumentData | undefined): string[] {
  if (!data) return [];
  const tokens = new Set<string>();
  const fcmTokens = data.fcmTokens;
  if (Array.isArray(fcmTokens)) {
    fcmTokens.forEach((token) => {
      if (typeof token === "string" && token.trim()) tokens.add(token.trim());
    });
  }
  if (typeof data.fcmToken === "string" && data.fcmToken.trim()) {
    tokens.add(data.fcmToken.trim());
  }
  return Array.from(tokens);
}

// FIX-10 (finding N-17). Bounds how many raw Firestore document snapshots
// (every field on every user document, not just what this function needs)
// are held in memory at once — the specific thing a single unbounded
// `.get()` did unboundedly. allTokens/userMapping still accumulate across
// the whole scan (this fixes the READ pattern, not the overall send-loop
// memory shape, which the contract did not ask this phase to redesign), but
// those are two flat arrays of strings, far lighter per user than a full
// document snapshot — 500 keeps each page's snapshot weight small relative
// to the 256MiB budget regardless of how large the users collection grows.
// Overridable via env for tests that need to exercise the multi-page cursor
// loop without seeding hundreds of documents; unset in every real
// deployment, so production always uses 500.
const BROADCAST_PAGE_SIZE = Number(process.env.BROADCAST_PAGE_SIZE_OVERRIDE) || 500;

// Phase DLV-2A: rider dispatch (radius, freshness, pickup point, offers)
// moved to ../delivery/dispatch.ts. The old helpers here fell back to the
// customer's delivery address as the pickup point.

async function sendOrderPushToUser(
  userId: string,
  title: string,
  body: string,
  type: string,
  orderId: string,
  orderNumber: string,
  orderStatus: string
): Promise<{ successCount: number; failureCount: number }> {
  const userRef = admin.firestore().collection("users").doc(userId);
  const userDoc = await userRef.get();
  if (!userDoc.exists) return { successCount: 0, failureCount: 0 };

  const invalidTokens: string[] = [];
  let successCount = 0;
  let failureCount = 0;

  await userRef.collection("notifications").add({
    title,
    body,
    type,
    data: { orderId, orderNumber, orderStatus, actionUrl: `order/${orderId}` },
    unread: true,
    createdAt: FieldValue.serverTimestamp(),
  });

  for (const token of uniqueTokens(userDoc.data())) {
    try {
      await admin.messaging().send(
        createNotificationMessage(token, title, body, undefined, `order/${orderId}`, type, orderId, orderNumber, orderStatus)
      );
      successCount++;
    } catch (error: any) {
      failureCount++;
      if (
        error.code === "messaging/invalid-registration-token" ||
        error.code === "messaging/registration-token-not-registered"
      ) {
        invalidTokens.push(token);
      }
    }
  }

  if (invalidTokens.length) {
    await userRef.update({
      fcmTokens: FieldValue.arrayRemove(...invalidTokens),
    });
  }

  return { successCount, failureCount };
}


export const sendBroadcastNotification = functions.https.onCall(
  async (data: NotificationData, context) => {
    try {
      await requireAdmin(context);
      const senderUid = context.auth!.uid;

      const { title, body, imageUrl, actionUrl, type, productId } = data;
      const errors = validateNotificationData(title, body, imageUrl, actionUrl);
      if (errors.length) throw new functions.https.HttpsError("invalid-argument", errors.join("; "));

      log.info("📢 Starting broadcast notification");

      // FIX-10 (finding N-17). Was a single `collection("users").get()` —
      // the ENTIRE users collection loaded into this 256MiB callable's
      // memory in one shot, with no bound on how large that collection
      // grows. Paginated at BROADCAST_PAGE_SIZE per page instead; the
      // running totals below (totalUsers, allTokens) are identical to what
      // a single unbounded read would have produced — this changes how the
      // data is FETCHED, not what the admin UI's delivery-count contract
      // reports (the stop condition this phase was given).
      const usersRef = admin.firestore().collection("users");
      let totalUsers = 0;
      const allTokens: string[] = [];
      const userMapping: Record<string, string> = {};
      let lastDoc: admin.firestore.QueryDocumentSnapshot | null = null;
      for (;;) {
        let pageQuery = usersRef.orderBy(FieldPath.documentId()).limit(BROADCAST_PAGE_SIZE);
        if (lastDoc) pageQuery = pageQuery.startAfter(lastDoc.id);
        const page = await pageQuery.get();
        if (page.empty) break;
        totalUsers += page.size;
        page.forEach((doc: admin.firestore.QueryDocumentSnapshot) => {
          // FIX-10 (finding N-16). Was `doc.data().fcmTokens || []` — the
          // ARRAY field only, unlike sendOrderPushToUser below (the only
          // other caller of uniqueTokens()), which also falls back to the
          // singular fcmToken field. A user whose token exists only in that
          // singular shape (a stale document from before fcm_service.dart
          // started writing both, or any future regression that writes only
          // one) was silently excluded from every broadcast. Same helper,
          // same fallback, now shared instead of duplicated and drifting.
          for (const token of uniqueTokens(doc.data())) {
            allTokens.push(token);
            userMapping[token] = doc.id;
          }
        });
        lastDoc = page.docs[page.docs.length - 1];
        if (page.size < BROADCAST_PAGE_SIZE) break;
      }

      if (!totalUsers) return { success: true, successCount: 0, failureCount: 0, message: "No users found" };
      if (!allTokens.length) return { success: true, successCount: 0, failureCount: 0, message: "No FCM tokens found" };

      let totalSuccess = 0;
      let totalFailure = 0;
      const batchSize = 500;

      for (let i = 0; i < allTokens.length; i += batchSize) {
        const batch = allTokens.slice(i, i + batchSize);
        const promises = batch.map(async (token: string) => {
          try {
            const msg = createNotificationMessage(token, title, body, imageUrl, actionUrl, type);
            await admin.messaging().send(msg);
            totalSuccess++;
          } catch (error: any) {
            totalFailure++;
            if (error.code === "messaging/invalid-registration-token" || error.code === "messaging/registration-token-not-registered") {
              const userId = userMapping[token];
              if (userId)
                await admin.firestore().collection("users").doc(userId).update({
                  fcmTokens: FieldValue.arrayRemove(token),
                });
            }
          }
        });
        await Promise.all(promises);
      }

      await admin.firestore().collection("notification_history").add({
        type: "broadcast",
        title: title.trim(),
        body: body.trim(),
        imageUrl: imageUrl || null,
        actionUrl: actionUrl || null,
        notificationType: type || "general",
        productId: productId || null,
        totalUsers,
        totalTokens: allTokens.length,
        successCount: totalSuccess,
        failureCount: totalFailure,
        sentBy: senderUid,
        timestamp: FieldValue.serverTimestamp(),
        sentAt: FieldValue.serverTimestamp(),
      });

      log.success(`Broadcast done: ${totalSuccess} success, ${totalFailure} fail`);
      return { success: true, successCount: totalSuccess, failureCount: totalFailure, totalUsers, totalTokens: allTokens.length };
    } catch (error: any) {
      log.error(`Broadcast error: ${error.message}`);
      rethrowHttpsError(error);
    }
  }
);

export const sendNotificationToUser = functions.https.onCall(
  async (data: NotificationData, context) => {
    try {
      await requireAdmin(context);
      const senderUid = context.auth!.uid;

      const { userId, title, body, imageUrl, actionUrl, type, orderId, orderNumber, orderStatus, productId } = data;

      if (!userId || typeof userId !== "string") throw new functions.https.HttpsError("invalid-argument", "userId is required");

      const errors = validateNotificationData(title, body, imageUrl, actionUrl);
      if (errors.length) throw new functions.https.HttpsError("invalid-argument", errors.join("; "));

      log.info(`📬 Sending notification to user: ${userId}`);

      const userDoc = await admin.firestore().collection("users").doc(userId).get();
      if (!userDoc.exists) throw new functions.https.HttpsError("not-found", "User not found");

      const tokens = (userDoc.data()?.fcmTokens as string[]) || [];
      if (!tokens.length) return { success: true, successCount: 0, failureCount: 0, message: "No tokens" };

      let successCount = 0;
      let failureCount = 0;
      const invalidTokens: string[] = [];

      for (const token of tokens) {
        try {
          const msg = createNotificationMessage(token, title, body, imageUrl, actionUrl, type, orderId, orderNumber, orderStatus);
          await admin.messaging().send(msg);
          successCount++;
        } catch (error: any) {
          failureCount++;
          if (error.code === "messaging/invalid-registration-token" || error.code === "messaging/registration-token-not-registered")
            invalidTokens.push(token);
        }
      }

      if (invalidTokens.length)
        await admin.firestore().collection("users").doc(userId).update({ fcmTokens: FieldValue.arrayRemove(...invalidTokens) });

      await admin.firestore().collection("notification_history").add({
        type: "single", userId, title: title.trim(), body: body.trim(),
        imageUrl: imageUrl || null, actionUrl: actionUrl || null,
        notificationType: type || "general", orderId: orderId || null,
        orderNumber: orderNumber || null, orderStatus: orderStatus || null,
        productId: productId || null, successCount, failureCount,
        sentBy: senderUid,
        timestamp: FieldValue.serverTimestamp(),
        sentAt: FieldValue.serverTimestamp(),
      });

      log.success(`User ${userId}: ${successCount} sent, ${failureCount} failed`);
      return { success: true, successCount, failureCount };
    } catch (error: any) {
      log.error(`Single user error: ${error.message}`);
      rethrowHttpsError(error);
    }
  }
);

export const sendOrderUpdateNotification = functions.https.onCall(
  async (data: NotificationData, context) => {
    try {
      await requireAdmin(context);
      const senderUid = context.auth!.uid;

      const { orderId, orderNumber, orderStatus } = data;
      if (!orderId || !orderNumber || !orderStatus)
        throw new functions.https.HttpsError("invalid-argument", "orderId, orderNumber, and orderStatus are required");

      log.info(`📦 Order update for ${orderNumber}`);

      const orderDoc = await admin.firestore().collection("orders").doc(orderId).get();
      if (!orderDoc.exists) throw new functions.https.HttpsError("not-found", "Order not found");

      const userId = orderDoc.data()?.userId;
      if (!userId) throw new functions.https.HttpsError("invalid-argument", "Order missing userId");

      const userDoc = await admin.firestore().collection("users").doc(userId).get();
      if (!userDoc.exists) throw new functions.https.HttpsError("not-found", "User not found");

      const tokens = (userDoc.data()?.fcmTokens as string[]) || [];
      if (!tokens.length) return { success: true, successCount: 0, failureCount: 0, message: "No tokens" };

      const statusMessages: Record<string, string> = {
        pending: "Order Received! We've successfully received your order and it's awaiting confirmation.",
        confirmed: "Order Confirmed! Your order is being processed and will be shipped soon.",
        processing: "Preparing Your Order! We are carefully packing your items.",
        ready_for_pickup: "Your order is packed and waiting for pickup.",
        delivery_accepted: "A delivery partner has accepted your order.",
        arrived_at_store: "The delivery partner reached the seller store.",
        picked_up: "Your order has been picked up from the seller.",
        out_for_delivery: "Out for Delivery! Your order will reach you today.",
        outfordelivery: "Out for Delivery! Your order will reach you today.",
        shipped: "Order Dispatched! Your items are on the way. Track your shipment. 🚚",
        outForDelivery: "Out for Delivery! Your order will reach you today. Keep an eye out! 📦",
        delivered: "Order Delivered! Your package has arrived safely. Thank you for shopping with Agrimore! ✅",
        cancelled: "Order Cancelled. If you have any questions, please contact support.",
        returned: "Return Processed. Your returned items have been received.",
        refunded: "Refund Initiated. Your refund has been successfully processed to your original payment method.",
      };

      const title = `Order ${orderNumber} Update`;
      const finalBody = data.body || statusMessages[orderStatus] || `Status: ${orderStatus.toUpperCase()}`;

      let successCount = 0;
      let failureCount = 0;
      const invalidTokens: string[] = [];

      for (const token of tokens) {
        try {
          const msg = createNotificationMessage(token, title, finalBody, undefined, `order/${orderId}`, "order_update", orderId, orderNumber, orderStatus);
          await admin.messaging().send(msg);
          successCount++;
        } catch (error: any) {
          failureCount++;
          if (error.code === "messaging/invalid-registration-token" || error.code === "messaging/registration-token-not-registered")
            invalidTokens.push(token);
        }
      }

      if (invalidTokens.length)
        await admin.firestore().collection("users").doc(userId).update({ fcmTokens: FieldValue.arrayRemove(...invalidTokens) });

      await admin.firestore().collection("notification_history").add({
        type: "order_update", orderId, orderNumber, userId, title, body: finalBody,
        orderStatus, notificationType: "order_update", successCount, failureCount,
        sentBy: senderUid,
        timestamp: FieldValue.serverTimestamp(),
        sentAt: FieldValue.serverTimestamp(),
      });

      log.success(`Order ${orderNumber}: ${successCount} ok, ${failureCount} fail`);
      return { success: true, successCount, failureCount };
    } catch (error: any) {
      log.error(`Order update error: ${error.message}`);
      rethrowHttpsError(error);
    }
  }
);

interface NotificationStats {
  totalNotifications: number;
  totalSuccessful: number;
  totalFailed: number;
  byType: Record<string, { count: number; successful: number; failed: number }>;
}

export const getNotificationStats = functions.https.onCall(async (_data, context) => {
  try {
    await requireAdmin(context);

    const snapshot = await admin.firestore().collection("notification_history").get();
    const stats: NotificationStats = { totalNotifications: snapshot.size, totalSuccessful: 0, totalFailed: 0, byType: {} };

    snapshot.forEach((doc: admin.firestore.QueryDocumentSnapshot) => {
      const d = doc.data();
      stats.totalSuccessful += d.successCount || 0;
      stats.totalFailed += d.failureCount || 0;
      const type = d.notificationType || "general";
      if (!stats.byType[type]) stats.byType[type] = { count: 0, successful: 0, failed: 0 };
      stats.byType[type].count++;
      stats.byType[type].successful += d.successCount || 0;
      stats.byType[type].failed += d.failureCount || 0;
    });

    return { success: true, stats };
  } catch (error: any) {
    log.error(`Stats error: ${error.message}`);
    rethrowHttpsError(error);
  }
});

// ============================================
// REAL-TIME FIRESTORE TRIGGERS
// ============================================

export const onOrderStatusChanged = functions.firestore
  .document("orders/{orderId}")
  .onUpdate(async (change, context) => {
    const orderId = context.params.orderId;
    const beforeData = change.before.data();
    const afterData = change.after.data();

    if (beforeData.orderStatus !== afterData.orderStatus) {
      log.info(`[AutoTrigger] Order ${orderId} status changed from ${beforeData.orderStatus} to ${afterData.orderStatus}`);
      
      const userId = afterData.userId;
      const orderNumber = afterData.orderNumber || orderId;
      const orderStatus = afterData.orderStatus;

      const statusMessages: Record<string, string> = {
        pending: "Order Received! We've successfully received your order and it's awaiting confirmation.",
        confirmed: "Order Confirmed! Your order is being processed and will be shipped soon.",
        processing: "Preparing Your Order! We are carefully packing your items.",
        ready_for_pickup: "Your order is packed and waiting for pickup.",
        delivery_accepted: "A delivery partner has accepted your order.",
        arrived_at_store: "The delivery partner reached the seller store.",
        picked_up: "Your order has been picked up from the seller.",
        out_for_delivery: "Out for Delivery! Your order will reach you today.",
        outfordelivery: "Out for Delivery! Your order will reach you today.",
        shipped: "Order Dispatched! Your items are on the way. Track your shipment. 🚚",
        outForDelivery: "Out for Delivery! Your order will reach you today. Keep an eye out! 📦",
        delivered: "Order Delivered! Your package has arrived safely. Thank you for shopping with Agrimore! ✅",
        cancelled: "Order Cancelled. If you have any questions, please contact support.",
        returned: "Return Processed. Your returned items have been received.",
        refunded: "Refund Initiated. Your refund has been successfully processed to your original payment method.",
      };

      const title = `Order ${orderNumber} Update`;
      const finalBody = statusMessages[orderStatus] || `Status: ${orderStatus.toUpperCase()}`;

      let successCount = 0;
      let failureCount = 0;
      if (userId) {
        const customerResult = await sendOrderPushToUser(
          userId,
          title,
          finalBody,
          "order_update",
          orderId,
          orderNumber,
          orderStatus
        );
        successCount += customerResult.successCount;
        failureCount += customerResult.failureCount;
      }

      // Phase DLV-2A: first wave of offers (nearest 3 eligible riders); the
      // advanceDeliveryDispatch scheduler runs the later waves and retries.
      let deliveryTargets = 0;
      if (orderStatus === "ready_for_pickup") {
        try {
          const r = await startDispatch(admin.firestore(), orderId, afterData, Date.now());
          deliveryTargets = r.started && "offered" in r ? r.offered.length : 0;
        } catch (e) {
          log.error(`[AutoTrigger] dispatch failed for ${orderId}: ${(e as Error)?.message ?? e}`);
        }
      }

      if (orderStatus === "delivery_accepted" && afterData.deliveryPartnerId) {
        await closeDispatch(admin.firestore(), orderId, String(afterData.deliveryPartnerId), Date.now(), "accepted");
      }

      if (afterData.sellerId && [
        "delivery_accepted",
        "arrived_at_store",
        "picked_up",
        "out_for_delivery",
        "outForDelivery",
        "outfordelivery",
        "delivered",
        "cancelled",
      ].includes(orderStatus)) {
        const sellerResult = await sendOrderPushToUser(
          afterData.sellerId,
          "Delivery update",
          `Order ${orderNumber}: ${finalBody}`,
          "seller_order_update",
          orderId,
          orderNumber,
          orderStatus
        );
        successCount += sellerResult.successCount;
        failureCount += sellerResult.failureCount;
      }

      await admin.firestore().collection("notification_history").add({
        type: "order_update_auto", orderId, orderNumber, userId, title, body: finalBody,
        orderStatus, notificationType: "order_update", successCount, failureCount,
        deliveryTargets,
        sentBy: "system",
        timestamp: FieldValue.serverTimestamp(),
        sentAt: FieldValue.serverTimestamp(),
      });
    }
  });

