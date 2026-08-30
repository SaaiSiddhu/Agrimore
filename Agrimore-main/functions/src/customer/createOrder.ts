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
//
// Phase C, Workstream 4: the pricing logic (product lookup, B2B/B2C price
// selection, MOQ, stock, coupon, delivery/tax sanity ceilings, per-seller
// ratio split, grand total) was extracted VERBATIM into orderPricing.ts's
// computeOrderPricing — see that file's header for why. This function's
// own transaction structure, its reads, and its writes are unchanged;
// it now calls that shared function instead of computing prices inline.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as crypto from "crypto";
import { computeOrderPricing } from "./orderPricing";

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

  // Phase 16D-2, Workstream 1: employeeCode is now read for BOTH modes —
  // previously it was discarded outright for B2C (`orderMode === "B2B" ?
  // ... : ""`), which is the reason no B2C order could ever be attributed
  // to a Sales Associate (see employeeCommission.ts's header comment for
  // the full history). Deliberately NOT uppercased/case-normalised beyond
  // the existing `.trim()` — B2B's behaviour must not change in any
  // observable way (D5/1c), and B2B has never case-normalised this value
  // (a case-mismatched B2B code has always simply failed to match the
  // stored, always-uppercase code from EmployeeModel.generateEmployeeCode()
  // — that pre-existing behaviour is preserved exactly). For B2C, the same
  // case-sensitivity applies: a case-mismatched code silently resolves to
  // "no attribution" rather than an error, which is exactly D5's required
  // behaviour anyway.
  const employeeCode = String(data?.employeeCode || "").trim();
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

    // Phase 16D-2, Workstream 1b: the ONE employee-code lookup query in
    // this codebase — unchanged in shape from its original B2B-only form
    // (same two equality filters, same `.limit(1)`), just no longer gated
    // on `orderMode === "B2B"`. Gated on `employeeCode` being non-empty
    // instead: a B2B order always has one (enforced above, before the
    // transaction even starts) so this is unconditional for B2B exactly as
    // before; a B2C order with no code supplied skips this read entirely
    // (Workstream 1f — no added read cost for the common unattributed
    // case).
    let employeeQuerySnap: FirebaseFirestore.QuerySnapshot | null = null;
    if (employeeCode) {
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

    // Phase 16D-2, Workstream 1c/2: THE CRITICAL ASYMMETRY. B2B is a
    // wholesale transaction identified BY its employee code — an
    // invalid/unapproved code still hard-fails the whole order, byte-for-
    // byte the same as before this phase (D5/1c: B2B's observable
    // behaviour must not change). B2C is an ordinary retail sale that just
    // HAPPENS to carry an optional attribution — per D5, a customer
    // mistyping (or never entering) an associate's code must still be able
    // to buy groceries, so every B2C failure-to-attribute case (unknown
    // code, pending/suspended associate, refunded/incomplete onboarding,
    // self-attribution) silently results in `employeeUid: null` and the
    // order is created normally. Never an error for B2C.
    let employeeUid: string | null = null;
    if (orderMode === "B2B") {
      if (!employeeQuerySnap || employeeQuerySnap.empty) {
        throw new HttpsError("failed-precondition", "Invalid or unapproved employee code");
      }
      const candidateUid = employeeQuerySnap.docs[0].id;
      // Workstream 2 (S3): self-attribution must be impossible. B2B is
      // all-or-nothing by design (it either gets a valid, non-self,
      // approved attribution, or the order fails outright, exactly like
      // an invalid code) — so self-attribution throws here rather than
      // silently dropping, consistent with every other B2B failure mode.
      if (candidateUid === uid) {
        throw new HttpsError(
          "failed-precondition",
          "You cannot attribute an order to your own associate code"
        );
      }
      employeeUid = candidateUid;
    } else if (employeeCode && employeeQuerySnap && !employeeQuerySnap.empty) {
      const candidate = employeeQuerySnap.docs[0];
      const candidateUid = candidate.id;
      const candidateData = candidate.data();
      // Mirrors EmployeeModel.hasClearedOnboardingGate exactly (paid OR
      // waived, AND not refunded) — an associate who hasn't cleared the
      // ₹500 onboarding gate, or whose fee was refunded, does not earn
      // retail-attribution credit. This is a B2C-only check: B2B has never
      // required onboarding completion (it predates the Phase 16A fee
      // entirely), so it is deliberately NOT applied to the B2B branch
      // above.
      const candidateGateCleared =
        (candidateData.onboardingPaid === true || candidateData.onboardingWaived === true) &&
        !candidateData.onboardingRefundedAt;
      if (candidateUid === uid) {
        console.warn(
          `⚠️ B2C order: associate ${candidateUid} attempted to attribute their own order to themselves — dropping attribution`
        );
      } else if (!candidateGateCleared) {
        console.warn(
          `⚠️ B2C order: associate code "${employeeCode}" resolved to ${candidateUid}, who has not cleared onboarding (or was refunded) — dropping attribution`
        );
      } else {
        employeeUid = candidateUid;
      }
    } else if (employeeCode) {
      console.warn(
        `⚠️ B2C order: associate code "${employeeCode}" did not match any approved associate — creating order with no attribution`
      );
    }

    // All pricing (product lookup, B2B/B2C price selection, MOQ, stock,
    // coupon, delivery/tax sanity ceilings, per-seller ratio split, grand
    // total) is computed by the shared, behaviour-preserving extraction in
    // orderPricing.ts — see that file for the full logic. This is the exact
    // same computation, in the exact same order, as before the extraction.
    const pricing = computeOrderPricing({
      items,
      productSnaps,
      orderMode,
      uid,
      couponSnap,
      couponCode: data?.couponCode,
      // Phase 15, Workstream 2: per-user redemption re-check, at the same
      // point in the sequence it always ran — after the coupon's own
      // validity/usageLimit check, before the delivery/tax sanity
      // ceilings. Passed as a plain boolean (not the snapshot itself) so
      // computeOrderPricing stays read-free.
      couponAlreadyRedeemed: !!(redemptionSnap && redemptionSnap.exists),
      deliveryCharge: data?.deliveryCharge,
      tax: data?.tax,
    });

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
      // Phase 16D-1, Workstream 1 (CTO-confirmed finding 16A-X): symmetric
      // counterpart to functions/src/employee/activationCore.ts's own
      // `payment.consumedByOrderId` check, which already blocks an
      // order-consumed payment from also activating onboarding. This
      // blocks the reverse direction: a payment already spent on an
      // associate's ₹500 onboarding activation must never also create a
      // real order.
      if (payment.consumedByOnboardingFor) {
        throw new HttpsError("failed-precondition", "This payment has already been used for onboarding");
      }
      if (payment.orderId !== razorpayOrderId) {
        throw new HttpsError("failed-precondition", "Payment does not match this order");
      }
      if (payment.status !== "captured") {
        throw new HttpsError("failed-precondition", "Payment was not captured");
      }
      const verifiedAmount = typeof payment.amount === "number" ? payment.amount : -1;
      if (Math.abs(verifiedAmount - pricing.grandTotal) > 1) {
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
    // are distributed by each seller's share of the cart subtotal
    // (computed by orderPricing.ts), mirroring _createSellerScopedOrders's
    // ratio-based split exactly. Nothing above this point has written
    // anything.
    // ============================================
    const createdOrders: { orderId: string; orderNumber: string; sellerId: string; total: number }[] = [];
    const baseOrderNumber = generateOrderNumber();
    const deliverySlot = typeof data?.deliverySlot === "string" ? data.deliverySlot : null;
    const notes = typeof data?.notes === "string" && data.notes.trim() ? data.notes.trim() : null;
    const orderType = typeof data?.orderType === "string" && data.orderType ? data.orderType : "One Time";
    const autoFrequency =
      orderType === "Auto Delivery" && typeof data?.autoFrequency === "string" ? data.autoFrequency : null;

    let index = 0;
    for (const sellerResult of pricing.perSeller) {
      index++;
      const orderRef = db.collection("orders").doc();
      const orderNumber = pricing.perSeller.length === 1 ? baseOrderNumber : `${baseOrderNumber}-${index}`;

      tx.set(orderRef, {
        id: orderRef.id,
        userId: uid,
        sellerId: sellerResult.sellerId,
        orderNumber,
        items: sellerResult.items,
        subtotal: sellerResult.subtotal,
        discount: sellerResult.discount,
        deliveryCharge: sellerResult.deliveryCharge,
        tax: sellerResult.tax,
        total: sellerResult.total,
        paymentMethod,
        paymentStatus: paymentMethod === "cod" ? "pending" : "paid",
        orderStatus: "pending",
        status: "pending",
        razorpayOrderId: data?.razorpayOrderId || null,
        razorpayPaymentId: data?.razorpayPaymentId || null,
        razorpaySignature: data?.razorpaySignature || null,
        couponCode: pricing.couponCode,
        notes,
        deliveryAddress: data?.deliveryAddress || null,
        deliverySlot,
        orderType,
        autoFrequency,
        deliveryVerificationCode: generateVerificationCode(),
        orderMode,
        // Phase 16D-2, Workstream 1d: both fields now tie to the SAME
        // resolution outcome for either mode — `employeeUid` is only ever
        // set when an attribution was actually resolved (see above), so
        // gating `employeeCode` on it (rather than on `orderMode`) stores
        // the RESOLVED, normalised code and never an orphaned code with no
        // matching uid. For B2B this is unchanged: employeeUid is always
        // truthy here (the function already threw otherwise).
        employeeCode: employeeUid ? employeeCode : null,
        employeeUid: employeeUid,
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

      createdOrders.push({
        orderId: orderRef.id,
        orderNumber,
        sellerId: sellerResult.sellerId ?? "",
        total: sellerResult.total,
      });
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
    if (pricing.couponCode && couponSnap && !couponSnap.empty && redemptionRef) {
      tx.update(couponSnap.docs[0].ref, {
        usedCount: admin.firestore.FieldValue.increment(1),
      });
      tx.set(redemptionRef, {
        couponCode: pricing.couponCode,
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
