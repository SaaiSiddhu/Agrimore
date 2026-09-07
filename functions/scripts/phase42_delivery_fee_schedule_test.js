// Phase FIX-8, Workstream 1: proves the per-seller delivery fee schedule
// actually computes correctly against emulated Firestore, not just that
// tsc accepts it. createOrder/quoteOrderWithCredit are v2 onCall callables
// (client-invoked runFunction dispatch, not the runBackground/
// processBackground path the P0-FIELDVALUE investigation found broken) —
// test.wrap() is a safe, genuine reproduction for a callable, unlike for a
// v1 Firestore/pubsub trigger.
//
// Run with:
//   firebase emulators:exec --only firestore,functions,auth \
//     "node scripts/phase42_delivery_fee_schedule_test.js"
// Requires: functions already built (npm run build).
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { createOrder } = require("../lib/customer/createOrder");
const { quoteOrderWithCredit } = require("../lib/customer/productCreditHold");

const wrappedCreateOrder = test.wrap(createOrder);
const wrappedQuote = test.wrap(quoteOrderWithCredit);

let failures = 0;
function check(label, condition, extra) {
  if (condition) {
    console.log(`PASSED — ${label}`);
  } else {
    failures++;
    console.log(`FAILED — ${label}`);
    if (extra !== undefined) console.log("  detail:", JSON.stringify(extra, null, 2));
  }
}

async function seedUser(uid) {
  await admin.firestore().collection("users").doc(uid).set({ uid, profileCompleted: true, role: "customer" });
}

async function seedSeller(sellerId, deliveryFeeSchedule) {
  const doc = { businessName: `Seller ${sellerId}`, status: "approved" };
  if (deliveryFeeSchedule !== undefined) doc.deliveryFeeSchedule = deliveryFeeSchedule;
  await admin.firestore().collection("sellers").doc(sellerId).set(doc);
}

async function seedProduct(productId, sellerId, salePrice) {
  await admin.firestore().collection("products").doc(productId).set({
    name: `Product ${productId}`,
    sellerId,
    salePrice,
    stock: 999,
    images: [],
  });
}

const DELIVERY_ADDRESS = { name: "Test Customer", phone: "9999999999" };

async function main() {
  console.log("=== Phase FIX-8 delivery fee schedule verification (genuine callable invocation) ===\n");

  // ------------------------------------------------------------
  // Scenario 1: single-seller cart, seller has a FLAT schedule.
  // Expect: order.deliveryCharge === the flat amount, NOT the client-
  // supplied value — proving the server overrides the client.
  // ------------------------------------------------------------
  await seedUser("p42-cust-flat");
  await seedSeller("p42-seller-flat", { type: "flat", amount: 45 });
  await seedProduct("p42-prod-flat", "p42-seller-flat", 100);

  const flatResult = await wrappedCreateOrder({
    data: {
      items: [{ productId: "p42-prod-flat", quantity: 2 }],
      orderMode: "B2C",
      paymentMethod: "cod",
      deliveryAddress: DELIVERY_ADDRESS,
      deliveryCharge: 999, // deliberately different from the schedule, to prove override
    },
    auth: { uid: "p42-cust-flat", token: {} },
  });
  const flatOrder = await admin.firestore().collection("orders").doc(flatResult.orders[0].orderId).get();
  check(
    "FLAT schedule: order.deliveryCharge is the seller's configured flat amount (45), not the client-supplied 999",
    flatOrder.data().deliveryCharge === 45,
    flatOrder.data()
  );
  check(
    "FLAT schedule: order.total reflects the schedule-computed delivery charge",
    flatOrder.data().total === 200 + 45,
    flatOrder.data()
  );

  // ------------------------------------------------------------
  // Scenario 2: single-seller cart, seller has a SLAB schedule.
  // Two orders at different subtotals must land in different slabs.
  // ------------------------------------------------------------
  const slabSchedule = {
    type: "slab",
    slabs: [
      { minOrderValue: 0, fee: 40 },
      { minOrderValue: 500, fee: 20 },
      { minOrderValue: 1000, fee: 0 },
    ],
  };
  await seedUser("p42-cust-slab-low");
  await seedUser("p42-cust-slab-high");
  await seedSeller("p42-seller-slab", slabSchedule);
  await seedProduct("p42-prod-slab", "p42-seller-slab", 200);

  const slabLowResult = await wrappedCreateOrder({
    data: {
      items: [{ productId: "p42-prod-slab", quantity: 1 }], // subtotal 200 -> slab "0" -> fee 40
      orderMode: "B2C",
      paymentMethod: "cod",
      deliveryAddress: DELIVERY_ADDRESS,
    },
    auth: { uid: "p42-cust-slab-low", token: {} },
  });
  const slabLowOrder = await admin.firestore().collection("orders").doc(slabLowResult.orders[0].orderId).get();
  check(
    "SLAB schedule: subtotal 200 (below the 500 slab) -> fee 40",
    slabLowOrder.data().deliveryCharge === 40,
    slabLowOrder.data()
  );

  const slabHighResult = await wrappedCreateOrder({
    data: {
      items: [{ productId: "p42-prod-slab", quantity: 6 }], // subtotal 1200 -> slab "1000" -> fee 0
      orderMode: "B2C",
      paymentMethod: "cod",
      deliveryAddress: DELIVERY_ADDRESS,
      // Deliberately non-zero and different from the expected schedule-computed
      // fee (0): if the schedule were ever silently disabled, the legacy
      // fallback would return this 999 unchanged, so the assertion below would
      // fail loudly instead of coincidentally matching a fallback default of 0.
      deliveryCharge: 999,
    },
    auth: { uid: "p42-cust-slab-high", token: {} },
  });
  const slabHighOrder = await admin.firestore().collection("orders").doc(slabHighResult.orders[0].orderId).get();
  check(
    "SLAB schedule: subtotal 1200 (above the 1000 slab) -> fee 0 (free delivery)",
    slabHighOrder.data().deliveryCharge === 0,
    slabHighOrder.data()
  );

  // ------------------------------------------------------------
  // Scenario 3: single-seller cart, seller has NO schedule configured.
  // Legacy behaviour: client-supplied deliveryCharge, unchanged.
  // ------------------------------------------------------------
  await seedUser("p42-cust-none");
  await seedSeller("p42-seller-none", undefined);
  await seedProduct("p42-prod-none", "p42-seller-none", 150);

  const noneResult = await wrappedCreateOrder({
    data: {
      items: [{ productId: "p42-prod-none", quantity: 1 }],
      orderMode: "B2C",
      paymentMethod: "cod",
      deliveryAddress: DELIVERY_ADDRESS,
      deliveryCharge: 60,
    },
    auth: { uid: "p42-cust-none", token: {} },
  });
  const noneOrder = await admin.firestore().collection("orders").doc(noneResult.orders[0].orderId).get();
  check(
    "NO schedule configured: legacy client-supplied deliveryCharge (60) is used unchanged",
    noneOrder.data().deliveryCharge === 60,
    noneOrder.data()
  );

  // ------------------------------------------------------------
  // Scenario 4: single-seller cart, seller has a MALFORMED schedule
  // (missing a zero-value slab). Must fall back to legacy behaviour
  // safely, never crash the order.
  // ------------------------------------------------------------
  await seedUser("p42-cust-malformed");
  await seedSeller("p42-seller-malformed", { type: "slab", slabs: [{ minOrderValue: 500, fee: 10 }] }); // no 0-slab
  await seedProduct("p42-prod-malformed", "p42-seller-malformed", 80);

  const malformedResult = await wrappedCreateOrder({
    data: {
      items: [{ productId: "p42-prod-malformed", quantity: 1 }],
      orderMode: "B2C",
      paymentMethod: "cod",
      deliveryAddress: DELIVERY_ADDRESS,
      deliveryCharge: 30,
    },
    auth: { uid: "p42-cust-malformed", token: {} },
  });
  const malformedOrder = await admin.firestore().collection("orders").doc(malformedResult.orders[0].orderId).get();
  check(
    "MALFORMED schedule (no 0-slab): parseDeliveryFeeSchedule rejects it, falls back to legacy client-supplied (30), does not crash",
    malformedOrder.data().deliveryCharge === 30,
    malformedOrder.data()
  );

  // ------------------------------------------------------------
  // Scenario 5: multi-seller cart, ONE seller has a schedule configured.
  // Must be completely ignored — 100% legacy ratio-split behaviour.
  // ------------------------------------------------------------
  await seedUser("p42-cust-multi");
  await seedSeller("p42-seller-multiA", { type: "flat", amount: 999 }); // configured, must be ignored
  await seedProduct("p42-prod-multiA", "p42-seller-multiA", 100);
  await seedProduct("p42-prod-multiB", "p42-seller-multiB", 100);

  const multiResult = await wrappedCreateOrder({
    data: {
      items: [
        { productId: "p42-prod-multiA", quantity: 1 },
        { productId: "p42-prod-multiB", quantity: 1 },
      ],
      orderMode: "B2C",
      paymentMethod: "cod",
      deliveryAddress: DELIVERY_ADDRESS,
      deliveryCharge: 50,
    },
    auth: { uid: "p42-cust-multi", token: {} },
  });
  check(
    "MULTI-SELLER cart: 2 orders created (one per seller), the configured schedule (999) is ignored entirely",
    Array.isArray(multiResult.orders) && multiResult.orders.length === 2,
    multiResult
  );
  let multiTotalDelivery = 0;
  for (const o of multiResult.orders) {
    const snap = await admin.firestore().collection("orders").doc(o.orderId).get();
    multiTotalDelivery += snap.data().deliveryCharge;
  }
  check(
    "MULTI-SELLER cart: sum of per-seller deliveryCharge equals the legacy client-supplied total (50), not 999+anything",
    Math.abs(multiTotalDelivery - 50) < 0.01,
    { multiTotalDelivery }
  );

  // ------------------------------------------------------------
  // Scenario 6: quoteOrderWithCredit (productCreditHold.ts) matches
  // createOrder's own schedule-computed value — quote/order parity.
  // ------------------------------------------------------------
  await seedUser("p42-cust-quote");
  const quoteResult = await wrappedQuote({
    data: {
      items: [{ productId: "p42-prod-flat", quantity: 2 }],
      orderMode: "B2C",
      deliveryCharge: 999,
    },
    auth: { uid: "p42-cust-quote", token: {} },
  });
  // quoteOrderWithCredit does not expose deliveryCharge directly, only the
  // grandTotal it feeds into (`total`) — 200 subtotal + 45 flat fee, no
  // discount/tax/credit for this customer, so total must be exactly 245,
  // proving the SAME schedule-computed fee flowed into the quote's own
  // grandTotal as flowed into createOrder's order.total in Scenario 1.
  check(
    "QUOTE/ORDER PARITY: quoteOrderWithCredit's total (245 = 200 subtotal + 45 flat fee) matches the SAME schedule-computed delivery charge createOrder used for the identical seller/cart in Scenario 1",
    quoteResult.total === 245,
    quoteResult
  );

  console.log(`\n=== ${failures === 0 ? "ALL PASSED" : `${failures} FAILURE(S)`} ===`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((error) => {
  console.error("FATAL — unhandled error in verification script:", error);
  process.exit(1);
});
