// Actual callable transactions and rules, loopback storage only. No provider IO.
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
const ensure = fft.wrap(require("../lib/customer/ensureCheckoutSubscriptions").ensureCheckoutSubscriptions);
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const { doc, getDoc, updateDoc, deleteDoc } = require("firebase/firestore");
const hash = tuple => crypto.createHash("sha256").update(JSON.stringify(tuple)).digest("hex");
let seq = 0, passed = 0, failed = 0, rules;
async function scenario(name, body) {
  try { await body(); passed++; console.log(`PASS ${name}`); }
  catch (e) { failed++; console.log(`FAIL ${name}: ${e.message}`); }
}
async function fixture({ sellers = 1, paid = false, type = "Auto Delivery", mode = "B2C" } = {}) {
  const n = ++seq, uid = `foundation10-owner-${n}`, key = `checkout-foundation10-${n}`;
  const auth = { uid, token: {} }, products = [];
  await db.collection("users").doc(uid).set({ profileCompleted: true });
  for (let i = 0; i < sellers; i++) {
    const sellerId = `foundation10-seller-${n}-${i}`, id = `foundation10-product-${n}-${i}`;
    products.push(id);
    await db.collection("sellers").doc(sellerId).set({ status: "approved" });
    await db.collection("products").doc(id).set({ sellerId, name: `Fixture ${i}`, salePrice: 100,
      stock: 20, images: ["fixture-image"], isB2BEnabled: false });
  }
  const data = { items: products.map(productId => ({ productId, quantity: 2 })),
    orderMode: "B2C", paymentMethod: paid ? "razorpay" : "cod", checkoutRequestId: key,
    deliveryAddress: { name: "Fixture", phone: "fixture-phone", addressLine1: "Fixture street",
      latitude: 13, longitude: 80 }, deliverySlot: "Fixture slot", tax: 0, deliveryCharge: 0,
    orderType: type, autoFrequency: "Daily" };
  if (paid) {
    data.razorpayPaymentId = `pay_foundation10_${n}`; data.razorpayOrderId = `order_foundation10_${n}`;
    await db.collection("verified_payments").doc(data.razorpayPaymentId).set({ userId: uid,
      paymentId: data.razorpayPaymentId, orderId: data.razorpayOrderId, amount: 200 * sellers,
      currency: "INR", status: "captured", purpose: "goods_checkout", signatureVerified: true });
  }
  const receipt = await create({ data, auth });
  const orderRefs = receipt.orders.map(row => db.collection("orders").doc(row.orderId));
  if (mode !== "B2C") await orderRefs[0].update({ orderMode: mode });
  const anchor = db.collection("checkout_requests").doc(hash([uid, key]));
  const input = { checkoutOwnerId: uid, checkoutRequestId: key };
  const call = (payload = input, caller = auth) => ensure({ data: payload, auth: caller });
  const subs = async () => (await db.collection("subscriptions").where("userId", "==", uid).get()).docs;
  return { uid, key, auth, input, call, products, anchor, orderRefs, receipt, subs };
}
async function refuses(f, code = "failed-precondition", call = () => f.call()) {
  const before = (await f.anchor.get()).data();
  await assert.rejects(call, e => e.code === code);
  assert.deepEqual((await f.anchor.get()).data(), before, "Refusal must preserve anchor exactly");
  assert.equal((await f.subs()).length, 0, "Refusal must not create any partial subscription");
}
(async () => {
  await scenario("confirmed COD creates one server-priced subscription and atomic anchor", async () => {
    const f = await fixture(), before = Date.now(), r = await f.call();
    assert.equal(r.success, true); assert.equal(r.checkoutRequestId, f.key);
    const subs = await f.subs(); assert.equal(subs.length, 1);
    const sub = subs[0].data(); assert.equal(sub.price, 100); assert.equal(sub.quantity, 2);
    assert.equal(sub.paymentMethod, "cod"); assert.equal(sub.frequency, "daily");
    assert.equal(sub.userName, "Fixture"); assert.equal(sub.userPhone, "fixture-phone");
    assert.equal(sub.address, "Fixture street"); assert.deepEqual(sub.location, { lat: 13, lng: 80 });
    assert.equal(sub.unit, "nos"); assert.equal(sub.deliverySlot, "Fixture slot");
    assert.equal(sub.nextRunDate instanceof admin.firestore.Timestamp, true);
    assert(sub.nextRunDate.toMillis() >= before + 86400000);
    assert.equal(sub.sourceOrderId, f.receipt.orders[0].orderId);
    assert.equal(sub.sourceCheckoutRequestId, f.key);
    assert.deepEqual((await f.anchor.get()).data().subscriptionIds, r.subscriptionIds);
  });
  await scenario("confirmed paid and multi-seller orders create every original line once", async () => {
    const f = await fixture({ sellers: 2, paid: true }); const r = await f.call();
    assert.equal(r.subscriptionIds.length, 2); assert.equal((await f.subs()).length, 2);
    for (const sub of await f.subs()) assert.equal(sub.data().paymentMethod, "razorpay");
  });
  await scenario("forged price quantity address and order IDs never replace server order fields", async () => {
    const f = await fixture(); await f.call({ ...f.input, price: 1, quantity: 999,
      orderIds: ["other-order"], deliveryAddress: { name: "Forged" } });
    const sub = (await f.subs())[0].data(); assert.equal(sub.price, 100);
    assert.equal(sub.quantity, 2); assert.equal(sub.userName, "Fixture");
  });
  await scenario("catalogue drift after confirmation cannot rewrite the original subscription tuple", async () => {
    const f = await fixture(); await db.collection("products").doc(f.products[0]).update({ salePrice: 999, stock: 0 });
    await f.call(); assert.equal((await f.subs())[0].data().price, 100);
  });
  await scenario("sequential and lost-reply retries preserve exact subscriptions and anchor", async () => {
    const f = await fixture(), first = await f.call();
    const before = (await f.subs())[0].data(), anchor = (await f.anchor.get()).data();
    assert.deepEqual(await f.call(), first);
    assert.deepEqual((await f.subs())[0].data(), before); assert.deepEqual((await f.anchor.get()).data(), anchor);
  });
  await scenario("concurrent setup converges on one original set", async () => {
    const f = await fixture({ sellers: 2 }); const rs = await Promise.all([f.call(), f.call(), f.call()]);
    for (const r of rs) assert.deepEqual(r, rs[0]); assert.equal((await f.subs()).length, 2);
  });
  await scenario("paused subscription and scheduler progress survive completed retries", async () => {
    const f = await fixture(), r = await f.call();
    const ref = db.collection("subscriptions").doc(r.subscriptionIds[0]);
    await ref.update({ isActive: false, nextRunDate: admin.firestore.Timestamp.fromMillis(9876543210) });
    const before = (await ref.get()).data(); assert.deepEqual(await f.call(), r);
    assert.deepEqual((await ref.get()).data(), before);
  });
  await scenario("deleted subscription is never recreated by order recovery", async () => {
    const f = await fixture(), r = await f.call(); await db.collection("subscriptions").doc(r.subscriptionIds[0]).delete();
    assert.deepEqual(await f.call(), r); assert.equal((await f.subs()).length, 0);
  });
  await scenario("weekly and variant labels retain the confirmed order values", async () => {
    const f = await fixture(); const o = (await f.orderRefs[0].get()).data();
    await f.orderRefs[0].update({ autoFrequency: "Weekly", items: [{ ...o.items[0], variant: "5 kg" }] });
    await f.call(); const sub = (await f.subs())[0].data(); assert.equal(sub.frequency, "weekly"); assert.equal(sub.unit, "5 kg");
  });
  await scenario("unauthenticated setup refuses", async () => {
    const f = await fixture(); await refuses(f, "unauthenticated", () => f.call(f.input, null));
  });
  await scenario("resolved auth owner mismatch refuses before touching another account", async () => {
    const f = await fixture(); await refuses(f, "permission-denied", () => f.call(f.input, { uid: "other-owner", token: {} }));
  });
  for (const payload of [{}, { checkoutOwnerId: "" }, { checkoutRequestId: "bad/path" }, { checkoutRequestId: 1 }]) {
    await scenario(`bad input ${JSON.stringify(payload)} refuses`, async () => {
      const f = await fixture(); await refuses(f, "invalid-argument", () => f.call({ ...f.input, ...payload,
        ...(Object.keys(payload).length ? {} : { checkoutOwnerId: undefined }) }));
    });
  }
  for (const change of [{ uid: "other" }, { requestId: "other" }, { status: "pending" },
    { orders: [] }, { orders: [{ orderId: "bad/path" }] }, { subscriptionIds: [] },
    { subscriptionIds: ["bad/path"] }]) {
    await scenario(`corrupt anchor ${Object.keys(change)} refuses`, async () => {
      const f = await fixture(); await f.anchor.update(change); await refuses(f);
    });
  }
  await scenario("missing anchor refuses", async () => { const f = await fixture(); await f.anchor.delete(); await refuses(f); });
  await scenario("missing confirmed order refuses", async () => { const f = await fixture(); await f.orderRefs[0].delete(); await refuses(f); });
  for (const change of [{ userId: "other" }, { id: "other" }, { total: 1 }, { sellerId: "other" },
    { orderType: "One Time" }, { orderMode: "B2B" }, { autoFrequency: "unknown" },
    { orderStatus: "cancelled" }, { status: "cancelled" }, { paymentStatus: "refunded" },
    { paymentMethod: "wallet" }, { deliveryAddress: null }, { items: [] }]) {
    await scenario(`invalid original order ${Object.keys(change)} refuses`, async () => {
      const f = await fixture(); await f.orderRefs[0].update(change); await refuses(f);
    });
  }
  await scenario("unpaid online order cannot initialize subscriptions", async () => {
    const f = await fixture({ paid: true }); await f.orderRefs[0].update({ paymentStatus: "pending" }); await refuses(f);
  });
  for (const change of [{ price: -1 }, { price: Number.MAX_VALUE }, { quantity: 0 },
    { quantity: 1.5 }, { productId: "" }, { productImage: null }]) {
    await scenario(`invalid trusted line ${Object.keys(change)} refuses`, async () => {
      const f = await fixture(), o = (await f.orderRefs[0].get()).data();
      await f.orderRefs[0].update({ items: [{ ...o.items[0], ...change }] }); await refuses(f);
    });
  }
  await scenario("pre-existing deterministic ID refuses without overwriting or partial marker", async () => {
    const f = await fixture({ sellers: 2 });
    const id = hash([f.uid, f.key, f.receipt.orders[0].orderId, 0]);
    const ref = db.collection("subscriptions").doc(id); await ref.set({ userId: "other-owner", price: 1 });
    await assert.rejects(() => f.call(), e => e.code === "failed-precondition");
    assert.deepEqual((await ref.get()).data(), { userId: "other-owner", price: 1 });
    assert.equal((await f.subs()).length, 0); assert.equal((await f.anchor.get()).data().subscriptionIds, undefined);
  });
  rules = await initializeTestEnvironment({ projectId: process.env.GCLOUD_PROJECT,
    firestore: { rules: fs.readFileSync(path.join(__dirname, "../../firestore.rules"), "utf8") } });
  await scenario("owner reads and pauses legitimate subscription but cannot forge anchor completion", async () => {
    const f = await fixture(), r = await f.call(); const owner = rules.authenticatedContext(f.uid).firestore();
    await assertSucceeds(getDoc(doc(owner, "subscriptions", r.subscriptionIds[0])));
    await assertSucceeds(updateDoc(doc(owner, "subscriptions", r.subscriptionIds[0]), { isActive: false }));
    await assertFails(updateDoc(doc(owner, "checkout_requests", f.anchor.id), { subscriptionIds: ["f".repeat(64)] }));
    await assertFails(updateDoc(doc(owner, "subscriptions", r.subscriptionIds[0]), { price: 1 }));
    await assertSucceeds(deleteDoc(doc(owner, "subscriptions", r.subscriptionIds[0])));
    await f.call(); assert.equal((await f.subs()).length, 0);
  });
  console.log(`FOUNDATION10 checkout subscriptions: ${passed} passed, ${failed} failed`);
  await rules.cleanup(); fft.cleanup(); await admin.app().delete(); process.exitCode = failed ? 1 : 0;
})().catch(e => { console.error(e); process.exitCode = 1; });
