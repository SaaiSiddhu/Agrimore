// Actual compiled seller helpers/Admin SDK demo transactions. Page transport
// failures are synthetic; no live planner/provider/public Auth/device proof.
const assert = require('node:assert/strict');
if (!/^(127\.0\.0\.1|localhost):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST || '')) throw Error('Loopback emulator required');
const PROJECT = 'demo-foundation-seller-pending-pages'; process.env.GCLOUD_PROJECT = PROJECT;
const admin = require('firebase-admin'); if (admin.apps.length) throw Error('Fresh demo SDK required'); admin.initializeApp({ projectId: PROJECT });
assert.equal(admin.app().options.projectId, PROJECT);
const db = admin.firestore(), { Timestamp } = require('firebase-admin/firestore'), W = require('../lib/seller/sellerWallet');
const NOW = Date.UTC(2026, 9, 5, 4), REQUEST = 'pending_page_request_01'; let seq = 0, passed = 0, failed = 0;
const get = async path => (await db.doc(path).get()).data();
const query = seller => db.collection('seller_payouts').where('sellerId', '==', seller).where('status', '==', 'pending');
async function scenario(label, fn) { try { await fn(); passed++; console.log(`PASS ${label}`); } catch (e) { failed++; console.log(`FAIL ${label}: ${e.message}`); } }
async function seed(f, count, make, prefix = 'p') {
  for (let start = 0; start < count; start += 300) {
    const batch = db.batch(); for (let i = start; i < Math.min(start + 300, count); i++) batch.set(db.doc(`seller_payouts/${f.seller}_${prefix}${String(i).padStart(5, '0')}`), { sellerId: f.seller, status: 'pending', netAmount: 1, createdAt: Timestamp.fromMillis(NOW - 86400000), orderId: `demo_order_${prefix}_${i}`, ...make(i) }); await batch.commit();
  }
}
async function fixture(count = 1, make = () => ({})) {
  await db.doc('settings/seller_wallet').set({ minWithdrawal: 0 }); const seller = `pending_page_${++seq}`, f = { seller, id: `${seller}_${REQUEST}` };
  await db.doc(`sellers/${seller}`).set({ shopName: 'Demo fixture' }); await db.doc(`seller_payout_details/${seller}`).set({ sellerId: seller, payoutMethod: 'upi', upiId: 'fixture@example.invalid' }); await seed(f, count, make); return f;
}
const request = (f, target = db) => W.requestWithdrawalCore(target, f.seller, REQUEST, NOW);
const summary = (f, target = db) => W.walletSummaryCore(target, f.seller, NOW);
const state = async f => ({ withdrawal: await get(`seller_withdrawals/${f.id}`), wallet: await get(`seller_wallets/${f.seller}`), rows: (await db.collection('seller_payouts').where('sellerId', '==', f.seller).get()).docs.map(p => ({ id: p.id, data: p.data() })) });
async function oracle(f) {
  const all = (await query(f.seller).get()).docs;
  const selected = all.filter(p => W.isWithdrawable(p.data(), NOW)).sort((a, b) => a.data().createdAt.toMillis() - b.data().createdAt.toMillis()).slice(0, 400);
  return { ids: selected.map(p => p.id), labels: selected.map(p => String(p.data().orderNumber || p.data().orderId || '')), paise: selected.reduce((s, p) => s + Math.round((p.data().netAmount ?? p.data().amount) * 100), 0) };
}
function trace({ rejectPage = 0, afterSettingsRead } = {}) {
  let hookRan = false;
  async function afterPoint(ref, snap) {
    if (!hookRan && ref.path === 'settings/seller_wallet' && afterSettingsRead) { hookRan = true; await afterSettingsRead(); }
    return snap;
  }
  const reads = { outsideQueries: 0, outsideDocuments: [], transactionDocuments: [], pages: [], options: [] };
  function wrapQuery(q) {
    return new Proxy(q, { get(target, k) {
      if (['where', 'limit', 'select', 'startAfter', 'orderBy'].includes(k)) return (...args) => wrapQuery(target[k](...args));
      if (k === 'get') return (...args) => { reads.outsideQueries++; return target.get(...args); };
      if (k === 'doc') return id => { const ref = target.doc(id), old = ref.get.bind(ref); ref.get = async (...args) => { reads.outsideDocuments.push(ref.path); return afterPoint(ref, await old(...args)); }; return ref; };
      const v = target[k]; return typeof v === 'function' ? v.bind(target) : v;
    } });
  }
  const proxy = new Proxy(db, { get(target, k) {
    if (k === 'collection') return name => wrapQuery(target.collection(name));
    if (k === 'runTransaction') return (cb, ...options) => { reads.options.push(options[0] ?? {}); return target.runTransaction(tx => cb(new Proxy(tx, { get(t, key) {
      if (key === 'get') return async (ref, ...args) => {
        if (typeof ref.path === 'string') { reads.transactionDocuments.push(ref.path); return afterPoint(ref, await t.get(ref, ...args)); }
        const page = { size: null }; reads.pages.push(page); if (rejectPage && reads.pages.length === rejectPage) throw Error('Synthetic later page unavailable');
        const snap = await t.get(ref, ...args); page.size = snap.size; return snap;
      };
      const v = t[key]; return typeof v === 'function' ? v.bind(t) : v;
    } })), ...options); };
    const v = target[k]; return typeof v === 'function' ? v.bind(target) : v;
  } }); return { db: proxy, reads };
}
function bounded(t, expectedRows) {
  assert.equal(t.reads.outsideQueries, 0, 'no materialized pending query outside transaction');
  assert(t.reads.pages.length > 0); assert(t.reads.pages.every(p => p.size <= 100), 'each actual transaction query returns at most100 documents');
  assert.equal(t.reads.pages.reduce((n, p) => n + p.size, 0), expectedRows, 'every pending row traversed exactly once');
}
(async () => {
  await scenario('summary covers1203 eligible plus future/legacy/assigned/zero with one snapshot', async () => {
    const f = await fixture(1203); await seed(f, 207, () => ({ netAmount: 2, createdAt: Timestamp.fromMillis(NOW + 86400000) }), 'future');
    await seed(f, 13, () => ({ netAmount: 3, createdAt: null }), 'legacy'); await seed(f, 11, () => ({ netAmount: null, withdrawalId: 'other_fixture_request' }), 'assigned'); await seed(f, 5, () => ({ netAmount: 0 }), 'zero');
    const t = trace(), s = await summary(f, t.db); assert.equal(s.availablePaise, 120300); assert.equal(s.availableCount, 1203); assert.equal(s.heldPaise, 45300); bounded(t, 1439);
    assert.equal(t.reads.options.length, 1); assert.equal(t.reads.options[0].readOnly, true); assert.equal(t.reads.outsideDocuments.length, 0);
    assert.deepEqual([...t.reads.transactionDocuments].sort(), ['settings/seller_wallet', `seller_wallets/${f.seller}`, `seller_payout_details/${f.seller}`].sort());
  });
  await scenario('summary retains one snapshot during actual concurrent settings/payout update', async () => {
    const f = await fixture(2), t = trace({ afterSettingsRead: async () => {
      const batch = db.batch(); batch.set(db.doc('settings/seller_wallet'), { minWithdrawal: 300 }); batch.update(db.doc(`seller_payouts/${f.seller}_p00000`), { netAmount: 9 }); await batch.commit();
    } });
    const s = await summary(f, t.db); assert.equal(s.availablePaise, 200); assert.equal(s.minWithdrawalPaise, 0);
    assert.equal((await get('settings/seller_wallet')).minWithdrawal, 300); assert.equal((await get(`seller_payouts/${f.seller}_p00000`)).netAmount, 9);
    const fresh = await summary(f); assert.equal(fresh.availablePaise, 1000); assert.equal(fresh.minWithdrawalPaise, 30000);
  });
  await scenario('new withdrawal picks oldest400 across1203 reverse-time doc-order rows', async () => {
    const f = await fixture(1203, i => ({ createdAt: Timestamp.fromMillis(NOW - 86400000 - i), orderNumber: `DEMO-${i}` })), expected = await oracle(f), t = trace(), v = await request(f, t.db), w = await get(`seller_withdrawals/${f.id}`);
    assert.equal(v.amountPaise, expected.paise); assert.equal(v.count, 400); assert.deepEqual(w.payoutIds, expected.ids); assert.deepEqual(w.orderNumbers, expected.labels); bounded(t, 1203);
    assert.equal((await query(f.seller).get()).size, 803);
  });
  await scenario('timestamp ties preserve legacy implicit SDK ID ordering across pages', async () => {
    const f = await fixture(395); for (const suffix of ['Z0', 'Z1', 'Z2', 'Z3', 'Z4', 'é', 'α', '😀', '𐀀', 'Ω']) await db.doc(`seller_payouts/${f.seller}_${suffix}`).set({ sellerId: f.seller, status: 'pending', netAmount: 1, createdAt: Timestamp.fromMillis(NOW - 86400000), orderNumber: `DEMO-${suffix}` });
    const expected = await oracle(f), t = trace(); await request(f, t.db); const w = await get(`seller_withdrawals/${f.id}`); assert.deepEqual(w.payoutIds, expected.ids); assert.deepEqual(w.orderNumbers, expected.labels); bounded(t, 405);
  });
  await scenario('all future rows are traversed but create no withdrawal', async () => {
    const f = await fixture(451, () => ({ createdAt: Timestamp.fromMillis(NOW + 86400000) })), before = await state(f), t = trace(); assert.equal((await request(f, t.db)).reason, 'nothing_to_withdraw'); bounded(t, 451); assert.deepEqual(await state(f), before);
  });
  await scenario('corruption on a late page beyond oldest400 refuses before effects', async () => {
    const f = await fixture(1103, i => i === 1102 ? { netAmount: null, createdAt: Timestamp.fromMillis(NOW + 86400000) } : {}), before = await state(f), t = trace();
    await assert.rejects(request(f, t.db), e => e.details?.reason === 'bad_money_state'); assert(t.reads.pages.every(p => p.size <= 100)); assert(t.reads.pages.length >= 12); assert.deepEqual(await state(f), before);
  });
  await scenario('summary second-page transport refusal returns no partial result', async () => {
    const f = await fixture(301), before = await state(f), t = trace({ rejectPage: 2 }); await assert.rejects(summary(f, t.db), /Synthetic later page unavailable/); assert.deepEqual(await state(f), before);
  });
  await scenario('withdrawal second-page transport refusal writes nothing', async () => {
    const f = await fixture(301), before = await state(f), t = trace({ rejectPage: 2 }); await assert.rejects(request(f, t.db), /Synthetic later page unavailable/); assert.deepEqual(await state(f), before);
  });
  for (const reason of ['withdrawal_open', 'payout_change_pending', 'not_a_seller', 'no_destination']) await scenario(`preflight ${reason} issues no payout query`, async () => {
    const f = await fixture(301);
    if (reason === 'withdrawal_open') await db.doc(`seller_wallets/${f.seller}`).set({ openWithdrawal: 'other_fixture_request' });
    if (reason === 'payout_change_pending') await db.doc(`seller_wallets/${f.seller}`).set({ payoutChangePending: 'fixture_change' });
    if (reason === 'not_a_seller') await db.doc(`sellers/${f.seller}`).delete();
    if (reason === 'no_destination') await db.doc(`seller_payout_details/${f.seller}`).delete();
    const before = await state(f), t = trace(); assert.equal((await request(f, t.db)).reason, reason); assert.equal(t.reads.pages.length, 0); assert.deepEqual(await state(f), before);
  });
  await scenario('completed request retry remains exactly anchor-only', async () => {
    const f = await fixture(501); await request(f); const before = await state(f), t = trace(); assert.equal((await request(f, t.db)).kind, 'already');
    assert.deepEqual(t.reads.transactionDocuments, [`seller_withdrawals/${f.id}`]); assert.equal(t.reads.pages.length, 0); assert.equal(t.reads.outsideDocuments.length, 0); assert.deepEqual(await state(f), before);
  });
  await scenario('legacy alias/rounding/cutoff/labels remain unchanged', async () => {
    const f = await fixture(0); await db.doc(`seller_payouts/${f.seller}_alias`).set({ sellerId: f.seller, status: 'pending', amount: 96.525, createdAt: Timestamp.fromMillis(NOW), orderId: 'DEMO-ALIAS' });
    await db.doc(`seller_payouts/${f.seller}_held`).set({ sellerId: f.seller, status: 'pending', netAmount: 2, createdAt: null });
    const s = await summary(f); assert.equal(s.availablePaise, 9653); assert.equal(s.heldPaise, 200); assert.equal((await request(f)).amountPaise, 9653); assert.deepEqual((await get(`seller_withdrawals/${f.id}`)).orderNumbers, ['DEMO-ALIAS']);
  });
  await scenario('concurrent same request still produces one economic transition', async () => {
    const f = await fixture(201), v = await Promise.all([request(f), request(f)]); assert.deepEqual(v.map(x => x.kind).sort(), ['already', 'requested']); assert.equal((await get(`seller_withdrawals/${f.id}`)).amountPaise, 20100);
  });
  console.log(`RESULT ${passed} passed; ${failed} failed`); await db.terminate(); await admin.app().delete(); process.exitCode = failed ? 1 : 0;
})().catch(e => { console.error(e.message); process.exitCode = 1; });
