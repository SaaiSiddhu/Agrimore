// Real v2 profile handlers with fresh loopback Firestore; no Auth/provider calls.
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
if (!/^(127\.0\.0\.1|localhost|\[::1\]):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST || '')) {
  throw new Error('Loopback Firestore emulator required');
}
process.env.GCLOUD_PROJECT = 'demo-agrimore-foundation';
const admin = require('firebase-admin');
admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT });
const db = admin.firestore();
const fft = require('firebase-functions-test')({ projectId: process.env.GCLOUD_PROJECT });
const names = ['verifyEmailForProfile', 'completeUserProfile', 'changePhoneNumber', 'changeEmailAddress', 'changeDateOfBirth'];
const handlers = Object.fromEntries(names.map(name => [name, fft.wrap(require(`../lib/customer/${name}`)[name])]));
const call = (name, uid, data) => handlers[name]({ data, auth: uid ? { uid, token: {} } : undefined });
let sequence = 0, passed = 0, failed = 0;
async function scenario(name, body) {
  try { await body(); passed++; console.log(`PASS ${name}`); }
  catch (e) { failed++; console.log(`FAIL ${name}: ${e.message}`); }
}
async function noDatabase(fn, code) {
  const collection = db.collection, transaction = db.runTransaction;
  let calls = 0;
  db.collection = function () { calls++; throw new Error('Database touched before owner refusal'); };
  db.runTransaction = function () { calls++; throw new Error('Transaction touched before owner refusal'); };
  try { await assert.rejects(fn, e => e.code === code); assert.equal(calls, 0); }
  finally { db.collection = collection; db.runTransaction = transaction; }
}
const hash = value => crypto.createHash('sha256').update(value).digest('hex');
function inputs(name) {
  if (name === 'verifyEmailForProfile') return { email: 'fixture@example.invalid', otp: '314159' };
  if (name === 'changePhoneNumber') return { phone: '9876500011', otp: '314159' };
  if (name === 'changeDateOfBirth') return { dateOfBirth: '1990-01-01' };
  if (name === 'changeEmailAddress') return { email: 'fixture@example.invalid' };
  return { name: 'Current User', email: 'fixture@example.invalid', dateOfBirth: '1990-01-01', gender: 'male' };
}
async function fixture(name) {
  const n = ++sequence, uid = `foundation14-owner-${n}`, other = `foundation14-other-${n}`;
  const email = `new-${n}@profile.invalid`, phone = String(9876500000 + n), normalized = `+91${phone}`;
  await db.collection('users').doc(uid).set({ role: 'user', name: 'Original', email: `old-${n}@profile.invalid`, phone: `+9187654${String(n).padStart(5, '0')}` });
  await db.collection('users').doc(other).set({ role: 'user', name: 'Other', email: `other-${n}@profile.invalid` });
  const data = { ...inputs(name) };
  if ('email' in data) data.email = email;
  if ('phone' in data) data.phone = phone;
  if (name === 'verifyEmailForProfile') {
    await db.collection('otp_codes').doc(email).set({ attempts: 0, otpHash: hash(data.otp), expiresAt: Date.now() + 300000, verified: false });
  }
  if (name === 'completeUserProfile' || name === 'changeEmailAddress') {
    await db.collection('otp_codes').doc(email).set({ verified: true, verifiedByUid: uid, verifiedAt: Date.now() });
  }
  if (name === 'changePhoneNumber') {
    await db.collection('phone_otp_codes').doc(normalized).set({ attempts: 0, otpHash: hash(data.otp), expiresAt: Date.now() + 300000 });
  }
  return { uid, other, data, email, normalized };
}
async function allowed(name, withHint) {
  const f = await fixture(name), otherBefore = (await db.collection('users').doc(f.other).get()).data();
  const data = { ...f.data, userId: f.other, uid: f.other };
  if (withHint) data.expectedOwnerId = f.uid;
  const result = await call(name, f.uid, data);
  assert.equal(result.success, true);
  assert.deepEqual((await db.collection('users').doc(f.other).get()).data(), otherBefore);
  const own = (await db.collection('users').doc(f.uid).get()).data();
  assert.equal(own.role, 'user');
  if (name === 'verifyEmailForProfile') {
    const marker = (await db.collection('otp_codes').doc(f.email).get()).data();
    assert.equal(marker.verified, true); assert.equal(marker.verifiedByUid, f.uid);
  } else if (name === 'completeUserProfile') {
    assert.equal(own.profileCompleted, true); assert.equal(own.name, 'Current User'); assert.equal(own.email, f.email);
  } else if (name === 'changePhoneNumber') {
    assert.equal(own.phone, f.normalized); assert.equal(own.phoneVerified, true);
    assert.equal((await db.collection('phone_otp_codes').doc(f.normalized).get()).exists, false);
  } else if (name === 'changeEmailAddress') {
    assert.equal(own.email, f.email); assert.equal(own.emailVerified, true);
  } else {
    assert.equal(own.dateOfBirth.toDate().toISOString(), '1990-01-01T00:00:00.000Z');
  }
}
(async () => {
  for (const name of names) {
    for (const [label, hint] of [['foreign', 'owner_b'], ['null', null], ['empty', ''], ['number', 42], ['boolean', true], ['array', ['owner_a']], ['object', { uid: 'owner_a' }]]) {
      await scenario(`${name} denies ${label} owner hint before database or verification IO`, async () => {
        await noDatabase(() => call(name, 'owner_a', { ...inputs(name), expectedOwnerId: hint }), 'permission-denied');
      });
    }
    await scenario(`${name} authentication checked before owner hint and IO`, async () => {
      await noDatabase(() => call(name, null, { ...inputs(name), expectedOwnerId: 'owner_a' }), 'unauthenticated');
    });
    await scenario(`${name} matching owner acts only on authenticated profile`, () => allowed(name, true));
    await scenario(`${name} missing legacy hint remains usable`, () => allowed(name, false));
    await scenario(`${name} switched transport with old hint preserves both profiles`, async () => {
      const f = await fixture(name);
      const ownBefore = (await db.collection('users').doc(f.uid).get()).data();
      const otherBefore = (await db.collection('users').doc(f.other).get()).data();
      await noDatabase(() => call(name, f.other, { ...f.data, expectedOwnerId: f.uid }), 'permission-denied');
      assert.deepEqual((await db.collection('users').doc(f.uid).get()).data(), ownBefore);
      assert.deepEqual((await db.collection('users').doc(f.other).get()).data(), otherBefore);
    });
    await scenario(`${name} valid owner retains existing business refusal`, async () => {
      const f = await fixture(name), data = { ...f.data, expectedOwnerId: f.uid };
      let code = 'invalid-argument';
      if (name === 'completeUserProfile') data.name = 'X';
      if (name === 'verifyEmailForProfile' || name === 'changePhoneNumber') data.otp = 'wrong';
      if (name === 'changeEmailAddress') { await db.collection('otp_codes').doc(f.email).delete(); code = 'failed-precondition'; }
      if (name === 'changeDateOfBirth') { data.dateOfBirth = new Date(Date.now() - 10 * 365.25 * 86400000).toISOString(); code = 'failed-precondition'; }
      await assert.rejects(() => call(name, f.uid, data), e => e.code === code);
    });
  }
  await scenario('complete profile owned retry remains idempotent', async () => {
    const f = await fixture('completeUserProfile'), data = { ...f.data, expectedOwnerId: f.uid };
    assert.equal((await call('completeUserProfile', f.uid, data)).alreadyComplete, false);
    assert.equal((await call('completeUserProfile', f.uid, data)).alreadyComplete, true);
  });
  await scenario('verified email owned retry retains same UID marker', async () => {
    const f = await fixture('verifyEmailForProfile'), data = { ...f.data, expectedOwnerId: f.uid };
    assert.equal((await call('verifyEmailForProfile', f.uid, data)).alreadyVerified, false);
    assert.equal((await call('verifyEmailForProfile', f.uid, data)).alreadyVerified, true);
  });
  console.log(`FOUNDATION14 ${passed} passed; ${failed} failed`);
  fft.cleanup(); await admin.app().delete(); process.exitCode = failed ? 1 : 0;
})().catch(e => { console.error(e); process.exitCode = 1; });
