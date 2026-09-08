// ============================================
//  BUSINESS NETWORK — Follower New-Product Alert (Phase BUSINESS-NETWORK-1)
// ============================================
//
// Trigger: fires when a seller creates a new product (products/{productId}
// is written via a direct client .add() from
// apps/seller/lib/providers/seller_product_provider.dart:68 -- there is no
// callable to hook, so this is a Firestore v1 onCreate trigger, matching the
// existing convention already used by sellerNotifications.ts and
// orderNotifications.ts in this same directory).
//
// Notifies every customer following that seller (firestore.rules'
// `follows/{followId}` collection, Phase BUSINESS-NETWORK-1 WS2) on BOTH
// channels -- an in-app doc under users/{followerId}/notifications, and an
// FCM push -- per owner decision D-BUSINESS-PROFILE-SHAPE ("both channels,
// not one"). sendBroadcastNotification/sendNotificationToUser
// (functions/src/admin/notifications.ts) are NOT reused here: both are
// requireAdmin()-gated onCall callables, and a background trigger has no
// admin auth context to call them with. createNotificationMessage
// (functions/src/common/helpers.ts) IS reused -- it is a plain exported
// helper, not gated.
import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { createNotificationMessage, log } from "../common/helpers";

// Duplicated locally rather than imported, matching this codebase's own
// established convention (the identical helper already exists,
// independently, in admin/notifications.ts and customer/orderNotifications.ts).
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

async function writeInAppNotification(
  followerId: string,
  title: string,
  body: string,
  productId: string,
  sellerId: string
): Promise<void> {
  await admin
    .firestore()
    .collection("users")
    .doc(followerId)
    .collection("notifications")
    .add({
      title,
      body,
      type: "new_product",
      data: { productId, sellerId },
      emoji: "🆕",
      unread: true,
      createdAt: FieldValue.serverTimestamp(),
    });
}

export const notifyFollowersOnNewProduct = functions.firestore
  .document("products/{productId}")
  .onCreate(async (snapshot, context) => {
    const product = snapshot.data();
    const productId = context.params.productId as string;
    if (!product) return null;

    const sellerId = product.sellerId as string | undefined;
    if (!sellerId) return null;

    const followersSnap = await admin
      .firestore()
      .collection("follows")
      .where("sellerId", "==", sellerId)
      .get();

    if (followersSnap.empty) return null;

    let sellerName = "A seller you follow";
    try {
      const sellerDoc = await admin
        .firestore()
        .collection("sellers")
        .doc(sellerId)
        .get();
      const shopName = sellerDoc.data()?.shopName as string | undefined;
      if (shopName) sellerName = shopName;
    } catch (e) {
      log.warn(`notifyFollowersOnNewProduct: could not load seller ${sellerId}: ${e}`);
    }

    const productName = (product.name as string) || "a new product";
    const title = sellerName;
    const body = `New product: ${productName}`;
    const actionUrl = `/product/${productId}`;

    const followerIds = followersSnap.docs
      .map((d) => d.data().followerId as string | undefined)
      .filter((id): id is string => !!id);

    let successCount = 0;
    let failureCount = 0;

    for (const followerId of followerIds) {
      try {
        await writeInAppNotification(followerId, title, body, productId, sellerId);

        const followerDoc = await admin.firestore().collection("users").doc(followerId).get();
        const tokens = uniqueTokens(followerDoc.data());

        for (const token of tokens) {
          try {
            const message = createNotificationMessage(
              token,
              title,
              body,
              undefined,
              actionUrl,
              "new_product"
            );
            await admin.messaging().send(message);
            successCount++;
          } catch (error: any) {
            failureCount++;
            if (
              error.code === "messaging/invalid-registration-token" ||
              error.code === "messaging/registration-token-not-registered"
            ) {
              await admin
                .firestore()
                .collection("users")
                .doc(followerId)
                .update({ fcmTokens: FieldValue.arrayRemove(token) });
            }
          }
        }
      } catch (e) {
        log.error(`notifyFollowersOnNewProduct: failed for follower ${followerId}: ${e}`);
      }
    }

    log.success(
      `notifyFollowersOnNewProduct: product ${productId}, ${followerIds.length} followers, ${successCount} pushes sent, ${failureCount} failed`
    );
    return null;
  });
