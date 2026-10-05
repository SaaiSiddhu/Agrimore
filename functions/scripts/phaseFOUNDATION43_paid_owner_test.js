// Compiled core + real Admin SDK; synthetic persisted demo states only.
const assert=require('node:assert/strict');
if(!/^(127\.0\.0\.1|localhost):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST||''))throw Error('Loopback emulator required');
process.env.GCLOUD_PROJECT='demo-paid-owner';const admin=require('firebase-admin');admin.initializeApp({projectId:process.env.GCLOUD_PROJECT});
const db=admin.firestore(),M=require('../lib/delivery/riderMoney'),NOW=Date.UTC(2026,9,5,3);let seq=0,passed=0,failed=0;
const ABSENT=Symbol('absent'),bank={accountHolderName:'Fixture Rider',bankAccountNumber:'123456789012',ifscCode:'HDFC0001234'};
async function scenario(label,fn){try{await fn();passed++;console.log('PASS '+label);}catch(e){failed++;console.log('FAIL '+label+': '+e.message);}}
async function fixture({payoutOwner='MATCH',account=true,accountOwner='MATCH',marker=null}={}){
 const id='paid_owner_'+(++seq),owner=payoutOwner==='MATCH'?id:payoutOwner,linked=String(owner),refs={payout:db.doc('rider_payouts/'+id),account:db.doc('rider_accounts/'+linked),partner:db.doc('delivery_partners/'+linked)};
 const a={bankChangePending:marker,cashHeldPaise:0,earningsUnsettledPaise:0};if(accountOwner!==ABSENT)a.riderId=accountOwner==='MATCH'?linked:accountOwner;
 const b=db.batch();b.set(refs.payout,{riderId:owner,status:'pending',amountPaise:100,amount:1});if(account)b.set(refs.account,a);b.set(refs.partner,{status:'approved',...bank});await b.commit();return{refs,linked};
}
async function snapshot(f){return Object.fromEntries(await Promise.all(Object.entries(f.refs).map(async([k,r])=>[k,(await r.get()).data()||null])));}
function trace(){const reads=[];const wrapped=new Proxy(db,{get(t,k){if(k==='runTransaction')return(cb,o)=>t.runTransaction(tx=>cb(new Proxy(tx,{get(x,key){if(key==='get')return(ref,...args)=>{reads.push(ref.path);return x.get(ref,...args);};const v=x[key];return typeof v==='function'?v.bind(x):v;}})),o);const v=t[k];return typeof v==='function'?v.bind(t):v;}});return{db:wrapped,reads};}
const pay=(f,target=db,ref='FIXTURE_UTR')=>M.markPayoutPaidCore(target,'fixture_admin',f.refs.payout.id,ref,'bank',NOW);
async function refuse(f,onlyPayout=false){const before=await snapshot(f),t=trace();assert.deepEqual(await pay(f,t.db),{kind:'refused',reason:'payout_review_state'});if(onlyPayout)assert.deepEqual(t.reads,[f.refs.payout.path]);assert.deepEqual(await snapshot(f),before);}
(async()=>{
 for(const payoutOwner of [null,17,true])await scenario('malformed stored owner '+String(payoutOwner)+' cannot be coerced into payout authority',async()=>refuse(await fixture({payoutOwner}),true));
 await scenario('missing account cannot authorize paid record',async()=>refuse(await fixture({account:false})));
 for(const accountOwner of ['different_rider',null,17])await scenario('explicit account owner '+String(accountOwner)+' must match',async()=>refuse(await fixture({accountOwner})));
 await scenario('valid linkage preserves exact money and linked records',async()=>{const f=await fixture(),before=await snapshot(f),v=await pay(f);assert.equal(v.kind,'paid');const after=await snapshot(f);assert.equal(after.payout.amountPaise,100);assert.equal(after.payout.riderId,f.linked);assert.equal(after.payout.paidTo.accountLast4,'9012');assert.deepEqual(after.account,before.account);assert.deepEqual(after.partner,before.partner);});
 await scenario('legacy absent optional account owner is accepted',async()=>assert.equal((await pay(await fixture({accountOwner:ABSENT}))).kind,'paid'));
 await scenario('coherent account retains pending-marker refusal',async()=>{const f=await fixture({marker:'pending_request'}),before=await snapshot(f);assert.deepEqual(await pay(f),{kind:'refused',reason:'bank_change_pending'});assert.deepEqual(await snapshot(f),before);});
 await scenario('completed replay survives later missing account without writes',async()=>{const f=await fixture(),v=await pay(f);assert.equal(v.kind,'paid');await f.refs.account.delete();const before=await snapshot(f),t=trace();assert.deepEqual(await pay(f,t.db),{kind:'already',paidTo:v.paidTo});assert.deepEqual(t.reads,[f.refs.payout.path]);assert.deepEqual(await snapshot(f),before);});
 await scenario('different reference cannot replace completed anchor',async()=>{const f=await fixture();await pay(f);const before=await snapshot(f);assert.deepEqual(await pay(f,db,'OTHER_UTR'),{kind:'refused',reason:'payout_not_pending'});assert.deepEqual(await snapshot(f),before);});
 console.log(`RESULT ${passed} passed; ${failed} failed`);await db.terminate();if(failed)process.exitCode=1;
})().catch(async e=>{console.error(e.stack);await db.terminate();process.exitCode=1;});
