// ============================================================
//  EMPLOYEE COMMISSION — B2B Order Delivered Trigger
// ============================================================
//
// Fires when an order transitions into the delivered status. Credits the
// attributed employee's wallet via a server-side transaction — mirrors the
// commission-on-delivery pattern in ./sellerNotifications.ts#calculateSellerPayout,
// but pays the employee (via wallets/wallet_transactions) instead of creating
// a seller_payouts document.
//
// Security invariant: wallet crediting NEVER happens client-side. This
// function is the only writer of wallet_transactions for commission and the
// only incrementer of wallets/{employeeUid}.balance for this purpose.

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

// Matches OrderModel.isDelivered exactly (packages/agrimore_core/lib/models/order_model.dart),
// which treats 'delivered' and 'completed' as equivalent terminal states — NOT just the
// order_status.dart enum's 'delivered' value. apps/admin's order_management_screen.dart has a
// live bulk-action that sets orderStatus to the literal string 'completed'
// (admin_service.dart:189 already branches on both), so watching only 'delivered' would silently
// skip commission for orders closed that way.
const DELIVERED_EQUIVALENT_STATUSES = new Set(["delivered", "completed"]);

function isDeliveredEquivalent(status: unknown): boolean {
  return typeof status === "string" && DELIVERED_EQUIVALENT_STATUSES.has(status.toLowerCase());
}

export const payEmployeeCommissionOnDelivery = functions.firestore
  .document("orders/{orderId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const orderId = context.params.orderId;

    // Only fire on the transition INTO a delivered-equivalent status, not on
    // every write while already delivered/completed.
    if (isDeliveredEquivalent(before.orderStatus) || !isDeliveredEquivalent(after.orderStatus)) {
      return null;
    }

    if (after.orderMode !== "B2B") {
      return null;
    }

    const employeeUid = after.employeeUid as string | undefined;
    if (!employeeUid) {
      console.log(`⚠️ B2B order ${orderId} delivered with no employeeUid — skipping commission`);
      return null;
    }

    if (after.commissionPaid === true) {
      console.log(`⚠️ Commission already paid for order ${orderId} — skipping`);
      return null;
    }

    const db = admin.firestore();
    const orderRef = db.collection("orders").doc(orderId);
    const employeeRef = db.collection("employees").doc(employeeUid);
    const walletRef = db.collection("wallets").doc(employeeUid);
    const walletTransactionRef = db.collection("wallet_transactions").doc();

    try {
      await db.runTransaction(async (tx) => {
        const [orderSnap, employeeSnap, walletSnap] = await Promise.all([
          tx.get(orderRef),
          tx.get(employeeRef),
          tx.get(walletRef),
        ]);

        // Re-check idempotency inside the transaction to guard against
        // concurrent/retried trigger invocations.
        if (orderSnap.data()?.commissionPaid === true) {
          console.log(`⚠️ Commission already paid for order ${orderId} (checked in tx) — skipping`);
          return;
        }

        let commissionRate = (employeeSnap.data()?.commissionRate as number | undefined) ?? 0;
        if (!commissionRate) {
          const settingsSnap = await tx.get(db.collection("settings").doc("commission"));
          commissionRate = (settingsSnap.data()?.employeeDefaultRate as number | undefined) ?? 5;
        }

        const grossAmount = (after.total as number | undefined) ?? 0;
        const commissionAmount = Math.round(grossAmount * (commissionRate / 100) * 100) / 100;

        if (commissionAmount <= 0) {
          tx.update(orderRef, {
            commissionPaid: true,
            commissionAmount: 0,
            commissionPaidAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          return;
        }

        const currentBalance = (walletSnap.data()?.balance as number | undefined) ?? 0;
        const balanceAfter = currentBalance + commissionAmount;

        tx.set(
          walletRef,
          {
            userId: employeeUid,
            balance: admin.firestore.FieldValue.increment(commissionAmount),
            lifetimeEarnings: admin.firestore.FieldValue.increment(commissionAmount),
            isActive: true,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            createdAt: walletSnap.exists
              ? walletSnap.data()?.createdAt
              : admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        tx.set(walletTransactionRef, {
          walletId: employeeUid,
          userId: employeeUid,
          type: "credit",
          source: "commission",
          amount: commissionAmount,
          coins: 0,
          balanceAfter,
          coinsAfter: walletSnap.data()?.coins ?? 0,
          orderId,
          description: `Commission on B2B order ${after.orderNumber || orderId}`,
          referenceId: orderId,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          expiresAt: null,
          metadata: {
            commissionRate,
            grossAmount,
          },
        });

        tx.update(orderRef, {
          commissionPaid: true,
          commissionAmount,
          commissionPaidAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      console.log(`✅ Employee commission paid: employee=${employeeUid}, order=${orderId}`);
    } catch (error: any) {
      console.error(`❌ Failed to pay employee commission for order ${orderId}: ${error.message}`);
      throw error;
    }

    return null;
  });
