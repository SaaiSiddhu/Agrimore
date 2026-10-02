// Phase RFQ-3: proves createOrderFromRfq against a real emulator — the
// properties this callable's own design claims: one-time consumption
// (double-spend), price substitution (the RFQ's finalPrice is used, never
// the product's own catalogue price), cross-user/role rejection, item/
// quantity-mismatch rejection, and that it participates in the same
// profile-completeness/stock/payment/rate-limit controls createOrder.ts
// itself enforces.
// Run with: node scripts/phase40_createorder_from_rfq_test.js
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { createOrderFromRfq } = require("../lib/customer/createOrderFromRfq");

const wrapped = test.wrap(createOrderFromRfq);

async function call(payload, auth) {
  try {
    const result = await wrapped({ data: payload, auth });
    return { ok: true, result };
  } catch (e) {
    return { ok: false, code: e.code, message: e.message };
  }
}

async function main() {
  const db = admin.firestore();
  let allPassed = true;
  const results = {};

  console.log("=== PHASE RFQ-3 — createOrderFromRfq ===");

  async function seedUser(uid, { profileCompleted = true } = {}) {
    await db.collection("users").doc(uid).set({ uid, profileCompleted });
  }

  async function seedProduct(productId, sellerId, { stock = 1000, catalogPrice = 999, ...state } = {}) {
    // catalogPrice is deliberately far from any RFQ finalPrice used below —
    // if the callable ever used this instead of the RFQ's own locked price,
    // the price-substitution scenario would catch it immediately.
    await db.collection("products").doc(productId).set({
      name: `Test Product ${productId}`,
      sellerId,
      isB2BEnabled: true,
      salePrice: catalogPrice,
      b2bPrice: catalogPrice,
      b2bMoq: 1,
      stock,
      images: [],
      ...state,
    });
  }

  async function seedAcceptedRfq(rfqId, { buyerId, sellerId, productId, finalPrice, finalQuantity }) {
    await db.collection("rfqs").doc(rfqId).set({
      buyerId,
      sellerId,
      productId,
      status: "accepted",
      awaitingResponseFrom: null,
      finalPrice,
      finalQuantity,
      lastOffer: { price: finalPrice, quantity: finalQuantity, by: "seller", notes: null },
      history: [],
    });
  }

  const BUYER = "phase40-buyer";
  const SELLER = "phase40-seller";
  const STRANGER = "phase40-stranger";

  await seedUser(BUYER);
  await seedUser(STRANGER);

  // Scenario 1: unauthenticated call is rejected.
  {
    const r = await call({ rfqId: "x", productId: "x", quantity: 1 }, undefined);
    const s = !r.ok && r.code === "unauthenticated" ? "PASSED" : `FAILED — ${JSON.stringify(r)}`;
    results.scenario1_unauthenticated = s;
    if (s !== "PASSED") allPassed = false;
    console.log("Scenario 1:", s);
  }

  // Scenario 2: a non-existent rfqId is rejected.
  {
    const r = await call(
      { rfqId: "phase40-does-not-exist", productId: "x", quantity: 1 },
      { uid: BUYER, token: {} }
    );
    const s = !r.ok && r.code === "not-found" ? "PASSED" : `FAILED — ${JSON.stringify(r)}`;
    results.scenario2_rfq_not_found = s;
    if (s !== "PASSED") allPassed = false;
    console.log("Scenario 2:", s);
  }

  // Scenario 3: a stranger (not the RFQ's buyerId) cannot consume it —
  // role derived from the RFQ's own stored buyerId, never a client claim.
  const PRODUCT = "phase40-product-1";
  const RFQ_ID = "phase40-rfq-1";
  {
    await seedProduct(PRODUCT, SELLER);
    await seedAcceptedRfq(RFQ_ID, {
      buyerId: BUYER,
      sellerId: SELLER,
      productId: PRODUCT,
      finalPrice: 42,
      finalQuantity: 5,
    });
    const r = await call(
      { rfqId: RFQ_ID, productId: PRODUCT, quantity: 5, paymentMethod: "cod" },
      { uid: STRANGER, token: {} }
    );
    const s = !r.ok && r.code === "permission-denied" ? "PASSED" : `FAILED — ${JSON.stringify(r)}`;
    results.scenario3_stranger_denied = s;
    if (s !== "PASSED") allPassed = false;
    console.log("Scenario 3:", s);
  }

  // Scenario 4: an RFQ that is not yet accepted (still pending) is rejected.
  const RFQ_PENDING = "phase40-rfq-pending";
  {
    await db.collection("rfqs").doc(RFQ_PENDING).set({
      buyerId: BUYER,
      sellerId: SELLER,
      productId: PRODUCT,
      status: "pending",
      finalPrice: null,
      finalQuantity: null,
    });
    const r = await call(
      { rfqId: RFQ_PENDING, productId: PRODUCT, quantity: 5, paymentMethod: "cod" },
      { uid: BUYER, token: {} }
    );
    const s =
      !r.ok && r.code === "failed-precondition" && /not accepted/i.test(r.message)
        ? "PASSED"
        : `FAILED — ${JSON.stringify(r)}`;
    results.scenario4_not_accepted_rejected = s;
    if (s !== "PASSED") allPassed = false;
    console.log("Scenario 4:", s);
  }

  // Scenario 5: item mismatch — a different productId than the RFQ's own
  // locked productId is rejected, even though the RFQ itself is valid.
  {
    const otherProduct = "phase40-product-other";
    await seedProduct(otherProduct, SELLER);
    const r = await call(
      { rfqId: RFQ_ID, productId: otherProduct, quantity: 5, paymentMethod: "cod" },
      { uid: BUYER, token: {} }
    );
    const s =
      !r.ok && r.code === "failed-precondition" && /does not match/i.test(r.message)
        ? "PASSED"
        : `FAILED — ${JSON.stringify(r)}`;
    results.scenario5_product_mismatch_rejected = s;
    if (s !== "PASSED") allPassed = false;
    console.log("Scenario 5:", s);
  }

  // Scenario 6: quantity mismatch — a different quantity than the RFQ's own
  // locked finalQuantity is rejected.
  {
    const r = await call(
      { rfqId: RFQ_ID, productId: PRODUCT, quantity: 999, paymentMethod: "cod" },
      { uid: BUYER, token: {} }
    );
    const s =
      !r.ok && r.code === "failed-precondition" && /quantity does not match/i.test(r.message)
        ? "PASSED"
        : `FAILED — ${JSON.stringify(r)}`;
    results.scenario6_quantity_mismatch_rejected = s;
    if (s !== "PASSED") allPassed = false;
    console.log("Scenario 6:", s);
  }

  // Scenario 7: profile-incomplete buyer is rejected.
  const INCOMPLETE_BUYER = "phase40-buyer-incomplete";
  const RFQ_INCOMPLETE = "phase40-rfq-incomplete";
  {
    await seedUser(INCOMPLETE_BUYER, { profileCompleted: false });
    await seedAcceptedRfq(RFQ_INCOMPLETE, {
      buyerId: INCOMPLETE_BUYER,
      sellerId: SELLER,
      productId: PRODUCT,
      finalPrice: 42,
      finalQuantity: 5,
    });
    const r = await call(
      { rfqId: RFQ_INCOMPLETE, productId: PRODUCT, quantity: 5, paymentMethod: "cod" },
      { uid: INCOMPLETE_BUYER, token: {} }
    );
    const s =
      !r.ok && r.code === "failed-precondition" && /complete your profile/i.test(r.message)
        ? "PASSED"
        : `FAILED — ${JSON.stringify(r)}`;
    results.scenario7_incomplete_profile_rejected = s;
    if (s !== "PASSED") allPassed = false;
    console.log("Scenario 7:", s);
  }

  // Scenario 8: insufficient stock is rejected — the RFQ's own locked
  // finalQuantity is enforced against real stock, not silently bypassed.
  const RFQ_LOWSTOCK = "phase40-rfq-lowstock";
  const PRODUCT_LOWSTOCK = "phase40-product-lowstock";
  {
    await seedProduct(PRODUCT_LOWSTOCK, SELLER, { stock: 2 });
    await seedAcceptedRfq(RFQ_LOWSTOCK, {
      buyerId: BUYER,
      sellerId: SELLER,
      productId: PRODUCT_LOWSTOCK,
      finalPrice: 42,
      finalQuantity: 5,
    });
    const r = await call(
      { rfqId: RFQ_LOWSTOCK, productId: PRODUCT_LOWSTOCK, quantity: 5, paymentMethod: "cod" },
      { uid: BUYER, token: {} }
    );
    const s =
      !r.ok && r.code === "failed-precondition" && /enough stock/i.test(r.message)
        ? "PASSED"
        : `FAILED — ${JSON.stringify(r)}`;
    results.scenario8_insufficient_stock_rejected = s;
    if (s !== "PASSED") allPassed = false;
    console.log("Scenario 8:", s);
  }

  // Scenario 9: non-COD with no Razorpay details is rejected.
  {
    const r = await call(
      { rfqId: RFQ_ID, productId: PRODUCT, quantity: 5, paymentMethod: "razorpay" },
      { uid: BUYER, token: {} }
    );
    const s = !r.ok && r.code === "invalid-argument" ? "PASSED" : `FAILED — ${JSON.stringify(r)}`;
    results.scenario9_missing_payment_details_rejected = s;
    if (s !== "PASSED") allPassed = false;
    console.log("Scenario 9:", s);
  }

  // Scenario 10 — THE core property: successful COD conversion prices the
  // order at the RFQ's own finalPrice (42), never the product's catalogue
  // price (999, seeded deliberately far away) — real price substitution,
  // not merely a passing compile.
  let createdOrderId;
  {
    const r = await call(
      { rfqId: RFQ_ID, productId: PRODUCT, quantity: 5, paymentMethod: "cod", deliveryAddress: { name: "T", phone: "9999999999" } },
      { uid: BUYER, token: {} }
    );
    let s;
    try {
      if (!r.ok) throw new Error(`expected success, got ${JSON.stringify(r)}`);
      createdOrderId = r.result.orderId;
      const orderSnap = await db.collection("orders").doc(createdOrderId).get();
      const order = orderSnap.data();
      if (order.sellerId !== SELLER) throw new Error(`sellerId mismatch: ${order.sellerId}`);
      if (order.orderMode !== "B2B") throw new Error(`expected orderMode B2B, got ${order.orderMode}`);
      if (order.employeeUid !== null || order.employeeCode !== null) {
        throw new Error("RFQ order must never carry Sales Associate attribution");
      }
      if (order.rfqId !== RFQ_ID) throw new Error(`rfqId not recorded on order: ${order.rfqId}`);
      if (order.items.length !== 1 || order.items[0].price !== 42 || order.items[0].quantity !== 5) {
        throw new Error(`PRICE SUBSTITUTION FAILED — expected price=42 qty=5, got ${JSON.stringify(order.items)}`);
      }
      if (order.total !== 210) throw new Error(`expected total=210 (42x5), got ${order.total}`);
      const rfqSnap = await db.collection("rfqs").doc(RFQ_ID).get();
      if (rfqSnap.data().consumedByOrderId !== createdOrderId) {
        throw new Error("rfqs/{rfqId}.consumedByOrderId was not set to the new order's id");
      }
      const productSnap = await db.collection("products").doc(PRODUCT).get();
      if (productSnap.data().stock !== 995) throw new Error(`expected stock decremented to 995, got ${productSnap.data().stock}`);
      s = `PASSED — order ${createdOrderId} priced at finalPrice=42, RFQ marked consumed, stock decremented`;
    } catch (e) {
      s = `FAILED — ${e.message}`;
    }
    results.scenario10_price_substitution_and_consumption = s;
    if (!s.startsWith("PASSED")) allPassed = false;
    console.log("Scenario 10:", s);
  }

  // Scenario 11 — the double-spend guard: the SAME accepted RFQ, now
  // consumed, cannot be converted a second time.
  {
    const r = await call(
      { rfqId: RFQ_ID, productId: PRODUCT, quantity: 5, paymentMethod: "cod" },
      { uid: BUYER, token: {} }
    );
    const s =
      !r.ok && r.code === "failed-precondition" && /already been converted/i.test(r.message)
        ? "PASSED"
        : `FAILED — ${JSON.stringify(r)}`;
    results.scenario11_double_spend_rejected = s;
    if (s !== "PASSED") allPassed = false;
    console.log("Scenario 11:", s);
  }

  // Scenario 12: rate limit participation — seed order_rate_limits/{uid}
  // already at the shared ceiling within the current window; a fresh
  // accepted RFQ for the same buyer must still be refused. Proves this
  // callable reads/writes the SAME order_rate_limits collection
  // createOrder.ts uses, not a separate, unbounded counter.
  const RFQ_RATELIMIT = "phase40-rfq-ratelimit";
  {
    await db.collection("order_rate_limits").doc(BUYER).set({
      windowStart: admin.firestore.FieldValue.serverTimestamp(),
      count: 8,
    });
    await seedAcceptedRfq(RFQ_RATELIMIT, {
      buyerId: BUYER,
      sellerId: SELLER,
      productId: PRODUCT,
      finalPrice: 10,
      finalQuantity: 1,
    });
    const r = await call(
      { rfqId: RFQ_RATELIMIT, productId: PRODUCT, quantity: 1, paymentMethod: "cod" },
      { uid: BUYER, token: {} }
    );
    const s = !r.ok && r.code === "resource-exhausted" ? "PASSED" : `FAILED — ${JSON.stringify(r)}`;
    results.scenario12_rate_limit_shared_with_createorder = s;
    if (s !== "PASSED") allPassed = false;
    console.log("Scenario 12:", s);
    // Reset the window so it doesn't interfere with any suite run after
    // this one against the same emulator instance in the same session.
    await db.collection("order_rate_limits").doc(BUYER).delete();
  }

  // Scenario 13: a real non-COD payment is verified and consumed correctly
  // — the payable amount must equal finalPrice x finalQuantity, not the
  // product's catalogue price.
  const RFQ_PAID = "phase40-rfq-paid";
  const PAYMENT_ID = "phase40-payment-1";
  const RAZORPAY_ORDER_ID = "phase40-razorpay-order-1";
  {
    await seedAcceptedRfq(RFQ_PAID, {
      buyerId: BUYER,
      sellerId: SELLER,
      productId: PRODUCT,
      finalPrice: 42,
      finalQuantity: 3,
    });
    await db.collection("verified_payments").doc(PAYMENT_ID).set({
      orderId: RAZORPAY_ORDER_ID,
      paymentId: PAYMENT_ID,
      userId: BUYER,
      status: "captured",
      amount: 126, // 42 x 3 — must match, not the catalogue price
    });
    const r = await call(
      {
        rfqId: RFQ_PAID,
        productId: PRODUCT,
        quantity: 3,
        paymentMethod: "razorpay",
        razorpayOrderId: RAZORPAY_ORDER_ID,
        razorpayPaymentId: PAYMENT_ID,
      },
      { uid: BUYER, token: {} }
    );
    let s;
    try {
      if (!r.ok) throw new Error(`expected success, got ${JSON.stringify(r)}`);
      const paymentSnap = await db.collection("verified_payments").doc(PAYMENT_ID).get();
      if (paymentSnap.data().consumedByOrderId !== r.result.orderId) {
        throw new Error("payment was not marked consumed by the new order");
      }
      s = `PASSED — non-COD order ${r.result.orderId} created, payment consumed`;
    } catch (e) {
      s = `FAILED — ${e.message}`;
    }
    results.scenario13_paid_order_success = s;
    if (!s.startsWith("PASSED")) allPassed = false;
    console.log("Scenario 13:", s);
  }

  // Scenario 14: a payment whose verified amount does NOT match
  // finalPrice x finalQuantity is rejected — proves the payable check uses
  // the RFQ's own locked total, not a client-supplied or catalogue amount.
  const RFQ_WRONGAMOUNT = "phase40-rfq-wrongamount";
  const PAYMENT_WRONGAMOUNT = "phase40-payment-wrongamount";
  const RAZORPAY_ORDER_WRONGAMOUNT = "phase40-razorpay-order-wrongamount";
  {
    await seedAcceptedRfq(RFQ_WRONGAMOUNT, {
      buyerId: BUYER,
      sellerId: SELLER,
      productId: PRODUCT,
      finalPrice: 42,
      finalQuantity: 3,
    });
    await db.collection("verified_payments").doc(PAYMENT_WRONGAMOUNT).set({
      orderId: RAZORPAY_ORDER_WRONGAMOUNT,
      paymentId: PAYMENT_WRONGAMOUNT,
      userId: BUYER,
      status: "captured",
      amount: 999, // does not match 42 x 3 = 126
    });
    const r = await call(
      {
        rfqId: RFQ_WRONGAMOUNT,
        productId: PRODUCT,
        quantity: 3,
        paymentMethod: "razorpay",
        razorpayOrderId: RAZORPAY_ORDER_WRONGAMOUNT,
        razorpayPaymentId: PAYMENT_WRONGAMOUNT,
      },
      { uid: BUYER, token: {} }
    );
    const s =
      !r.ok && r.code === "failed-precondition" && /does not match/i.test(r.message)
        ? "PASSED"
        : `FAILED — ${JSON.stringify(r)}`;
    results.scenario14_payment_amount_mismatch_rejected = s;
    if (s !== "PASSED") allPassed = false;
    console.log("Scenario 14:", s);
  }

  // Scenarios 15–17 — RFQ conversion must apply the same explicit
  // purchasability policy as standard checkout, while retaining legacy
  // documents with absent flags.
  async function purchasabilityScenario({ suffix, productState, expectSuccess }) {
    const buyerId = `phase40-f3b-buyer-${suffix}`;
    const productId = `phase40-f3b-product-${suffix}`;
    const rfqId = `phase40-f3b-rfq-${suffix}`;
    await seedUser(buyerId);
    await seedProduct(productId, SELLER, { stock: 17, ...productState });
    await seedAcceptedRfq(rfqId, {
      buyerId,
      sellerId: SELLER,
      productId,
      finalPrice: 42,
      finalQuantity: 3,
    });
    const result = await call(
      { rfqId, productId, quantity: 3, paymentMethod: "cod" },
      { uid: buyerId, token: {} }
    );
    const rfqSnap = await db.collection("rfqs").doc(rfqId).get();
    const productSnap = await db.collection("products").doc(productId).get();
    const orderSnap = await db.collection("orders").where("rfqId", "==", rfqId).get();
    if (expectSuccess) {
      if (!result.ok) throw new Error(`expected RFQ conversion success, got ${JSON.stringify(result)}`);
      if (rfqSnap.data().consumedByOrderId !== result.result.orderId) throw new Error("successful conversion did not consume RFQ");
      if (productSnap.data().stock !== 14) throw new Error(`expected stock 14, got ${productSnap.data().stock}`);
      if (orderSnap.size !== 1) throw new Error(`expected one order, got ${orderSnap.size}`);
    } else {
      if (result.ok || result.code !== "failed-precondition" || !/not available for purchase/i.test(result.message)) {
        throw new Error(`expected purchasability refusal, got ${JSON.stringify(result)}`);
      }
      if (rfqSnap.data().consumedByOrderId) throw new Error("refused RFQ was consumed");
      if (productSnap.data().stock !== 17) throw new Error(`refused conversion changed stock to ${productSnap.data().stock}`);
      if (orderSnap.size !== 0) throw new Error(`refused conversion created ${orderSnap.size} order(s)`);
    }
  }

  for (const scenario of [
    { key: "scenario15_inactive_product_rejected", suffix: "inactive", productState: { isActive: false }, expectSuccess: false },
    { key: "scenario16_draft_product_rejected", suffix: "draft", productState: { isActive: true, isDraft: true }, expectSuccess: false },
    { key: "scenario17_explicit_active_product_allowed", suffix: "active", productState: { isActive: true, isDraft: false }, expectSuccess: true },
  ]) {
    let status;
    try {
      await purchasabilityScenario(scenario);
      status = "PASSED";
    } catch (e) {
      status = `FAILED — ${e.message}`;
      allPassed = false;
    }
    results[scenario.key] = status;
    console.log(`${scenario.key}:`, status);
  }

  console.log("=== PHASE RFQ-3 SUMMARY ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phase40 createOrderFromRfq test:", e);
  process.exit(1);
});
