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

    // Cheap pre-filter before opening a transaction — NOT authoritative;
    // see the in-transaction re-check below.
    if (after.stockRestored === true) {
      return null;
    }
    const preFilterItems: OrderItem[] = Array.isArray(after.items) ? after.items : [];
    if (preFilterItems.length === 0) {
      return null;
    }

    const db = admin.firestore();
    const orderRef = db.collection("orders").doc(orderId);

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
      const items: OrderItem[] = Array.isArray(order.items) ? order.items : [];
      if (items.length === 0) {
        tx.update(orderRef, { stockRestored: true });
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
                functions.logger.warn("restoreStockOnCancellation: variant stock not numeric, skipped", {
                  orderId, productId: productSnap.id, variantId: line.variantId,
                });
              }
              continue; // matched (whether or not its stock was usable) — never fall through to base
            }
            functions.logger.warn("restoreStockOnCancellation: variant no longer exists, skipped (not folded into base)", {
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

      tx.update(orderRef, { stockRestored: true });
    });

    return null;
  });
