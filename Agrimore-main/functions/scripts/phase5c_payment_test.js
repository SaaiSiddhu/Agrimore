// Phase 5c, workstream 4: proves createOrder's verified_payments trust
// boundary for non-COD orders against a real emulator — every rejection
// path, not just the happy path. A suite that only exercises success proves
// nothing about finding #4's actual protection.
// Run with: node scripts/phase5c_payment_test.js
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

async function main() {
  const db = admin.firestore();
  let allPassed = true;
  const results = {};

  // Phase 16, Workstream 7 fixture update: createOrder.ts now rejects an
  // incomplete-profile caller — unrelated to this file's payment-trust
  // scenarios, so every test user here is seeded profileCompleted:true up
  // front. Purely additive, no assertion below is touched.
  for (const uid of [
    "phase5c-pay-customer1",
    "phase5c-pay-customer2",
    "phase5c-pay-customer3",
    "phase5c-pay-customer4",
    "phase5c-pay-customer5",
    "phase5c-pay-customer6",
  ]) {
    await db.collection("users").doc(uid).set({ uid, profileCompleted: true });
  }

  console.log("=== WORKSTREAM 4 — verified_payments trust boundary (non-COD) ===");

  // salePrice 500 * qty 1, no discount/deliveryCharge/tax -> grandTotal = 500
  await db.collection("products").doc("phase5c-pay-product").set({
    name: "Payment Test Product",
    salePrice: 500,
    isB2BEnabled: false,
    sellerId: "phase5c-pay-seller",
    images: [],
  });

  // Scenario 1: non-COD with no razorpay fields at all.
  {
    const r = await callAndCapture(
      {
        items: [{ productId: "phase5c-pay-product", quantity: 1 }],
        orderMode: "B2C",
        paymentMethod: "razorpay",
      },
      { uid: "phase5c-pay-customer1", token: {} }
    );
    console.log("Scenario 1 raw:", JSON.stringify(r, null, 2));
    const expectedMsg = "Razorpay payment details are required for non-COD orders";
    let s;
    if (r.ok) {
      s = "FAILED — non-COD order succeeded with no razorpay fields supplied";
      allPassed = false;
    } else if (r.message !== expectedMsg) {
      s = `FAILED — wrong message "${r.message}"`;
      allPassed = false;
    } else {
      s = `PASSED — rejected as expected. code=${r.code} message="${r.message}"`;
    }
    results.scenario1 = s;
    console.log("Scenario 1:", s);
  }

  // Scenario 2: razorpay fields supplied, but no matching verified_payments
  // document exists at all — proves a client can't just make up a payment ID.
  {
    const r = await callAndCapture(
      {
        items: [{ productId: "phase5c-pay-product", quantity: 1 }],
        orderMode: "B2C",
        paymentMethod: "razorpay",
        razorpayPaymentId: "pay_nonexistent",
        razorpayOrderId: "order_nonexistent",
      },
      { uid: "phase5c-pay-customer2", token: {} }
    );
    console.log("Scenario 2 raw:", JSON.stringify(r, null, 2));
    const expectedMsg = "Payment could not be verified";
    let s;
    if (r.ok) {
      s = "FAILED — order succeeded with a made-up razorpayPaymentId and no verified_payments doc";
      allPassed = false;
    } else if (r.message !== expectedMsg) {
      s = `FAILED — wrong message "${r.message}"`;
      allPassed = false;
    } else {
      s = `PASSED — rejected as expected. code=${r.code} message="${r.message}"`;
    }
    results.scenario2 = s;
    console.log("Scenario 2:", s);
  }

  // Scenario 3: verified_payments doc exists but its orderId doesn't match
  // what the client is claiming this order's razorpayOrderId is.
  //
  // Phase 14, Workstream 4 update: `userId` added, matching this scenario's
  // own caller (phase5c-pay-customer3) — createOrder now requires it to
  // reach the orderId-mismatch check this scenario actually tests, rather
  // than being rejected one step earlier for lacking user ownership (that
  // earlier rejection is proven deliberately, on its own, by
  // phase14_payment_replay_test.js's scenario 4).
  {
    await db.collection("verified_payments").doc("pay_mismatch").set({
      orderId: "order_totally_different",
      userId: "phase5c-pay-customer3",
      status: "captured",
      amount: 500,
    });
    const r = await callAndCapture(
      {
        items: [{ productId: "phase5c-pay-product", quantity: 1 }],
        orderMode: "B2C",
        paymentMethod: "razorpay",
        razorpayPaymentId: "pay_mismatch",
        razorpayOrderId: "order_the_client_claims",
      },
      { uid: "phase5c-pay-customer3", token: {} }
    );
    console.log("Scenario 3 raw:", JSON.stringify(r, null, 2));
    const expectedMsg = "Payment does not match this order";
    let s;
    if (r.ok) {
      s = "FAILED — order succeeded despite the verified_payments doc's orderId not matching";
      allPassed = false;
    } else if (r.message !== expectedMsg) {
      s = `FAILED — wrong message "${r.message}"`;
      allPassed = false;
    } else {
      s = `PASSED — rejected as expected. code=${r.code} message="${r.message}"`;
    }
    results.scenario3 = s;
    console.log("Scenario 3:", s);
  }

  // Scenario 4: verified_payments doc matches orderId but status isn't
  // "captured" (e.g. still "created" — payment initiated but never completed).
  // Phase 14, Workstream 4 update: `userId` added, matching this scenario's
  // own caller — see the identical note on Scenario 3 above.
  {
    await db.collection("verified_payments").doc("pay_notcaptured").set({
      orderId: "order_notcaptured",
      userId: "phase5c-pay-customer4",
      status: "created",
      amount: 500,
    });
    const r = await callAndCapture(
      {
        items: [{ productId: "phase5c-pay-product", quantity: 1 }],
        orderMode: "B2C",
        paymentMethod: "razorpay",
        razorpayPaymentId: "pay_notcaptured",
        razorpayOrderId: "order_notcaptured",
      },
      { uid: "phase5c-pay-customer4", token: {} }
    );
    console.log("Scenario 4 raw:", JSON.stringify(r, null, 2));
    const expectedMsg = "Payment was not captured";
    let s;
    if (r.ok) {
      s = "FAILED — order succeeded despite status !== 'captured'";
      allPassed = false;
    } else if (r.message !== expectedMsg) {
      s = `FAILED — wrong message "${r.message}"`;
      allPassed = false;
    } else {
      s = `PASSED — rejected as expected. code=${r.code} message="${r.message}"`;
    }
    results.scenario4 = s;
    console.log("Scenario 4:", s);
  }

  // Scenario 5 — THE key fraud scenario: verified_payments doc matches
  // orderId, is captured, but the verified amount (₹1) is nowhere near the
  // real order total (₹500). Proves a customer can't pay ₹1 and claim a
  // ₹500 order.
  // Phase 14, Workstream 4 update: `userId` added, matching this scenario's
  // own caller — see the identical note on Scenario 3 above.
  {
    await db.collection("verified_payments").doc("pay_tampered").set({
      orderId: "order_tampered",
      userId: "phase5c-pay-customer5",
      status: "captured",
      amount: 1,
    });
    const r = await callAndCapture(
      {
        items: [{ productId: "phase5c-pay-product", quantity: 1 }],
        orderMode: "B2C",
        paymentMethod: "razorpay",
        razorpayPaymentId: "pay_tampered",
        razorpayOrderId: "order_tampered",
      },
      { uid: "phase5c-pay-customer5", token: {} }
    );
    console.log("Scenario 5 raw:", JSON.stringify(r, null, 2));
    const expectedMsg = "Verified payment amount does not match the order total";
    let s;
    if (r.ok) {
      s = "FAILED — a ₹500 order succeeded with only ₹1 verified as paid — THIS WOULD BE A REAL FRAUD HOLE";
      allPassed = false;
    } else if (r.message !== expectedMsg) {
      s = `FAILED — wrong message "${r.message}"`;
      allPassed = false;
    } else {
      s = `PASSED — rejected as expected (₹1 verified vs ₹500 order total). code=${r.code} message="${r.message}"`;
    }
    results.scenario5 = s;
    console.log("Scenario 5:", s);
  }

  // Scenario 6: everything correct — matching orderId, captured, amount
  // equal to the real computed grandTotal. Must succeed.
  {
    // grandTotal = roundMoney(max(0, 500 - 0) + 0 + 0) = 500, computed the
    // same way createOrder.ts itself computes it, not guessed.
    const expectedGrandTotal = 500;
    // Phase 14, Workstream 4 update: `userId` added, matching this
    // scenario's own caller — see the identical note on Scenario 3 above.
    await db.collection("verified_payments").doc("pay_correct").set({
      orderId: "order_correct",
      userId: "phase5c-pay-customer6",
      status: "captured",
      amount: expectedGrandTotal,
    });
    const r = await callAndCapture(
      {
        items: [{ productId: "phase5c-pay-product", quantity: 1 }],
        orderMode: "B2C",
        paymentMethod: "razorpay",
        razorpayPaymentId: "pay_correct",
        razorpayOrderId: "order_correct",
      },
      { uid: "phase5c-pay-customer6", token: {} }
    );
    console.log("Scenario 6 raw:", JSON.stringify(r, null, 2));
    let s;
    try {
      if (!r.ok) throw new Error(`expected success, got error: ${r.message}`);
      const doc = await db.collection("orders").doc(r.result.orders[0].orderId).get();
      const data = doc.data();
      if (data.paymentStatus !== "paid") throw new Error(`expected paymentStatus "paid", got ${data.paymentStatus}`);
      if (data.total !== expectedGrandTotal) {
        throw new Error(`expected total ${expectedGrandTotal}, got ${data.total}`);
      }
      s = `PASSED — correctly-verified non-COD payment accepted, order created with paymentStatus=${data.paymentStatus}, total=${data.total}`;
    } catch (e) {
      s = `FAILED — ${e.message}`;
      allPassed = false;
    }
    results.scenario6 = s;
    console.log("Scenario 6:", s);
  }

  console.log("=== WORKSTREAM 4 SUMMARY ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running payment test:", e);
  process.exit(1);
});
