// ============================================================
//  Product Credit quote + hold + release lifecycle
//  (Phase C: Product Credit redemption machinery)
// ============================================================
//
// Solves the sequencing problem createOrder.ts alone cannot: today's
// checkout charges Razorpay BEFORE calling createOrder, so the client must
// know the authoritative total (including any credit deduction) ahead of
// time, and the credit it plans to use must not be spendable elsewhere in
// the gap between charging and order creation.
//
// quoteOrderWithCredit computes the exact same numbers createOrder.ts would
// (via the shared orderPricing.ts — see that file's header), decides how
// much credit may actually be applied (via redemptionRules.ts —
// NEVER the client-requested amount), and — if any credit is applied —
// places a HOLD via appendLedgerEntry so that credit cannot be spent twice
// while the customer is mid-checkout. releaseProductCreditHold undoes a
// hold. Nothing in this file ever writes a REDEMPTION entry: Phase D's
// createOrder cutover is what settles a hold into an actual spend.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as crypto from "crypto";
import { assertProgramLaunchable, resolveIsAdmin } from "../admin/complianceGate";
import { appendLedgerEntry, toProjectionFields } from "./productCreditLedger";
import { computeOrderPricing, normalizeOrderItems, OrderPricingItemInput, assertSafeOrderMoney } from "./orderPricing";
import { computeRedeemableAmount } from "./redemptionRules";
import { DeliveryFeeSchedule, parseDeliveryFeeSchedule } from "./deliveryFeeSchedule";
import { validateDeliveryQuote } from "./deliveryQuoteValidation";
import { resolveProductCategoryId } from "../common/productCategory";

// 30 minutes: long enough to cover a real Razorpay checkout flow, short
// enough that an abandoned cart doesn't lock a customer's credit for long —
// releaseExpiredProductCreditHolds (productCreditExpiry.ts) sweeps anything
// that outlives this.
const HOLD_TTL_MINUTES = 30;
const HOLD_TTL_MS = HOLD_TTL_MINUTES * 60 * 1000;

// Enrollments whose credit may actually be redeemed against — same set
// benefitAccrual.ts treats as accrual-eligible; an enrollment that isn't in
// one of these statuses has nothing spendable regardless of its ledger
// history.
const REDEMPTION_ELIGIBLE_STATUSES = ["active", "benefitEligible"];

function roundMoney(value: number): number {
  return Math.round(value * 100) / 100;
}

// A stable hash of what the customer is committing to at quote time — the
// sorted (productId, quantity) pairs plus orderMode/couponCode. Phase D
// uses this to confirm the cart hasn't changed between quote and order.
// Exported (Phase D) so createOrder.ts can recompute the exact same hash
// server-side to validate against a hold's stored cartFingerprint —
// duplicating this logic in two files would risk the two implementations
// silently drifting apart.
export function computeCartFingerprint(
  items: OrderPricingItemInput[],
  orderMode: string,
  couponCode: string | null
): string {
  // variantId only when present, so a variant-free cart hashes exactly as it
  // did before SELLER-CATALOGUE-2 (holds quoted before the deploy still match).
  const sorted = items
    .map((i) => (i.variantId ? { productId: i.productId, quantity: i.quantity, variantId: i.variantId } : { productId: i.productId, quantity: i.quantity }))
    .sort((a, b) => a.productId.localeCompare(b.productId) || String(a.variantId ?? "").localeCompare(String(b.variantId ?? "")));
  const payload = JSON.stringify({ items: sorted, orderMode, couponCode: couponCode ?? null });
  return crypto.createHash("sha256").update(payload).digest("hex");
}

interface QuoteOrderWithCreditData {
  items: OrderPricingItemInput[];
  orderMode: "B2C" | "B2B";
  // Accepted for interface parity with the createOrder call this quote
  // precedes, but NOT validated/resolved here — computeOrderPricing's
  // authoritative total never depends on employeeCode (only orderMode
  // selects B2B vs B2C pricing); employee-code validity is createOrder's
  // concern at order-creation time, not the quote's.
  employeeCode?: string;
  couponCode?: string;
  deliveryCharge?: number;
  legacyDeliveryCharge?: number;
  deliveryQuoteId?: string;
  deliveryAddress?: Record<string, unknown>;
  tax?: number;
  /** An upper-bound REQUEST — never trusted as the final amount (S4). */
  requestedCreditAmount?: number;
}

export const quoteOrderWithCredit = onCall(
  { minInstances: 0, memory: "256MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required");
    }
    const uid = request.auth.uid;
    const data = request.data as QuoteOrderWithCreditData;
    const items = Array.isArray(data?.items) ? data.items : [];
    const orderMode = data?.orderMode;

    if (items.length === 0) {
      throw new HttpsError("invalid-argument", "items cannot be empty");
    }
    if (orderMode !== "B2C" && orderMode !== "B2B") {
      throw new HttpsError("invalid-argument", "orderMode must be 'B2C' or 'B2B'");
    }
    for (const item of items) {
      if (!item || typeof item.productId !== "string" || !item.productId.trim()) {
        throw new HttpsError("invalid-argument", "Each item requires a productId");
      }
      if (!Number.isSafeInteger(item.quantity) || item.quantity <= 0) {
        throw new HttpsError("invalid-argument", `Invalid quantity for product ${item.productId}`);
      }
    }

    // Phase FIX-3 (finding N-4, P1). Identical normalization to createOrder.ts,
    // from the SAME shared implementation. This is load-bearing for holds, not
    // just for pricing: computeCartFingerprint below hashes the item list, and
    // createOrder re-derives that fingerprint to validate the hold. If only one
    // side normalized, every hold quoted from a cart containing a repeated
    // productId would fail its cart-change guard at settlement.
    const normalizedItems = normalizeOrderItems(items);

    const requestedCreditAmount =
      typeof data?.requestedCreditAmount === "number" && data.requestedCreditAmount > 0
        ? data.requestedCreditAmount
        : 0;

    const db = admin.firestore();

    // Q5's gate, checked OUTSIDE the transaction (non-transactional reads,
    // same pattern as setBenefitProgramConfig's activation check): a
    // customer with no launchable program, or with redemption not
    // explicitly enabled, must still get a valid quote — creditApplied 0,
    // never a throw. Checkout without credit must always work.
    const launch = await assertProgramLaunchable(db);
    const flagSnap = await db.collection("feature_flags").doc("benefit_program").get();
    const gateOpen = launch.launchable && flagSnap.data()?.PRODUCT_CREDIT_REDEMPTION_ENABLED === true;

    const normalizedCouponCode =
      data?.couponCode && data.couponCode.trim() ? data.couponCode.trim().toUpperCase() : null;
    const cartFingerprint = computeCartFingerprint(normalizedItems, orderMode, normalizedCouponCode);

    // One read per distinct product (two variants of a product share a doc);
    // snaps stay index-aligned with normalizedItems.
    const uniqueProductIds = Array.from(new Set(normalizedItems.map((item) => item.productId)));
    const uniqueRefs = uniqueProductIds.map((id) => db.collection("products").doc(id));
    const couponQuery = normalizedCouponCode
      ? db.collection("coupons").where("code", "==", normalizedCouponCode).limit(1)
      : null;
    const redemptionRef = normalizedCouponCode
      ? db.collection("coupon_redemptions").doc(`${normalizedCouponCode}_${uid}`)
      : null;
    const projectionRef = db.collection("product_credit_balances").doc(uid);
    const enrollmentQuery = db
      .collection("benefit_enrollments")
      .where("customerId", "==", uid)
      .where("status", "in", REDEMPTION_ELIGIBLE_STATUSES)
      .limit(1);
    const activeHoldQuery = db
      .collection("product_credit_holds")
      .where("customerId", "==", uid)
      .where("status", "==", "active");

    const result = await db.runTransaction(async (tx) => {
      // ============================================
      // ALL READS FIRST.
      // ============================================
      const uniqueSnaps = await tx.getAll(...uniqueRefs);
      const snapById = new Map(uniqueSnaps.map((s) => [s.id, s]));
      const productSnaps = normalizedItems.map((item) => snapById.get(item.productId)!);
      const couponSnap = couponQuery ? await tx.get(couponQuery) : null;
      const redemptionSnap = redemptionRef ? await tx.get(redemptionRef) : null;
      const projectionSnap = await tx.get(projectionRef);
      const enrollmentSnap = await tx.get(enrollmentQuery);
      const activeHoldsSnap = await tx.get(activeHoldQuery);

      let programSnap: FirebaseFirestore.DocumentSnapshot | null = null;
      if (!enrollmentSnap.empty) {
        const programId = enrollmentSnap.docs[0].data().programId as string;
        programSnap = await tx.get(db.collection("benefit_programs").doc(programId));
      }

      // Phase FIX-8, WS1: mirrors createOrder.ts's own identical seller-
      // schedule read exactly, so a quote and the order it precedes can
      // never disagree on the delivery charge — see orderPricing.ts's own
      // header for why this file exists at all.
      const cartSellerIds = new Set(
        productSnaps.map((snap) => {
          const sellerId = snap.exists ? (snap.data() as Record<string, unknown> | undefined)?.sellerId : undefined;
          return typeof sellerId === "string" && sellerId ? sellerId : "_unassigned";
        })
      );
      const realSellerIds = [...cartSellerIds].filter((sellerId) => sellerId !== "_unassigned");
      const sellerSnaps = realSellerIds.length
        ? await tx.getAll(...realSellerIds.map((sellerId) => db.collection("sellers").doc(sellerId)))
        : [];
      const sellerFeeSchedules = new Map<string, DeliveryFeeSchedule>();
      for (const sellerSnap of sellerSnaps) {
        const schedule = parseDeliveryFeeSchedule(sellerSnap.data()?.deliveryFeeSchedule);
        if (schedule) sellerFeeSchedules.set(sellerSnap.id, schedule);
      }
      const { sellerDistanceMeters } = await validateDeliveryQuote({
        db, tx, uid, deliveryQuoteId: data?.deliveryQuoteId,
        deliveryAddress: data?.deliveryAddress, items: normalizedItems, orderMode,
        deliveryCharge: data?.deliveryCharge, legacyDeliveryCharge: data?.legacyDeliveryCharge,
        sellerFeeSchedules, sellerSnapshots: sellerSnaps, expectedSellerIds: [...cartSellerIds],
      });

      // ============================================
      // COMPUTATION — same authoritative pricing createOrder would produce.
      // ============================================
      const pricing = computeOrderPricing({
        items: normalizedItems,
        productSnaps,
        orderMode,
        uid,
        couponSnap,
        couponCode: data?.couponCode,
        couponAlreadyRedeemed: !!(redemptionSnap && redemptionSnap.exists),
        deliveryCharge: data?.deliveryQuoteId ? data?.legacyDeliveryCharge : data?.deliveryCharge,
        tax: data?.tax,
        sellerFeeSchedules,
        sellerDistanceMeters,
      });

      // ============================================
      // Release any existing active hold(s) FIRST — a customer may hold
      // only ONE active hold at a time, and releasing before computing the
      // new redeemable amount ensures the just-released credit is counted
      // as available again for THIS quote (not double-reserved).
      // ============================================
      let currentProjection = toProjectionFields(projectionSnap.data());
      for (const holdDoc of activeHoldsSnap.docs) {
        const holdData = holdDoc.data();
        const holdAmount = typeof holdData.amount === "number" ? holdData.amount : 0;
        if (holdAmount > 0) {
          const released = appendLedgerEntry(tx, db, {
            customerId: uid,
            enrollmentId: (holdData.enrollmentId as string) || "",
            type: "RELEASE",
            amount: holdAmount,
            currentProjection,
            relatedEntryId: (holdData.ledgerEntryId as string) || null,
            description: `Released hold ${holdDoc.id} — superseded by a new quote`,
          });
          currentProjection = released.newProjection;
        }
        tx.update(holdDoc.ref, {
          status: "released",
          releasedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      // ============================================
      // Decide how much credit may be applied, using the balance AFTER any
      // release above.
      // ============================================
      let creditApplied = 0;
      let reasons: string[] = [];
      let enrollmentId: string | null = null;

      if (!gateOpen) {
        reasons = ["Product Credit redemption is not currently enabled"];
      } else if (enrollmentSnap.empty || !programSnap || !programSnap.exists) {
        reasons = ["No active benefit enrollment found for this customer"];
      } else {
        enrollmentId = enrollmentSnap.docs[0].id;
        const program = programSnap.data()!;

        const redeemableCategoryIds: string[] | null =
          Array.isArray(program.redeemableCategoryIds) && program.redeemableCategoryIds.length > 0
            ? (program.redeemableCategoryIds as string[])
            : null;

        // Sum of line items whose category is redemption-eligible (the
        // whole subtotal when the program has no category restriction).
        let eligibleSubtotal = 0;
        for (let i = 0; i < items.length; i++) {
          const productSnap = productSnaps[i];
          if (!productSnap.exists) continue; // computeOrderPricing already threw for this — unreachable
          const categoryId = resolveProductCategoryId(productSnap.data()!);
          const validated = pricing.validatedItems.find((v) => v.productId === items[i].productId);
          const lineTotal = validated ? validated.price * validated.quantity : 0;
          if (!redeemableCategoryIds || (categoryId && redeemableCategoryIds.includes(categoryId))) {
            eligibleSubtotal += lineTotal;
          }
        }

        const redemption = computeRedeemableAmount({
          program: {
            redemptionEnabled: program.redemptionEnabled === true,
            minOrderValueForRedemption:
              typeof program.minOrderValueForRedemption === "number" ? program.minOrderValueForRedemption : 0,
            maxCreditPerOrder: typeof program.maxCreditPerOrder === "number" ? program.maxCreditPerOrder : null,
            maxCreditPercentOfOrder:
              typeof program.maxCreditPercentOfOrder === "number" ? program.maxCreditPercentOfOrder : null,
          },
          orderSubtotal: pricing.cartSubtotal,
          eligibleSubtotal,
          availableCredit: currentProjection.available,
          // No specific request -> treat as "apply as much as the rules
          // allow" by requesting the full available balance as the upper
          // bound; computeRedeemableAmount's other caps still apply.
          requestedAmount: requestedCreditAmount > 0 ? requestedCreditAmount : currentProjection.available,
          // Phase D-1, DEFECT D-2 fix: credit can never exceed the order's
          // final payable total — see redemptionRules.ts's cap comment.
          orderGrandTotal: pricing.grandTotal,
        });
        creditApplied = redemption.amount;
        reasons = redemption.reasons;
      }

      const payable = roundMoney(pricing.grandTotal - creditApplied);
      assertSafeOrderMoney(payable);

      // ============================================
      // Place a new HOLD if any credit was approved. All-or-nothing (see
      // productCreditLedger.ts's REDEMPTION note): this hold is later
      // either settled in full or released in full — never partially.
      // ============================================
      let holdId: string | null = null;
      let expiresAtTimestamp: admin.firestore.Timestamp | null = null;

      if (creditApplied > 0 && enrollmentId) {
        const holdRef = db.collection("product_credit_holds").doc();
        const entryRef = db.collection("product_credit_ledger").doc();
        expiresAtTimestamp = admin.firestore.Timestamp.fromMillis(Date.now() + HOLD_TTL_MS);

        appendLedgerEntry(tx, db, {
          entryRef,
          customerId: uid,
          enrollmentId,
          type: "HOLD",
          amount: creditApplied,
          currentProjection,
          description: `Hold for checkout quote (fingerprint ${cartFingerprint})`,
          expiresAt: expiresAtTimestamp,
        });

        tx.set(holdRef, {
          id: holdRef.id,
          customerId: uid,
          enrollmentId,
          amount: creditApplied,
          status: "active",
          ledgerEntryId: entryRef.id,
          cartFingerprint,
          quotedTotal: pricing.grandTotal,
          quotedPayable: payable,
          deliveryQuoteId: data?.deliveryQuoteId ?? null,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          expiresAt: expiresAtTimestamp,
          releasedAt: null,
          settledAt: null,
        });
        holdId = holdRef.id;
      }

      return {
        total: pricing.grandTotal,
        creditApplied,
        payable,
        holdId,
        deliveryQuoteId: data?.deliveryQuoteId ?? null,
        expiresAt: expiresAtTimestamp ? expiresAtTimestamp.toDate().toISOString() : null,
        // Frozen native recovery metadata, derived from the SAME server hold
        // timestamp. Device admission is advisory; settlement rechecks Firestore.
        productCreditHoldExpiresAtMs: expiresAtTimestamp ? expiresAtTimestamp.toMillis() : null,
        reasons,
      };
    });

    return { success: true, ...result };
  }
);

interface ReleaseProductCreditHoldData {
  holdId?: string;
  reason?: string;
}

export const releaseProductCreditHold = onCall(
  { minInstances: 0, memory: "256MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required");
    }
    const uid = request.auth.uid;
    const isAdminClaim = request.auth.token.admin === true;

    const data = request.data as ReleaseProductCreditHoldData;
    const holdId = String(data?.holdId || "").trim();
    const reasonInput = String(data?.reason || "").trim();

    if (!holdId) {
      throw new HttpsError("invalid-argument", "holdId is required");
    }
    if (!reasonInput) {
      throw new HttpsError("invalid-argument", "reason is required");
    }

    const db = admin.firestore();
    const isAdmin = await resolveIsAdmin(db, uid, isAdminClaim);
    const holdRef = db.collection("product_credit_holds").doc(holdId);

    const result = await db.runTransaction(async (tx) => {
      const holdSnap = await tx.get(holdRef);
      if (!holdSnap.exists) {
        throw new HttpsError("not-found", "Hold not found");
      }
      const hold = holdSnap.data()!;
      if (hold.customerId !== uid && !isAdmin) {
        throw new HttpsError("permission-denied", "You do not own this hold");
      }

      // Idempotent: releasing an already-released/expired/settled hold is
      // a successful no-op, not an error — a client retry after a network
      // blip must not fail.
      if (hold.status !== "active") {
        return { alreadyReleased: true, status: hold.status as string };
      }

      const projectionRef = db.collection("product_credit_balances").doc(hold.customerId as string);
      const projectionSnap = await tx.get(projectionRef);
      const currentProjection = toProjectionFields(projectionSnap.data());

      appendLedgerEntry(tx, db, {
        customerId: hold.customerId as string,
        enrollmentId: (hold.enrollmentId as string) || "",
        type: "RELEASE",
        amount: typeof hold.amount === "number" ? hold.amount : 0,
        currentProjection,
        relatedEntryId: (hold.ledgerEntryId as string) || null,
        description: `Hold ${holdId} released: ${reasonInput}`,
      });

      tx.update(holdRef, {
        status: "released",
        releasedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { alreadyReleased: false, status: "released" };
    });

    return { success: true, holdId, ...result };
  }
);
