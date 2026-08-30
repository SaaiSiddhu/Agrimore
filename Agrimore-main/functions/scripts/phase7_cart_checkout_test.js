// Phase 7: proves that the exact payload shape now sent by
// apps/marketplace/lib/screens/user/cart/mobile_cart_screen.dart's migrated
// _createOrderInFirestore() is accepted by the real createOrder callable
// (functions/src/customer/createOrder.ts) against a real emulator — not just
// that the Dart compiles. Field-by-field cross-check against the literal
// Dart map built in _createOrderInFirestore:
//
//   {
//     'items': cartProvider.items.map((item) => {
//       'productId': item.productId,
//       'quantity': item.quantity,
//     }).toList(),
//     'orderMode': 'B2C',
//     'deliveryAddress': address.toMap(),
//     'paymentMethod': normalizedPaymentMethod,       // 'cod' | 'razorpay'
//     if (razorpayOrderId != null) 'razorpayOrderId': razorpayOrderId,
//     if (razorpayPaymentId != null) 'razorpayPaymentId': razorpayPaymentId,
//     if (razorpaySignature != null) 'razorpaySignature': razorpaySignature,
//     if (couponProvider.appliedCoupon?.code != null) 'couponCode': ...,
//     'deliveryCharge': deliveryCharge,
//     'tax': 0.0,
//   }
//
// Run with: node scripts/phase7_cart_checkout_test.js
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { createOrder } = require("../lib/customer/createOrder");

const wrapped = test.wrap(createOrder);

async function callAndCapture(payload, auth) {
  try {
    const result = await wrapped({ data: payload, auth });
    return { ok: true, result };
  } catch (e) {
    return { ok: false, code: e.code, message: e.message };
  }
}

// Mirrors AddressModel.toMap()'s shape closely enough for createOrder's
// purposes — createOrder stores deliveryAddress verbatim and never reads
// individual fields from it, so exact schema fidelity isn't load-bearing
// here, only that it's a plain object as address.toMap() would produce.
function fakeAddressMap() {
  return {
    name: "Phase7 Test Customer",
    phone: "9999999999",
    addressLine1: "123 Test Street",
    addressLine2: "",
    city: "Chennai",
    state: "Tamil Nadu",
    zipcode: "600001",
    country: "India",
    latitude: 13.0827,
    longitude: 80.2707,
  };
}

async function main() {
  const db = admin.firestore();
  let allPassed = true;
  const results = {};

  // Phase 16, Workstream 7 fixture update: createOrder.ts now rejects an
  // incomplete-profile caller. This file's scenarios are about checkout
  // payload shape, unrelated to profile completion, so every test user
  // here is seeded profileCompleted:true up front — purely additive, no
  // assertion below is touched.
  for (const uid of ["phase7-cod-customer", "phase7-razorpay-customer", "phase7-uncased-customer"]) {
    await db.collection("users").doc(uid).set({ uid, profileCompleted: true });
  }

  console.log("=== PHASE 7 — mobile_cart_screen.dart -> createOrder payload shape ===");

  // salePrice 250 * qty 2 = 500 subtotal, matching the reference product used
  // in phase5c_payment_test.js's own passing scenario for consistency.
  await db.collection("products").doc("phase7-cart-product").set({
    name: "Cart Checkout Test Product",
    salePrice: 250,
    isB2BEnabled: false,
    sellerId: "phase7-cart-seller",
    images: [],
  });

  // Scenario 1 (BEFORE evidence): the OLD mobile_cart_screen.dart wrote
  // directly to `orders` via batch.set() — that write is now rejected by the
  // real, deployed `allow create: if false;` rule (already proven in Phase
  // 5b/5c's rules tests; not re-proven here since it's the unchanged,
  // out-of-scope rule). This callable test instead proves the NEW code path
  // (server-validated createOrder) works end-to-end, which is the actual
  // fix.

  // Scenario 2: COD order, exact payload shape mobile_cart_screen.dart sends
  // when _selectedPaymentMethod == 'COD' (normalized to lowercase 'cod'),
  // no coupon applied, deliveryCharge = 40 (the standard non-free-delivery
  // fee _calculateAdvancedPricing computes), tax always 0.0 in this screen.
  {
    const payload = {
      items: [{ productId: "phase7-cart-product", quantity: 2 }],
      orderMode: "B2C",
      deliveryAddress: fakeAddressMap(),
      paymentMethod: "cod",
      deliveryCharge: 40,
      tax: 0.0,
    };
    console.log("Scenario 2 payload:", JSON.stringify(payload, null, 2));
    const r = await callAndCapture(payload, { uid: "phase7-cod-customer", token: {} });
    console.log("Scenario 2 raw response:", JSON.stringify(r, null, 2));
    let s;
    try {
      if (!r.ok) throw new Error(`expected success, got error: code=${r.code} message=${r.message}`);
      if (r.result.orders.length !== 1) throw new Error(`expected 1 order, got ${r.result.orders.length}`);
      const orderId = r.result.orders[0].orderId;
      const doc = await db.collection("orders").doc(orderId).get();
      const data = doc.data();
      if (data.paymentMethod !== "cod") throw new Error(`expected paymentMethod "cod", got ${data.paymentMethod}`);
      if (data.paymentStatus !== "pending") throw new Error(`expected paymentStatus "pending", got ${data.paymentStatus}`);
      // 250*2 - 0 discount + 40 delivery + 0 tax = 540
      if (data.total !== 540) throw new Error(`expected total 540, got ${data.total}`);
      if (data.orderMode !== "B2C") throw new Error(`expected orderMode "B2C", got ${data.orderMode}`);
      s = `PASSED — COD order created. orderId=${orderId} total=${data.total} paymentStatus=${data.paymentStatus}`;
    } catch (e) {
      s = `FAILED — ${e.message}`;
      allPassed = false;
    }
    results.scenario2_cod = s;
    console.log("Scenario 2:", s);
  }

  // Scenario 3: Razorpay order, exact payload shape mobile_cart_screen.dart
  // sends when _selectedPaymentMethod == 'Razorpay' (normalized to lowercase
  // 'razorpay') after a real payment — requires a matching verified_payments
  // doc, exactly like payment_method_screen.dart's already-migrated path.
  {
    // subtotal 500 + deliveryCharge 40 + tax 0 = grandTotal 540
    //
    // Phase 14, Workstream 4 update: `userId` added to this fixture — as of
    // this phase, verifyRazorpayPayment (functions/src/customer/payment.ts)
    // always stamps the paying user's uid onto verified_payments/{paymentId}
    // (closing a cross-user payment-reuse hole), and createOrder now
    // requires it to match the caller. This fixture is hand-seeded (it
    // bypasses verifyRazorpayPayment entirely, the same way it always has),
    // so it must be kept in sync with that same schema by hand. Without
    // this field the call below would be rejected with "Payment could not
    // be verified for this user" — the exact intended behavior for a
    // legacy/foreign payment, proven separately and on purpose by
    // phase14_payment_replay_test.js's scenario 4 — which is not what this
    // scenario is testing, so the fixture is updated to match rather than
    // left stale.
    await db.collection("verified_payments").doc("phase7-pay-correct").set({
      orderId: "phase7-razorpay-order",
      userId: "phase7-razorpay-customer",
      status: "captured",
      amount: 540,
    });
    const payload = {
      items: [{ productId: "phase7-cart-product", quantity: 2 }],
      orderMode: "B2C",
      deliveryAddress: fakeAddressMap(),
      paymentMethod: "razorpay",
      razorpayOrderId: "phase7-razorpay-order",
      razorpayPaymentId: "phase7-pay-correct",
      razorpaySignature: "fake-signature-verified-client-side-already",
      deliveryCharge: 40,
      tax: 0.0,
    };
    console.log("Scenario 3 payload:", JSON.stringify(payload, null, 2));
    const r = await callAndCapture(payload, { uid: "phase7-razorpay-customer", token: {} });
    console.log("Scenario 3 raw response:", JSON.stringify(r, null, 2));
    let s;
    try {
      if (!r.ok) throw new Error(`expected success, got error: code=${r.code} message=${r.message}`);
      const orderId = r.result.orders[0].orderId;
      const doc = await db.collection("orders").doc(orderId).get();
      const data = doc.data();
      if (data.paymentMethod !== "razorpay") throw new Error(`expected paymentMethod "razorpay", got ${data.paymentMethod}`);
      if (data.paymentStatus !== "paid") throw new Error(`expected paymentStatus "paid", got ${data.paymentStatus}`);
      if (data.total !== 540) throw new Error(`expected total 540, got ${data.total}`);
      s = `PASSED — Razorpay order created against a matching verified_payments doc. orderId=${orderId} total=${data.total} paymentStatus=${data.paymentStatus}`;
    } catch (e) {
      s = `FAILED — ${e.message}`;
      allPassed = false;
    }
    results.scenario3_razorpay = s;
    console.log("Scenario 3:", s);
  }

  // Scenario 4 (negative control — proves paymentMethod casing actually
  // matters and that the fix's .toLowerCase() call is load-bearing): if the
  // OLD raw display-cased string 'COD' were sent instead of the normalized
  // 'cod', createOrder.ts's `paymentMethod !== "cod"` check treats it as a
  // NON-COD order and demands Razorpay fields — this is the exact bug that
  // sending _selectedPaymentMethod verbatim (without .toLowerCase()) would
  // have caused, and confirms why the fix normalizes it.
  {
    const payload = {
      items: [{ productId: "phase7-cart-product", quantity: 1 }],
      orderMode: "B2C",
      deliveryAddress: fakeAddressMap(),
      paymentMethod: "COD", // deliberately un-normalized, as a regression guard
      deliveryCharge: 0,
      tax: 0.0,
    };
    const r = await callAndCapture(payload, { uid: "phase7-uncased-customer", token: {} });
    console.log("Scenario 4 raw response:", JSON.stringify(r, null, 2));
    const expectedMsg = "Razorpay payment details are required for non-COD orders";
    let s;
    if (r.ok) {
      s = "FAILED — un-normalized 'COD' was accepted as COD; expected it to be misread as non-COD (this would mean the casing bug doesn't actually matter, contradicting the analysis)";
      allPassed = false;
    } else if (r.message !== expectedMsg) {
      s = `FAILED — wrong message "${r.message}"`;
      allPassed = false;
    } else {
      s = `PASSED (confirms the bug this fix avoids) — sending un-normalized 'COD' verbatim is rejected as expected. code=${r.code} message="${r.message}"`;
    }
    results.scenario4_negative_control_uncased = s;
    console.log("Scenario 4:", s);
  }

  console.log("=== PHASE 7 SUMMARY ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phase7 cart checkout test:", e);
  process.exit(1);
});
