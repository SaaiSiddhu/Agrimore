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
//
// Phase D: settles an existing Product Credit hold (see
// productCreditHold.ts) against this order — the amount redeemed always
// comes from the hold DOCUMENT, read server-side inside this same
// transaction, NEVER from client input (S4). See the productCreditHoldId
// handling below for the full validation sequence, the double-spend guard,
// and the per-seller credit split.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as crypto from "crypto";
import { computeOrderPricing, normalizeOrderItems, MAX_VARIANT_ID_LENGTH } from "./orderPricing";
import { computeCartFingerprint } from "./productCreditHold";
import { appendLedgerEntry, toProjectionFields } from "./productCreditLedger";
import { DeliveryFeeSchedule, parseDeliveryFeeSchedule } from "./deliveryFeeSchedule";
import { deliverySecretRef, newDeliverySecret } from "../delivery/deliverySecret";
import { assertSellerAcceptingOrders } from "../common/sellerAvailability";
import { isSpendableCapturedPayment } from "../common/paymentIntegrity";

interface CreateOrderItemInput {
  productId: string;
  quantity: number;
  variantId?: string;
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
  /** Phase D: an active hold from quoteOrderWithCredit to settle against
   *  this order. The amount redeemed is read from the hold document, never
   *  from this string alone (S4). */
  productCreditHoldId?: string;
}

// FIX-9, WS5. Was `Date.now()` plus a `Math.random()` 4-digit tail — neither
// CSPRNG nor collision-checked, so two orders in the same millisecond had a
// real chance of an identical suffix. crypto.randomInt is the same CSPRNG
// primitive createOrder.ts's own delivery verification code (and
// sendPhoneOTP.ts's) already uses for exactly this reason.
function generateOrderNumber(): string {
  const random = crypto.randomInt(1000, 10000);
  return `ORD${Date.now()}${random}`;
}

function roundMoney(value: number): number {
  return Math.round(value * 100) / 100;
}

// FIX-9, WS3. Shared by the verified-payment tolerance check and the
// payable-requires-a-real-payment branch below — see both call sites' own
// comments for why 0.02 (2 paise), not the previous 1 (a full rupee).
const MONEY_EPSILON = 0.02;

// Mirrors OrderModel.generateVerificationCode()'s range exactly
// (packages/agrimore_core/lib/models/order_model.dart:
// Random.secure().nextInt(900000) + 100000) using Node's CSPRNG.
function generateVerificationCode(): string {
  return crypto.randomInt(100000, 1000000).toString();
}

// FIX-16, WS1 (finding N-23). createOrder had no per-user rate limit at
// all, and a COD order costs the caller nothing to create, so a script
// could hammer this callable without bound.
//
// First attempt was a flat per-uid COOLDOWN (createAssociateOnboardingPayment.ts's
// `onboarding_rate_limits` pattern) — reverted after the full emulator
// battery caught it regressing four EXISTING suites (phase14_payment_replay,
// phase15_order_integrity, phase27_stock_integrity, phaseD_redemption), all
// of which legitimately call createOrder a second time for the SAME uid
// within seconds (retrying with a different coupon, attempting a double
// spend that must be rejected for ITS OWN reason, a second real order after
// stock moved) — real evidence that "a legitimate checkout never needs a
// second call within N seconds" was wrong, not merely a test-fixture
// inconvenience: a genuine customer does the same thing (buys something,
// then immediately buys something else they forgot).
//
// Replaced with a fixed-window COUNTER instead: up to MAX_ORDERS_PER_WINDOW
// successful orders per uid per ORDER_RATE_LIMIT_WINDOW_MS, read/written
// INSIDE this function's own transaction (createOrder already runs one
// transaction per call, so folding the check-then-write into it makes the
// two atomic against each other for free — no separate get()/set() race).
// 8 orders per 60 seconds is a generous safety margin, not a measured
// business ceiling: comfortably above every same-uid call pattern in this
// codebase's own test suites (none exceeds 2), while still turning
// "unlimited" into a real, enforced ceiling (≤480/hour) against a
// burst-abuse script.
const ORDER_RATE_LIMIT_WINDOW_MS = 60 * 1000;
const MAX_ORDERS_PER_WINDOW = 8;

// FIX-16, WS2 (finding N-23). deliveryAddress/notes/deliverySlot/orderType/
// autoFrequency were written into the order document verbatim from client
// input with no shape or size bound. Firestore's own per-document limit
// (1 MiB) would eventually reject an extreme payload, but only AFTER this
// transaction has already done all its other reads/writes and is about to
// commit — turning a cheap, clean invalid-argument rejection into an
// expensive failed transaction. These caps are generous relative to any
// real value (AddressModel's real fields — name/phone/address lines/city/
// state/zipcode/country/landmark — serialize to well under 1 KB; a real
// delivery note is a short sentence) while still blocking a multi-KB/MB
// payload outright.
const MAX_NOTES_LENGTH = 500;
const MAX_SHORT_STRING_FIELD_LENGTH = 100;
const MAX_DELIVERY_ADDRESS_BYTES = 4096;

function validateOrderInputBounds(data: CreateOrderData): void {
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
  for (const field of ["deliverySlot", "orderType", "autoFrequency"] as const) {
    const value = data?.[field];
    if (typeof value === "string" && value.length > MAX_SHORT_STRING_FIELD_LENGTH) {
      throw new HttpsError("invalid-argument", `${field} is too long`);
    }
  }
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
    if (item.variantId !== undefined && item.variantId !== null &&
        (typeof item.variantId !== "string" || item.variantId.length > MAX_VARIANT_ID_LENGTH)) {
      throw new HttpsError("invalid-argument", `Invalid option for product ${item.productId}`);
    }
  }

  // FIX-16, WS2 (finding N-23). Pure input shape/size validation — no
  // Firestore dependency, so it runs before any read, same as the item
  // checks above.
  validateOrderInputBounds(data);

  // Phase FIX-3 (finding N-4, P1). Collapse repeated productIds into one line
  // with the summed quantity, and bound the cart, BEFORE anything downstream
  // consumes the list. Every later consumer must see the SAME normalized array:
  // the product refs (so tx.getAll is bounded and stays index-aligned with the
  // items), the pricing call (so the per-entry stock check sees the true total
  // per product — that per-entry comparison is what let [{p,5},{p,5}] pass
  // twice against stock 5), and computeCartFingerprint (so a hold quoted by
  // quoteOrderWithCredit, which normalizes identically, produces a matching
  // fingerprint here instead of failing its cart-change guard). Shared
  // implementation in orderPricing.ts for the same reason the pricing itself
  // lives there: the quote and the order must never disagree.
  const normalizedItems = normalizeOrderItems(items);

  const db = admin.firestore();

  // Phase D: a hold's amount is never known until it's read inside the
  // transaction below — and it may cover the ENTIRE order, in which case
  // there is no Razorpay payment at all (see the payable-aware checks in
  // the transaction body). So the upfront "Razorpay details required"
  // guard below is skipped ONLY when a hold is supplied; with no hold, this
  // is byte-for-byte the pre-Phase-D check, firing before any Firestore
  // access exactly as before (S4 note: the amount itself always comes from
  // the hold document, never from productCreditHoldId's mere presence).
  const productCreditHoldId =
    typeof data?.productCreditHoldId === "string" && data.productCreditHoldId.trim()
      ? data.productCreditHoldId.trim()
      : null;

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
  if (!productCreditHoldId && paymentMethod !== "cod" && (!razorpayPaymentId || !razorpayOrderId)) {
    throw new HttpsError(
      "invalid-argument",
      "Razorpay payment details are required for non-COD orders"
    );
  }
  // Phase D: constructed off razorpayPaymentId's presence rather than
  // paymentMethod alone — a hold that covers the full order arrives here
  // with paymentMethod !== "cod" but no razorpayPaymentId at all, and must
  // not attempt `.doc(undefined)`.
  const paymentRef =
    paymentMethod !== "cod" && razorpayPaymentId
      ? db.collection("verified_payments").doc(razorpayPaymentId as string)
      : null;

  // Phase 16, Workstream 7: an incomplete-profile user must not be able to
  // transact — read alongside every other read this transaction needs.
  const userRef = db.collection("users").doc(uid);

  // FIX-16, WS1 (finding N-23). Read+written inside this same transaction
  // (see ORDER_RATE_LIMIT_WINDOW_MS's comment above) so the check and the
  // marker update are atomic with the order-creation writes they gate.
  const rateLimitRef = db.collection("order_rate_limits").doc(uid);

  // Phase D: refs for the hold this order settles, plus the Q5 gate
  // (assertProgramLaunchable + PRODUCT_CREDIT_REDEMPTION_ENABLED) re-read
  // fresh HERE — never trusted from quote time — via tx.get() so it is
  // part of this transaction's own atomic read set rather than
  // complianceGate.ts's assertProgramLaunchable(), which performs its own
  // non-transactional reads. All four are no-ops (null) for the
  // overwhelming majority of orders that carry no hold at all.
  const creditHoldRef = productCreditHoldId
    ? db.collection("product_credit_holds").doc(productCreditHoldId)
    : null;
  const creditProjectionRef = productCreditHoldId
    ? db.collection("product_credit_balances").doc(uid)
    : null;
  const creditComplianceRef = productCreditHoldId
    ? db.collection("compliance_config").doc("benefit_program")
    : null;
  const creditFlagRef = productCreditHoldId
    ? db.collection("feature_flags").doc("benefit_program")
    : null;

  const result = await db.runTransaction(async (tx) => {
    // ============================================
    // ALL READS FIRST — Firestore transactions require every read to
    // precede every write; the writes (order/timeline/payment-consumption
    // docs) happen only in the second half of this callback, below.
    // ============================================
    const userSnap = await tx.get(userRef);

    // FIX-16, WS1 (finding N-23). Checked right after the mandatory reads,
    // before the (unconditional) employee-code/product reads below, so a
    // throttled caller doesn't pay for reads it can't use. Fixed-window
    // counter, computed here (not via FieldValue.increment(), which cannot
    // also conditionally reset the window in the same merge) since the
    // current state is already known from this same read.
    const rateLimitSnap = await tx.get(rateLimitRef);
    const rateLimitData = rateLimitSnap.data();
    const windowStart = rateLimitData?.windowStart as admin.firestore.Timestamp | undefined;
    const withinWindow = !!windowStart && Date.now() - windowStart.toMillis() < ORDER_RATE_LIMIT_WINDOW_MS;
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
    // One read per distinct product; snaps index-aligned with normalizedItems
    // (two variants of one product are two lines over the same document).
    const uniqueProductIds = Array.from(new Set(normalizedItems.map((item) => item.productId)));
    const uniqueRefs = uniqueProductIds.map((id) => db.collection("products").doc(id));
    const uniqueSnaps = await tx.getAll(...uniqueRefs);
    const snapById = new Map(uniqueSnaps.map((s) => [s.id, s]));
    const productSnaps = normalizedItems.map((item) => snapById.get(item.productId)!);

    // Phase FIX-8, WS1: fetch the cart's single seller's own delivery fee
    // schedule, if the cart resolves to exactly one real seller. Mirrors
    // orderPricing.ts's own sellerId-extraction sentinel exactly (a
    // deliberate small duplication, not a shared helper — the caller must
    // know the seller set BEFORE calling computeOrderPricing, which is
    // what determines it, and this read must happen before any write in
    // this transaction regardless). A multi-seller cart, or one where the
    // single seller has no schedule configured, reads nothing extra here
    // and falls through to computeOrderPricing's own legacy path.
    const cartSellerIds = new Set(
      productSnaps.map((snap) => {
        const sellerId = snap.exists ? (snap.data() as Record<string, unknown> | undefined)?.sellerId : undefined;
        return typeof sellerId === "string" && sellerId ? sellerId : "_unassigned";
      })
    );
    // SELLER-OPS-1: a paused seller (sellers/{uid}.acceptingOrders false)
    // takes no orders. One read per real seller in the cart, before any
    // write in this transaction.
    const realSellerIds = Array.from(cartSellerIds).filter((id) => id !== "_unassigned");
    const sellerSnaps = realSellerIds.length
      ? await tx.getAll(...realSellerIds.map((id) => db.collection("sellers").doc(id)))
      : [];
    const nowMs = Date.now();
    for (const snap of sellerSnaps) {
      assertSellerAcceptingOrders(snap.data(), nowMs);
    }

    let sellerFeeSchedules: Map<string, DeliveryFeeSchedule> | undefined;
    if (cartSellerIds.size === 1) {
      const [onlySellerId] = Array.from(cartSellerIds);
      if (onlySellerId !== "_unassigned") {
        const sellerSnap = sellerSnaps.find((s) => s.id === onlySellerId);
        const schedule = parseDeliveryFeeSchedule(sellerSnap?.data()?.deliveryFeeSchedule);
        if (schedule) {
          sellerFeeSchedules = new Map([[onlySellerId, schedule]]);
        }
      }
    }

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

    // Phase D: the hold this order settles, its owner's balance projection
    // (needed by appendLedgerEntry's REDEMPTION arithmetic below), and the
    // Q5 gate documents — all no-ops when no hold was supplied.
    const creditHoldSnap = creditHoldRef ? await tx.get(creditHoldRef) : null;
    const creditProjectionSnap = creditProjectionRef ? await tx.get(creditProjectionRef) : null;
    const creditComplianceSnap = creditComplianceRef ? await tx.get(creditComplianceRef) : null;
    const creditFlagSnap = creditFlagRef ? await tx.get(creditFlagRef) : null;

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
      items: normalizedItems,
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
      sellerFeeSchedules,
    });

    // ============================================
    // Phase D: settle the Product Credit hold, if one was supplied. This
    // entire block is a no-op (creditApplied stays 0) when
    // productCreditHoldId is absent — the overwhelming majority of orders.
    // Every validation below re-reads from THIS transaction's own snapshot
    // (never a value cached outside it), so a retried transaction callback
    // re-validates from scratch. amount is read from the hold document —
    // never from client input (S4/S7).
    // ============================================
    let creditApplied = 0;
    let creditEnrollmentId = "";
    let creditRelatedEntryId: string | null = null;
    let creditProjection: ReturnType<typeof toProjectionFields> | null = null;
    let creditLedgerEntryRef: FirebaseFirestore.DocumentReference | null = null;

    if (productCreditHoldId) {
      if (!creditHoldSnap || !creditHoldSnap.exists) {
        throw new HttpsError(
          "failed-precondition",
          "Product Credit hold not found — please re-quote"
        );
      }
      const hold = creditHoldSnap.data()!;

      // Double-spend / cross-user guards, in this order: existence (above),
      // ownership, then status. A hold already settled/released/expired by
      // an earlier call (or the expiry sweep) is rejected here exactly like
      // a not-found hold — this IS the double-spend guard (S7).
      if (hold.customerId !== uid) {
        throw new HttpsError(
          "permission-denied",
          "This Product Credit hold does not belong to you"
        );
      }
      if (hold.status !== "active") {
        throw new HttpsError(
          "failed-precondition",
          `This Product Credit hold is no longer active (status: ${hold.status}) — please re-quote`
        );
      }
      const expiresAtMs = (hold.expiresAt as admin.firestore.Timestamp | undefined)?.toMillis() ?? 0;
      if (expiresAtMs <= Date.now()) {
        throw new HttpsError(
          "failed-precondition",
          "This Product Credit hold has expired — please re-quote"
        );
      }
      // Cart-change guard. NOTE: computeCartFingerprint does NOT cover
      // deliveryCharge/tax (see productCreditHold.ts) — a change in those
      // alone will NOT be caught here; it is caught by the payment-amount
      // cross-check below instead, since it changes pricing.grandTotal.
      const recomputedFingerprint = computeCartFingerprint(normalizedItems, orderMode, normalizedCouponCode);
      if (recomputedFingerprint !== hold.cartFingerprint) {
        throw new HttpsError(
          "failed-precondition",
          "Your cart has changed since this Product Credit hold was quoted — please re-quote"
        );
      }

      // Q5 gate: both the compliance/launch gate AND the redemption flag
      // must be open, re-checked fresh (never trusted from quote time).
      // Read via tx.get() above rather than calling
      // complianceGate.ts's assertProgramLaunchable() (which performs its
      // own non-transactional reads) so this check is part of THIS
      // transaction's atomic snapshot.
      const compliance = creditComplianceSnap?.data() || {};
      const flags = creditFlagSnap?.data() || {};
      const launchable =
        compliance.legalReviewStatus === "APPROVED" &&
        compliance.complianceApprovalStatus === "APPROVED" &&
        flags.BENEFIT_PROGRAM_ENABLED === true;
      if (!launchable || flags.PRODUCT_CREDIT_REDEMPTION_ENABLED !== true) {
        throw new HttpsError(
          "failed-precondition",
          "Product Credit redemption is not currently enabled — this order cannot be settled with a hold"
        );
      }

      creditApplied = typeof hold.amount === "number" ? hold.amount : 0;

      // Phase D-1, DEFECT D-2 fix (defence in depth): quoteOrderWithCredit
      // now caps a NEW hold's amount at the order's grand total (see
      // redemptionRules.ts), but this hold was quoted earlier — pricing can
      // have changed since (e.g. a coupon's usageLimit was hit, stock
      // dropped, a product's price changed). REJECT rather than silently
      // cap: capping here would settle the hold for less than its full
      // amount, which violates the all-or-nothing invariant (a hold is
      // settled in full or released in full — never partially). The
      // customer must re-quote instead, same phrasing as the sibling
      // guards above.
      if (creditApplied > pricing.grandTotal + 0.01) {
        throw new HttpsError(
          "failed-precondition",
          "This Product Credit hold exceeds the order total — please re-quote"
        );
      }

      creditEnrollmentId = (hold.enrollmentId as string) || "";
      creditRelatedEntryId = (hold.ledgerEntryId as string) || null;
      creditProjection = toProjectionFields(creditProjectionSnap?.data());
      // Pre-allocated here (no Firestore round-trip) so its id can be
      // embedded on every order document created below, for the
      // cancellation-reversal trigger to look up without a query.
      creditLedgerEntryRef = db.collection("product_credit_ledger").doc();
    }

    // Payment trust boundary: for any non-COD order, a real verified_payments
    // document (written only by verifyRazorpayPayment after HMAC + live API
    // verification — see functions/src/customer/payment.ts) must exist,
    // belong to THIS caller, not already be consumed by an earlier order,
    // and match this request. A client-supplied razorpayPaymentId string
    // alone proves nothing.
    //
    // Phase D: the amount a non-COD order must be verifiably PAID for is no
    // longer always the grand total — it's the grand total minus whatever
    // Product Credit was applied (`payable`). When credit covers the order
    // in full, `payable` is ~0 and there is no Razorpay payment to check at
    // all (paymentRef is null in that case — see its construction above).
    const payable = roundMoney(pricing.grandTotal - creditApplied);
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
      // Phase FIX-1 (finding N-1, P0): the third consumption direction, which
      // did not exist as a check until now. verifyWalletTopup
      // (functions/src/customer/wallet.ts) used to anchor idempotency ONLY on
      // wallet_topups/{paymentId} — a collection neither this function nor
      // activationCore.ts reads — so the wallet namespace and this one were
      // disjoint and a single captured payment could be spent twice: once on
      // real goods here, once as wallet balance there, in either order. That
      // function now claims the payment with consumedByWalletTopup inside the
      // same transaction that credits the wallet; this check is the half that
      // makes the guard mutual.
      if (payment.consumedByWalletTopup) {
        throw new HttpsError("failed-precondition", "This payment has already been used for a wallet top-up");
      }
      // Phase AI-4 (D-SELLER-AI-FUNDING): fourth consumption direction. A
      // payment already spent on a seller's ₹50 AI Assistant activation
      // (functions/src/seller/aiConnection.ts's connectSellerAiProvider) must
      // never also create a real order.
      if (payment.consumedBySellerAiActivationFor) {
        throw new HttpsError("failed-precondition", "This payment has already been used for a seller AI Assistant activation");
      }
      if (payment.orderId !== razorpayOrderId) {
        throw new HttpsError("failed-precondition", "Payment does not match this order");
      }
      if (!isSpendableCapturedPayment(payment, razorpayPaymentId, "goods_checkout")) {
        throw new HttpsError("failed-precondition", "Payment was not captured");
      }
      const verifiedAmount = typeof payment.amount === "number" ? payment.amount : -1;
      // FIX-9, WS3. Was `> 1` — a full RUPEE, on values that are already
      // rupee-denominated (payment.ts converts Razorpay's paise back to
      // rupees before storage) and each independently rounded exactly ONCE
      // (orderPricing.ts's grandTotal, roundMoney to 2dp). True drift between
      // two independently-computed totals is on the order of a paisa, not a
      // rupee — the old tolerance let a customer pay up to ₹1 less than the
      // order total and still pass. MONEY_EPSILON is generous enough to
      // absorb one independent rounding step on each side without leaving a
      // rupee-scale gap; if real-world false-rejects ever appear, this is
      // the one constant to revisit.
      if (Math.abs(verifiedAmount - payable) > MONEY_EPSILON) {
        throw new HttpsError(
          "failed-precondition",
          "Verified payment amount does not match the order total"
        );
      }
    } else if (paymentMethod !== "cod" && payable > MONEY_EPSILON) {
      // Deferred form of the upfront "Razorpay details required" guard
      // (skipped above only when a hold was supplied) — a hold that does
      // NOT cover the order in full still requires a real payment for the
      // remainder.
      throw new HttpsError(
        "invalid-argument",
        "Razorpay payment details are required for non-COD orders"
      );
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

    // Phase D: distribute creditApplied across the per-seller order
    // documents by each seller's share of the cart subtotal — the exact
    // same ratio orderPricing.ts already used to split discount/delivery/
    // tax. Rounding: each non-last seller's share is rounded to the nearest
    // paisa; the LAST seller absorbs whatever residual that rounding left
    // behind (rather than also being independently rounded), so the shares
    // always sum to creditApplied exactly — never drift a cent short/over
    // of what the ledger actually redeemed.
    const sellerCount = pricing.perSeller.length;
    const creditShares: number[] = [];
    if (creditApplied > 0) {
      let allocated = 0;
      for (let i = 0; i < sellerCount; i++) {
        if (i === sellerCount - 1) {
          creditShares.push(roundMoney(creditApplied - allocated));
        } else {
          const ratio =
            pricing.cartSubtotal > 0 ? pricing.perSeller[i].subtotal / pricing.cartSubtotal : 1 / sellerCount;
          const share = roundMoney(creditApplied * ratio);
          creditShares.push(share);
          allocated = roundMoney(allocated + share);
        }
      }
    } else {
      for (let i = 0; i < sellerCount; i++) creditShares.push(0);
    }

    let index = 0;
    for (const sellerResult of pricing.perSeller) {
      const sellerCreditShare = creditShares[index];
      index++;
      const orderRef = db.collection("orders").doc();
      const orderNumber = pricing.perSeller.length === 1 ? baseOrderNumber : `${baseOrderNumber}-${index}`;

      const deliveryCode = generateVerificationCode();
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
        // DLV-0 stage A: the same code is also written to
        // orders/{id}/secrets/delivery just below. This copy stays ONLY
        // because the released marketplace build reads it from here; it is
        // partner-readable, and DLV-0B removes it once a marketplace build
        // reading the secret doc is adopted.
        deliveryVerificationCode: deliveryCode,
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
        // Phase D: this seller's share of the settled Product Credit hold
        // (0 when no hold was supplied — the overwhelming majority of
        // orders). productCreditLedgerEntryId is server-side bookkeeping
        // (not modeled in OrderModel, same as commissionAmount/
        // commissionPaid) letting productCreditReversal.ts find the
        // REDEMPTION ledger entry to reverse on cancellation without a
        // query.
        productCreditApplied: sellerCreditShare,
        productCreditHoldId: productCreditHoldId,
        productCreditReversed: false,
        productCreditLedgerEntryId: creditLedgerEntryRef ? creditLedgerEntryRef.id : null,
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

      createdOrders.push({
        orderId: orderRef.id,
        orderNumber,
        sellerId: sellerResult.sellerId ?? "",
        total: sellerResult.total,
      });
    }

    // ============================================
    // Phase FIX-3 (finding N-3, P1): actually reserve the stock.
    // ============================================
    // Until now NOTHING in this codebase decremented stock. computeOrderPricing
    // validated `product.stock` and no code path anywhere wrote it back — a
    // grep for a stock write across functions/src returned zero, and the only
    // decrement that ever existed (updateStockAfterOrder in
    // packages/agrimore_services/lib/orders/order_service.dart) has no callers
    // and would be denied by the `products` rules anyway. So stock never fell,
    // an out-of-stock product stayed purchasable forever, `soldCount` never
    // moved, and onProductStockChanged's low-stock alerts could only ever fire
    // from a manual seller edit — never from a sale.
    //
    // Written here, in the same transaction that creates the orders, so the
    // stock check performed earlier in this same transaction and the decrement
    // are atomic: two concurrent orders for the last unit cannot both pass.
    // productSnaps is index-aligned with normalizedItems (tx.getAll preserves
    // the order of the refs it was given), so snap i belongs to item i.
    //
    // N-49, deliberately preserved: `stock` is only decremented when it is
    // ALREADY a finite number. computeOrderPricing fails OPEN for a missing or
    // non-numeric stock — mirroring ProductModel.fromMap's default of 999 — and
    // blindly applying increment(-qty) to such a product would materialise a
    // negative stock field out of nothing, turning a documented fail-open into
    // silent data corruption. Whether that fail-open should become fail-closed
    // is an owner decision about the live catalogue (how many products were
    // never backfilled), not something this phase decides.
    //
    // `soldCount` is incremented unconditionally: it is a pure counter, and
    // increment() on a missing field starts it at 0, which is correct.
    // SELLER-CATALOGUE-2: one write per product. Base lines decrement
    // `stock` (N-49 rule kept); variant lines decrement that variant's own
    // stock inside the `variants` array, rewritten once from the snapshot
    // read in this same transaction.
    const lineIndex = new Map<string, number[]>();
    normalizedItems.forEach((item, i) => {
      const list = lineIndex.get(item.productId) ?? [];
      list.push(i);
      lineIndex.set(item.productId, list);
    });
    for (const [productId, indexes] of lineIndex) {
      const snap = snapById.get(productId)!;
      const data = snap.data() ?? {};
      let baseQty = 0;
      let soldQty = 0;
      const variants = Array.isArray(data.variants) ? (data.variants as Record<string, unknown>[]).map((v) => ({ ...v })) : null;
      let variantsChanged = false;
      for (const i of indexes) {
        const qty = normalizedItems[i].quantity;
        soldQty += qty;
        const vIndex = pricing.validatedItems[i]?.variantIndex;
        if (vIndex !== undefined && variants && variants[vIndex]) {
          const vs = variants[vIndex].stock;
          if (typeof vs === "number" && Number.isFinite(vs)) {
            variants[vIndex].stock = vs - qty;
            variantsChanged = true;
          }
        } else {
          baseQty += qty;
        }
      }
      const stockRaw = data.stock;
      const stockIsEnforceable = typeof stockRaw === "number" && Number.isFinite(stockRaw);
      const update: Record<string, unknown> = {
        soldCount: admin.firestore.FieldValue.increment(soldQty),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      if (baseQty > 0 && stockIsEnforceable) update.stock = admin.firestore.FieldValue.increment(-baseQty);
      if (variantsChanged) update.variants = variants;
      tx.update(snap.ref, update);
    }

    // Phase D: settle the hold — append the REDEMPTION ledger entry (with
    // relatedEntryId pointing at the HOLD entry, which is what
    // productCreditLedger.ts's arithmetic keys off to clear onHold WITHOUT
    // touching `available` a second time — see its header comment) and
    // mark the hold itself settled. All-or-nothing: creditApplied is either
    // the hold's full amount or this block doesn't run at all (Q3 — no
    // partial settlement exists anywhere in this codebase).
    if (productCreditHoldId && creditHoldRef && creditProjection && creditLedgerEntryRef) {
      appendLedgerEntry(tx, db, {
        entryRef: creditLedgerEntryRef,
        customerId: uid,
        enrollmentId: creditEnrollmentId,
        type: "REDEMPTION",
        amount: creditApplied,
        currentProjection: creditProjection,
        relatedEntryId: creditRelatedEntryId,
        orderId: createdOrders[0].orderId,
        description: `Redeemed against order ${baseOrderNumber}`,
      });
      tx.update(creditHoldRef, {
        status: "settled",
        settledAt: admin.firestore.FieldValue.serverTimestamp(),
        settledByOrderId: createdOrders[0].orderId,
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

    // FIX-16, WS1 (finding N-23). Marked only once every other write this
    // order needs has been queued — a caller who hits an error above never
    // consumes a slot in their own window for an order that didn't happen.
    tx.set(
      rateLimitRef,
      { windowStart: rateLimitWindowStartToWrite, count: rateLimitCountToWrite },
      { merge: true }
    );

    return { success: true, orders: createdOrders };
  });

  return result;
});
