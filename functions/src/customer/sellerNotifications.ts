// ============================================================
//  SELLER NOTIFICATION — New Order Alert Cloud Function
// ============================================================

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";

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
          createdAt: FieldValue.serverTimestamp(),
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
// Phase FIX-4 (finding N-8, P1). Mirrors employeeCommission.ts's
// DELIVERED_EQUIVALENT_STATUSES exactly. Kept as a local copy rather than an
// import because that module is owned by FIX-4B (finding N-29 lives in it) and
// this phase must not touch it; if the two ever diverge, a seller is unpaid for
// an order an associate was paid for, which is precisely the bug this closes.
const PAYOUT_ELIGIBLE_STATUSES = new Set(["delivered", "completed"]);

function isPayoutEligibleStatus(status: unknown): boolean {
  return typeof status === "string" && PAYOUT_ELIGIBLE_STATUSES.has(status.toLowerCase());
}

const DEFAULT_COMMISSION_RATE = 8;
const MAX_PAYOUT_COMMISSION_RATE = 100;

/**
 * Phase FIX-4 (finding N-28, P1). `categoryRates[...]` and `defaultRate` were
 * used with no validation at all, so a non-numeric or negative admin entry
 * produced `NaN` or a NEGATIVE netAmount — real money, computed from unchecked
 * input. employeeCommission.ts validates carefully via resolveCommissionRate;
 * this file did not.
 *
 * Same ceiling reasoning as that function: a rate at or above 100% would mean
 * AgriMore keeps everything or more, which is a data-entry error rather than a
 * business decision, so it is REFUSED rather than clamped — clamping would
 * still pay out at a rate nobody chose. A present-but-zero or negative value is
 * treated as unconfigured, matching that file's documented "rate 0 semantics"
 * decision, instead of `|| 8` silently turning a configured 0 into 8.
 */
function resolvePayoutRate(value: unknown, fallback: number): number {
  if (typeof value !== "number" || !Number.isFinite(value)) return fallback;
  if (value <= 0) return fallback;
  if (value > MAX_PAYOUT_COMMISSION_RATE) {
    console.error(
      `❌ settings/commission holds a rate above ${MAX_PAYOUT_COMMISSION_RATE}% — refusing it and using ${fallback}%`
    );
    return fallback;
  }
  return value;
}

export const calculateSellerPayout = functions.firestore
  .document("orders/{orderId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const orderId = context.params.orderId;

    // Phase FIX-4 (finding N-8, P1). This fired ONLY on the exact string
    // "delivered", while employeeCommission.ts's payEmployeeCommissionOnDelivery
    // treats "delivered" and "completed" as equivalent, case-insensitively —
    // and its own comment records that apps/admin's order_management_screen has
    // a live bulk action writing the literal 'completed'. An order closed that
    // way paid the ASSOCIATE and silently never created a seller_payouts
    // document at all. The two triggers now share one definition of "the order
    // was fulfilled"; anything else is a way for a seller to go unpaid.
    if (isPayoutEligibleStatus(before.orderStatus) || !isPayoutEligibleStatus(after.orderStatus)) {
      return null;
    }

    console.log(`💰 Calculating payout for delivered order ${orderId}`);

    const items = after.items as Array<any> || [];

    // Phase FIX-4 (N-28, and the N+1 read observed alongside it). settings/
    // commission was read once here for defaultRate AND again inside the
    // per-seller loop for categoryRates — an N+1 read on a money path. One read,
    // both values.
    //
    // `defaultRate || 8` also silently turned a CONFIGURED rate of 0 into 8.
    // employeeCommission.ts documents that exact hazard as its "rate 0
    // semantics" decision and handles it deliberately; this file simply got it
    // wrong. resolvePayoutRate below treats 0 as unconfigured rather than as
    // "pay nothing", matching that decision, but never silently substitutes a
    // number for a value that is present and out of range.
    let commissionSettings: admin.firestore.DocumentData = {};
    try {
      const settingsDoc = await admin.firestore().collection("settings").doc("commission").get();
      commissionSettings = settingsDoc.data() || {};
    } catch (e) {
      console.log("⚠️ settings/commission unreadable — falling back to the default rate");
    }
    const defaultCommission = resolvePayoutRate(commissionSettings.defaultRate, DEFAULT_COMMISSION_RATE);

    // Group items by seller
    const sellerItems: Record<string, { total: number; items: any[] }> = {};

    for (const item of items) {
      try {
        // Phase FIX-4 (finding N-26, P1). sellerId now comes from the ORDER's
        // own stored per-item value (written by orderPricing.ts:327 at creation
        // time), NOT from the live products/{id} document. Re-deriving it from
        // the product meant a product reassigned to a different seller after the
        // order paid the WRONG seller, and a deleted product hit
        // `if (!sellerId) continue;` and silently dropped that item from the
        // payout — the seller simply never got paid for it, with no error.
        // The order is the record of what was sold and by whom; the product
        // document is mutable state that has moved on.
        //
        // The product is still read, for categoryId ONLY, so EACH item's own
        // category rate can be resolved below (Phase FIX-4B, N-27,
        // D-PAYOUT-MIXED-CATEGORY — a weighted average across items, not the
        // first item's category alone). A missing product now degrades that
        // one item to the default rate instead of dropping the line.
        const sellerId = typeof item.sellerId === "string" ? item.sellerId : "";
        if (!sellerId) {
          console.warn(
            `⚠️ Order ${orderId} item ${item.productId} has no sellerId on the order — no payout target, skipping this line`
          );
          continue;
        }

        let categoryId: string | undefined;
        try {
          const productDoc = await admin.firestore().collection("products").doc(item.productId).get();
          categoryId = productDoc.data()?.categoryId;
        } catch (e) {
          console.warn(`⚠️ Could not read product ${item.productId} for its category — using the default rate`);
        }

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
        // Phase FIX-4B (finding N-27, D-PAYOUT-MIXED-CATEGORY — owner
        // decision, 2026-09-07): a mixed-category order now uses a WEIGHTED
        // AVERAGE of each item's own category rate, not the first item's
        // category rate applied to the whole payout. Each item's own
        // resolved rate (via the SAME categoryRates/resolvePayoutRate this
        // file already reads once — no new Firestore read) is applied to
        // that item's own value, and commissionAmount is the sum across the
        // seller's items. The stored `commissionRate` field is then the
        // DERIVED weighted average (commissionAmount/grossAmount×100) —
        // mathematically identical to averaging the per-item rates weighted
        // by value, computed the simpler way, and kept as a single
        // percentage for backward-compat with anything already reading it.
        const categoryRates = commissionSettings.categoryRates || {};
        let commissionAmount = 0;
        for (const item of data.items) {
          const itemTotal = (item.price || 0) * (item.quantity || 1);
          const rawCategoryRate =
            item.categoryId && categoryRates[item.categoryId] !== undefined
              ? categoryRates[item.categoryId]
              : undefined;
          const itemRate =
            rawCategoryRate === undefined
              ? defaultCommission
              : resolvePayoutRate(rawCategoryRate, defaultCommission);
          commissionAmount += itemTotal * (itemRate / 100);
        }

        const grossAmount = data.total;
        const commissionRate = grossAmount > 0 ? (commissionAmount / grossAmount) * 100 : 0;
        const netAmount = grossAmount - commissionAmount;

        // Phase FIX-4 (finding N-7, P1). This was a non-transactional
        // check-then-act: a query, an early return if non-empty, then a bare
        // .add() with a RANDOM document id. v1 Firestore triggers are
        // at-least-once and can be delivered concurrently, so two invocations
        // both observed `empty` and both added — paying the seller twice.
        // payEmployeeCommissionOnDelivery in the sibling file already got this
        // right by re-checking inside runTransaction; this one never did.
        //
        // Two changes make a double payout impossible rather than unlikely:
        // the document id is now DETERMINISTIC (`{orderId}_{sellerId}`), so a
        // duplicate is the same document rather than a second one; and the
        // existence check and the write are in one transaction, so a concurrent
        // invocation either sees the marker or loses the transaction lock and
        // retries. Either alone would leave a window; the pair does not.
        const payoutRef = admin
          .firestore()
          .collection("seller_payouts")
          .doc(`${orderId}_${sellerId}`);

        const created = await admin.firestore().runTransaction(async (tx) => {
          const existing = await tx.get(payoutRef);
          if (existing.exists) return false;
          tx.set(payoutRef, {
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
            createdAt: FieldValue.serverTimestamp(),
            paidAt: null,
          });
          return true;
        });

        if (!created) {
          console.log(`⚠️ Payout already exists for order ${orderId}, seller ${sellerId}`);
          return;
        }

        console.log(
          `✅ Payout created: seller=${sellerId}, gross=₹${grossAmount}, commission=${commissionRate}%, net=₹${netAmount}`
        );
      }
    );

    await Promise.all(payoutPromises);
    return null;
  });
