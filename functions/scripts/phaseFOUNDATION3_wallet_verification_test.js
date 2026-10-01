// Fresh local database, actual compiled wallet callable, fixture-only provider.
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
if (!/^(127\.0\.0\.1|localhost|\[::1\]):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST || "")) throw new Error("Loopback emulator required");
process.env.GCLOUD_PROJECT = "demo-agrimore-foundation";
process.env.FUNCTIONS_EMULATOR = "false";
process.env.RAZORPAY_KEY_ID = "rzp_test_foundation3_fixture";
process.env.RAZORPAY_KEY_SECRET = "foundation3_fixture_not_a_provider_credential";
let provider, duringFetch, seq = 0, calls = 0, passed = 0, failed = 0;
require("axios").get = async () => { calls++; if (duringFetch) await duringFetch(); return { data: { ...provider } }; };
const admin = require("firebase-admin"); admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT });
const db = admin.firestore();
const fft = require("firebase-functions-test")({ projectId: process.env.GCLOUD_PROJECT });
const topup = fft.wrap(require("../lib/customer/wallet").verifyWalletTopup);
async function scenario(name, body) {
  duringFetch = null;
  try { await body(); passed++; console.log(`PASS ${name}`); }
  catch (e) { failed++; console.log(`FAIL ${name}: ${e.message}`); }
}
async function fixture() {
  const n = ++seq, uid = `foundation3-owner-${n}`, paymentId = `pay_foundation3_${n}`, orderId = `order_foundation3_${n}`;
  await db.collection("users").doc(uid).set({ profileCompleted: true });
  const orderRef = db.collection("razorpay_orders").doc(orderId), paymentRef = db.collection("verified_payments").doc(paymentId);
  await orderRef.set({ orderId, userId: uid, amount: 100, amountPaise: 10000, currency: "INR" });
  provider = { id: paymentId, order_id: orderId, amount: 10000, currency: "INR", status: "captured", method: "upi" };
  const payload = { amount: 100, paymentId, orderId, signature: crypto.createHmac("sha256", process.env.RAZORPAY_KEY_SECRET).update(`${orderId}|${paymentId}`).digest("hex") };
  const call = (data = payload, caller = uid) => topup({ data, auth: { uid: caller, token: {} } });
  return { uid, paymentId, orderId, orderRef, paymentRef, payload, call };
}
async function denied(f, data = f.payload, code) {
  await assert.rejects(() => f.call(data), e => !!e.code && (!code || e.code === code));
  assert.equal((await db.collection("wallets").doc(f.uid).get()).exists, false);
  assert.equal((await db.collection("wallet_topups").doc(f.paymentId).get()).exists, false);
  assert.equal((await db.collection("wallet_transactions").where("userId", "==", f.uid).get()).size, 0);
}
(async () => {
  await scenario("genuine capture and retry credit exactly once", async () => {
    const f = await fixture(); assert.equal((await f.call()).alreadyCredited, false); assert.equal((await f.call()).alreadyCredited, true);
    assert.equal((await db.collection("wallets").doc(f.uid).get()).data().balance, 100);
    assert.equal((await db.collection("wallet_transactions").where("userId", "==", f.uid).get()).size, 1);
  });
  await scenario("retry cannot reveal another payer balance", async () => {
    const f = await fixture(); await f.call(); const attacker = `foundation3-attacker-${++seq}`;
    await db.collection("users").doc(attacker).set({ profileCompleted: true });
    await assert.rejects(() => f.call(f.payload, attacker), e => e.code === "permission-denied");
    assert.equal((await db.collection("wallets").doc(attacker).get()).exists, false);
    assert.equal((await db.collection("wallets").doc(f.uid).get()).data().balance, 100);
  });
  await scenario("concurrent capture calls credit once", async () => {
    const f = await fixture(); const results = await Promise.all([f.call(), f.call(), f.call()]);
    assert.equal(results.filter(r => !r.alreadyCredited).length, 1);
    assert.equal((await db.collection("wallets").doc(f.uid).get()).data().balance, 100);
    assert.equal((await db.collection("wallet_transactions").where("userId", "==", f.uid).get()).size, 1);
  });
  for (const [field, value] of [["paymentId", "pay_other"], ["orderId", "order_other"], ["amount", 99], ["amountPaise", 9999]]) {
    await scenario(`retry rejects corrupted ${field} anchor`, async () => {
      const f = await fixture(); await f.call(); await db.collection("wallet_topups").doc(f.paymentId).update({ [field]: value });
      await assert.rejects(() => f.call(), e => e.code === "failed-precondition");
      assert.equal((await db.collection("wallets").doc(f.uid).get()).data().balance, 100);
      assert.equal((await db.collection("wallet_transactions").where("userId", "==", f.uid).get()).size, 1);
    });
  }
  for (const [field, value] of [["id", "pay_other"], ["order_id", "order_other"], ["currency", "USD"], ["amount", 9999]]) {
    await scenario(`reject provider ${field} mismatch`, async () => { const f = await fixture(); provider[field] = value; await denied(f); });
  }
  for (const [field, value] of [["orderId", "order_other"], ["amountPaise", 9999], ["currency", "USD"], ["userId", "other-owner"]]) {
    await scenario(`reject stored order ${field} mismatch`, async () => { const f = await fixture(); await f.orderRef.update({ [field]: value }); await denied(f); });
  }
  for (const field of ["orderId", "amount", "currency"]) {
    await scenario(`reject stored verification ${field} mismatch`, async () => {
      const f = await fixture(); await f.paymentRef.set({ paymentId: f.paymentId, orderId: f.orderId, userId: f.uid, amount: 100, currency: "INR", status: "captured",
        [field]: field === "amount" ? 99 : field === "currency" ? "USD" : "order_other" });
      await denied(f);
    });
  }
  await scenario("normal verified legacy ownership remains usable without order document", async () => {
    const f = await fixture(); await f.orderRef.delete();
    await f.paymentRef.set({ paymentId: f.paymentId, orderId: f.orderId, userId: f.uid, amount: 100, status: "captured" });
    assert.equal((await f.call()).success, true);
  });
  await scenario("legacy fallback must prove the payment ID", async () => {
    const f = await fixture(); await f.orderRef.delete();
    await f.paymentRef.set({ orderId: f.orderId, userId: f.uid, amount: 100, status: "captured" }); await denied(f);
  });
  await scenario("canonical captured minor units determine credit and ledger", async () => {
    const f = await fixture(); const result = await f.call({ ...f.payload, amount: 100.004 }); assert.equal(result.amount, 100);
    assert.equal((await db.collection("wallets").doc(f.uid).get()).data().balance, 100);
    const ledger = await db.collection("wallet_transactions").where("userId", "==", f.uid).get(); assert.equal(ledger.docs[0].data().amount, 100);
  });
  await scenario("ownership is checked again after provider lookup", async () => {
    const f = await fixture(); duringFetch = async () => f.orderRef.update({ userId: "other-owner" }); await denied(f);
  });
  await scenario("bad signature retains denial and redacted log", async () => {
    const f = await fixture(); const before = calls; await denied(f, { ...f.payload, signature: "bad-signature" }, "permission-denied"); assert.equal(calls, before);
    const logs = await db.collection("payment_security_logs").where("paymentId", "==", f.paymentId).get(); assert.equal(logs.size, 1);
    assert.equal("expectedSignature" in logs.docs[0].data(), false);
  });
  for (const [field, value] of [["paymentId", 5], ["orderId", "bad/path"], ["signature", {}], ["amount", true], ["amount", "100"]]) {
    await scenario(`reject malformed ${field} ${JSON.stringify(value)}`, async () => { const f = await fixture(); const before = calls;
      await denied(f, { ...f.payload, [field]: value }, "invalid-argument"); assert.equal(calls, before); });
  }
  console.log(`FOUNDATION3 wallet verification: ${passed} passed, ${failed} failed`);
  fft.cleanup(); await admin.app().delete(); process.exitCode = failed ? 1 : 0;
})().catch(e => { console.error(e.message); process.exitCode = 1; });
