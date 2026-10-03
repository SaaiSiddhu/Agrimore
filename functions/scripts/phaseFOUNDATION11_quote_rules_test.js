// F0/F7: prove server-only delivery quote/journal storage has no client bypass.
// Run only with a loopback Firestore emulator. No Admin SDK or provider calls.
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');

async function main() {
  const endpoint = process.env.FIRESTORE_EMULATOR_HOST || '';
  if (!/^(127\.0\.0\.1|localhost):\d+$/.test(endpoint)) throw new Error('Loopback emulator required');
  const [host, port] = endpoint.split(':');
  const env = await initializeTestEnvironment({
    projectId: 'demo-foundation-quote-rules',
    firestore: { host, port: Number(port), rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8') },
  });
  let passed = 0;
  try {
    const collections = ['delivery_fee_quotes', 'delivery_fee_quote_rate_limits', 'checkout_requests'];
    await env.withSecurityRulesDisabled(async (ctx) => {
      for (const name of collections) await ctx.firestore().doc(`${name}/fixture_owner`).set({ uid: 'fixture_owner', userId: 'fixture_owner' });
      await ctx.firestore().doc('product_credit_holds/fixture_hold').set({ customerId: 'fixture_owner', status: 'active' });
    });
    const owner = env.authenticatedContext('fixture_owner', { role: 'user', admin: false }).firestore();
    const admin = env.authenticatedContext('fixture_admin', { role: 'admin', admin: true }).firestore();
    const other = env.authenticatedContext('fixture_other', { role: 'user', admin: false }).firestore();
    const anonymous = env.unauthenticatedContext().firestore();
    for (const [role, db] of [['owner', owner], ['admin', admin], ['other', other], ['anonymous', anonymous]]) {
      for (const name of collections) {
        const ref = db.doc(`${name}/fixture_owner`);
        for (const [action, invoke] of [
          ['read', () => ref.get()],
          ['list', () => db.collection(name).where('uid', '==', 'fixture_owner').get()],
          ['create', () => db.doc(`${name}/fixture_new`).set({ uid: 'fixture_owner' })],
          ['update', () => ref.update({ expiresAt: new Date(Date.now() + 600000), consumedAt: null })],
          ['delete', () => ref.delete()],
        ]) {
          await assertFails(invoke());
          passed++;
          console.log(`PASSED ${role} ${name} ${action} denied`);
        }
      }
    }
    // Positive controls ensure the harness can exercise an allowed owner/admin
    // read; default denial is deliberately specific to these private namespaces.
    await assertSucceeds(owner.doc('product_credit_holds/fixture_hold').get()); passed++;
    await assertSucceeds(admin.doc('product_credit_holds/fixture_hold').get()); passed++;
    await assertFails(other.doc('product_credit_holds/fixture_hold').get()); passed++;
    await assertFails(owner.doc('product_credit_holds/fixture_hold').update({ status: 'active', expiresAt: new Date() })); passed++;
    console.log(`${passed}/${passed} checks passed`);
  } finally { await env.cleanup(); }
}
main().catch((error) => { console.error(error); process.exitCode = 1; });
