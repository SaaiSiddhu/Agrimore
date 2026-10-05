// Actual compiled seller cores/Admin SDK on loopback demo Firestore. Explicit
// unavailable-settings transport is synthetic. No live/provider/rules/device proof.
const assert = require('node:assert/strict');
if (!/^(127\.0\.0\.1|localhost):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST || '')) throw Error('Loopback emulator required');
const PROJECT = 'demo-foundation-seller-wallet-money'; process.env.GCLOUD_PROJECT = PROJECT;
const admin = require('firebase-admin'); if (admin.apps.length) throw Error('Fresh demo SDK required');
admin.initializeApp({ projectId: PROJECT }); assert.equal(admin.app().options.projectId, PROJECT);
const db = admin.firestore(), { Timestamp, FieldValue } = require('firebase-admin/firestore'), W = require('../lib/seller/sellerWallet');
const NOW = Date.UTC(2026, 9, 5, 3), REQUEST = 'wallet_money_request_01'; let seq = 0, passed = 0, failed = 0;
const get = async path => (await db.doc(path).get()).data();
async function scenario(label, fn) { try { await fn(); passed++; console.log(`PASS ${label}`); } catch (e) { failed++; console.log(`FAIL ${label}: ${e.message}`); } }
async function fixture(extra = {}, settings = {}) {
  await db.doc('settings/seller_wallet').set(settings);
  const seller = `wallet_money_${++seq}`, id = `${seller}_${REQUEST}`, payout = `${seller}_p1`;
  await db.doc(`sellers/${seller}`).set({ shopName: 'Demo fixture' });
  await db.doc(`seller_payout_details/${seller}`).set({ sellerId: seller, payoutMethod: 'upi', upiId: 'fixture@example.invalid' });
  await db.doc(`seller_payouts/${payout}`).set({ sellerId: seller, status: 'pending', netAmount: 200, createdAt: Timestamp.fromMillis(NOW - 86400000), ...extra });
  return { seller, id, ids: [payout] };
}
const state = async f => Promise.all([get(`seller_withdrawals/${f.id}`), get(`seller_wallets/${f.seller}`), ...f.ids.map(pid => get(`seller_payouts/${pid}`))]);
const request = (f, target = db) => W.requestWithdrawalCore(target, f.seller, REQUEST, NOW);
const summary = (f, target = db) => W.walletSummaryCore(target, f.seller, NOW);
const bad = e => e.code === 'failed-precondition' && e.details?.reason === 'bad_money_state';
async function pair(first, second, { future = false } = {}) {
  const f = await fixture({ netAmount: first, createdAt: Timestamp.fromMillis(NOW + (future ? 86400000 : -86400000)) });
  const pid = `${f.seller}_p2`; f.ids.push(pid);
  await db.doc(`seller_payouts/${pid}`).set({ sellerId: f.seller, status: 'pending', netAmount: second, createdAt: Timestamp.fromMillis(NOW + (future ? 86400000 : -86400000)) }); return f;
}
function trace({ rejectSettings = false, beforeAnchor } = {}) {
  const reads = { outsideSettings: 0, transactionSettings: 0, documents: [] }; let hookRan = false;
  const proxy = new Proxy(db, { get(target, key) {
    if (key === 'collection') return name => {
      const c = target.collection(name); if (name !== 'settings') return c;
      return new Proxy(c, { get(collection, k) {
        if (k === 'doc') return id => {
          const ref = collection.doc(id), realGet = ref.get.bind(ref);
          ref.get = async (...args) => { reads.outsideSettings++; if (rejectSettings) throw Error('Synthetic settings unavailable'); return realGet(...args); }; return ref;
        };
        const v = collection[k]; return typeof v === 'function' ? v.bind(collection) : v;
      } });
    };
    if (key === 'runTransaction') return cb => target.runTransaction(tx => cb(new Proxy(tx, { get(t, k) {
      if (k === 'get') return async (ref, ...args) => {
        if (typeof ref.path === 'string') {
          reads.documents.push(ref.path);
          if (!hookRan && ref.path.startsWith('seller_withdrawals/') && beforeAnchor) { hookRan = true; await beforeAnchor(); }
          if (ref.path === 'settings/seller_wallet') { reads.transactionSettings++; if (rejectSettings) throw Error('Synthetic settings unavailable'); }
        }
        return t.get(ref, ...args);
      };
      const v = t[k]; return typeof v === 'function' ? v.bind(t) : v;
    } })));
    const v = target[key]; return typeof v === 'function' ? v.bind(target) : v;
  } }); return { db: proxy, reads };
}
const corrupt = [
  ['missing net and alias', { netAmount: FieldValue.delete() }],
  ['explicit null net with plausible alias', { netAmount: null, amount: 200 }],
  ['digit string net with plausible alias', { netAmount: '200', amount: 200 }],
  ['boolean net', { netAmount: true }],
  ['object net', { netAmount: { value: 200 } }],
  ['NaN net', { netAmount: NaN }],
  ['infinite net', { netAmount: Infinity }],
  ['negative net', { netAmount: -1 }],
  ['negative subpaise net', { netAmount: -1e-12 }],
  ['conversion overflow net', { netAmount: 1e308 }],
  ['unsafe paise net', { netAmount: Number.MAX_SAFE_INTEGER }],
];
(async () => {
  for (const mode of ['summary', 'request']) {
    const call = mode === 'summary' ? summary : request;
    for (const [label, fields] of corrupt) await scenario(`${mode}: rejects ${label} without effects`, async () => {
      const f = await fixture(); await db.doc(`seller_payouts/${f.ids[0]}`).update(fields); const before = await state(f);
      await assert.rejects(call(f), bad); assert.deepEqual(await state(f), before);
    });
    for (const [label, fields] of corrupt.slice(0, 3)) await scenario(`${mode}: future ${label} cannot be hidden`, async () => {
      const f = await fixture({ createdAt: Timestamp.fromMillis(NOW + 86400000) }); await db.doc(`seller_payouts/${f.ids[0]}`).update(fields); const before = await state(f);
      await assert.rejects(call(f), bad); assert.deepEqual(await state(f), before);
    });
    await scenario(`${mode}: aggregate available amount cannot overflow`, async () => {
      const f = await pair(50000000000000, 50000000000000), before = await state(f); await assert.rejects(call(f), bad); assert.deepEqual(await state(f), before);
    });
    await scenario(`${mode}: safe integer sum must survive rupee roundtrip`, async () => {
      const f = await pair((Number.MAX_SAFE_INTEGER - 2) / 100, .01), before = await state(f);
      assert.equal(Math.round(((Number.MAX_SAFE_INTEGER - 1) / 100) * 100), Number.MAX_SAFE_INTEGER);
      await assert.rejects(call(f), bad); assert.deepEqual(await state(f), before);
    });
    for (const minWithdrawal of [1e308, Number.MAX_SAFE_INTEGER]) await scenario(`${mode}: unsafe accepted minimum is refused`, async () => {
      const f = await fixture({}, { minWithdrawal }), before = await state(f); await assert.rejects(call(f), bad); assert.deepEqual(await state(f), before);
    });
  }
  await scenario('summary: held amount cannot overflow', async () => {
    const f = await pair(50000000000000, 50000000000000, { future: true }), before = await state(f); await assert.rejects(summary(f), bad); assert.deepEqual(await state(f), before);
  });
  await scenario('valid current row preserves default minimum and exact withdrawal', async () => {
    const f = await fixture(), s = await summary(f); assert.equal(s.availablePaise, 20000); assert.equal(s.availableCount, 1); assert.equal(s.minWithdrawalPaise, 10000);
    assert.equal((await request(f)).amountPaise, 20000); const w = await get(`seller_withdrawals/${f.id}`); assert.equal(w.amount, 200); assert.deepEqual(w.payoutIds, f.ids);
  });
  await scenario('absent net accepts genuine numeric legacy alias', async () => {
    const f = await fixture(); await db.doc(`seller_payouts/${f.ids[0]}`).update({ netAmount: FieldValue.delete(), amount: 200 });
    assert.equal((await summary(f)).availablePaise, 20000); assert.equal((await request(f)).amountPaise, 20000);
  });
  for (const netAmount of [0, .001]) await scenario(`zero-rounded money ${netAmount} remains valid and unwithdrawable`, async () => {
    const f = await fixture({ netAmount }), before = await state(f), s = await summary(f); assert.equal(s.availablePaise, 0); assert.equal(s.heldPaise, 0); assert.equal(s.availableCount, 0);
    assert.deepEqual(await request(f), { kind: 'refused', reason: 'nothing_to_withdraw' }); assert.deepEqual(await state(f), before);
  });
  await scenario('fractional commission preserves existing per-row rounding', async () => {
    const f = await fixture({ netAmount: 96.525 }, { minWithdrawal: 0 }); assert.equal((await summary(f)).availablePaise, 9653); assert.equal((await request(f)).amountPaise, 9653);
  });
  await scenario('hold policy preserves genuine held money and cutoff', async () => {
    const f = await fixture({}, { holdDays: 3 }), before = await state(f), s = await summary(f); assert.equal(s.availablePaise, 0); assert.equal(s.heldPaise, 20000); assert.equal(s.holdDays, 3);
    assert.equal((await request(f)).reason, 'nothing_to_withdraw'); assert.deepEqual(await state(f), before);
  });
  await scenario('missing legacy timestamp remains held rather than selected', async () => {
    const f = await fixture(); await db.doc(`seller_payouts/${f.ids[0]}`).update({ createdAt: FieldValue.delete() }); const before = await state(f), s = await summary(f);
    assert.equal(s.heldPaise, 20000); assert.equal(s.availablePaise, 0); assert.equal((await request(f)).reason, 'nothing_to_withdraw'); assert.deepEqual(await state(f), before);
  });
  await scenario('already assigned pending money remains outside this available selection', async () => {
    const f = await fixture(); await db.doc(`seller_payouts/${f.seller}_assigned`).set({ sellerId: f.seller, status: 'pending', withdrawalId: 'other_fixture_request', netAmount: null });
    assert.equal((await summary(f)).availablePaise, 20000); assert.equal((await request(f)).amountPaise, 20000); assert.equal((await get(`seller_payouts/${f.seller}_assigned`)).netAmount, null);
  });
  await scenario('optional malformed settings retain established defaults', async () => {
    const f = await fixture({}, { minWithdrawal: 'invalid', holdDays: 'invalid' }), s = await summary(f); assert.equal(s.minWithdrawalPaise, 10000); assert.equal(s.holdDays, 0); assert.equal((await request(f)).amountPaise, 20000);
  });
  await scenario('new request settings are a transaction point read', async () => {
    const f = await fixture(), t = trace(); assert.equal((await request(f, t.db)).kind, 'requested'); assert.equal(t.reads.outsideSettings, 0); assert.equal(t.reads.transactionSettings, 1);
  });
  await scenario('configuration committed before first transaction read governs new request', async () => {
    const f = await fixture(), before = await state(f), t = trace({ beforeAnchor: () => db.doc('settings/seller_wallet').set({ minWithdrawal: 300 }) });
    assert.deepEqual(await request(f, t.db), { kind: 'refused', reason: 'below_minimum' }); assert.deepEqual(await state(f), before);
  });
  await scenario('existing request survives settings transport failure with only anchor', async () => {
    const f = await fixture(); await request(f); const before = await state(f), t = trace({ rejectSettings: true });
    assert.equal((await request(f, t.db)).kind, 'already'); assert.deepEqual(t.reads.documents, [`seller_withdrawals/${f.id}`]); assert.equal(t.reads.outsideSettings, 0); assert.equal(t.reads.transactionSettings, 0); assert.deepEqual(await state(f), before);
  });
  await scenario('existing result survives later unsafe minimum without effects', async () => {
    const f = await fixture(); await request(f); await db.doc('settings/seller_wallet').set({ minWithdrawal: 1e308 }); const before = await state(f), t = trace();
    assert.equal((await request(f, t.db)).kind, 'already'); assert.equal(t.reads.outsideSettings, 0); assert.deepEqual(await state(f), before);
  });
  await scenario('new request settings failure occurs before all effects', async () => {
    const f = await fixture(), before = await state(f), t = trace({ rejectSettings: true }); await assert.rejects(request(f, t.db), /Synthetic settings unavailable/); assert.deepEqual(await state(f), before);
  });
  await scenario('more than400 valid rows preserve selected cap and remaining balance', async () => {
    const f = await fixture({ netAmount: .01 }, { minWithdrawal: 0 }), batch = db.batch();
    for (let i = 2; i <= 401; i++) { const pid = `${f.seller}_p${String(i).padStart(4, '0')}`; f.ids.push(pid); batch.set(db.doc(`seller_payouts/${pid}`), { sellerId: f.seller, status: 'pending', netAmount: .01, createdAt: Timestamp.fromMillis(NOW - 86400000 + i) }); }
    await batch.commit(); assert.equal((await summary(f)).availablePaise, 401); const v = await request(f); assert.equal(v.count, 400); assert.equal(v.amountPaise, 400); assert.equal((await summary(f)).availablePaise, 1);
  });
  await scenario('corrupt row beyond selected cap is not hidden by first400', async () => {
    const f = await fixture({ netAmount: .01 }, { minWithdrawal: 0 }), batch = db.batch();
    for (let i = 2; i <= 401; i++) { const pid = `${f.seller}_p${String(i).padStart(4, '0')}`; f.ids.push(pid); batch.set(db.doc(`seller_payouts/${pid}`), { sellerId: f.seller, status: 'pending', netAmount: i === 401 ? null : .01, createdAt: Timestamp.fromMillis(NOW - 86400000 + i) }); }
    await batch.commit(); const before = await state(f); await assert.rejects(request(f), bad); assert.deepEqual(await state(f), before);
  });
  console.log(`RESULT ${passed} passed; ${failed} failed`); await db.terminate(); await admin.app().delete(); process.exitCode = failed ? 1 : 0;
})().catch(e => { console.error(e.message); process.exitCode = 1; });
