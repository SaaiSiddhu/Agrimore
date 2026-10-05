// Actual scheduled handler, demo loopback storage and fixture-only provider.
const assert = require('node:assert/strict');
if (!/^(127\.0\.0\.1|localhost):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST || '')) throw new Error('Loopback emulator required');
process.env.GCLOUD_PROJECT = 'demo-foundation-reconciliation';
process.env.RAZORPAY_KEY_ID = 'rzp_test_foundation_paging_fixture';
process.env.RAZORPAY_KEY_SECRET = 'fixture_only_not_a_provider_credential';
const fetched = [];
const delayed = new Map();
const providerPath = require.resolve('razorpay');
require.cache[providerPath] = { id: providerPath, filename: providerPath, loaded: true,
  exports: class { constructor() { this.orders = { fetchPayments: async id => { fetched.push(id); return {items: delayed.get(id) || []}; } }; } } };
const admin = require('firebase-admin');
admin.initializeApp({projectId: process.env.GCLOUD_PROJECT});
const db = admin.firestore();
const handler = require('../lib/employee/reconcileStaleOnboardingPayments').reconcileStaleOnboardingPayments;
(async () => {
  const batch = db.batch();
  batch.set(db.doc('settings/associate_onboarding'), {isEnabled:true,feeAmount:500,currency:'INR',version:1});
  const createdAt = admin.firestore.Timestamp.fromMillis(Date.now() - 3600000);
  for (let i=0; i<55; i++) {
    const id = `order_paging_${String(i).padStart(3,'0')}`;
    batch.set(db.doc(`employees/owner_${i}`), {userId:`owner_${i}`, status:'pending'});
    batch.set(db.doc(`razorpay_orders/${id}`), {orderId:id, userId:`owner_${i}`, employeeId:`owner_${i}`, purpose:'associate_onboarding', amount:500, amountPaise:50000, currency:'INR', createdAt});
  }
  await batch.commit();
  await handler.run();
  assert.equal(fetched.length, 50, 'first run respects provider cap');
  fetched.length=0;
  await handler.run();
  assert.deepEqual(fetched, Array.from({length:5},(_,i)=>`order_paging_${String(i+50).padStart(3,'0')}`), 'second run must reach remaining orders despite the oldest 50 staying unpaid');
  delayed.set('order_paging_000', [{id:'pay_paging_delayed',order_id:'order_paging_000',status:'captured',amount:50000,currency:'INR',method:'upi'}]);
  fetched.length=0;
  await handler.run();
  assert.equal(fetched.length,50,'completed sweep restarts to revisit delayed payment outcomes');
  assert.equal(fetched[0],'order_paging_000','earlier unpaid rows remain eligible next sweep');
  assert.equal((await db.doc('employees/owner_0').get()).data().onboardingPaid,true,'a delayed capture activates on the next sweep');
  assert.equal((await db.doc('verified_payments/pay_paging_delayed').get()).data().consumedByOnboardingFor,'owner_0');
  console.log('PASS bounded paging, equal-timestamp continuation and delayed-capture activation');
  const {readStaleOnboardingPage,advanceStaleOnboardingCursor} = require('../lib/employee/staleOnboardingPage');
  const floor = admin.firestore.Timestamp.fromMillis(Date.now()-86400000);
  const cutoff = admin.firestore.Timestamp.fromMillis(Date.now()-1800000);
  const a=await readStaleOnboardingPage(db,'associate_onboarding',floor,cutoff,50);
  const b=await readStaleOnboardingPage(db,'associate_onboarding',floor,cutoff,50);
  assert.equal(a.version,b.version);
  assert.equal(await advanceStaleOnboardingCursor(db,a.version,a.snapshot.docs.at(-1)),true);
  assert.equal(await advanceStaleOnboardingCursor(db,b.version,b.snapshot.docs.at(-1)),false,'stale overlapping run cannot overwrite newer cursor');
  console.log('PASS cursor compare-and-set refuses stale concurrent advancement');
  await db.doc('payment_reconciliation_cursors/associate_onboarding').set({version:'corrupt'});
  fetched.length=0;
  await assert.rejects(handler.run(),/Invalid payment reconciliation cursor/);
  assert.equal(fetched.length,0,'invalid cursor refuses before provider lookup');
  console.log('PASS malformed cursor fails closed before provider work');
})().catch(error => {console.error(error); process.exitCode=1;});
