// Real createOrder transactions and Firestore rules on an isolated emulator.
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
if (!/^(127\.0\.0\.1|localhost|\[::1\]):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST || "")) {
  throw new Error("Loopback Firestore emulator required");
}
process.env.GCLOUD_PROJECT = "demo-agrimore-foundation";
const admin = require("firebase-admin");
admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT });
const db = admin.firestore();
const fft = require("firebase-functions-test")({ projectId: process.env.GCLOUD_PROJECT });
const create = fft.wrap(require("../lib/customer/createOrder").createOrder);
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const { doc, getDoc, setDoc, updateDoc, deleteDoc } = require("firebase/firestore");
let seq = 0, passed = 0, failed = 0, rules;
const address = { name: "Fixture", phone: "9999999999", addressLine1: "Fixture", city: "Chennai", state: "TN", zipcode: "600001", country: "India" };
const anchorId = (uid, key) => crypto.createHash("sha256").update(JSON.stringify([uid, key])).digest("hex");
async function scenario(name, body) {
  try { await body(); passed++; console.log(`PASS ${name}`); }
  catch (error) { failed++; console.log(`FAIL ${name}: ${error.message}`); }
}
async function fixture({ paid = false, sellers = 1, stock = 10 } = {}) {
  const n = ++seq, uid = `foundation7-owner-${n}`, key = `checkout-foundation-${n}`;
  const auth = { uid, token: {} }, productIds = [];
  await db.collection("users").doc(uid).set({ profileCompleted: true });
  for (let i = 0; i < sellers; i++) {
    const sellerId = `foundation7-seller-${n}-${i}`, productId = `foundation7-product-${n}-${i}`;
    productIds.push(productId);
    await db.collection("sellers").doc(sellerId).set({ status: "approved" });
    await db.collection("products").doc(productId).set({ name: "Fixture", sellerId, salePrice: 100, stock, images: [], isB2BEnabled: false });
  }
  const data = { items: productIds.map(productId => ({ productId, quantity: 1 })), orderMode: "B2C", paymentMethod: paid ? "razorpay" : "cod", deliveryAddress: { ...address }, deliveryCharge: 0, tax: 0, checkoutRequestId: key };
  if (paid) {
    Object.assign(data, { razorpayPaymentId: `pay_foundation7_${n}`, razorpayOrderId: `order_foundation7_${n}` });
    await db.collection("verified_payments").doc(data.razorpayPaymentId).set({ userId: uid, paymentId: data.razorpayPaymentId, orderId: data.razorpayOrderId, amount: 100 * sellers, currency: "INR", status: "captured", signatureVerified: true, purpose: "goods_checkout" });
  }
  const anchor = db.collection("checkout_requests").doc(anchorId(uid, key));
  const call = (payload = data, caller = auth) => create({ data: payload, auth: caller });
  const state = async () => ({
    orders: (await db.collection("orders").where("userId", "==", uid).get()).size,
    products: await Promise.all(productIds.map(async id => {
      const product = (await db.collection("products").doc(id).get()).data();
      return { stock: product.stock, soldCount: product.soldCount };
    })),
    rateCount: (await db.collection("order_rate_limits").doc(uid).get()).data()?.count,
  });
  return { uid, key, auth, data, productIds, anchor, call, state };
}
async function sameEffect(f, first) {
  const before = await f.state(), second = await f.call();
  assert.deepEqual(second.orders, first.orders);
  assert.deepEqual(await f.state(), before, "Recovery must not change stock, sold count or rate counter");
}

(async () => {
  await scenario("explicit checkout owner matches authenticated session", async () => {
    const f = await fixture(); f.data.checkoutOwnerId = f.uid;
    const first = await f.call(); await sameEffect(f, first);
  });
  await scenario("different checkout owner refuses before any order effect", async () => {
    const f = await fixture(); f.data.checkoutOwnerId = "another-owner";
    const before = await f.state();
    await assert.rejects(() => f.call(), error => error.code === "permission-denied");
    assert.deepEqual(await f.state(), before); assert.equal((await f.anchor.get()).exists, false);
  });
  await scenario("completed checkout cannot bypass explicit owner binding", async () => {
    const f = await fixture(); await f.call(); f.data.checkoutOwnerId = "another-owner";
    const before = await f.state();
    await assert.rejects(() => f.call(), error => error.code === "permission-denied");
    assert.deepEqual(await f.state(), before);
  });
  await scenario("auth token switching to another user cannot submit saved owner's cart", async () => {
    const original = await fixture(), switched = await fixture();
    original.data.checkoutOwnerId = original.uid;
    const beforeOriginal = await original.state(), beforeSwitched = await switched.state();
    await assert.rejects(() => original.call(original.data, switched.auth), error => error.code === "permission-denied");
    assert.deepEqual(await original.state(), beforeOriginal);
    assert.deepEqual(await switched.state(), beforeSwitched);
    assert.equal((await original.anchor.get()).exists, false);
  });
  for (const paid of [false, true]) {
    await scenario(`${paid ? "paid" : "COD"} lost response recovers identical order without another effect`, async () => {
      const f = await fixture({ paid });
      await sameEffect(f, await f.call());
      assert.equal((await f.anchor.get()).data().uid, f.uid);
      assert.equal((await f.state()).orders, 1);
    });
    await scenario(`${paid ? "paid" : "COD"} concurrent retries all recover one checkout`, async () => {
      const f = await fixture({ paid });
      const results = await Promise.all([f.call(), f.call(), f.call(), f.call()]);
      for (const result of results) assert.deepEqual(result.orders, results[0].orders);
      const state = await f.state();
      assert.equal(state.orders, 1); assert.equal(state.products[0].stock, 9); assert.equal(state.rateCount, 1);
    });
  }
  await scenario("multi-seller retry recovers every original seller order", async () => {
    const f = await fixture({ sellers: 2 });
    const first = await f.call(); assert.equal(first.orders.length, 2);
    await sameEffect(f, first); assert.equal((await f.state()).orders, 2);
  });
  await scenario("paid multi-seller retry recovers the complete original order set", async () => {
    const f = await fixture({ paid: true, sellers: 2 });
    const first = await f.call(); assert.equal(first.orders.length, 2);
    await sameEffect(f, first); assert.equal((await f.state()).orders, 2);
  });
  await scenario("different users may use the same request ID without sharing results", async () => {
    const first = await fixture(), second = await fixture();
    second.data.checkoutRequestId = first.key;
    const a = await first.call(), b = await second.call();
    assert.notEqual(a.orders[0].orderId, b.orders[0].orderId);
    assert.equal((await first.state()).orders, 1); assert.equal((await second.state()).orders, 1);
    assert.equal((await db.collection("checkout_requests").doc(anchorId(second.uid, first.key)).get()).data().uid, second.uid);
  });
  for (const change of ["stock", "price", "seller availability", "rate limit"]) {
    await scenario(`completed request recovers after ${change} changes`, async () => {
      const f = await fixture(), first = await f.call();
      if (change === "stock") await db.collection("products").doc(f.productIds[0]).update({ stock: 0 });
      if (change === "price") await db.collection("products").doc(f.productIds[0]).update({ salePrice: 700 });
      if (change === "seller availability") {
        const product = (await db.collection("products").doc(f.productIds[0]).get()).data();
        await db.collection("sellers").doc(product.sellerId).update({ acceptingOrders: false });
      }
      if (change === "rate limit") await db.collection("order_rate_limits").doc(f.uid).update({ count: 8 });
      await sameEffect(f, first);
    });
  }
  for (const field of ["quantity", "address", "notes", "deliveryCharge", "tax", "employeeCode", "razorpayOrderId", "razorpayPaymentId"]) {
    await scenario(`same request ID refuses changed ${field} without another effect`, async () => {
      const f = await fixture(); await f.call(); const before = await f.state();
      const data = { ...f.data };
      if (field === "quantity") data.items = [{ productId: f.productIds[0], quantity: 2 }];
      else if (field === "address") data.deliveryAddress = { ...address, city: "Other city" };
      else data[field] = field === "deliveryCharge" || field === "tax" ? 1 : "different";
      await assert.rejects(() => f.call(data), error => error.code === "already-exists");
      assert.deepEqual(await f.state(), before);
    });
  }
  for (const key of [null, 42, "", "bad/path", "short", "a".repeat(129)]) {
    await scenario(`invalid request ID ${String(key).slice(0, 20)} refuses before order creation`, async () => {
      const f = await fixture();
      await assert.rejects(() => f.call({ ...f.data, checkoutRequestId: key }), error => error.code === "invalid-argument");
      assert.equal((await f.state()).orders, 0);
    });
  }
  await scenario("address key ordering does not alter the same logical request", async () => {
    const f = await fixture(), first = await f.call();
    const reordered = Object.fromEntries(Object.entries(f.data.deliveryAddress).reverse());
    const second = await f.call({ ...f.data, deliveryAddress: reordered });
    assert.deepEqual(second.orders, first.orders); assert.equal((await f.state()).orders, 1);
  });
  await scenario("a genuine new COD request ID may buy the same cart again", async () => {
    const f = await fixture(); await f.call();
    await f.call({ ...f.data, checkoutRequestId: `${f.key}-new` });
    assert.equal((await f.state()).orders, 2); assert.equal((await f.state()).products[0].stock, 8);
  });
  await scenario("a new request ID cannot reuse the same captured payment", async () => {
    const f = await fixture({ paid: true }); await f.call();
    await assert.rejects(() => f.call({ ...f.data, checkoutRequestId: `${f.key}-new` }), error => error.code === "failed-precondition");
    assert.equal((await f.state()).orders, 1);
  });
  await scenario("legacy paid replay without request ID still refuses", async () => {
    const f = await fixture({ paid: true }); delete f.data.checkoutRequestId; await f.call();
    await assert.rejects(() => f.call(), error => error.code === "failed-precondition");
    assert.equal((await f.anchor.get()).exists, false);
  });
  await scenario("legacy COD calls without request ID remain separate purchases", async () => {
    const f = await fixture(); delete f.data.checkoutRequestId; await f.call(); await f.call();
    assert.equal((await f.state()).orders, 2); assert.equal((await f.anchor.get()).exists, false);
  });
  await scenario("failed first attempt leaves no anchor and may retry when stock returns", async () => {
    const f = await fixture({ stock: 0 });
    await assert.rejects(() => f.call(), error => error.code === "failed-precondition");
    assert.equal((await f.anchor.get()).exists, false);
    await db.collection("products").doc(f.productIds[0]).update({ stock: 10 });
    const result = await f.call(); await sameEffect(f, result);
  });
  await scenario("completed checkout still requires a complete current profile", async () => {
    const f = await fixture(); await f.call(); const before = await f.state();
    await db.collection("users").doc(f.uid).update({ profileCompleted: false });
    await assert.rejects(() => f.call(), error => error.code === "failed-precondition");
    assert.deepEqual(await f.state(), before);
  });
  for (const corrupt of ["owner", "fingerprint", "order owner", "missing order", "invalid order ID", "total"]) {
    await scenario(`corrupt ${corrupt} anchor cannot expose or create orders`, async () => {
      const f = await fixture(); const first = await f.call();
      assert.equal((await f.anchor.get()).exists, true, "Actual callable must create the anchor");
      if (corrupt === "owner") await f.anchor.update({ uid: "another-owner" });
      if (corrupt === "fingerprint") await f.anchor.update({ fingerprint: "corrupt" });
      if (corrupt === "order owner") await db.collection("orders").doc(first.orders[0].orderId).update({ userId: "another-owner" });
      if (corrupt === "missing order") await db.collection("orders").doc(first.orders[0].orderId).delete();
      if (corrupt === "invalid order ID") await f.anchor.update({ orders: [{ ...first.orders[0], orderId: "bad/path" }] });
      if (corrupt === "total") await f.anchor.update({ orders: [{ ...first.orders[0], total: 1 }] });
      const before = await f.state();
      await assert.rejects(() => f.call(), error => ["failed-precondition", "already-exists"].includes(error.code));
      assert.deepEqual(await f.state(), before);
    });
  }
  await scenario("coupon recovery increments usage and redeems once", async () => {
    const f = await fixture(), code = `FOUNDATION7-${seq}`;
    const coupon = db.collection("coupons").doc(code);
    await coupon.set({ code, type: "flat", discount: 10, usageLimit: 1, usedCount: 0, isActive: true, validFrom: admin.firestore.Timestamp.fromMillis(Date.now() - 60000), validTo: admin.firestore.Timestamp.fromMillis(Date.now() + 60000) });
    f.data.couponCode = code; const first = await f.call();
    await sameEffect(f, first); assert.equal((await coupon.get()).data().usedCount, 1);
    assert.equal(first.orders[0].total, 90);
  });
  const f = await fixture(), first = await f.call();
  // Rules fixtures are independent of the callable's anchor positive controls.
  await f.anchor.set({ uid: f.uid, status: "completed", orders: first.orders });
  const [host, port] = process.env.FIRESTORE_EMULATOR_HOST.split(":");
  rules = await initializeTestEnvironment({ projectId: process.env.GCLOUD_PROJECT, firestore: { host, port: Number(port), rules: fs.readFileSync(path.join(__dirname, "../../firestore.rules"), "utf8") } });
  await scenario("rules allow the customer's legitimate own-order read", async () => {
    const client = rules.authenticatedContext(f.uid).firestore();
    await assertSucceeds(getDoc(doc(client, "orders", first.orders[0].orderId)));
  });
  for (const who of ["owner", "other", "admin", "anonymous"]) {
    await scenario(`rules deny ${who} checkout anchor reads and writes`, async () => {
      const client = (who === "anonymous" ? rules.unauthenticatedContext() : rules.authenticatedContext(who === "owner" ? f.uid : who, who === "admin" ? { admin: true } : {})).firestore();
      const ref = doc(client, "checkout_requests", f.anchor.id);
      await assertFails(getDoc(ref)); await assertFails(updateDoc(ref, { status: "changed" }));
      await assertFails(deleteDoc(ref)); await assertFails(setDoc(doc(client, "checkout_requests", `forged-${who}`), { uid: f.uid }));
    });
  }
  console.log(`FOUNDATION7 checkout retry: ${passed} passed, ${failed} failed`);
  await rules.cleanup(); fft.cleanup(); await admin.app().delete(); process.exitCode = failed ? 1 : 0;
})().catch(async error => { console.error(error.message); if (rules) await rules.cleanup(); process.exitCode = 1; });
