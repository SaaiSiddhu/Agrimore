// Actual compiled seller withdrawal transitions/Admin SDK demo transactions.
// No provider, public callable authorization, live rules or device proof.
const assert = require('node:assert/strict');
if (!/^(127\.0\.0\.1|localhost):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST || '')) throw Error('Loopback emulator required');
const PROJECT = 'demo-foundation-seller-withdrawal-integrity'; process.env.GCLOUD_PROJECT = PROJECT;
const admin = require('firebase-admin'); if (admin.apps.length) throw Error('Fresh demo SDK required');
admin.initializeApp({ projectId: PROJECT }); assert.equal(admin.app().options.projectId, PROJECT);
const db = admin.firestore(), { Timestamp } = require('firebase-admin/firestore'), W = require('../lib/seller/sellerWallet');
const NOW = Date.UTC(2026, 9, 5, 2); let seq = 0, passed = 0, failed = 0;
const get = async path => (await db.doc(path).get()).data();
async function scenario(label, fn) { try { await fn(); passed++; console.log(`PASS ${label}`); } catch (e) { failed++; console.log(`FAIL ${label}: ${e.message}`); } }
async function fixture() {
  const seller = `integrity_seller_${++seq}`, id = `${seller}_withdrawal`, ids = [`${seller}_a`, `${seller}_b`];
  await db.doc(`seller_wallets/${seller}`).set({ sellerId: seller, openWithdrawal: id });
  for (const [i, pid] of ids.entries()) await db.doc(`seller_payouts/${pid}`).set({ sellerId: seller, withdrawalId: id, status: 'requested', netAmount: (i + 1) * 100 });
  await db.doc(`seller_withdrawals/${id}`).set({ sellerId: seller, status: 'requested', amountPaise: 30000, payoutCount: 2, payoutIds: ids,
    destination: { method: 'upi', upiId: 'fixture@example.invalid' }, destinationFull: { payoutMethod: 'upi', upiId: 'fixture@example.invalid' }, createdAt: Timestamp.fromMillis(NOW) });
  return { seller, id, ids };
}
const state = async f => Promise.all([get(`seller_withdrawals/${f.id}`), get(`seller_wallets/${f.seller}`), ...f.ids.map(pid => get(`seller_payouts/${pid}`))]);
const act = (f, mode, target = db) => mode === 'pay'
  ? W.markWithdrawalPaidCore(target, 'fixture_admin', f.id, 'DEMO-REFERENCE-01', 'upi', NOW + 1)
  : W.closeWithdrawalCore(target, mode === 'reject' ? { adminUid: 'fixture_admin' } : { sellerId: f.seller }, f.id, mode === 'reject' ? 'Demo review reason' : null, NOW + 1);
function trace() {
  const reads = [];
  const proxy = new Proxy(db, { get(target, key) {
    if (key === 'runTransaction') return cb => target.runTransaction(tx => cb(new Proxy(tx, { get(t, k) {
      if (k === 'get') return (ref, ...args) => { reads.push(ref.path); return t.get(ref, ...args); };
      const v = t[k]; return typeof v === 'function' ? v.bind(t) : v;
    } })));
    const v = target[key]; return typeof v === 'function' ? v.bind(target) : v;
  } }); return { db: proxy, reads };
}
const updateW = (f, data) => db.doc(`seller_withdrawals/${f.id}`).update(data);
const updateP = (f, data) => db.doc(`seller_payouts/${f.ids[0]}`).update(data);
// The original malformed-path code starts an unawaited wallet SDK read before
// throwing; baseline/mutation may omit those three cases to finish cleanly.
const args = process.argv.slice(2);
if (args.some(a => a !== '--skip-malformed-path')) throw Error('Unknown test option');
const skipMalformedPath = args.includes('--skip-malformed-path');
const corruptions = [
  ['empty member list', f => updateW(f, { payoutIds: [], payoutCount: 0 }), true],
  ['duplicate member list', f => updateW(f, { payoutIds: [f.ids[0], f.ids[0]], amountPaise: 20000 }), true],
  ['nonnumeric member identifier', f => updateW(f, { payoutIds: [123, f.ids[1]] }), true],
  ['nested path member identifier', f => updateW(f, { payoutIds: ['a/b', f.ids[1]] }), true],
  ['more than400 members', f => updateW(f, { payoutIds: Array.from({ length: 401 }, (_, i) => `${f.seller}_excess_${i}`), payoutCount: 401 }), true],
  ['count does not equal membership', f => updateW(f, { payoutCount: 1 }), true],
  ['explicit invalid count', f => updateW(f, { payoutCount: '2' }), true],
  ['withdrawal amount mismatch', f => updateW(f, { amountPaise: 30001 })],
  ['nonnumeric withdrawal amount', f => updateW(f, { amountPaise: '30000' }), true],
  ['fractional withdrawal paise', f => updateW(f, { amountPaise: 30000.5 }), true],
  ['unsafe withdrawal paise', f => updateW(f, { amountPaise: Number.MAX_SAFE_INTEGER + 1 }), true],
  ['zero withdrawal paise', f => updateW(f, { amountPaise: 0 }), true],
  ['wrong seller member', f => updateP(f, { sellerId: 'different_fixture_owner' })],
  ['missing member', f => db.doc(`seller_payouts/${f.ids[0]}`).delete()],
  ['wrong member withdrawal', f => updateP(f, { withdrawalId: 'other_fixture_withdrawal' })],
  ['already paid member', f => updateP(f, { status: 'paid' })],
  ['negative member amount', f => updateP(f, { netAmount: -100 })],
  ['nonfinite member amount', f => updateP(f, { netAmount: Infinity })],
  ['explicit nonnumeric net cannot use alias', f => updateP(f, { netAmount: '100', amount: 100 })],
  ['explicit null net cannot use alias', f => updateP(f, { netAmount: null, amount: 100 })],
  ['unsafe rounded member amount', f => updateP(f, { netAmount: Number.MAX_SAFE_INTEGER })],
];
(async () => {
  for (const mode of ['pay', 'reject', 'cancel']) {
    await scenario(`${mode}: consistent membership transitions atomically`, async () => {
      const f = await fixture(), v = await act(f, mode), after = await state(f), target = { pay: 'paid', reject: 'rejected', cancel: 'cancelled' }[mode];
      assert.equal(v.kind, target); assert.equal(v.amountPaise, 30000); assert.equal(after[0].status, target); assert.equal(after[1].openWithdrawal, null);
      for (const p of after.slice(2)) { assert.equal(p.status, mode === 'pay' ? 'paid' : 'pending'); if (mode !== 'pay') assert.equal(p.withdrawalId, undefined); }
    });
    for (const [label, corrupt, beforeOtherReads] of corruptions.filter(row => !skipMalformedPath || row[0] !== 'nested path member identifier')) await scenario(`${mode}: refuses ${label} without effects`, async () => {
      const f = await fixture(); await corrupt(f); const before = await state(f), t = trace();
      assert.deepEqual(await act(f, mode, t.db), { kind: 'refused', reason: 'payout_mismatch' }); assert.deepEqual(await state(f), before);
      if (beforeOtherReads) assert.deepEqual(t.reads, [`seller_withdrawals/${f.id}`], 'invalid declared set/money must fail before linked reads');
    });
    await scenario(`${mode}: exact400 member boundary remains usable`, async () => {
      const f = await fixture(), batch = db.batch();
      for (let i = 2; i < 400; i++) {
        const pid = `${f.seller}_boundary_${i}`; f.ids.push(pid);
        batch.set(db.doc(`seller_payouts/${pid}`), { sellerId: f.seller, withdrawalId: f.id, status: 'requested', netAmount: 1 });
      }
      await batch.commit(); await updateW(f, { payoutIds: f.ids, payoutCount: 400, amountPaise: 69800 });
      const value = await act(f, mode), after = await state(f);
      assert.equal(value.kind, { pay: 'paid', reject: 'rejected', cancel: 'cancelled' }[mode]); assert.equal(value.amountPaise, 69800);
      assert.equal(after[1].openWithdrawal, null); assert.equal(after.slice(2).length, 400);
      for (const row of after.slice(2)) assert.equal(row.status, mode === 'pay' ? 'paid' : 'pending');
    });
    await scenario(`${mode}: absent legacy count and amount alias remain compatible`, async () => {
      const f = await fixture(); await updateW(f, { payoutCount: admin.firestore.FieldValue.delete() });
      await updateP(f, { netAmount: admin.firestore.FieldValue.delete(), amount: 100 });
      assert.equal((await act(f, mode)).kind, { pay: 'paid', reject: 'rejected', cancel: 'cancelled' }[mode]);
    });
    await scenario(`${mode}: legacy fractional commission keeps existing row rounding`, async () => {
      const f = await fixture(); await updateP(f, { netAmount: 96.525 }); await updateW(f, { amountPaise: Math.round(96.525 * 100) + 20000 });
      assert.equal((await act(f, mode)).amountPaise, 29653);
    });
    await scenario(`${mode}: target replay ignores later malformed member data`, async () => {
      const f = await fixture(); await act(f, mode); await updateW(f, { payoutIds: [], payoutCount: 'legacy_bad' });
      const before = await state(f), t = trace(); assert.equal((await act(f, mode, t.db)).kind, 'already'); assert.deepEqual(t.reads, [`seller_withdrawals/${f.id}`]); assert.deepEqual(await state(f), before);
    });
  }
  await scenario('pending destination change blocks payment without effects', async () => {
    const f = await fixture(); await db.doc(`seller_wallets/${f.seller}`).update({ payoutChangePending: 'fixture_change' }); const before = await state(f);
    assert.deepEqual(await act(f, 'pay'), { kind: 'refused', reason: 'payout_change_pending' }); assert.deepEqual(await state(f), before);
  });
  await scenario('different seller cannot cancel withdrawal', async () => {
    const f = await fixture(), before = await state(f);
    assert.deepEqual(await W.closeWithdrawalCore(db, { sellerId: 'different_fixture_owner' }, f.id, null, NOW), { kind: 'refused', reason: 'not_yours' }); assert.deepEqual(await state(f), before);
  });
  await scenario('concurrent pay and cancel cannot both settle', async () => {
    const f = await fixture(), values = await Promise.all([act(f, 'pay'), act(f, 'cancel')]); assert.equal(values.filter(v => v.kind === 'paid' || v.kind === 'cancelled').length, 1);
    const [w, a, ...p] = await state(f); assert.equal(a.openWithdrawal, null); for (const row of p) assert.equal(row.status, w.status === 'paid' ? 'paid' : 'pending');
  });
  if (skipMalformedPath) console.log('SKIPPED 3 malformed-path controls for original-read-order SDK cleanup; full fixed run includes them');
  console.log(`RESULT ${passed} passed; ${failed} failed`); await db.terminate(); await admin.app().delete(); process.exitCode = failed ? 1 : 0;
})().catch(e => { console.error(e.message); process.exitCode = 1; });
