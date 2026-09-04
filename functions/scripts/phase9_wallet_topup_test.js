// Phase 9, Workstream 1: proves verifyWalletTopup's signature verification,
// live-API status/amount cross-check, and idempotent crediting against a
// real emulator — not mocked Firestore, only the outbound Razorpay HTTP
// call (which cannot reach the real Razorpay API from a test). axios is a
// CommonJS singleton (see functions/lib/customer/wallet.js's
// `__importDefault(require("axios"))`), so patching require('axios').get
// here — BEFORE requiring the compiled wallet.js — intercepts the exact
// same call the function makes, since both resolve to the same
// node_modules/axios instance under Node's module cache.
// Run with: node scripts/phase9_wallet_topup_test.js
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";
process.env.RAZORPAY_KEY_ID = "rzp_test_phase9_fake_key";
process.env.RAZORPAY_KEY_SECRET = "phase9_fake_secret_never_a_real_key";

const crypto = require("crypto");
const axios = require("axios");

// Registry of mocked Razorpay payment responses, keyed by paymentId. Each
// scenario registers its own before calling the function.
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
admin.initializeApp({ projectId: "agrimore-66a4e" });

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { verifyWalletTopup } = require("../lib/customer/wallet");

const wrapped = test.wrap(verifyWalletTopup);

function computeSignature(orderId, paymentId) {
  return crypto
    .createHmac("sha256", process.env.RAZORPAY_KEY_SECRET)
    .update(`${orderId}|${paymentId}`)
    .digest("hex");
}

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

  console.log("=== PHASE 9, WORKSTREAM 1 — verifyWalletTopup ===");

  // Phase 18 fixture update (found while running a broader regression
  // sweep than any prior phase's explicit list required): verifyWalletTopup
  // has rejected an incomplete-profile caller since Phase 16, Workstream 7
  // — unrelated to what this file actually tests, so every test user here
  // is seeded profileCompleted:true up front. Purely additive, no
  // assertion below is touched.
  for (const uid of [
    "phase9-topup-customer1",
    "phase9-topup-customer2",
    "phase9-topup-customer3",
    "phase9-topup-customer4",
  ]) {
    await db.collection("users").doc(uid).set({ uid, profileCompleted: true });
  }

  // Phase FIX-1 fixture update (finding N-6), same class as the Phase 18
  // profileCompleted update noted above and made for the same reason: the
  // function grew a precondition this file's fixtures never satisfied.
  // verifyWalletTopup now requires the payment to be provably the caller's —
  // razorpay_orders/{orderId}.userId (written by createRazorpayOrder for every
  // order it creates) or verified_payments/{paymentId}.userId must name the
  // caller, and "neither exists" is a refusal rather than a pass. Without this
  // seed, scenarios 1 and 4 fail with "This payment could not be verified for
  // your account" — confirmed by running this suite against the WS1 build
  // before adding it. All four orders are seeded, not just the two that must
  // succeed, so that scenarios 2 and 3 still prove what their names claim: that
  // the refusal comes from the tampered signature and the amount mismatch
  // respectively, and NOT incidentally from missing ownership evidence.
  const PHASE9_ORDERS = [
    ["order_phase9_topup1", "phase9-topup-customer1", 1000],
    ["order_phase9_topup2", "phase9-topup-customer2", 1000],
    ["order_phase9_topup3", "phase9-topup-customer3", 500],
    ["order_phase9_topup4", "phase9-topup-customer4", 500],
  ];
  for (const [orderId, uid, amount] of PHASE9_ORDERS) {
    await db.collection("razorpay_orders").doc(orderId).set({
      orderId,
      userId: uid,
      amount,
      amountPaise: amount * 100,
      currency: "INR",
      status: "created",
    });
  }

  // Seed a non-default wallet_config so bonus computation is exercised
  // against a real Firestore read, not just the hardcoded default.
  await db.collection("settings").doc("wallet_config").set({
    topupBonuses: { "500": 25, "1000": 75, "2000": 200 },
    isCashbackEnabled: true,
    signupBonus: 50,
    isReferralEnabled: true,
    referrerBonus: 100,
    referredBonus: 50,
  });

  // Scenario 1: correctly-signed, captured, amount-matching payment for a
  // ₹1000 top-up — must credit balance +1000 and coins +75 (the 1000
  // threshold's bonus).
  {
    const uid = "phase9-topup-customer1";
    const orderId = "order_phase9_topup1";
    const paymentId = "pay_phase9_topup1";
    const amount = 1000;
    mockPayments[paymentId] = { id: paymentId, amount: amount * 100, currency: "INR", status: "captured", method: "card" };
    const signature = computeSignature(orderId, paymentId);

    const r = await callAndCapture(
      { amount, paymentId, orderId, signature },
      { uid, token: {} }
    );
    console.log("Scenario 1 raw:", JSON.stringify(r, null, 2));
    let s;
    try {
      if (!r.ok) throw new Error(`expected success, got error: code=${r.code} message=${r.message}`);
      if (r.result.bonusCoins !== 75) throw new Error(`expected bonusCoins 75, got ${r.result.bonusCoins}`);
      const walletDoc = await db.collection("wallets").doc(uid).get();
      const wallet = walletDoc.data();
      if (wallet.balance !== 1000) throw new Error(`expected wallet balance 1000, got ${wallet.balance}`);
      if (wallet.coins !== 75) throw new Error(`expected wallet coins 75, got ${wallet.coins}`);
      s = `PASSED — credited balance=${wallet.balance}, coins=${wallet.coins} (bonus=${r.result.bonusCoins})`;
    } catch (e) {
      s = `FAILED — ${e.message}`;
      allPassed = false;
    }
    results.scenario1_correct_topup = s;
    console.log("Scenario 1:", s);
  }

  // Scenario 2: tampered signature — must be rejected, wallet must NOT be
  // credited at all.
  {
    const uid = "phase9-topup-customer2";
    const orderId = "order_phase9_topup2";
    const paymentId = "pay_phase9_topup2";
    const amount = 500;
    mockPayments[paymentId] = { id: paymentId, amount: amount * 100, currency: "INR", status: "captured", method: "card" };

    const r = await callAndCapture(
      { amount, paymentId, orderId, signature: "0000tampered0000signature0000" },
      { uid, token: {} }
    );
    console.log("Scenario 2 raw:", JSON.stringify(r, null, 2));
    let s;
    try {
      if (r.ok) throw new Error("expected rejection, but the tampered-signature top-up succeeded — THIS WOULD BE FINDING #3 STILL OPEN");
      if (r.code !== "permission-denied") throw new Error(`expected code permission-denied, got ${r.code}`);
      const walletDoc = await db.collection("wallets").doc(uid).get();
      if (walletDoc.exists) throw new Error("wallet document should not have been created/credited for a rejected top-up");
      s = `PASSED — rejected as expected, no wallet credit occurred. code=${r.code} message="${r.message}"`;
    } catch (e) {
      s = `FAILED — ${e.message}`;
      allPassed = false;
    }
    results.scenario2_tampered_signature = s;
    console.log("Scenario 2:", s);
  }

  // Scenario 3: amount mismatch — claimed ₹2000, but Razorpay only captured
  // ₹500. Must be rejected.
  {
    const uid = "phase9-topup-customer3";
    const orderId = "order_phase9_topup3";
    const paymentId = "pay_phase9_topup3";
    mockPayments[paymentId] = { id: paymentId, amount: 500 * 100, currency: "INR", status: "captured", method: "card" };
    const signature = computeSignature(orderId, paymentId);

    const r = await callAndCapture(
      { amount: 2000, paymentId, orderId, signature },
      { uid, token: {} }
    );
    console.log("Scenario 3 raw:", JSON.stringify(r, null, 2));
    let s;
    if (r.ok) {
      s = "FAILED — a claimed ₹2000 top-up succeeded despite only ₹500 being captured — THIS WOULD BE A REAL FRAUD HOLE";
      allPassed = false;
    } else if (r.message !== "Captured amount does not match the requested top-up amount") {
      s = `FAILED — wrong message "${r.message}"`;
      allPassed = false;
    } else {
      s = `PASSED — rejected as expected. code=${r.code} message="${r.message}"`;
    }
    results.scenario3_amount_mismatch = s;
    console.log("Scenario 3:", s);
  }

  // Scenario 4 — THE idempotency proof: call verifyWalletTopup TWICE with
  // the exact same paymentId. The second call must not double-credit.
  {
    const uid = "phase9-topup-customer4";
    const orderId = "order_phase9_topup4";
    const paymentId = "pay_phase9_topup4";
    const amount = 500;
    mockPayments[paymentId] = { id: paymentId, amount: amount * 100, currency: "INR", status: "captured", method: "card" };
    const signature = computeSignature(orderId, paymentId);
    const payload = { amount, paymentId, orderId, signature };

    const first = await callAndCapture(payload, { uid, token: {} });
    console.log("Scenario 4 first call raw:", JSON.stringify(first, null, 2));
    const second = await callAndCapture(payload, { uid, token: {} });
    console.log("Scenario 4 second call raw:", JSON.stringify(second, null, 2));

    let s;
    try {
      if (!first.ok) throw new Error(`first call unexpectedly failed: ${first.message}`);
      if (!second.ok) throw new Error(`second call unexpectedly failed: ${second.message}`);
      if (second.result.alreadyCredited !== true) {
        throw new Error("second call did not report alreadyCredited=true");
      }
      const walletDoc = await db.collection("wallets").doc(uid).get();
      const wallet = walletDoc.data();
      // 500 -> bonus 25 (per the 500 threshold). If double-credited, balance
      // would be 1000 and coins 50 instead of 500/25.
      if (wallet.balance !== 500) throw new Error(`expected balance 500 after TWO calls with the same paymentId, got ${wallet.balance} — DOUBLE-CREDITED`);
      if (wallet.coins !== 25) throw new Error(`expected coins 25 after TWO calls with the same paymentId, got ${wallet.coins} — DOUBLE-CREDITED`);
      const topupDocs = await db.collection("wallet_topups").doc(paymentId).get();
      if (!topupDocs.exists) throw new Error("expected a wallet_topups/{paymentId} idempotency doc to exist");
      s = `PASSED — second call with the same paymentId did NOT double-credit. balance=${wallet.balance} coins=${wallet.coins} (unchanged from first call)`;
    } catch (e) {
      s = `FAILED — ${e.message}`;
      allPassed = false;
    }
    results.scenario4_idempotency = s;
    console.log("Scenario 4:", s);
  }

  console.log("=== PHASE 9 WORKSTREAM 1 SUMMARY ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phase9 wallet topup test:", e);
  process.exit(1);
});
