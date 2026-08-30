// Phase 14, Workstream 4: proves createOrder.ts's verified_payments
// consumption fix against a real emulator (not mocked Firestore) — the
// same razorpayPaymentId cannot create a second order (replay), and
// another user's razorpayPaymentId cannot create an order for a different
// caller (cross-user reuse). createOrder is a v2 onCall
// (firebase-functions/v2/https), so it's wrapped and invoked as
// `wrapped({ data: payload, auth })` — NOT `wrapped(payload, { auth })`,
// which is the v1 shape used by roleClaims.ts's refreshUserRoleClaims.
// Mirrors phase9_wallet_topup_test.js's real-emulator harness pattern.
// Run with: node scripts/phase14_payment_replay_test.js
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

async function seedVerifiedPayment(db, paymentId, { orderId, userId, amount, status = "captured" }) {
  await db.collection("verified_payments").doc(paymentId).set({
    orderId,
    paymentId,
    userId,
    signatureVerified: true,
    status,
    amount,
    currency: "INR",
    verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function main() {
  const db = admin.firestore();
  let allPassed = true;
  const results = {};

  // Phase 16, Workstream 7 fixture update: createOrder.ts now rejects an
  // incomplete-profile caller. This file's scenarios are about payment
  // replay/consumption, unrelated to profile completion, so every test
  // user here is seeded profileCompleted:true up front — purely additive,
  // no assertion below is touched.
  for (const uid of [
    "phase14-payment-customer1",
    "phase14-payment-customer2",
    "phase14-payment-customer3",
    "phase14-payment-customer4",
  ]) {
    await db.collection("users").doc(uid).set({ uid, profileCompleted: true });
  }

  console.log("=== PHASE 14, WORKSTREAM 4 — createOrder payment consumption ===");

  // Scenario 1: a normal first-time non-COD order — the control proving
  // checkout still works after making createOrder transactional.
  {
    const uid = "phase14-payment-customer1";
    const productId = "phase14-payment-product1";
    const paymentId = "phase14-pay-1";
    const razorpayOrderId = "phase14-rzp-order-1";
    await seedProduct(db, productId, "phase14-seller1", 500);
    await seedVerifiedPayment(db, paymentId, { orderId: razorpayOrderId, userId: uid, amount: 500 });

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
    console.log("Scenario 1 raw:", JSON.stringify(r, null, 2));
    let s;
    try {
      if (!r.ok) throw new Error(`expected success, got error: code=${r.code} message=${r.message}`);
      if (!r.result.orders || r.result.orders.length !== 1) throw new Error("expected exactly one created order");
      if (r.result.orders[0].total !== 500) throw new Error(`expected total 500, got ${r.result.orders[0].total}`);
      const paymentDoc = await db.collection("verified_payments").doc(paymentId).get();
      const payment = paymentDoc.data();
      if (!payment.consumedByOrderId) throw new Error("expected verified_payments doc to be marked consumed after a successful order");
      if (payment.consumedByOrderId !== r.result.orders[0].orderId) {
        throw new Error(`consumedByOrderId (${payment.consumedByOrderId}) does not match the created order id (${r.result.orders[0].orderId})`);
      }
      s = `PASSED — order created (total=${r.result.orders[0].total}), payment marked consumedByOrderId=${payment.consumedByOrderId}`;
    } catch (e) {
      s = `FAILED — ${e.message}`;
      allPassed = false;
    }
    results.scenario1_normal_order_succeeds = s;
    console.log("Scenario 1:", s);
  }

  // Scenario 2 — THE replay proof: reuse the SAME paymentId from Scenario 1
  // for a second order. Must be rejected now that it's marked consumed.
  {
    const uid = "phase14-payment-customer1"; // same user as scenario 1
    const productId = "phase14-payment-product1";
    const paymentId = "phase14-pay-1"; // same paymentId as scenario 1
    const razorpayOrderId = "phase14-rzp-order-1";

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
    console.log("Scenario 2 raw:", JSON.stringify(r, null, 2));
    let s;
    if (r.ok) {
      s = "FAILED — replaying the SAME razorpayPaymentId created a SECOND order — THIS IS THE UNLIMITED-FREE-ORDERS EXPLOIT, STILL OPEN";
      allPassed = false;
    } else if (r.message !== "This payment has already been used for an order") {
      s = `FAILED — rejected, but with the wrong message: "${r.message}" (code=${r.code})`;
      allPassed = false;
    } else {
      s = `PASSED — the replay was rejected. code=${r.code} message="${r.message}"`;
    }
    results.scenario2_replay_rejected = s;
    console.log("Scenario 2:", s);

    // Independent confirmation: only ONE order should exist for this
    // payment's razorpayPaymentId, not two.
    const ordersSnap = await db.collection("orders").where("razorpayPaymentId", "==", paymentId).get();
    const countCheck = ordersSnap.size === 1
      ? `PASSED — exactly 1 order exists for paymentId=${paymentId} after the replay attempt`
      : `FAILED — ${ordersSnap.size} orders exist for paymentId=${paymentId}, expected exactly 1`;
    if (ordersSnap.size !== 1) allPassed = false;
    results.scenario2b_exactly_one_order_persisted = countCheck;
    console.log("Scenario 2b:", countCheck);
  }

  // Scenario 3 — THE cross-user-reuse proof: customer3 tries to use
  // customer2's verified payment. Must be rejected, even though the
  // payment is genuinely captured and the amount matches.
  {
    const payerUid = "phase14-payment-customer2";
    const attackerUid = "phase14-payment-customer3";
    const productId = "phase14-payment-product2";
    const paymentId = "phase14-pay-2";
    const razorpayOrderId = "phase14-rzp-order-2";
    await seedProduct(db, productId, "phase14-seller2", 300);
    await seedVerifiedPayment(db, paymentId, { orderId: razorpayOrderId, userId: payerUid, amount: 300 });

    const r = await callAndCapture(
      {
        items: [{ productId, quantity: 1 }],
        orderMode: "B2C",
        paymentMethod: "upi",
        razorpayOrderId,
        razorpayPaymentId: paymentId,
      },
      { uid: attackerUid, token: {} } // NOT the uid the payment belongs to
    );
    console.log("Scenario 3 raw:", JSON.stringify(r, null, 2));
    let s;
    if (r.ok) {
      s = "FAILED — a DIFFERENT user's razorpayPaymentId satisfied this caller's order — CROSS-USER PAYMENT REUSE, STILL OPEN";
      allPassed = false;
    } else if (r.message !== "Payment could not be verified for this user") {
      s = `FAILED — rejected, but with the wrong message: "${r.message}" (code=${r.code})`;
      allPassed = false;
    } else {
      s = `PASSED — cross-user reuse was rejected. code=${r.code} message="${r.message}"`;
    }
    results.scenario3_cross_user_reuse_rejected = s;
    console.log("Scenario 3:", s);

    // The genuine payer must still be able to use their own payment
    // afterward — proves this isn't a blanket rejection of the payment.
    const r2 = await callAndCapture(
      {
        items: [{ productId, quantity: 1 }],
        orderMode: "B2C",
        paymentMethod: "upi",
        razorpayOrderId,
        razorpayPaymentId: paymentId,
      },
      { uid: payerUid, token: {} }
    );
    console.log("Scenario 3b raw:", JSON.stringify(r2, null, 2));
    const s2 = r2.ok
      ? `PASSED — the genuine payer (${payerUid}) could still use their own verified payment after the attacker's attempt was rejected`
      : `FAILED — the genuine payer's own payment was incorrectly rejected too: code=${r2.code} message="${r2.message}"`;
    if (!r2.ok) allPassed = false;
    results.scenario3b_genuine_payer_still_works = s2;
    console.log("Scenario 3b:", s2);
  }

  // Scenario 4 — legacy document with no userId at all (written before
  // this phase's payment.ts change) must be treated as unverifiable, not
  // "unknown, allow it".
  {
    const uid = "phase14-payment-customer4";
    const productId = "phase14-payment-product3";
    const paymentId = "phase14-pay-legacy";
    const razorpayOrderId = "phase14-rzp-order-legacy";
    await seedProduct(db, productId, "phase14-seller3", 200);
    // Deliberately no `userId` field, simulating a pre-Phase-14 document.
    await db.collection("verified_payments").doc(paymentId).set({
      orderId: razorpayOrderId,
      paymentId,
      status: "captured",
      amount: 200,
      currency: "INR",
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
    console.log("Scenario 4 raw:", JSON.stringify(r, null, 2));
    let s;
    if (r.ok) {
      s = "FAILED — a legacy verified_payments document with no userId field was accepted — the fail-closed legacy handling is not working";
      allPassed = false;
    } else if (r.message !== "Payment could not be verified for this user") {
      s = `FAILED — rejected, but with the wrong message: "${r.message}" (code=${r.code})`;
      allPassed = false;
    } else {
      s = `PASSED — a legacy document with no userId was rejected (fail-closed), as designed`;
    }
    results.scenario4_legacy_missing_userid_rejected = s;
    console.log("Scenario 4:", s);
  }

  console.log("=== PHASE 14 WORKSTREAM 4 SUMMARY ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phase14 payment replay test:", e);
  process.exit(1);
});
