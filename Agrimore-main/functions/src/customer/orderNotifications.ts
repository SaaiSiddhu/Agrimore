import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

function uniqueTokens(data: admin.firestore.DocumentData | undefined): string[] {
  if (!data) return [];
  const tokens = new Set<string>();
  const tokenList = data.fcmTokens;
  if (Array.isArray(tokenList)) {
    tokenList.forEach((token) => {
      if (typeof token === "string" && token.trim()) tokens.add(token.trim());
    });
  }
  if (typeof data.fcmToken === "string" && data.fcmToken.trim()) {
    tokens.add(data.fcmToken.trim());
  }
  return Array.from(tokens);
}

function orderActionUrl(orderId: string): string {
  return `order/${orderId}`;
}

async function writeInAppNotification(
  userId: string,
  title: string,
  body: string,
  type: string,
  data: Record<string, string>,
  emoji: string
): Promise<void> {
  const payload = {
    title,
    body,
    type,
    data,
    emoji,
    unread: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await admin
    .firestore()
    .collection("users")
    .doc(userId)
    .collection("notifications")
    .add(payload);
}

async function notifyUser(
  userId: string,
  title: string,
  body: string,
  type: string,
  data: Record<string, string>,
  emoji: string
): Promise<{ successCount: number; failureCount: number }> {
  const userRef = admin.firestore().collection("users").doc(userId);
  const userDoc = await userRef.get();
  if (!userDoc.exists) return { successCount: 0, failureCount: 0 };

  const tokens = uniqueTokens(userDoc.data());
  const invalidTokens: string[] = [];
  let successCount = 0;
  let failureCount = 0;

  await writeInAppNotification(userId, title, body, type, data, emoji);

  for (const token of tokens) {
    try {
      await admin.messaging().send({
        token,
        notification: { title, body },
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          type,
          actionUrl: data.actionUrl || "",
          ...data,
        },
        android: {
          priority: "high",
          notification: {
            channelId: type.includes("order") ? "order_channel" : "default_channel",
            priority: "high",
            sound: "default",
          },
        },
        apns: {
          headers: { "apns-priority": "10" },
          payload: {
            aps: {
              alert: { title, body },
              sound: "default",
              badge: 1,
            },
          },
        },
      });
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

function matchesDeliveryArea(
  partner: admin.firestore.DocumentData,
  orderAddress: admin.firestore.DocumentData
): boolean {
  const partnerPincode = String(partner.pincode || "").trim();
  const orderPincode = String(orderAddress.pincode || "").trim();
  if (partnerPincode && orderPincode && partnerPincode === orderPincode) {
    return true;
  }

  const partnerCity = String(partner.city || "").trim().toLowerCase();
  const orderCity = String(orderAddress.city || "").trim().toLowerCase();
  if (partnerCity && orderCity && partnerCity === orderCity) {
    return true;
  }

  return !partnerPincode && !partnerCity;
}

export const onOrderCreatedNotifications = functions.firestore
  .document("orders/{orderId}")
  .onCreate(async (snapshot, context) => {
    const order = snapshot.data();
    if (!order) return null;

    const orderId = context.params.orderId;
    const orderNumber = String(order.orderNumber || orderId.substring(0, 8));
    const total = Number(order.total || order.totalAmount || 0);
    const totalText = total > 0 ? ` worth Rs.${total.toFixed(2)}` : "";
    const actionUrl = orderActionUrl(orderId);
    const baseData = {
      orderId,
      orderNumber,
      actionUrl,
      type: "order",
    };

    const notificationPromises: Promise<any>[] = [];

    if (order.userId) {
      notificationPromises.push(
        notifyUser(
          String(order.userId),
          `Order ${orderNumber} placed`,
          "Your order has been placed successfully.",
          "order_created",
          baseData,
          "📦"
        )
      );
    }

    if (order.sellerId) {
      notificationPromises.push(
        notifyUser(
          String(order.sellerId),
          "New order received",
          `Order ${orderNumber}${totalText} is waiting in your seller app.`,
          "seller_new_order",
          baseData,
          "🛒"
        )
      );
    }

    const admins = await admin
      .firestore()
      .collection("users")
      .where("role", "==", "admin")
      .get();
    admins.docs.forEach((doc) => {
      notificationPromises.push(
        notifyUser(
          doc.id,
          "New order placed",
          `Order ${orderNumber}${totalText} has been created.`,
          "admin_new_order",
          baseData,
          "📊"
        )
      );
    });

    const orderAddress = (order.deliveryAddress || {}) as admin.firestore.DocumentData;
    const partners = await admin
      .firestore()
      .collection("delivery_partners")
      .where("status", "==", "approved")
      .get();

    const nearbyPartners = partners.docs.filter((doc) =>
      matchesDeliveryArea(doc.data(), orderAddress)
    );
    const targetPartners = nearbyPartners.length ? nearbyPartners : partners.docs;

    targetPartners.forEach((doc) => {
      notificationPromises.push(
        notifyUser(
          doc.id,
          "Delivery request nearby",
          `Order ${orderNumber} is ready for delivery assignment.`,
          "delivery_available_order",
          baseData,
          "🛵"
        )
      );
    });

    await Promise.all(notificationPromises);

    await admin.firestore().collection("notification_history").add({
      type: "order_created_auto",
      orderId,
      orderNumber,
      sellerId: order.sellerId || null,
      userId: order.userId || null,
      deliveryPartnerTargets: targetPartners.length,
      adminTargets: admins.size,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return null;
  });
