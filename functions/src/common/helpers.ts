import * as admin from "firebase-admin";

export const APP_ICON = "https://agrimore.in/icons/Icon-192.png";
export const DEFAULT_COLOR = "#4CAF50";
export const NOTIFICATION_SOUND = "default";

export const log = {
  info: (msg: string) => console.log(`📌 ${msg}`),
  success: (msg: string) => console.log(`✅ ${msg}`),
  error: (msg: string) => console.error(`❌ ${msg}`),
  warn: (msg: string) => console.warn(`⚠️ ${msg}`),
};

export interface NotificationData {
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

export function isValidUrl(string: string): boolean {
  try {
    new URL(string);
    return true;
  } catch (_) {
    return /^[/a-zA-Z0-9-_]+$/.test(string);
  }
}

export function validateNotificationData(
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

export function createNotificationMessage(
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
