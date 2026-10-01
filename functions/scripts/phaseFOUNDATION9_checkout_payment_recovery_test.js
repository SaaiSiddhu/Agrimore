// Actual v2 handler and Firestore transactions. All provider IO is replaced
// before importing production handlers; loopback storage is mandatory.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
if (!/^(127\.0\.0\.1|localhost|\[::1\]):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST || "")) {
  throw new Error("Loopback Firestore emulator required");
}
process.env.GCLOUD_PROJECT = "demo-agrimore-foundation";
process.env.FUNCTIONS_EMULATOR = "false";
const fixtureKey = "rzp_test_foundation_recovery_fixture";
const fixtureSecret = "foundation_recovery_fixture_not_a_provider_credential";
let calls = [], body, duringLookup, providerFailure, seq = 0, passed = 0, failed = 0, rules;
const axios = require("axios");
axios.get = async (url, options) => {
  calls.push({ url, options });
  if (duringLookup) await duringLookup();
  if (providerFailure) throw new Error("PRIVATE_FIXTURE_PROVIDER_PAYLOAD");
  return { data: body };
};
for (const verb of ["post", "put", "patch", "delete", "request"]) {
  axios[verb] = async () => { throw new Error("Unexpected provider write/request"); };
}
const razorpayPath = require.resolve("razorpay");
function ForbiddenRazorpay() { throw new Error("Recovery must not create/capture/refund a payment"); }
require.cache[razorpayPath] = { id: razorpayPath, filename: razorpayPath, loaded: true, exports: ForbiddenRazorpay };
const admin = require("firebase-admin");
admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT });
const db = admin.firestore();
const fft = require("firebase-functions-test")({ projectId: process.env.GCLOUD_PROJECT });
const recover = fft.wrap(require("../lib/customer/recoverCheckoutPayment").recoverCheckoutPayment);
const create = fft.wrap(require("../lib/customer/createOrder").createOrder);
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const { doc, getDoc, setDoc, updateDoc, deleteDoc } = require("firebase/firestore");

async function scenario(name, test) {
  process.env.RAZORPAY_KEY_ID = fixtureKey;
  process.env.RAZORPAY_KEY_SECRET = fixtureSecret;
  process.env.FUNCTIONS_EMULATOR = "false";
  calls = []; duringLookup = null; providerFailure = false;
  try { await test(); passed++; console.log(`PASS ${name}`); }
  catch (error) { failed++; console.log(`FAIL ${name}: ${error.message}`); }
}
async function fixture(extra = {}) {
  const n = ++seq, uid = `foundation9-owner-${n}`, orderId = `order_foundation9_${n}`, paymentId = `pay_foundation9_${n}`;
  const auth = { uid, token: {} };
  const orderRef = db.collection("razorpay_orders").doc(orderId);
  const paymentRef = db.collection("verified_payments").doc(paymentId);
  await orderRef.set({ userId: uid, orderId, amount: 100, amountPaise: 10000,
    currency: "INR", purpose: "goods_checkout", providerMode: "test", isTestOrder: false, ...extra });
  body = { entity: "collection", count: 1, items: [{ entity: "payment", id: paymentId,
    order_id: orderId, amount: 10000, currency: "INR", status: "captured", captured: true,
    amount_refunded: 0, refund_status: null, email: "PRIVATE_FIXTURE_PII", contact: "PRIVATE_FIXTURE_PII",
    vpa: "PRIVATE_FIXTURE_PII", method: "upi" }] };
  const input = { orderId, checkoutOwnerId: uid };
  const call = (data = input, caller = auth) => recover({ data, auth: caller });
  const verified = { userId: uid, orderId, paymentId, amount: 100, amountPaise: 10000,
    currency: "INR", purpose: "goods_checkout", providerMode: "test", status: "captured" };
  return { uid, auth, orderId, paymentId, input, call, orderRef, paymentRef, verified };
}
async function refuses(f, code = "failed-precondition", callback = () => f.call()) {
  const before = (await f.paymentRef.get()).data();
  await assert.rejects(callback, error => error.code === code);
  assert.deepEqual((await f.paymentRef.get()).data(), before, "Refusal must preserve existing payment exactly");
}
const markers = { consumedByOrderId: "original-goods-order", consumedByWalletTopup: "wallet-owner",
  consumedByOnboardingFor: "associate-owner", consumedBySellerAiActivationFor: "seller-owner",
  consumedByRfqOrderId: "rfq-order", consumedAt: admin.firestore.Timestamp.fromMillis(123456),
  unfamiliarFutureConsumptionMarker: { id: "future" } };

(async () => {
  await scenario("valid lost callback recovers exact capture without claiming SDK signature", async () => {
    const f = await fixture(), result = await f.call();
    assert.deepEqual(result, { success: true, verified: true, outcome: "captured", orderId: f.orderId,
      paymentId: f.paymentId, amountPaise: 10000, currency: "INR" });
    const saved = (await f.paymentRef.get()).data();
    assert.equal(saved.providerCaptureVerified, true);
    assert.equal(saved.verificationMethod, "provider_api_recovery");
    assert.equal("signatureVerified" in saved, false);
    assert.equal(saved.userId, f.uid); assert.equal(saved.amount, 100);
    assert.equal(JSON.stringify(result).includes("PRIVATE_FIXTURE"), false);
    assert.equal(JSON.stringify(saved).includes("PRIVATE_FIXTURE"), false);
    assert.equal(calls.length, 1); assert.equal(calls[0].url, `https://api.razorpay.com/v1/orders/${f.orderId}/payments`);
    assert.equal(calls[0].options.timeout, 15000); assert.equal(calls[0].options.maxContentLength, 262144);
    assert.equal(calls[0].options.maxRedirects, 0);
    assert.equal(calls[0].options.auth.username, fixtureKey); assert.equal(calls[0].options.auth.password, fixtureSecret);
  });
  await scenario("live-key tuple uses real-shaped provider capture in isolated storage", async () => {
    const f = await fixture({ providerMode: "live" }); process.env.RAZORPAY_KEY_ID = "rzp_live_foundation_fake_fixture";
    assert.equal((await f.call()).verified, true);
    assert.equal((await f.paymentRef.get()).data().providerMode, "live");
  });
  await scenario("recovery merges and preserves every existing consumption marker and SDK proof", async () => {
    const f = await fixture(); await f.paymentRef.set({ ...f.verified, ...markers, signatureVerified: true });
    await f.call(); const saved = (await f.paymentRef.get()).data();
    assert.equal(saved.signatureVerified, true);
    for (const [key, value] of Object.entries(markers)) assert.deepEqual(saved[key], value);
  });
  await scenario("consumption racing provider lookup survives transaction merge", async () => {
    const f = await fixture(); await f.call();
    duringLookup = () => f.paymentRef.update(markers);
    await f.call(); const saved = (await f.paymentRef.get()).data();
    for (const [key, value] of Object.entries(markers)) assert.deepEqual(saved[key], value);
  });
  await scenario("concurrent recovery converges on one capture document", async () => {
    const f = await fixture(); const results = await Promise.all([f.call(), f.call(), f.call()]);
    for (const result of results) assert.deepEqual(result, results[0]);
    assert.equal((await f.paymentRef.get()).data().paymentId, f.paymentId);
  });
  await scenario("unauthenticated lookup never calls provider", async () => {
    const f = await fixture(); await refuses(f, "unauthenticated", () => f.call(f.input, null));
    assert.equal(calls.length, 0);
  });
  await scenario("different stored owner denied before provider lookup", async () => {
    const f = await fixture({ userId: "other-owner" }); await refuses(f, "permission-denied"); assert.equal(calls.length, 0);
  });
  await scenario("auth transport token switch denied before provider lookup", async () => {
    const f = await fixture(); await refuses(f, "permission-denied", () => f.call(f.input, { uid: "other-owner", token: {} }));
    assert.equal(calls.length, 0);
  });
  for (const input of [null, {}, { orderId: "safe" }, { orderId: "bad/path", checkoutOwnerId: "owner" },
    { orderId: "safe", checkoutOwnerId: 42 }, { orderId: "a".repeat(201), checkoutOwnerId: "owner" }]) {
    await scenario("malformed recovery input refused", async () => {
      const f = await fixture(); await refuses(f, "invalid-argument", () => f.call(input)); assert.equal(calls.length, 0);
    });
  }
  for (const extra of [{ purpose: "wallet_topup" }, { purpose: "associate_onboarding" },
    { purpose: "seller_ai_activation" }, { purpose: "rfq_checkout" }, { purpose: null },
    { providerMode: null }, { providerMode: "live" }, { currency: "USD" }, { amount: NaN },
    { amount: 100.001 }, { amountPaise: 9999 }, { amountPaise: Number.MAX_VALUE },
    { amountPaise: "10000" }, { isTestOrder: true }, { orderId: "wrong-order" }, { userId: null }]) {
    await scenario(`stored tuple refuses ${Object.keys(extra).join()}`, async () => {
      const f = await fixture(extra); await refuses(f); assert.equal(calls.length, 0);
    });
  }
  await scenario("legacy untyped order remains on its original verification path", async () => {
    const f = await fixture(); await f.orderRef.update({ purpose: admin.firestore.FieldValue.delete() });
    await refuses(f); assert.equal(calls.length, 0);
  });
  await scenario("missing order refuses before provider call", async () => {
    const f = await fixture(); await f.orderRef.delete(); await refuses(f); assert.equal(calls.length, 0);
  });
  await scenario("missing credentials do not simulate recovery", async () => {
    const f = await fixture(); delete process.env.RAZORPAY_KEY_SECRET;
    await refuses(f); assert.equal(calls.length, 0);
  });
  await scenario("local emulator flag cannot manufacture a provider capture", async () => {
    const f = await fixture(); process.env.FUNCTIONS_EMULATOR = "true"; providerFailure = true;
    await refuses(f, "unavailable");
  });
  await scenario("provider failure returns stable error without private response", async () => {
    const f = await fixture(); providerFailure = true;
    await assert.rejects(() => f.call(), e => e.code === "unavailable" && !e.message.includes("PRIVATE_FIXTURE"));
    assert.equal((await f.paymentRef.get()).exists, false);
  });
  for (const change of ["owner", "amount", "purpose", "mode", "delete", "orderId"]) {
    await scenario(`stored ${change} changed during lookup is rechecked`, async () => {
      const f = await fixture();
      duringLookup = () => change === "delete" ? f.orderRef.delete() : f.orderRef.update(
        change === "owner" ? { userId: "other-owner" } : change === "amount" ? { amount: 101, amountPaise: 10100 } :
          change === "purpose" ? { purpose: "wallet_topup" } : change === "mode" ? { providerMode: "live" } : { orderId: "wrong-order" });
      await refuses(f, change === "owner" ? "permission-denied" : "failed-precondition");
    });
  }
  for (const [key, value] of [["id", "bad/path"], ["id", "pay_test_forged"], ["entity", "order"],
    ["order_id", "other-order"], ["amount", 9999], ["amount", "10000"], ["amount", Number.MAX_VALUE],
    ["currency", "USD"], ["captured", false], ["status", "unknown"], ["amount_refunded", -1],
    ["amount_refunded", "0"], ["amount_refunded", 10001], ["refund_status", "unknown"]]) {
    await scenario(`malformed provider ${key} refuses without write`, async () => {
      const f = await fixture(); body.items[0][key] = value; await refuses(f);
    });
  }
  for (const change of ["entity", "count", "truncated", "oversized", "duplicate", "null", "missing_refund"]) {
    await scenario(`malformed collection ${change} refuses`, async () => {
      const f = await fixture();
      if (change === "entity") body.entity = "payment";
      if (change === "count") body.count = "1";
      if (change === "truncated") body.count = 2;
      if (change === "oversized") { body.items = Array.from({ length: 101 }, (_, i) => ({ ...body.items[0], id: `pay_large_${i}` })); body.count = 101; }
      if (change === "duplicate") { body.items.push({ ...body.items[0] }); body.count = 2; }
      if (change === "null") body = null;
      if (change === "missing_refund") delete body.items[0].amount_refunded;
      await refuses(f);
    });
  }
  for (const status of ["created", "authorized", "failed", "empty"]) {
    await scenario(`${status} observation remains unconfirmed without new-charge permission`, async () => {
      const f = await fixture();
      if (status === "empty") { body.items = []; body.count = 0; }
      else { body.items[0].status = status; body.items[0].captured = false; }
      assert.deepEqual(await f.call(), { success: true, verified: false, outcome: "unconfirmed", orderId: f.orderId });
      assert.equal((await f.paymentRef.get()).exists, false);
    });
  }
  await scenario("one capture alongside failed attempt recovers the captured payment", async () => {
    const f = await fixture(); body.items.unshift({ ...body.items[0], id: "pay_failed_attempt", status: "failed", captured: false }); body.count = 2;
    assert.equal((await f.call()).paymentId, f.paymentId);
  });
  await scenario("two distinct captures need review, never an arbitrary winner", async () => {
    const f = await fixture(); body.items.push({ ...body.items[0], id: "pay_second_capture" }); body.count = 2; await refuses(f);
    assert.equal((await db.collection("verified_payments").doc("pay_second_capture").get()).exists, false);
  });
  for (const change of ["partial", "full", "refunded_status", "inconsistent_refund_status"]) {
    await scenario(`${change} cannot fund a fresh goods order`, async () => {
      const f = await fixture();
      if (change === "partial") { body.items[0].amount_refunded = 1; body.items[0].refund_status = "partial"; }
      if (change === "full") { body.items[0].amount_refunded = 10000; body.items[0].refund_status = "full"; }
      if (change === "refunded_status") body.items[0].status = "refunded";
      if (change === "inconsistent_refund_status") body.items[0].refund_status = "partial";
      await refuses(f);
    });
  }
  for (const extra of [{ userId: "other-owner" }, { orderId: "other-order" }, { paymentId: "other-payment" },
    { amount: 99 }, { amountPaise: 9999 }, { currency: "USD" }, { purpose: "wallet_topup" },
    { providerMode: "live" }, { isTest: true }, { signatureVerified: false }, { status: "refunded" }]) {
    await scenario(`existing proof ${Object.keys(extra).join()} cannot be overwritten`, async () => {
      const f = await fixture(); await f.paymentRef.set({ ...f.verified, ...markers, ...extra }); await refuses(f);
    });
  }
  await scenario("recovered capture fulfils once and lost receipt reuses original request", async () => {
    const f = await fixture(); await f.call();
    const productId = `foundation9-product-${seq}`, sellerId = `foundation9-seller-${seq}`;
    await db.collection("users").doc(f.uid).set({ profileCompleted: true });
    await db.collection("sellers").doc(sellerId).set({ status: "approved" });
    await db.collection("products").doc(productId).set({ name: "Fixture", sellerId, salePrice: 100, stock: 10, images: [], isB2BEnabled: false });
    const data = { items: [{ productId, quantity: 1 }], orderMode: "B2C", paymentMethod: "razorpay",
      razorpayOrderId: f.orderId, razorpayPaymentId: f.paymentId, checkoutRequestId: `checkout-foundation9-${seq}`,
      checkoutOwnerId: f.uid, deliveryCharge: 0, tax: 0,
      deliveryAddress: { name: "Fixture", phone: "9999999999", addressLine1: "Fixture", city: "Chennai", state: "TN", zipcode: "600001", country: "India" } };
    const first = await create({ data, auth: f.auth });
    const before = (await f.paymentRef.get()).data().consumedByOrderId;
    await f.call(); assert.equal((await f.paymentRef.get()).data().consumedByOrderId, before);
    const second = await create({ data, auth: f.auth }); assert.deepEqual(second.orders, first.orders);
    await assert.rejects(() => create({ data: { ...data, checkoutRequestId: `${data.checkoutRequestId}-new` }, auth: f.auth }), e => e.code === "failed-precondition");
    assert.equal((await db.collection("orders").where("userId", "==", f.uid).get()).size, 1);
    assert.equal((await db.collection("products").doc(productId).get()).data().stock, 9);
  });
  rules = await initializeTestEnvironment({ projectId: process.env.GCLOUD_PROJECT,
    firestore: { rules: fs.readFileSync(path.join(__dirname, "../../firestore.rules"), "utf8") } });
  await scenario("owner can read saved provider order but cannot forge or delete recovery proof", async () => {
    const f = await fixture(); await f.call(); const client = rules.authenticatedContext(f.uid).firestore();
    await assertSucceeds(getDoc(doc(client, "razorpay_orders", f.orderId)));
    await assertFails(setDoc(doc(client, "verified_payments", "forged_recovery"), f.verified));
    await assertFails(updateDoc(doc(client, "verified_payments", f.paymentId), { signatureVerified: true }));
    await assertFails(deleteDoc(doc(client, "verified_payments", f.paymentId)));
    await assertFails(updateDoc(doc(client, "razorpay_orders", f.orderId), { amountPaise: 1 }));
    await assertFails(getDoc(doc(rules.authenticatedContext("other-owner").firestore(), "razorpay_orders", f.orderId)));
  });
  console.log(`FOUNDATION9 checkout payment recovery: ${passed} passed, ${failed} failed`);
  await rules.cleanup(); fft.cleanup(); await admin.app().delete(); process.exitCode = failed ? 1 : 0;
})().catch(error => { console.error(error.message); process.exitCode = 1; });
