// ============================================================
//  Order pricing — extracted from createOrder.ts (Phase C, Workstream 4)
// ============================================================
//
// Originally a behaviour-preserving extraction from createOrder.ts.
// Subsequent shared validation rejects unsafe quantities and money; valid
// pricing retains the existing computation order and rounding. Its transaction
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
import { DeliveryFeeSchedule, computeFeeFromSchedule } from "./deliveryFeeSchedule";

export interface OrderPricingItemInput {
  productId: string;
  quantity: number;
  /** SELLER-CATALOGUE-2: the chosen variant (its `id`, or its name for
   *  variants stored without one — the marketplace cart keeps the name). */
  variantId?: string;
}

export const MAX_VARIANT_ID_LENGTH = 120;

/** Name a variant is known by, with the same fallbacks as
 *  ProductVariant.fromMap (name → weight → label → title). */
function variantName(v: Record<string, unknown>): string {
  for (const k of ["name", "weight", "label", "title"]) {
    if (typeof v[k] === "string" && (v[k] as string).trim()) return (v[k] as string).trim();
  }
  return "";
}

/** The variant a line refers to: by `id` first, then by name. */
export function findVariant(
  product: Record<string, unknown>,
  variantId: string
): { index: number; variant: Record<string, unknown> } | null {
  const variants = Array.isArray(product.variants) ? (product.variants as unknown[]) : [];
  const byId = variants.findIndex((v) => typeof v === "object" && v !== null && (v as Record<string, unknown>).id === variantId);
  const index = byId >= 0 ? byId : variants.findIndex((v) => typeof v === "object" && v !== null && variantName(v as Record<string, unknown>) === variantId);
  return index >= 0 ? { index, variant: variants[index] as Record<string, unknown> } : null;
}

/** First positive price among the same fields ProductVariant.fromMap reads. */
function positivePrice(o: Record<string, unknown>): number | null {
  for (const k of ["salePrice", "price", "discountedPrice"]) {
    const v = o[k];
    const n = typeof v === "number" ? v : typeof v === "string" ? Number(v) : NaN;
    if (Number.isFinite(n) && n > 0) return n;
  }
  return null;
}

export interface ValidatedItem {
  productId: string;
  price: number;
  quantity: number;
  data: Record<string, unknown>;
  /** Index into product.variants when the line is a variant. */
  variantIndex?: number;
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

/** Monetary arithmetic must stay finite and within exact integer-paise
 * representation. Existing fractional-rupee rounding is preserved; this is
 * a numerical bound, not a new business limit. Legacy seller-split residuals
 * may be signed, so those components are checked with allowNegative. */
export function assertSafeOrderMoney(value: number, allowNegative = false): void {
  if (!Number.isFinite(value) || (!allowNegative && value < 0) ||
      !Number.isSafeInteger(Math.round(Math.abs(value) * 100))) {
    throw new HttpsError("failed-precondition", "Order pricing cannot be calculated safely");
  }
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
  if (typeof maxDiscountAmount === "number" && !Number.isFinite(maxDiscountAmount)) {
    throw new HttpsError("failed-precondition", "Order pricing cannot be calculated safely");
  }
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
  /** Phase FIX-8, Workstream 1. Keyed by real sellerId (never the
   *  "_unassigned" sentinel) — the caller's own already-fetched, already-
   *  parsed schedule for each seller in the cart, or omitted entirely for a
   *  seller with none configured. ONLY consulted when the cart resolves to
   *  exactly one real seller (see the single-seller guard below) — a
   *  multi-seller cart keeps 100% of the legacy ratio-split behaviour
   *  unconditionally in this workstream; correctly prorating multiple
   *  independent per-seller schedules across one client-supplied total is
   *  deferred to its own follow-up (see the ledger row), not guessed at
   *  here. This function still performs zero Firestore access — the caller
   *  reads and parses every schedule before calling in, same discipline as
   *  every other input here. */
  sellerFeeSchedules?: Map<string, DeliveryFeeSchedule>;
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
  // One line per product + variant (SELLER-CATALOGUE-2): two variants of
  // the same product are different goods with different prices and stock.
  const byProduct = new Map<string, OrderPricingItemInput>();
  const quantityByProduct = new Map<string, number>();
  for (const item of items) {
    if (!Number.isSafeInteger(item.quantity) || item.quantity <= 0) {
      throw new HttpsError("invalid-argument", `Invalid quantity for product ${item.productId}`);
    }
    // soldCount is incremented per product, across its variants as well.
    const productQuantity = (quantityByProduct.get(item.productId) ?? 0) + item.quantity;
    if (!Number.isSafeInteger(productQuantity)) {
      throw new HttpsError("invalid-argument", `Invalid quantity for product ${item.productId}`);
    }
    quantityByProduct.set(item.productId, productQuantity);
    const variantId = typeof item.variantId === "string" && item.variantId.trim() ? item.variantId.trim() : undefined;
    const key = variantId ? `${item.productId}\u0000${variantId}` : item.productId;
    const existing = byProduct.get(key);
    if (existing) {
      existing.quantity += item.quantity;
    } else {
      byProduct.set(key, variantId ? { productId: item.productId, quantity: item.quantity, variantId } : { productId: item.productId, quantity: item.quantity });
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

    // Catalogue visibility is also the server-side purchase policy. Keep
    // legacy products compatible with ProductModel.fromMap (missing
    // isActive defaults true; missing isDraft defaults false), while
    // refusing products the seller/admin explicitly hid or saved as drafts.
    if (product.isActive === false || product.isDraft === true) {
      throw new HttpsError(
        "failed-precondition",
        `Product ${item.productId} is not available for purchase`
      );
    }

    // SELLER-CATALOGUE-2: a line naming a variant is priced and stock-checked
    // against that variant. A line without one keeps the base-product
    // behaviour (older app versions never send variantId).
    const chosen = item.variantId ? findVariant(product, item.variantId) : null;
    if (item.variantId && !chosen) {
      throw new HttpsError("not-found", `Option "${item.variantId}" of product ${item.productId} is no longer available`);
    }
    const variant = chosen?.variant;

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
      // B2C pricing: resolve the active price with parity to agrimore_core's
      // ProductModel.fromMap and ProductVariant.fromMap, which fall back to
      // `price` / `discountPrice` when `salePrice` is absent (61 of 65
      // catalog products in production use `price`).
      let candidatePrice: number | null = null;
      if (typeof product.salePrice === "number" && Number.isFinite(product.salePrice) && product.salePrice > 0) {
        candidatePrice = product.salePrice;
      } else if (typeof product.price === "number" && Number.isFinite(product.price) && product.price > 0) {
        candidatePrice = product.price;
      } else if (typeof product.discountPrice === "number" && Number.isFinite(product.discountPrice) && product.discountPrice > 0) {
        candidatePrice = product.discountPrice;
      } else if (typeof product.discountedPrice === "number" && Number.isFinite(product.discountedPrice) && product.discountedPrice > 0) {
        candidatePrice = product.discountedPrice;
      } else if (typeof product.salePrice === "string" && !isNaN(Number(product.salePrice)) && Number(product.salePrice) > 0) {
        candidatePrice = Number(product.salePrice);
      } else if (typeof product.price === "string" && !isNaN(Number(product.price)) && Number(product.price) > 0) {
        candidatePrice = Number(product.price);
      }

      if (variant) {
        const variantPrice = positivePrice(variant);
        if (variantPrice === null) {
          throw new HttpsError("failed-precondition", `Option "${item.variantId}" of product ${item.productId} has no price`);
        }
        candidatePrice = variantPrice;
      }

      if (candidatePrice === null) {
        throw new HttpsError(
          "failed-precondition",
          `Product ${item.productId} has no price configured`
        );
      }
      price = candidatePrice;
    }

    assertSafeOrderMoney(price);
    const lineSubtotal = price * item.quantity;
    assertSafeOrderMoney(lineSubtotal);

    // Stock validation. Fail-OPEN (with a logged warning) when `stock` is
    // missing or non-numeric, rather than fail-closed — deliberately
    // mirroring packages/agrimore_core/lib/models/product_model.dart's own
    // ProductModel.fromMap, which defaults a missing/non-numeric stock to
    // 999. When stock IS a real number, it is enforced exactly.
    const stockRaw = variant ? variant.stock : product.stock;
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
    cartSubtotal += lineSubtotal;
    assertSafeOrderMoney(cartSubtotal);

    const validatedItem: Record<string, unknown> = {
      id: item.productId,
      productId: item.productId,
      productName: product.name || "",
      productImage:
        variant && Array.isArray(variant.images) && variant.images.length > 0
          ? variant.images[0]
          : Array.isArray(product.images) && product.images.length > 0
            ? product.images[0]
            : "",
      price,
      // `variant` is the field CartItemModel (and so every app) reads.
      ...(variant ? { variantId: typeof variant.id === "string" && variant.id ? variant.id : item.variantId, variant: variantName(variant) } : {}),
      quantity: item.quantity,
      userId: uid,
      sellerId: sellerId === "_unassigned" ? "" : sellerId,
      // Server timestamps are not supported inside array elements — use a
      // fixed Timestamp instead of FieldValue.serverTimestamp() here.
      addedAt: admin.firestore.Timestamp.now(),
    };

    validatedItems.push({ productId: item.productId, price, quantity: item.quantity, data: validatedItem, variantIndex: chosen?.index });

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
  assertSafeOrderMoney(discountAmount);

  // Per-user redemption re-check — same point in the sequence
  // createOrder.ts always ran it: after the coupon's own validity check,
  // before the delivery/tax sanity ceilings.
  if (couponCode && params.couponAlreadyRedeemed) {
    throw new HttpsError("failed-precondition", "You have already redeemed this coupon");
  }

  // Phase FIX-8, WS1: a single-seller cart whose seller has a configured
  // delivery fee schedule gets a REAL server-computed charge instead of
  // the client-supplied stopgap below. Guarded on itemsBySeller.size === 1
  // (not just "one real sellerId") so a cart mixing a real seller with an
  // "_unassigned" bucket — a product missing sellerId entirely, an
  // anomalous data state — never has its schedule-computed charge silently
  // split with that bucket by the per-seller ratio logic further down;
  // it falls through to the legacy path instead, same as any multi-seller
  // cart. When this IS a true single-seller cart, the per-seller split
  // loop's own "last seller absorbs the residual" rule already gives 100%
  // of `deliveryCharge` to that one seller by construction — no further
  // change needed there.
  const singleSellerId = itemsBySeller.size === 1 ? Array.from(itemsBySeller.keys())[0] : null;
  let scheduleComputedDeliveryCharge: number | null = null;
  if (singleSellerId && singleSellerId !== "_unassigned") {
    const schedule = params.sellerFeeSchedules?.get(singleSellerId);
    if (schedule) {
      let sellerSubtotal = 0;
      for (const item of itemsBySeller.get(singleSellerId)!) {
        sellerSubtotal += (item.price as number) * (item.quantity as number);
      }
      scheduleComputedDeliveryCharge = computeFeeFromSchedule(schedule, sellerSubtotal);
    }
  }

  // deliveryCharge/tax have no server-side source of truth to recompute
  // from — apply a sanity ceiling instead of trusting the client number
  // outright. This is a stopgap, not a fix; it only catches a
  // wildly-inflated value, not a modestly inflated one. Superseded above
  // for a single seller with a configured schedule — the ceiling check
  // below still applies to that value too, as defence in depth (it can
  // never actually trigger for one, since parseDeliveryFeeSchedule already
  // enforces the identical bound at write-parse time).
  const deliveryCharge =
    scheduleComputedDeliveryCharge !== null
      ? scheduleComputedDeliveryCharge
      : typeof params.deliveryCharge === "number" && params.deliveryCharge > 0
      ? params.deliveryCharge
      : 0;
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
  assertSafeOrderMoney(grandTotal);

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

    for (const amount of [sellerSubtotal, sellerDiscount, sellerDeliveryCharge, sellerTax, sellerTotal]) {
      assertSafeOrderMoney(amount, true);
    }

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
