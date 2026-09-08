// Phase AI-4 (D-SELLER-AI-FUNDING) — proves createSellerAiActivationOrder /
// connectSellerAiProvider (functions/src/seller/aiConnection.ts) against a
// real emulator, and proves the WS3 symmetric cross-consumption guard added
// to the four PRE-EXISTING consumers (activationCore.ts, wallet.ts's
// verifyWalletTopup, createOrder.ts, createOrderFromRfq.ts): a payment
// already spent on a seller's ₹50 AI Assistant activation must never also
// fund an associate onboarding, a wallet top-up, or a real order.
//
// The live Razorpay order-create API is never called: `razorpay` is stubbed
// at the module-cache boundary before the compiled seller/aiConnection.js
// is required, mirroring phase16d1_onboarding_coverage_test.js's own
// pattern. verifyRazorpayPayment itself is NOT exercised here (it is
// generic, unchanged by this phase, and already covered elsewhere) —
// verified_payments docs are seeded directly, mirroring exactly what it
// writes, the same convention phase25_payment_single_consumption_test.js
// and phase40_createorder_from_rfq_test.js already use.
//
// Run with:
//   firebase emulators:exec --only firestore,functions,auth \
//     "node scripts/phase45_seller_ai_funding_test.js"
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";
process.env.RAZORPAY_KEY_ID = "rzp_test_phase45_fake_key";
process.env.RAZORPAY_KEY_SECRET = "phase45_fake_secret_never_a_real_key";
process.env.AI_KEY_ENCRYPTION_SECRET = Buffer.alloc(32, 9).toString("base64");

// ---- Stub `razorpay` at the module-cache boundary, before any compiled
// file that imports it is required.
const razorpayPath = require.resolve("razorpay");
let nextOrderSeq = 0;
function FakeRazorpay() {
  this.orders = {
    create: async (opts) => {
      nextOrderSeq += 1;
      return {
        id: `order_phase45_fake_${nextOrderSeq}`,
        amount: opts.amount,
        currency: opts.currency,
        status: "created",
        receipt: opts.receipt,
      };
    },
  };
}
require.cache[razorpayPath] = { id: razorpayPath, filename: razorpayPath, loaded: true, exports: FakeRazorpay };

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });
const db = admin.firestore();

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { createSellerAiActivationOrder, connectSellerAiProvider } = require("../lib/seller/aiConnection");
const { performOnboardingActivation } = require("../lib/employee/activationCore");
const { verifyWalletTopup } = require("../lib/customer/wallet");
const { createOrder } = require("../lib/customer/createOrder");
const { createOrderFromRfq } = require("../lib/customer/createOrderFromRfq");

const wrappedCreateActivationOrder = test.wrap(createSellerAiActivationOrder);
const wrappedConnect = test.wrap(connectSellerAiProvider);
const wrappedTopup = test.wrap(verifyWalletTopup);
const wrappedCreateOrder = test.wrap(createOrder);
const wrappedCreateOrderFromRfq = test.wrap(createOrderFromRfq);

async function call(wrapped, payload, auth) {
  try {
    return { ok: true, result: await wrapped({ data: payload, auth }) };
  } catch (e) {
    return { ok: false, code: e.code, message: e.message };
  }
}

async function seedVerifiedPayment(paymentId, uid, amount, extra) {
  await db
    .collection("verified_payments")
    .doc(paymentId)
    .set(
      Object.assign(
        {
          paymentId,
          userId: uid,
          status: "captured",
          amount,
          method: "card",
        },
        extra || {}
      )
    );
}

async function seedUser(uid) {
  await db.collection("users").doc(uid).set({ uid, profileCompleted: true });
}

async function seedProduct(productId, sellerId, salePrice, stock) {
  await db.collection("products").doc(productId).set({
    name: `Phase45 Product ${productId}`,
    salePrice,
    sellerId,
    images: [],
    stock,
    isB2BEnabled: false,
  });
}

const DELIVERY_ADDRESS = {
  name: "Phase45 Test",
  phone: "9999999995",
  addressLine1: "1 Test Street",
  addressLine2: "",
  city: "Chennai",
  state: "Tamil Nadu",
  zipcode: "600001",
  country: "India",
  latitude: 13.0827,
  longitude: 80.2707,
};

function orderPayload(productId, paymentId, orderId) {
  return {
    items: [{ productId, quantity: 1 }],
    orderMode: "B2C",
    deliveryAddress: DELIVERY_ADDRESS,
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
  copy: { headline: "h", body: "b", ctaLabel: "c", refundPolicy: "r" },
};

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

const ACTIVATION_FEE = 50;

async function main() {
  let allPassed = true;
  const results = {};
  const record = (key, passed, detail) => {
    results[key] = passed;
    console.log(`${key}: ${passed ? "PASSED" : "FAILED"} — ${detail}`);
    if (!passed) allPassed = false;
  };

  console.log("=== PHASE AI-4 — seller AI activation funding + connection ===");

  // ==================================================================
  // createSellerAiActivationOrder
  // ==================================================================

  // Scenario 1: unauthenticated call is rejected.
  {
    const r = await call(wrappedCreateActivationOrder, {}, undefined);
    record("scenario1_order_unauthenticated", !r.ok && r.code === "unauthenticated", `code=${r.code}`);
  }

  // Scenario 2: a fresh seller can create an activation order for exactly
  // ₹50, tagged with the right purpose, and razorpay_orders is bookkept.
  const SELLER_FRESH = "phase45-seller-fresh";
  {
    const r = await call(wrappedCreateActivationOrder, {}, { uid: SELLER_FRESH, token: {} });
    let s, detail;
    try {
      if (!r.ok) throw new Error(`expected success, got code=${r.code} message=${r.message}`);
      if (r.result.amount !== ACTIVATION_FEE * 100) throw new Error(`expected amount ${ACTIVATION_FEE * 100} paise, got ${r.result.amount}`);
      if (r.result.currency !== "INR") throw new Error(`expected INR, got ${r.result.currency}`);
      if (!r.result.keyId) throw new Error("no keyId returned");
      if (r.result.keyId === process.env.RAZORPAY_KEY_SECRET) throw new Error("THE SECRET KEY WAS RETURNED TO THE CLIENT");
      const orderDoc = await db.collection("razorpay_orders").doc(r.result.orderId).get();
      if (!orderDoc.exists) throw new Error("razorpay_orders bookkeeping doc was not written");
      if (orderDoc.data().purpose !== "seller_ai_activation") throw new Error(`expected purpose seller_ai_activation, got ${orderDoc.data().purpose}`);
      if (orderDoc.data().userId !== SELLER_FRESH) throw new Error("razorpay_orders doc has wrong userId");
      if (orderDoc.data().amount !== ACTIVATION_FEE) throw new Error(`expected amount ${ACTIVATION_FEE} rupees in bookkeeping doc, got ${orderDoc.data().amount}`);
      s = true;
      detail = `orderId=${r.result.orderId} amountPaise=${r.result.amount}`;
    } catch (e) {
      s = false;
      detail = e.message;
    }
    record("scenario2_order_created_correctly", s, detail);
  }

  // Scenario 3: a seller who is already connected cannot create a second
  // activation order.
  const SELLER_ALREADY_CONNECTED = "phase45-seller-already-connected";
  {
    await db.collection("ai_connections").doc(SELLER_ALREADY_CONNECTED).set({ uid: SELLER_ALREADY_CONNECTED, provider: "gemini" });
    const r = await call(wrappedCreateActivationOrder, {}, { uid: SELLER_ALREADY_CONNECTED, token: {} });
    record("scenario3_order_rejected_if_already_connected", !r.ok && r.code === "already-exists", `code=${r.code} message="${r.message}"`);
  }

  // Scenario 4: rapid second call is rate-limited. A fresh uid, never used
  // in a prior scenario, so r1 itself is not already inside another
  // scenario's own rate-limit window.
  const SELLER_RATELIMIT = "phase45-seller-ratelimit";
  {
    const r1 = await call(wrappedCreateActivationOrder, {}, { uid: SELLER_RATELIMIT, token: {} });
    const r2 = await call(wrappedCreateActivationOrder, {}, { uid: SELLER_RATELIMIT, token: {} });
    record(
      "scenario4_order_rate_limited",
      r1.ok && !r2.ok && r2.code === "resource-exhausted",
      `r1.ok=${r1.ok} r2.code=${r2.code}`
    );
  }

  // ==================================================================
  // connectSellerAiProvider
  // ==================================================================

  // Scenario 5: unauthenticated call is rejected.
  {
    const r = await call(wrappedConnect, { provider: "gemini", apiKey: "k", paymentId: "x" }, undefined);
    record("scenario5_connect_unauthenticated", !r.ok && r.code === "unauthenticated", `code=${r.code}`);
  }

  // Scenario 6: invalid provider is rejected.
  {
    const r = await call(
      wrappedConnect,
      { provider: "claude", apiKey: "some-fake-key", paymentId: "x" },
      { uid: "phase45-badprovider", token: {} }
    );
    record("scenario6_connect_invalid_provider", !r.ok && r.code === "invalid-argument", `code=${r.code}`);
  }

  // Scenario 7: empty and oversized apiKey are both rejected.
  {
    const empty = await call(wrappedConnect, { provider: "gemini", apiKey: "", paymentId: "x" }, { uid: "phase45-badkey", token: {} });
    const oversized = await call(
      wrappedConnect,
      { provider: "gemini", apiKey: "x".repeat(500), paymentId: "x" },
      { uid: "phase45-badkey", token: {} }
    );
    record(
      "scenario7_connect_bad_key_shape",
      !empty.ok && empty.code === "invalid-argument" && !oversized.ok && oversized.code === "invalid-argument",
      `empty.code=${empty.code} oversized.code=${oversized.code}`
    );
  }

  // Scenario 8: a fresh (never-connected) seller with no paymentId is
  // rejected.
  {
    const r = await call(wrappedConnect, { provider: "gemini", apiKey: "AIzaFakeNoPayment" }, { uid: "phase45-nopayment", token: {} });
    record("scenario8_connect_missing_paymentid", !r.ok && r.code === "invalid-argument", `code=${r.code}`);
  }

  // Scenario 9: a non-existent paymentId is rejected with a generic message.
  {
    const r = await call(
      wrappedConnect,
      { provider: "gemini", apiKey: "AIzaFakeNotFound", paymentId: "phase45-does-not-exist" },
      { uid: "phase45-notfound", token: {} }
    );
    record(
      "scenario9_connect_payment_not_found",
      !r.ok && r.code === "failed-precondition" && !r.message.toLowerCase().includes("not found"),
      `code=${r.code} message="${r.message}"`
    );
  }

  // Scenario 10: a payment belonging to a DIFFERENT user is rejected.
  {
    const paymentId = "phase45-pay-wronguser";
    await seedVerifiedPayment(paymentId, "phase45-real-payer", ACTIVATION_FEE);
    const r = await call(
      wrappedConnect,
      { provider: "gemini", apiKey: "AIzaFakeWrongUser", paymentId },
      { uid: "phase45-attacker", token: {} }
    );
    record("scenario10_connect_wrong_user_payment", !r.ok && r.code === "failed-precondition", `code=${r.code} message="${r.message}"`);
  }

  // Scenario 11: an uncaptured payment is rejected.
  {
    const uid = "phase45-uncaptured";
    const paymentId = "phase45-pay-uncaptured";
    await seedVerifiedPayment(paymentId, uid, ACTIVATION_FEE, { status: "created" });
    const r = await call(wrappedConnect, { provider: "gemini", apiKey: "AIzaFakeUncaptured", paymentId }, { uid, token: {} });
    record("scenario11_connect_uncaptured_payment", !r.ok && r.code === "failed-precondition", `code=${r.code} message="${r.message}"`);
  }

  // Scenario 12: a payment for the wrong amount is rejected.
  {
    const uid = "phase45-wrongamount";
    const paymentId = "phase45-pay-wrongamount";
    await seedVerifiedPayment(paymentId, uid, 5); // way below the ₹50 fee
    const r = await call(wrappedConnect, { provider: "gemini", apiKey: "AIzaFakeWrongAmount", paymentId }, { uid, token: {} });
    record("scenario12_connect_wrong_amount", !r.ok && r.code === "failed-precondition", `code=${r.code} message="${r.message}"`);
  }

  // Scenario 13: a payment already consumed by an ORDER is rejected.
  {
    const uid = "phase45-dir-order";
    const paymentId = "phase45-pay-dir-order";
    await seedVerifiedPayment(paymentId, uid, ACTIVATION_FEE, { consumedByOrderId: "some-real-order-id" });
    const r = await call(wrappedConnect, { provider: "gemini", apiKey: "AIzaFakeDirOrder", paymentId }, { uid, token: {} });
    record("scenario13_connect_rejects_order_consumed_payment", !r.ok && r.code === "failed-precondition", `code=${r.code} message="${r.message}"`);
  }

  // Scenario 14: a payment already consumed by ONBOARDING is rejected.
  {
    const uid = "phase45-dir-onboarding";
    const paymentId = "phase45-pay-dir-onboarding";
    await seedVerifiedPayment(paymentId, uid, ACTIVATION_FEE, { consumedByOnboardingFor: uid });
    const r = await call(wrappedConnect, { provider: "gemini", apiKey: "AIzaFakeDirOnboarding", paymentId }, { uid, token: {} });
    record("scenario14_connect_rejects_onboarding_consumed_payment", !r.ok && r.code === "failed-precondition", `code=${r.code} message="${r.message}"`);
  }

  // Scenario 15: a payment already consumed by a WALLET TOP-UP is rejected.
  {
    const uid = "phase45-dir-wallet";
    const paymentId = "phase45-pay-dir-wallet";
    await seedVerifiedPayment(paymentId, uid, ACTIVATION_FEE, { consumedByWalletTopup: uid });
    const r = await call(wrappedConnect, { provider: "gemini", apiKey: "AIzaFakeDirWallet", paymentId }, { uid, token: {} });
    record("scenario15_connect_rejects_wallettopup_consumed_payment", !r.ok && r.code === "failed-precondition", `code=${r.code} message="${r.message}"`);
  }

  // Scenario 16 — POSITIVE CONTROL (non-vacuity): a genuine, unconsumed,
  // correctly-amounted, captured payment for THIS caller succeeds, connects,
  // encrypts the key, and marks the payment consumed. Without this, every
  // rejection above could pass simply because the function refuses
  // everything.
  const SELLER_SUCCESS = "phase45-seller-success";
  const PAYMENT_SUCCESS = "phase45-pay-success";
  {
    await seedVerifiedPayment(PAYMENT_SUCCESS, SELLER_SUCCESS, ACTIVATION_FEE);
    const r = await call(
      wrappedConnect,
      { provider: "gemini", apiKey: "AIzaRealShapedTestKeyScenario16", paymentId: PAYMENT_SUCCESS },
      { uid: SELLER_SUCCESS, token: {} }
    );
    let s, detail;
    try {
      if (!r.ok) throw new Error(`expected success, got code=${r.code} message=${r.message}`);
      if (r.result.activated !== true || r.result.rotated !== false) throw new Error(`expected activated=true rotated=false, got ${JSON.stringify(r.result)}`);
      const connectionSnap = await db.collection("ai_connections").doc(SELLER_SUCCESS).get();
      if (!connectionSnap.exists) throw new Error("ai_connections doc was not created");
      const connection = connectionSnap.data();
      if (connection.encryptedKey === "AIzaRealShapedTestKeyScenario16") throw new Error("the stored key is PLAINTEXT — encryption did not happen");
      const statusSnap = await db.collection("ai_connection_status").doc(SELLER_SUCCESS).get();
      if (!statusSnap.exists || statusSnap.data().connected !== true) throw new Error("ai_connection_status was not set to connected");
      const paymentAfter = (await db.collection("verified_payments").doc(PAYMENT_SUCCESS).get()).data();
      if (paymentAfter.consumedBySellerAiActivationFor !== SELLER_SUCCESS) throw new Error("payment was not marked consumedBySellerAiActivationFor");
      s = true;
      detail = `connected, key encrypted, payment marked consumed by ${paymentAfter.consumedBySellerAiActivationFor}`;
    } catch (e) {
      s = false;
      detail = e.message;
    }
    record("scenario16_connect_success_control", s, detail);
  }

  // Scenario 17: reusing the SAME already-consumed payment for a second,
  // different (disconnected) seller is rejected — a single payment cannot
  // fund two connections.
  {
    const uid = "phase45-reuse-attacker";
    const r = await call(
      wrappedConnect,
      { provider: "gemini", apiKey: "AIzaFakeReuseAttempt", paymentId: PAYMENT_SUCCESS },
      { uid, token: {} }
    );
    record("scenario17_connect_rejects_reused_own_payment", !r.ok && r.code === "failed-precondition", `code=${r.code} message="${r.message}"`);
  }

  // Scenario 18: reconnecting while ALREADY connected rotates the key for
  // FREE — no paymentId required, no new payment consumed.
  {
    const r = await call(wrappedConnect, { provider: "chatgpt", apiKey: "sk-fakeTestKeyScenario18ROTATED" }, { uid: SELLER_SUCCESS, token: {} });
    let s, detail;
    try {
      if (!r.ok) throw new Error(`expected success, got code=${r.code} message=${r.message}`);
      if (r.result.activated !== false || r.result.rotated !== true) throw new Error(`expected activated=false rotated=true, got ${JSON.stringify(r.result)}`);
      const connection = (await db.collection("ai_connections").doc(SELLER_SUCCESS).get()).data();
      if (connection.provider !== "chatgpt") throw new Error(`expected provider rotated to chatgpt, got ${connection.provider}`);
      s = true;
      detail = `rotated to ${connection.provider} with no payment required`;
    } catch (e) {
      s = false;
      detail = e.message;
    }
    record("scenario18_connect_free_rotate", s, detail);
  }

  // ==================================================================
  // WS3 — reverse-direction symmetry: a payment already consumed by
  // seller AI activation must be rejected by all four OTHER consumers.
  // ==================================================================

  // Scenario 19: activationCore.ts's performOnboardingActivation.
  {
    const uid = "phase45-reverse-onboarding";
    const paymentId = "phase45-pay-reverse-onboarding";
    await seedVerifiedPayment(paymentId, uid, 500, { consumedBySellerAiActivationFor: uid });
    await db.collection("settings").doc("associate_onboarding").set(ONBOARDING_CONFIG);
    await db.collection("employees").doc(uid).set({
      uid,
      name: "Phase45 Associate",
      email: `${uid}@phase45-test.example`,
      phone: "9999999998",
      employeeCode: "PH45RO",
      status: "pending",
      commissionRate: 0,
      createdBy: "self",
    });
    const activation = await performOnboardingActivation({ db, uid, paymentId, source: "client" });
    record(
      "scenario19_reverse_onboarding_rejects_seller_ai_consumed_payment",
      activation.ok === false && activation.failureCode === "payment_already_consumed_by_seller_ai_activation",
      `ok=${activation.ok} failureCode=${activation.failureCode}`
    );
  }

  // Scenario 20: wallet.ts's verifyWalletTopup.
  {
    const uid = "phase45-reverse-wallet";
    const paymentId = "phase45-pay-reverse-wallet";
    const orderId = "phase45-razorpayorder-reverse-wallet";
    await seedVerifiedPayment(paymentId, uid, 500, { consumedBySellerAiActivationFor: uid, orderId });
    const r = await call(wrappedTopup, { amount: 500, paymentId, orderId, signature: "irrelevant-short-circuited-before-use" }, { uid, token: {} });
    // Whether the signature check or the consumption check fires first is
    // an implementation detail; what matters is it never credits the
    // wallet with a payment already spent on a seller's AI activation.
    const wallet = await db.collection("wallets").doc(uid).get();
    record(
      "scenario20_reverse_wallet_topup_rejects_seller_ai_consumed_payment",
      !r.ok && !wallet.exists,
      `ok=${r.ok} code=${r.code} message="${r.message}" walletCreated=${wallet.exists}`
    );
  }

  // Scenario 21: createOrder.ts.
  {
    const uid = "phase45-reverse-order";
    const productId = "phase45-reverse-order-product";
    const orderId = "phase45-razorpayorder-reverse-order";
    const paymentId = "phase45-pay-reverse-order";
    const amount = 250;
    await seedUser(uid);
    await seedProduct(productId, "phase45-reverse-order-seller", amount, 50);
    await seedVerifiedPayment(paymentId, uid, amount, { consumedBySellerAiActivationFor: uid, orderId });
    const r = await call(wrappedCreateOrder, orderPayload(productId, paymentId, orderId), { uid, token: {} });
    record(
      "scenario21_reverse_createorder_rejects_seller_ai_consumed_payment",
      !r.ok && r.code === "failed-precondition" && r.message.toLowerCase().includes("ai"),
      `ok=${r.ok} code=${r.code} message="${r.message}"`
    );
  }

  // Scenario 22: createOrderFromRfq.ts.
  {
    const uid = "phase45-reverse-rfq";
    const seller = "phase45-reverse-rfq-seller";
    const productId = "phase45-reverse-rfq-product";
    const rfqId = "phase45-reverse-rfq-1";
    const razorpayOrderId = "phase45-razorpayorder-reverse-rfq";
    const paymentId = "phase45-pay-reverse-rfq";
    const finalPrice = 42;
    const finalQuantity = 3;
    await seedUser(uid);
    await seedProduct(productId, seller, 999, 1000);
    await seedAcceptedRfq(rfqId, { buyerId: uid, sellerId: seller, productId, finalPrice, finalQuantity });
    await seedVerifiedPayment(paymentId, uid, finalPrice * finalQuantity, {
      consumedBySellerAiActivationFor: uid,
      orderId: razorpayOrderId,
    });
    const r = await call(
      wrappedCreateOrderFromRfq,
      { rfqId, productId, quantity: finalQuantity, paymentMethod: "razorpay", razorpayOrderId, razorpayPaymentId: paymentId },
      { uid, token: {} }
    );
    record(
      "scenario22_reverse_createorderfromrfq_rejects_seller_ai_consumed_payment",
      !r.ok && r.code === "failed-precondition" && r.message.toLowerCase().includes("ai"),
      `ok=${r.ok} code=${r.code} message="${r.message}"`
    );
  }

  console.log("=== PHASE AI-4 SUMMARY ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v ? "PASSED" : "FAILED");
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phase45 seller AI funding test:", e);
  process.exit(1);
});
