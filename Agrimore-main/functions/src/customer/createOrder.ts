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
 *
 * Phase 14, Workstream 4: takes an already-fetched QuerySnapshot instead of
 * querying itself — createOrder now runs inside a single db.runTransaction,
 * and Firestore transactions require every read to happen before any write,
 * so this coupon lookup is performed up front alongside the product/payment
 * reads rather than inline here.
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

  // Phase 14, Workstream 4: the razorpayPaymentId argument shape check
  // happens up front (outside the transaction) since it's pure input
  // validation — the payment DOCUMENT itself, however, is now read and
  // consumed inside the transaction below, alongside every other read this
  // function needs (products, coupon, employee code), so that checking the
  // payment and creating the order(s) that spend it are atomic. Previously,
  // this function only checked the payment document's existence/amount —
  // it never marked it as spent, so the same razorpayPaymentId could
  // satisfy unlimited orders (replay), and it never checked WHO the
  // payment belonged to, so any user's paymentId could satisfy any other
  // user's order of the same amount (cross-user reuse).
  const razorpayPaymentId = data?.razorpayPaymentId;
  const razorpayOrderId = data?.razorpayOrderId;
  if (paymentMethod !== "cod" && (!razorpayPaymentId || !razorpayOrderId)) {
    throw new HttpsError(
      "invalid-argument",
      "Razorpay payment details are required for non-COD orders"
    );
  }
  const paymentRef =
    paymentMethod !== "cod" ? db.collection("verified_payments").doc(razorpayPaymentId as string) : null;

  // Phase 16, Workstream 7: an incomplete-profile user must not be able to
  // transact — read alongside every other read this transaction needs.
  const userRef = db.collection("users").doc(uid);

  const result = await db.runTransaction(async (tx) => {
    // ============================================
    // ALL READS FIRST — Firestore transactions require every read to
    // precede every write; the writes (order/timeline/payment-consumption
    // docs) happen only in the second half of this callback, below.
    // ============================================
    const userSnap = await tx.get(userRef);

    let employeeQuerySnap: FirebaseFirestore.QuerySnapshot | null = null;
    if (orderMode === "B2B") {
      employeeQuerySnap = await tx.get(
        db
          .collection("employees")
          .where("employeeCode", "==", employeeCode)
          .where("status", "==", "approved")
          .limit(1)
      );
    }

    // Batched read instead of one sequential await per cart item —
    // getAll returns snapshots in the same order as the refs passed in, so
    // productSnaps[i] always corresponds to items[i]. Same document-read
    // count and billing as before (Firestore bills per document regardless
    // of batching); this only removes N sequential round-trips.
    const productRefs = items.map((item) => db.collection("products").doc(item.productId));
    const productSnaps = await tx.getAll(...productRefs);

    const normalizedCouponCode =
      data?.couponCode && data.couponCode.trim() ? data.couponCode.trim().toUpperCase() : null;
    const couponSnap = normalizedCouponCode
      ? await tx.get(db.collection("coupons").where("code", "==", normalizedCouponCode).limit(1))
      : null;
    // Phase 15, Workstream 2: per-user redemption tracking. One document per
    // (couponCode, uid) pair — its existence is what blocks a second
    // redemption of the same coupon by the same user, the same
    // idempotency-anchor shape as wallet.ts's wallet_topups/{paymentId}.
    // Read here, before any write, alongside the coupon/product/payment
    // reads this transaction already performs.
    const redemptionRef = normalizedCouponCode
      ? db.collection("coupon_redemptions").doc(`${normalizedCouponCode}_${uid}`)
      : null;
    const redemptionSnap = redemptionRef ? await tx.get(redemptionRef) : null;

    const paymentSnap = paymentRef ? await tx.get(paymentRef) : null;

    // ============================================
    // VALIDATION / COMPUTATION — pure, no further Firestore access until
    // the write phase below.
    // ============================================

    // Phase 16, Workstream 7: block transacting with an incomplete profile
    // server-side, not just via client routing (a modified client or a
    // direct callable invocation must not be able to bypass this). A
    // grandfathered/backfilled existing user has profileCompleted: true and
    // passes unchanged.
    if (!userSnap.exists || userSnap.data()?.profileCompleted !== true) {
      throw new HttpsError(
        "failed-precondition",
        "Please complete your profile before placing an order"
      );
    }

    let employeeUid: string | null = null;
    if (orderMode === "B2B") {
      if (!employeeQuerySnap || employeeQuerySnap.empty) {
        throw new HttpsError("failed-precondition", "Invalid or unapproved employee code");
      }
      employeeUid = employeeQuerySnap.docs[0].id;
    }

    // Re-derive every price server-side. Never trust client-supplied amounts.
    // Grouped by sellerId as we go — see the multi-seller note above. Also
    // kept as a flat list (validatedItems) for coupon BOGO matching.
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

      // Phase 15, Workstream 2: stock validation. Fail-OPEN (with a logged
      // warning) when `stock` is missing or non-numeric, rather than
      // fail-closed — deliberately mirroring
      // packages/agrimore_core/lib/models/product_model.dart's own
      // ProductModel.fromMap, which defaults a missing/non-numeric stock to
      // 999 (`(map['stock'] as num?)?.toInt() ?? 999`). That default,
      // chosen by this codebase's own developers, is strong evidence that
      // many real products predate this field entirely — rejecting every
      // order for such a product would break checkout that has always
      // worked, for a data-completeness gap this phase didn't create. Live
      // production data was not queried directly to confirm the exact
      // proportion (no safe read-only Admin SDK credential path was set up
      // in this environment); the decision instead rests on this explicit,
      // deliberate model-layer default, which is the alternative basis the
      // brief itself allows. When stock IS a real number, it is enforced
      // exactly — this closes the actual overselling gap for every product
      // that already reports its stock accurately.
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
      couponSnap,
      data?.couponCode,
      cartSubtotal,
      validatedItems
    );

    // Phase 15, Workstream 2: per-user redemption re-check, inside the same
    // transaction as the coupon's own usageLimit check above (both read
    // from snapshots taken at the start of this transaction, so a
    // concurrent double-redemption of the last available use correctly
    // causes one caller to retry and then fail). A coupon that validated
    // successfully but was already redeemed by this exact user is rejected
    // here — computeCouponDiscount only knows about the coupon document
    // itself, not per-user history.
    if (couponCode && redemptionSnap && redemptionSnap.exists) {
      throw new HttpsError("failed-precondition", "You have already redeemed this coupon");
    }

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
    // verification — see functions/src/customer/payment.ts) must exist,
    // belong to THIS caller, not already be consumed by an earlier order,
    // and match this request. A client-supplied razorpayPaymentId string
    // alone proves nothing.
    if (paymentRef) {
      if (!paymentSnap || !paymentSnap.exists) {
        throw new HttpsError("failed-precondition", "Payment could not be verified");
      }
      const payment = paymentSnap.data()!;
      // Fail-closed on legacy documents written before this change (no
      // userId field): a missing userId is treated as "not verifiably this
      // caller's payment", not as "unknown, allow it". Customer impact:
      // any checkout already in flight at deploy time — payment verified
      // but createOrder not yet called — would need to retry the payment.
      if (!payment.userId || payment.userId !== uid) {
        throw new HttpsError("failed-precondition", "Payment could not be verified for this user");
      }
      if (payment.consumedByOrderId) {
        throw new HttpsError("failed-precondition", "This payment has already been used for an order");
      }
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

    // ============================================
    // ALL WRITES — one order document per seller, matching
    // _createSellerScopedOrders's own grouping (payment_method_screen.dart)
    // and keeping every order visible to its seller under firestore.rules
    // (`resource.data.sellerId == request.auth.uid`). Discount/delivery/tax
    // are distributed by each seller's share of the cart subtotal,
    // mirroring _createSellerScopedOrders's ratio-based split
    // exactly. Nothing above this point has written anything.
    // ============================================
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

      tx.set(orderRef, {
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
      tx.set(timelineRef, {
        id: timelineRef.id,
        status: "pending",
        title: "Order Placed",
        description: "Your order has been placed successfully",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      createdOrders.push({ orderId: orderRef.id, orderNumber, sellerId: resolvedSellerId ?? "", total: sellerTotal });
    }

    // Idempotency-anchor pattern, mirroring wallet.ts's verifyWalletTopup
    // exactly: mark the payment consumed inside the SAME transaction that
    // creates the order(s) it pays for, so a retried/replayed call either
    // sees the marker already set (checked above, before any write) or
    // races the transaction lock and retries — never both succeed. A
    // multi-seller cart produces multiple order documents sharing one
    // payment; consumedByOrderId anchors to the first (baseOrderNumber
    // covers the human-readable multi-order case).
    if (paymentRef) {
      tx.set(
        paymentRef,
        {
          consumedByOrderId: createdOrders[0].orderId,
          consumedByOrderNumber: baseOrderNumber,
          consumedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }

    // Phase 15, Workstream 2: increment the coupon's usedCount and record
    // this user's redemption, inside the same transaction that creates the
    // order(s) the coupon discounted — same idempotency-anchor shape as the
    // payment-consumption write above. Nothing anywhere else in the
    // codebase increments usedCount (grepped: the only client-side
    // incrementUsageCount() call sites are dead code with zero callers, and
    // would be rejected by firestore.rules' admin-only `coupons` write rule
    // regardless) — this is the first real enforcement of usageLimit.
    if (couponCode && couponSnap && !couponSnap.empty && redemptionRef) {
      tx.update(couponSnap.docs[0].ref, {
        usedCount: admin.firestore.FieldValue.increment(1),
      });
      tx.set(redemptionRef, {
        couponCode,
        uid,
        orderId: createdOrders[0].orderId,
        orderNumber: baseOrderNumber,
        redeemedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    return { success: true, orders: createdOrders };
  });

  return result;
});
