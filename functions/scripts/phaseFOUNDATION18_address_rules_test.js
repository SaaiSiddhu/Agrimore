// F2/F7: address ownership is immutable at the independent rules boundary.
// Synthetic identities and loopback demo emulator only. Never live probes.
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const firebase = require('firebase/compat/app');
require('firebase/compat/firestore');

async function main() {
  const endpoint = process.env.FIRESTORE_EMULATOR_HOST || '';
  if (!/^(127\.0\.0\.1|localhost):\d+$/.test(endpoint)) throw new Error('Loopback emulator required');
  const [host, port] = endpoint.split(':');
  const env = await initializeTestEnvironment({
    projectId: 'demo-foundation-address-rules',
    firestore: { host, port: Number(port), rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8') },
  });
  const claims = { role: 'user', admin: false };
  const owner = env.authenticatedContext('fixture_owner', claims).firestore();
  const other = env.authenticatedContext('fixture_other', claims).firestore();
  const admin = env.authenticatedContext('fixture_admin', { role: 'admin', admin: true }).firestore();
  const anonymous = env.unauthenticatedContext().firestore();
  const row = { id: 'fixture_address', userId: 'fixture_owner', name: 'Fixture', phoneNumber: '0000000000', addressLine1: 'Synthetic road', city: 'Fixture city', isDefault: false };
  let passed = 0, failed = 0;
  async function check(name, action) {
    await env.withSecurityRulesDisabled(ctx => ctx.firestore().doc('addresses/fixture_address').set(row));
    try { await action(); passed++; console.log(`PASSED ${name}`); }
    catch (_) { failed++; console.log(`FAILED ${name}`); }
  }
  const ref = db => db.doc('addresses/fixture_address');
  try {
    for (const [name, value] of [['other uid', 'fixture_other'], ['null', null], ['number', 17], ['object', { uid: 'fixture_owner' }], ['removed', firebase.firestore.FieldValue.delete()]]) {
      await check(`owner identity ${name} update refused`, () => assertFails(ref(owner).update({ userId: value })));
    }
    await check('full set ownership transfer refused', () => assertFails(ref(owner).set({ ...row, userId: 'fixture_other' })));
    await check('full set missing identity refused', () => { const { userId, ...rest } = row; return assertFails(ref(owner).set(rest)); });
    await check('merge transfer refused', () => assertFails(ref(owner).set({ userId: 'fixture_other' }, { merge: true })));
    await check('own create permitted', () => assertSucceeds(owner.doc('addresses/fixture_new').set({ ...row, id: 'fixture_new' })));
    await check('other-owner create refused', () => assertFails(owner.doc('addresses/fixture_wrong_owner').set({ ...row, userId: 'fixture_other' })));
    await check('missing-owner create refused', () => assertFails(owner.doc('addresses/fixture_missing_owner').set({ name: 'Fixture' })));
    await check('own ordinary edit permitted', () => assertSucceeds(ref(owner).update({ addressLine1: 'New synthetic road', phoneNumber: '0000000001' })));
    await check('own default edit permitted', () => assertSucceeds(ref(owner).update({ isDefault: true })));
    await check('same identity full model save permitted', () => assertSucceeds(ref(owner).set({ ...row, city: 'New fixture city' })));
    await check('same identity merge permitted', () => assertSucceeds(ref(owner).set({ userId: 'fixture_owner', isDefault: true }, { merge: true })));
    await check('own read permitted', () => assertSucceeds(ref(owner).get()));
    await check('admin read permitted', () => assertSucceeds(ref(admin).get()));
    await check('own filtered list permitted', () => assertSucceeds(owner.collection('addresses').where('userId', '==', 'fixture_owner').get()));
    await check('unfiltered owner list refused', () => assertFails(owner.collection('addresses').get()));
    await check('other read refused', () => assertFails(ref(other).get()));
    await check('other update refused', () => assertFails(ref(other).update({ city: 'Other fixture city' })));
    await check('other delete refused', () => assertFails(ref(other).delete()));
    await check('admin ownership edit refused', () => assertFails(ref(admin).update({ userId: 'fixture_admin' })));
    await check('admin ordinary edit refused', () => assertFails(ref(admin).update({ city: 'Admin fixture city' })));
    await check('admin delete refused', () => assertFails(ref(admin).delete()));
    await check('anonymous read refused', () => assertFails(ref(anonymous).get()));
    await check('anonymous create refused', () => assertFails(anonymous.doc('addresses/fixture_anon').set(row)));
    await check('anonymous update refused', () => assertFails(ref(anonymous).update({ city: 'Anonymous fixture city' })));
    await check('anonymous delete refused', () => assertFails(ref(anonymous).delete()));
    await check('own delete permitted', () => assertSucceeds(ref(owner).delete()));
    await check('nested own address path unchanged', () => assertSucceeds(owner.doc('users/fixture_owner/addresses/fixture_nested').set(row)));
    await check('nested other address path refused', () => assertFails(other.doc('users/fixture_owner/addresses/fixture_nested').get()));
    await check('failed mixed batch has no side effect', async () => {
      const batch = owner.batch(); batch.update(ref(owner), { isDefault: true });
      batch.set(owner.doc('addresses/fixture_bad_batch'), { ...row, userId: 'fixture_other' });
      await assertFails(batch.commit());
      await env.withSecurityRulesDisabled(async ctx => {
        const db = ctx.firestore();
        if ((await ref(db).get()).data().isDefault !== false || (await db.doc('addresses/fixture_bad_batch').get()).exists) throw new Error('Refused batch mutated data');
      });
    });
    console.log(`ADDRESS RULES ${passed} passed / ${failed} failed / ${passed + failed} scenarios`);
    if (failed) process.exitCode = 1;
  } finally { await env.cleanup(); }
}
main().catch(() => { console.error('Address rules fixture setup failed.'); process.exitCode = 1; });
