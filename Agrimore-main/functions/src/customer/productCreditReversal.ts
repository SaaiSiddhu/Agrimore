// ============================================================
//  PRODUCT CREDIT REVERSAL — Order Cancellation Trigger
//  (Phase D, Workstream 4; hardened in Phase D-1)
// ============================================================
//
// Mirrors employeeCommission.ts's trigger shape exactly: a Firestore
// onUpdate trigger on orders/{orderId}, firing only on the transition INTO
// 'cancelled', with idempotency checked AND written inside the same
// transaction that performs the refund (guards concurrent/retried trigger
// invocations — Firestore triggers are at-least-once).
//
// Multi-seller carts: each seller's order document carries its OWN
// per-seller productCreditApplied share (see createOrder.ts's Phase D
// settlement and its per-seller rounding comment) — cancelling one
// seller's order reverses only THAT order's own share via THIS order's own
// productCreditApplied/productCreditReversed fields. It never touches
// another seller's order in the same original cart, because each order
// document is independently gated on its own fields here.
//
// Phase D-1, DEFECT D-0/Workstream 2 (defence in depth): the refund AMOUNT,
// customerId, and relatedEntryId are now re-derived from the transaction's
// OWN read of the order document — never from the trigger's `after`
// payload. `after` is still read once, before the transaction, purely as a
// cheap PRE-FILTER so the overwhelming majority of order updates (no
// credit applied, or already reversed) can skip opening a transaction at
// all — but it is never treated as authoritative for anything that gets
// written. This closes the gap firestore.rules alone left: a future write
// path that forgets to extend a denylist (as Phase D itself did for the
// seller/delivery-partner branches — see firestore.rules' matching
// comment) previously let a tampered `after.productCreditApplied` dictate
// real money movement; now it cannot, because the trigger no longer trusts
// it for anything but the decision to open a transaction.
//
// Phase D-1, DEFECT D-1/Workstream 3: fires on a transition into
// 'cancelled' signalled by EITHER `orderStatus` OR the mirrored `status`
// field. firestore.rules' ownerOrderStatusChangeIsValid() already treats
// both as one signal, for the identical reason stated in its own comment:
// order_provider.dart's cancelOrder() (customer path) writes only
// orderStatus, but apps/marketplace/lib/screens/seller/
// seller_panel_screen.dart's _updateOrderStatus (and apps/admin's
// identical copy) writes ONLY `status` — an orderStatus-only guard
// silently missed every seller-initiated cancellation and permanently
// destroyed the customer's credit (it was already removed from `available`
// at HOLD and cleared from `onHold` at REDEMPTION; never returned).

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import { appendLedgerEntry, toProjectionFields } from "./productCreditLedger";

function isCancelled(status: unknown): boolean {
  return typeof status === "string" && status.toLowerCase() === "cancelled";
}

export const reverseProductCreditOnCancellation = functions.firestore
  .document("orders/{orderId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const orderId = context.params.orderId;

    // Transition guard: fires only when NEITHER field was already
    // 'cancelled' before this write, AND at least one of them is
    // 'cancelled' after it. A single write that sets both fields to
    // 'cancelled' at once is still exactly one Firestore update — one
    // trigger invocation — so this fires exactly once for it; the guard
    // only inspects the aggregate before/after state, not which
    // individual field(s) changed.
    const wasCancelled = isCancelled(before.orderStatus) || isCancelled(before.status);
    const isNowCancelled = isCancelled(after.orderStatus) || isCancelled(after.status);
    if (wasCancelled || !isNowCancelled) {
      return null;
    }

    // Cheap PRE-FILTER before any Firestore access, mirroring
    // employeeCommission.ts's early-return-on-no-employeeUid shape — NOT
    // authoritative for anything written below (see the module comment).
    // This only lets the common case (no credit applied, or already
    // reversed) skip opening a transaction.
    const preFilterCreditApplied =
      typeof after.productCreditApplied === "number" ? after.productCreditApplied : 0;
    if (preFilterCreditApplied <= 0) {
      return null;
    }
    if (after.productCreditReversed === true) {
      return null;
    }

    const db = admin.firestore();
    const orderRef = db.collection("orders").doc(orderId);

    try {
      await db.runTransaction(async (tx) => {
        // ============================================
        // ALL READS FIRST.
        // ============================================
        const orderSnap = await tx.get(orderRef);
        if (!orderSnap.exists) {
          return;
        }
        const order = orderSnap.data()!;

        // Every authoritative value below is re-derived HERE, from the
        // LIVE document read inside this transaction — never from `after`.
        // This block is also the idempotency re-check: a repeated/retried
        // trigger invocation (or a redelivered identical event, whose
        // `after` payload is fixed at original dispatch time and would
        // still show productCreditReversed:false) must not double-refund.
        if (order.productCreditReversed === true) {
          console.log(`⚠️ Product Credit already reversed for order ${orderId} (checked in tx) — skipping`);
          return;
        }
        const amount = typeof order.productCreditApplied === "number" ? order.productCreditApplied : 0;
        if (amount <= 0) {
          // The pre-filter saw a positive amount in `after`, but the live
          // document disagrees (e.g. a tampered/stale `after` payload) —
          // there is genuinely nothing to reverse. Do not write anything;
          // in particular, do not mark productCreditReversed:true for an
          // order that never had real credit to reverse.
          return;
        }
        const customerId = order.userId as string;
        // REVERSAL entries carry no enrollment scoping of their own — the
        // productCreditLedger.ts arithmetic table doesn't key REVERSAL off
        // enrollmentId, only off relatedEntryId (below).
        const enrollmentId = "";
        const relatedEntryId =
          typeof order.productCreditLedgerEntryId === "string" ? order.productCreditLedgerEntryId : null;

        const projectionRef = db.collection("product_credit_balances").doc(customerId);
        const projectionSnap = await tx.get(projectionRef);
        const currentProjection = toProjectionFields(projectionSnap.data());

        // ============================================
        // ALL WRITES.
        // ============================================
        appendLedgerEntry(tx, db, {
          customerId,
          enrollmentId,
          type: "REVERSAL",
          amount,
          currentProjection,
          relatedEntryId,
          orderId,
          description: `Reversal of Product Credit for cancelled order ${orderId}`,
        });

        tx.update(orderRef, { productCreditReversed: true });
      });

      console.log(`✅ Product Credit reversal processed for cancelled order ${orderId}`);
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : String(error);
      console.error(`❌ Failed to reverse Product Credit for order ${orderId}: ${message}`);
      throw error;
    }

    return null;
  });
