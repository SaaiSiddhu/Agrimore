// ============================================================
//  RESTORE STOCK ON CANCELLATION — Order Cancellation Trigger
//  (Phase ADMR-1)
// ============================================================
//
// Mirrors productCreditReversal.ts's trigger shape exactly: a Firestore
// onUpdate trigger on orders/{orderId}, firing only on the transition INTO
// 'cancelled' (checking both `orderStatus` and `status`, for the identical
// reason that file's own header documents — different write paths use
// different fields), idempotent via a `stockRestored` flag re-checked AND
// written inside the same transaction that performs the restoration.
//
// WHY A TRIGGER, NOT CALLABLE-LOCAL CODE: before this phase, stock
// restoration lived entirely inside sellerTransitionOrder.ts's own
// transaction — the ONLY cancellation path that ever restored anything.
// Two other paths can move an order to 'cancelled' and always could: the
// customer's own cancellation (a direct, rules-guarded client write — see
// firestore.rules' ownerOrderStatusChangeIsValid()) and apps/admin's
// order_provider.dart, which also writes orderStatus directly. Neither
// path ever went through sellerTransitionOrder, so neither ever restored a
// single unit of stock — a real, live gap, not a hypothetical one.
// Commission and credit reversal do NOT share this gap:
// reverseEmployeeCommissionOnCancellation and
// reverseProductCreditOnCancellation are already generic triggers that
// fire regardless of who wrote the cancellation. Making stock restoration
// a trigger too closes the last uncovered path, uniformly.
//
// VARIANT-AWARE, BY STABLE ID: createOrder.ts decrements a variant line's
// OWN stock inside product.variants[], resolved by the variant's stable
// `id` field (orderPricing.ts's findVariant()), and persists that same
// `variantId` string onto the order's own item record — never a raw
// positional index. sellerTransitionOrder.ts's old restore block ignored
// variants entirely and always incremented the BASE `stock` field, so a
// cancelled variant-line order permanently understated that variant's own
// stock AND wrongly inflated base stock (a unit that was never taken from
// base was handed back to it). This trigger re-resolves each variant line
// by that same stable id against the CURRENT variants array — never a
// stored index, which could point at the wrong entry if the seller has
// since reordered or edited the array — and restores into the matching
// variant's own stock field, falling back to base-line restoration only
// for lines that never carried a variantId (every order-creation path:
// createOrderFromRfq.ts's items never carry one either, so RFQ-derived
// orders fall through to the same base-only restore they always used).
//
// If a variant referenced by an order line no longer exists (deleted
// since the order was placed) this deliberately does NOT fold that unit
// into base stock — doing so would misattribute it to the wrong SKU. It
// is logged and otherwise skipped; a proper exception queue for this class
// of case is future inventory-ledger work (admin-restructure register
// domain B08), not this phase's scope.
//
// ADMR-37: a cancellation reached FROM 'delivered' is different in kind
// from every other one above — the customer already has physical
// possession, so auto-restoring stock the instant the status flips would
// claim inventory is sellable again before anyone has confirmed the item
// physically came back. This trigger does not decide return/refund/
// inspection policy (none of that is decided anywhere in this codebase
// today) — it only refuses to silently ASSUME a return happened. A
// delivered→cancelled transition instead sets `stockRestorePending: true`
// and leaves `stockRestored` unset; `confirmOrderReturnReceived.ts` (admin-
// only) is the sole path that later resolves it, by calling the exact same
// `restoreOrderItemStock` this trigger uses for every other cancellation,
// so the two paths can never drift apart on HOW a unit is restored — only
// on WHEN. Every other transition into 'cancelled' (the overwhelming
// majority — pre-delivery, no physical handoff yet) is unaffected.
//
// Generation: v1 Firestore trigger, no secrets.

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

interface OrderItem {
  productId?: string;
  quantity?: number;
  variantId?: string;
}

function isCancelled(status: unknown): boolean {
  return typeof status === "string" && status.toLowerCase() === "cancelled";
}

function isDelivered(status: unknown): boolean {
  return typeof status === "string" && status.toLowerCase() === "delivered";
}

/**
 * Restores every line of a cancelled order's stock (base or variant, by
 * stable id) into the current product documents — the exact logic this
 * trigger always ran, unchanged, extracted only so
 * confirmOrderReturnReceived.ts's admin-confirmed path can share it byte
 * for byte instead of reimplementing it. Must be called with every read
 * already done by the caller (`order` itself) — this function does its
 * OWN product reads via `tx.get`, so it must run before the caller's own
 * writes, same as any other Firestore transaction.
 */
export async function restoreOrderItemStock(
  tx: FirebaseFirestore.Transaction,
  db: admin.firestore.Firestore,
  order: FirebaseFirestore.DocumentData,
  orderId: string
): Promise<void> {
  const items: OrderItem[] = Array.isArray(order.items) ? order.items : [];
  if (items.length === 0) {
    return;
  }

  // One read per distinct product, even if the order lists the same
  // product on more than one line (mirrors sellerTransitionOrder.ts's
  // own dedup, which mirrored createOrder.ts's before it).
  const productIds = [...new Set(
    items
      .map((i) => i.productId)
      .filter((id): id is string => typeof id === "string" && id.length > 0)
  )];
  const productSnaps = await Promise.all(
    productIds.map((id) => tx.get(db.collection("products").doc(id)))
  );

  const now = admin.firestore.FieldValue.serverTimestamp();

  for (const productSnap of productSnaps) {
    if (!productSnap.exists) continue; // product deleted since the order — nothing to restore into
    const data = productSnap.data() ?? {};
    const lines = items.filter((i) => i.productId === productSnap.id);

    let baseQty = 0;
    const variants = Array.isArray(data.variants)
      ? (data.variants as Record<string, unknown>[]).map((v) => ({ ...v }))
      : null;
    let variantsChanged = false;

    for (const line of lines) {
      const qty = typeof line.quantity === "number" && Number.isFinite(line.quantity) ? line.quantity : 0;
      if (qty <= 0) continue;

      if (line.variantId && variants) {
        const vIndex = variants.findIndex(
          (v) => typeof v === "object" && v !== null && (v as Record<string, unknown>).id === line.variantId
        );
        if (vIndex >= 0) {
          const vs = variants[vIndex].stock;
          if (typeof vs === "number" && Number.isFinite(vs)) {
            variants[vIndex].stock = vs + qty;
            variantsChanged = true;
          } else {
            functions.logger.warn("restoreOrderItemStock: variant stock not numeric, skipped", {
              orderId, productId: productSnap.id, variantId: line.variantId,
            });
          }
          continue; // matched (whether or not its stock was usable) — never fall through to base
        }
        functions.logger.warn("restoreOrderItemStock: variant no longer exists, skipped (not folded into base)", {
          orderId, productId: productSnap.id, variantId: line.variantId, qty,
        });
        continue; // deleted variant — do not misattribute this unit to base stock
      }

      baseQty += qty;
    }

    const stockRaw = data.stock;
    const stockIsEnforceable = typeof stockRaw === "number" && Number.isFinite(stockRaw);
    const update: Record<string, unknown> = {};
    if (baseQty > 0 && stockIsEnforceable) {
      update.stock = admin.firestore.FieldValue.increment(baseQty);
    }
    if (variantsChanged) {
      update.variants = variants;
    }
    if (Object.keys(update).length > 0) {
      update.updatedAt = now;
      tx.update(productSnap.ref, update);
    }
  }
}

export const restoreStockOnCancellation = functions.firestore
  .document("orders/{orderId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data() ?? {};
    const after = change.after.data() ?? {};
    const orderId = context.params.orderId;

    // Transition guard, identical shape to productCreditReversal.ts's own.
    const wasCancelled = isCancelled(before.orderStatus) || isCancelled(before.status);
    const isNowCancelled = isCancelled(after.orderStatus) || isCancelled(after.status);
    if (wasCancelled || !isNowCancelled) {
      return null;
    }

    const db = admin.firestore();
    const orderRef = db.collection("orders").doc(orderId);

    // ADMR-37: see the header above — a delivered order's stock is never
    // auto-restored. This is a plain, idempotent flag merge (not a
    // transaction): it changes no financial or inventory count, and
    // setting `stockRestorePending: true` when it is already `true` is a
    // no-op either way. It does not re-trigger this same function
    // recursively — the recursive event's OWN `before` snapshot already
    // shows `orderStatus: 'cancelled'`, so the `wasCancelled` guard above
    // catches it immediately.
    const wasDelivered = isDelivered(before.orderStatus) || isDelivered(before.status);
    if (wasDelivered) {
      if (after.stockRestorePending !== true) {
        await orderRef.set({ stockRestorePending: true }, { merge: true });
      }
      return null;
    }

    // Cheap pre-filter before opening a transaction — NOT authoritative;
    // see the in-transaction re-check below.
    if (after.stockRestored === true) {
      return null;
    }
    const preFilterItems: OrderItem[] = Array.isArray(after.items) ? after.items : [];
    if (preFilterItems.length === 0) {
      return null;
    }

    await db.runTransaction(async (tx) => {
      // Re-read the order LIVE inside the transaction — never trust the
      // trigger's own `after` payload for the authoritative decision, the
      // same defence-in-depth productCreditReversal.ts's header explains:
      // a retried/redelivered trigger event still carries the ORIGINAL
      // `after` snapshot even after a first invocation already restored.
      const orderSnap = await tx.get(orderRef);
      const order = orderSnap.data();
      if (!order || order.stockRestored === true) {
        return;
      }
      if (!Array.isArray(order.items) || order.items.length === 0) {
        tx.update(orderRef, { stockRestored: true });
        return;
      }

      await restoreOrderItemStock(tx, db, order, orderId);

      tx.update(orderRef, { stockRestored: true });
    });

    return null;
  });
