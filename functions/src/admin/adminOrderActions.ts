// ============================================================
//  Callable: adminUpdateOrderStatus — canonical admin order-status transition
// ============================================================
//
// ADMR-24: admin's only order-status write path today is a raw client
// Firestore update (apps/admin/lib/providers/order_provider.dart's
// OrderProvider.updateOrderStatus) with no server-side actor stamp, no
// audit record, no idempotency, and — separately, confirmed by reading the
// caller — a return value the UI never checks, so a genuine failure there
// is shown to the admin as a green success toast. This callable is the
// server-authorized replacement for that write. Firestore rules still also
// allow admin's own direct write on orders/{orderId} (a pre-existing,
// deliberate trust decision, not reopened here) — this is an additive,
// safer path, not yet the only one.
//
// Mirrors setUserRole.ts's admin-auth idiom (claim-first, Firestore-role
// fallback) and its own runTransaction-for-a-conditional-write shape.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

// Matches apps/admin/lib/screens/admin/orders/widgets/order_status_updater.dart's
// own _buildStatusChips() list exactly — the only statuses any admin UI can
// currently select from.
const VALID_STATUSES = [
  "pending",
  "confirmed",
  "processing",
  "shipped",
  "delivered",
  "cancelled",
] as const;
type OrderStatus = (typeof VALID_STATUSES)[number];

// Mirrors order_status_updater.dart's isDangerousOrderStatusTransition
// exactly (leaving 'delivered' un-does stock/commission/product-credit
// reversals already fired on delivery) — enforced here server-side so no
// other caller of this callable can bypass the confirmation the admin app's
// own dialog already asks for.
export function isDangerousOrderStatusTransition(
  currentStatus: string,
  nextStatus: string
): boolean {
  return (
    currentStatus.toLowerCase() === "delivered" &&
    nextStatus.toLowerCase() !== "delivered"
  );
}

function statusTitle(status: OrderStatus): string {
  switch (status) {
    case "pending":
      return "Order Pending";
    case "confirmed":
      return "Order Confirmed";
    case "processing":
      return "Order Processing";
    case "shipped":
      return "Order Shipped";
    case "delivered":
      return "Order Delivered";
    case "cancelled":
      return "Order Cancelled";
  }
}

type Outcome =
  | "applied"
  | "already_applied"
  | "stale_state"
  | "not_found"
  | "validation_failed";

interface Result {
  outcome: Outcome;
  fromStatus?: string;
  toStatus?: string;
  message?: string;
}

export const adminUpdateOrderStatus = onCall(
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
    const requestedStatus = String(request.data?.newStatus || "")
      .trim()
      .toLowerCase();
    const requestId = String(request.data?.requestId || "").trim();
    const reason = String(request.data?.reason || "").trim();
    const expectedCurrentStatus = request.data?.expectedCurrentStatus
      ? String(request.data.expectedCurrentStatus).trim().toLowerCase()
      : null;

    if (!orderId) {
      throw new HttpsError("invalid-argument", "orderId is required");
    }
    if (!requestId) {
      throw new HttpsError(
        "invalid-argument",
        "requestId is required (client-generated, one per user action, for idempotency)"
      );
    }
    if (!(VALID_STATUSES as readonly string[]).includes(requestedStatus)) {
      return {
        outcome: "validation_failed",
        message: `newStatus must be one of: ${VALID_STATUSES.join(", ")}`,
      };
    }
    const newStatus = requestedStatus as OrderStatus;

    const db = admin.firestore();
    const orderRef = db.collection("orders").doc(orderId);
    const actionRef = orderRef.collection("adminActions").doc(requestId);

    return db.runTransaction(async (tx): Promise<Result> => {
      const actionSnap = await tx.get(actionRef);
      if (actionSnap.exists) {
        const prior = actionSnap.data() || {};
        return {
          outcome: "already_applied",
          fromStatus: prior.fromStatus,
          toStatus: prior.toStatus,
        };
      }

      const orderSnap = await tx.get(orderRef);
      if (!orderSnap.exists) {
        return { outcome: "not_found", message: "Order not found" };
      }
      const currentStatus = String(
        orderSnap.data()?.orderStatus || orderSnap.data()?.status || ""
      ).toLowerCase();

      if (
        expectedCurrentStatus !== null &&
        expectedCurrentStatus !== currentStatus
      ) {
        return {
          outcome: "stale_state",
          fromStatus: currentStatus,
          message: `Order's current status is "${currentStatus}", not "${expectedCurrentStatus}" — reload and try again`,
        };
      }

      if (currentStatus === newStatus) {
        // No-op transition: record for idempotency, but don't duplicate a
        // timeline entry or re-fire anything downstream.
        tx.set(actionRef, {
          adminUid: request.auth!.uid,
          fromStatus: currentStatus,
          toStatus: newStatus,
          reason: reason || null,
          noop: true,
          at: admin.firestore.FieldValue.serverTimestamp(),
        });
        return {
          outcome: "already_applied",
          fromStatus: currentStatus,
          toStatus: newStatus,
        };
      }

      if (isDangerousOrderStatusTransition(currentStatus, newStatus) && !reason) {
        return {
          outcome: "validation_failed",
          message:
            "A reason is required to change the status of a delivered order.",
        };
      }

      tx.update(orderRef, {
        orderStatus: newStatus,
        status: newStatus,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      tx.set(orderRef.collection("timeline").doc(), {
        status: newStatus,
        title: statusTitle(newStatus),
        description: reason || `Status updated to ${newStatus.toUpperCase()}.`,
        actorUid: request.auth!.uid,
        reason: reason || null,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      tx.set(actionRef, {
        adminUid: request.auth!.uid,
        fromStatus: currentStatus,
        toStatus: newStatus,
        reason: reason || null,
        noop: false,
        at: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { outcome: "applied", fromStatus: currentStatus, toStatus: newStatus };
    });
  }
);
