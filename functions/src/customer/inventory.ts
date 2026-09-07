// ============================================================
//  LOW-STOCK ALERT & INVENTORY MANAGEMENT CLOUD FUNCTIONS
// ============================================================

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
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
        createdAt: FieldValue.serverTimestamp(),
      });
    } catch (error: any) {
      log.error(`❌ Low-stock alert error: ${error.message}`);
    }

    return null;
  });

/**
 * Callable: Admin/Seller can set low-stock threshold per product
 */
export const setLowStockThreshold = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Must be logged in"
    );
  }

  const { productId, threshold } = data;

  if (!productId || typeof productId !== "string") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "productId is required"
    );
  }

  // FIX-9, WS4. Was `threshold === undefined` only — any other type
  // (a string, NaN, Infinity, a negative number) reached the bare
  // `productRef.update({ lowStockThreshold: threshold })` below unchecked.
  // A non-finite or negative threshold either breaks onProductStockChanged's
  // numeric comparison against it or fires a low-stock alert on every write.
  if (typeof threshold !== "number" || !Number.isFinite(threshold) || threshold < 0) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "threshold must be a non-negative finite number"
    );
  }

  const productRef = admin.firestore().collection("products").doc(productId);

  // FIX-9, WS4. Claim-first, mirroring createEmployeeByAdmin.ts's and
  // createSellerByAdmin.ts's own callerIsAdmin() idiom: check the auth
  // token's admin claim before touching Firestore at all, rather than
  // unconditionally reading userDoc even when the claim already answers the
  // question. Falls back to the Firestore role field only when the claim
  // is absent, matching those two files' fallback for the same reason.
  const isAdminByClaim = context.auth.token.admin === true;
  const [productDoc, userDoc] = await Promise.all([
    productRef.get(),
    isAdminByClaim
      ? Promise.resolve(null)
      : admin.firestore().collection("users").doc(context.auth.uid).get(),
  ]);

  if (!productDoc.exists) {
    throw new functions.https.HttpsError("not-found", "Product not found");
  }

  const isAdmin = isAdminByClaim || userDoc?.data()?.role === "admin";
  const isSellerOwner = productDoc.data()?.sellerId === context.auth.uid;
  if (!isAdmin && !isSellerOwner) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Only an admin or the product owner can update stock alerts"
    );
  }

  await productRef.update({
    lowStockThreshold: threshold,
  });

  log.info(
    `✅ Low-stock threshold set to ${threshold} for product ${productId}`
  );

  return { success: true, threshold };
});
