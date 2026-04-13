// ============================================================
//  AGRIMORE FIREBASE CLOUD FUNCTIONS  —  FULL VERSION
// ============================================================

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import axios from "axios";
import Razorpay from "razorpay";

// Initialize only if not already initialized
if (admin.apps.length === 0) {
  admin.initializeApp();
}

// Export OTP functions (after initialization)
export { sendEmailOTP } from "./sendEmailOTP";
export { verifyEmailOTP } from "./verifyEmailOTP";

// ============================================
// CONFIGURATION
// ============================================
const APP_ICON = "https://agrimore.in/icons/Icon-192.png";
const DEFAULT_COLOR = "#4CAF50";
const NOTIFICATION_SOUND = "default";

// ============================================
// LOGGING HELPER
// ============================================
const log = {
  info: (msg: string) => console.log(`📌 ${msg}`),
  success: (msg: string) => console.log(`✅ ${msg}`),
  error: (msg: string) => console.error(`❌ ${msg}`),
  warn: (msg: string) => console.warn(`⚠️ ${msg}`),
};

// ============================================
// INTERFACES
// ============================================
interface NotificationData {
  title: string;
  body: string;
  imageUrl?: string;
  actionUrl?: string;
  type?: string;
  productId?: string;
  orderId?: string;
  orderNumber?: string;
  orderStatus?: string;
  userId?: string;
}

interface NotificationStats {
  totalNotifications: number;
  totalSuccessful: number;
  totalFailed: number;
  byType: Record<string, { count: number; successful: number; failed: number }>;
}

// ✅ Razorpay type to fix “unknown” errors
interface RazorpayPayment {
  id: string;
  entity: string;
  amount: number;
  currency: string;
  status: string;
  method: string;
  bank?: string;
  email?: string;
  contact?: string;
  [key: string]: any;
}

// ============================================
// VALIDATION HELPER
// ============================================
function validateNotificationData(
  title: string,
  body: string,
  imageUrl?: string,
  actionUrl?: string
): string[] {
  const errors: string[] = [];

  if (!title || typeof title !== "string" || title.trim().length === 0)
    errors.push("Title is required and must be a non-empty string");

  if (!body || typeof body !== "string" || body.trim().length === 0)
    errors.push("Body is required and must be a non-empty string");

  if (title && title.length > 200) errors.push("Title must not exceed 200 characters");
  if (body && body.length > 4000) errors.push("Body must not exceed 4000 characters");

  if (imageUrl && !isValidUrl(imageUrl)) errors.push("Invalid image URL format");
  if (actionUrl && !isValidUrl(actionUrl)) errors.push("Invalid action URL format");

  return errors;
}

// ============================================
// URL VALIDATION HELPER
// ============================================
function isValidUrl(string: string): boolean {
  try {
    new URL(string);
    return true;
  } catch (_) {
    return /^[/a-zA-Z0-9-_]+$/.test(string);
  }
}

// ============================================
// Helper: Create Platform-Specific Message
// ============================================
function createNotificationMessage(
  token: string,
  title: string,
  body: string,
  imageUrl?: string,
  actionUrl?: string,
  notificationType?: string,
  orderId?: string,
  orderNumber?: string,
  orderStatus?: string
): admin.messaging.Message {
  const baseMessage: admin.messaging.Message = {
    token,
    notification: { title, body },
    data: {
      click_action: "FLUTTER_NOTIFICATION_CLICK",
      timestamp: Date.now().toString(),
      type: notificationType || "general",
    },
  };

  if (orderId) baseMessage.data!.orderId = orderId;
  if (orderNumber) baseMessage.data!.orderNumber = orderNumber;
  if (orderStatus) baseMessage.data!.orderStatus = orderStatus;
  if (imageUrl) baseMessage.data!.imageUrl = imageUrl.trim();
  if (actionUrl) baseMessage.data!.actionUrl = actionUrl.trim();

  baseMessage.webpush = {
    notification: {
      icon: APP_ICON,
      badge: APP_ICON,
      vibrate: [200, 100, 200],
      ...(imageUrl && { image: imageUrl.trim() }),
    } as any,
    fcmOptions: { link: actionUrl || "/" },
  };

  baseMessage.android = {
    priority: "high",
    notification: {
      channelId: "default_channel",
      icon: "ic_notification",
      color: DEFAULT_COLOR,
      sound: NOTIFICATION_SOUND,
      clickAction: "FLUTTER_NOTIFICATION_CLICK",
      ...(imageUrl && { imageUrl: imageUrl.trim() }),
    },
  };

  baseMessage.apns = {
    headers: {
      "apns-priority": "10",
      "apns-expiration": String(Math.floor(Date.now() / 1000) + 3600),
    },
    payload: {
      aps: {
        alert: { title, body },
        badge: 1,
        sound: "default",
      },
    },
  };

  return baseMessage;
}

// ============================================
// Send Broadcast Notification
// ============================================
export const sendBroadcastNotification = functions.https.onCall(
  async (data: NotificationData, context: functions.https.CallableContext) => {
    try {
      if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "User must be authenticated");

      const { title, body, imageUrl, actionUrl, type, productId } = data;
      const errors = validateNotificationData(title, body, imageUrl, actionUrl);
      if (errors.length)
        throw new functions.https.HttpsError("invalid-argument", errors.join("; "));

      log.info("📢 Starting broadcast notification");

      const usersSnapshot = await admin.firestore().collection("users").get();
      if (usersSnapshot.empty)
        return { success: true, successCount: 0, failureCount: 0, message: "No users found" };

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

      if (!allTokens.length)
        return { success: true, successCount: 0, failureCount: 0, message: "No FCM tokens found" };

      log.info(`📊 Found ${allTokens.length} tokens`);

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
            if (
              error.code === "messaging/invalid-registration-token" ||
              error.code === "messaging/registration-token-not-registered"
            ) {
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
        sentBy: context.auth.uid,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      log.success(`Broadcast done: ${totalSuccess} success, ${totalFailure} fail`);
      return {
        success: true,
        successCount: totalSuccess,
        failureCount: totalFailure,
        totalUsers: usersSnapshot.size,
        totalTokens: allTokens.length,
      };
    } catch (error: any) {
      log.error(`Broadcast error: ${error.message}`);
      throw new functions.https.HttpsError("internal", error.message);
    }
  }
);
// ============================================
// Send Notification to a Single User
// ============================================
export const sendNotificationToUser = functions.https.onCall(
  async (data: NotificationData, context: functions.https.CallableContext) => {
    try {
      if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "User must be authenticated");

      const {
        userId,
        title,
        body,
        imageUrl,
        actionUrl,
        type,
        orderId,
        orderNumber,
        orderStatus,
        productId,
      } = data;

      if (!userId || typeof userId !== "string")
        throw new functions.https.HttpsError("invalid-argument", "userId is required");

      const errors = validateNotificationData(title, body, imageUrl, actionUrl);
      if (errors.length)
        throw new functions.https.HttpsError("invalid-argument", errors.join("; "));

      log.info(`📬 Sending notification to user: ${userId}`);

      const userDoc = await admin.firestore().collection("users").doc(userId).get();
      if (!userDoc.exists)
        throw new functions.https.HttpsError("not-found", "User not found");

      const tokens = (userDoc.data()?.fcmTokens as string[]) || [];
      if (!tokens.length)
        return { success: true, successCount: 0, failureCount: 0, message: "No tokens" };

      let successCount = 0;
      let failureCount = 0;
      const invalidTokens: string[] = [];

      for (const token of tokens) {
        try {
          const msg = createNotificationMessage(
            token,
            title,
            body,
            imageUrl,
            actionUrl,
            type,
            orderId,
            orderNumber,
            orderStatus
          );
          await admin.messaging().send(msg);
          successCount++;
        } catch (error: any) {
          failureCount++;
          if (
            error.code === "messaging/invalid-registration-token" ||
            error.code === "messaging/registration-token-not-registered"
          )
            invalidTokens.push(token);
        }
      }

      if (invalidTokens.length)
        await admin.firestore().collection("users").doc(userId).update({
          fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
        });

      await admin.firestore().collection("notification_history").add({
        type: "single",
        userId,
        title: title.trim(),
        body: body.trim(),
        imageUrl: imageUrl || null,
        actionUrl: actionUrl || null,
        notificationType: type || "general",
        orderId: orderId || null,
        orderNumber: orderNumber || null,
        orderStatus: orderStatus || null,
        productId: productId || null,
        successCount,
        failureCount,
        sentBy: context.auth.uid,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      log.success(`User ${userId}: ${successCount} sent, ${failureCount} failed`);
      return { success: true, successCount, failureCount };
    } catch (error: any) {
      log.error(`Single user error: ${error.message}`);
      throw new functions.https.HttpsError("internal", error.message);
    }
  }
);

// ============================================
// Send Order Update Notification
// ============================================
export const sendOrderUpdateNotification = functions.https.onCall(
  async (data: NotificationData, context: functions.https.CallableContext) => {
    try {
      if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "User must be authenticated");

      const { orderId, orderNumber, orderStatus } = data;
      if (!orderId || !orderNumber || !orderStatus)
        throw new functions.https.HttpsError(
          "invalid-argument",
          "orderId, orderNumber, and orderStatus are required"
        );

      log.info(`📦 Order update for ${orderNumber}`);

      const orderDoc = await admin.firestore().collection("orders").doc(orderId).get();
      if (!orderDoc.exists)
        throw new functions.https.HttpsError("not-found", "Order not found");

      const orderData = orderDoc.data();
      const userId = orderData?.userId;
      if (!userId)
        throw new functions.https.HttpsError("invalid-argument", "Order missing userId");

      const userDoc = await admin.firestore().collection("users").doc(userId).get();
      if (!userDoc.exists)
        throw new functions.https.HttpsError("not-found", "User not found");

      const tokens = (userDoc.data()?.fcmTokens as string[]) || [];
      if (!tokens.length)
        return { success: true, successCount: 0, failureCount: 0, message: "No tokens" };

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
      const finalBody =
        data.body || statusMessages[orderStatus] || `Status: ${orderStatus.toUpperCase()}`;

      let successCount = 0;
      let failureCount = 0;
      const invalidTokens: string[] = [];

      for (const token of tokens) {
        try {
          const msg = createNotificationMessage(
            token,
            title,
            finalBody,
            undefined,
            `order/${orderId}`,
            "order_update",
            orderId,
            orderNumber,
            orderStatus
          );
          await admin.messaging().send(msg);
          successCount++;
        } catch (error: any) {
          failureCount++;
          if (
            error.code === "messaging/invalid-registration-token" ||
            error.code === "messaging/registration-token-not-registered"
          )
            invalidTokens.push(token);
        }
      }

      if (invalidTokens.length)
        await admin.firestore().collection("users").doc(userId).update({
          fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
        });

      await admin.firestore().collection("notification_history").add({
        type: "order_update",
        orderId,
        orderNumber,
        userId,
        title,
        body: finalBody,
        orderStatus,
        notificationType: "order_update",
        successCount,
        failureCount,
        sentBy: context.auth.uid,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      log.success(`Order ${orderNumber}: ${successCount} ok, ${failureCount} fail`);
      return { success: true, successCount, failureCount };
    } catch (error: any) {
      log.error(`Order update error: ${error.message}`);
      throw new functions.https.HttpsError("internal", error.message);
    }
  }
);

// ============================================
// Get Notification Statistics
// ============================================
export const getNotificationStats = functions.https.onCall(async (data: any, context: functions.https.CallableContext) => {
  try {
    if (!context.auth)
      throw new functions.https.HttpsError("unauthenticated", "User must be authenticated");

    const snapshot = await admin.firestore().collection("notification_history").get();
    const stats: NotificationStats = {
      totalNotifications: snapshot.size,
      totalSuccessful: 0,
      totalFailed: 0,
      byType: {},
    };

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
    throw new functions.https.HttpsError("internal", error.message);
  }
});

// ============================================
// Create Razorpay Order (Server-side)
// ============================================
interface CreateOrderData {
  amount: number; // Amount in INR (will be converted to paise)
  currency?: string;
  receipt?: string;
  notes?: Record<string, string>;
}

export const createRazorpayOrder = functions.https.onCall(
  async (data: CreateOrderData, context: functions.https.CallableContext) => {
    try {
      // Authentication check
      if (!context.auth) {
        throw new functions.https.HttpsError(
          "unauthenticated",
          "User must be authenticated to create an order"
        );
      }

      const { amount, currency = "INR", receipt, notes } = data;

      // Validate amount
      if (!amount || amount <= 0) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Amount must be a positive number"
        );
      }

      // Get Razorpay credentials from Firebase config
      const RAZORPAY_KEY_ID = functions.config().razorpay?.key_id;
      const RAZORPAY_KEY_SECRET = functions.config().razorpay?.key_secret;

      if (!RAZORPAY_KEY_ID || !RAZORPAY_KEY_SECRET) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Razorpay credentials not configured. Run: firebase functions:config:set razorpay.key_id=YOUR_KEY razorpay.key_secret=YOUR_SECRET"
        );
      }

      // Initialize Razorpay
      const razorpay = new Razorpay({
        key_id: RAZORPAY_KEY_ID,
        key_secret: RAZORPAY_KEY_SECRET,
      });

      // Create order
      const orderOptions = {
        amount: Math.round(amount * 100), // Convert to paise
        currency: currency,
        receipt: receipt || `order_${Date.now()}`,
        notes: {
          userId: context.auth.uid,
          ...notes,
        },
      };

      log.info(`💳 Creating Razorpay order for amount: ₹${amount}`);

      const order = await razorpay.orders.create(orderOptions);

      log.success(`✅ Razorpay order created: ${order.id}`);

      // Store order in Firestore for tracking
      await admin.firestore().collection("razorpay_orders").doc(order.id).set({
        orderId: order.id,
        userId: context.auth.uid,
        amount: amount,
        amountPaise: order.amount,
        currency: order.currency,
        status: order.status,
        receipt: order.receipt,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        orderId: order.id,
        amount: order.amount,
        currency: order.currency,
        keyId: RAZORPAY_KEY_ID, // Return key ID for client
      };
    } catch (error: any) {
      log.error(`❌ Create order error: ${error.message}`);

      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      throw new functions.https.HttpsError(
        "internal",
        `Failed to create order: ${error.message}`
      );
    }
  }
);

// ============================================
// Verify Razorpay Payment  —  FIXED ✅
// ============================================
export const verifyRazorpayPayment = functions.https.onCall(async (data: any, context: functions.https.CallableContext) => {
  try {
    const { paymentId, orderId, signature, upiId } = data;
    if (!paymentId || !orderId || !signature)
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing Razorpay verification parameters"
      );

    const RAZORPAY_KEY_ID = functions.config().razorpay.key_id;
    const RAZORPAY_KEY_SECRET = functions.config().razorpay.key_secret;
    if (!RAZORPAY_KEY_ID || !RAZORPAY_KEY_SECRET)
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Razorpay credentials not configured"
      );

    const authHeader = Buffer.from(
      `${RAZORPAY_KEY_ID}:${RAZORPAY_KEY_SECRET}`
    ).toString("base64");

    const response = await axios.get(`https://api.razorpay.com/v1/payments/${paymentId}`, {
      headers: { Authorization: `Basic ${authHeader}` },
    });

    const payment = response.data as RazorpayPayment;
    const isValid = payment.status === "captured";

    if (isValid) {
      await admin.firestore().collection("verified_payments").doc(paymentId).set({
        orderId,
        paymentId,
        signature,
        upiId: upiId || null,
        verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        method: payment.method,
        bank: payment.bank || null,
        email: payment.email || null,
        contact: payment.contact || null,
        amount: payment.amount / 100,
        currency: payment.currency,
        status: payment.status,
      });
      log.success(`✅ Verified Razorpay payment: ${paymentId}`);
      return { success: true, verified: true, payment };
    } else {
      log.warn(`⚠️ Payment not captured: ${paymentId}`);
      return { success: true, verified: false, payment };
    }
  } catch (error: any) {
    log.error(`❌ Razorpay verification error: ${error.message}`);
    throw new functions.https.HttpsError("internal", error.message);
  }
});
// ============================================
// Cleanup Invalid FCM Tokens (Scheduled)
// ============================================
export const cleanupInvalidTokens = functions.pubsub
  .schedule("every day 02:00")
  .timeZone("Asia/Kolkata")
  .onRun(async () => {
    try {
      log.info("🧹 Starting invalid token cleanup");
      const usersSnapshot = await admin.firestore().collection("users").get();
      let totalRemoved = 0;

      for (const userDoc of usersSnapshot.docs) {
        const data = userDoc.data();
        const tokens = (data.fcmTokens as string[]) || [];
        if (!tokens.length) continue;

        const validTokens: string[] = [];
        for (const token of tokens) {
          try {
            const testMessage: admin.messaging.Message = {
              token,
              notification: { title: "Token Test", body: "This is a test message" },
              data: { test: "true" },
              webpush: { fcmOptions: { link: "/" } },
            };
            await admin.messaging().send(testMessage);
            validTokens.push(token);
          } catch (error: any) {
            if (
              error.code === "messaging/invalid-registration-token" ||
              error.code === "messaging/registration-token-not-registered"
            ) {
              totalRemoved++;
              log.warn(`Removed invalid token: ${token.substring(0, 20)}...`);
            } else {
              validTokens.push(token);
            }
          }
        }

        if (validTokens.length !== tokens.length) {
          await admin.firestore().collection("users").doc(userDoc.id).update({
            fcmTokens: validTokens,
          });
        }
      }

      log.success(`✅ Cleanup complete — removed ${totalRemoved} invalid token(s)`);
      return { success: true, tokensRemoved: totalRemoved };
    } catch (error: any) {
      log.error(`Cleanup error: ${error.message}`);
      return { success: false, error: error.message };
    }
  });

// ============================================
// INITIALIZATION LOG
// ============================================
log.info("🚀 Firebase Cloud Functions initialized successfully");

// ============================================================
// END OF FILE — FULL VERSION WITH ALL EXISTING CODE (900+ LINES)
// ============================================================
