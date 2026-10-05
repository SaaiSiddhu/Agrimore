// Actual compiled seller core/Admin SDK demo transactions. Transport refusal is
// synthetic; this does not verify public callable auth, provider or live rules.
const assert = require('node:assert/strict');
if (!/^(127\.0\.0\.1|localhost):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST || '')) throw Error('Loopback emulator required');
const PROJECT = 'demo-foundation-seller-withdrawal-replay';
process.env.GCLOUD_PROJECT = PROJECT;
const admin = require('firebase-admin');
if (admin.apps.length) throw Error('Fresh demo SDK required');
admin.initializeApp({ projectId: PROJECT });
assert.equal(admin.app().options.projectId, PROJECT);
const db = admin.firestore(), { Timestamp } = require('firebase-admin/firestore');
const W = require('../lib/seller/sellerWallet');
const NOW = Date.UTC(2026, 9, 5, 1), REQUEST = 'request_fixture_01';
let seq = 0, passed = 0, failed = 0;
const get = async path => (await db.doc(path).get()).data();
async function scenario(label, fn) {
  try { await fn(); passed++; console.log(`PASS ${label}`); }
  catch (e) { failed++; console.log(`FAIL ${label}: ${e.message}`); }
}
function trace({ rejectQuery = false } = {}) {
  const reads = { documents: [], queries: [] };
  const traced = new Proxy(db, { get(target, key) {
    if (key === 'runTransaction') return callback => target.runTransaction(tx => callback(new Proxy(tx, { get(t, k) {
      if (k === 'get') return async (ref, ...options) => {
        if (typeof ref.path === 'string') { reads.documents.push(ref.path); return t.get(ref, ...options); }
        const row = { size: null }; reads.queries.push(row);
        if (rejectQuery) throw Object.assign(Error('Synthetic unavailable query transport'), { code: 'unavailable' });
        const snap = await t.get(ref, ...options); row.size = snap.size; return snap;
      };
      const v = t[k]; return typeof v === 'function' ? v.bind(t) : v;
    } })));
    const v = target[key]; return typeof v === 'function' ? v.bind(target) : v;
  } });
  return { db: traced, reads };
}
async function fixture() {
  const seller = `seller_replay_${++seq}`, payout = `${seller}_earning`;
  await db.doc(`sellers/${seller}`).set({ shopName: 'Demo fixture' });
  await db.doc(`seller_payout_details/${seller}`).set({ sellerId: seller, payoutMethod: 'upi', upiId: 'fixture@example.invalid' });
  await db.doc(`seller_payouts/${payout}`).set({ sellerId: seller, status: 'pending', netAmount: 200, createdAt: Timestamp.fromMillis(NOW - 86400000) });
  return { seller, payout, id: `${seller}_${REQUEST}` };
}
const request = (f, target = db) => W.requestWithdrawalCore(target, f.seller, REQUEST, NOW);
function onlyAnchor(t, f) {
  assert.equal(t.reads.queries.length, 0, 'replay must not scan pending payouts');
  assert.deepEqual(t.reads.documents, [`seller_withdrawals/${f.id}`], 'replay must read only its transaction anchor');
}
const state = async f => Promise.all([get(`seller_withdrawals/${f.id}`), get(`seller_wallets/${f.seller}`), get(`seller_payouts/${f.payout}`)]);
(async () => {
  await scenario('new request preserves owned amount and frozen destination', async () => {
    const f = await fixture(), v = await request(f), [w, a, p] = await state(f);
    assert.deepEqual(v, { kind: 'requested', id: f.id, amountPaise: 20000, count: 1 });
    assert.equal(w.sellerId, f.seller); assert.deepEqual(w.payoutIds, [f.payout]); assert.equal(w.destinationFull.upiId, 'fixture@example.invalid');
    assert.equal(a.openWithdrawal, f.id); assert.equal(p.status, 'requested'); assert.equal(p.withdrawalId, f.id);
  });
  await scenario('existing request reads only anchor without economics', async () => {
    const f = await fixture(); await request(f); const before = await state(f), t = trace();
    assert.deepEqual(await request(f, t.db), { kind: 'already', id: f.id, amountPaise: 20000, count: 1 }); onlyAnchor(t, f); assert.deepEqual(await state(f), before);
  });
  await scenario('existing request survives unavailable pending query', async () => {
    const f = await fixture(); await request(f); const before = await state(f), t = trace({ rejectQuery: true });
    assert.equal((await request(f, t.db)).kind, 'already'); onlyAnchor(t, f); assert.deepEqual(await state(f), before);
  });
  await scenario('replay never rereads a later600 row backlog', async () => {
    const f = await fixture(); await request(f);
    for (let start = 0; start < 600; start += 300) {
      const batch = db.batch(); for (let i = start; i < start + 300; i++) batch.set(db.doc(`seller_payouts/${f.seller}_later_${i}`), { sellerId: f.seller, status: 'pending', netAmount: 1, createdAt: Timestamp.fromMillis(NOW) }); await batch.commit();
    }
    const before = await state(f), t = trace(); assert.equal((await request(f, t.db)).amountPaise, 20000); onlyAnchor(t, f); assert.deepEqual(await state(f), before);
    assert.equal((await db.collection('seller_payouts').where('sellerId', '==', f.seller).where('status', '==', 'pending').get()).size, 600);
  });
  await scenario('later wallet and destination changes cannot redirect replay', async () => {
    const f = await fixture(); await request(f);
    await db.doc(`seller_wallets/${f.seller}`).update({ payoutChangePending: 'later_change', openWithdrawal: 'later_withdrawal' });
    await db.doc(`seller_payout_details/${f.seller}`).set({ payoutMethod: 'upi', upiId: 'changed@example.invalid' });
    const before = await state(f), t = trace(); assert.equal((await request(f, t.db)).kind, 'already'); onlyAnchor(t, f); assert.deepEqual(await state(f), before);
  });
  await scenario('missing later seller identity does not change historical replay', async () => {
    const f = await fixture(); await request(f); await db.doc(`sellers/${f.seller}`).delete();
    const before = await state(f), t = trace(); assert.equal((await request(f, t.db)).kind, 'already'); onlyAnchor(t, f); assert.deepEqual(await state(f), before);
  });
  await scenario('paid withdrawal replay remains historical and effect free', async () => {
    const f = await fixture(); await request(f); assert.equal((await W.markWithdrawalPaidCore(db, 'demo_admin', f.id, 'DEMO-PAID-01', 'upi', NOW + 1)).kind, 'paid');
    const before = await state(f), t = trace(); assert.equal((await request(f, t.db)).kind, 'already'); onlyAnchor(t, f); assert.deepEqual(await state(f), before);
  });
  await scenario('cancelled withdrawal replay does not request released payouts again', async () => {
    const f = await fixture(); await request(f); assert.equal((await W.closeWithdrawalCore(db, { sellerId: f.seller }, f.id, null, NOW + 1)).kind, 'cancelled');
    const before = await state(f), t = trace(); assert.equal((await request(f, t.db)).kind, 'already'); onlyAnchor(t, f); assert.deepEqual(await state(f), before);
    assert.equal((await get(`seller_payouts/${f.payout}`)).status, 'pending');
  });
  await scenario('mismatched stored owner is refused before unrelated reads', async () => {
    const f = await fixture(); await db.doc(`seller_withdrawals/${f.id}`).set({ sellerId: 'other_fixture_owner', amountPaise: 99999, payoutCount: 1, status: 'requested' });
    const before = await state(f), t = trace(); assert.deepEqual(await request(f, t.db), { kind: 'refused', reason: 'bad_request_id' }); onlyAnchor(t, f); assert.deepEqual(await state(f), before);
  });
  await scenario('new request unavailable query fails before all effects', async () => {
    const f = await fixture(), before = await state(f), t = trace({ rejectQuery: true });
    await assert.rejects(request(f, t.db), /Synthetic unavailable/); assert.deepEqual(await state(f), before);
  });
  await scenario('concurrent same request creates one withdrawal', async () => {
    const f = await fixture(), values = await Promise.all([request(f), request(f)]);
    assert.deepEqual(values.map(v => v.kind).sort(), ['already', 'requested']);
    assert.equal((await db.collection('seller_withdrawals').where('sellerId', '==', f.seller).get()).size, 1);
    assert.equal((await get(`seller_withdrawals/${f.id}`)).amountPaise, 20000);
  });
  await scenario('bad request format is refused without transaction reads', async () => {
    const f = await fixture(), t = trace(); assert.deepEqual(await W.requestWithdrawalCore(t.db, f.seller, '/', NOW), { kind: 'refused', reason: 'bad_request_id' });
    assert.deepEqual(t.reads, { documents: [], queries: [] }); assert.equal(await get(`seller_withdrawals/${f.id}`), undefined);
  });
  console.log(`RESULT ${passed} passed; ${failed} failed`); await db.terminate(); await admin.app().delete(); process.exitCode = failed ? 1 : 0;
})().catch(e => { console.error(e.message); process.exitCode = 1; });
