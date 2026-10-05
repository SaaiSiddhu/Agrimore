// Real callable, isolated loopback demo storage; no external provider.
const assert=require('node:assert/strict');
if(!/^(127\.0\.0\.1|localhost):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST||''))throw Error('Loopback emulator required');
process.env.GCLOUD_PROJECT='demo-foundation-rider-deposit';
const admin=require('firebase-admin');admin.initializeApp({projectId:process.env.GCLOUD_PROJECT});const db=admin.firestore();
const fft=require('firebase-functions-test')({projectId:process.env.GCLOUD_PROJECT});
const M=require('../lib/delivery/riderMoney');const call=fft.wrap(M.recordRiderCashDeposit);
let seq=0,passed=0,failed=0;const auth={uid:'fixture_deposit_admin',token:{admin:true}};
async function scenario(label,fn){try{await fn();passed++;console.log(`PASS ${label}`);}catch(e){failed++;console.log(`FAIL ${label}: ${e.message}`);}}
async function rider(fields={cashHeld:100,earningsUnsettled:10}){const id=`fixture_deposit_rider_${++seq}`;await db.doc(`rider_accounts/${id}`).set(fields);return id;}
const invoke=(riderId,amount,requestId=`fixture_deposit_${seq}`)=>call({data:{riderId,amount,reference:'FIXTURE_RECEIPT',requestId},auth});
const account=async id=>(await db.doc(`rider_accounts/${id}`).get()).data();
const count=async id=>(await db.collection('rider_cash_ledger').where('riderId','==',id).get()).size;
(async()=>{
 await db.doc(`users/${auth.uid}`).set({role:'admin',isAdmin:true});
 for(const amount of ['10',true,1.001,0.001,NaN,Infinity,-1,1000001])await scenario(`bad amount ${String(amount)}`,async()=>{const id=await rider();await assert.rejects(invoke(id,amount),e=>e.details?.reason==='bad_amount');assert.equal((await account(id)).cashHeld,100);assert.equal(await count(id),0);});
 for(const [field,value] of [['cashHeld',NaN],['cashHeld',Infinity],['cashHeld','100'],['cashHeld',1.001],['cashHeld',-1],['cashHeldPaise',1.5],['cashHeldPaise',Number.MAX_SAFE_INTEGER+1],['cashHeldPaise',-1],['earningsUnsettled','10'],['earningsUnsettledPaise',1.5],['cashHeldPaise',null]])await scenario(`bad state ${field} ${String(value)}`,async()=>{const id=await rider({cashHeld:100,earningsUnsettled:10,[field]:value});await assert.rejects(invoke(id,1),e=>e.details?.reason==='bad_money_state');assert.equal(await count(id),0);});
 await scenario('paise authority preserves exact balances',async()=>{const id=await rider({cashHeld:'stale',cashHeldPaise:3,earningsUnsettled:999,earningsUnsettledPaise:7});await invoke(id,.01);const a=await account(id);assert.equal(a.cashHeldPaise,2);assert.equal(a.cashHeld,.02);assert.equal(a.earningsUnsettledPaise,7);});
 await scenario('six retries once and changed amount refused',async()=>{const id=await rider();await Promise.all(Array.from({length:6},()=>invoke(id,10)));assert.equal((await account(id)).cashHeldPaise,9000);assert.equal(await count(id),1);await assert.rejects(invoke(id,11),e=>e.details?.reason==='request_reused');});
 await scenario('two deposits cannot overdraw',async()=>{const id=await rider();const r=await Promise.allSettled([invoke(id,60,`fixture_race_a_${seq}`),invoke(id,60,`fixture_race_b_${seq}`)]);assert.equal(r.filter(x=>x.status==='fulfilled').length,1);assert.equal((await account(id)).cashHeldPaise,4000);assert.equal(await count(id),1);});
 await scenario('legacy float arithmetic remains valid',async()=>{const id=await rider({cashHeld:.1+.2,earningsUnsettled:0});await invoke(id,.01);assert.equal((await account(id)).cashHeldPaise,29);});
 await scenario('missing optional earnings defaults zero',async()=>{const id=await rider({cashHeld:2});await invoke(id,1);assert.equal((await account(id)).earningsUnsettledPaise,0);});
 await scenario('signed earnings debt is preserved',async()=>{const id=await rider({cashHeld:2,earningsUnsettled:-1.23});await invoke(id,1);assert.equal((await account(id)).earningsUnsettledPaise,-123);});
 await scenario('nonadmin denied',async()=>{const id=await rider();await assert.rejects(call({data:{riderId:id,amount:1,reference:'FIXTURE'},auth:{uid:'fixture_customer',token:{}}}),e=>e.code==='permission-denied');assert.equal(await count(id),0);});
 console.log(`RESULT ${passed} passed; ${failed} failed`);fft.cleanup();await db.terminate();if(failed)process.exitCode=1;
})().catch(e=>{console.error(e.message);process.exitCode=1;});
