'use strict';
// Loopback demo-only, no Admin SDK/live CLI credentials or production reads.
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const firebase = require('firebase/compat/app');
require('firebase/compat/firestore');
const timestamp = () => firebase.firestore.FieldValue.serverTimestamp();
const OWNER = 'rating-owner', OTHER = 'rating-other';
const projectId = 'demo-agrimore-foundation';
if (!process.env.FIRESTORE_EMULATOR_HOST || process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8080') {
  throw new Error('Requires explicit loopback demo Firestore emulator');
}
const claims = {role:'user', admin:false, seller:false, sellerApproved:false,
  delivery_partner:false, deliveryApproved:false, employee:false, employeeApproved:false};
const orderData = (extra={}) => ({userId:OWNER, sellerId:'rating-seller', deliveryPartnerId:'rating-rider',
  orderStatus:'delivered', status:'delivered', total:100, subtotal:100, tax:0,
  deliveryCharge:0, discount:0, items:[], paymentStatus:'paid', paymentMethod:'cod', ...extra});
const reviewData = (extra={}) => ({userId:OWNER, rating:4, tags:['Fresh Items'], note:'Fixture note', createdAt:timestamp(), ...extra});
(async () => {
  const env = await initializeTestEnvironment({projectId,firestore:{host:'127.0.0.1',port:8080,
    rules:fs.readFileSync(path.resolve(__dirname,'../../firestore.rules'),'utf8')}});
  let passed=0, failed=0, sequence=0;
  const db = env.authenticatedContext(OWNER, claims).firestore();
  const foreign = env.authenticatedContext(OTHER,claims).firestore();
  const unsigned = env.unauthenticatedContext().firestore();
  const seller = env.authenticatedContext('rating-seller',{...claims,role:'seller',seller:true,sellerApproved:true}).firestore();
  const rider = env.authenticatedContext('rating-rider',{...claims,role:'delivery_partner',delivery_partner:true,deliveryApproved:true}).firestore();
  async function seed(extra={}) {
    const id=`foundation-rating-${++sequence}`;
    await env.withSecurityRulesDisabled(async ctx => {
      await ctx.firestore().doc(`orders/${id}`).set(orderData(extra));
    });return id;
  }
  function refs(client,id,reviewId=OWNER) {return [client.doc(`orders/${id}`),client.doc(`orders/${id}/reviews/${reviewId}`)];}
  function atomic(client,id,payload=reviewData(),summary={rating:4,isRated:true},reviewId=OWNER) {
    const [order,review]=refs(client,id,reviewId);const b=client.batch();b.set(review,payload);b.update(order,summary);return b.commit();
  }
  async function test(name,fn) {try {await fn();passed++;console.log(`PASS ${name}`);} catch(e) {failed++;console.error(`FAIL ${name}: ${e.code||e.message}`);}}
  try {
    await test('delivered owner atomic review and summary accepted',async()=>{
      const id=await seed();await assertSucceeds(atomic(db,id));
      const [o,r]=refs(db,id);if((await r.get()).data().rating!==4||(await o.get()).data().isRated!==true) throw Error('receipt mismatch');
    });
    for(const [name,client] of [['foreign',foreign],['unsigned',unsigned],['seller',seller],['rider',rider]]) {
      await test(`${name} cannot rate`,async()=>{const id=await seed();await assertFails(atomic(client,id));});
    }
    for(const status of ['pending','confirmed','out_for_delivery','cancelled','returned','refunded']) {
      await test(`cannot rate ${status} order`,async()=>{const id=await seed({orderStatus:status});await assertFails(atomic(db,id));});
    }
    for(const [name,extra] of [
      ['zero',{rating:0}],['six',{rating:6}],['fraction',{rating:2.5}],['text',{rating:'4'}],
      ['forged reviewer',{userId:OTHER}],['extra seller reply',{sellerReply:'forged'}],
      ['unknown tag',{tags:['Guaranteed']}],['tags text',{tags:'Fresh Items'}],
      ['too many tags',{tags:Array(7).fill('Fresh Items')}],['note too long',{note:'x'.repeat(2001)}],
      ['note wrong type',{note:123}],['stale timestamp',{createdAt:new Date(0)}],['missing note',{note:undefined}],
    ]) {
      await test(`review schema rejects ${name}`,async()=>{const id=await seed();const payload=reviewData(extra);if(payload.note===undefined) delete payload.note;await assertFails(atomic(db,id,payload));});
    }
    await test('review cannot be written alone',async()=>{const id=await seed();await assertFails(refs(db,id)[1].set(reviewData()));});
    await test('summary cannot be written alone',async()=>{const id=await seed();await assertFails(refs(db,id)[0].update({rating:4,isRated:true}));});
    await test('summary must match review',async()=>{const id=await seed();await assertFails(atomic(db,id,reviewData(),{rating:5,isRated:true}));});
    await test('rated flag required',async()=>{const id=await seed();await assertFails(atomic(db,id,reviewData(),{rating:4,isRated:false}));});
    await test('stable UID review key required',async()=>{const id=await seed();await assertFails(atomic(db,id,reviewData(),{rating:4,isRated:true},'auto-id'));});
    await test('review cannot accompany financial change and atomic failure leaves no review',async()=>{
      const id=await seed();await assertFails(atomic(db,id,reviewData(),{rating:4,isRated:true,total:1}));
      if((await refs(db,id)[1].get()).exists) throw Error('partial review persisted');
    });
    for (const flag of [null, 'true', 0]) {
      await test(`malformed isRated refuses review ${flag}`,async()=>{const id=await seed({isRated:flag});await assertFails(atomic(db,id));});
    }
    await test('existing legacy rated order is not silently rewritten',async()=>{const id=await seed({isRated:true,rating:3});await assertFails(atomic(db,id));});
    await test('customer cannot edit or remove confirmed review',async()=>{
      const id=await seed();await assertSucceeds(atomic(db,id));const r=refs(db,id)[1];await assertFails(r.update({rating:5}));await assertFails(r.delete());
    });
    await test('customer cannot overwrite summary after confirmed review',async()=>{
      const id=await seed();await assertSucceeds(atomic(db,id));await assertFails(refs(db,id)[0].update({rating:5}));
    });
    await test('private review read denied for foreign customer',async()=>{
      const id=await seed();await assertSucceeds(atomic(db,id));await assertFails(refs(foreign,id)[1].get());
    });
    for(const [name,client] of [['seller',seller],['rider',rider]]) {
      await test(`${name} cannot forge summary`,async()=>{const id=await seed();await assertFails(refs(client,id)[0].update({rating:5,isRated:true}));});
    }
    await test('unchanged-summary order cancellation still allowed',async()=>{
      const id=await seed({orderStatus:'pending',status:'pending'});await assertSucceeds(refs(db,id)[0].update({orderStatus:'cancelled'}));
    });
    await test('idempotent transaction replay returns confirmed rating without duplicate',async()=>{
      const id=await seed();const [o,r]=refs(db,id);
      async function submit() {return db.runTransaction(async tx=>{
        const order=await tx.get(o),review=await tx.get(r);
        if(review.exists) {const saved=review.data();if(order.data().rating!==saved.rating||order.data().isRated!==true) throw Error('inconsistent');return saved.rating;}
        tx.set(r,reviewData());tx.update(o,{rating:4,isRated:true});return 4;
      });}
      if(await submit()!==4||await submit()!==4) throw Error('wrong rating');
      if((await o.collection('reviews').get()).size!==1) throw Error('duplicate');
    });
    await test('minimum payload and maximum note accepted',async()=>{const id=await seed();await assertSucceeds(atomic(db,id,reviewData({rating:1,tags:[],note:'x'.repeat(2000)}),{rating:1,isRated:true}));});
    await test('two concurrent submit transactions produce one immutable review',async()=>{
      const id=await seed();const [o,r]=refs(db,id);
      async function submit(rating) {
        const transact = (receiptOnly=false) => db.runTransaction(async tx=>{
        const order=await tx.get(o),review=await tx.get(r);
        if(review.exists) {if(order.data().rating!==review.data().rating||order.data().isRated!==true) throw Error('inconsistent receipt');return review.data().rating;}
        if(receiptOnly || order.data().isRated===true) throw Error('no confirmed receipt');
        tx.set(r,reviewData({rating}));tx.update(o,{rating,isRated:true});return rating;
      });
        try {return await transact();} catch(e) {
          if(!['permission-denied','aborted'].includes(e.code)) throw e;
          return transact(true);
        }
      }
      const values=await Promise.all([submit(2),submit(5)]);
      if(values[0]!==values[1]||(await o.collection('reviews').get()).size!==1) throw Error('race duplicate');
    });
  } finally {await env.cleanup();}
  console.log(`ORDER RATING RULES ${passed} passed ${failed} failed`);if(failed) process.exitCode=1;
})().catch(e=>{console.error(e.message);process.exitCode=1;});
