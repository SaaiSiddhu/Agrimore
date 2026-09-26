// ============================================================
//  LOW-STOCK ALERT & INVENTORY MANAGEMENT CLOUD FUNCTIONS
// ============================================================

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { log } from "../common/helpers";
import { notifyUser } from "./orderNotifications";

/**
 * Trigger: Fires when a product document is updated.
 * Purpose: Check if stock has dropped below threshold and send
 *          a push notification to the seller.
 *
 * Phase ADMR-4 rewrite. Three confirmed bugs in the previous version:
 *   - Compared only before.stock/after.stock (the BASE field). A sale that
 *     only moves a variant's own stock — every variant-line order, since
 *     createOrder.ts decrements product.variants[i].stock directly for
 *     those lines (SELLER-CATALOGUE-2) — never changed the base field, so
 *     this trigger never fired for a variant-only product, ever.
 *   - Fired on every further decrease while ALREADY at/below threshold, not
 *     just the first crossing (`currentStock >= previousStock` was the only
 *     guard) — a seller selling through an already-low item got a push on
 *     every single subsequent sale.
 *   - The push send and the inventory_alerts write shared one try block, so
 *     a stale/invalid FCM token (common) threw before the alert doc was
 *     ever written — losing the RECORD, not just the notification.
 *
 * Fixed by checking each "unit" (the base product, plus every variant
 * matched to its `before` counterpart by stable id — never a positional
 * index, which could drift if variants were reordered in this same write)
 * for a genuine above-to-at-or-below crossing, and by reusing notifyUser()
 * (already used by sellerWallet.ts for exactly this "push may fail, the
 * record must not" shape) instead of a hand-rolled admin.messaging().send().
 */
export const onProductStockChanged = functions.firestore
  .document("products/{productId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const productId = context.params.productId;
    const productName = after.name ?? "Unknown Product";
    const sellerId = after.sellerId;
    const threshold =
      typeof after.lowStockThreshold === "number" && Number.isFinite(after.lowStockThreshold)
        ? after.lowStockThreshold
        : 5;

    interface Unit {
      variantId: string | null;
      variantName: string | null;
      previousStock: number;
      currentStock: number;
    }
    const units: Unit[] = [];

    if (typeof before.stock === "number" && typeof after.stock === "number") {
      units.push({ variantId: null, variantName: null, previousStock: before.stock, currentStock: after.stock });
    }

    const beforeVariants: Record<string, unknown>[] = Array.isArray(before.variants) ? before.variants : [];
    const afterVariants: Record<string, unknown>[] = Array.isArray(after.variants) ? after.variants : [];
    for (const av of afterVariants) {
      const variantId = typeof av.id === "string" ? av.id : null;
      if (!variantId) continue;
      const bv = beforeVariants.find((v) => typeof v.id === "string" && v.id === variantId);
      if (!bv) continue; // a variant that didn't exist in `before` has nothing to compare against
      const previousStock = bv.stock;
      const currentStock = av.stock;
      if (typeof previousStock !== "number" || typeof currentStock !== "number") continue;
      const variantName = typeof av.name === "string" ? av.name : null;
      units.push({ variantId, variantName, previousStock, currentStock });
    }

    // A genuine crossing: was above the threshold, is now at or below it.
    // Excludes every further decrease while already below — that used to
    // re-fire this trigger, and a real push, on every subsequent sale.
    const crossed = units.filter((u) => u.previousStock > threshold && u.currentStock <= threshold);
    if (crossed.length === 0) return null;

    for (const u of crossed) {
      const label = u.variantName ? `${productName} (${u.variantName})` : String(productName);
      const title = u.currentStock === 0 ? "⚠️ Out of Stock!" : "📉 Low Stock Alert";
      const body =
        u.currentStock === 0
          ? `"${label}" is now out of stock. Restock immediately to avoid losing sales.`
          : `"${label}" has only ${u.currentStock} units left. Consider restocking soon.`;

      log.info(`📉 Low stock alert: "${label}" has ${u.currentStock} units left (threshold: ${threshold})`);

      if (sellerId) {
        // Never throws on a push failure (an invalid/stale FCM token is
        // common) — it also writes the seller's in-app inbox entry, which
        // this trigger never gave sellers before. A rare non-push failure
        // (e.g. the users/{sellerId} read itself) is still caught here so
        // it can never skip the alert-persistence write below.
        await notifyUser(
          sellerId,
          title,
          body,
          "low_stock",
          { productId, productName: String(productName), variantId: u.variantId ?? "", currentStock: String(u.currentStock) },
          "📉"
        ).catch((e) => log.error(`❌ Low-stock notifyUser failed: ${e}`));
      }

      // Always attempted, regardless of the notification outcome above —
      // previously this shared one try block with the push send, so a
      // stale token silently skipped this write too.
      try {
        await admin.firestore().collection("inventory_alerts").add({
          productId,
          productName,
          sellerId: sellerId || null,
          variantId: u.variantId,
          variantName: u.variantName,
          previousStock: u.previousStock,
          currentStock: u.currentStock,
          threshold,
          alertType: u.currentStock === 0 ? "out_of_stock" : "low_stock",
          isRead: false,
          createdAt: FieldValue.serverTimestamp(),
        });
      } catch (error: any) {
        log.error(`❌ Low-stock alert persistence error: ${error.message}`);
      }
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
