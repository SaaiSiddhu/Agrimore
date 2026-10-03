// F3.3 security and provider-boundary tests for the distance quote callable.
// Run after `npm run build`:
//   firebase emulators:exec --only firestore --project demo-f3c-distance \
//     "node scripts/phaseFOUNDATION10_distance_quote_test.js"
// The Maps request is replaced with a local fake; this suite never contacts Google.

process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "demo-f3c-distance";
process.env.GOOGLE_ROUTES_API_KEY = "synthetic-test-secret";

const assert = require("node:assert/strict");
const admin = require("firebase-admin");
admin.initializeApp({ projectId: "demo-f3c-distance" });
const test = require("firebase-functions-test")({ projectId: "demo-f3c-distance" });
const { quoteDeliveryFees } = require("../lib/customer/deliveryDistanceQuote");
const wrappedQuote = test.wrap(quoteDeliveryFees);
const { createOrder } = require("../lib/customer/createOrder");
const wrappedCreateOrder = test.wrap(createOrder);
const { createOrderFromRfq } = require("../lib/customer/createOrderFromRfq");
const wrappedCreateOrderFromRfq = test.wrap(createOrderFromRfq);
const { quoteOrderWithCredit } = require("../lib/customer/productCreditHold");
const wrappedCreditQuote = test.wrap(quoteOrderWithCredit);

let failures = 0;
let passed = 0;
let routeCalls = [];
global.fetch = async (url, options) => {
  routeCalls.push({ url, options });
  return { ok: true, json: async () => ({ routes: [{ distanceMeters: 5000 }] }) };
};

function check(label, condition, details) {
  if (condition) {
    passed++;
    console.log(`PASSED — ${label}`);
  } else {
    failures++;
    console.log(`FAILED — ${label}`);
    if (details !== undefined) console.log("  details:", JSON.stringify(details));
  }
}

async function expectCode(label, fn, code) {
  try {
    await fn();
    check(label, false, "expected callable error");
  } catch (error) {
    check(label, error.code === code, { actual: error.code, message: error.message });
  }
}

async function callAndCapture(fn, data, auth) {
  try {
    return { ok: true, result: await fn({ data, auth }) };
  } catch (error) {
    return { ok: false, code: error.code, message: error.message };
  }
}

async function seedSeller(id, extra = {}) {
  await admin.firestore().collection("sellers").doc(id).set({
    status: "approved",
    latitude: 12.9716,
    longitude: 77.5946,
    deliveryRadiusKm: 10,
    deliveryFeeSchedule: { type: "distance", baseFeePaise: 2500, ratePerKmPaise: 5000 },
    ...extra,
  });
}

async function seedProduct(id, sellerId) {
  await admin.firestore().collection("products").doc(id).set({ sellerId, stock: 10, salePrice: 50 });
}

async function seedAddress(id, userId, extra = {}) {
  await admin.firestore().collection("addresses").doc(id).set({
    userId,
    latitude: 12.99,
    longitude: 77.60,
    addressLine1: "Synthetic road",
    city: "Bengaluru",
    ...extra,
  });
}

async function quote(uid, addressId, productId) {
  return wrappedQuote({
    data: { addressId, items: [{ productId, quantity: 1 }] },
    auth: { uid, token: {} },
  });
}

async function main() {
  const db = admin.firestore();
  await seedAddress("f3c-address-a", "f3c-user-a");
  await seedSeller("f3c-seller-a");
  await seedProduct("f3c-product-a", "f3c-seller-a");
  routeCalls = [];

  const valid = await quote("f3c-user-a", "f3c-address-a", "f3c-product-a");
  check("authenticated owner receives a quote computed from server route distance", valid.deliveryCharge === 275 && !!valid.deliveryQuoteId, valid);
  check("route call uses server-only API and requests only distanceMeters", routeCalls.length === 1 && routeCalls[0].url === "https://routes.googleapis.com/directions/v2:computeRoutes" && routeCalls[0].options.headers["X-Goog-FieldMask"] === "routes.distanceMeters", routeCalls[0]);
  const routeBody = JSON.parse(routeCalls[0].options.body);
  check("route request uses driving distance without live traffic", routeBody.travelMode === "DRIVE" && routeBody.routingPreference === "TRAFFIC_UNAWARE", routeBody);
  const quoteDoc = await db.collection("delivery_fee_quotes").doc(valid.deliveryQuoteId).get();
  const quoteData = quoteDoc.data();
  check("client deadline exactly matches server quote expiry", valid.deliveryQuoteExpiresAtMs === quoteData.expiresAt.toMillis());
  check("quote is short-lived and contains no raw origin or destination coordinates", quoteData.expiresAt.toMillis() - quoteData.createdAt.toMillis() === 600000 && !JSON.stringify(quoteData).includes("12.9716") && !JSON.stringify(quoteData).includes("12.99"), quoteData);

  routeCalls = [];
  await expectCode("unauthenticated callers cannot obtain a quote", () => wrappedQuote({ data: { addressId: "f3c-address-a", items: [{ productId: "f3c-product-a", quantity: 1 }] } }), "unauthenticated");
  check("unauthenticated call makes no route request", routeCalls.length === 0);

  await seedAddress("f3c-address-other", "f3c-user-other");
  routeCalls = [];
  await expectCode("a caller cannot price against another customer's saved address", () => quote("f3c-user-a", "f3c-address-other", "f3c-product-a"), "permission-denied");
  check("foreign-address refusal makes no route request", routeCalls.length === 0);

  await seedAddress("f3c-address-no-coords", "f3c-user-no-coords", { latitude: "12.99", longitude: 77.6 });
  await seedSeller("f3c-seller-no-coords");
  await seedProduct("f3c-product-no-coords", "f3c-seller-no-coords");
  routeCalls = [];
  await expectCode("distance pricing refuses a missing or nonnumeric saved coordinate", () => quote("f3c-user-no-coords", "f3c-address-no-coords", "f3c-product-no-coords"), "failed-precondition");
  check("invalid destination refusal makes no route request", routeCalls.length === 0);

  await seedAddress("f3c-address-radius", "f3c-user-radius");
  await seedSeller("f3c-seller-radius", { deliveryRadiusKm: 4 });
  await seedProduct("f3c-product-radius", "f3c-seller-radius");
  routeCalls = [];
  await expectCode("server refuses a route beyond the seller's radius", () => quote("f3c-user-radius", "f3c-address-radius", "f3c-product-radius"), "failed-precondition");
  check("out-of-radius route is computed once and no quote is issued", routeCalls.length === 1 && (await db.collection("delivery_fee_quotes").where("uid", "==", "f3c-user-radius").get()).empty);

  await seedAddress("f3c-address-bad-schedule", "f3c-user-bad-schedule");
  await seedSeller("f3c-seller-bad-schedule", { deliveryFeeSchedule: { type: "distance", baseFeePaise: 2500, ratePerKmPaise: 0 } });
  await seedProduct("f3c-product-bad-schedule", "f3c-seller-bad-schedule");
  routeCalls = [];
  await expectCode("malformed distance schedule fails closed", () => quote("f3c-user-bad-schedule", "f3c-address-bad-schedule", "f3c-product-bad-schedule"), "failed-precondition");
  check("malformed schedule cannot fall back to client price or call Routes", routeCalls.length === 0);

  await seedSeller("f3c-seller-flat", { deliveryFeeSchedule: { type: "flat", amount: 20 } });
  await seedProduct("f3c-product-flat", "f3c-seller-flat");
  await seedAddress("f3c-address-flat", "f3c-user-flat");
  routeCalls = [];
  const noDistance = await quote("f3c-user-flat", "f3c-address-flat", "f3c-product-flat");
  check("flat seller receives a fee quote without requiring address coordinates or Maps", noDistance.deliveryCharge === 20 && !!noDistance.deliveryQuoteId && routeCalls.length === 0, noDistance);
  await db.collection("users").doc("f3c-user-flat").set({ uid: "f3c-user-flat", profileCompleted: true, role: "customer" });
  const flatOrder = await wrappedCreateOrder({
    data: {
      items: [{ productId: "f3c-product-flat", quantity: 1 }], orderMode: "B2C", paymentMethod: "cod",
      deliveryAddress: { id: "f3c-address-flat", latitude: 12.99, longitude: 77.6, name: "Test", phone: "9999999999" },
      deliveryCharge: 20, legacyDeliveryCharge: 0, deliveryQuoteId: noDistance.deliveryQuoteId,
    },
    auth: { uid: "f3c-user-flat", token: {} },
  });
  const flatOrderDoc = await db.collection("orders").doc(flatOrder.orders[0].orderId).get();
  check("flat quote is consumed by createOrder and its amount matches the stored order", flatOrderDoc.data().deliveryCharge === 20 && flatOrderDoc.data().deliveryQuoteId === noDistance.deliveryQuoteId);

  await seedAddress("f3c-address-mixed", "f3c-user-mixed");
  await seedSeller("f3c-seller-mixed-distance");
  await seedSeller("f3c-seller-mixed-flat", { deliveryFeeSchedule: { type: "flat", amount: 20 } });
  await seedProduct("f3c-product-mixed-distance", "f3c-seller-mixed-distance");
  await seedProduct("f3c-product-mixed-flat", "f3c-seller-mixed-flat");
  routeCalls = [];
  const mixed = await wrappedQuote({
    data: {
      addressId: "f3c-address-mixed", orderMode: "B2C", legacyDeliveryCharge: 40,
      items: [
        { productId: "f3c-product-mixed-distance", quantity: 1 },
        { productId: "f3c-product-mixed-flat", quantity: 1 },
      ],
    },
    auth: { uid: "f3c-user-mixed", token: {} },
  });
  check("mixed seller quote includes distance, flat, and only the applicable legacy fallback", mixed.deliveryCharge === 295 && !!mixed.deliveryQuoteId, mixed);
  const mixedQuote = (await db.collection("delivery_fee_quotes").doc(mixed.deliveryQuoteId).get()).data();
  check("mixed quote fingerprints every configured seller schedule and preserves legacy input separately", Object.keys(mixedQuote.scheduleFingerprints).length === 2 && mixedQuote.legacyDeliveryChargePaise === 4000);

  await seedAddress("f3c-address-parallel", "f3c-user-parallel");
  await seedSeller("f3c-seller-parallel-a");
  await seedSeller("f3c-seller-parallel-b", { latitude: 12.972, longitude: 77.595 });
  await seedProduct("f3c-product-parallel-a", "f3c-seller-parallel-a");
  await seedProduct("f3c-product-parallel-b", "f3c-seller-parallel-b");
  const originalFetch = global.fetch;
  let activeRoutes = 0;
  let peakActiveRoutes = 0;
  global.fetch = async () => {
    activeRoutes++;
    peakActiveRoutes = Math.max(peakActiveRoutes, activeRoutes);
    await new Promise((resolve) => setTimeout(resolve, 20));
    activeRoutes--;
    return { ok: true, json: async () => ({ routes: [{ distanceMeters: 5000 }] }) };
  };
  try {
    const parallel = await wrappedQuote({
      data: {
        addressId: "f3c-address-parallel", orderMode: "B2C",
        items: [
          { productId: "f3c-product-parallel-a", quantity: 1 },
          { productId: "f3c-product-parallel-b", quantity: 1 },
        ],
      },
      auth: { uid: "f3c-user-parallel", token: {} },
    });
    check("bounded multi-seller route lookups run concurrently and return both fees", peakActiveRoutes === 2 && parallel.sellerFees.length === 2, { peakActiveRoutes, sellerFees: parallel.sellerFees });
  } finally {
    global.fetch = originalFetch;
  }

  const creditUid = "f3c-user-credit-distance";
  await seedAddress("f3c-address-credit", creditUid);
  await seedSeller("f3c-seller-credit-distance");
  await seedProduct("f3c-product-credit-distance", "f3c-seller-credit-distance");
  await db.collection("compliance_config").doc("benefit_program").set({
    legalReviewStatus: "APPROVED", complianceApprovalStatus: "APPROVED",
  });
  await db.collection("feature_flags").doc("benefit_program").set({
    BENEFIT_PROGRAM_ENABLED: true, PRODUCT_CREDIT_REDEMPTION_ENABLED: true,
  });
  await db.collection("benefit_programs").doc("f3c-credit-program").set({
    status: "active", redemptionEnabled: true, minOrderValueForRedemption: 0,
    maxCreditPerOrder: null, maxCreditPercentOfOrder: null,
  });
  await db.collection("benefit_enrollments").doc("f3c-credit-enrollment").set({
    customerId: creditUid, programId: "f3c-credit-program", status: "active",
  });
  await db.collection("product_credit_balances").doc(creditUid).set({
    available: 30, pending: 0, onHold: 0, lifetimeEarned: 30, lifetimeUsed: 0, lifetimeExpired: 0,
  });
  await db.collection("users").doc(creditUid).set({ uid: creditUid, profileCompleted: true, role: "customer" });
  const creditDeliveryQuote = await quote(creditUid, "f3c-address-credit", "f3c-product-credit-distance");
  const creditRequest = {
    items: [{ productId: "f3c-product-credit-distance", quantity: 1 }],
    orderMode: "B2C", deliveryCharge: creditDeliveryQuote.deliveryCharge,
    legacyDeliveryCharge: 0, deliveryQuoteId: creditDeliveryQuote.deliveryQuoteId,
    deliveryAddress: { id: "f3c-address-credit", latitude: 12.99, longitude: 77.6 },
  };
  const creditResult = await wrappedCreditQuote({ data: creditRequest, auth: { uid: creditUid, token: {} } });
  const creditHoldRef = db.collection("product_credit_holds").doc(creditResult.holdId);
  const creditHold = (await creditHoldRef.get()).data();
  check("Product Credit quote uses server distance fee and binds its hold to the exact delivery quote", creditResult.total === 325 && creditResult.creditApplied === 30 && creditResult.deliveryQuoteId === creditDeliveryQuote.deliveryQuoteId && creditHold.deliveryQuoteId === creditDeliveryQuote.deliveryQuoteId, { creditResult, holdDeliveryQuoteId: creditHold.deliveryQuoteId });

  const wrongAddressCredit = await callAndCapture(wrappedCreditQuote, {
    ...creditRequest,
    deliveryAddress: { id: "f3c-address-other", latitude: 12.99, longitude: 77.6 },
  }, { uid: creditUid, token: {} });
  const activeCreditHoldAfterMismatch = await creditHoldRef.get();
  check("Product Credit rejects address mismatch before releasing or replacing the active hold", !wrongAddressCredit.ok && activeCreditHoldAfterMismatch.data().status === "active");

  const alternateCreditDeliveryQuote = await quote(creditUid, "f3c-address-credit", "f3c-product-credit-distance");
  const alternateCreditRequest = {
    ...creditRequest,
    deliveryCharge: alternateCreditDeliveryQuote.deliveryCharge,
    deliveryQuoteId: alternateCreditDeliveryQuote.deliveryQuoteId,
  };
  const alternateCreditResult = await wrappedCreditQuote({ data: alternateCreditRequest, auth: { uid: creditUid, token: {} } });
  const alternateCreditHoldRef = db.collection("product_credit_holds").doc(alternateCreditResult.holdId);
  const mismatchedQuoteOrder = await callAndCapture(wrappedCreateOrder, {
    ...alternateCreditRequest,
    deliveryQuoteId: creditDeliveryQuote.deliveryQuoteId,
    deliveryCharge: creditDeliveryQuote.deliveryCharge,
    paymentMethod: "cod", productCreditHoldId: alternateCreditResult.holdId,
  }, { uid: creditUid, token: {} });
  const quoteAfterHoldMismatch = (await db.collection("delivery_fee_quotes").doc(creditDeliveryQuote.deliveryQuoteId).get()).data();
  const alternateQuoteAfterHoldMismatch = (await db.collection("delivery_fee_quotes").doc(alternateCreditDeliveryQuote.deliveryQuoteId).get()).data();
  check("createOrder rejects a Product Credit hold paired with another valid delivery quote without consuming either", !mismatchedQuoteOrder.ok && (await alternateCreditHoldRef.get()).data().status === "active" && quoteAfterHoldMismatch.consumedAt == null && alternateQuoteAfterHoldMismatch.consumedAt == null);

  // A provider can capture while the app is backgrounded. Neither expiry
  // refusal may consume that payment or partially mutate the economic state.
  // This proves safety, not successful recovery/refund of an expired checkout.
  const prepaidPaymentId = "pay_f3c_credit_expiry";
  const prepaidOrderId = "order_f3c_credit_expiry";
  await db.collection("verified_payments").doc(prepaidPaymentId).set({
    paymentId: prepaidPaymentId, orderId: prepaidOrderId, userId: creditUid,
    amount: 295, amountPaise: 29500, currency: "INR", status: "captured",
    signatureVerified: true, purpose: "goods_checkout", consumedByOrderId: null,
  });
  const prepaidCreditRequest = {
    ...alternateCreditRequest, paymentMethod: "razorpay",
    productCreditHoldId: alternateCreditResult.holdId,
    razorpayPaymentId: prepaidPaymentId, razorpayOrderId: prepaidOrderId,
  };
  async function creditEconomicState() {
    const [hold, projection, product, payment, deliveryQuote, orders, ledger] = await Promise.all([
      alternateCreditHoldRef.get(), db.collection("product_credit_balances").doc(creditUid).get(),
      db.collection("products").doc("f3c-product-credit-distance").get(),
      db.collection("verified_payments").doc(prepaidPaymentId).get(),
      db.collection("delivery_fee_quotes").doc(alternateCreditDeliveryQuote.deliveryQuoteId).get(),
      db.collection("orders").where("userId", "==", creditUid).get(),
      db.collection("product_credit_ledger").where("customerId", "==", creditUid).get(),
    ]);
    return JSON.stringify({ hold: hold.data(), balance: projection.data(), stock: product.data().stock,
      payment: payment.data(), deliveryQuote: deliveryQuote.data(),
      orders: orders.docs.map((d) => d.id).sort(), ledger: ledger.docs.map((d) => d.id).sort() });
  }
  const holdExpiry = (await alternateCreditHoldRef.get()).data().expiresAt;
  await alternateCreditHoldRef.update({ expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() - 1000) });
  const beforeHoldExpiry = await creditEconomicState();
  const expiredHoldOrder = await callAndCapture(wrappedCreateOrder, prepaidCreditRequest, { uid: creditUid, token: {} });
  check("captured prepaid order refuses an expired credit hold specifically", !expiredHoldOrder.ok && expiredHoldOrder.code === "failed-precondition" && expiredHoldOrder.message.includes("hold has expired"), expiredHoldOrder);
  check("expired credit hold leaves captured payment, balance, stock, quote and ledger untouched", beforeHoldExpiry === await creditEconomicState());
  await alternateCreditHoldRef.update({ expiresAt: holdExpiry });

  const deliveryQuoteRef = db.collection("delivery_fee_quotes").doc(alternateCreditDeliveryQuote.deliveryQuoteId);
  const deliveryExpiry = (await deliveryQuoteRef.get()).data().expiresAt;
  await deliveryQuoteRef.update({ expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() - 1000) });
  const beforeQuoteExpiry = await creditEconomicState();
  const expiredDeliveryOrder = await callAndCapture(wrappedCreateOrder, prepaidCreditRequest, { uid: creditUid, token: {} });
  check("captured prepaid order refuses expired delivery pricing specifically", !expiredDeliveryOrder.ok && expiredDeliveryOrder.code === "failed-precondition" && expiredDeliveryOrder.message.includes("pricing changed or expired"), expiredDeliveryOrder);
  check("expired delivery quote leaves captured payment, balance, stock, hold and ledger untouched", beforeQuoteExpiry === await creditEconomicState());
  await deliveryQuoteRef.update({ expiresAt: deliveryExpiry });

  const creditOrder = await wrappedCreateOrder({
    data: {
      ...prepaidCreditRequest,
      deliveryAddress: { ...alternateCreditRequest.deliveryAddress, name: "Test", phone: "9999999999" },
    },
    auth: { uid: creditUid, token: {} },
  });
  const creditOrderDoc = await db.collection("orders").doc(creditOrder.orders[0].orderId).get();
  check("Product Credit order settles the quote-bound hold and consumes that same distance quote", creditOrderDoc.data().deliveryCharge === 275 && creditOrderDoc.data().deliveryQuoteId === alternateCreditDeliveryQuote.deliveryQuoteId && (await alternateCreditHoldRef.get()).data().status === "settled" && (await db.collection("delivery_fee_quotes").doc(alternateCreditDeliveryQuote.deliveryQuoteId).get()).data().consumedAt != null);
  check("valid prepaid credit checkout consumes the captured payment exactly once", (await db.collection("verified_payments").doc(prepaidPaymentId).get()).data().consumedByOrderId === creditOrder.orders[0].orderId && creditOrderDoc.data().paymentStatus === "paid");

  const replayedCreditQuote = await callAndCapture(wrappedCreditQuote, alternateCreditRequest, { uid: creditUid, token: {} });
  check("Product Credit cannot create a new hold from a delivery quote already consumed by an order", !replayedCreditQuote.ok && (await db.collection("product_credit_holds").where("customerId", "==", creditUid).where("status", "==", "active").get()).empty);

  const checkoutUid = "f3c-user-atomic-checkout";
  await db.collection("users").doc(checkoutUid).set({ uid: checkoutUid, profileCompleted: true, role: "customer" });
  await seedAddress("f3c-address-atomic", checkoutUid);
  await seedSeller("f3c-seller-atomic");
  await seedProduct("f3c-product-atomic", "f3c-seller-atomic");
  const atomicQuote = await quote(checkoutUid, "f3c-address-atomic", "f3c-product-atomic");
  const orderRequest = {
    data: {
      items: [{ productId: "f3c-product-atomic", quantity: 1 }],
      orderMode: "B2C", paymentMethod: "cod",
      deliveryAddress: { id: "f3c-address-atomic", latitude: 12.99, longitude: 77.6, name: "Test", phone: "9999999999" },
      deliveryCharge: atomicQuote.deliveryCharge, legacyDeliveryCharge: 0,
      deliveryQuoteId: atomicQuote.deliveryQuoteId,
    },
    auth: { uid: checkoutUid, token: {} },
  };
  const created = await wrappedCreateOrder(orderRequest);
  const createdOrder = await db.collection("orders").doc(created.orders[0].orderId).get();
  check("createOrder validates the quote and records the same authoritative distance fee", createdOrder.data().deliveryCharge === 275 && createdOrder.data().deliveryQuoteId === atomicQuote.deliveryQuoteId, createdOrder.data());
  await expectCode("a consumed route quote cannot fund a second order", () => wrappedCreateOrder(orderRequest), "failed-precondition");

  const changedAddressRequest = { ...orderRequest, data: { ...orderRequest.data, deliveryAddress: { ...orderRequest.data.deliveryAddress, latitude: 13.1 } } };
  const freshQuote = await quote(checkoutUid, "f3c-address-atomic", "f3c-product-atomic");
  await expectCode("order rejects a route quote when submitted delivery coordinates differ", () => wrappedCreateOrder({
    ...changedAddressRequest,
    data: { ...changedAddressRequest.data, deliveryQuoteId: freshQuote.deliveryQuoteId, deliveryCharge: freshQuote.deliveryCharge },
  }), "failed-precondition");
  const addressEditQuote = await quote(checkoutUid, "f3c-address-atomic", "f3c-product-atomic");
  await db.collection("addresses").doc("f3c-address-atomic").update({ latitude: 13.2 });
  await expectCode("order rejects a quote after the saved address coordinates change", () => wrappedCreateOrder({
    ...orderRequest,
    data: { ...orderRequest.data, deliveryQuoteId: addressEditQuote.deliveryQuoteId, deliveryCharge: addressEditQuote.deliveryCharge },
  }), "failed-precondition");

  const rfqUid = "f3c-user-distance-rfq";
  await db.collection("users").doc(rfqUid).set({ uid: rfqUid, profileCompleted: true, role: "customer" });
  await seedAddress("f3c-address-rfq", rfqUid);
  await seedSeller("f3c-seller-rfq");
  await seedProduct("f3c-product-rfq", "f3c-seller-rfq");
  await db.collection("rfqs").doc("f3c-rfq-order").set({
    buyerId: rfqUid, sellerId: "f3c-seller-rfq", productId: "f3c-product-rfq",
    status: "accepted", finalPrice: 75, finalQuantity: 2,
  });
  const rfqQuote = await wrappedQuote({
    data: { addressId: "f3c-address-rfq", orderMode: "B2C", legacyDeliveryCharge: 0, rfqId: "f3c-rfq-order", items: [{ productId: "f3c-product-rfq", quantity: 2 }] },
    auth: { uid: rfqUid, token: {} },
  });
  const rfqOrderRequest = {
    data: {
      rfqId: "f3c-rfq-order", productId: "f3c-product-rfq", quantity: 2,
      deliveryAddress: { id: "f3c-address-rfq", latitude: 12.99, longitude: 77.6, name: "Test", phone: "9999999999" },
      deliveryCharge: rfqQuote.deliveryCharge, legacyDeliveryCharge: 0, deliveryQuoteId: rfqQuote.deliveryQuoteId,
    },
    auth: { uid: rfqUid, token: {} },
  };
  const rfqResult = await wrappedCreateOrderFromRfq(rfqOrderRequest);
  const rfqOrder = await db.collection("orders").doc(rfqResult.orderId).get();
  check("accepted RFQ uses its locked negotiated quantity and atomically consumes the distance quote", rfqOrder.data().deliveryCharge === 275 && rfqOrder.data().deliveryQuoteId === rfqQuote.deliveryQuoteId);
  await expectCode("accepted RFQ and its route quote cannot be reused", () => wrappedCreateOrderFromRfq(rfqOrderRequest), "failed-precondition");

  const limitUser = "f3c-user-rate-limit";
  await seedAddress("f3c-address-rate-limit", limitUser);
  await seedSeller("f3c-seller-rate-limit");
  await seedProduct("f3c-product-rate-limit", "f3c-seller-rate-limit");
  routeCalls = [];
  for (let i = 0; i < 3; i++) await quote(limitUser, "f3c-address-rate-limit", "f3c-product-rate-limit");
  await expectCode("per-user rate limit blocks excess billable quotes", () => quote(limitUser, "f3c-address-rate-limit", "f3c-product-rate-limit"), "resource-exhausted");
  check("rate limit is claimed before provider work", routeCalls.length === 3, { routeCalls: routeCalls.length });

  console.log(`\n=== ${passed} passed; ${failures} failed ===`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((error) => {
  console.error("FATAL — distance quote test crashed:", error);
  process.exit(1);
});
