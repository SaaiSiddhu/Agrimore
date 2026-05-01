// ============================================================
//  SELLER NOTIFICATION — New Order Alert Cloud Function
// ============================================================

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

/**
 * Trigger: Fires when a new order is created in the orders collection.
 * Purpose: Notify all affected sellers that they have a new order.
 */
export const notifySellerNewOrder = functions.firestore
  .document("orders/{orderId}")
  .onCreate(async (snapshot, context) => {
    const order = snapshot.data();
    const orderId = context.params.orderId;

    if (!order) return null;
    if (order.sellerId) {
      console.log("Seller notification handled by onOrderCreatedNotifications");
      return null;
    }

    const items = order.items as Array<any> || [];
    const orderTotal = order.total || 0;
    const orderNumber = order.orderNumber || orderId.substring(0, 8);

    console.log(`📦 New order ${orderNumber} created with ${items.length} items`);

    // Collect unique seller IDs from order items
    // We need to look up the product's sellerId for each item
    const productIds = items
      .map((item: any) => item.productId)
      .filter((id: string) => id);

    if (productIds.length === 0) {
      console.log("⚠️ No product IDs in order items");
      return null;
    }

    // Batch fetch products to get sellerIds
    const sellerIds = new Set<string>();
    const sellerItemCounts: Record<string, number> = {};

    for (const productId of productIds) {
      try {
        const productDoc = await admin
          .firestore()
          .collection("products")
          .doc(productId)
          .get();

        const sellerId = productDoc.data()?.sellerId;
        if (sellerId) {
          sellerIds.add(sellerId);
          sellerItemCounts[sellerId] = (sellerItemCounts[sellerId] || 0) + 1;
        }
      } catch (e) {
        console.log(`⚠️ Could not fetch product ${productId}: ${e}`);
      }
    }

    if (sellerIds.size === 0) {
      console.log("⚠️ No seller IDs found for order items");
      return null;
    }

    console.log(`📬 Notifying ${sellerIds.size} sellers`);

    // Send push notification to each seller
    const promises = Array.from(sellerIds).map(async (sellerId) => {
      try {
        const sellerDoc = await admin
          .firestore()
          .collection("users")
          .doc(sellerId)
          .get();

        const fcmToken = sellerDoc.data()?.fcmToken;
        const itemCount = sellerItemCounts[sellerId] || 0;

        if (!fcmToken) {
          console.log(`⚠️ No FCM token for seller ${sellerId}`);
          return;
        }

        await admin.messaging().send({
          token: fcmToken,
          notification: {
            title: "🛒 New Order Received!",
            body: `You have a new order (#${orderNumber}) with ${itemCount} item(s). Total: ₹${orderTotal}`,
          },
          data: {
            type: "new_order",
            orderId: orderId,
            orderNumber: orderNumber,
            total: orderTotal.toString(),
          },
          android: {
            priority: "high",
            notification: {
              channelId: "order_alerts",
              priority: "high",
              sound: "default",
            },
          },
        });

        console.log(`✅ Notification sent to seller ${sellerId}`);

        // Also create an in-app notification document
        await admin.firestore().collection("notifications").add({
          userId: sellerId,
          title: "New Order Received!",
          body: `Order #${orderNumber} with ${itemCount} item(s). Total: ₹${orderTotal}`,
          type: "new_order",
          data: { orderId, orderNumber },
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (error: any) {
        console.error(
          `❌ Failed to notify seller ${sellerId}: ${error.message}`
        );
      }
    });

    await Promise.all(promises);
    return null;
  });

/**
 * Trigger: Fires when order status changes to 'delivered'.
 * Purpose: Calculate seller payout based on commission rate.
 */
export const calculateSellerPayout = functions.firestore
  .document("orders/{orderId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const orderId = context.params.orderId;

    // Only trigger when status changes to "delivered"
    if (before.orderStatus === "delivered" || after.orderStatus !== "delivered") {
      return null;
    }

    console.log(`💰 Calculating payout for delivered order ${orderId}`);

    const items = after.items as Array<any> || [];
    const orderTotal = after.total || 0;

    // Get commission settings
    let defaultCommission = 8; // 8% default
    try {
      const settingsDoc = await admin
        .firestore()
        .collection("settings")
        .doc("commission")
        .get();

      if (settingsDoc.exists) {
        defaultCommission = settingsDoc.data()?.defaultRate || 8;
      }
    } catch (e) {
      console.log("⚠️ Using default commission rate");
    }

    // Group items by seller
    const sellerItems: Record<string, { total: number; items: any[] }> = {};

    for (const item of items) {
      try {
        const productDoc = await admin
          .firestore()
          .collection("products")
          .doc(item.productId)
          .get();

        const sellerId = productDoc.data()?.sellerId;
        const categoryId = productDoc.data()?.categoryId;

        if (!sellerId) continue;

        if (!sellerItems[sellerId]) {
          sellerItems[sellerId] = { total: 0, items: [] };
        }

        const itemTotal = (item.price || 0) * (item.quantity || 1);
        sellerItems[sellerId].total += itemTotal;
        sellerItems[sellerId].items.push({
          ...item,
          categoryId,
        });
      } catch (e) {
        console.log(`⚠️ Error processing item: ${e}`);
      }
    }

    // Create payout document for each seller
    const payoutPromises = Object.entries(sellerItems).map(
      async ([sellerId, data]) => {
        // Check for category-specific commission
        let commissionRate = defaultCommission;
        try {
          const settingsDoc = await admin
            .firestore()
            .collection("settings")
            .doc("commission")
            .get();

          const categoryRates = settingsDoc.data()?.categoryRates || {};
          // Use the first item's category for simplicity
          const firstCategory = data.items[0]?.categoryId;
          if (firstCategory && categoryRates[firstCategory]) {
            commissionRate = categoryRates[firstCategory];
          }
        } catch (e) {
          // Use default
        }

        const grossAmount = data.total;
        const commissionAmount = grossAmount * (commissionRate / 100);
        const netAmount = grossAmount - commissionAmount;

        // Check if payout already exists for this order+seller
        const existing = await admin
          .firestore()
          .collection("seller_payouts")
          .where("orderId", "==", orderId)
          .where("sellerId", "==", sellerId)
          .limit(1)
          .get();

        if (!existing.empty) {
          console.log(
            `⚠️ Payout already exists for order ${orderId}, seller ${sellerId}`
          );
          return;
        }

        await admin.firestore().collection("seller_payouts").add({
          sellerId,
          orderId,
          orderNumber: after.orderNumber || "",
          grossAmount,
          commissionRate,
          commissionAmount,
          netAmount,
          amount: netAmount, // Alias for backward compat
          status: "pending",
          itemCount: data.items.length,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          paidAt: null,
        });

        console.log(
          `✅ Payout created: seller=${sellerId}, gross=₹${grossAmount}, commission=${commissionRate}%, net=₹${netAmount}`
        );
      }
    );

    await Promise.all(payoutPromises);
    return null;
  });
