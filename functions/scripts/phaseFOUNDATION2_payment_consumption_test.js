// Actual economic handlers on a fresh loopback Firestore emulator. Payment
// provider calls are fixture-only; AI connection tests only encrypt locally.
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
if (!/^(127\.0\.0\.1|localhost|\[::1\]):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST || "")) {
  throw new Error("A loopback Firestore emulator is required");
}
process.env.GCLOUD_PROJECT = "demo-agrimore-foundation";
process.env.FUNCTIONS_EMULATOR = "false";
process.env.RAZORPAY_KEY_ID = "rzp_test_foundation2_fixture";
process.env.RAZORPAY_KEY_SECRET = "foundation2_fixture_not_a_provider_credential";
process.env.AI_KEY_ENCRYPTION_SECRET = Buffer.alloc(32, 9).toString("base64");
const providerPayments = new Map();
require("axios").get = async url => {
  const id = url.split("/").at(-1);
  if (!providerPayments.has(id)) throw new Error("Unexpected provider request blocked");
  return { data: providerPayments.get(id) };
};
const admin = require("firebase-admin");
admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT });
const db = admin.firestore();
// Pin the fixture transport before testing production-shaped environment
// flags. Clearing the authority flag must never redirect test data to cloud.
db.settings({ host: process.env.FIRESTORE_EMULATOR_HOST, ssl: false });
const fft = require("firebase-functions-test")({ projectId: process.env.GCLOUD_PROJECT });
const goods = fft.wrap(require("../lib/customer/createOrder").createOrder);
const rfq = fft.wrap(require("../lib/customer/createOrderFromRfq").createOrderFromRfq);
const wallet = fft.wrap(require("../lib/customer/wallet").verifyWalletTopup);
const seller = fft.wrap(require("../lib/seller/aiConnection").connectSellerAiProvider);
const { performOnboardingActivation } = require("../lib/employee/activationCore");
let seq = 0, passed = 0, failed = 0;
const address = { name: "Fixture", phone: "9999999999", addressLine1: "Fixture", city: "Chennai", state: "TN", zipcode: "600001", country: "India" };
async function scenario(name, body) {
  process.env.FUNCTIONS_EMULATOR = "false";
  try { await body(); passed++; console.log(`PASS ${name}`); }
  catch (e) { failed++; console.log(`FAIL ${name}: ${e.message}`); }
}
async function fixture(kind, overrides = {}, { noRecord = false } = {}) {
  const n = ++seq, uid = `foundation2-${kind}-${n}`, productId = `foundation2-product-${n}`, rfqId = `foundation2-rfq-${n}`;
  const amount = kind === "associate" ? 500 : kind === "seller" ? 50 : 100;
  const paymentId = overrides.paymentId || `pay_foundation2_${n}`, orderId = overrides.orderId || `order_foundation2_${n}`;
  const auth = { uid, token: {} };
  await db.collection("users").doc(uid).set({ profileCompleted: true });
  await db.collection("products").doc(productId).set({ name: "Fixture", sellerId: uid, salePrice: amount, b2bPrice: amount, b2bMoq: 1,
    isB2BEnabled: true, stock: 10, images: [] });
  await db.collection("sellers").doc(uid).set({ status: "approved" });
  await db.collection("employees").doc(uid).set({ userId: uid, status: "pending" });
  await db.collection("rfqs").doc(rfqId).set({ buyerId: uid, sellerId: uid, productId, status: "accepted", finalPrice: amount, finalQuantity: 1 });
  await db.collection("razorpay_orders").doc(orderId).set({ orderId, userId: uid, amount, amountPaise: amount * 100, currency: "INR" });
  if (!noRecord) await db.collection("verified_payments").doc(paymentId).set({ paymentId, orderId, userId: uid, amount, currency: "INR", status: "captured", signatureVerified: true, ...overrides });
  providerPayments.set(paymentId, { id: paymentId, order_id: orderId, amount: amount * 100, currency: "INR", status: "captured", method: "upi" });
  const orderData = { paymentMethod: "razorpay", razorpayPaymentId: paymentId, razorpayOrderId: orderId, deliveryAddress: address, deliveryCharge: 0, tax: 0 };
  const call = async () => {
    if (kind === "goods") return goods({ data: { ...orderData, items: [{ productId, quantity: 1 }], orderMode: "B2C" }, auth });
    if (kind === "rfq") return rfq({ data: { ...orderData, productId, quantity: 1, rfqId }, auth });
    if (kind === "associate") return performOnboardingActivation({ db, uid, paymentId, source: "client" });
    if (kind === "seller") return seller({ data: { provider: "gemini", apiKey: "fixture-key", paymentId }, auth });
    const signature = crypto.createHmac("sha256", process.env.RAZORPAY_KEY_SECRET).update(`${orderId}|${paymentId}`).digest("hex");
    return wallet({ data: { amount, orderId, paymentId, signature }, auth });
  };
  async function economicState() {
    return {
      stock: (await db.collection("products").doc(productId).get()).data().stock,
      orders: (await db.collection("orders").where("userId", "==", uid).get()).size,
      active: (await db.collection("employees").doc(uid).get()).data().onboardingPaid === true,
      connected: (await db.collection("ai_connections").doc(uid).get()).exists,
      wallet: (await db.collection("wallets").doc(uid).get()).exists,
      topup: (await db.collection("wallet_topups").doc(paymentId).get()).exists,
    };
  }
  return { call, economicState, paymentId, orderId, amount, uid };
}
async function refused(f) {
  const before = await f.economicState();
  let result, error;
  try { result = await f.call(); } catch (e) { error = e; }
  assert.ok(error?.code || result?.ok === false, "Expected capture consumption rejection");
  assert.deepEqual(await f.economicState(), before, "Rejected payment must not change economic state");
  const payment = (await db.collection("verified_payments").doc(f.paymentId).get()).data();
  for (const marker of ["consumedByOrderId", "consumedByOnboardingFor", "consumedByWalletTopup", "consumedBySellerAiActivationFor"]) {
    assert.equal(payment?.[marker], undefined, "Rejected capture must not be marked spent");
  }
}
async function allowed(f, kind) {
  const result = await f.call(); assert.ok(result.success === true || result.ok === true);
  const state = await f.economicState();
  if (kind === "goods" || kind === "rfq") { assert.equal(state.orders, 1); assert.equal(state.stock, 9); }
  if (kind === "associate") assert.equal(state.active, true);
  if (kind === "seller") assert.equal(state.connected, true);
  if (kind === "wallet") { assert.equal(state.topup, true); assert.equal((await db.collection("wallets").doc(f.uid).get()).data().balance, f.amount); }
}

(async () => {
  await db.collection("settings").doc("associate_onboarding").set({
    isEnabled: true, feeAmount: 500, currency: "INR", feeIsOneTime: true, version: 1,
    copy: { headline: "h", feeLabel: "f", supportingStatement: "s", whyTheFeeExists: { title: "t", body: ["a"] },
      benefitGroups: [{ key: "g1", title: "G", items: ["i"] }],
      earningsExplainer: { title: "t", body: ["a"], flowSteps: ["a"], variabilityFactors: ["a"] },
      journeySteps: [{ step: 1, title: "t", body: "b" }], summaryCard: { title: "t", feeLine: "f", includes: ["i"], ctaLabel: "c", ctaSubtext: "s" },
      supportContact: { title: "t", body: "b", email: "fixture@example.com", phone: "" } },
  });
  const badRecords = [
    ["simulated record", { isTest: true }],
    ["simulated payment ID", () => ({ paymentId: `pay_test_foundation2_${seq + 1}` })],
    ["simulated order ID", () => ({ orderId: `order_test_foundation2_${seq + 1}` })],
    ["NaN amount", { amount: NaN }], ["infinite amount", { amount: Infinity }],
    ["unsafe amount", { amount: Number.MAX_VALUE }], ["foreign currency", { currency: "USD" }],
    ["failed signature", { signatureVerified: false }], ["inconsistent minor units", { amountPaise: 1 }],
  ];
  for (const kind of ["goods", "rfq", "associate", "seller", "wallet"]) {
    const expectedPurpose = { goods: "goods_checkout", rfq: "rfq_checkout", associate: "associate_onboarding", seller: "seller_ai_activation", wallet: "wallet_topup" }[kind];
    for (const purpose of ["goods_checkout", "rfq_checkout", "associate_onboarding", "seller_ai_activation", "wallet_topup", 42]) {
      await scenario(`${kind} ${purpose === expectedPurpose ? "allows" : "rejects"} explicit purpose ${purpose}`, async () => {
        const f = await fixture(kind, { purpose });
        if (purpose === expectedPurpose) await allowed(f, kind); else await refused(f);
      });
    }
    for (const [label, overrides] of badRecords) {
      await scenario(`${kind} rejects ${label}`, async () => refused(await fixture(kind, typeof overrides === "function" ? overrides() : overrides)));
    }
    await scenario(`${kind} allows ordinary INR capture`, async () => allowed(await fixture(kind), kind));
    await scenario(`${kind} allows legacy capture without currency`, async () => {
      const f = await fixture(kind); await db.collection("verified_payments").doc(f.paymentId).update({ currency: admin.firestore.FieldValue.delete() });
      await allowed(f, kind);
    });
    await scenario(`${kind} allows trusted local simulated record`, async () => {
      process.env.FUNCTIONS_EMULATOR = "true"; await allowed(await fixture(kind, { isTest: true }), kind);
    });
    await scenario(`${kind} rejects unknown provider mode`, async () => refused(await fixture(kind, { providerMode: "unknown" })));
    await scenario(`${kind} allows test provider capture in loopback storage`, async () => allowed(await fixture(kind, { providerMode: "test" }), kind));
    for (const mode of ["test", "live"]) {
      await scenario(`${kind} ${mode === "test" ? "rejects" : "allows"} provider ${mode} capture outside loopback authority`, async () => {
        const f = await fixture(kind, { providerMode: mode });
        const host = process.env.FIRESTORE_EMULATOR_HOST, keyId = process.env.RAZORPAY_KEY_ID;
        delete process.env.FIRESTORE_EMULATOR_HOST;
        process.env.RAZORPAY_KEY_ID = "rzp_live_foundation2_fixture";
        try { if (mode === "test") await refused(f); else await allowed(f, kind); }
        finally { process.env.FIRESTORE_EMULATOR_HOST = host; process.env.RAZORPAY_KEY_ID = keyId; }
      });
    }
  }
  await scenario("wallet credits genuine provider capture without prior verification record", async () => allowed(await fixture("wallet", {}, { noRecord: true }), "wallet"));
  console.log(`FOUNDATION2 payment consumption: ${passed} passed, ${failed} failed`);
  fft.cleanup(); await admin.app().delete(); process.exitCode = failed ? 1 : 0;
})().catch(e => { console.error(e.message); process.exitCode = 1; });
