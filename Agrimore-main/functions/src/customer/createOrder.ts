// ============================================================
//  Callable: createOrder — Server-validated order creation
// ============================================================
//
// Trust boundary fix: apps/marketplace's checkout previously wrote orders
// (and their totals) directly from the client via
// _createSellerScopedOrders in payment_method_screen.dart. This callable is
// the server-validated replacement, now fully wired into checkout as of
// Phase 5: it re-derives every price from the products collection, enforces
// B2B enablement/MOQ, resolves employee attribution codes server-side,
// re-validates coupon discounts server-side (porting CouponModel's exact
// logic from packages/agrimore_core — NOT OrderService.validateCoupon, which
// reads different, stale field names and is dead/unused code), requires a
// matching verified_payments/{paymentId} document for any non-COD order, and
// generates the delivery verification code server-side.
//
// Locked decision: an order is fully B2C or fully B2B, never mixed — the
// whole cart is validated against a single `orderMode`.
//
// Multi-seller carts: mirrors _createSellerScopedOrders's own ratio-based
// discount/delivery/tax distribution exactly (by seller subtotal share of
// the cart total) and its order-number suffixing convention
// ($baseOrderNumber-$index for carts spanning more than one seller).

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as crypto from "crypto";

interface CreateOrderItemInput {
  productId: string;
  quantity: number;
}

interface CreateOrderData {
  items: CreateOrderItemInput[];
  orderMode: "B2C" | "B2B";
  employeeCode?: string;
  deliveryAddress?: Record<string, unknown>;
  paymentMethod?: string;
  razorpayOrderId?: string;
  razorpayPaymentId?: string;
  razorpaySignature?: string;
  couponCode?: string;
  deliveryCharge?: number;
  tax?: number;
  deliverySlot?: string;
  notes?: string;
  orderType?: string;
  autoFrequency?: string;
}

function generateOrderNumber(): string {
  const random = Math.floor(1000 + Math.random() * 9000);
  return `ORD${Date.now()}${random}`;
}

// Mirrors OrderModel.generateVerificationCode()'s range exactly
// (packages/agrimore_core/lib/models/order_model.dart:
// Random.secure().nextInt(900000) + 100000) using Node's CSPRNG.
function generateVerificationCode(): string {
  return crypto.randomInt(100000, 1000000).toString();
}

function roundMoney(value: number): number {
  return Math.round(value * 100) / 100;
}

interface ValidatedItem {
  productId: string;
  price: number;
  quantity: number;
  data: Record<string, unknown>;
}

interface CouponResult {
  discountAmount: number;
  couponCode: string | null;
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
 */
async function validateAndComputeCouponDiscount(
  db: admin.firestore.Firestore,
  couponCode: string | undefined,
  orderAmount: number,
  validatedItems: ValidatedItem[]
): Promise<CouponResult> {
  if (!couponCode || !couponCode.trim()) {
    return { discountAmount: 0, couponCode: null };
  }

  const normalizedCode = couponCode.trim().toUpperCase();
  const snap = await db
    .collection("coupons")
    .where("code", "==", normalizedCode)
    .limit(1)
    .get();

  if (snap.empty) {
    throw new HttpsError("failed-precondition", "Invalid coupon code");
  }

  const coupon = snap.docs[0].data();
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

export const createOrder = onCall({ minInstances: 0, memory: "256MiB" }, async (request) => {
  const data = request.data as CreateOrderData;

  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required");
  }

  const uid = request.auth.uid;
  const items = Array.isArray(data?.items) ? data.items : [];
  const orderMode = data?.orderMode;
  const paymentMethod = data?.paymentMethod || "cod";

  if (items.length === 0) {
    throw new HttpsError("invalid-argument", "items cannot be empty");
  }
  if (orderMode !== "B2C" && orderMode !== "B2B") {
    throw new HttpsError("invalid-argument", "orderMode must be 'B2C' or 'B2B'");
  }

  const employeeCode = orderMode === "B2B" ? String(data?.employeeCode || "").trim() : "";
  if (orderMode === "B2B" && !employeeCode) {
    throw new HttpsError("invalid-argument", "employeeCode is required for B2B orders");
  }

  for (const item of items) {
    if (!item || typeof item.productId !== "string" || !item.productId.trim()) {
      throw new HttpsError("invalid-argument", "Each item requires a productId");
    }
    if (!Number.isInteger(item.quantity) || item.quantity <= 0) {
      throw new HttpsError("invalid-argument", `Invalid quantity for product ${item.productId}`);
    }
  }

  const db = admin.firestore();

  // Resolve employee attribution BEFORE touching products — fail fast on a
  // bad code rather than doing wasted product reads.
  let employeeUid: string | null = null;
  if (orderMode === "B2B") {
    const employeeQuery = await db
      .collection("employees")
      .where("employeeCode", "==", employeeCode)
      .where("status", "==", "approved")
      .limit(1)
      .get();

    if (employeeQuery.empty) {
      throw new HttpsError(
        "failed-precondition",
        "Invalid or unapproved employee code"
      );
    }
    employeeUid = employeeQuery.docs[0].id;
  }

  // Re-derive every price server-side. Never trust client-supplied amounts.
  // Grouped by sellerId as we go — see the multi-seller note above. Also
  // kept as a flat list (validatedItems) for coupon BOGO matching.
  const itemsBySeller = new Map<string, Record<string, unknown>[]>();
  const validatedItems: ValidatedItem[] = [];
  let cartSubtotal = 0;

  // Batched read instead of one sequential await per cart item — db.getAll
  // returns snapshots in the same order as the refs passed in, so
  // productSnaps[i] always corresponds to items[i]. Same document-read count
  // and billing as before (Firestore bills per document regardless of
  // batching); this only removes N sequential round-trips.
  const productRefs = items.map((item) => db.collection("products").doc(item.productId));
  const productSnaps = await db.getAll(...productRefs);

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
  const { discountAmount, couponCode } = await validateAndComputeCouponDiscount(
    db,
    data?.couponCode,
    cartSubtotal,
    validatedItems
  );

  // deliveryCharge/tax have no server-side source of truth to recompute
  // from (investigated: settings/delivery only stores time-window labels,
  // not fees — see DeliverySlotService — and the live checkout route
  // doesn't even forward non-zero values for either field today). Until a
  // real fee schedule exists to validate against, apply a sanity ceiling
  // instead of trusting the client number outright — this is a stopgap,
  // not a fix; it only catches a wildly-inflated value, not a modestly
  // inflated one.
  const MAX_REASONABLE_DELIVERY_CHARGE = 1000;
  const MAX_REASONABLE_TAX = 1000;
  const deliveryCharge = typeof data?.deliveryCharge === "number" && data.deliveryCharge > 0 ? data.deliveryCharge : 0;
  const tax = typeof data?.tax === "number" && data.tax > 0 ? data.tax : 0;
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
  const grandTotal = roundMoney(
    Math.max(0, cartSubtotal - discountAmount) + deliveryCharge + tax
  );

  // Payment trust boundary: for any non-COD order, a real verified_payments
  // document (written only by verifyRazorpayPayment after HMAC + live API
  // verification — see functions/src/customer/payment.ts) must exist and
  // match this request. A client-supplied razorpayPaymentId string alone
  // proves nothing.
  if (paymentMethod !== "cod") {
    const razorpayPaymentId = data?.razorpayPaymentId;
    const razorpayOrderId = data?.razorpayOrderId;
    if (!razorpayPaymentId || !razorpayOrderId) {
      throw new HttpsError(
        "invalid-argument",
        "Razorpay payment details are required for non-COD orders"
      );
    }

    const paymentSnap = await db.collection("verified_payments").doc(razorpayPaymentId).get();
    if (!paymentSnap.exists) {
      throw new HttpsError("failed-precondition", "Payment could not be verified");
    }
    const payment = paymentSnap.data()!;
    if (payment.orderId !== razorpayOrderId) {
      throw new HttpsError("failed-precondition", "Payment does not match this order");
    }
    if (payment.status !== "captured") {
      throw new HttpsError("failed-precondition", "Payment was not captured");
    }
    const verifiedAmount = typeof payment.amount === "number" ? payment.amount : -1;
    if (Math.abs(verifiedAmount - grandTotal) > 1) {
      throw new HttpsError(
        "failed-precondition",
        "Verified payment amount does not match the order total"
      );
    }
  }

  // One order document per seller — matches splitCartIntoOrders.ts's
  // established convention and _createSellerScopedOrders's own grouping, and
  // keeps every order visible to its seller under firestore.rules
  // (`resource.data.sellerId == request.auth.uid`). Discount/delivery/tax
  // are distributed by each seller's share of the cart subtotal, mirroring
  // _createSellerScopedOrders's ratio-based split exactly.
  const batch = db.batch();
  const createdOrders: { orderId: string; orderNumber: string; sellerId: string; total: number }[] = [];
  const baseOrderNumber = generateOrderNumber();
  const sellerCount = itemsBySeller.size;
  const deliverySlot = typeof data?.deliverySlot === "string" ? data.deliverySlot : null;
  const notes = typeof data?.notes === "string" && data.notes.trim() ? data.notes.trim() : null;
  const orderType = typeof data?.orderType === "string" && data.orderType ? data.orderType : "One Time";
  const autoFrequency =
    orderType === "Auto Delivery" && typeof data?.autoFrequency === "string" ? data.autoFrequency : null;

  let index = 0;
  for (const [sellerId, sellerItems] of itemsBySeller.entries()) {
    index++;
    let sellerSubtotal = 0;
    for (const item of sellerItems) {
      sellerSubtotal += (item.price as number) * (item.quantity as number);
    }
    const ratio = cartSubtotal > 0 ? sellerSubtotal / cartSubtotal : 1 / sellerCount;
    const sellerDiscount = roundMoney(discountAmount * ratio);
    const sellerDeliveryCharge = roundMoney(deliveryCharge * ratio);
    const sellerTax = roundMoney(tax * ratio);
    const sellerTotal = roundMoney(
      Math.max(0, sellerSubtotal - sellerDiscount) + sellerDeliveryCharge + sellerTax
    );
    const resolvedSellerId = sellerId === "_unassigned" ? null : sellerId;

    const orderRef = db.collection("orders").doc();
    const orderNumber = sellerCount === 1 ? baseOrderNumber : `${baseOrderNumber}-${index}`;

    batch.set(orderRef, {
      id: orderRef.id,
      userId: uid,
      sellerId: resolvedSellerId,
      orderNumber,
      items: sellerItems,
      subtotal: roundMoney(sellerSubtotal),
      discount: sellerDiscount,
      deliveryCharge: sellerDeliveryCharge,
      tax: sellerTax,
      total: sellerTotal,
      paymentMethod,
      paymentStatus: paymentMethod === "cod" ? "pending" : "paid",
      orderStatus: "pending",
      status: "pending",
      razorpayOrderId: data?.razorpayOrderId || null,
      razorpayPaymentId: data?.razorpayPaymentId || null,
      razorpaySignature: data?.razorpaySignature || null,
      couponCode,
      notes,
      deliveryAddress: data?.deliveryAddress || null,
      deliverySlot,
      orderType,
      autoFrequency,
      deliveryVerificationCode: generateVerificationCode(),
      orderMode,
      employeeCode: orderMode === "B2B" ? employeeCode : null,
      employeeUid: orderMode === "B2B" ? employeeUid : null,
      commissionPaid: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const timelineRef = orderRef.collection("timeline").doc();
    batch.set(timelineRef, {
      id: timelineRef.id,
      status: "pending",
      title: "Order Placed",
      description: "Your order has been placed successfully",
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    createdOrders.push({ orderId: orderRef.id, orderNumber, sellerId: resolvedSellerId ?? "", total: sellerTotal });
  }

  await batch.commit();

  return { success: true, orders: createdOrders };
});
