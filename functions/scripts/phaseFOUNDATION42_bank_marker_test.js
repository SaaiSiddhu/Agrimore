// Compiled cores + real Admin SDK, synthetic persisted states on loopback demo only.
const assert=require('node:assert/strict');
if(!/^(127\.0\.0\.1|localhost):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST||''))throw Error('Loopback emulator required');
process.env.GCLOUD_PROJECT='demo-bank-marker';
const admin=require('firebase-admin');admin.initializeApp({projectId:process.env.GCLOUD_PROJECT});
const db=admin.firestore(),M=require('../lib/delivery/riderMoney'),{statementCutoff}=require('../lib/delivery/riderPay');
const NOW=Date.UTC(2026,9,5,2),{cutoffMs}=statementCutoff(NOW);let seq=0,passed=0,failed=0;
const ABSENT=Symbol('absent'),bank={accountHolderName:'Fixture Rider',bankAccountNumber:'123456789012',ifscCode:'HDFC0001234'};
async function scenario(label,fn){try{await fn();passed++;console.log('PASS '+label);}catch(e){failed++;console.log('FAIL '+label+': '+e.message);}}
async function fixture(marker){
 const rider='marker_rider_'+(++seq),refs={account:db.doc('rider_accounts/'+rider),partner:db.doc('delivery_partners/'+rider),payout:db.doc('rider_payouts/'+rider+'_pending'),earning:db.doc('rider_earnings/'+rider+'_earning')};
 const a={riderId:rider,cashHeldPaise:0,earningsUnsettledPaise:100};if(marker!==ABSENT)a.bankChangePending=marker;
 const b=db.batch();b.set(refs.account,a);b.set(refs.partner,{status:'approved',...bank});b.set(refs.payout,{riderId:rider,status:'pending',amountPaise:100,amount:1});b.set(refs.earning,{riderId:rider,statementId:null,totalPaise:100,total:1,createdAt:admin.firestore.Timestamp.fromMillis(cutoffMs-1000)});await b.commit();return{rider,refs};
}
async function snapshot(f){
 const docs=Object.fromEntries(await Promise.all(Object.entries(f.refs).map(async([k,r])=>[k,(await r.get()).data()])));
 const requests=await db.collection('rider_bank_change_requests').where('riderId','==',f.rider).get();
 const payouts=await db.collection('rider_payouts').where('riderId','==',f.rider).get();
 return {docs,requests:requests.docs.map(d=>[d.id,d.data()]),payouts:payouts.docs.map(d=>[d.id,d.data()])};
}
async function request(marker,blocked){const f=await fixture(marker),before=await snapshot(f),v=await M.requestBankChangeCore(db,f.rider,bank,NOW);if(blocked){assert.deepEqual(v,{kind:'refused',reason:'already_pending'});assert.deepEqual(await snapshot(f),before);}else{assert.equal(v.kind,'requested');assert.equal((await f.refs.account.get()).data().bankChangePending,v.id);assert.equal((await f.refs.payout.get()).data().status,'on_hold');}}
async function paid(marker,blocked){const f=await fixture(marker),before=await snapshot(f),v=await M.markPayoutPaidCore(db,'fixture_admin',f.refs.payout.id,'FIXTURE_UTR','bank',NOW);if(blocked){assert.deepEqual(v,{kind:'refused',reason:'bank_change_pending'});assert.deepEqual(await snapshot(f),before);}else{assert.equal(v.kind,'paid');assert.equal((await f.refs.payout.get()).data().amountPaise,100);}}
async function statement(marker,blocked){const f=await fixture(marker),v=await M.buildStatementCore(db,f.rider,NOW);assert.equal(v.kind,'created');assert.equal(v.status,blocked?'on_hold':'pending');assert.equal(v.amount,1);const p=(await db.doc('rider_payouts/'+v.id).get()).data();assert.equal(p.amountPaise,100);assert.equal(p.holdReason,blocked?'bank_change_pending':null);const a=(await f.refs.account.get()).data();assert.equal(a.earningsUnsettledPaise,0);assert.equal(a.cashHeldPaise,0);if(marker===ABSENT)assert.ok(!Object.hasOwn(a,'bankChangePending'));else assert.deepEqual(a.bankChangePending,marker);}
(async()=>{
 for(const [label,marker] of [['empty',''],['zero',0],['number',17],['false',false],['true',true],['array',[]],['object',{}],['array-id',['pending_id']],['valid-id','pending_id']]){
  await scenario(label+' blocks request without effects',()=>request(marker,true));
  await scenario(label+' blocks paid record without effects',()=>paid(marker,true));
  await scenario(label+' holds new positive statement with exact money',()=>statement(marker,true));
 }
 for(const [label,marker] of [['absent',ABSENT],['null',null]]){
  await scenario(label+' permits bank request',()=>request(marker,false));
  await scenario(label+' permits paid record',()=>paid(marker,false));
  await scenario(label+' permits pending statement',()=>statement(marker,false));
 }
 await scenario('completed paid anchor remains effect-free after marker becomes malformed',async()=>{const f=await fixture(null),v=await M.markPayoutPaidCore(db,'fixture_admin',f.refs.payout.id,'FIXTURE_UTR','bank',NOW);assert.equal(v.kind,'paid');await f.refs.account.update({bankChangePending:false});const before=await snapshot(f);assert.deepEqual(await M.markPayoutPaidCore(db,'fixture_admin',f.refs.payout.id,'FIXTURE_UTR','bank',NOW+1),{kind:'already',paidTo:v.paidTo});assert.deepEqual(await snapshot(f),before);});
 await scenario('completed statement anchor remains effect-free after marker becomes malformed',async()=>{const f=await fixture(null),v=await M.buildStatementCore(db,f.rider,NOW);assert.equal(v.kind,'created');await f.refs.account.update({bankChangePending:{invalid:true}});const before=await snapshot(f);assert.deepEqual(await M.buildStatementCore(db,f.rider,NOW+1),{kind:'exists'});assert.deepEqual(await snapshot(f),before);});
 console.log(`RESULT ${passed} passed; ${failed} failed`);await db.terminate();if(failed)process.exitCode=1;
})().catch(async e=>{console.error(e.stack);await db.terminate();process.exitCode=1;});
