// Phase FIX-1 — proves that one captured Razorpay payment can be spent EXACTLY
// once, across all three spending paths, and that a wallet top-up is bound to
// the person who actually paid.
//
// Findings closed here:
//   N-1 (P0) — verifyWalletTopup anchored idempotency solely on
//              wallet_topups/{paymentId}, a collection neither createOrder.ts
//              nor employee/activationCore.ts reads. Those two anchor on
//              verified_payments/{paymentId}.consumedBy*. The namespaces were
//              DISJOINT, so one captured payment bought goods AND credited a
//              wallet — in either order, with no guard in either direction.
//   N-6 (P1) — verifyWalletTopup never checked who paid, so anyone holding a
//              valid (orderId, paymentId, signature) triple could credit their
//              OWN wallet with someone else's money.
//
// Exercises the REAL compiled functions/lib/customer/wallet.js,
// functions/lib/customer/createOrder.js and
// functions/lib/employee/activationCore.js against the Firestore emulator.
// Only the outbound Razorpay HTTP call is mocked (it cannot reach the real
// API from a test) — patched on the axios CommonJS singleton BEFORE the
// compiled wallet.js is required, exactly as phase9_wallet_topup_test.js does.
//
// createOrder and verifyWalletTopup are v2 onCall — wrapped and invoked as
// `wrapped({ data, auth })`. performOnboardingActivation is a plain async
// function, called directly (activateAssociateOnboarding.ts is its onCall
// wrapper).
//
// Run with:
//   firebase emulators:exec --only firestore,functions,auth \
//     "node scripts/phase25_payment_single_consumption_test.js"
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";
process.env.RAZORPAY_KEY_ID = "rzp_test_phase25_fake_key";
process.env.RAZORPAY_KEY_SECRET = "phase25_fake_secret_never_a_real_key";

const crypto = require("crypto");
const axios = require("axios");

const mockPayments = {};
const originalAxiosGet = axios.get.bind(axios);
axios.get = async (url, config) => {
  const match = /\/v1\/payments\/([^/]+)$/.exec(url);
  if (match && mockPayments[match[1]]) {
    return { data: mockPayments[match[1]] };
  }
  return originalAxiosGet(url, config);
};

const admin = require("firebase-admin");
if (admin.apps.length === 0) {
  admin.initializeApp({ projectId: "agrimore-66a4e" });
}
const db = admin.firestore();

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { verifyWalletTopup } = require("../lib/customer/wallet");
const { createOrder } = require("../lib/customer/createOrder");
const { performOnboardingActivation } = require("../lib/employee/activationCore");

const wrappedTopup = test.wrap(verifyWalletTopup);
const wrappedCreateOrder = test.wrap(createOrder);

function computeSignature(orderId, paymentId) {
  return crypto
    .createHmac("sha256", process.env.RAZORPAY_KEY_SECRET)
    .update(`${orderId}|${paymentId}`)
    .digest("hex");
}

async function callTopup(payload, auth) {
  try {
    return { ok: true, result: await wrappedTopup({ data: payload, auth }) };
  } catch (e) {
    return { ok: false, code: e.code, message: e.message };
  }
}

async function callCreateOrder(payload, auth) {
  try {
    return { ok: true, result: await wrappedCreateOrder({ data: payload, auth }) };
  } catch (e) {
    return { ok: false, code: e.code, message: e.message };
  }
}

async function seedUser(uid) {
  await db.collection("users").doc(uid).set({ uid, profileCompleted: true });
}

async function seedProduct(productId, sellerId, salePrice, stock) {
  await db.collection("products").doc(productId).set({
    name: `Product ${productId}`,
    salePrice,
    sellerId,
    images: [],
    stock,
    isB2BEnabled: false,
  });
}

async function seedRazorpayOrder(orderId, uid, amount) {
  await db.collection("razorpay_orders").doc(orderId).set({
    orderId,
    userId: uid,
    amount,
    amountPaise: amount * 100,
    currency: "INR",
    status: "created",
  });
}

// Mirrors what verifyRazorpayPayment writes after HMAC + live-API verification.
async function seedVerifiedPayment(paymentId, orderId, uid, amount, extra) {
  await db
    .collection("verified_payments")
    .doc(paymentId)
    .set(
      Object.assign(
        {
          paymentId,
          orderId,
          userId: uid,
          status: "captured",
          amount,
          signatureVerified: true,
        },
        extra || {}
      )
    );
}

function mockCaptured(paymentId, amount, orderId) {
  mockPayments[paymentId] = {
    id: paymentId,
    order_id: orderId,
    amount: amount * 100,
    currency: "INR",
    status: "captured",
    method: "card",
  };
}

function orderPayload(productId, paymentId, orderId) {
  return {
    items: [{ productId, quantity: 1 }],
    orderMode: "B2C",
    deliveryAddress: {
      name: "Phase25 Test",
      phone: "9999999996",
      addressLine1: "1 Test Street",
      addressLine2: "",
      city: "Chennai",
      state: "Tamil Nadu",
      zipcode: "600001",
      country: "India",
      latitude: 13.0827,
      longitude: 80.2707,
    },
    paymentMethod: "razorpay",
    razorpayPaymentId: paymentId,
    razorpayOrderId: orderId,
    deliveryCharge: 0,
    tax: 0,
  };
}

const ONBOARDING_CONFIG = {
  isEnabled: true,
  feeAmount: 500,
  currency: "INR",
  feeIsOneTime: true,
  version: 1,
  copy: {
    headline: "h",
    body: "b",
    ctaLabel: "c",
    refundPolicy: "r",
  },
};

async function main() {
  let allPassed = true;
  const results = {};
  const record = (key, passed, detail) => {
    results[key] = passed;
    console.log(`${key}: ${passed ? "PASSED" : "FAILED"} — ${detail}`);
    if (!passed) allPassed = false;
  };

  console.log("=== PHASE FIX-1 — payment single-consumption (N-1, N-6) ===");

  // ------------------------------------------------------------------
  // Scenario 1 — POSITIVE CONTROL (non-vacuity).
  // A clean, owned, unconsumed payment must still credit the wallet. Without
  // this, every other scenario below could pass simply because the function
  // refuses everything.
  // ------------------------------------------------------------------
  {
    const uid = "phase25-control-user";
    const orderId = "order_phase25_control";
    const paymentId = "pay_phase25_control";
    const amount = 1000;
    await seedUser(uid);
    await seedRazorpayOrder(orderId, uid, amount);
    mockCaptured(paymentId, amount, orderId);

    const r = await callTopup(
      { amount, paymentId, orderId, signature: computeSignature(orderId, paymentId) },
      { uid, token: {} }
    );
    const wallet = await db.collection("wallets").doc(uid).get();
    const payment = await db.collection("verified_payments").doc(paymentId).get();
    const s =
      r.ok &&
      wallet.exists &&
      wallet.data().balance === amount &&
      payment.exists &&
      payment.data().consumedByWalletTopup === uid;
    record(
      "scenario1_clean_topup_succeeds_and_claims_payment",
      s,
      `ok=${r.ok} balance=${wallet.data()?.balance} consumedByWalletTopup=${payment.data()?.consumedByWalletTopup}`
    );
  }

  // ------------------------------------------------------------------
  // Scenario 2 — N-1 DIRECTION A: order first, then top-up.
  // The REAL createOrder consumes the payment (writing consumedByOrderId), then
  // the same paymentId must be refused by verifyWalletTopup.
  // ------------------------------------------------------------------
  {
    const uid = "phase25-dirA-user";
    const productId = "phase25-dirA-product";
    const orderId = "order_phase25_dirA";
    const paymentId = "pay_phase25_dirA";
    const amount = 500;
    await seedUser(uid);
    await seedProduct(productId, "phase25-dirA-seller", amount, 50);
    await seedRazorpayOrder(orderId, uid, amount);
    await seedVerifiedPayment(paymentId, orderId, uid, amount);
    mockCaptured(paymentId, amount, orderId);

    const orderResult = await callCreateOrder(orderPayload(productId, paymentId, orderId), {
      uid,
      token: {},
    });
    const consumed = (await db.collection("verified_payments").doc(paymentId).get()).data();
    const topup = await callTopup(
      { amount, paymentId, orderId, signature: computeSignature(orderId, paymentId) },
      { uid, token: {} }
    );
    const wallet = await db.collection("wallets").doc(uid).get();
    const s =
      orderResult.ok &&
      !!consumed.consumedByOrderId &&
      !topup.ok &&
      topup.code === "failed-precondition" &&
      topup.message.toLowerCase().includes("order") &&
      !wallet.exists;
    record(
      "scenario2_N1_order_consumed_payment_cannot_credit_wallet",
      s,
      `order.ok=${orderResult.ok} consumedByOrderId=${!!consumed.consumedByOrderId} topup.code=${topup.code} topup.msg="${topup.message}" walletCreated=${wallet.exists}`
    );
  }

  // ------------------------------------------------------------------
  // Scenario 3 — N-1 DIRECTION B: top-up first, then order.
  // This is the direction that did not exist as a check at all before FIX-1:
  // the wallet is credited, and the same payment must no longer buy goods.
  // ------------------------------------------------------------------
  {
    const uid = "phase25-dirB-user";
    const productId = "phase25-dirB-product";
    const orderId = "order_phase25_dirB";
    const paymentId = "pay_phase25_dirB";
    const amount = 500;
    await seedUser(uid);
    await seedProduct(productId, "phase25-dirB-seller", amount, 50);
    await seedRazorpayOrder(orderId, uid, amount);
    // Seeded deliberately, with NO consumedBy* marker: this is what a payment
    // looks like after verifyRazorpayPayment has run but before anything has
    // spent it. Without this seed the scenario is vacuous under revert-and-
    // watch — the pre-fix wallet.ts never creates verified_payments, so
    // createOrder would bail at "Payment could not be verified" (a missing
    // document) instead of demonstrating the double-spend. With it, the
    // reverted build creates the order AND keeps the wallet credit, which is
    // the N-1 exploit itself.
    await seedVerifiedPayment(paymentId, orderId, uid, amount);
    mockCaptured(paymentId, amount, orderId);

    const topup = await callTopup(
      { amount, paymentId, orderId, signature: computeSignature(orderId, paymentId) },
      { uid, token: {} }
    );
    const orderResult = await callCreateOrder(orderPayload(productId, paymentId, orderId), {
      uid,
      token: {},
    });
    const orders = await db.collection("orders").where("userId", "==", uid).get();
    const s =
      topup.ok &&
      !orderResult.ok &&
      orderResult.code === "failed-precondition" &&
      orderResult.message.toLowerCase().includes("wallet top-up") &&
      orders.empty;
    record(
      "scenario3_N1_topup_consumed_payment_cannot_create_order",
      s,
      `topup.ok=${topup.ok} order.code=${orderResult.code} order.msg="${orderResult.message}" ordersCreated=${orders.size}`
    );
  }

  // ------------------------------------------------------------------
  // Scenario 4 — N-1 DIRECTION C: top-up first, then onboarding activation.
  // The third path. performOnboardingActivation must refuse with the new
  // payment_already_consumed_by_wallet_topup code.
  // ------------------------------------------------------------------
  {
    const uid = "phase25-dirC-user";
    const orderId = "order_phase25_dirC";
    const paymentId = "pay_phase25_dirC";
    const amount = 500;
    await seedUser(uid);
    await seedRazorpayOrder(orderId, uid, amount);
    await db.collection("settings").doc("associate_onboarding").set(ONBOARDING_CONFIG);
    await db.collection("employees").doc(uid).set({
      uid,
      name: "Phase25 Associate",
      email: `${uid}@phase25-test.example`,
      phone: "9999999999",
      employeeCode: "PH25DC",
      status: "pending",
      commissionRate: 0,
      createdBy: "self",
    });
    // Same reason as scenario 3: seeded with no consumedBy* marker so that the
    // reverted build reaches activationCore's real consumption checks and
    // ACTIVATES onboarding off an already-spent payment, rather than stopping
    // early at payment_not_found.
    await seedVerifiedPayment(paymentId, orderId, uid, amount);
    mockCaptured(paymentId, amount, orderId);

    const topup = await callTopup(
      { amount, paymentId, orderId, signature: computeSignature(orderId, paymentId) },
      { uid, token: {} }
    );
    const activation = await performOnboardingActivation({
      db,
      uid,
      paymentId,
      source: "client",
    });
    const employee = await db.collection("employees").doc(uid).get();
    const s =
      topup.ok &&
      activation.ok === false &&
      activation.failureCode === "payment_already_consumed_by_wallet_topup" &&
      employee.data().onboardingPaid !== true;
    record(
      "scenario4_N1_topup_consumed_payment_cannot_activate_onboarding",
      s,
      `topup.ok=${topup.ok} activation.failureCode=${activation.failureCode} onboardingPaid=${employee.data()?.onboardingPaid}`
    );
  }

  // ------------------------------------------------------------------
  // Scenario 5 — N-6: cross-user binding.
  // The razorpay_orders document names userA. userB holds a valid
  // (orderId, paymentId, signature) triple and must NOT be able to credit
  // their own wallet with it.
  // ------------------------------------------------------------------
  {
    const payer = "phase25-n6-payer";
    const attacker = "phase25-n6-attacker";
    const orderId = "order_phase25_n6";
    const paymentId = "pay_phase25_n6";
    const amount = 2000;
    await seedUser(payer);
    await seedUser(attacker);
    await seedRazorpayOrder(orderId, payer, amount);
    mockCaptured(paymentId, amount, orderId);

    const r = await callTopup(
      { amount, paymentId, orderId, signature: computeSignature(orderId, paymentId) },
      { uid: attacker, token: {} }
    );
    const attackerWallet = await db.collection("wallets").doc(attacker).get();
    const s = !r.ok && r.code === "permission-denied" && !attackerWallet.exists;
    record(
      "scenario5_N6_cross_user_payment_cannot_credit_attacker_wallet",
      s,
      `code=${r.code} msg="${r.message}" attackerWalletCreated=${attackerWallet.exists}`
    );
  }

  // ------------------------------------------------------------------
  // Scenario 6 — N-6: no ownership evidence at all.
  // Neither razorpay_orders/{orderId} nor verified_payments/{paymentId} names
  // an owner. "No evidence of ownership" must not read as "owned by whoever
  // asked" — that permissiveness WAS the N-6 hole.
  // ------------------------------------------------------------------
  {
    const uid = "phase25-n6-orphan";
    const orderId = "order_phase25_orphan";
    const paymentId = "pay_phase25_orphan";
    const amount = 750;
    await seedUser(uid);
    mockCaptured(paymentId, amount, orderId);

    const r = await callTopup(
      { amount, paymentId, orderId, signature: computeSignature(orderId, paymentId) },
      { uid, token: {} }
    );
    const wallet = await db.collection("wallets").doc(uid).get();
    const s = !r.ok && r.code === "failed-precondition" && !wallet.exists;
    record(
      "scenario6_N6_no_ownership_evidence_is_refused",
      s,
      `code=${r.code} msg="${r.message}" walletCreated=${wallet.exists}`
    );
  }

  console.log("\n=== SUMMARY ===");
  const total = Object.keys(results).length;
  const passed = Object.values(results).filter(Boolean).length;
  for (const [k, v] of Object.entries(results)) {
    console.log(`  ${v ? "PASS" : "FAIL"}  ${k}`);
  }
  console.log(`\n${passed}/${total} scenarios passed`);
  if (!allPassed) {
    console.error("PHASE 25: FAILED");
    process.exit(1);
  }
  console.log("PHASE 25: ALL PASSED");
  process.exit(0);
}

main().catch((e) => {
  console.error("PHASE 25: harness error", e);
  process.exit(1);
});
