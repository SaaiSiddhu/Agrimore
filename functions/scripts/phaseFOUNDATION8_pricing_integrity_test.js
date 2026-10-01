// Real checkout/quote transactions; synthetic fixtures on loopback only.
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
if (!/^(127\.0\.0\.1|localhost|\[::1\]):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST || "")) {
  throw new Error("Loopback Firestore emulator required");
}
process.env.GCLOUD_PROJECT = "demo-agrimore-foundation";
const admin = require("firebase-admin");
admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT });
const db = admin.firestore();
const fft = require("firebase-functions-test")({ projectId: process.env.GCLOUD_PROJECT });
const create = fft.wrap(require("../lib/customer/createOrder").createOrder);
const quote = fft.wrap(require("../lib/customer/productCreditHold").quoteOrderWithCredit);
let seq = 0, passed = 0, failed = 0;
const address = { name: "Fixture", phone: "9999999999", addressLine1: "Fixture", city: "Chennai", state: "TN", zipcode: "600001", country: "India" };
async function scenario(name, body) {
  try { await body(); passed++; console.log(`PASS ${name}`); }
  catch (error) { failed++; console.log(`FAIL ${name}: ${error.message}`); }
}
async function fixture() {
  const n = ++seq, uid = `foundation8-owner-${n}`, productId = `foundation8-product-${n}`, sellerId = `foundation8-seller-${n}`;
  const product = db.collection("products").doc(productId), coupon = db.collection("coupons").doc(`foundation8-coupon-${n}`);
  const payment = db.collection("verified_payments").doc(`pay_foundation8_${n}`);
  const hold = db.collection("product_credit_holds").doc(`foundation8-hold-${n}`);
  const balance = db.collection("product_credit_balances").doc(uid);
  const data = { items: [{ productId, quantity: 1 }], orderMode: "B2C", paymentMethod: "cod", deliveryAddress: { ...address }, deliveryCharge: 0, tax: 0, checkoutRequestId: `checkout-foundation8-${n}` };
  await db.collection("users").doc(uid).set({ profileCompleted: true });
  await db.collection("sellers").doc(sellerId).set({ status: "approved" });
  await db.collection("employees").doc(`foundation8-employee-${n}`).set({ status: "approved", employeeCode: `FOUNDATION8-${n}` });
  await product.set({ name: "Fixture", sellerId, salePrice: 100, images: [], isB2BEnabled: true, b2bPrice: 100 });
  await payment.set({ userId: uid, paymentId: payment.id, orderId: `order_foundation8_${n}`, amount: 100, currency: "INR", status: "captured", signatureVerified: true, purpose: "goods_checkout" });
  // Existing hold proves a refused quote also rolls back queued releases.
  await hold.set({ customerId: uid, enrollmentId: "fixture", status: "active", amount: 10, ledgerEntryId: "fixture-prior-hold" });
  await balance.set({ available: 20, onHold: 10, totalEarned: 30, totalRedeemed: 0 });
  const auth = { uid, token: {} };
  const anchor = db.collection("checkout_requests").doc(crypto.createHash("sha256").update(JSON.stringify([uid, data.checkoutRequestId])).digest("hex"));
  const snapshot = async () => ({
    product: (await product.get()).data(), payment: (await payment.get()).data(), coupon: (await coupon.get()).data(),
    products: (await db.collection("products").where("sellerId", "==", sellerId).get()).docs.map(d => ({ id: d.id, ...d.data() })),
    hold: (await hold.get()).data(), balance: (await balance.get()).data(), anchor: (await anchor.get()).data(),
    rate: (await db.collection("order_rate_limits").doc(uid).get()).data(),
    orders: (await db.collection("orders").where("userId", "==", uid).get()).docs.map(d => d.data()),
    redemptions: (await db.collection("coupon_redemptions").where("uid", "==", uid).get()).docs.map(d => d.data()),
    ledger: (await db.collection("product_credit_ledger").where("customerId", "==", uid).get()).docs.map(d => d.data()),
  });
  const addCoupon = async (patch) => {
    data.couponCode = `FOUNDATION8-COUPON-${n}`;
    await coupon.set({ code: data.couponCode, type: "percentage", discount: 10, usedCount: 0, usageLimit: 0, isActive: true, validFrom: admin.firestore.Timestamp.fromMillis(Date.now() - 60000), validTo: admin.firestore.Timestamp.fromMillis(Date.now() + 60000), ...patch });
  };
  const paid = async (amount = 1) => {
    Object.assign(data, { paymentMethod: "razorpay", razorpayPaymentId: payment.id, razorpayOrderId: `order_foundation8_${n}` });
    await payment.update({ amount });
  };
  const b2b = () => { data.orderMode = "B2B"; data.employeeCode = `FOUNDATION8-${n}`; };
  return { n, uid, data, auth, productId, sellerId, product, coupon, payment, hold, balance, anchor, snapshot, addCoupon, paid, b2b };
}
const invalid = [
  ["unsafe integral quantity", f => { f.data.items[0].quantity = Number.MAX_SAFE_INTEGER + 1; }],
  ["nonfinite quantity", f => { f.data.items[0].quantity = Infinity; }],
  ["unsafe duplicate quantity sum", async f => { await f.product.update({ salePrice: 0.001 }); f.data.items = [{ productId: f.productId, quantity: Number.MAX_SAFE_INTEGER }, { productId: f.productId, quantity: 1 }]; }],
  ["unsafe aggregate across variants", async f => { await f.product.update({ variants: [{ id: "a", price: 0.001 }, { id: "b", price: 0.001 }] }); f.data.items = [{ productId: f.productId, variantId: "a", quantity: Number.MAX_SAFE_INTEGER }, { productId: f.productId, variantId: "b", quantity: 1 }]; }],
  ["overflowing line money", f => { f.data.items[0].quantity = Number.MAX_SAFE_INTEGER; }],
  ["unsafe catalogue money", f => f.product.update({ salePrice: Number.MAX_VALUE })],
  ["nonfinite string catalogue price", f => f.product.update({ salePrice: "Infinity" })],
  ["nonfinite wholesale price", async f => { f.b2b(); await f.product.update({ b2bPrice: NaN }); }],
  ["negative wholesale price", async f => { f.b2b(); await f.product.update({ b2bPrice: -100 }); }],
  ["nonfinite flat coupon", f => f.addCoupon({ type: "flat", discount: NaN })],
  ["overflowing percentage coupon", f => f.addCoupon({ discount: Number.MAX_VALUE })],
  ["nonfinite coupon cap", f => f.addCoupon({ maxDiscountAmount: -Infinity })],
  ["unsafe aggregate cart money", async f => {
    await f.product.update({ salePrice: 60000000000000 });
    const other = `foundation8-other-${f.n}`;
    await db.collection("products").doc(other).set({ name: "Fixture", sellerId: f.sellerId, salePrice: 60000000000000 });
    f.data.items.push({ productId: other, quantity: 1 });
  }],
];
(async () => {
  for (const [name, mutate] of invalid) {
    for (const command of ["order", "quote"]) {
      await scenario(`${command} rejects ${name} without any effect`, async () => {
        const f = await fixture(); await mutate(f); const before = await f.snapshot();
        const callable = command === "order" ? create : quote;
        const quantityCase = /quantity|aggregate across variants/.test(name);
        await assert.rejects(() => callable({ data: f.data, auth: f.auth }), error => quantityCase ? error.code === "invalid-argument" : error.code === "failed-precondition");
        assert.deepEqual(await f.snapshot(), before);
      });
    }
  }
  for (const cause of ["quantity overflow", "coupon NaN", "wholesale NaN"]) {
    await scenario(`paid checkout rejects ${cause} without consuming payment`, async () => {
      const f = await fixture(); await f.paid();
      if (cause === "quantity overflow") { f.data.items[0].quantity = Number.MAX_VALUE; await f.addCoupon({ discount: 10 }); }
      if (cause === "coupon NaN") await f.addCoupon({ type: "flat", discount: NaN });
      if (cause === "wholesale NaN") { f.b2b(); await f.product.update({ b2bPrice: NaN }); }
      const before = await f.snapshot();
      await assert.rejects(() => create({ data: f.data, auth: f.auth }), error => ["invalid-argument", "failed-precondition"].includes(error.code));
      assert.deepEqual(await f.snapshot(), before);
    });
  }
  for (const paid of [false, true]) {
    await scenario(`${paid ? "paid" : "COD"} ordinary checkout still succeeds`, async () => {
      const f = await fixture(); await f.product.update({ stock: 10 });
      if (paid) await f.paid(100);
      const result = await create({ data: f.data, auth: f.auth });
      assert.equal(result.orders[0].total, 100); assert.equal((await f.product.get()).data().stock, 9);
      assert.equal((await f.payment.get()).data().consumedByOrderId, paid ? result.orders[0].orderId : undefined);
    });
  }
  await scenario("missing stock policy remains open for an ordinary order", async () => {
    const f = await fixture(), result = await create({ data: f.data, auth: f.auth });
    assert.equal(result.orders[0].total, 100); assert.equal((await f.product.get()).data().stock, undefined);
    assert.equal((await f.product.get()).data().soldCount, 1);
  });
  await scenario("ordinary quote and order agree including coupon and fees", async () => {
    const f = await fixture(); await f.addCoupon({ discount: 10 });
    f.data.deliveryCharge = 5; f.data.tax = 2;
    const q = await quote({ data: f.data, auth: f.auth }), result = await create({ data: f.data, auth: f.auth });
    assert.equal(q.total, 97); assert.equal(q.payable, 97); assert.equal(q.creditApplied, 0);
    assert.equal(result.orders[0].total, q.total); assert.equal((await f.coupon.get()).data().usedCount, 1);
  });
  await scenario("fractional catalogue rupees retain established rounding", async () => {
    const f = await fixture(); await f.product.update({ salePrice: 0.29 }); await f.paid(0.29);
    const q = await quote({ data: f.data, auth: f.auth }), result = await create({ data: f.data, auth: f.auth });
    assert.equal(q.total, 0.29); assert.equal(result.orders[0].total, 0.29);
  });
  await scenario("valid duplicates normalize once and preserve stock accounting", async () => {
    const f = await fixture(); await f.product.update({ stock: 10 });
    f.data.items.push({ productId: f.productId, quantity: 2 });
    const result = await create({ data: f.data, auth: f.auth });
    assert.equal(result.orders[0].total, 300); assert.equal((await f.product.get()).data().stock, 7);
    assert.equal((await db.collection("orders").doc(result.orders[0].orderId).get()).data().items.length, 1);
  });
  await scenario("representable large quantity is not given an arbitrary business cap", async () => {
    const f = await fixture(); await f.product.update({ salePrice: 0.001 }); f.data.items[0].quantity = Number.MAX_SAFE_INTEGER;
    const q = await quote({ data: f.data, auth: f.auth });
    assert.equal(q.total, Math.round(0.001 * Number.MAX_SAFE_INTEGER * 100) / 100);
    assert.ok(Number.isFinite(q.payable));
  });
  await scenario("valid wholesale pricing remains consistent across quote and order", async () => {
    const f = await fixture(); f.b2b(); await f.product.update({ b2bPrice: 75, stock: 10 });
    const q = await quote({ data: f.data, auth: f.auth }), result = await create({ data: f.data, auth: f.auth });
    assert.equal(q.total, 75); assert.equal(result.orders[0].total, 75);
  });
  await scenario("configured zero wholesale price retains its existing behavior", async () => {
    const f = await fixture(); f.b2b(); await f.product.update({ b2bPrice: 0 });
    const q = await quote({ data: f.data, auth: f.auth }), result = await create({ data: f.data, auth: f.auth });
    assert.equal(q.total, 0); assert.equal(result.orders[0].total, 0);
  });
  console.log(`FOUNDATION8 pricing integrity: ${passed} passed, ${failed} failed`);
  fft.cleanup(); await admin.app().delete(); process.exitCode = failed ? 1 : 0;
})().catch(error => { console.error(error); process.exit(1); });
