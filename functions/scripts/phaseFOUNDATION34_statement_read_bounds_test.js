// Actual compiled monetary cores + real Admin SDK on loopback demo Firestore.
// Query transport refusal is synthetic. No live index/provider/rules/device proof.
const assert=require('node:assert/strict');
if(!/^(127\.0\.0\.1|localhost):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST||''))throw Error('Loopback emulator required');
const PROJECT='demo-foundation-statement-read-bounds';process.env.GCLOUD_PROJECT=PROJECT;
const admin=require('firebase-admin');if(admin.apps.length)throw Error('Fresh demo SDK application required');
admin.initializeApp({projectId:PROJECT});assert.equal(admin.app().options.projectId,PROJECT);
const db=admin.firestore(),{Timestamp}=require('firebase-admin/firestore');
const M=require('../lib/delivery/riderMoney'),{statementCutoff}=require('../lib/delivery/riderPay');
const NOW=Date.UTC(2026,9,5,1),{cutoffMs,weekKey}=statementCutoff(NOW);let seq=0,passed=0,failed=0;
const get=async p=>(await db.doc(p).get()).data();
async function scenario(label,fn){try{await fn();passed++;console.log(`PASS ${label}`);}catch(e){failed++;console.log(`FAIL ${label}: ${e.message}`);}}
function trace({rejectQuery=false}={},targetDb=db){
 const reads={documents:[],queries:[]};
 const traced=new Proxy(targetDb,{get(target,key){
  if(key==='runTransaction')return (callback,options)=>target.runTransaction(tx=>callback(new Proxy(tx,{get(t,k){
   if(k==='get')return async(ref,...options)=>{
    if(typeof ref.path==='string'){reads.documents.push(ref.path);return t.get(ref,...options);}
    if(ref._queryOptions?.collectionId==='rider_accounts')return t.get(ref,...options);
    const row={size:null};reads.queries.push(row);
    if(rejectQuery)throw Object.assign(Error('Synthetic unavailable query transport'),{code:'unavailable'});
    const snap=await t.get(ref,...options);row.size=snap.size;return snap;
   };
   const v=t[k];return typeof v==='function'?v.bind(t):v;
  }})),options);
  const v=target[key];return typeof v==='function'?v.bind(target):v;
 }});return {db:traced,reads};
}
async function seed(id,count,prefix='eligible',future=false){
 for(let start=0;start<count;start+=400){const batch=db.batch();for(let i=start;i<Math.min(start+400,count);i++)
  batch.set(db.doc(`rider_earnings/${id}_${prefix}_${String(i).padStart(4,'0')}`),{riderId:id,total:1,totalPaise:100,statementId:null,createdAt:Timestamp.fromMillis(cutoffMs+(future?86400000:-86400000)+i)});
  await batch.commit();}
}
async function fixture(count=1,{cash=0,pending=0}={}){
 const id=`statement_bound_${++seq}`;await db.doc(`rider_accounts/${id}`).set({riderId:id,cashHeldPaise:cash,cashHeld:cash/100,earningsUnsettledPaise:(count+pending)*100,earningsUnsettled:count+pending});
 await db.doc(`delivery_partners/${id}`).set({status:'approved',upiId:'fixture@example.invalid'});await seed(id,count);return id;
}
function onlyAnchor(t,id,part=1){assert.equal(t.reads.queries.length,0,'existing anchor must issue no earnings query');assert.deepEqual(t.reads.documents,[`rider_payouts/${M.statementId(id,weekKey,part)}`]);}
const pending=id=>db.collection('rider_earnings').where('riderId','==',id).where('statementId','==',null).get();
(async()=>{
 await scenario('first creation preserves exact cash netting and rider ownership',async()=>{
  const id=await fixture(2,{cash:50}),t=trace(),v=await M.buildStatementCore(t.db,id,NOW);assert.equal(v.kind,'created');assert.equal(v.amount,1.5);assert.equal(v.netted,.5);
  assert.equal(t.reads.queries.length,1);assert.equal(t.reads.queries[0].size,2);
  const a=await get(`rider_accounts/${id}`),p=await get(`rider_payouts/${v.id}`);assert.equal(a.cashHeldPaise,0);assert.equal(a.earningsUnsettledPaise,0);assert.equal(p.riderId,id);assert.equal(p.orderCount,2);assert.equal(p.amountPaise,150);
 });
 await scenario('completed statement returns with only its anchor and no effects',async()=>{
  const id=await fixture(),v=await M.buildStatementCore(db,id,NOW),a=await get(`rider_accounts/${id}`),p=await get(`rider_payouts/${v.id}`),t=trace();
  assert.deepEqual(await M.buildStatementCore(t.db,id,NOW+1000),{kind:'exists'});onlyAnchor(t,id);assert.deepEqual(await get(`rider_accounts/${id}`),a);assert.deepEqual(await get(`rider_payouts/${v.id}`),p);
 });
 await scenario('existing anchor does not depend on an available query',async()=>{
  const id=await fixture();await M.buildStatementCore(db,id,NOW);const t=trace({rejectQuery:true});assert.deepEqual(await M.buildStatementCore(t.db,id,NOW),{kind:'exists'});onlyAnchor(t,id);
 });
 await scenario('existing anchor never rereads a later dense backlog',async()=>{
  const id=await fixture();await M.buildStatementCore(db,id,NOW);await seed(id,601,'later',true);const t=trace();assert.equal((await M.buildStatementCore(t.db,id,NOW)).kind,'exists');onlyAnchor(t,id);assert.equal((await pending(id)).size,601);
 });
 await scenario('later corrupt account cannot turn existing anchor into economics',async()=>{
  const id=await fixture(),v=await M.buildStatementCore(db,id,NOW);await db.doc(`rider_accounts/${id}`).update({earningsUnsettledPaise:null});const a=await get(`rider_accounts/${id}`),p=await get(`rider_payouts/${v.id}`),t=trace();
  assert.equal((await M.buildStatementCore(t.db,id,NOW)).kind,'exists');onlyAnchor(t,id);assert.deepEqual(await get(`rider_accounts/${id}`),a);assert.deepEqual(await get(`rider_payouts/${v.id}`),p);
 });
 await scenario('new statement reads401 eligible lines and settles oldest400',async()=>{
  const id=await fixture(650,{cash:1000});await seed(id,200,'future',true);const t=trace(),v=await M.buildStatementCore(t.db,id,NOW);
  assert.equal(v.kind,'created');assert.equal(v.more,true);assert.equal(v.amount,390);assert.equal(t.reads.queries.length,1);assert.equal(t.reads.queries[0].size,401,'transaction query must be bounded');
  assert.equal((await get(`rider_payouts/${v.id}`)).orderCount,400);const rows=(await db.collection('rider_earnings').where('riderId','==',id).get()).docs;
  assert.deepEqual(rows.filter(d=>d.data().statementId===v.id).map(d=>d.id).sort(),Array.from({length:400},(_,i)=>`${id}_eligible_${String(i).padStart(4,'0')}`));assert.equal(rows.filter(d=>d.id.includes('_future_')&&d.data().statementId!==null).length,0);
 });
 await scenario('cutoff and stored type eligibility preserve legacy selection',async()=>{
  const id=await fixture(0,{pending:2});const values=[['one',Timestamp.fromMillis(cutoffMs-1)],['two',Timestamp.fromMillis(cutoffMs-100)],['cutoff',Timestamp.fromMillis(cutoffMs)],['future',Timestamp.fromMillis(cutoffMs+1)],['missing',undefined],['null',null],['number',cutoffMs-1],['string',new Date(cutoffMs-1).toISOString()],['boolean',false],['map',{seconds:Math.floor(cutoffMs/1000)-1}],['array',[cutoffMs-1]]];
  for(const [label,date]of values){const data={riderId:id,statementId:null,total:1,totalPaise:100};if(date!==undefined)data.createdAt=date;await db.doc(`rider_earnings/${id}_${label}`).set(data);}
  const original=(await pending(id)).docs.filter(d=>d.data().createdAt instanceof Timestamp&&d.data().createdAt.toMillis()<cutoffMs).sort((a,b)=>a.data().createdAt.toMillis()-b.data().createdAt.toMillis()).map(d=>d.id);
  const t=trace(),v=await M.buildStatementCore(t.db,id,NOW);assert.equal(v.kind,'created');assert.equal(v.amount,2);const actual=(await db.collection('rider_earnings').where('riderId','==',id).get()).docs.filter(d=>d.data().statementId===v.id).map(d=>d.id).sort();assert.deepEqual(actual,original.slice().sort());assert.equal(t.reads.queries[0].size,2,'future/invalid dates must not be fetched');
 });
 await scenario('equal timestamp ties remain deterministic at the400 boundary',async()=>{
  const id=await fixture(0,{pending:405}),at=Timestamp.fromMillis(cutoffMs-10),batch=db.batch();for(let i=404;i>=0;i--)batch.set(db.doc(`rider_earnings/${id}_tie_${String(i).padStart(4,'0')}`),{riderId:id,statementId:null,total:1,totalPaise:100,createdAt:at});await batch.commit();
  const t=trace(),v=await M.buildStatementCore(t.db,id,NOW);assert.equal(t.reads.queries[0].size,401);assert.equal(v.more,true);assert.equal((await get(`rider_earnings/${id}_tie_0399`)).statementId,v.id);assert.equal((await get(`rider_earnings/${id}_tie_0400`)).statementId,null);
 });
 await scenario('multipart retry skips existing parts and reads only new candidate',async()=>{
  const id=await fixture(405),v=await M.buildRiderStatementParts(db,id,NOW);assert.equal(v.filter(x=>x.kind==='created').length,2);const a=await get(`rider_accounts/${id}`),t=trace(),retry=await M.buildRiderStatementParts(t.db,id,NOW+1000);
  assert.deepEqual(retry.map(x=>x.kind),['exists','exists','nothing']);assert.equal(t.reads.queries.length,1,'only unanchored candidate should query');assert.deepEqual(await get(`rider_accounts/${id}`),a);assert.equal((await db.collection('rider_payouts').where('riderId','==',id).get()).size,2);
 });
 await scenario('all50 existing parts need no account or earnings scans',async()=>{
  const id=await fixture(0),batch=db.batch();for(let part=1;part<=M.MAX_STATEMENT_PARTS;part++)batch.set(db.doc(`rider_payouts/${M.statementId(id,weekKey,part)}`),{riderId:id,weekKey,part,status:'nothing_to_pay',amountPaise:0});await batch.commit();const t=trace(),v=await M.buildRiderStatementParts(t.db,id,NOW);assert.equal(v.length,50);assert.ok(v.every(x=>x.kind==='exists'));assert.equal(t.reads.queries.length,0);assert.equal(t.reads.documents.length,50);
 });
 await scenario('fresh unavailable query refuses before any economic effect',async()=>{
  const id=await fixture(),a=await get(`rider_accounts/${id}`),t=trace({rejectQuery:true});await assert.rejects(M.buildStatementCore(t.db,id,NOW),e=>e.code==='unavailable');assert.deepEqual(await get(`rider_accounts/${id}`),a);assert.equal((await db.collection('rider_payouts').where('riderId','==',id).get()).size,0);assert.equal((await pending(id)).size,1);
 });
 await scenario('concurrent builders settle and net each earning exactly once',async()=>{
  const id=await fixture(2,{cash:50}),v=await Promise.all([M.buildStatementCore(db,id,NOW),M.buildStatementCore(db,id,NOW)]);assert.equal(v.filter(x=>x.kind==='created').length,1);assert.equal(v.filter(x=>x.kind==='exists').length,1);assert.equal((await get(`rider_accounts/${id}`)).cashHeldPaise,0);assert.equal((await get(`rider_accounts/${id}`)).earningsUnsettledPaise,0);assert.equal((await db.collection('rider_cash_ledger').where('riderId','==',id).get()).size,1);
 });
 const noticeApp=admin.initializeApp({projectId:'demo-foundation-statement-notice-core'},'notice-core');
 const noticeDb=admin.firestore(noticeApp);
 await scenario('weekly scheduler records an owned statement-ready notice',async()=>{
  const id='notice_owner';await noticeDb.doc(`rider_accounts/${id}`).set({riderId:id,cashHeldPaise:0,earningsUnsettledPaise:100});await noticeDb.doc(`delivery_partners/${id}`).set({status:'approved',upiId:'fixture@example.invalid'});
  await noticeDb.doc('rider_earnings/notice_line').set({riderId:id,statementId:null,totalPaise:100,total:1,createdAt:Timestamp.fromMillis(cutoffMs-1000)});
  const v=await M.buildAllStatements(noticeDb,NOW);assert.equal(v.created,1);assert.equal(v.failed,0);
  const notices=await noticeDb.collection(`users/${id}/notifications`).get();assert.equal(notices.size,1);assert.equal(notices.docs[0].data().type,'statement_ready');assert.equal(notices.docs[0].data().title,'Your weekly statement is ready');assert.notEqual(notices.docs[0].data().title,'Money sent');assert.equal((await noticeDb.collection('users/other_owner/notifications').get()).size,0);
 });
 await scenario('weekly scheduler retry adds no notice or economic effect',async()=>{
  const id='notice_owner',before=(await noticeDb.collection(`users/${id}/notifications`).get()).docs[0].data(),account=(await noticeDb.doc(`rider_accounts/${id}`).get()).data(),t=trace({},noticeDb);
  const v=await M.buildAllStatements(t.db,NOW+1000);assert.equal(v.created,0);assert.equal(v.exists,1);assert.equal(v.nothing,1);assert.equal(v.failed,0);assert.equal(t.reads.queries.length,1);
  const notices=await noticeDb.collection(`users/${id}/notifications`).get();assert.equal(notices.size,1);assert.deepEqual(notices.docs[0].data(),before);assert.deepEqual((await noticeDb.doc(`rider_accounts/${id}`).get()).data(),account);
 });
 await noticeDb.terminate();await noticeApp.delete();
 console.log(`RESULT ${passed} passed; ${failed} failed`);await db.terminate();if(failed)process.exitCode=1;
})().catch(async e=>{console.error(e.stack);await db.terminate();process.exitCode=1;});
