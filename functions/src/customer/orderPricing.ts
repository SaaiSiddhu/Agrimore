// ============================================================
//  Order pricing — extracted from createOrder.ts (Phase C, Workstream 4)
// ============================================================
//
// BEHAVIOUR-PRESERVING EXTRACTION. Every line of logic in this file is
// moved VERBATIM out of createOrder.ts — same HttpsError codes, same
// message strings, same computation order, same rounding. Nothing was
// "improved", reordered, or re-tidied. createOrder.ts's own transaction
// still does every Firestore read itself (products, coupon, per-user
// coupon-redemption existence) and passes the results in here; this module
// performs zero Firestore access, which is what makes it safe for
// productCreditHold.ts's quote callable (Phase C, Workstream 5) to call
// the exact same function from inside its OWN transaction and get the
// exact same numbers createOrder would.
//
// Why this file exists at all: before Product Credit redemption, the
// client computed its own local total and happened to agree with the
// server closely enough that createOrder's ±₹1 tolerance check never
// mattered in practice. Once a credit deduction enters the picture, the
// client cannot know the authoritative total ahead of a real quote — and
// any duplicate reimplementation of this logic (client-side or in a second
// server file) WILL eventually drift from createOrder's own numbers, which
// would then reject an already-paid order. One shared implementation is
// the only way both call sites can guarantee identical numbers.

import { HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

export interface OrderPricingItemInput {
  productId: string;
  quantity: number;
}

export interface ValidatedItem {
  productId: string;
  price: number;
  quantity: number;
  data: Record<string, unknown>;
}

interface CouponResult {
  discountAmount: number;
  couponCode: string | null;
}

export interface PerSellerPricing {
  /** null for the "_unassigned" seller sentinel — same meaning as
   *  createOrder's original `resolvedSellerId`. */
  sellerId: string | null;
  subtotal: number;
  discount: number;
  deliveryCharge: number;
  tax: number;
  total: number;
  items: Record<string, unknown>[];
}

export interface OrderPricingResult {
  validatedItems: ValidatedItem[];
  itemsBySeller: Map<string, Record<string, unknown>[]>;
  cartSubtotal: number;
  discountAmount: number;
  couponCode: string | null;
  deliveryCharge: number;
  tax: number;
  grandTotal: number;
  perSeller: PerSellerPricing[];
}

function roundMoney(value: number): number {
  return Math.round(value * 100) / 100;
}

/**
 * Ports CouponModel.calculateDiscount's exact logic
 * (packages/agrimore_core/lib/models/coupon_model.dart) server-side. Does
 * NOT reuse OrderService.validateCoupon
 * (packages/agrimore_services/lib/orders/order_service.dart) — that method
 * reads different, stale field names (expiry/usedCount/usageLimit/minOrder/
 * discountType vs. this schema's validFrom/validTo/minOrderAmount/type) left
 * over from an earlier port and is not what the live client checkout flow
 * actually calls (CouponProvider.calculateDiscount -> CouponModel.
 * calculateDiscount is the real, live path — verified by reading both).
 *
 * Takes an already-fetched QuerySnapshot instead of querying itself —
 * callers run inside their own db.runTransaction, and Firestore
 * transactions require every read to happen before any write.
 */
function computeCouponDiscount(
  couponSnap: FirebaseFirestore.QuerySnapshot | null,
  couponCode: string | undefined,
  orderAmount: number,
  validatedItems: ValidatedItem[]
): CouponResult {
  if (!couponCode || !couponCode.trim()) {
    return { discountAmount: 0, couponCode: null };
  }

  const normalizedCode = couponCode.trim().toUpperCase();
  if (!couponSnap || couponSnap.empty) {
    throw new HttpsError("failed-precondition", "Invalid coupon code");
  }

  const coupon = couponSnap.docs[0].data();
  const nowMs = Date.now();
  const validFromMs = (coupon.validFrom as admin.firestore.Timestamp | undefined)?.toMillis() ?? 0;
  const validToMs = (coupon.validTo as admin.firestore.Timestamp | undefined)?.toMillis() ?? 0;
  const isActive = coupon.isActive !== false;
  const usageLimit = typeof coupon.usageLimit === "number" ? coupon.usageLimit : 0;
  const usedCount = typeof coupon.usedCount === "number" ? coupon.usedCount : 0;

  const isValid =
    isActive && nowMs > validFromMs && nowMs < validToMs && (usageLimit === 0 || usedCount < usageLimit);
  if (!isValid) {
    throw new HttpsError(
      "failed-precondition",
      "This coupon has expired or reached its usage limit"
    );
  }

  const minOrderAmount = typeof coupon.minOrderAmount === "number" ? coupon.minOrderAmount : 0;
  if (orderAmount < minOrderAmount) {
    throw new HttpsError(
      "failed-precondition",
      `Minimum order amount is ₹${minOrderAmount}`
    );
  }

  const type = String(coupon.type || "flat");
  const discountValue = typeof coupon.discount === "number" ? coupon.discount : 0;
  let discountAmount = 0;

  if (type === "flat") {
    discountAmount = discountValue;
  } else if (type === "percentage") {
    discountAmount = (orderAmount * discountValue) / 100;
  } else if (type === "buyOneGetOne") {
    const buyProductId = coupon.buyProductId as string | undefined;
    const getProductId = coupon.getProductId as string | undefined;
    const buyItem = buyProductId
      ? validatedItems.find((i) => i.productId === buyProductId)
      : undefined;
    if (buyItem) {
      if (getProductId) {
        const getItem = validatedItems.find((i) => i.productId === getProductId);
        discountAmount = getItem ? getItem.price : 0;
      } else {
        discountAmount = buyItem.price;
      }
    }
  }

  const maxDiscountAmount = coupon.maxDiscountAmount as number | undefined;
  if (typeof maxDiscountAmount === "number" && discountAmount > maxDiscountAmount) {
    discountAmount = maxDiscountAmount;
  }

  return {
    discountAmount: Math.max(0, discountAmount),
    couponCode: (coupon.code as string | undefined) || normalizedCode,
  };
}

export interface ComputeOrderPricingParams {
  items: OrderPricingItemInput[];
  /** Same order as `items` — e.g. from `tx.getAll(...productRefs)`. */
  productSnaps: FirebaseFirestore.DocumentSnapshot[];
  orderMode: "B2C" | "B2B";
  uid: string;
  couponSnap: FirebaseFirestore.QuerySnapshot | null;
  couponCode?: string;
  /** Whether this exact coupon code has already been redeemed by `uid` —
   *  a pre-computed boolean (from the caller's own
   *  coupon_redemptions/{code}_{uid} read) rather than a Firestore
   *  snapshot, so this function stays read-free while still throwing at
   *  EXACTLY the same point in the validation sequence createOrder always
   *  has: after the coupon's own validity/discount is computed, before the
   *  delivery/tax sanity ceilings. */
  couponAlreadyRedeemed?: boolean;
  deliveryCharge?: number;
  tax?: number;
}

const MAX_REASONABLE_DELIVERY_CHARGE = 1000;
const MAX_REASONABLE_TAX = 1000;

/**
 * Phase FIX-3 (findings N-4, N-23-partial).
 *
 * Upper bound on DISTINCT product lines in one cart. It exists to bound the
 * `tx.getAll(...productRefs)` both callers perform — that read was previously
 * unbounded, so a crafted request could ask the transaction to fetch an
 * arbitrary number of documents. 100 distinct products is far above any real
 * grocery basket while still being a bound.
 */
export const MAX_CART_LINES = 100;

/**
 * Phase FIX-3 (finding N-4, P1). Collapses repeated `productId` entries into
 * one line with the summed quantity, and enforces MAX_CART_LINES.
 *
 * WHY THIS EXISTS: `computeOrderPricing` validates stock per ITEM ENTRY, not
 * per product. A cart of `[{p,5},{p,5}]` against `stock: 5` passed the check
 * twice and oversold — each entry was compared against the full stock
 * independently. Summing first makes the existing check correct without
 * touching it.
 *
 * WHY IT LIVES HERE, and why both callers must call it BEFORE building their
 * product refs:
 *   - `createOrder.ts` and `productCreditHold.ts` (quoteOrderWithCredit) both
 *     call computeOrderPricing, and this module exists precisely so the quote
 *     and the order can never disagree on a number (see the file header). A
 *     de-duplication implemented in one caller would reintroduce exactly the
 *     drift this file was created to prevent.
 *   - The cap must be applied before `tx.getAll`, which happens in the caller.
 *     Enforcing it inside computeOrderPricing would be too late to bound the
 *     read it is meant to bound.
 *   - `computeCartFingerprint` (productCreditHold.ts) hashes the item list, and
 *     createOrder re-derives that fingerprint to validate a hold. Both sides
 *     must therefore fingerprint the SAME normalized list, or every hold would
 *     fail its cart-change guard. Normalize first, then use the normalized
 *     array for the fingerprint, the refs and the pricing alike.
 *
 * First-appearance order is preserved so that per-seller grouping, the
 * order-number suffixing and the BOGO coupon match keep their existing,
 * observable ordering.
 */
export function normalizeOrderItems(items: OrderPricingItemInput[]): OrderPricingItemInput[] {
  const byProduct = new Map<string, OrderPricingItemInput>();
  for (const item of items) {
    const existing = byProduct.get(item.productId);
    if (existing) {
      existing.quantity += item.quantity;
    } else {
      byProduct.set(item.productId, { productId: item.productId, quantity: item.quantity });
    }
  }
  const normalized = Array.from(byProduct.values());
  if (normalized.length > MAX_CART_LINES) {
    throw new HttpsError(
      "invalid-argument",
      `A cart cannot contain more than ${MAX_CART_LINES} different products`
    );
  }
  return normalized;
}

export function computeOrderPricing(params: ComputeOrderPricingParams): OrderPricingResult {
  const { items, productSnaps, orderMode, uid } = params;

  // Re-derive every price server-side. Never trust client-supplied amounts.
  // Grouped by sellerId as we go — see the multi-seller note in
  // createOrder.ts. Also kept as a flat list (validatedItems) for coupon
  // BOGO matching.
  const itemsBySeller = new Map<string, Record<string, unknown>[]>();
  const validatedItems: ValidatedItem[] = [];
  let cartSubtotal = 0;

  for (let i = 0; i < items.length; i++) {
    const item = items[i];
    const productSnap = productSnaps[i];
    if (!productSnap.exists) {
      throw new HttpsError("not-found", `Product ${item.productId} not found`);
    }
    const product = productSnap.data()!;

    let price: number;
    if (orderMode === "B2B") {
      if (product.isB2BEnabled !== true) {
        throw new HttpsError(
          "failed-precondition",
          `Product ${item.productId} is not enabled for B2B ordering`
        );
      }
      if (typeof product.b2bPrice !== "number") {
        throw new HttpsError(
          "failed-precondition",
          `Product ${item.productId} has no B2B price configured`
        );
      }
      const moq = typeof product.b2bMoq === "number" ? product.b2bMoq : 1;
      if (item.quantity < moq) {
        throw new HttpsError(
          "failed-precondition",
          `Quantity for product ${item.productId} is below the minimum order quantity (${moq})`
        );
      }
      price = product.b2bPrice;
    } else {
      if (typeof product.salePrice !== "number") {
        throw new HttpsError(
          "failed-precondition",
          `Product ${item.productId} has no price configured`
        );
      }
      price = product.salePrice;
    }

    // Stock validation. Fail-OPEN (with a logged warning) when `stock` is
    // missing or non-numeric, rather than fail-closed — deliberately
    // mirroring packages/agrimore_core/lib/models/product_model.dart's own
    // ProductModel.fromMap, which defaults a missing/non-numeric stock to
    // 999. When stock IS a real number, it is enforced exactly.
    const stockRaw = product.stock;
    if (typeof stockRaw !== "number" || !Number.isFinite(stockRaw)) {
      console.warn(
        `⚠️ Product ${item.productId} has no numeric stock field — assuming available (mirrors ProductModel.fromMap's default of 999). Backfill this product's stock to enforce real limits.`
      );
    } else if (stockRaw < item.quantity) {
      throw new HttpsError(
        "failed-precondition",
        `Product ${item.productId} does not have enough stock (available: ${stockRaw}, requested: ${item.quantity})`
      );
    }

    const sellerId = typeof product.sellerId === "string" && product.sellerId ? product.sellerId : "_unassigned";
    cartSubtotal += price * item.quantity;

    const validatedItem: Record<string, unknown> = {
      id: item.productId,
      productId: item.productId,
      productName: product.name || "",
      productImage: Array.isArray(product.images) && product.images.length > 0 ? product.images[0] : "",
      price,
      quantity: item.quantity,
      userId: uid,
      sellerId: sellerId === "_unassigned" ? "" : sellerId,
      // Server timestamps are not supported inside array elements — use a
      // fixed Timestamp instead of FieldValue.serverTimestamp() here.
      addedAt: admin.firestore.Timestamp.now(),
    };

    validatedItems.push({ productId: item.productId, price, quantity: item.quantity, data: validatedItem });

    const bucket = itemsBySeller.get(sellerId);
    if (bucket) {
      bucket.push(validatedItem);
    } else {
      itemsBySeller.set(sellerId, [validatedItem]);
    }
  }

  // Coupon discount — server-computed, never trusted from the client.
  const { discountAmount, couponCode } = computeCouponDiscount(
    params.couponSnap,
    params.couponCode,
    cartSubtotal,
    validatedItems
  );

  // Per-user redemption re-check — same point in the sequence
  // createOrder.ts always ran it: after the coupon's own validity check,
  // before the delivery/tax sanity ceilings.
  if (couponCode && params.couponAlreadyRedeemed) {
    throw new HttpsError("failed-precondition", "You have already redeemed this coupon");
  }

  // deliveryCharge/tax have no server-side source of truth to recompute
  // from — apply a sanity ceiling instead of trusting the client number
  // outright. This is a stopgap, not a fix; it only catches a
  // wildly-inflated value, not a modestly inflated one.
  const deliveryCharge =
    typeof params.deliveryCharge === "number" && params.deliveryCharge > 0 ? params.deliveryCharge : 0;
  const tax = typeof params.tax === "number" && params.tax > 0 ? params.tax : 0;
  if (deliveryCharge > MAX_REASONABLE_DELIVERY_CHARGE) {
    throw new HttpsError(
      "invalid-argument",
      `deliveryCharge exceeds the maximum allowed value of ₹${MAX_REASONABLE_DELIVERY_CHARGE}`
    );
  }
  if (tax > MAX_REASONABLE_TAX) {
    throw new HttpsError(
      "invalid-argument",
      `tax exceeds the maximum allowed value of ₹${MAX_REASONABLE_TAX}`
    );
  }
  const grandTotal = roundMoney(Math.max(0, cartSubtotal - discountAmount) + deliveryCharge + tax);

  // Per-seller ratio split — mirrors _createSellerScopedOrders's own
  // ratio-based discount/delivery/tax distribution exactly (by seller
  // subtotal share of the cart total).
  //
  // FIX-9, WS7. Every seller's discount/deliveryCharge/tax/total used to be
  // rounded independently with no reconciliation step, so
  // sum(perSeller[].total) could drift from grandTotal by up to roughly
  // sellerCount x 0.5 paisa — small, but a real gap between what the
  // customer was charged and what the per-seller records (which
  // calculateSellerPayout reads) sum to. createOrder.ts's own comment shows
  // this "last one absorbs the residual" pattern already exists for
  // creditApplied distribution; generalized here to all four per-seller
  // fields, not just total. Running totals track every EARLIER seller's
  // rounded share; the LAST seller in iteration order gets the exact
  // remainder instead of its own independently-rounded value, so the sums
  // are exact by construction rather than by coincidence.
  const sellerCount = itemsBySeller.size;
  const perSeller: PerSellerPricing[] = [];
  let discountAssigned = 0;
  let deliveryAssigned = 0;
  let taxAssigned = 0;
  let totalAssigned = 0;
  let sellerIndex = 0;
  for (const [sellerId, sellerItems] of itemsBySeller.entries()) {
    sellerIndex += 1;
    const isLastSeller = sellerIndex === sellerCount;
    let sellerSubtotal = 0;
    for (const item of sellerItems) {
      sellerSubtotal += (item.price as number) * (item.quantity as number);
    }
    const ratio = cartSubtotal > 0 ? sellerSubtotal / cartSubtotal : 1 / sellerCount;

    const sellerDiscount = isLastSeller
      ? roundMoney(discountAmount - discountAssigned)
      : roundMoney(discountAmount * ratio);
    const sellerDeliveryCharge = isLastSeller
      ? roundMoney(deliveryCharge - deliveryAssigned)
      : roundMoney(deliveryCharge * ratio);
    const sellerTax = isLastSeller
      ? roundMoney(tax - taxAssigned)
      : roundMoney(tax * ratio);
    const sellerTotal = isLastSeller
      ? roundMoney(grandTotal - totalAssigned)
      : roundMoney(Math.max(0, sellerSubtotal - sellerDiscount) + sellerDeliveryCharge + sellerTax);

    discountAssigned = roundMoney(discountAssigned + sellerDiscount);
    deliveryAssigned = roundMoney(deliveryAssigned + sellerDeliveryCharge);
    taxAssigned = roundMoney(taxAssigned + sellerTax);
    totalAssigned = roundMoney(totalAssigned + sellerTotal);

    const resolvedSellerId = sellerId === "_unassigned" ? null : sellerId;

    perSeller.push({
      sellerId: resolvedSellerId,
      subtotal: roundMoney(sellerSubtotal),
      discount: sellerDiscount,
      deliveryCharge: sellerDeliveryCharge,
      tax: sellerTax,
      total: sellerTotal,
      items: sellerItems,
    });
  }

  return {
    validatedItems,
    itemsBySeller,
    cartSubtotal,
    discountAmount,
    couponCode,
    deliveryCharge,
    tax,
    grandTotal,
    perSeller,
  };
}
