// Actual exported accrual handlers and Firestore/rules SDK, strict demo only.
// Trusted synthetic admin contexts; no HTTP/provider/native/production proof.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
for (const key of ['FIRESTORE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_HOST', 'FIREBASE_STORAGE_EMULATOR_HOST']) {
  if (!/^(127\.0\.0\.1|localhost|\[::1\]):\d+$/.test(process.env[key] || '')) throw Error('Loopback emulators required');
}
const project = process.env.GCLOUD_PROJECT;
if (!/^demo-/.test(project || '')) throw Error('Demo project required');
process.env.STORAGE_EMULATOR_HOST = 'http://' + process.env.FIREBASE_STORAGE_EMULATOR_HOST;
const admin = require('firebase-admin');
const app = admin.initializeApp({ projectId: project });
const db = app.firestore();
const { runBenefitAccrualNow, accrueMonthlyBenefits } = require('../lib/customer/benefitAccrual');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, updateDoc, deleteDoc } = require('firebase/firestore');
const period = '2026-10';
const cursor = db.doc('benefit_accrual_cursors/' + period);
let env, passed = 0, failed = 0;
async function batches(entries, remove = false) {
  for (let i = 0; i < entries.length; i += 450) {
    const batch = db.batch();
    for (const entry of entries.slice(i, i + 450)) remove ? batch.delete(entry) : batch.set(entry.ref, entry.data);
    await batch.commit();
  }
}
async function reset() {
  for (const collection of ['benefit_enrollments', 'benefit_accruals', 'benefit_accrual_cursors', 'product_credit_ledger', 'product_credit_balances', 'compliance_audit_log']) {
    await batches((await db.collection(collection).get()).docs.map(d => d.ref), true);
  }
  await db.doc('compliance_config/benefit_program').set({ legalReviewStatus: 'APPROVED', complianceApprovalStatus: 'APPROVED' });
  await db.doc('feature_flags/benefit_program').set({ BENEFIT_PROGRAM_ENABLED: true, MONTHLY_CREDIT_ENABLED: true });
  await db.doc('benefit_programs/page-test').set({ status: 'active', benefitRuleType: 'flatRupee', benefitRateValue: 1, creditFrequency: 'monthly', rulesVersion: 1 });
}
function enrollment() {
  return { customerId: 'benefit-owner', status: 'active', programId: 'page-test', startDate: admin.firestore.Timestamp.fromDate(new Date('2026-01-01T00:00:00Z')), programAmount: 1, rulesVersionAtEnrollment: 1 };
}
async function enroll(id) { await db.doc('benefit_enrollments/' + id).set(enrollment()); }
async function tailFixture() {
  await reset();
  const rows = [];
  for (let i = 0; i < 500; i++) {
    const id = 'a_head_' + String(i).padStart(3, '0');
    rows.push({ ref: db.doc('benefit_enrollments/' + id), data: enrollment() });
    rows.push({ ref: db.doc('benefit_accruals/' + id + '_' + period), data: { enrollmentId: id, customerId: 'benefit-owner', period, calculatedAmount: 0, status: 'zero' } });
  }
  await batches(rows);
  await enroll('z_tail');
}
const run = (p = period) => runBenefitAccrualNow.run({ auth: { uid: 'synthetic-page-admin', token: { admin: true } }, data: { period: p, reason: 'Synthetic bounded progression test' } });
async function balance() { return (await db.doc('product_credit_balances/benefit-owner').get()).get('available') || 0; }
async function credits() { return (await db.collection('product_credit_ledger').where('type', '==', 'CREDIT').get()).size; }
async function check(name, fn) {
  try { await fn(); passed++; console.log('PASS ' + name); }
  catch (e) { failed++; console.error('FAIL ' + name + ': ' + e.name + ' ' + e.message); }
}
async function main() {
  env = await initializeTestEnvironment({ projectId: project, firestore: { host: '127.0.0.1', port: 8080, rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8') } });
  await check('501st eligible enrollment progresses past already anchored first500', async () => {
    await tailFixture(); const first = await run(), second = await run();
    if (second.credited !== 1) console.log('OBSERVED accrual starvation: firstProcessed=' + first.processed + ' secondProcessed=' + second.processed + ' tailCredited=' + second.credited);
    assert.equal(first.processed, 500); assert.equal(first.truncated, true); assert.equal(first.credited, 0);
    assert.equal(second.processed, 1); assert.equal(second.credited, 1); assert.equal(await balance(), 1);
    assert.equal((await db.doc('benefit_accruals/z_tail_' + period).get()).get('calculatedAmount'), 1);
    assert.equal((await cursor.get()).get('version'), 2); assert.equal((await cursor.get()).get('lastEnrollmentId'), null);
    await run(); assert.equal(await credits(), 1); assert.equal(await balance(), 1);
  });
  await check('new earlier enrollment revisited after cycle reset', async () => {
    await tailFixture(); await run(); await enroll('a_early_new'); await run();
    assert.equal((await db.doc('benefit_accruals/a_early_new_' + period).get()).exists, false);
    await run(); assert.equal((await db.doc('benefit_accruals/a_early_new_' + period).get()).exists, true); assert.equal(await balance(), 2);
  });
  await check('period cursors and economic anchors are isolated', async () => {
    await reset(); await enroll('one'); await run(); await run('2026-11'); await run(); await run('2026-11');
    assert.equal(await balance(), 2); assert.equal(await credits(), 2);
    assert.equal((await cursor.get()).get('version'), 2); assert.equal((await db.doc('benefit_accrual_cursors/2026-11').get()).get('version'), 2);
    assert.equal((await db.doc('benefit_accruals/one_2026-10').get()).exists, true); assert.equal((await db.doc('benefit_accruals/one_2026-11').get()).exists, true);
  });
  await check('partial page failure never advances and replay never doubles credit', async () => {
    await reset(); for (const id of ['entry_0', 'entry_1', 'entry_2']) await enroll(id);
    const original = db.runTransaction; let fired = false;
    db.runTransaction = function (fn, ...args) { return original.call(this, async tx => {
      const get = tx.get.bind(tx); tx.get = async (ref, ...rest) => {
        if (!fired && ref.path === 'benefit_enrollments/entry_1') { fired = true; throw Error('Synthetic page interruption'); }
        return get(ref, ...rest);
      }; return fn(tx);
    }, ...args); };
    try { await assert.rejects(() => run()); assert.equal(fired, true); } finally { db.runTransaction = original; }
    assert.equal((await cursor.get()).exists, false); await run(); await run(); assert.equal(await credits(), 3); assert.equal(await balance(), 3);
  });
  await check('older overlapping run cannot regress two newer checkpoints', async () => {
    await reset(); await enroll('overlap');
    let enteredResolve, resumeResolve, held = false;
    const entered = new Promise(r => enteredResolve = r), resume = new Promise(r => resumeResolve = r), original = db.runTransaction;
    db.runTransaction = function (fn, ...args) { return original.call(this, async tx => {
      const get = tx.get.bind(tx); tx.get = async (ref, ...rest) => {
        if (!held && ref.path === cursor.path) { held = true; enteredResolve(); await resume; }
        return get(ref, ...rest);
      }; return fn(tx);
    }, ...args); };
    const first = run();
    try {
      await Promise.race([entered, new Promise((_, reject) => setTimeout(() => reject(Error('Checkpoint pause not reached')), 5000))]);
      await run(); await run(); assert.equal((await cursor.get()).get('version'), 2); resumeResolve(); await first;
      const version = (await cursor.get()).get('version'); if (version !== 2) console.log('OBSERVED accrual checkpoint regression: expectedVersion=2 actualVersion=' + version);
      assert.equal(version, 2); assert.equal(await credits(), 1); assert.equal(await balance(), 1);
    } finally { resumeResolve(); await first.catch(() => {}); db.runTransaction = original; }
  });
  await check('empty period writes valid reset checkpoint', async () => {
    await reset(); const result = await run(); assert.equal(result.processed, 0); assert.equal((await cursor.get()).get('version'), 1); assert.equal((await cursor.get()).get('lastEnrollmentId'), null);
  });
  for (const bad of [{ version: 0, lastEnrollmentId: null }, { version: -1, lastEnrollmentId: null }, { version: Number.MAX_SAFE_INTEGER, lastEnrollmentId: null }, { version: 1 }, { version: 1, lastEnrollmentId: '' }, { version: 1, lastEnrollmentId: 'bad/path' }, { version: 1, lastEnrollmentId: 1 }]) {
    await check('malformed period cursor refuses before economic writes ' + JSON.stringify(bad), async () => {
      await reset(); await enroll('valid'); await cursor.set(bad); await assert.rejects(() => run());
      assert.equal(await credits(), 0); assert.equal((await db.doc('benefit_accruals/valid_' + period).get()).exists, false); assert.deepEqual((await cursor.get()).data(), bad);
    });
  }
  await check('monthly and compliance gates do not consume malformed checkpoint', async () => {
    await reset(); await enroll('gated'); await cursor.set({ version: 0 });
    await db.doc('feature_flags/benefit_program').update({ MONTHLY_CREDIT_ENABLED: false }); const disabled = await run(); assert.equal(disabled.monthlyCreditDisabled, true);
    await db.doc('feature_flags/benefit_program').update({ MONTHLY_CREDIT_ENABLED: true }); await db.doc('compliance_config/benefit_program').update({ legalReviewStatus: 'PENDING' });
    const held = await run(); assert.equal(held.notLaunchable, true); assert.equal(await credits(), 0); assert.deepEqual((await cursor.get()).data(), { version: 0 });
  });
  await check('ordinary actor and admin without reason cannot accrue', async () => {
    await reset(); await enroll('protected');
    await assert.rejects(() => runBenefitAccrualNow.run({ auth: { uid: 'benefit-owner', token: {} }, data: { period, reason: 'Attempt' } }), e => e.code === 'permission-denied');
    await assert.rejects(() => runBenefitAccrualNow.run({ auth: { uid: 'synthetic-page-admin', token: { admin: true } }, data: { period } }), e => e.code === 'invalid-argument');
    assert.equal(await credits(), 0); assert.equal((await cursor.get()).exists, false);
  });
  await check('scheduled handler uses same bounded period checkpoint', async () => {
    await reset(); await enroll('scheduled'); const result = await accrueMonthlyBenefits.run({});
    const p = new Date().toISOString().slice(0, 7); assert.equal(result.credited, 1); assert.equal((await db.doc('benefit_accrual_cursors/' + p).get()).get('version'), 1);
  });
  await reset(); await cursor.set({ version: 1, lastEnrollmentId: null }); await db.doc('product_credit_balances/benefit-owner').set({ available: 1 });
  for (const [name, claims] of [['benefit-owner', {}], ['foreign', {}], ['admin', { admin: true }], ['anonymous', null]]) {
    await check(name + ' client cannot read-create-update-delete period cursor', async () => {
      const context = claims === null ? env.unauthenticatedContext() : env.authenticatedContext(name, claims), ref = doc(context.firestore(), 'benefit_accrual_cursors/' + period);
      await assertFails(getDoc(ref)); await assertFails(setDoc(doc(context.firestore(), 'benefit_accrual_cursors/new'), { version: 1 })); await assertFails(updateDoc(ref, { version: 2 })); await assertFails(deleteDoc(ref));
    });
  }
  await check('owner balance read stays authorized', async () => { await assertSucceeds(getDoc(doc(env.authenticatedContext('benefit-owner').firestore(), 'product_credit_balances/benefit-owner'))); });
  console.log(`SUMMARY ${passed} passed ${failed} failed`); if (failed) process.exitCode = 1;
}
main().catch(e => { console.error('Fixture failure: ' + e.name + ' ' + e.message); process.exitCode = 1; }).finally(async () => { if (env) await env.cleanup(); await app.delete(); });
