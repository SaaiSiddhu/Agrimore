// Real economic handlers; loopback demo storage only, no provider transport.
const assert = require('node:assert/strict');
if (!/^(127\.0\.0\.1|localhost):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST || '')) throw new Error('Loopback emulator required');
process.env.GCLOUD_PROJECT='demo-foundation-payout-money';
const admin=require('firebase-admin');admin.initializeApp({projectId:process.env.GCLOUD_PROJECT});const db=admin.firestore();
const test=require('firebase-functions-test')({projectId:process.env.GCLOUD_PROJECT});
const request=test.wrap(require('../lib/customer/requestEmployeePayout').requestEmployeePayout);
const review=require('../lib/customer/reviewEmployeePayout');
const reject=test.wrap(review.rejectEmployeePayout), paid=test.wrap(review.markEmployeePayoutPaid);
const adminAuth={uid:'fixture_payout_admin',token:{admin:true}};
let seq=0,passed=0,failed=0;
async function scenario(label,fn){try{await fn();passed++;console.log(`PASS ${label}`);}catch(e){failed++;console.log(`FAIL ${label}: ${e.message}`);}}
async function owner(balance=100){const uid=`fixture_payout_owner_${++seq}`;await db.doc(`employees/${uid}`).set({status:'approved',payoutMethod:'upi',upiId:'fixture@example.invalid'});await db.doc(`wallets/${uid}`).set({balance,coins:0});return uid;}
const requestAs=(uid,amount,requestId='fixture_request_0001')=>request({amount,requestId},{auth:{uid,token:{}}});
const rejectAs=payoutId=>reject({data:{payoutId,reason:'Synthetic review rejection'},auth:adminAuth});
const paidAs=payoutId=>paid({data:{payoutId,paymentReference:'FIXTURE_REFERENCE_0001'},auth:adminAuth});
const balance=async uid=>(await db.doc(`wallets/${uid}`).get()).data().balance;
const count=async(collection,uid)=>(await db.collection(collection).where(collection==='employee_payouts'?'employeeId':'userId','==',uid).get()).size;
(async()=>{
 await db.doc('users/fixture_payout_admin').set({role:'admin',isAdmin:true});
 for(const amount of ['10',true,0.001,1.001,Infinity,NaN,Number.MAX_SAFE_INTEGER]){
  await scenario(`malformed request ${String(amount)} refuses without effects`,async()=>{
   const uid=await owner();await assert.rejects(requestAs(uid,amount),e=>e.code==='invalid-argument');
   assert.equal(await balance(uid),100);assert.equal(await count('employee_payouts',uid),0);assert.equal(await count('wallet_transactions',uid),0);
  });
 }
 await scenario('one-paise request and recredit preserve exact balances',async()=>{
  const uid=await owner(0.03);const r=await requestAs(uid,0.01);assert.equal(await balance(uid),0.02);
  await rejectAs(r.payoutId);assert.equal(await balance(uid),0.03);await rejectAs(r.payoutId);assert.equal(await count('wallet_transactions',uid),2);
 });
 await scenario('six retries debit once',async()=>{
  const uid=await owner();const results=await Promise.all(Array.from({length:6},()=>requestAs(uid,10)));
  assert.equal(new Set(results.map(r=>r.payoutId)).size,1);assert.equal(await balance(uid),90);assert.equal(await count('wallet_transactions',uid),1);
 });
 await scenario('concurrent distinct requests cannot overspend',async()=>{
  const uid=await owner();const r=await Promise.allSettled([requestAs(uid,60,'fixture_distinct_0001'),requestAs(uid,60,'fixture_distinct_0002')]);
  assert.equal(r.filter(x=>x.status==='fulfilled').length,1);assert.equal(await balance(uid),40);assert.equal(await count('wallet_transactions',uid),1);
 });
 for(const badBalance of ['100',NaN,Infinity,1.001]){
  await scenario(`invalid wallet balance ${String(badBalance)} cannot debit`,async()=>{
   const uid=await owner(badBalance);await assert.rejects(requestAs(uid,1),e=>e.code==='failed-precondition');assert.equal(await count('employee_payouts',uid),0);assert.equal(await count('wallet_transactions',uid),0);
  });
 }
 for(const amount of ['20',-20,NaN,Infinity,0.001]){
  await scenario(`corrupt stored payout ${String(amount)} cannot recredit or settle`,async()=>{
   const uid=await owner();const payoutId=`corrupt_${uid}`;await db.doc(`employee_payouts/${payoutId}`).set({employeeId:uid,amount,status:'requested'});
   await assert.rejects(rejectAs(payoutId),e=>e.code==='failed-precondition');await assert.rejects(paidAs(payoutId),e=>e.code==='failed-precondition');
   assert.equal(await balance(uid),100);assert.equal(await count('wallet_transactions',uid),0);assert.equal((await db.doc(`employee_payouts/${payoutId}`).get()).data().status,'requested');
  });
 }
 await scenario('recredit permits valid signed wallet debt',async()=>{
  const uid=await owner(-30);const payoutId=`debt_${uid}`;await db.doc(`employee_payouts/${payoutId}`).set({employeeId:uid,amount:20,status:'requested'});
  await rejectAs(payoutId);assert.equal(await balance(uid),-10);
 });
 await scenario('request-ID namespace collision cannot replay another owner payout',async()=>{
  const a='fixture_collision_owner',b='fixture_collision_owner_extra';
  for(const uid of [a,b]){await db.doc(`employees/${uid}`).set({status:'approved'});await db.doc(`wallets/${uid}`).set({balance:100,coins:0});}
  await requestAs(a,10,'extra_fixture_0001');await assert.rejects(requestAs(b,10,'fixture_0001'),e=>e.code==='failed-precondition');
  assert.equal(await balance(b),100);assert.equal(await count('wallet_transactions',b),0);
 });
 for(const badBalance of ['100',NaN,Infinity,1.001]){
  await scenario(`corrupt rejection wallet ${String(badBalance)} remains untouched`,async()=>{
   const uid=await owner(badBalance),id=`bad_wallet_${uid}`;await db.doc(`employee_payouts/${id}`).set({employeeId:uid,amount:20,status:'requested'});
   await assert.rejects(rejectAs(id),e=>e.code==='failed-precondition');assert.equal(await count('wallet_transactions',uid),0);assert.equal((await db.doc(`employee_payouts/${id}`).get()).data().status,'requested');
  });
 }
 await scenario('recredit cannot overflow safe minor units',async()=>{
  const uid=await owner(Number.MAX_SAFE_INTEGER/100),id=`overflow_${uid}`;await db.doc(`employee_payouts/${id}`).set({employeeId:uid,amount:1,status:'requested'});
  await assert.rejects(rejectAs(id),e=>e.code==='failed-precondition');assert.equal(await count('wallet_transactions',uid),0);
 });
 await scenario('debit cannot lose a paise while encoding its after-balance',async()=>{
  const uid=await owner(90071992547409.72);await assert.rejects(requestAs(uid,0.01),e=>e.code==='failed-precondition');assert.equal(await balance(uid),90071992547409.72);assert.equal(await count('wallet_transactions',uid),0);assert.equal(await count('employee_payouts',uid),0);
 });
 await scenario('invalid stored payout owner cannot create a wallet',async()=>{
  const id='fixture_payout_missing_owner';await db.doc(`employee_payouts/${id}`).set({amount:20,status:'requested'});
  await assert.rejects(rejectAs(id),e=>e.code==='failed-precondition');await assert.rejects(paidAs(id),e=>e.code==='failed-precondition');assert.equal((await db.doc('wallets/undefined').get()).exists,false);
 });
 await scenario('floating arithmetic noise is normalized in ledger',async()=>{
  const uid=await owner(0.1+0.2);const r=await requestAs(uid,0.1);assert.equal(await balance(uid),0.2);
  await rejectAs(r.payoutId);assert.equal(await balance(uid),0.3);
 });
 await scenario('paid versus rejected race has one terminal outcome',async()=>{
  const uid=await owner();const r=await requestAs(uid,40);const verdicts=await Promise.allSettled([paidAs(r.payoutId),rejectAs(r.payoutId)]);
  assert.equal(verdicts.filter(x=>x.status==='fulfilled').length,1);const status=(await db.doc(`employee_payouts/${r.payoutId}`).get()).data().status;
  assert.ok(['paid','rejected'].includes(status));assert.equal(await balance(uid),status==='paid'?60:100);assert.equal(await count('wallet_transactions',uid),status==='paid'?1:2);
 });
 console.log(`${passed} passed, ${failed} failed`);test.cleanup();if(failed)process.exitCode=1;
})().catch(e=>{console.error(e);process.exitCode=1;});
