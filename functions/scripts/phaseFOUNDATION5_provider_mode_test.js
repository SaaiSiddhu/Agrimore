// Actual payment entry handlers. Database transport is pinned to loopback
// while authority flags are changed to reproduce nonlocal configuration.
const assert = require('node:assert/strict'), crypto = require('node:crypto'), { EventEmitter } = require('node:events');
const fixtureHost = process.env.FIRESTORE_EMULATOR_HOST;
if (!/^(127\.0\.0\.1|localhost|\[::1\]):\d+$/.test(fixtureHost || '')) throw new Error('Loopback emulator required');
process.env.GCLOUD_PROJECT = 'demo-agrimore-foundation';
process.env.FUNCTIONS_EMULATOR = 'false';
process.env.RAZORPAY_KEY_SECRET = 'foundation5_fixture_not_a_provider_credential';
process.env.RAZORPAY_WEBHOOK_SECRET = 'foundation5_fixture_webhook_secret';
let current, calls=0, seq=0, passed=0, failed=0;
require('axios').get = async url => { calls++; assert.equal(url.split('/').pop(), current.paymentId); return {data:current.capture}; };
const providerPath=require.resolve('razorpay');
require.cache[providerPath]={id:providerPath,filename:providerPath,loaded:true,exports:class { constructor(){this.orders={
 create:async options=>{calls++;return {id:current.createdOrderId,amount:options.amount,currency:options.currency,status:'created',receipt:options.receipt};},
 fetchPayments:async id=>{calls++;assert.equal(id,current.orderId);return {items:[current.capture]};},
};}}};
const admin=require('firebase-admin');admin.initializeApp({projectId:process.env.GCLOUD_PROJECT});const db=admin.firestore();db.settings({host:fixtureHost,ssl:false});
const fft=require('firebase-functions-test')({projectId:process.env.GCLOUD_PROJECT});
const payment=require('../lib/customer/payment');
const create=fft.wrap(payment.createRazorpayOrder),verify=fft.wrap(payment.verifyRazorpayPayment);
const topup=fft.wrap(require('../lib/customer/wallet').verifyWalletTopup);
const associate=fft.wrap(require('../lib/employee/createAssociateOnboardingPayment').createAssociateOnboardingPayment);
const seller=fft.wrap(require('../lib/seller/aiConnection').createSellerAiActivationOrder);
const webhook=require('../lib/employee/razorpayOnboardingWebhook').razorpayOnboardingWebhook;
const reconcile=require('../lib/employee/reconcileStaleOnboardingPayments').reconcileStaleOnboardingPayments;
async function scenario(name,body){process.env.FIRESTORE_EMULATOR_HOST=fixtureHost;process.env.FUNCTIONS_EMULATOR='false';try{await body();passed++;console.log(`PASS ${name}`);}catch(e){failed++;console.log(`FAIL ${name}: ${e.message}`);}}
async function fixture(kind){
 const n=++seq,uid=`foundation5-owner-${n}`,paymentId=`pay_foundation5_${n}`,orderId=`order_foundation5_${n}`,createdOrderId=`order_foundation5_created_${n}`;
 const amount=kind==='associate-create'||kind==='webhook'||kind==='reconcile'?500:kind==='seller-create'?50:100;
 const auth={uid,token:{seller:true}},orderRef=db.collection('razorpay_orders').doc(orderId),paymentRef=db.collection('verified_payments').doc(paymentId);
 await db.collection('users').doc(uid).set({profileCompleted:true});await db.collection('employees').doc(uid).set({userId:uid,status:'pending'});
 await orderRef.set({orderId,userId:uid,employeeId:uid,purpose:'associate_onboarding',amount,amountPaise:amount*100,currency:'INR',createdAt:admin.firestore.Timestamp.fromMillis(Date.now()-(kind==='reconcile'?40*60000:0))});
 const capture={id:paymentId,order_id:orderId,amount:amount*100,currency:'INR',status:'captured',method:'upi'};
 current={uid,paymentId,orderId,createdOrderId,capture};
 const signature=crypto.createHmac('sha256',process.env.RAZORPAY_KEY_SECRET).update(`${orderId}|${paymentId}`).digest('hex');
 const call=async()=>{
  if(kind==='generic-create')return create({data:{amount},auth});
  if(kind==='generic-verify')return verify({data:{paymentId,orderId,signature},auth});
  if(kind==='wallet')return topup({data:{amount,paymentId,orderId,signature},auth});
  if(kind==='associate-create')return associate({data:{},auth});
  if(kind==='seller-create')return seller({data:{},auth});
  if(kind==='reconcile'){await reconcile.run();return;}
  const rawBody=Buffer.from(JSON.stringify({event:'payment.captured',payload:{payment:{entity:{...capture,notes:{purpose:'associate_onboarding',userId:uid}}}}}));
  const headers={'x-razorpay-signature':crypto.createHmac('sha256',process.env.RAZORPAY_WEBHOOK_SECRET).update(rawBody).digest('hex'),'x-razorpay-event-id':`evt_foundation5_${n}`};
  const req={method:'POST',rawBody,headers,get:name=>headers[name.toLowerCase()]};const res=new EventEmitter();
  res.status=code=>{res.statusCode=code;return res;};res.send=text=>{res.body=text;res.emit('finish');return res;};res.end=res.send;res.setHeader=()=>{};res.getHeader=()=>undefined;res.removeHeader=()=>{};
  await webhook(req,res);return res;
 };
 const state=async()=>({verified:(await paymentRef.get()).exists,created:(await db.collection('razorpay_orders').doc(createdOrderId).get()).exists,wallet:(await db.collection('wallets').doc(uid).get()).exists,active:(await db.collection('employees').doc(uid).get()).data().onboardingPaid===true});
 const record=async()=> (await db.collection(['generic-create','associate-create','seller-create'].includes(kind)?'razorpay_orders':'verified_payments').doc(['generic-create','associate-create','seller-create'].includes(kind)?createdOrderId:paymentId).get()).data();
 return {call,state,record,orderRef};
}
(async()=>{
 await db.collection('settings').doc('associate_onboarding').set({isEnabled:true,feeAmount:500,currency:'INR',version:1});
 const kinds=['generic-create','generic-verify','wallet','associate-create','seller-create','webhook','reconcile'];
 for(const kind of kinds){
  for(const mode of ['test','live']){
   await scenario(`${kind} ${mode==='test'?'denies':'allows'} ${mode} key outside loopback authority`,async()=>{
    const f=await fixture(kind),before=await f.state(),count=calls;delete process.env.FIRESTORE_EMULATOR_HOST;process.env.RAZORPAY_KEY_ID=`rzp_${mode}_foundation5_fixture`;
    try{if(mode==='test'){
     if(kind==='webhook')assert.equal((await f.call()).statusCode,500);else await assert.rejects(()=>f.call(),e=>e.code==='failed-precondition');
     assert.equal(calls,count);assert.deepEqual(await f.state(),before);
    }else{const result=await f.call();if(kind==='webhook')assert.equal(result.statusCode,200);assert.equal((await f.record()).providerMode,'live');assert.ok(calls>count);}}
    finally{process.env.FIRESTORE_EMULATOR_HOST=fixtureHost;await f.orderRef.update({createdAt:admin.firestore.Timestamp.now()});}
   });
  }
  await scenario(`${kind} loopback test key persists provider test provenance`,async()=>{
   const f=await fixture(kind);process.env.RAZORPAY_KEY_ID='rzp_test_foundation5_fixture';try{await f.call();assert.equal((await f.record()).providerMode,'test');}finally{await f.orderRef.update({createdAt:admin.firestore.Timestamp.now()});}
  });
 }
 await scenario('unknown key mode outside loopback fails before provider contact',async()=>{const f=await fixture('generic-create'),count=calls;delete process.env.FIRESTORE_EMULATOR_HOST;process.env.RAZORPAY_KEY_ID='unknown_foundation5_fixture';await assert.rejects(()=>f.call(),e=>e.code==='failed-precondition');assert.equal(calls,count);});
 for(const host of ['localhost.evil.example:8080','192.0.2.1:8080']){
  await scenario(`emulator flag cannot enable test key with nonloopback host ${host}`,async()=>{const f=await fixture('generic-create'),count=calls;process.env.FUNCTIONS_EMULATOR='true';process.env.FIRESTORE_EMULATOR_HOST=host;process.env.RAZORPAY_KEY_ID='rzp_test_foundation5_fixture';await assert.rejects(()=>f.call(),e=>e.code==='failed-precondition');assert.equal(calls,count);});
 }
 await scenario('reverification cannot relabel a stored test capture as live',async()=>{const f=await fixture('generic-verify');const {uid,paymentId,orderId}=current;await db.collection('verified_payments').doc(paymentId).set({paymentId,orderId,userId:uid,amount:100,currency:'INR',status:'captured',providerMode:'test',consumedByOrderId:'previous-order'});delete process.env.FIRESTORE_EMULATOR_HOST;process.env.RAZORPAY_KEY_ID='rzp_live_foundation5_fixture';await assert.rejects(()=>f.call(),e=>e.code==='failed-precondition');const stored=await f.record();assert.equal(stored.providerMode,'test');assert.equal(stored.consumedByOrderId,'previous-order');});
 await scenario('wallet retry cannot relabel a mismatched mode anchor',async()=>{const f=await fixture('wallet');process.env.RAZORPAY_KEY_ID='rzp_test_foundation5_fixture';await f.call();await db.collection('wallet_topups').doc(current.paymentId).update({providerMode:'live'});await assert.rejects(()=>f.call(),e=>e.code==='failed-precondition');assert.equal((await db.collection('wallets').doc(current.uid).get()).data().balance,100);});
 console.log(`FOUNDATION5 provider modes: ${passed} passed, ${failed} failed`);fft.cleanup();await admin.app().delete();process.exitCode=failed?1:0;
})().catch(e=>{console.error(e.message);process.exitCode=1;});
