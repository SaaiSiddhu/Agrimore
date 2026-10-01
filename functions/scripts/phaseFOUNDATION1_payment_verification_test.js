// Actual compiled callables + local Firestore; provider calls are replaced before
// importing handlers. Refuse to run against any non-loopback database.
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
if (!/^(127\.0\.0\.1|localhost|\[::1\]):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST || "")) {
  throw new Error("This suite requires a loopback Firestore emulator");
}
process.env.GCLOUD_PROJECT = "demo-agrimore-foundation";
process.env.FUNCTIONS_EMULATOR = "false";
process.env.RAZORPAY_KEY_ID = "rzp_test_foundation_fixture";
process.env.RAZORPAY_KEY_SECRET = "foundation_fixture_not_a_provider_credential";
const fixtureSecret = process.env.RAZORPAY_KEY_SECRET;
let createMode = "normal", providerCalls = 0, seq = 0, providerPayment, duringFetch;
const razorpayPath = require.resolve("razorpay");
function FakeRazorpay() {
  this.orders = { create: async (options) => {
    providerCalls++;
    if (createMode === "failure") throw new Error("fixture provider unavailable");
    return { id: `order_foundation_created_${++seq}`, amount: options.amount + (createMode === "wrong_amount" ? 1 : 0),
      currency: createMode === "wrong_currency" ? "USD" : options.currency, status: "created", receipt: options.receipt };
  }};
}
require.cache[razorpayPath] = { id: razorpayPath, filename: razorpayPath, loaded: true, exports: FakeRazorpay };
const axios = require("axios");
axios.get = async () => {
  providerCalls++;
  if (duringFetch) await duringFetch();
  return { data: { ...providerPayment } };
};
const admin = require("firebase-admin");
admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT });
const db = admin.firestore();
const fft = require("firebase-functions-test")({ projectId: process.env.GCLOUD_PROJECT });
const payment = require("../lib/customer/payment");
const verify = fft.wrap(payment.verifyRazorpayPayment);
const create = fft.wrap(payment.createRazorpayOrder);
const createGoodsOrder = fft.wrap(require("../lib/customer/createOrder").createOrder);
const auth = { uid: "foundation-payer", token: {} };
const sign = (orderId, paymentId) => crypto.createHmac("sha256", fixtureSecret).update(`${orderId}|${paymentId}`).digest("hex");
const markers = { consumedByOrderId: "goods-order", consumedByOnboardingFor: "associate", consumedByWalletTopup: "wallet-owner",
  consumedBySellerAiActivationFor: "seller", consumedAt: admin.firestore.Timestamp.fromMillis(123456) };
let passed = 0, failed = 0;
async function scenario(name, body) {
  process.env.FUNCTIONS_EMULATOR = "false";
  process.env.RAZORPAY_KEY_ID = "rzp_test_foundation_fixture";
  process.env.RAZORPAY_KEY_SECRET = fixtureSecret;
  createMode = "normal"; duringFetch = null;
  try { await body(); passed++; console.log(`PASS ${name}`); }
  catch (e) { failed++; console.log(`FAIL ${name}: ${e.message}`); }
}
async function seed(extra = {}) {
  const orderId = `order_foundation_${++seq}`, paymentId = `pay_foundation_${seq}`;
  await db.collection("razorpay_orders").doc(orderId).set({ orderId, userId: auth.uid, amount: 100, amountPaise: 10000, currency: "INR", ...extra });
  providerPayment = { id: paymentId, order_id: orderId, amount: 10000, currency: "INR", status: "captured", method: "upi" };
  return { orderId, paymentId, signature: sign(orderId, paymentId) };
}
async function rejected(call, code) {
  await assert.rejects(call, e => (!code || e.code === code) && typeof e.code === "string");
}
const verifyCall = (data, caller = auth) => verify({ data, auth: caller });
const createCall = (data) => create({ data, auth });
const paymentRef = p => db.collection("verified_payments").doc(p.paymentId);

(async () => {
  await scenario("valid capture is bound to stored owned order", async () => {
    const p = await seed({ purpose: "seller_ai_activation" });
    assert.equal((await verifyCall(p)).verified, true);
    const saved = (await paymentRef(p).get()).data();
    assert.equal(saved.userId, auth.uid); assert.equal(saved.amount, 100);
    assert.equal(saved.purpose, "seller_ai_activation");
  });
  for (const field of ["orderId", "paymentId", "signature"]) {
    await scenario(`production rejects simulated ${field}`, async () => {
      const p = await seed();
      p[field] = field === "orderId" ? "order_test_forged" : field === "paymentId" ? "pay_test_forged" : "test_sig_forged";
      await rejected(() => verifyCall(p), "failed-precondition");
      assert.equal((await paymentRef(p).get()).exists, false);
    });
  }
  await scenario("cross-owner capture is rejected without provider call", async () => {
    const p = await seed({ userId: "other-payer" }); const before = providerCalls;
    await rejected(() => verifyCall(p), "permission-denied"); assert.equal(providerCalls, before);
    assert.equal((await paymentRef(p).get()).exists, false);
  });
  for (const field of ["missing_order", "missing_owner", "stored_order_id", "missing_amount"]) {
    await scenario(`reject ${field}`, async () => {
      const p = await seed(); const ref = db.collection("razorpay_orders").doc(p.orderId);
      if (field === "missing_order") await ref.delete();
      if (field === "missing_owner") await ref.update({ userId: admin.firestore.FieldValue.delete() });
      if (field === "stored_order_id") await ref.update({ orderId: "other-order" });
      if (field === "missing_amount") await ref.update({ amount: admin.firestore.FieldValue.delete(), amountPaise: admin.firestore.FieldValue.delete() });
      await rejected(() => verifyCall(p)); assert.equal((await paymentRef(p).get()).exists, false);
    });
  }
  for (const [field, value] of [["id", "pay_other"], ["order_id", "order_other"], ["amount", 9999], ["currency", "USD"], ["amount", "10000"]]) {
    await scenario(`provider mismatch ${field}:${value}`, async () => {
      const p = await seed(); providerPayment[field] = value;
      await rejected(() => verifyCall(p), "failed-precondition"); assert.equal((await paymentRef(p).get()).exists, false);
    });
  }
  await scenario("uncaptured matching payment remains unverified", async () => {
    const p = await seed(); providerPayment.status = "authorized";
    assert.equal((await verifyCall(p)).verified, false); assert.equal((await paymentRef(p).get()).exists, false);
  });
  await scenario("bad signature preserves legacy result and redacted security log", async () => {
    const p = await seed(); p.signature = "deliberately-wrong";
    const before = providerCalls; assert.equal((await verifyCall(p)).verified, false); assert.equal(providerCalls, before);
    const logs = await db.collection("payment_security_logs").where("paymentId", "==", p.paymentId).get();
    assert.equal(logs.size, 1); assert.equal(logs.docs[0].data().signatureMatched, false);
    assert.equal("expectedSignature" in logs.docs[0].data(), false);
  });
  for (const data of [null, { paymentId: 7, orderId: "valid", signature: "valid" }, { paymentId: "bad/path", orderId: "valid", signature: "valid" }]) {
    await scenario(`malformed input ${JSON.stringify(data)}`, async () => {
      const before = providerCalls; await rejected(() => verifyCall(data), "invalid-argument"); assert.equal(providerCalls, before);
    });
  }
  await scenario("verification retry preserves every consumption marker", async () => {
    const p = await seed(); await verifyCall(p); await paymentRef(p).update(markers);
    assert.equal((await verifyCall(p)).verified, true);
    const saved = (await paymentRef(p).get()).data();
    for (const [key, value] of Object.entries(markers)) assert.deepEqual(saved[key], value);
  });
  await scenario("consumption during provider fetch survives verification", async () => {
    const p = await seed(); await verifyCall(p);
    duringFetch = async () => paymentRef(p).update({ consumedByWalletTopup: auth.uid });
    await verifyCall(p); assert.equal((await paymentRef(p).get()).data().consumedByWalletTopup, auth.uid);
  });
  for (const existing of [{ userId: "other-payer" }, { userId: auth.uid, orderId: "other-order" }, { userId: auth.uid, orderId: null }]) {
    await scenario(`existing verified identity cannot be replaced ${JSON.stringify(existing)}`, async () => {
      const p = await seed(); await paymentRef(p).set({ paymentId: p.paymentId, orderId: p.orderId, ...existing, ...markers });
      await rejected(() => verifyCall(p)); assert.equal((await paymentRef(p).get()).data().consumedByOrderId, markers.consumedByOrderId);
    });
  }
  await scenario("order ownership mutation during provider fetch is rechecked", async () => {
    const p = await seed(); duringFetch = async () => db.collection("razorpay_orders").doc(p.orderId).update({ userId: "other-payer" });
    await rejected(() => verifyCall(p)); assert.equal((await paymentRef(p).get()).exists, false);
  });
  await scenario("verify then spend then verify cannot fund a second goods order", async () => {
    const p = await seed(); await db.collection("users").doc(auth.uid).set({ profileCompleted: true });
    const productId = `foundation_goods_${++seq}`;
    await db.collection("products").doc(productId).set({ name: "Fixture goods", salePrice: 100, sellerId: "foundation-seller", stock: 10, images: [], isB2BEnabled: false });
    const payload = { items: [{ productId, quantity: 1 }], orderMode: "B2C", paymentMethod: "razorpay", razorpayPaymentId: p.paymentId, razorpayOrderId: p.orderId,
      deliveryCharge: 0, tax: 0, deliveryAddress: { name: "Fixture", phone: "9999999999", addressLine1: "Fixture", city: "Chennai", state: "TN", zipcode: "600001", country: "India" } };
    await verifyCall(p); const first = await createGoodsOrder({ data: payload, auth }); assert.equal(first.success, true);
    await verifyCall(p); await rejected(() => createGoodsOrder({ data: payload, auth }), "failed-precondition");
    const orders = await db.collection("orders").where("razorpayPaymentId", "==", p.paymentId).get(); assert.equal(orders.size, 1);
  });
  for (const mode of ["missing_credentials", "failure", "wrong_amount", "wrong_currency"]) {
    await scenario(`production order creation fails closed ${mode}`, async () => {
      if (mode === "missing_credentials") { delete process.env.RAZORPAY_KEY_ID; delete process.env.RAZORPAY_KEY_SECRET; } else createMode = mode;
      const before = (await db.collection("razorpay_orders").get()).size;
      await rejected(() => createCall({ amount: 100 })); assert.equal((await db.collection("razorpay_orders").get()).size, before);
    });
  }
  for (const amount of [NaN, Infinity, "100", 0.001, -1, Number.MAX_VALUE]) {
    await scenario(`reject invalid amount ${String(amount)}`, async () => { await rejected(() => createCall({ amount }), "invalid-argument"); });
  }
  await scenario("real order creation stores authoritative minor units and owner", async () => {
    const result = await createCall({ amount: 10.25, notes: { userId: "forged" } });
    assert.equal(result.isTestMode, false); assert.equal(result.amount, 1025);
    const saved = (await db.collection("razorpay_orders").doc(result.orderId).get()).data();
    assert.equal(saved.amountPaise, 1025); assert.equal(saved.userId, auth.uid);
  });
  await scenario("sandbox succeeds only with trusted emulator and owned sandbox record", async () => {
    process.env.FUNCTIONS_EMULATOR = "true"; delete process.env.RAZORPAY_KEY_ID; delete process.env.RAZORPAY_KEY_SECRET;
    const result = await createCall({ amount: 100 }); assert.equal(result.isTestMode, true);
    const p = { orderId: result.orderId, paymentId: `pay_test_foundation_${++seq}`, signature: "test_sig_foundation" };
    assert.equal((await verifyCall(p)).verified, true); assert.equal((await paymentRef(p).get()).data().isTest, true);
    await paymentRef(p).update(markers); await verifyCall(p);
    assert.equal((await paymentRef(p).get()).data().consumedByOrderId, markers.consumedByOrderId);
    await rejected(() => verifyCall(p, { uid: "attacker", token: {} }));
  });
  await scenario("emulator cannot verify nonexistent sandbox order", async () => {
    process.env.FUNCTIONS_EMULATOR = "true";
    await rejected(() => verifyCall({ orderId: "order_test_missing", paymentId: "pay_test_missing", signature: "test_sig_missing" }));
  });
  await scenario("emulator cannot simulate a real stored order", async () => {
    process.env.FUNCTIONS_EMULATOR = "true"; const p = await seed(); p.signature = "test_sig_forged";
    await rejected(() => verifyCall(p));
  });
  console.log(`FOUNDATION1 payment verification: ${passed} passed, ${failed} failed`);
  fft.cleanup(); await admin.app().delete(); process.exitCode = failed ? 1 : 0;
})().catch(e => { console.error(e.message); process.exitCode = 1; });
