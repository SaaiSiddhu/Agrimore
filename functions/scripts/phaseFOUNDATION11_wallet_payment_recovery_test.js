// Actual callables + local Firestore. All provider reads are fixture-only;
// writes/provider construction are forbidden before production imports.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
if (!/^(127\.0\.0\.1|localhost|\[::1\]):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST || '')) throw new Error('Loopback database required');
process.env.GCLOUD_PROJECT = 'demo-agrimore-foundation';
process.env.FUNCTIONS_EMULATOR = 'false';
process.env.RAZORPAY_KEY_ID = 'rzp_test_foundation11_fixture';
process.env.RAZORPAY_KEY_SECRET = 'foundation11_fixture_not_a_provider_credential';
let collection, capture, calls, during, providerFailure, seq = 0, passed = 0, failed = 0;
const axios = require('axios');
axios.get = async (url, options) => {
  calls.push({ url, options });
  if (during) await during(url);
  if (providerFailure) throw new Error('PRIVATE_FIXTURE_HEADERS_AND_PII');
  if (/\/orders\/[^/]+\/payments$/.test(url)) return { data: collection };
  if (/\/payments\/[^/]+$/.test(url)) return { data: capture };
  throw new Error('Unexpected provider URL');
};
for (const verb of ['post', 'put', 'patch', 'delete', 'request']) axios[verb] = async () => { throw new Error('Provider write forbidden'); };
const providerPath = require.resolve('razorpay');
require.cache[providerPath] = { id: providerPath, filename: providerPath, loaded: true, exports: function() { throw new Error('Provider construction forbidden'); } };
const admin = require('firebase-admin'); admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT });
const db = admin.firestore();
const fft = require('firebase-functions-test')({ projectId: process.env.GCLOUD_PROJECT });
const recover = fft.wrap(require('../lib/customer/recoverWalletTopupPayment').recoverWalletTopupPayment);
const goodsRecover = fft.wrap(require('../lib/customer/recoverCheckoutPayment').recoverCheckoutPayment);
const topup = fft.wrap(require('../lib/customer/wallet').verifyWalletTopup);
async function scenario(name, test) {
  calls = []; during = null; providerFailure = false;
  try { await test(); passed++; console.log(`PASS ${name}`); }
  catch (error) { failed++; console.log(`FAIL ${name}: ${error.message}`); }
}
async function fixture(extra = {}) {
  const n = ++seq, uid = `foundation11-owner-${n}`, orderId = `order_foundation11_${n}`, paymentId = `pay_foundation11_${n}`;
  await db.collection('users').doc(uid).set({ profileCompleted: true });
  const orderRef = db.collection('razorpay_orders').doc(orderId), paymentRef = db.collection('verified_payments').doc(paymentId);
  await orderRef.set({ userId: uid, orderId, amount: 100, amountPaise: 10000, currency: 'INR',
    purpose: 'wallet_topup', providerMode: 'test', isTestOrder: false, ...extra });
  capture = { entity: 'payment', id: paymentId, order_id: orderId, amount: 10000, currency: 'INR',
    status: 'captured', captured: true, amount_refunded: 0, refund_status: null };
  collection = { entity: 'collection', count: 1, items: [{ ...capture }] };
  const auth = { uid, token: {} }, data = { orderId, checkoutOwnerId: uid };
  const creditData = { amount: 100, orderId, paymentId, checkoutOwnerId: uid, proofSource: 'provider_api_recovery' };
  const lookup = (value = data, caller = auth) => recover({ data: value, auth: caller });
  const credit = (value = creditData, caller = auth) => topup({ data: value, auth: caller });
  return { uid, orderId, paymentId, orderRef, paymentRef, auth, data, creditData, lookup, credit };
}
async function denied(f, operation, code = 'failed-precondition') {
  const before = (await f.paymentRef.get()).data();
  await assert.rejects(operation, e => e.code === code);
  assert.deepEqual((await f.paymentRef.get()).data(), before);
  assert.equal((await db.collection('wallets').doc(f.uid).get()).exists, false);
  assert.equal((await db.collection('wallet_topups').doc(f.paymentId).get()).exists, false);
  assert.equal((await db.collection('wallet_transactions').where('userId', '==', f.uid).get()).size, 0);
}
(async () => {
  await scenario('recover capture then credit only once, preserving provider proof', async () => {
    const f = await fixture(); const r = await f.lookup(); assert.equal(r.outcome, 'captured'); assert.equal(r.paymentId, f.paymentId);
    let saved = (await f.paymentRef.get()).data(); assert.equal(saved.providerCaptureVerified, true); assert.equal(saved.signatureVerified, undefined);
    await db.collection('settings').doc('wallet_config').set({ topupBonuses: { '100': 5 } });
    const results = await Promise.all([f.credit(), f.credit(), f.credit()]);
    assert.equal(results.filter(x => !x.alreadyCredited).length, 1);
    const wallet = (await db.collection('wallets').doc(f.uid).get()).data(); assert.equal(wallet.balance, 100); assert.equal(wallet.coins, 5);
    assert.equal((await db.collection('wallet_transactions').where('userId', '==', f.uid).get()).size, 2);
    await f.lookup(); assert.equal((await f.credit()).alreadyCredited, true);
    saved = (await f.paymentRef.get()).data(); assert.equal(saved.consumedByWalletTopup, f.uid); assert.equal(saved.signatureVerified, undefined);
    await db.collection('settings').doc('wallet_config').delete();
  });
  await scenario('no capture reopens only the original owned provider order', async () => {
    const f = await fixture(); collection = { entity: 'collection', count: 0, items: [] };
    const result = await f.lookup({ ...f.data, includeCheckoutOrder: true });
    assert.equal(result.outcome, 'unconfirmed'); assert.equal(result.orderId, f.orderId); assert.equal(result.amountPaise, 10000);
    assert.equal(result.keyId, process.env.RAZORPAY_KEY_ID); assert.equal((await f.paymentRef.get()).exists, false);
    assert.equal(calls.length, 1);
  });
  await scenario('forged source flag without server proof never credits', async () => { const f = await fixture(); await denied(f, () => f.credit()); });
  await scenario('client purpose cannot override server-selected wallet purpose', async () => {
    const f = await fixture(); await f.lookup({ ...f.data, purpose: 'goods_checkout' });
    assert.equal((await f.paymentRef.get()).data().purpose, 'wallet_topup');
  });
  await scenario('wallet and goods recovery cannot exchange purposes', async () => {
    const f = await fixture(); await denied(f, () => goodsRecover({ data: f.data, auth: f.auth })); assert.equal(calls.length, 0);
  });
  for (const purpose of ['goods_checkout', 'rfq_checkout', 'employee_onboarding', 'seller_ai_activation', null]) {
    await scenario(`wallet refuses stored purpose ${purpose}`, async () => { const f = await fixture({ purpose }); await denied(f, () => f.lookup()); assert.equal(calls.length, 0); });
  }
  for (const [field, value] of [['userId', 'another-owner'], ['orderId', 'order_other'], ['amountPaise', 9999],
    ['currency', 'USD'], ['providerMode', 'live'], ['isTestOrder', true]]) {
    await scenario(`wallet refuses stored ${field}`, async () => { const f = await fixture({ [field]: value }); await denied(f, () => f.lookup(), field === 'userId' ? 'permission-denied' : 'failed-precondition'); });
  }
  for (const [field, value] of [['currency', 'USD'], ['amount', 9999], ['order_id', 'order_other'],
    ['amount_refunded', 1], ['refund_status', 'partial'], ['status', 'refunded'], ['captured', false], ['id', 'pay_test_simulated']]) {
    await scenario(`wallet refuses provider ${field}`, async () => { const f = await fixture(); collection.items[0][field] = value; await denied(f, () => f.lookup()); });
  }
  await scenario('multiple captures require review without credit', async () => {
    const f = await fixture(); collection.items.push({ ...capture, id: 'pay_second' }); collection.count = 2; await denied(f, () => f.lookup());
  });
  await scenario('missing authentication refuses before provider IO', async () => { const f = await fixture(); await denied(f, () => f.lookup(f.data, null), 'unauthenticated'); });
  await scenario('owner hint rejects changed transport account', async () => { const f = await fixture(); await denied(f, () => f.lookup({ ...f.data, checkoutOwnerId: 'another-owner' }), 'permission-denied'); });
  await scenario('malformed owner hint rejects before lookup', async () => { const f = await fixture(); await denied(f, () => f.lookup({ orderId: f.orderId }), 'invalid-argument'); });
  await scenario('owner changes during provider read fails transaction recheck', async () => {
    const f = await fixture(); during = async () => f.orderRef.update({ userId: 'another-owner' }); await denied(f, () => f.lookup(), 'permission-denied');
  });
  await scenario('unconfirmed metadata rechecks owner after provider read', async () => {
    const f = await fixture(); collection = { entity: 'collection', count: 0, items: [] }; during = async () => f.orderRef.update({ userId: 'another-owner' });
    await denied(f, () => f.lookup({ ...f.data, includeCheckoutOrder: true }), 'permission-denied');
  });
  await scenario('provider failure stays uncertain and excludes private headers', async () => {
    const f = await fixture(); providerFailure = true;
    await assert.rejects(() => f.lookup(), e => e.code === 'unavailable' && !e.message.includes('PRIVATE'));
    assert.equal((await f.paymentRef.get()).exists, false);
  });
  await scenario('credit rechecks fresh provider capture and refunds', async () => {
    const f = await fixture(); await f.lookup(); capture.amount_refunded = 1; await denied(f, () => f.credit());
  });
  await scenario('credit provider failure is safe and leaves verified proof', async () => {
    const f = await fixture(); await f.lookup(); providerFailure = true; await denied(f, () => f.credit(), 'unavailable');
  });
  for (const marker of ['consumedByOrderId', 'consumedByOnboardingFor', 'consumedBySellerAiActivationFor', 'consumedByWalletTopup']) {
    await scenario(`recovery preserves ${marker} and refuses another credit`, async () => {
      const f = await fixture(); await f.lookup(); await f.paymentRef.update({ [marker]: 'prior-use', futureConsumptionMarker: 'keep' });
      await f.lookup(); assert.equal((await f.paymentRef.get()).data()[marker], 'prior-use'); assert.equal((await f.paymentRef.get()).data().futureConsumptionMarker, 'keep'); await denied(f, () => f.credit());
    });
  }
  await scenario('profile incomplete may check capture but cannot credit', async () => {
    const f = await fixture(); await db.collection('users').doc(f.uid).update({ profileCompleted: false }); await f.lookup(); await denied(f, () => f.credit());
  });
  const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
  const { doc, getDoc, setDoc, updateDoc } = require('firebase/firestore');
  const rules = await initializeTestEnvironment({ projectId: process.env.GCLOUD_PROJECT,
    firestore: { rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8') } });
  await scenario('wallet owner can read own balance but cannot fabricate capture or credit', async () => {
    const f = await fixture(); await f.lookup(); await f.credit(); const client = rules.authenticatedContext(f.uid).firestore();
    await assertSucceeds(getDoc(doc(client, 'wallets', f.uid)));
    await assertFails(setDoc(doc(client, 'verified_payments', 'forged_api_capture'), { providerCaptureVerified: true, userId: f.uid }));
    await assertFails(updateDoc(doc(client, 'wallets', f.uid), { balance: 999999 }));
    await assertFails(setDoc(doc(client, 'wallet_topups', 'forged_topup'), { uid: f.uid, amount: 100 }));
  });
  console.log(`FOUNDATION11 wallet recovery: ${passed} passed, ${failed} failed`);
  await rules.cleanup(); fft.cleanup(); await admin.app().delete(); process.exitCode = failed ? 1 : 0;
})().catch(e => { console.error(e.message); process.exitCode = 1; });
