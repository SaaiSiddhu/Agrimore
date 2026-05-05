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

const DELIVERY_ASSIGNMENT_RADIUS_KM = 5;
const DELIVERY_REQUEST_LIMIT = 12;
const DELIVERY_LOCATION_FRESHNESS_MS = 30 * 60 * 1000;

function numberValue(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim()) {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return null;
}

function distanceKm(
  startLat: number,
  startLng: number,
  endLat: number,
  endLng: number
): number {
  const earthRadiusKm = 6371;
  const degToRad = (degrees: number) => (degrees * Math.PI) / 180;
  const dLat = degToRad(endLat - startLat);
  const dLng = degToRad(endLng - startLng);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(degToRad(startLat)) *
      Math.cos(degToRad(endLat)) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);
  return earthRadiusKm * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function timestampMillis(value: unknown): number | null {
  if (!value) return null;
  if (value instanceof admin.firestore.Timestamp) return value.toMillis();
  if (typeof (value as any).toDate === "function") {
    return (value as any).toDate().getTime();
  }
  return null;
}

function hasFreshPartnerLocation(partner: admin.firestore.DocumentData): boolean {
  const lastUpdate = timestampMillis(partner.lastLocationUpdate);
  if (!lastUpdate) return false;
  return Date.now() - lastUpdate <= DELIVERY_LOCATION_FRESHNESS_MS;
}

function readPoint(
  data: admin.firestore.DocumentData | undefined,
  latKeys: string[],
  lngKeys: string[]
): { lat: number; lng: number } | null {
  if (!data) return null;
  for (const latKey of latKeys) {
    for (const lngKey of lngKeys) {
      const lat = numberValue(data[latKey]);
      const lng = numberValue(data[lngKey]);
      if (lat !== null && lng !== null) return { lat, lng };
    }
  }
  return null;
}

async function resolvePickupPoint(
  order: admin.firestore.DocumentData
): Promise<{ lat: number; lng: number; source: string } | null> {
  const directPoint = readPoint(
    order,
    ["pickupLat", "sellerLat", "storeLat", "currentLat", "lat", "latitude"],
    ["pickupLng", "sellerLng", "storeLng", "currentLng", "lng", "longitude"]
  );
  if (directPoint) return { ...directPoint, source: "order" };

  for (const key of ["pickupLocation", "sellerLocation", "storeLocation"]) {
    const nestedPoint = readPoint(order[key], ["lat", "latitude"], ["lng", "longitude"]);
    if (nestedPoint) return { ...nestedPoint, source: key };
  }

  const sellerId = String(order.sellerId || "").trim();
  if (sellerId) {
    for (const collectionName of ["sellers", "users"]) {
      const sellerDoc = await admin.firestore().collection(collectionName).doc(sellerId).get();
      const sellerPoint = readPoint(
        sellerDoc.data(),
        ["currentLat", "storeLat", "shopLat", "lat", "latitude"],
        ["currentLng", "storeLng", "shopLng", "lng", "longitude"]
      );
      if (sellerPoint) return { ...sellerPoint, source: collectionName };
    }
  }

  const addressPoint = readPoint(
    order.deliveryAddress,
    ["latitude", "lat"],
    ["longitude", "lng"]
  );
  return addressPoint ? { ...addressPoint, source: "deliveryAddress" } : null;
}

function matchesDeliveryArea(
  partner: admin.firestore.DocumentData,
  orderAddress: admin.firestore.DocumentData
): boolean {
  const partnerPincode = String(partner.pincode || "").trim();
  const orderPincode = String(orderAddress.pincode || orderAddress.zipcode || "").trim();
  if (partnerPincode && orderPincode && partnerPincode === orderPincode) return true;

  const partnerCity = String(partner.city || "").trim().toLowerCase();
  const orderCity = String(orderAddress.city || "").trim().toLowerCase();
  return !!partnerCity && !!orderCity && partnerCity === orderCity;
}

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
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
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
      fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
    });
  }

  return { successCount, failureCount };
}

async function notifyDeliveryPartnersForPickup(
  orderId: string,
  orderNumber: string,
  order: admin.firestore.DocumentData
): Promise<number> {
  const orderAddress = (order.deliveryAddress || {}) as admin.firestore.DocumentData;
  const partners = await admin
    .firestore()
    .collection("delivery_partners")
    .where("status", "==", "approved")
    .where("isOnline", "==", true)
    .get();

  const pickupPoint = await resolvePickupPoint(order);
  const partnersByDistance = pickupPoint
    ? partners.docs
        .map((doc) => {
          const partner = doc.data();
          const partnerLat = numberValue(partner.currentLat);
          const partnerLng = numberValue(partner.currentLng);
          if (
            partnerLat === null ||
            partnerLng === null ||
            !hasFreshPartnerLocation(partner)
          ) {
            return null;
          }
          return {
            doc,
            distance: distanceKm(pickupPoint.lat, pickupPoint.lng, partnerLat, partnerLng),
          };
        })
        .filter((entry): entry is { doc: admin.firestore.QueryDocumentSnapshot; distance: number } => !!entry)
        .filter((entry) => entry.distance <= DELIVERY_ASSIGNMENT_RADIUS_KM)
        .sort((a, b) => a.distance - b.distance)
    : [];

  const fallbackPartners = partners.docs
    .filter((doc) => matchesDeliveryArea(doc.data(), orderAddress))
    .map((doc) => ({ doc, distance: null as number | null }));

  const selectedPartners = (partnersByDistance.length
    ? partnersByDistance
    : fallbackPartners).slice(0, DELIVERY_REQUEST_LIMIT);

  if (!selectedPartners.length) return 0;

  const batch = admin.firestore().batch();
  selectedPartners.forEach(({ doc, distance }) => {
    const requestId = `${orderId}_${doc.id}`;
    const request = {
      requestId,
      orderId,
      orderNumber,
      partnerId: doc.id,
      sellerId: order.sellerId || null,
      userId: order.userId || null,
      status: "pending",
      distanceKm: distance === null ? null : Number(distance.toFixed(2)),
      pickupLat: pickupPoint?.lat ?? null,
      pickupLng: pickupPoint?.lng ?? null,
      pickupSource: pickupPoint?.source ?? null,
      radiusKm: DELIVERY_ASSIGNMENT_RADIUS_KM,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    batch.set(
      admin.firestore().collection("orders").doc(orderId).collection("deliveryRequests").doc(doc.id),
      request,
      { merge: true }
    );
    batch.set(admin.firestore().collection("delivery_requests").doc(requestId), request, { merge: true });
  });
  await batch.commit();

  await Promise.all(
    selectedPartners.map(({ doc, distance }) =>
      sendOrderPushToUser(
        doc.id,
        "New nearby delivery request",
        distance === null
          ? `Order ${orderNumber} is packed and ready for pickup.`
          : `Order ${orderNumber} pickup is ${distance.toFixed(1)} km away.`,
        "delivery_pickup_ready",
        orderId,
        orderNumber,
        "ready_for_pickup"
      )
    )
  );

  return selectedPartners.length;
}

async function closeDeliveryRequests(orderId: string, assignedPartnerId: string): Promise<void> {
  const requests = await admin
    .firestore()
    .collection("orders")
    .doc(orderId)
    .collection("deliveryRequests")
    .get();

  if (requests.empty) return;

  const batch = admin.firestore().batch();
  requests.docs.forEach((doc) => {
    const status = doc.id === assignedPartnerId ? "accepted" : "cancelled";
    const update = {
      status,
      assignedPartnerId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    batch.set(doc.ref, update, { merge: true });
    batch.set(
      admin.firestore().collection("delivery_requests").doc(`${orderId}_${doc.id}`),
      update,
      { merge: true }
    );
  });
  await batch.commit();
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

      let deliveryTargets = 0;
      if (orderStatus === "ready_for_pickup") {
        deliveryTargets = await notifyDeliveryPartnersForPickup(orderId, orderNumber, afterData);
      }

      if (orderStatus === "delivery_accepted" && afterData.deliveryPartnerId) {
        await closeDeliveryRequests(orderId, String(afterData.deliveryPartnerId));
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
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });

