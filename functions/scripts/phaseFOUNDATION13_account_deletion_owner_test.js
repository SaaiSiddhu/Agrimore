// Real v1 callable against fresh loopback Firestore + Auth, never production.
const assert = require('node:assert/strict');
for (const key of ['FIRESTORE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_HOST', 'FIREBASE_STORAGE_EMULATOR_HOST']) {
  if (!/^(127\.0\.0\.1|localhost|\[::1\]):\d+$/.test(process.env[key] || '')) throw new Error(`${key} loopback emulator required`);
}
if (!/^demo-/.test(process.env.GCLOUD_PROJECT || '')) throw new Error('Demo project required');
const admin = require('firebase-admin');
process.env.STORAGE_EMULATOR_HOST = `http://${process.env.FIREBASE_STORAGE_EMULATOR_HOST}`;
admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT, storageBucket: `${process.env.GCLOUD_PROJECT}.appspot.com` });
const db = admin.firestore(), auth = admin.auth();
const fft = require('firebase-functions-test')({ projectId: process.env.GCLOUD_PROJECT });
const remove = fft.wrap(require('../lib/customer/deleteUserData').deleteUserData);
let sequence = 0, passed = 0, failed = 0;
const sessionTimes = new Map();
const call = (uid, data) => {
  if (uid && !sessionTimes.has(uid)) sessionTimes.set(uid, Math.floor(Date.now() / 1000));
  return remove(data, { auth: uid ? { uid, token: { auth_time: sessionTimes.get(uid) } } : undefined });
};
async function scenario(name, body) {
  try { await body(); passed++; console.log(`PASS ${name}`); }
  catch (e) { failed++; console.log(`FAIL ${name}: ${e.message}`); }
}
async function fixture() {
  const uid = `foundation13-owner-${++sequence}`;
  await auth.createUser({ uid });
  await db.collection('users').doc(uid).set({ role: 'user', name: 'Local fixture' });
  await db.collection('wallets').doc(uid).set({ userId: uid, balance: 0 });
  return { uid };
}
async function stillPresent(uid) {
  assert.equal((await db.collection('users').doc(uid).get()).exists, true);
  assert.equal((await db.collection('wallets').doc(uid).get()).exists, true);
  assert.equal((await auth.getUser(uid)).uid, uid);
  assert.equal((await db.collection('account_deletion_audit').doc(uid).get()).exists, false);
}
async function noDatabase(fn, errorCode) {
  const original = db.collection; let calls = 0;
  db.collection = function () { calls++; throw new Error('Database touched before owner denial'); };
  try { await assert.rejects(fn, e => e.code === errorCode); assert.equal(calls, 0); }
  finally { db.collection = original; }
}
(async () => {
  for (const [label, hint] of [['different account', 'other-account'], ['null', null], ['empty', ''], ['number', 42], ['boolean', true], ['array', ['owner']], ['object', { uid: 'owner' }]]) {
    await scenario(`denies ${label} owner hint before database or Auth deletion`, async () => {
      await noDatabase(() => call('fixture-owner', { expectedOwnerId: hint }), 'permission-denied');
    });
  }
  await scenario('authentication checked before owner hint and database', async () => {
    await noDatabase(() => call(null, { expectedOwnerId: 'fixture-owner' }), 'unauthenticated');
  });
  await scenario('confirmed deletion removes only own Auth and personal data, keeps ledger and anonymized order', async () => {
    const own = await fixture(), other = await fixture();
    const ledger = db.collection('wallet_transactions').doc(`${own.uid}-ledger`);
    await ledger.set({ userId: own.uid, amount: 9, coins: 3 });
    const order = db.collection('orders').doc(`${own.uid}-delivered`);
    await order.set({ userId: own.uid, orderStatus: 'delivered', total: 9, deliveryAddress: { name: 'Fixture' }, notes: 'Private fixture' });
    const result = await call(own.uid, { expectedOwnerId: own.uid });
    assert.equal(result.success, true); assert.equal(result.alreadyDeleted, false);
    assert.equal((await db.collection('users').doc(own.uid).get()).exists, false);
    assert.equal((await db.collection('wallets').doc(own.uid).get()).exists, false);
    await assert.rejects(() => auth.getUser(own.uid), e => e.code === 'auth/user-not-found');
    assert.equal((await ledger.get()).data().amount, 9);
    assert.equal((await order.get()).data().deliveryAddress, null); assert.equal((await order.get()).data().notes, '');
    assert.equal((await db.collection('account_deletion_audit').doc(own.uid).get()).exists, true);
    await stillPresent(other.uid);
    const retry = await call(own.uid, { expectedOwnerId: own.uid });
    assert.equal(retry.success, true); assert.equal(retry.alreadyDeleted, true);
  });
  for (const [label, data] of [['empty map', {}], ['null data', null], ['missing data', undefined], ['undefined hint', { expectedOwnerId: undefined }]]) {
    await scenario(`legacy ${label} deletion remains usable`, async () => {
      const f = await fixture(); assert.equal((await call(f.uid, data)).success, true);
      await assert.rejects(() => auth.getUser(f.uid), e => e.code === 'auth/user-not-found');
    });
  }
  await scenario('transport switched to new owner with old hint preserves both accounts', async () => {
    const old = await fixture(), current = await fixture();
    await assert.rejects(() => call(current.uid, { expectedOwnerId: old.uid }), e => e.code === 'permission-denied');
    await stillPresent(old.uid); await stillPresent(current.uid);
  });
  await scenario('hint compares identity and never lets arbitrary data choose deletion target', async () => {
    const own = await fixture(), other = await fixture();
    assert.equal((await call(own.uid, { expectedOwnerId: own.uid, uid: other.uid, userId: other.uid })).success, true);
    await stillPresent(other.uid);
    await assert.rejects(() => auth.getUser(own.uid), e => e.code === 'auth/user-not-found');
  });
  for (const type of ['balance', 'active-order', 'pending-payout']) {
    await scenario(`valid owned request preserves existing ${type} refusal`, async () => {
      const f = await fixture();
      if (type === 'balance') await db.collection('wallets').doc(f.uid).update({ balance: 5 });
      if (type === 'active-order') await db.collection('orders').doc(`${f.uid}-open`).set({ userId: f.uid, orderStatus: 'processing' });
      if (type === 'pending-payout') await db.collection('employee_payouts').doc(`${f.uid}-pending`).set({ employeeId: f.uid, status: 'requested' });
      await assert.rejects(() => call(f.uid, { expectedOwnerId: f.uid }), e => e.code === 'failed-precondition');
      await stillPresent(f.uid);
    });
  }
  for (const type of ['rider-active-order', 'rider-cash-held', 'rider-pay-owed']) {
    await scenario(`owned deletion preserves ${type} refusal`, async () => {
      const f = await fixture();
      if (type === 'rider-active-order') await db.collection('orders').doc(`${f.uid}-assigned`).set({ deliveryPartnerId: f.uid, orderStatus: 'picked_up' });
      if (type === 'rider-cash-held') await db.collection('rider_accounts').doc(f.uid).set({ cashHeld: 8 });
      if (type === 'rider-pay-owed') await db.collection('rider_accounts').doc(f.uid).set({ earningsUnsettled: 8 });
      await assert.rejects(() => call(f.uid, { expectedOwnerId: f.uid }), e => e.code === 'failed-precondition');
      await stillPresent(f.uid);
    });
  }
  await scenario('owned rider deletion removes fixture KYC files and profile while retaining financial records', async () => {
    const f = await fixture(), other = await fixture();
    const bucket = admin.storage().bucket(), file = bucket.file(`delivery_documents/${f.uid}/fixture.jpg`), otherFile = bucket.file(`delivery_documents/${other.uid}/fixture.jpg`);
    await db.collection('delivery_partners').doc(f.uid).set({ status: 'approved' });
    await db.collection('rider_accounts').doc(f.uid).set({ cashHeld: 0, earningsUnsettled: 0 });
    await db.collection('rider_earnings').doc(`${f.uid}-earning`).set({ riderId: f.uid, amount: 8 });
    await file.save(Buffer.from('local-fixture'), { contentType: 'image/jpeg' });
    await otherFile.save(Buffer.from('other-local-fixture'), { contentType: 'image/jpeg' });
    assert.equal((await call(f.uid, { expectedOwnerId: f.uid })).success, true);
    assert.equal((await db.collection('delivery_partners').doc(f.uid).get()).exists, false);
    assert.equal((await file.exists())[0], false); assert.equal((await otherFile.exists())[0], true);
    assert.equal((await db.collection('rider_accounts').doc(f.uid).get()).exists, true);
    assert.equal((await db.collection('rider_earnings').doc(`${f.uid}-earning`).get()).data().amount, 8);
    assert.equal((await db.collection('account_deletion_audit').doc(f.uid).get()).data().wasRider, true);
    await stillPresent(other.uid);
  });
  for (const type of ['seller-open-order', 'seller-settlement-owed']) {
    await scenario(`owned deletion preserves ${type} refusal`, async () => {
      const f = await fixture();
      if (type === 'seller-open-order') await db.collection('orders').doc(`${f.uid}-selling`).set({ sellerId: f.uid, orderStatus: 'processing' });
      if (type === 'seller-settlement-owed') await db.collection('seller_payouts').doc(`${f.uid}-owed`).set({ sellerId: f.uid, status: 'requested', netAmount: 8 });
      await assert.rejects(() => call(f.uid, { expectedOwnerId: f.uid }), e => e.code === 'failed-precondition');
      await stillPresent(f.uid);
    });
  }
  await scenario('owned seller deletion removes fixture KYC and bank data, hides catalogue, retains paid settlement', async () => {
    const f = await fixture(), other = await fixture(); const bucket = admin.storage().bucket();
    await db.collection('sellers').doc(f.uid).set({ status: 'approved' });
    await db.collection('seller_payout_details').doc(f.uid).set({ accountNumber: 'fixture-only' });
    await db.collection('products').doc(`${f.uid}-product`).set({ sellerId: f.uid, isActive: true });
    await db.collection('seller_payouts').doc(`${f.uid}-paid`).set({ sellerId: f.uid, status: 'paid', netAmount: 8 });
    const file = bucket.file(`seller_documents/${f.uid}/fixture.jpg`), otherFile = bucket.file(`seller_documents/${other.uid}/fixture.jpg`);
    await file.save(Buffer.from('local-fixture'), { contentType: 'image/jpeg' }); await otherFile.save(Buffer.from('other-local-fixture'), { contentType: 'image/jpeg' });
    assert.equal((await call(f.uid, { expectedOwnerId: f.uid })).success, true);
    assert.equal((await db.collection('seller_payout_details').doc(f.uid).get()).exists, false);
    assert.equal((await db.collection('sellers').doc(f.uid).get()).exists, false);
    assert.equal((await db.collection('products').doc(`${f.uid}-product`).get()).data().isActive, false);
    assert.equal((await db.collection('seller_payouts').doc(`${f.uid}-paid`).get()).data().netAmount, 8);
    assert.equal((await file.exists())[0], false); assert.equal((await otherFile.exists())[0], true);
    await stillPresent(other.uid);
  });
  console.log(`FOUNDATION13 ${passed} passed; ${failed} failed`);
  fft.cleanup(); await admin.app().delete(); process.exitCode = failed ? 1 : 0;
})().catch(e => { console.error(e); process.exitCode = 1; });
