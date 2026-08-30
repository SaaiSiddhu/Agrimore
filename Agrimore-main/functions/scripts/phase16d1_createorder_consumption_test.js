// Phase 16D-1, Workstream 1: proves createOrder.ts's new
// `payment.consumedByOnboardingFor` check — the symmetric counterpart to
// functions/src/employee/activationCore.ts's own `consumedByOrderId`
// check — against a real emulator. Mirrors phase14_payment_replay_test.js's
// harness exactly: createOrder is a v2 onCall, wrapped and invoked as
// `wrapped({ data: payload, auth })`.
// Run with: node scripts/phase16d1_createorder_consumption_test.js
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

async function seedProduct(db, productId, sellerId, salePrice) {
  await db.collection("products").doc(productId).set({
    name: `Product ${productId}`,
    salePrice,
    sellerId,
    images: [],
    stock: 100,
    isB2BEnabled: false,
  });
}

async function main() {
  const db = admin.firestore();
  let allPassed = true;
  const results = {};

  for (const uid of ["p16d1-w1-customer1", "p16d1-w1-customer2"]) {
    await db.collection("users").doc(uid).set({ uid, profileCompleted: true });
  }

  console.log("=== PHASE 16D-1, WORKSTREAM 1 — createOrder cross-consumption gap ===");

  // Scenario A: a payment already consumed by an associate's onboarding
  // activation (consumedByOnboardingFor set) must be REJECTED for order
  // creation — this is the exploit finding 16A-X being closed.
  {
    const uid = "p16d1-w1-customer1";
    const productId = "p16d1-w1-product1";
    const paymentId = "p16d1-w1-pay-onboarding-consumed";
    const razorpayOrderId = "p16d1-w1-rzp-order-1";
    await seedProduct(db, productId, "p16d1-w1-seller1", 500);
    await db.collection("verified_payments").doc(paymentId).set({
      orderId: razorpayOrderId,
      paymentId,
      userId: uid,
      signatureVerified: true,
      status: "captured",
      amount: 500,
      currency: "INR",
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      // Set by functions/src/employee/activationCore.ts when this exact
      // payment was spent on onboarding.
      consumedByOnboardingFor: uid,
      consumedByOnboardingAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const r = await callAndCapture(
      {
        items: [{ productId, quantity: 1 }],
        orderMode: "B2C",
        paymentMethod: "upi",
        razorpayOrderId,
        razorpayPaymentId: paymentId,
      },
      { uid, token: {} }
    );
    console.log("Scenario A raw:", JSON.stringify(r, null, 2));
    let s;
    if (r.ok) {
      s = "FAILED — an onboarding-consumed payment was accepted to create a real order — THE EXPLOIT (finding 16A-X) IS STILL OPEN";
      allPassed = false;
    } else if (r.message !== "This payment has already been used for onboarding") {
      s = `FAILED — rejected, but with the wrong message: "${r.message}" (code=${r.code})`;
      allPassed = false;
    } else {
      s = `PASSED — an onboarding-consumed payment was rejected for order creation. code=${r.code} message="${r.message}"`;
    }
    results.scenarioA_onboarding_consumed_payment_rejected = s;
    console.log("Scenario A:", s);

    const ordersSnap = await db.collection("orders").where("razorpayPaymentId", "==", paymentId).get();
    const s2 = ordersSnap.empty
      ? "PASSED — no order was created for the onboarding-consumed payment"
      : `FAILED — ${ordersSnap.size} order(s) were created despite the payment being onboarding-consumed`;
    if (!ordersSnap.empty) allPassed = false;
    results.scenarioA2_no_order_created = s2;
    console.log("Scenario A2:", s2);
  }

  // Scenario B: a normal, unconsumed payment (neither consumedByOrderId
  // nor consumedByOnboardingFor set) must still create an order
  // successfully — the new check must not be over-broad.
  {
    const uid = "p16d1-w1-customer2";
    const productId = "p16d1-w1-product2";
    const paymentId = "p16d1-w1-pay-clean";
    const razorpayOrderId = "p16d1-w1-rzp-order-2";
    await seedProduct(db, productId, "p16d1-w1-seller2", 300);
    await db.collection("verified_payments").doc(paymentId).set({
      orderId: razorpayOrderId,
      paymentId,
      userId: uid,
      signatureVerified: true,
      status: "captured",
      amount: 300,
      currency: "INR",
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const r = await callAndCapture(
      {
        items: [{ productId, quantity: 1 }],
        orderMode: "B2C",
        paymentMethod: "upi",
        razorpayOrderId,
        razorpayPaymentId: paymentId,
      },
      { uid, token: {} }
    );
    console.log("Scenario B raw:", JSON.stringify(r, null, 2));
    let s;
    if (!r.ok) {
      s = `FAILED — a normal, unconsumed payment was rejected: code=${r.code} message="${r.message}" (the new check is over-broad)`;
      allPassed = false;
    } else {
      s = `PASSED — a normal unconsumed payment still creates an order successfully (total=${r.result.orders[0].total})`;
    }
    results.scenarioB_normal_payment_still_works = s;
    console.log("Scenario B:", s);
  }

  console.log("=== PHASE 16D-1 WORKSTREAM 1 SUMMARY ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phase16d1 createOrder consumption test:", e);
  process.exit(1);
});
