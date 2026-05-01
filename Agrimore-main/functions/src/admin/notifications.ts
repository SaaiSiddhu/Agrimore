import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import { log, NotificationData, validateNotificationData, createNotificationMessage } from "../common/helpers";

const BOOTSTRAP_ADMIN_EMAILS = new Set([
  "admin@agrimore.com",
  "admin@admin.com",
  "agrimore@gmail.com",
]);

async function requireAdmin(context: functions.https.CallableContext) {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "User must be authenticated");
  }

  if (context.auth.token.admin === true) return;

  const email = String(context.auth.token.email || "").trim().toLowerCase();
  if (BOOTSTRAP_ADMIN_EMAILS.has(email)) {
    await admin.firestore().collection("users").doc(context.auth.uid).set({
      email,
      role: "admin",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    return;
  }

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

export const sendBroadcastNotification = functions.https.onCall(
  async (data: NotificationData, context) => {
    try {
      await requireAdmin(context);
      const senderUid = context.auth!.uid;

      const { title, body, imageUrl, actionUrl, type, productId } = data;
      const errors = validateNotificationData(title, body, imageUrl, actionUrl);
      if (errors.length) throw new functions.https.HttpsError("invalid-argument", errors.join("; "));

      log.info("📢 Starting broadcast notification");

      const usersSnapshot = await admin.firestore().collection("users").get();
      if (usersSnapshot.empty) return { success: true, successCount: 0, failureCount: 0, message: "No users found" };

      const allTokens: string[] = [];
      const userMapping: Record<string, string> = {};
      usersSnapshot.forEach((doc: admin.firestore.QueryDocumentSnapshot) => {
        const tokens = doc.data().fcmTokens || [];
        if (Array.isArray(tokens) && tokens.length > 0) {
          tokens.forEach((token: string) => {
            allTokens.push(token);
            userMapping[token] = doc.id;
          });
        }
      });

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
                  fcmTokens: admin.firestore.FieldValue.arrayRemove(token),
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
        totalUsers: usersSnapshot.size,
        totalTokens: allTokens.length,
        successCount: totalSuccess,
        failureCount: totalFailure,
        sentBy: senderUid,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      log.success(`Broadcast done: ${totalSuccess} success, ${totalFailure} fail`);
      return { success: true, successCount: totalSuccess, failureCount: totalFailure, totalUsers: usersSnapshot.size, totalTokens: allTokens.length };
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
        await admin.firestore().collection("users").doc(userId).update({ fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens) });

      await admin.firestore().collection("notification_history").add({
        type: "single", userId, title: title.trim(), body: body.trim(),
        imageUrl: imageUrl || null, actionUrl: actionUrl || null,
        notificationType: type || "general", orderId: orderId || null,
        orderNumber: orderNumber || null, orderStatus: orderStatus || null,
        productId: productId || null, successCount, failureCount,
        sentBy: senderUid,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
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
        pending: "Your order has been placed successfully!",
        confirmed: "Your order has been confirmed!",
        processing: "We're preparing your order...",
        shipped: "Your order is on its way! 🚚",
        outForDelivery: "Your order is out for delivery!",
        delivered: "Your order has been delivered! ✅",
        cancelled: "Your order has been cancelled.",
        returned: "Your order has been returned.",
        refunded: "Your refund has been processed.",
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
        await admin.firestore().collection("users").doc(userId).update({ fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens) });

      await admin.firestore().collection("notification_history").add({
        type: "order_update", orderId, orderNumber, userId, title, body: finalBody,
        orderStatus, notificationType: "order_update", successCount, failureCount,
        sentBy: senderUid,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
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
      
      const userDoc = await admin.firestore().collection("users").doc(userId).get();
      if (!userDoc.exists) return;

      const tokens = (userDoc.data()?.fcmTokens as string[]) || [];
      if (!tokens.length) return;

      const statusMessages: Record<string, string> = {
        pending: "Your order has been placed successfully!",
        confirmed: "Your order has been confirmed!",
        processing: "We're preparing your order...",
        shipped: "Your order is on its way! 🚚",
        outForDelivery: "Your order is out for delivery!",
        delivered: "Your order has been delivered! ✅",
        cancelled: "Your order has been cancelled.",
        returned: "Your order has been returned.",
        refunded: "Your refund has been processed.",
      };

      const title = `Order ${orderNumber} Update`;
      const finalBody = statusMessages[orderStatus] || `Status: ${orderStatus.toUpperCase()}`;

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

      if (invalidTokens.length) {
        await admin.firestore().collection("users").doc(userId).update({ fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens) });
      }

      await admin.firestore().collection("notification_history").add({
        type: "order_update_auto", orderId, orderNumber, userId, title, body: finalBody,
        orderStatus, notificationType: "order_update", successCount, failureCount,
        sentBy: "system",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });

