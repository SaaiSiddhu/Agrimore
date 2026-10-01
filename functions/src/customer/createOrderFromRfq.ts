// ============================================================
//  Callable: createOrderFromRfq — convert an accepted RFQ into a real order
// ============================================================
//
// Phase RFQ-3. Lets a buyer convert an accepted rfqs/{rfqId} (status:
// 'accepted', finalPrice/finalQuantity locked by rfq.ts's
// respondToRfqOffer) into a real order at that exact negotiated price.
//
// Deliberately a SEPARATE callable from createOrder.ts, not a new branch
// inside it. computeOrderPricing (orderPricing.ts) — shared by createOrder.ts
// and productCreditHold.ts's quoteOrderWithCredit specifically so the two can
// never disagree on a number — has no per-item price-override hook; every
// price is product.b2bPrice or product.salePrice, selected by orderMode
// alone. Bolting a third, RFQ-derived price into that shared function would
// touch createOrder.ts, this codebase's single most security-sensitive,
// most collision-prone file, for a flow that is inherently single-product,
// single-seller and needs none of computeOrderPricing's B2B/B2C selection,
// coupon logic or per-seller ratio split. createOrder.ts and orderPricing.ts
// are NOT touched by this phase.
//
// The payment-verification block below intentionally DUPLICATES (does not
// extract-and-share) createOrder.ts's own block: unlike pricing, a
// self-contained "does this payment cover this payable amount" check has no
// two-systems-must-agree hazard, and extracting it would require touching
// createOrder.ts to call the extraction — reintroducing exactly the
// regression surface this design avoids. Keep the two in sync by hand if
// either changes.
//
// Product Credit holds are NOT supported here — stacking a hold discount on
// an already-negotiated bespoke price is a product question this phase was
// never asked to answer. Once consumed, an RFQ stays consumed even if the
// resulting order is later cancelled, mirroring verified_payments' own
// behaviour (a consumed payment is never "un-consumed" by a cancellation
// either — refund/reversal is a separate, manual, out-of-band concern this
// codebase does not automate for payments, so RFQ consumption is held to the
// identical standard).

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { assertSellerAcceptingOrders } from "../common/sellerAvailability";
import { isSpendableCapturedPayment } from "../common/paymentIntegrity";
import * as crypto from "crypto";
import { deliverySecretRef, newDeliverySecret } from "../delivery/deliverySecret";

interface CreateOrderFromRfqData {
  rfqId: string;
  productId: string;
  quantity: number;
  deliveryAddress?: Record<string, unknown>;
  paymentMethod?: string;
  razorpayOrderId?: string;
  razorpayPaymentId?: string;
  deliverySlot?: string;
  notes?: string;
  deliveryCharge?: number;
  tax?: number;
}

// Mirrors createOrder.ts's own generateOrderNumber/generateVerificationCode/
// roundMoney/MONEY_EPSILON exactly — see that file's own comments for why
// crypto.randomInt and 0.02 rupees specifically.
function generateOrderNumber(): string {
  const random = crypto.randomInt(1000, 10000);
  return `ORD${Date.now()}${random}`;
}

function generateVerificationCode(): string {
  return crypto.randomInt(100000, 1000000).toString();
}

function roundMoney(value: number): number {
  return Math.round(value * 100) / 100;
}

const MONEY_EPSILON = 0.02;

// Same fixed-window counter as createOrder.ts, and the SAME
// order_rate_limits/{uid} document — an RFQ-derived order still counts
// against the same per-uid ceiling as a normal order (see createOrder.ts's
// own comment for why 8/60s is a safety margin, not a business ceiling).
const ORDER_RATE_LIMIT_WINDOW_MS = 60 * 1000;
const MAX_ORDERS_PER_WINDOW = 8;

const MAX_NOTES_LENGTH = 500;
const MAX_SHORT_STRING_FIELD_LENGTH = 100;
const MAX_DELIVERY_ADDRESS_BYTES = 4096;

function validateOrderInputBounds(data: CreateOrderFromRfqData): void {
  if (data?.deliveryAddress !== undefined && data?.deliveryAddress !== null) {
    const addr = data.deliveryAddress;
    if (typeof addr !== "object" || Array.isArray(addr)) {
      throw new HttpsError("invalid-argument", "deliveryAddress must be an object");
    }
    const byteLength = Buffer.byteLength(JSON.stringify(addr), "utf8");
    if (byteLength > MAX_DELIVERY_ADDRESS_BYTES) {
      throw new HttpsError("invalid-argument", "deliveryAddress is too large");
    }
  }
  if (typeof data?.notes === "string" && data.notes.length > MAX_NOTES_LENGTH) {
    throw new HttpsError("invalid-argument", "notes is too long");
  }
  if (typeof data?.deliverySlot === "string" && data.deliverySlot.length > MAX_SHORT_STRING_FIELD_LENGTH) {
    throw new HttpsError("invalid-argument", "deliverySlot is too long");
  }
}

export const createOrderFromRfq = onCall(
  { minInstances: 0, memory: "256MiB" },
  async (request) => {
    const data = request.data as CreateOrderFromRfqData;

    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required");
    }
    const uid = request.auth.uid;

    const rfqId = typeof data?.rfqId === "string" ? data.rfqId.trim() : "";
    if (!rfqId) {
      throw new HttpsError("invalid-argument", "rfqId is required");
    }
    if (typeof data?.productId !== "string" || !data.productId.trim()) {
      throw new HttpsError("invalid-argument", "productId is required");
    }
    if (!Number.isInteger(data?.quantity) || data.quantity <= 0) {
      throw new HttpsError("invalid-argument", "Invalid quantity");
    }
    validateOrderInputBounds(data);

    const paymentMethod = data?.paymentMethod || "cod";
    const razorpayPaymentId = data?.razorpayPaymentId;
    const razorpayOrderId = data?.razorpayOrderId;
    if (paymentMethod !== "cod" && (!razorpayPaymentId || !razorpayOrderId)) {
      throw new HttpsError(
        "invalid-argument",
        "Razorpay payment details are required for non-COD orders"
      );
    }

    const db = admin.firestore();
    const rfqRef = db.collection("rfqs").doc(rfqId);
    const userRef = db.collection("users").doc(uid);
    const rateLimitRef = db.collection("order_rate_limits").doc(uid);
    const paymentRef =
      paymentMethod !== "cod" && razorpayPaymentId
        ? db.collection("verified_payments").doc(razorpayPaymentId as string)
        : null;

    const result = await db.runTransaction(async (tx) => {
      // ============================================
      // ALL READS FIRST
      // ============================================
      const rfqSnap = await tx.get(rfqRef);
      const userSnap = await tx.get(userRef);
      const rateLimitSnap = await tx.get(rateLimitRef);

      const rateLimitData = rateLimitSnap.data();
      const windowStart = rateLimitData?.windowStart as admin.firestore.Timestamp | undefined;
      const withinWindow =
        !!windowStart && Date.now() - windowStart.toMillis() < ORDER_RATE_LIMIT_WINDOW_MS;
      const ordersInWindow = withinWindow ? (rateLimitData?.count as number) || 0 : 0;
      if (withinWindow && ordersInWindow >= MAX_ORDERS_PER_WINDOW) {
        throw new HttpsError(
          "resource-exhausted",
          "You're placing orders too quickly. Please wait a moment and try again."
        );
      }
      const rateLimitWindowStartToWrite = withinWindow
        ? windowStart!
        : admin.firestore.FieldValue.serverTimestamp();
      const rateLimitCountToWrite = ordersInWindow + 1;

      if (!rfqSnap.exists) {
        throw new HttpsError("not-found", "Quote request not found");
      }
      const rfq = rfqSnap.data()!;

      // Role/ownership: derived from the RFQ's OWN stored buyerId, never a
      // client-asserted role — mirrors rfq.ts's own roleOf() discipline.
      if (rfq.buyerId !== uid) {
        throw new HttpsError(
          "permission-denied",
          "This quote request does not belong to you"
        );
      }
      if (rfq.status !== "accepted") {
        throw new HttpsError(
          "failed-precondition",
          `This quote request is not accepted (status: ${rfq.status})`
        );
      }
      // Double-spend guard, checked before any write, exactly like
      // createOrder.ts's own payment.consumedByOrderId check.
      if (rfq.consumedByOrderId) {
        throw new HttpsError(
          "failed-precondition",
          "This quote request has already been converted into an order"
        );
      }
      // The submitted item must match the RFQ's own locked product/quantity
      // exactly — never trust the client's own productId/quantity beyond
      // this cross-check.
      if (rfq.productId !== data.productId) {
        throw new HttpsError(
          "failed-precondition",
          "This order does not match the accepted quote request"
        );
      }
      if (typeof rfq.finalQuantity !== "number" || rfq.finalQuantity !== data.quantity) {
        throw new HttpsError(
          "failed-precondition",
          "The order quantity does not match the accepted quote"
        );
      }
      // Mirrors rfq.ts's own validatePrice() check exactly (Number.isFinite,
      // not just typeof — a NaN/Infinity value is technically typeof
      // "number" in JS and would otherwise slip past a bare `<= 0` guard,
      // since every comparison against NaN is false). rfq.ts's own
      // validatePrice() already guarantees this in practice; this is
      // defense-in-depth, not a currently reachable gap.
      if (typeof rfq.finalPrice !== "number" || !Number.isFinite(rfq.finalPrice) || rfq.finalPrice <= 0) {
        throw new HttpsError(
          "failed-precondition",
          "This quote request has no locked price"
        );
      }
      const sellerId = typeof rfq.sellerId === "string" && rfq.sellerId ? rfq.sellerId : null;
      if (!sellerId) {
        throw new HttpsError("failed-precondition", "This quote request has no seller");
      }

      const productRef = db.collection("products").doc(rfq.productId as string);
      const productSnap = await tx.get(productRef);
      // SELLER-OPS-1: an accepted quote cannot become an order while the
      // seller has paused their store.
      const rfqSellerSnap = await tx.get(db.collection("sellers").doc(sellerId));
      assertSellerAcceptingOrders(rfqSellerSnap.data(), Date.now());

      // Profile-completeness — same server-side gate createOrder.ts enforces.
      if (!userSnap.exists || userSnap.data()?.profileCompleted !== true) {
        throw new HttpsError(
          "failed-precondition",
          "Please complete your profile before placing an order"
        );
      }

      if (!productSnap.exists) {
        throw new HttpsError("not-found", `Product ${rfq.productId} not found`);
      }
      const product = productSnap.data()!;

      // ============================================
      // PRICING — the RFQ's own locked finalPrice/finalQuantity, never
      // re-derived from the product's own catalogue price. deliveryCharge/
      // tax follow the SAME client-supplied-with-sanity-ceiling handling
      // orderPricing.ts already uses elsewhere — an unrelated "trust but
      // cap" concern, not part of the negotiated price's own integrity.
      // ============================================
      const MAX_REASONABLE_DELIVERY_CHARGE = 1000;
      const MAX_REASONABLE_TAX = 1000;
      const deliveryCharge =
        typeof data?.deliveryCharge === "number" && data.deliveryCharge > 0 ? data.deliveryCharge : 0;
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

      const finalPrice = rfq.finalPrice as number;
      const finalQuantity = rfq.finalQuantity as number;
      const subtotal = roundMoney(finalPrice * finalQuantity);
      const grandTotal = roundMoney(subtotal + deliveryCharge + tax);

      // Stock check — mirrors orderPricing.ts's own fail-open-on-missing
      // behaviour exactly (a missing/non-numeric stock is assumed
      // available, matching ProductModel.fromMap's default of 999); when
      // stock IS a real number it is enforced against the RFQ's own locked
      // quantity.
      const stockRaw = product.stock;
      const stockIsEnforceable = typeof stockRaw === "number" && Number.isFinite(stockRaw);
      if (stockIsEnforceable && (stockRaw as number) < finalQuantity) {
        throw new HttpsError(
          "failed-precondition",
          `Product ${rfq.productId} does not have enough stock (available: ${stockRaw}, requested: ${finalQuantity})`
        );
      }

      // ============================================
      // PAYMENT — duplicates createOrder.ts's own verification block. See
      // this file's header comment for why it is duplicated, not shared.
      // ============================================
      const paymentSnap = paymentRef ? await tx.get(paymentRef) : null;
      const payable = grandTotal;
      if (paymentRef) {
        if (!paymentSnap || !paymentSnap.exists) {
          throw new HttpsError("failed-precondition", "Payment could not be verified");
        }
        const payment = paymentSnap.data()!;
        if (!payment.userId || payment.userId !== uid) {
          throw new HttpsError("failed-precondition", "Payment could not be verified for this user");
        }
        if (payment.consumedByOrderId) {
          throw new HttpsError("failed-precondition", "This payment has already been used for an order");
        }
        if (payment.consumedByOnboardingFor) {
          throw new HttpsError("failed-precondition", "This payment has already been used for onboarding");
        }
        if (payment.consumedByWalletTopup) {
          throw new HttpsError("failed-precondition", "This payment has already been used for a wallet top-up");
        }
        // Phase AI-4 (D-SELLER-AI-FUNDING): fourth consumption direction. A
        // payment already spent on a seller's ₹50 AI Assistant activation
        // (functions/src/seller/aiConnection.ts's connectSellerAiProvider)
        // must never also create a real RFQ order.
        if (payment.consumedBySellerAiActivationFor) {
          throw new HttpsError("failed-precondition", "This payment has already been used for a seller AI Assistant activation");
        }
        if (payment.orderId !== razorpayOrderId) {
          throw new HttpsError("failed-precondition", "Payment does not match this order");
        }
        if (!isSpendableCapturedPayment(payment, razorpayPaymentId, "rfq_checkout")) {
          throw new HttpsError("failed-precondition", "Payment was not captured");
        }
        const verifiedAmount = typeof payment.amount === "number" ? payment.amount : -1;
        if (Math.abs(verifiedAmount - payable) > MONEY_EPSILON) {
          throw new HttpsError(
            "failed-precondition",
            "Verified payment amount does not match the order total"
          );
        }
      } else if (paymentMethod !== "cod" && payable > MONEY_EPSILON) {
        throw new HttpsError(
          "invalid-argument",
          "Razorpay payment details are required for non-COD orders"
        );
      }

      // ============================================
      // ALL WRITES
      // ============================================
      const orderRef = db.collection("orders").doc();
      const orderNumber = generateOrderNumber();
      const deliverySlot = typeof data?.deliverySlot === "string" ? data.deliverySlot : null;
      const notes = typeof data?.notes === "string" && data.notes.trim() ? data.notes.trim() : null;

      const orderItem = {
        id: rfq.productId,
        productId: rfq.productId,
        productName: product.name || "",
        productImage:
          Array.isArray(product.images) && product.images.length > 0 ? product.images[0] : "",
        price: finalPrice,
        quantity: finalQuantity,
        userId: uid,
        sellerId,
        addedAt: admin.firestore.Timestamp.now(),
      };

      const deliveryCode = generateVerificationCode();
      tx.set(orderRef, {
        id: orderRef.id,
        userId: uid,
        sellerId,
        orderNumber,
        items: [orderItem],
        subtotal,
        discount: 0,
        deliveryCharge,
        tax,
        total: grandTotal,
        paymentMethod,
        paymentStatus: paymentMethod === "cod" ? "pending" : "paid",
        orderStatus: "pending",
        status: "pending",
        razorpayOrderId: data?.razorpayOrderId || null,
        razorpayPaymentId: data?.razorpayPaymentId || null,
        couponCode: null,
        notes,
        deliveryAddress: data?.deliveryAddress || null,
        deliverySlot,
        orderType: "One Time",
        autoFrequency: null,
        // DLV-0 stage A: the same code is also written to
        // orders/{id}/secrets/delivery just below. This copy stays ONLY
        // because the released marketplace build reads it from here; it is
        // partner-readable, and DLV-0B removes it once a marketplace build
        // reading the secret doc is adopted.
        deliveryVerificationCode: deliveryCode,
        orderMode: "B2B",
        // An RFQ is a direct buyer-seller negotiation — no Sales Associate
        // attribution point exists anywhere in rfq.ts/RFQ-2's client flow,
        // so this is deliberately always null, unlike a normal B2B order
        // (which requires an employeeCode). Disclosed departure from
        // createOrder.ts's own B2B rule, not an oversight.
        employeeCode: null,
        employeeUid: null,
        commissionPaid: false,
        productCreditApplied: 0,
        productCreditHoldId: null,
        productCreditReversed: false,
        productCreditLedgerEntryId: null,
        // Server-side bookkeeping identifying this order's origin. Not
        // modeled in OrderModel (packages/agrimore_core) — same convention
        // as productCreditLedgerEntryId/commissionAmount, which OrderModel
        // also doesn't model. Protected from client tampering by the same
        // three order-update denylist functions this phase adds it to
        // (firestore.rules).
        rfqId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      // DLV-0: the delivery code where no delivery partner can read it
      // (firestore.rules orders/{orderId}/secrets — owner/admin read, no
      // client write). confirmDelivery reads this first.
      tx.set(deliverySecretRef(db, orderRef.id), newDeliverySecret(deliveryCode));

      const timelineRef = orderRef.collection("timeline").doc();
      tx.set(timelineRef, {
        id: timelineRef.id,
        status: "pending",
        title: "Order Placed",
        description: "Your order has been placed successfully",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Stock decrement — same pattern as createOrder.ts, atomic with the
      // stock check performed earlier in this same transaction.
      if (stockIsEnforceable) {
        tx.update(productRef, {
          stock: admin.firestore.FieldValue.increment(-finalQuantity),
          soldCount: admin.firestore.FieldValue.increment(finalQuantity),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } else {
        tx.update(productRef, {
          soldCount: admin.firestore.FieldValue.increment(finalQuantity),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      if (paymentRef) {
        tx.set(
          paymentRef,
          {
            consumedByOrderId: orderRef.id,
            consumedByOrderNumber: orderNumber,
            consumedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      }

      // Idempotency-anchor write: marks the RFQ consumed inside the SAME
      // transaction that creates the order it produced — the exact
      // discipline verified_payments.consumedByOrderId already proves.
      tx.set(
        rfqRef,
        {
          consumedByOrderId: orderRef.id,
          consumedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      tx.set(
        rateLimitRef,
        { windowStart: rateLimitWindowStartToWrite, count: rateLimitCountToWrite },
        { merge: true }
      );

      return {
        success: true,
        orderId: orderRef.id,
        orderNumber,
        total: grandTotal,
      };
    });

    return result;
  }
);
