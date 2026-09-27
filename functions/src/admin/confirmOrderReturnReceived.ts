// ============================================================
//  Callable: confirmOrderReturnReceived — admin-confirmed return stock
// ============================================================
//
// ADMR-37: restoreStockOnCancellation.ts no longer auto-restores stock when
// an order is cancelled FROM 'delivered' — the customer already had
// physical possession, so an automatic restore would claim inventory is
// sellable again before anyone confirmed the item actually came back. That
// trigger instead sets `stockRestorePending: true` and stops. This callable
// is the ONLY path that resolves it: an admin, having actually confirmed
// the physical return (by whatever means — this callable takes no
// inspection/condition data, because no such policy exists anywhere in
// this codebase yet, and inventing one is explicitly out of scope), taps a
// single confirmation and the exact same `restoreOrderItemStock` the
// trigger uses runs now instead. This intentionally does NOT decide
// refund timing, restocking fees, or partial-quantity returns — it is a
// binary "the ordered items are back, restore them" action; anything finer
// stays a genuinely open owner decision, not silently resolved here.
//
// Mirrors adminOrderActions.ts's own admin-auth idiom exactly.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { restoreOrderItemStock } from "../customer/restoreStockOnCancellation";

type Outcome =
  | "restored"
  | "already_restored"
  | "not_pending"
  | "not_found"
  | "validation_failed";

interface Result {
  outcome: Outcome;
  message?: string;
}

export const confirmOrderReturnReceived = onCall(
  { minInstances: 0, memory: "256MiB" },
  async (request): Promise<Result> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required");
    }

    const isAdminClaim = request.auth.token.admin === true;
    if (!isAdminClaim) {
      const callerSnap = await admin
        .firestore()
        .collection("users")
        .doc(request.auth.uid)
        .get();
      if (callerSnap.data()?.role !== "admin") {
        throw new HttpsError("permission-denied", "Admin only");
      }
    }

    const orderId = String(request.data?.orderId || "").trim();
    if (!orderId) {
      throw new HttpsError("invalid-argument", "orderId is required");
    }

    const db = admin.firestore();
    const orderRef = db.collection("orders").doc(orderId);

    return db.runTransaction(async (tx): Promise<Result> => {
      const orderSnap = await tx.get(orderRef);
      if (!orderSnap.exists) {
        return { outcome: "not_found", message: "Order not found" };
      }
      const order = orderSnap.data()!;

      if (order.stockRestored === true) {
        return { outcome: "already_restored" };
      }
      if (order.stockRestorePending !== true) {
        return {
          outcome: "not_pending",
          message: "This order is not awaiting a return-stock confirmation.",
        };
      }
      const status = String(order.orderStatus || order.status || "").toLowerCase();
      if (status !== "cancelled") {
        // Defensive only — stockRestorePending is set solely by
        // restoreStockOnCancellation.ts alongside a genuine cancellation,
        // so this should be unreachable. Never restore stock against a
        // stale flag on a non-cancelled order.
        return { outcome: "not_pending", message: "Order is not cancelled." };
      }

      await restoreOrderItemStock(tx, db, order, orderId);

      const now = admin.firestore.FieldValue.serverTimestamp();
      tx.update(orderRef, {
        stockRestored: true,
        stockRestorePending: false,
        stockRestoreConfirmedBy: request.auth!.uid,
        stockRestoreConfirmedAt: now,
      });

      tx.set(orderRef.collection("timeline").doc(), {
        status: "cancelled",
        title: "Return Stock Restored",
        description: "Admin confirmed the returned items were received; stock has been restored.",
        actorUid: request.auth!.uid,
        updatedBy: "admin",
        reason: null,
        timestamp: now,
      });

      return { outcome: "restored" };
    });
  }
);
