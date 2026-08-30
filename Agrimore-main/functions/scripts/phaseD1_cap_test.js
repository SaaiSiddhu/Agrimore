// Phase D-1, Workstream 4 — DEFECT D-2 fix: credit can never exceed the
// order's grand total. Proves (1) quoteOrderWithCredit caps a NEW hold at
// grandTotal even when eligibleSubtotal/availableCredit would otherwise
// allow more (a large coupon discount is what exposes the gap — grandTotal
// drops below eligibleSubtotal), so `payable` is never negative, and (2)
// createOrder independently REJECTS (never silently caps — the
// all-or-nothing hold invariant) a hold that somehow still exceeds the
// order's grand total at settlement time. Same onCall direct-invocation
// harness as phaseD_redemption_test.js.
// Run with: node scripts/phaseD1_cap_test.js
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { quoteOrderWithCredit } = require("../lib/customer/productCreditHold");
const { createOrder } = require("../lib/customer/createOrder");
const { computeCartFingerprint } = require("../lib/customer/productCreditHold");

const wrappedQuote = test.wrap(quoteOrderWithCredit);
const wrappedCreateOrder = test.wrap(createOrder);

const db = admin.firestore();
const auth = (uid) => ({ uid, token: {} });

async function callAndCapture(wrapped, payload, authCtx) {
  try {
    const result = await wrapped({ data: payload, auth: authCtx });
    return { ok: true, result };
  } catch (e) {
    return { ok: false, code: e.code, message: e.message };
  }
}

async function seedUser(uid) {
  await db.collection("users").doc(uid).set({ uid, profileCompleted: true });
}
async function seedProduct(productId, salePrice, sellerId) {
  await db.collection("products").doc(productId).set({
    name: `Product ${productId}`,
    salePrice,
    sellerId,
    images: [],
    isB2BEnabled: false,
  });
}
async function seedProgram(programId, overrides) {
  await db.collection("benefit_programs").doc(programId).set({
    name: `Program ${programId}`,
    status: "active",
    durationMonths: 12,
    rulesVersion: 1,
    benefitRuleType: "flatRupee",
    benefitRateValue: 500,
    creditFrequency: "monthly",
    minProgramAmount: 0,
    maxProgramAmount: 0,
    redemptionEnabled: true,
    minOrderValueForRedemption: 0,
    maxCreditPerOrder: null,
    maxCreditPercentOfOrder: null,
    redeemableCategoryIds: null,
    ...overrides,
  });
}
async function seedEnrollment(enrollmentId, customerId, programId) {
  await db.collection("benefit_enrollments").doc(enrollmentId).set({
    customerId,
    programId,
    status: "active",
    programAmount: 100000,
    rulesVersionAtEnrollment: 1,
    startDate: admin.firestore.Timestamp.fromDate(new Date("2026-01-01")),
    maturityDate: admin.firestore.Timestamp.fromDate(new Date("2027-01-01")),
  });
}
async function seedBalance(customerId, available) {
  await db
    .collection("product_credit_balances")
    .doc(customerId)
    .set({ available, pending: 0, onHold: 0, lifetimeEarned: available, lifetimeUsed: 0, lifetimeExpired: 0 });
}
async function seedCoupon(code, discount, type = "flat") {
  await db.collection("coupons").add({
    code,
    type,
    discount,
    isActive: true,
    usageLimit: 0,
    usedCount: 0,
    minOrderAmount: 0,
    validFrom: admin.firestore.Timestamp.fromMillis(Date.now() - 24 * 60 * 60 * 1000),
    validTo: admin.firestore.Timestamp.fromMillis(Date.now() + 24 * 60 * 60 * 1000),
  });
}
async function approveComplianceAndFlags({ redemptionEnabled = true } = {}) {
  await db
    .doc("compliance_config/benefit_program")
    .set({ legalReviewStatus: "APPROVED", complianceApprovalStatus: "APPROVED" }, { merge: true });
  await db
    .doc("feature_flags/benefit_program")
    .set({ BENEFIT_PROGRAM_ENABLED: true, PRODUCT_CREDIT_REDEMPTION_ENABLED: redemptionEnabled }, { merge: true });
}

async function resetCustomerCreditState(customerId) {
  const holdsSnap = await db.collection("product_credit_holds").where("customerId", "==", customerId).get();
  await Promise.all(holdsSnap.docs.map((d) => d.ref.delete()));
  await db.collection("product_credit_balances").doc(customerId).delete().catch(() => {});
}

async function main() {
  const results = {};
  const record = (key, ok, passMsg, failMsg) => {
    results[key] = ok ? `PASSED — ${passMsg}` : `FAILED — ${failMsg}`;
  };

  const ALL_TEST_CUSTOMER_IDS = ["phaseD1-cap-c1", "phaseD1-cap-c3", "phaseD1-cap-c4"];
  for (const c of ALL_TEST_CUSTOMER_IDS) await resetCustomerCreditState(c);

  // ============================================================
  // Scenario 1+2: a coupon large enough that grandTotal < availableCredit
  // (and < eligibleSubtotal, which alone would have allowed far more)
  // yields a quote whose creditApplied <= grandTotal and payable >= 0.
  // Product 1000, flat coupon discount 800 -> grandTotal = 200.
  // eligibleSubtotal = 1000 (no category restriction) would, pre-fix, have
  // let creditApplied reach up to min(available=2000, eligible=1000) =
  // 1000 -- 800 MORE than the order actually costs.
  // ============================================================
  {
    const customerId = "phaseD1-cap-c1";
    await seedUser(customerId);
    await seedProduct("phaseD1-cap-p1", 1000, "phaseD1-cap-seller1");
    await seedProgram("phaseD1-cap-prog1", {});
    await seedEnrollment("phaseD1-cap-enroll1", customerId, "phaseD1-cap-prog1");
    await approveComplianceAndFlags({ redemptionEnabled: true });
    await seedBalance(customerId, 2000); // far more than the discounted grandTotal
    await seedCoupon("PHASED1CAP1", 800, "flat");

    const quote = await callAndCapture(
      wrappedQuote,
      { items: [{ productId: "phaseD1-cap-p1", quantity: 1 }], orderMode: "B2C", couponCode: "PHASED1CAP1" },
      auth(customerId)
    );

    const ok =
      quote.ok &&
      quote.result.total === 200 && // 1000 - 800 discount
      quote.result.creditApplied === 200 && // capped at grandTotal, NOT 1000 (eligibleSubtotal cap)
      quote.result.creditApplied <= quote.result.total &&
      quote.result.payable === 0 &&
      quote.result.payable >= 0;
    record(
      "1and2_coupon_caps_credit_at_grandtotal_payable_never_negative",
      ok,
      `grandTotal=200 (after 800 coupon discount on a 1000 item), creditApplied capped at 200 (not the 1000 eligibleSubtotal would have allowed), payable=0 (never negative)`,
      `quote=${JSON.stringify(quote)}`
    );
  }

  // ============================================================
  // Scenario 3: a hold whose amount exceeds the order's grand total at
  // SETTLEMENT time (simulating pricing having changed since the quote) is
  // REJECTED by createOrder with failed-precondition — never silently
  // capped.
  // ============================================================
  {
    const customerId = "phaseD1-cap-c3";
    await seedUser(customerId);
    await seedProduct("phaseD1-cap-p3", 500, "phaseD1-cap-seller3");
    await approveComplianceAndFlags({ redemptionEnabled: true });

    const items = [{ productId: "phaseD1-cap-p3", quantity: 1 }];
    const cartFingerprint = computeCartFingerprint(items, "B2C", null);
    const oversizedHoldId = "phaseD1-cap-oversizedhold3";
    await db.collection("product_credit_holds").doc(oversizedHoldId).set({
      id: oversizedHoldId,
      customerId,
      enrollmentId: "phaseD1-cap-enroll3",
      amount: 999, // exceeds the order's actual grandTotal (500)
      status: "active",
      ledgerEntryId: null,
      cartFingerprint,
      quotedTotal: 999,
      quotedPayable: 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + 30 * 60 * 1000),
      releasedAt: null,
      settledAt: null,
    });

    const order = await callAndCapture(
      wrappedCreateOrder,
      { items, orderMode: "B2C", paymentMethod: "cod", productCreditHoldId: oversizedHoldId },
      auth(customerId)
    );

    const holdDoc = await db.collection("product_credit_holds").doc(oversizedHoldId).get();
    const ok = !order.ok && order.code === "failed-precondition" && holdDoc.data().status === "active"; // untouched, not silently settled/capped
    record(
      "3_oversized_hold_rejected_not_capped",
      ok,
      `hold amount 999 > order grandTotal 500 -> rejected: code=${order.code}, message="${order.message}"; hold status remains "active" (not silently settled for less)`,
      `order=${JSON.stringify(order)} holdStatus=${holdDoc.data()?.status}`
    );
  }

  // ============================================================
  // Scenario 4: a normal order (credit well below total) is completely
  // unaffected by the D-2 fix — regression safety.
  // ============================================================
  {
    const customerId = "phaseD1-cap-c4";
    await seedUser(customerId);
    await seedProduct("phaseD1-cap-p4", 1000, "phaseD1-cap-seller4");
    await seedProgram("phaseD1-cap-prog4", {});
    await seedEnrollment("phaseD1-cap-enroll4", customerId, "phaseD1-cap-prog4");
    await approveComplianceAndFlags({ redemptionEnabled: true });
    await seedBalance(customerId, 100); // well below the 1000 grandTotal

    const items = [{ productId: "phaseD1-cap-p4", quantity: 1 }];
    const quote = await callAndCapture(wrappedQuote, { items, orderMode: "B2C" }, auth(customerId));
    const order = await callAndCapture(
      wrappedCreateOrder,
      { items, orderMode: "B2C", paymentMethod: "cod", productCreditHoldId: quote.result?.holdId },
      auth(customerId)
    );

    let orderCreditApplied = null;
    if (order.ok) {
      const orderDoc = await db.collection("orders").doc(order.result.orders[0].orderId).get();
      orderCreditApplied = orderDoc.data().productCreditApplied;
    }

    const ok = quote.ok && quote.result.creditApplied === 100 && order.ok && orderCreditApplied === 100;
    record(
      "4_normal_order_unaffected",
      ok,
      `credit well below total (100 available on a 1000 order): quote creditApplied=100, order settled with productCreditApplied=100 — unchanged by the D-2 fix`,
      `quote=${JSON.stringify(quote)} order=${JSON.stringify(order)} orderCreditApplied=${orderCreditApplied}`
    );
  }

  console.log("=== PHASE D-1 — CREDIT-CAP TEST (DEFECT D-2) ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);
  const allPassed = Object.values(results).every((v) => v.startsWith("PASSED"));
  console.log(allPassed ? "\nALL PASSED" : "\nSOME FAILED");
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phaseD1 cap test:", e);
  process.exit(1);
});
