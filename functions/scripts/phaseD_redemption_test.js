// Phase D, Workstream 5 — createOrder.ts's Product Credit hold settlement.
// Proves the full quote -> hold -> createOrder cutover against a real
// emulator: an order with no hold behaves exactly as before, a valid hold
// settles with the corrected ledger arithmetic, the same hold cannot settle
// twice (double-spend guard), another user's hold is rejected, an expired
// hold is rejected, a changed cart is rejected (fingerprint mismatch), the
// payment-amount cross-check uses the discounted payable (not the full
// total), a COD order still applies credit while staying 'pending', credit
// covering the whole order needs no payment at all, a multi-seller cart's
// per-seller shares sum exactly to the hold amount, and a hold is refused
// (not silently full-priced) when the redemption flag is off.
// quoteOrderWithCredit/createOrder are v2 onCall, wrapped as
// `wrapped({data, auth})`.
// Run with: node scripts/phaseD_redemption_test.js
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { quoteOrderWithCredit } = require("../lib/customer/productCreditHold");
const { createOrder } = require("../lib/customer/createOrder");

const wrappedQuote = test.wrap(quoteOrderWithCredit);
const wrappedCreateOrder = test.wrap(createOrder);

const db = admin.firestore();
const auth = (uid) => ({ uid, token: {} });

function roundMoney(v) {
  return Math.round(v * 100) / 100;
}

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

async function getBalance(customerId) {
  const snap = await db.collection("product_credit_balances").doc(customerId).get();
  return snap.data() || {};
}

async function approveComplianceAndFlags({ redemptionEnabled = true } = {}) {
  await db
    .doc("compliance_config/benefit_program")
    .set({ legalReviewStatus: "APPROVED", complianceApprovalStatus: "APPROVED" }, { merge: true });
  await db
    .doc("feature_flags/benefit_program")
    .set(
      { BENEFIT_PROGRAM_ENABLED: true, PRODUCT_CREDIT_REDEMPTION_ENABLED: redemptionEnabled },
      { merge: true }
    );
}

async function ledgerEntriesFor(customerId, type) {
  let q = db.collection("product_credit_ledger").where("customerId", "==", customerId);
  if (type) q = q.where("type", "==", type);
  return q.get();
}

async function seedVerifiedPayment(paymentId, { orderId, userId, amount, status = "captured" }) {
  await db.collection("verified_payments").doc(paymentId).set({
    orderId,
    paymentId,
    userId,
    amount,
    status,
    consumedByOrderId: null,
    consumedByOnboardingFor: null,
  });
}

// This test's fixed customer IDs let scenarios 5/7/12 deliberately leave a
// hold ACTIVE (never settled/released, by design — that's what each of
// those scenarios is proving). Re-running this script against the same
// persistent emulator without cleaning that up first collides with
// quoteOrderWithCredit's own "release the customer's prior active hold"
// step: it tries to RELEASE a hold seedBalance's later full-overwrite
// never accounted for, driving onHold negative. Reset every customer this
// file uses before scenario 1 so the whole script is safely re-runnable.
const ALL_TEST_CUSTOMER_IDS = [
  "phaseD-red-c1", "phaseD-red-c2", "phaseD-red-c5owner", "phaseD-red-c5attacker",
  "phaseD-red-c6", "phaseD-red-c7", "phaseD-red-c8", "phaseD-red-c9", "phaseD-red-c10",
  "phaseD-red-c11", "phaseD-red-c12",
];

async function resetCustomerCreditState(customerId) {
  const holdsSnap = await db.collection("product_credit_holds").where("customerId", "==", customerId).get();
  await Promise.all(holdsSnap.docs.map((d) => d.ref.delete()));
  await db.collection("product_credit_balances").doc(customerId).delete().catch(() => {});
}

async function main() {
  let allPassed = true;
  const results = {};

  for (const customerId of ALL_TEST_CUSTOMER_IDS) {
    await resetCustomerCreditState(customerId);
  }

  // ============================================================
  // Scenario 1: no productCreditHoldId -> completely normal order.
  // ============================================================
  {
    const customerId = "phaseD-red-c1";
    await seedUser(customerId);
    await seedProduct("phaseD-red-p1", 200, "phaseD-red-seller1");

    const r = await callAndCapture(
      wrappedCreateOrder,
      {
        items: [{ productId: "phaseD-red-p1", quantity: 1 }],
        orderMode: "B2C",
        paymentMethod: "cod",
        deliveryAddress: { name: "Test", phone: "9999999999" },
      },
      auth(customerId)
    );
    let orderOk = false;
    let ledgerEmpty = false;
    if (r.ok && r.result.orders?.length === 1) {
      const orderDoc = await db.collection("orders").doc(r.result.orders[0].orderId).get();
      const data = orderDoc.data();
      orderOk =
        data.productCreditApplied === 0 &&
        data.productCreditHoldId === null &&
        data.productCreditReversed === false;
      const ledgerSnap = await ledgerEntriesFor(customerId);
      ledgerEmpty = ledgerSnap.empty;
    }
    const pass = r.ok && orderOk && ledgerEmpty;
    results.scenario1_no_hold_normal_order = pass
      ? "PASSED — order created with productCreditApplied=0, productCreditHoldId=null, no ledger entries written"
      : `FAILED — ${JSON.stringify(r)}`;
    if (!pass) allPassed = false;
  }

  // ============================================================
  // Scenario 2 + 3: valid hold settles; order fields correct; ledger
  // arithmetic corrected (onHold back to 0, available unchanged by the
  // REDEMPTION itself since it was already reduced at HOLD time).
  // ============================================================
  let scenario2CustomerId = "phaseD-red-c2";
  let scenario2HoldId = null;
  let scenario2OrderId = null;
  {
    const customerId = scenario2CustomerId;
    await seedUser(customerId);
    await seedProduct("phaseD-red-p2", 1000, "phaseD-red-seller2");
    await seedProgram("phaseD-red-prog2", {});
    await seedEnrollment("phaseD-red-enroll2", customerId, "phaseD-red-prog2");
    await approveComplianceAndFlags({ redemptionEnabled: true });
    await seedBalance(customerId, 300);

    const quote = await callAndCapture(
      wrappedQuote,
      { items: [{ productId: "phaseD-red-p2", quantity: 1 }], orderMode: "B2C" },
      auth(customerId)
    );
    scenario2HoldId = quote.result?.holdId;
    const balAfterQuote = await getBalance(customerId);

    const order = await callAndCapture(
      wrappedCreateOrder,
      {
        items: [{ productId: "phaseD-red-p2", quantity: 1 }],
        orderMode: "B2C",
        paymentMethod: "cod",
        productCreditHoldId: scenario2HoldId,
      },
      auth(customerId)
    );
    scenario2OrderId = order.result?.orders?.[0]?.orderId;

    let orderFieldsOk = false;
    if (order.ok && scenario2OrderId) {
      const orderDoc = await db.collection("orders").doc(scenario2OrderId).get();
      const data = orderDoc.data();
      orderFieldsOk =
        data.productCreditApplied === 300 &&
        data.productCreditHoldId === scenario2HoldId &&
        data.productCreditReversed === false;
    }
    const holdDoc = await db.collection("product_credit_holds").doc(scenario2HoldId).get();
    const holdSettled =
      holdDoc.data()?.status === "settled" && holdDoc.data()?.settledByOrderId === scenario2OrderId;

    const pass =
      quote.ok &&
      quote.result.creditApplied === 300 &&
      order.ok &&
      orderFieldsOk &&
      holdSettled;
    results.scenario2_valid_hold_settles = pass
      ? `PASSED — quote creditApplied=${quote.result.creditApplied}, order.productCreditApplied=300, hold status=settled, settledByOrderId=${scenario2OrderId}`
      : `FAILED — quote=${JSON.stringify(quote)}, order=${JSON.stringify(order)}, hold=${JSON.stringify(holdDoc.data())}`;
    if (!pass) allPassed = false;

    const balAfterOrder = await getBalance(customerId);
    const pass3 = balAfterQuote.available === 0 && balAfterQuote.onHold === 300 &&
      balAfterOrder.available === balAfterQuote.available && balAfterOrder.onHold === 0;
    results.scenario3_ledger_arithmetic_corrected = pass3
      ? `PASSED — after quote: available=${balAfterQuote.available}, onHold=${balAfterQuote.onHold}; after settlement: available=${balAfterOrder.available} (unchanged), onHold=${balAfterOrder.onHold}`
      : `FAILED — afterQuote=${JSON.stringify(balAfterQuote)}, afterOrder=${JSON.stringify(balAfterOrder)}`;
    if (!pass3) allPassed = false;
  }

  // ============================================================
  // Scenario 4: reusing the SAME (now-settled) holdId a second time is
  // rejected — the double-spend guard.
  // ============================================================
  {
    const r = await callAndCapture(
      wrappedCreateOrder,
      {
        items: [{ productId: "phaseD-red-p2", quantity: 1 }],
        orderMode: "B2C",
        paymentMethod: "cod",
        productCreditHoldId: scenario2HoldId,
      },
      auth(scenario2CustomerId)
    );
    const pass = !r.ok && r.code === "failed-precondition";
    results.scenario4_double_spend_rejected = pass
      ? `PASSED — reusing settled hold ${scenario2HoldId} rejected: code=${r.code}, message="${r.message}"`
      : `FAILED — ${JSON.stringify(r)}`;
    if (!pass) allPassed = false;
  }

  // ============================================================
  // Scenario 5: another user's holdId is rejected permission-denied.
  // ============================================================
  {
    const ownerId = "phaseD-red-c5owner";
    const attackerId = "phaseD-red-c5attacker";
    await seedUser(ownerId);
    await seedUser(attackerId);
    await seedProduct("phaseD-red-p5", 400, "phaseD-red-seller5");
    await seedProgram("phaseD-red-prog5", {});
    await seedEnrollment("phaseD-red-enroll5", ownerId, "phaseD-red-prog5");
    await approveComplianceAndFlags({ redemptionEnabled: true });
    await seedBalance(ownerId, 100);

    const quote = await callAndCapture(
      wrappedQuote,
      { items: [{ productId: "phaseD-red-p5", quantity: 1 }], orderMode: "B2C" },
      auth(ownerId)
    );
    const holdId = quote.result?.holdId;

    const r = await callAndCapture(
      wrappedCreateOrder,
      {
        items: [{ productId: "phaseD-red-p5", quantity: 1 }],
        orderMode: "B2C",
        paymentMethod: "cod",
        productCreditHoldId: holdId,
      },
      auth(attackerId)
    );
    const pass = quote.ok && !!holdId && !r.ok && r.code === "permission-denied";
    results.scenario5_other_users_hold_rejected = pass
      ? `PASSED — attacker rejected with code=${r.code}, message="${r.message}"`
      : `FAILED — quote=${JSON.stringify(quote)}, order=${JSON.stringify(r)}`;
    if (!pass) allPassed = false;
  }

  // ============================================================
  // Scenario 6: an expired hold is rejected.
  // ============================================================
  {
    const customerId = "phaseD-red-c6";
    await seedUser(customerId);
    await seedProduct("phaseD-red-p6", 250, "phaseD-red-seller6");

    const expiredHoldId = "phaseD-red-expiredhold6";
    await db.collection("product_credit_holds").doc(expiredHoldId).set({
      id: expiredHoldId,
      customerId,
      enrollmentId: "phaseD-red-enroll6",
      amount: 100,
      status: "active",
      ledgerEntryId: null,
      cartFingerprint: "irrelevant-for-this-scenario",
      quotedTotal: 250,
      quotedPayable: 150,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() - 60000),
      releasedAt: null,
      settledAt: null,
    });

    const r = await callAndCapture(
      wrappedCreateOrder,
      {
        items: [{ productId: "phaseD-red-p6", quantity: 1 }],
        orderMode: "B2C",
        paymentMethod: "cod",
        productCreditHoldId: expiredHoldId,
      },
      auth(customerId)
    );
    const pass = !r.ok && r.code === "failed-precondition";
    results.scenario6_expired_hold_rejected = pass
      ? `PASSED — expired hold rejected: code=${r.code}, message="${r.message}"`
      : `FAILED — ${JSON.stringify(r)}`;
    if (!pass) allPassed = false;

    // Cleanup: createOrder correctly left this hold untouched (still
    // status:"active", expiresAt in the past — it never got a chance to
    // update it, since it rejected before any write). Left as-is, this
    // shared-emulator artifact would later be picked up by
    // phaseC_hold_test.js's expiry-sweep scenario (which sweeps ALL
    // expired active holds, not just its own) and crash it — this
    // customer has no product_credit_balances doc, so RELEASEing 100 into
    // a zeroed onHold goes negative and throws. Delete it now rather than
    // leaving that landmine for the next regression run.
    await db.collection("product_credit_holds").doc(expiredHoldId).delete();
  }

  // ============================================================
  // Scenario 7: cart changed after quote (fingerprint mismatch) is
  // rejected.
  // ============================================================
  {
    const customerId = "phaseD-red-c7";
    await seedUser(customerId);
    await seedProduct("phaseD-red-p7a", 500, "phaseD-red-seller7");
    await seedProduct("phaseD-red-p7b", 500, "phaseD-red-seller7");
    await seedProgram("phaseD-red-prog7", {});
    await seedEnrollment("phaseD-red-enroll7", customerId, "phaseD-red-prog7");
    await approveComplianceAndFlags({ redemptionEnabled: true });
    await seedBalance(customerId, 200);

    const quote = await callAndCapture(
      wrappedQuote,
      { items: [{ productId: "phaseD-red-p7a", quantity: 1 }], orderMode: "B2C" },
      auth(customerId)
    );
    const holdId = quote.result?.holdId;

    // Different product in the cart at order time -> fingerprint mismatch.
    const r = await callAndCapture(
      wrappedCreateOrder,
      {
        items: [{ productId: "phaseD-red-p7b", quantity: 1 }],
        orderMode: "B2C",
        paymentMethod: "cod",
        productCreditHoldId: holdId,
      },
      auth(customerId)
    );
    const pass = quote.ok && !!holdId && !r.ok && r.code === "failed-precondition";
    results.scenario7_cart_changed_fingerprint_mismatch = pass
      ? `PASSED — changed cart rejected: code=${r.code}, message="${r.message}"`
      : `FAILED — quote=${JSON.stringify(quote)}, order=${JSON.stringify(r)}`;
    if (!pass) allPassed = false;
  }

  // ============================================================
  // Scenario 8: non-COD payment amount must equal (total - creditApplied)
  // — a payment for the full total is rejected, a payment for the
  // discounted payable is accepted (reusing the same still-active hold).
  // ============================================================
  {
    const customerId = "phaseD-red-c8";
    await seedUser(customerId);
    await seedProduct("phaseD-red-p8", 1000, "phaseD-red-seller8");
    await seedProgram("phaseD-red-prog8", {});
    await seedEnrollment("phaseD-red-enroll8", customerId, "phaseD-red-prog8");
    await approveComplianceAndFlags({ redemptionEnabled: true });
    await seedBalance(customerId, 300);

    const quote = await callAndCapture(
      wrappedQuote,
      { items: [{ productId: "phaseD-red-p8", quantity: 1 }], orderMode: "B2C" },
      auth(customerId)
    );
    const holdId = quote.result?.holdId;
    const payable = quote.result?.payable; // expect 700

    await seedVerifiedPayment("phaseD-red-pay8a", {
      orderId: "phaseD-red-razorpayorder8a",
      userId: customerId,
      amount: quote.result.total, // WRONG: full total, not the discounted payable
    });
    const wrongAmountAttempt = await callAndCapture(
      wrappedCreateOrder,
      {
        items: [{ productId: "phaseD-red-p8", quantity: 1 }],
        orderMode: "B2C",
        paymentMethod: "razorpay",
        razorpayPaymentId: "phaseD-red-pay8a",
        razorpayOrderId: "phaseD-red-razorpayorder8a",
        productCreditHoldId: holdId,
      },
      auth(customerId)
    );

    await seedVerifiedPayment("phaseD-red-pay8b", {
      orderId: "phaseD-red-razorpayorder8b",
      userId: customerId,
      amount: payable, // correct
    });
    const correctAmountAttempt = await callAndCapture(
      wrappedCreateOrder,
      {
        items: [{ productId: "phaseD-red-p8", quantity: 1 }],
        orderMode: "B2C",
        paymentMethod: "razorpay",
        razorpayPaymentId: "phaseD-red-pay8b",
        razorpayOrderId: "phaseD-red-razorpayorder8b",
        productCreditHoldId: holdId,
      },
      auth(customerId)
    );

    let orderPaid = false;
    if (correctAmountAttempt.ok) {
      const orderDoc = await db.collection("orders").doc(correctAmountAttempt.result.orders[0].orderId).get();
      orderPaid = orderDoc.data().paymentStatus === "paid" && orderDoc.data().productCreditApplied === 300;
    }

    const pass =
      quote.ok &&
      payable === 700 &&
      !wrongAmountAttempt.ok &&
      wrongAmountAttempt.code === "failed-precondition" &&
      correctAmountAttempt.ok &&
      orderPaid;
    results.scenario8_payment_amount_must_match_payable = pass
      ? `PASSED — full-total payment rejected (code=${wrongAmountAttempt.code}); discounted payable=${payable} payment accepted, order paymentStatus=paid, productCreditApplied=300`
      : `FAILED — quote=${JSON.stringify(quote)}, wrong=${JSON.stringify(wrongAmountAttempt)}, correct=${JSON.stringify(correctAmountAttempt)}`;
    if (!pass) allPassed = false;
  }

  // ============================================================
  // Scenario 9: COD order with credit -> succeeds, paymentStatus 'pending',
  // credit still applied.
  // ============================================================
  {
    const customerId = "phaseD-red-c9";
    await seedUser(customerId);
    await seedProduct("phaseD-red-p9", 500, "phaseD-red-seller9");
    await seedProgram("phaseD-red-prog9", {});
    await seedEnrollment("phaseD-red-enroll9", customerId, "phaseD-red-prog9");
    await approveComplianceAndFlags({ redemptionEnabled: true });
    await seedBalance(customerId, 200);

    const quote = await callAndCapture(
      wrappedQuote,
      { items: [{ productId: "phaseD-red-p9", quantity: 1 }], orderMode: "B2C" },
      auth(customerId)
    );
    const holdId = quote.result?.holdId;

    const order = await callAndCapture(
      wrappedCreateOrder,
      {
        items: [{ productId: "phaseD-red-p9", quantity: 1 }],
        orderMode: "B2C",
        paymentMethod: "cod",
        productCreditHoldId: holdId,
      },
      auth(customerId)
    );

    let fieldsOk = false;
    if (order.ok) {
      const orderDoc = await db.collection("orders").doc(order.result.orders[0].orderId).get();
      const data = orderDoc.data();
      fieldsOk = data.paymentStatus === "pending" && data.productCreditApplied === 200;
    }
    const pass = quote.ok && !!holdId && order.ok && fieldsOk;
    results.scenario9_cod_with_credit = pass
      ? `PASSED — COD order created with paymentStatus=pending, productCreditApplied=200`
      : `FAILED — quote=${JSON.stringify(quote)}, order=${JSON.stringify(order)}`;
    if (!pass) allPassed = false;
  }

  // ============================================================
  // Scenario 10: credit >= total -> payable 0, no Razorpay payment
  // required, order settles as fully credit-paid.
  // ============================================================
  {
    const customerId = "phaseD-red-c10";
    await seedUser(customerId);
    await seedProduct("phaseD-red-p10", 100, "phaseD-red-seller10");
    await seedProgram("phaseD-red-prog10", {});
    await seedEnrollment("phaseD-red-enroll10", customerId, "phaseD-red-prog10");
    await approveComplianceAndFlags({ redemptionEnabled: true });
    await seedBalance(customerId, 5000); // far more than the 100 order

    const quote = await callAndCapture(
      wrappedQuote,
      { items: [{ productId: "phaseD-red-p10", quantity: 1 }], orderMode: "B2C" },
      auth(customerId)
    );
    const holdId = quote.result?.holdId;

    // No razorpayPaymentId/razorpayOrderId supplied at all — must still
    // succeed because the hold covers the entire order.
    const order = await callAndCapture(
      wrappedCreateOrder,
      {
        items: [{ productId: "phaseD-red-p10", quantity: 1 }],
        orderMode: "B2C",
        paymentMethod: "razorpay",
        productCreditHoldId: holdId,
      },
      auth(customerId)
    );

    let fieldsOk = false;
    if (order.ok) {
      const orderDoc = await db.collection("orders").doc(order.result.orders[0].orderId).get();
      const data = orderDoc.data();
      fieldsOk = data.paymentStatus === "paid" && data.productCreditApplied === 100 && data.total === 100;
    }
    const pass = quote.ok && quote.result.payable === 0 && quote.result.creditApplied === 100 && order.ok && fieldsOk;
    results.scenario10_credit_covers_full_order = pass
      ? `PASSED — payable=0, no payment required, order paymentStatus=paid, productCreditApplied=100`
      : `FAILED — quote=${JSON.stringify(quote)}, order=${JSON.stringify(order)}`;
    if (!pass) allPassed = false;
  }

  // ============================================================
  // Scenario 11: multi-seller cart -> per-seller productCreditApplied
  // values sum EXACTLY to the hold amount.
  // ============================================================
  {
    const customerId = "phaseD-red-c11";
    await seedUser(customerId);
    await seedProduct("phaseD-red-p11a", 600, "phaseD-red-seller11a");
    await seedProduct("phaseD-red-p11b", 400, "phaseD-red-seller11b");
    await seedProgram("phaseD-red-prog11", {});
    await seedEnrollment("phaseD-red-enroll11", customerId, "phaseD-red-prog11");
    await approveComplianceAndFlags({ redemptionEnabled: true });
    await seedBalance(customerId, 1000); // covers the full 1000 cart

    const items = [
      { productId: "phaseD-red-p11a", quantity: 1 },
      { productId: "phaseD-red-p11b", quantity: 1 },
    ];
    const quote = await callAndCapture(wrappedQuote, { items, orderMode: "B2C" }, auth(customerId));
    const holdId = quote.result?.holdId;

    const order = await callAndCapture(
      wrappedCreateOrder,
      { items, orderMode: "B2C", paymentMethod: "razorpay", productCreditHoldId: holdId },
      auth(customerId)
    );

    let sharesSumExactly = false;
    let shareDetails = null;
    if (order.ok && order.result.orders.length === 2) {
      const docs = await Promise.all(
        order.result.orders.map((o) => db.collection("orders").doc(o.orderId).get())
      );
      const shares = docs.map((d) => d.data().productCreditApplied);
      const sum = roundMoney(shares.reduce((a, b) => a + b, 0));
      sharesSumExactly = sum === quote.result.creditApplied;
      shareDetails = shares;
    }
    const pass =
      quote.ok &&
      quote.result.creditApplied === 1000 &&
      order.ok &&
      order.result.orders.length === 2 &&
      sharesSumExactly;
    results.scenario11_multiseller_shares_sum_exactly = pass
      ? `PASSED — 2 orders created, per-seller shares=${JSON.stringify(shareDetails)} sum exactly to creditApplied=${quote.result.creditApplied}`
      : `FAILED — quote=${JSON.stringify(quote)}, order=${JSON.stringify(order)}, shares=${JSON.stringify(shareDetails)}`;
    if (!pass) allPassed = false;
  }

  // ============================================================
  // Scenario 12: redemption flag disabled after the hold was taken ->
  // order with a holdId is rejected, NOT silently created at full price.
  // ============================================================
  {
    const customerId = "phaseD-red-c12";
    await seedUser(customerId);
    await seedProduct("phaseD-red-p12", 300, "phaseD-red-seller12");
    await seedProgram("phaseD-red-prog12", {});
    await seedEnrollment("phaseD-red-enroll12", customerId, "phaseD-red-prog12");
    await approveComplianceAndFlags({ redemptionEnabled: true });
    await seedBalance(customerId, 300);

    const quote = await callAndCapture(
      wrappedQuote,
      { items: [{ productId: "phaseD-red-p12", quantity: 1 }], orderMode: "B2C" },
      auth(customerId)
    );
    const holdId = quote.result?.holdId;

    // Flip the redemption flag off WITHOUT touching the hold itself.
    await approveComplianceAndFlags({ redemptionEnabled: false });

    const order = await callAndCapture(
      wrappedCreateOrder,
      {
        items: [{ productId: "phaseD-red-p12", quantity: 1 }],
        orderMode: "B2C",
        paymentMethod: "cod",
        productCreditHoldId: holdId,
      },
      auth(customerId)
    );
    const pass = quote.ok && !!holdId && !order.ok && order.code === "failed-precondition";
    results.scenario12_gate_closed_rejects_not_fullprice = pass
      ? `PASSED — order with a holdId rejected once PRODUCT_CREDIT_REDEMPTION_ENABLED was flipped false: code=${order.code}, message="${order.message}"`
      : `FAILED — quote=${JSON.stringify(quote)}, order=${JSON.stringify(order)}`;
    if (!pass) allPassed = false;
  }

  console.log("=== PHASE D — REDEMPTION CUTOVER TEST ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);
  console.log(allPassed ? "\nALL PASSED" : "\nSOME FAILED");
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phaseD redemption test:", e);
  process.exit(1);
});
