// ============================================================
//  LOW-STOCK ALERT & INVENTORY MANAGEMENT CLOUD FUNCTIONS
// ============================================================

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import { log } from "../common/helpers";

/**
 * Trigger: Fires when a product document is updated.
 * Purpose: Check if stock has dropped below threshold and send
 *          a push notification to the seller.
 */
export const onProductStockChanged = functions.firestore
  .document("products/{productId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const productId = context.params.productId;

    const previousStock = before.stock ?? 0;
    const currentStock = after.stock ?? 0;
    const productName = after.name ?? "Unknown Product";
    const sellerId = after.sellerId;
    const lowStockThreshold = after.lowStockThreshold ?? 5;

    // Only trigger if stock decreased and crossed threshold
    if (currentStock >= previousStock) return null;
    if (currentStock > lowStockThreshold) return null;

    log.info(
      `📉 Low stock alert: "${productName}" has ${currentStock} units left (threshold: ${lowStockThreshold})`
    );

    // Determine notification message
    let title: string;
    let body: string;

    if (currentStock === 0) {
      title = "⚠️ Out of Stock!";
      body = `"${productName}" is now out of stock. Restock immediately to avoid losing sales.`;
    } else {
      title = "📉 Low Stock Alert";
      body = `"${productName}" has only ${currentStock} units left. Consider restocking soon.`;
    }

    try {
      // Get seller's FCM token
      if (sellerId) {
        const sellerDoc = await admin
          .firestore()
          .collection("users")
          .doc(sellerId)
          .get();

        const fcmToken = sellerDoc.data()?.fcmToken;

        if (fcmToken) {
          await admin.messaging().send({
            token: fcmToken,
            notification: { title, body },
            data: {
              type: "low_stock",
              productId: productId,
              productName: productName,
              currentStock: currentStock.toString(),
            },
            android: {
              priority: "high",
              notification: {
                channelId: "inventory_alerts",
                priority: "high",
              },
            },
          });
          log.success(`✅ Low-stock notification sent to seller ${sellerId}`);
        }
      }

      // Also save alert to a collection for admin dashboard
      await admin.firestore().collection("inventory_alerts").add({
        productId: productId,
        productName: productName,
        sellerId: sellerId || null,
        previousStock: previousStock,
        currentStock: currentStock,
        threshold: lowStockThreshold,
        alertType: currentStock === 0 ? "out_of_stock" : "low_stock",
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (error: any) {
      log.error(`❌ Low-stock alert error: ${error.message}`);
    }

    return null;
  });

/**
 * Callable: Admin/Seller can set low-stock threshold per product
 */
export const setLowStockThreshold = functions.https.onCall(async (request) => {
  const data = request.data;
  const context = request;

  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Must be logged in"
    );
  }

  const { productId, threshold } = data;

  if (!productId || threshold === undefined) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "productId and threshold are required"
    );
  }

  await admin.firestore().collection("products").doc(productId).update({
    lowStockThreshold: threshold,
  });

  log.info(
    `✅ Low-stock threshold set to ${threshold} for product ${productId}`
  );

  return { success: true, threshold };
});
