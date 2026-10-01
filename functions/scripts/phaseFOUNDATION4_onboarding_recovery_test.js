// Actual HTTP/scheduled handlers, loopback database and fixture-only provider.
const assert = require('node:assert/strict'), crypto = require('node:crypto'), {EventEmitter} = require('node:events');
if (!/^(127\.0\.0\.1|localhost|\[::1\]):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST || '')) throw new Error('Loopback emulator required');
process.env.GCLOUD_PROJECT = 'demo-agrimore-foundation';
process.env.FUNCTIONS_EMULATOR = 'false';
process.env.RAZORPAY_KEY_ID = 'rzp_test_foundation4_fixture';
process.env.RAZORPAY_KEY_SECRET = 'foundation4_fixture_not_a_provider_credential';
process.env.RAZORPAY_WEBHOOK_SECRET = 'foundation4_fixture_webhook_secret';
const payments = new Map(), orderPayments = new Map(); let duringFetch = null, seq=0, passed=0, failed=0;
require('axios').get = async url => { const id=url.split('/').pop(); if(!payments.has(id)) throw new Error('Unexpected provider call'); if(duringFetch) await duringFetch(); return {data:payments.get(id)}; };
const providerPath=require.resolve('razorpay');
require.cache[providerPath]={id:providerPath,filename:providerPath,loaded:true,exports:class {constructor(){this.orders={fetchPayments:async id => ({items:orderPayments.get(id)||[]})};}}};
const admin=require('firebase-admin'); admin.initializeApp({projectId:process.env.GCLOUD_PROJECT}); const db=admin.firestore();
const webhook=require('../lib/employee/razorpayOnboardingWebhook').razorpayOnboardingWebhook;
const reconcile=require('../lib/employee/reconcileStaleOnboardingPayments').reconcileStaleOnboardingPayments;
async function scenario(name,body){duringFetch=null;try{await body();passed++;console.log(`PASS ${name}`);}catch(e){failed++;console.log(`FAIL ${name}: ${e.message}`);}}
async function fixture(){
 const n=++seq,uid=`foundation4-owner-${n}`,paymentId=`pay_foundation4_${n}`,orderId=`order_foundation4_${n}`;
 const employeeRef=db.collection('employees').doc(uid),orderRef=db.collection('razorpay_orders').doc(orderId),paymentRef=db.collection('verified_payments').doc(paymentId);
 await employeeRef.set({userId:uid,status:'pending'});
 await orderRef.set({orderId,userId:uid,employeeId:uid,purpose:'associate_onboarding',amount:500,amountPaise:50000,currency:'INR',createdAt:admin.firestore.Timestamp.now()});
 const captured={id:paymentId,order_id:orderId,status:'captured',amount:50000,currency:'INR',method:'upi'}; payments.set(paymentId,captured); orderPayments.set(orderId,[captured]);
 const verified={paymentId,orderId,userId:uid,amount:500,currency:'INR',status:'captured',signatureVerified:true};
 const payload={event:'payment.captured',payload:{payment:{entity:{id:paymentId,order_id:orderId,status:'captured',notes:{purpose:'associate_onboarding',userId:uid}}}}};
 const send=async (eventId=`evt_foundation4_${n}`,body=payload)=>{
  const rawBody=Buffer.from(JSON.stringify(body)),headers={'x-razorpay-signature':crypto.createHmac('sha256',process.env.RAZORPAY_WEBHOOK_SECRET).update(rawBody).digest('hex'),'x-razorpay-event-id':eventId};
  const req={method:'POST',rawBody,headers,get:name=>headers[name.toLowerCase()]};
  const res=new EventEmitter();res.status=code=>{res.statusCode=code;return res;};res.send=text=>{res.body=text;res.emit('finish');return res;};res.end=res.send;res.setHeader=()=>{};res.getHeader=()=>undefined;res.removeHeader=()=>{};
  await webhook(req,res);return res;
 };
 return {uid,paymentId,orderId,employeeRef,orderRef,paymentRef,captured,verified,payload,send};
}
async function notActivated(f){assert.notEqual((await f.employeeRef.get()).data().onboardingPaid,true);assert.equal((await db.collection('onboarding_events').where('uid','==',f.uid).get()).size,0);}
(async()=>{
 await db.collection('settings').doc('associate_onboarding').set({isEnabled:true,feeAmount:500,currency:'INR',version:1});
 await scenario('webhook without callback verifies and activates once',async()=>{const f=await fixture();assert.equal((await f.send()).statusCode,200);assert.equal((await f.employeeRef.get()).data().onboardingPaid,true);assert.equal((await f.employeeRef.get()).data().status,'pending');await f.send(`evt_redelivery_${seq}`);assert.equal((await db.collection('onboarding_events').where('uid','==',f.uid).get()).size,1);});
 await scenario('concurrent webhook deliveries activate once',async()=>{const f=await fixture();const results=await Promise.all([f.send(),f.send(),f.send()]);assert.ok(results.every(r=>r.statusCode===200));assert.equal((await db.collection('onboarding_events').where('uid','==',f.uid).get()).size,1);assert.equal((await f.paymentRef.get()).data().consumedByOnboardingFor,f.uid);});
 await scenario('trusted local simulation remains marked in persisted verification',async()=>{const f=await fixture();await f.orderRef.update({isTest:true});f.captured.isTestOrder=true;process.env.FUNCTIONS_EMULATOR='true';try{await f.send();assert.equal((await f.employeeRef.get()).data().onboardingPaid,true);assert.equal((await f.paymentRef.get()).data().isTest,true);}finally{process.env.FUNCTIONS_EMULATOR='false';}});
 for(const marker of ['consumedByOrderId','consumedByWalletTopup','consumedBySellerAiActivationFor','consumedByOnboardingFor']){
  await scenario(`webhook race preserves ${marker}`,async()=>{const f=await fixture();duringFetch=async()=>f.paymentRef.set({...f.verified,[marker]:'previous-consumer'});await f.send();assert.equal((await f.paymentRef.get()).data()[marker],'previous-consumer');await notActivated(f);});
 }
 for(const [field,value]of [['id','pay_other'],['order_id','order_other'],['amount',49999],['currency','USD'],['status','authorized']]){
  await scenario(`webhook rejects provider ${field} mismatch`,async()=>{const f=await fixture();f.captured[field]=value;await f.send();await notActivated(f);assert.equal((await f.paymentRef.get()).exists,false);});
 }
 for(const [field,value]of [['orderId','order_other'],['purpose','goods'],['amountPaise',49999],['currency','USD'],['employeeId','other-owner'],['userId','other-owner'],['isTest',true],['isTestOrder',true]]){
  await scenario(`webhook rejects stored order ${field} mismatch`,async()=>{const f=await fixture();await f.orderRef.update({[field]:value});await f.send();await notActivated(f);assert.equal((await f.paymentRef.get()).exists,false);});
 }
 await scenario('webhook rejects preexisting verification for a different order',async()=>{const f=await fixture();await f.paymentRef.set({...f.verified,orderId:'order_other'});await f.send();await notActivated(f);assert.equal((await f.paymentRef.get()).data().orderId,'order_other');});
 await scenario('legacy complete verification survives absent order document',async()=>{const f=await fixture();await f.orderRef.delete();await f.paymentRef.set(f.verified);await f.send();assert.equal((await f.employeeRef.get()).data().onboardingPaid,true);});
 await scenario('provider outage remains retryable',async()=>{const f=await fixture();payments.delete(f.paymentId);assert.equal((await f.send()).statusCode,500);assert.equal((await db.collection('webhook_events').doc(`evt_foundation4_${seq}`).get()).exists,false);payments.set(f.paymentId,f.captured);assert.equal((await f.send()).statusCode,200);assert.equal((await f.employeeRef.get()).data().onboardingPaid,true);});
 await scenario('malformed event ID returns a safe response',async()=>{const f=await fixture();const res=await f.send('bad/path');assert.equal(res.statusCode,400);await notActivated(f);});
 await scenario('malformed payment ID cannot address another document',async()=>{const f=await fixture();f.payload.payload.payment.entity.id='bad/path';const res=await f.send();assert.equal(res.statusCode,200);await notActivated(f);});
 async function stale(f){await f.orderRef.update({createdAt:admin.firestore.Timestamp.fromMillis(Date.now()-40*60000)});}
 async function runOnly(f){await stale(f);try{await reconcile.run();}finally{await f.orderRef.update({createdAt:admin.firestore.Timestamp.now()});}}
 await scenario('reconciler recovers when callback and webhook are both absent',async()=>{const f=await fixture();await runOnly(f);assert.equal((await f.employeeRef.get()).data().onboardingPaid,true);assert.equal((await f.paymentRef.get()).data().consumedByOnboardingFor,f.uid);await runOnly(f);assert.equal((await db.collection('onboarding_events').where('uid','==',f.uid).get()).size,1);assert.equal((await f.employeeRef.get()).data().status,'pending');});
 for(const [field,value]of [['order_id','order_other'],['currency','USD'],['amount',49999]]){
  await scenario(`reconciler refuses provider ${field} mismatch even with saved verification`,async()=>{const f=await fixture();await f.paymentRef.set(f.verified);f.captured[field]=value;await runOnly(f);await notActivated(f);});
 }
 await scenario('reconciler preserves a payment already spent on goods',async()=>{const f=await fixture();await f.paymentRef.set({...f.verified,consumedByOrderId:'existing-order'});await runOnly(f);await notActivated(f);assert.equal((await f.paymentRef.get()).data().consumedByOrderId,'existing-order');});
 console.log(`FOUNDATION4 onboarding recovery: ${passed} passed, ${failed} failed`);await admin.app().delete();process.exitCode=failed?1:0;
})().catch(e=>{console.error(e.message);process.exitCode=1;});
