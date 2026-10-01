// Actual compiled v2 callables, isolated loopback database, no live/provider IO.
const assert = require('node:assert/strict');
if (!/^(127\.0\.0\.1|localhost|\[::1\]):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST || '')) {
  throw new Error('Loopback Firestore emulator required');
}
process.env.GCLOUD_PROJECT = 'demo-agrimore-foundation';
process.env.FUNCTIONS_EMULATOR = 'false';
for (const method of ['get', 'post', 'request']) {
  require('axios')[method] = async () => { throw new Error('Provider IO forbidden in session-owner suite'); };
}
const admin = require('firebase-admin');
admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT });
const db = admin.firestore();
const fft = require('firebase-functions-test')({ projectId: process.env.GCLOUD_PROJECT });
const wallet = require('../lib/customer/wallet');
const signup = fft.wrap(wallet.creditSignupBonus);
const referral = fft.wrap(wallet.redeemReferralCode);
let seq = 0, passed = 0, failed = 0;
const call = (fn, uid, data) => fn({ data, auth: uid ? { uid, token: {} } : undefined });
async function scenario(name, body) {
  try { await body(); passed++; console.log(`PASS ${name}`); }
  catch (e) { failed++; console.log(`FAIL ${name}: ${e.message}`); }
}
async function fixture({ profile = true, config = {}, walletExists = true } = {}) {
  const uid = `foundation12-owner-${++seq}`, referrer = `${uid}-referrer`, code = `F12REF${seq}`;
  await db.collection('settings').doc('wallet_config').set({
    isCashbackEnabled: true, isReferralEnabled: true, signupBonus: 17, referredBonus: 23, referrerBonus: 31, ...config,
  });
  await db.collection('users').doc(uid).set({ profileCompleted: profile });
  if (walletExists) await db.collection('wallets').doc(uid).set({
    userId: uid, balance: 12, coins: 3, lifetimeCoinsEarned: 3, referredBy: null, signupBonusCredited: false,
  });
  await db.collection('wallets').doc(referrer).set({ userId: referrer, balance: 8, coins: 5, referralCode: code, referralCount: 0 });
  return { uid, referrer, code };
}
async function ledger(uid) { return db.collection('wallet_transactions').where('userId', '==', uid).get(); }
async function deniedBeforeDatabase(fn, uid, data, errorCode) {
  const original = db.collection;
  let accesses = 0;
  db.collection = function () { accesses++; throw new Error('Unexpected database access before owner rejection'); };
  try {
    await assert.rejects(() => call(fn, uid, data), e => e.code === errorCode);
    assert.equal(accesses, 0, 'No database access permitted for rejected session');
  } finally { db.collection = original; }
}
(async () => {
  for (const [name, fn] of [['signup', signup], ['referral', referral]]) {
    for (const [label, hint] of [['different owner', 'other-owner'], ['null', null], ['empty', ''], ['number', 42], ['boolean', true], ['array', ['owner']], ['object', { uid: 'owner' }]]) {
      await scenario(`${name} denies ${label} hint before database access`, async () => {
        await deniedBeforeDatabase(fn, 'fixture-owner', { code: 'VALIDCODE', checkoutOwnerId: hint }, 'permission-denied');
      });
    }
    await scenario(`${name} authentication precedes owner hint and IO`, async () => {
      await deniedBeforeDatabase(fn, null, { checkoutOwnerId: 'someone' }, 'unauthenticated');
    });
  }
  await scenario('valid owned signup, retry and concurrent callers grant one configured bonus', async () => {
    const f = await fixture();
    const results = await Promise.all(Array.from({ length: 4 }, () => call(signup, f.uid, { checkoutOwnerId: f.uid })));
    assert.equal(results.filter(r => r.credited).length, 1);
    assert.equal((await call(signup, f.uid, { checkoutOwnerId: f.uid })).credited, false);
    const data = (await db.collection('wallets').doc(f.uid).get()).data();
    assert.equal(data.balance, 12); assert.equal(data.coins, 20); assert.equal(data.lifetimeCoinsEarned, 20);
    const entries = await ledger(f.uid); assert.equal(entries.size, 1); assert.equal(entries.docs[0].data().coins, 17);
  });
  for (const [label, payload] of [['empty map', {}], ['missing data', undefined], ['null data', null], ['undefined hint', { checkoutOwnerId: undefined }]]) {
    await scenario(`legacy signup ${label} remains usable before profile completion`, async () => {
      const f = await fixture({ profile: false });
      assert.equal((await call(signup, f.uid, payload)).credited, true);
      assert.equal((await ledger(f.uid)).size, 1);
    });
  }
  await scenario('valid referral credits caller and keeps referrer pending first delivery', async () => {
    const f = await fixture();
    const result = await call(referral, f.uid, { code: ` ${f.code.toLowerCase()} `, checkoutOwnerId: f.uid });
    assert.equal(result.success, true); assert.equal(result.referredBonus, 23); assert.equal(result.referrerBonus, 31);
    const own = (await db.collection('wallets').doc(f.uid).get()).data();
    const other = (await db.collection('wallets').doc(f.referrer).get()).data();
    assert.equal(own.coins, 26); assert.equal(own.balance, 12); assert.equal(own.referredBy, f.code);
    assert.equal(other.coins, 5); assert.equal(other.referralCount, 0); assert.equal((await ledger(f.referrer)).size, 0);
    const entries = await ledger(f.uid); assert.equal(entries.size, 1); assert.equal(entries.docs[0].data().source, 'referral');
    const refs = await db.collection('referrals').where('referredUserId', '==', f.uid).get();
    assert.equal(refs.size, 1); assert.equal(refs.docs[0].data().isCompleted, false);
    await assert.rejects(() => call(referral, f.uid, { code: f.code, checkoutOwnerId: f.uid }), e => e.code === 'failed-precondition');
    assert.equal((await ledger(f.uid)).size, 1);
  });
  await scenario('concurrent referral attempts grant caller once', async () => {
    const f = await fixture();
    const results = await Promise.allSettled(Array.from({ length: 3 }, () => call(referral, f.uid, { code: f.code, checkoutOwnerId: f.uid })));
    assert.equal(results.filter(r => r.status === 'fulfilled').length, 1);
    assert.equal((await ledger(f.uid)).size, 1);
    assert.equal((await db.collection('referrals').where('referredUserId', '==', f.uid).get()).size, 1);
  });
  await scenario('legacy referral without hint remains usable', async () => {
    const f = await fixture(); assert.equal((await call(referral, f.uid, { code: f.code })).success, true);
  });
  await scenario('valid owner still cannot redeem before profile completion', async () => {
    const f = await fixture({ profile: false });
    await assert.rejects(() => call(referral, f.uid, { code: f.code, checkoutOwnerId: f.uid }), e => e.code === 'failed-precondition');
    assert.equal((await ledger(f.uid)).size, 0);
  });
  await scenario('disabled signup and referral policies remain enforced for valid owner', async () => {
    const f = await fixture({ config: { isCashbackEnabled: false, isReferralEnabled: false } });
    assert.equal((await call(signup, f.uid, { checkoutOwnerId: f.uid })).credited, false);
    await assert.rejects(() => call(referral, f.uid, { code: f.code, checkoutOwnerId: f.uid }), e => e.code === 'failed-precondition');
    assert.equal((await ledger(f.uid)).size, 0);
  });
  await scenario('valid owner signup cannot manufacture missing wallet', async () => {
    const f = await fixture({ walletExists: false });
    await assert.rejects(() => call(signup, f.uid, { checkoutOwnerId: f.uid }), e => e.code === 'failed-precondition');
    assert.equal((await db.collection('wallets').doc(f.uid).get()).exists, false);
    assert.equal((await ledger(f.uid)).size, 0);
  });
  await scenario('session-switch hints cannot mutate either account', async () => {
    const old = await fixture(), current = await fixture();
    for (const fn of [signup, referral]) {
      await assert.rejects(() => call(fn, current.uid, { checkoutOwnerId: old.uid, code: old.code }), e => e.code === 'permission-denied');
    }
    for (const f of [old, current]) {
      assert.equal((await db.collection('wallets').doc(f.uid).get()).data().coins, 3);
      assert.equal((await ledger(f.uid)).size, 0);
      assert.equal((await db.collection('referrals').where('referredUserId', '==', f.uid).get()).size, 0);
    }
  });
  console.log(`FOUNDATION12 ${passed} passed; ${failed} failed`);
  fft.cleanup(); await admin.app().delete(); process.exitCode = failed ? 1 : 0;
})().catch(e => { console.error(e); process.exitCode = 1; });
