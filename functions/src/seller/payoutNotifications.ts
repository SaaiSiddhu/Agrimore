// ============================================================
//  SELLER-HOME-1b — tell the seller when a payout is marked paid
// ============================================================
//
// firestore.rules (SELLER-MONEY-1) allow exactly one admin transition on
// seller_payouts: pending → paid with a paymentReference. This trigger turns
// that transition into an inbox entry + push for the seller (users/{uid}/
// notifications, same helper and shape as order notifications).

import * as functions from "firebase-functions/v1";
import { notifyUser } from "../customer/orderNotifications";

export const notifySellerPayoutPaid = functions.firestore
  .document("seller_payouts/{payoutId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    if (!before || !after) return null;
    if (before.status === "paid" || after.status !== "paid") return null;
    const sellerId = typeof after.sellerId === "string" ? after.sellerId : "";
    if (!sellerId) return null;

    const net = Number(after.netAmount ?? after.amount ?? 0);
    const orderNumber = String(after.orderNumber || after.orderId || "");
    const reference = typeof after.paymentReference === "string" ? after.paymentReference : "";
    const payoutId = context.params.payoutId;

    await notifyUser(
      sellerId,
      "Payment sent",
      `Rs.${net.toFixed(2)} for order ${orderNumber} has been paid${reference ? ` (ref ${reference})` : ""}.`,
      "payout_paid",
      { payoutId, orderNumber, actionUrl: `payout/${payoutId}`, type: "payout" },
      "💸"
    );
    return null;
  });
