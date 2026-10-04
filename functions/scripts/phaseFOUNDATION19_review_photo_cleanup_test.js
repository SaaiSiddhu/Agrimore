// Actual synthetic demo SDK deletions and SDK-boundary failure controls only.
process.env.FIRESTORE_EMULATOR_HOST='127.0.0.1:8080';
process.env.STORAGE_EMULATOR_HOST='http://127.0.0.1:9199';
const admin=require('firebase-admin'),assert=require('node:assert/strict');
const {createPhotoDraft,readyPhotoDraft,publishPhotoDraft}=require('../lib/seller/reviewPhotoDraftCore');
const {cleanupPhotoDraftObjects:cleanup}=require('../lib/seller/reviewPhotoCleanup');
const app=admin.initializeApp({projectId:'demo-agrimore-review-photos',storageBucket:'demo-agrimore-review-photos.appspot.com'}),db=app.firestore(),bucket=app.storage().bucket(),B=bucket.name;
const NOW=1000,EXPIRES=1801000, content={rating:4,title:'T',comment:'C',userName:'Owner',userAvatar:''};
let seq=0,passed=0,failed=0;
async function test(name,fn){try{await fn();++passed;console.log('PASS '+name);}catch(e){++failed;console.error('FAIL '+name+': '+e.message);}}
async function draft(assets=['one']){const id='clean'+(++seq);return {id,paths:await createPhotoDraft(db,'owner',id,'p','owner',assets,NOW)};}
async function save(path,bytes=Buffer.from('synthetic-jpeg-metadata-only')){await bucket.file(path).save(bytes,{resumable:false,metadata:{contentType:'image/jpeg'}});}
function fake(patches={},errors={},onDelete=async()=>{}){
 const calls=[];return {name:B,calls,file(path,opts){calls.push({path,opts});return {
  async getMetadata(){if(errors[path]?.lookup)throw errors[path].lookup;return [{name:path,bucket:B,generation:'1',...(patches[path]||{})}];},
  async delete(){await onDelete(path,opts);if(errors[path]?.delete)throw errors[path].delete;}
 };}};
}
async function run(){
 await db.doc('products/p').set({name:'Product'});
 await test('actual SDK deletion only after durable cleanup claim',async()=>{
  const d=await draft();await save(d.paths[0]);const result=await cleanup(db,bucket,B,'owner',d.id,true,()=>NOW);
  assert.deepEqual(result.deletedPaths,d.paths);assert.equal(result.recoveryRequired,true);assert.equal((await bucket.file(d.paths[0]).exists())[0],false);assert.equal((await db.doc('review_photo_drafts/'+d.id).get()).data().state,'cleanup');
 });
 await test('actual SDK retry observes absent and retains recovery',async()=>{
  const d=await draft();await save(d.paths[0]);await cleanup(db,bucket,B,'owner',d.id,true,()=>NOW);const result=await cleanup(db,bucket,B,'owner',d.id,false,()=>EXPIRES);
  assert.deepEqual(result.observedAbsentPaths,d.paths);assert.equal(result.leaseExpired,true);assert.equal(result.recoveryRequired,true);
 });
 await test('linked actual SDK photo preserved without object lookup',async()=>{
  const d=await draft();await save(d.paths[0]);await readyPhotoDraft(db,'owner',d.id,[{path:d.paths[0],generation:'1',url:'https://fixture.invalid/linked.jpg'}],NOW);await publishPhotoDraft(db,'owner',d.id,content,NOW);
  const b=fake(),result=await cleanup(db,b,B,'owner',d.id,true,()=>EXPIRES);assert.equal(result.claimed,false);assert.equal(b.calls.length,0);assert.equal((await bucket.file(d.paths[0]).exists())[0],true);
 });
 await test('unrecorded actual SDK object preserved',async()=>{
  const d=await draft(),other='profiles/owner/cleanup-control.jpg';await save(d.paths[0]);await save(other);await cleanup(db,bucket,B,'owner',d.id,true,()=>NOW);assert.equal((await bucket.file(other).exists())[0],true);
 });
 await test('active lease needs abandon before any object lookup',async()=>{const d=await draft(),b=fake();await assert.rejects(cleanup(db,b,B,'owner',d.id,false,()=>NOW));assert.equal(b.calls.length,0);});
 await test('foreign actor refuses without cleanup transition or object access',async()=>{const d=await draft(),b=fake();await assert.rejects(cleanup(db,b,B,'foreign',d.id,true,()=>NOW));assert.equal(b.calls.length,0);assert.equal((await db.doc('review_photo_drafts/'+d.id).get()).data().state,'open');});
 await test('wrong configured bucket refuses before claim',async()=>{const d=await draft(),b=fake();await assert.rejects(cleanup(db,b,'foreign-bucket','owner',d.id,true,()=>NOW));assert.equal(b.calls.length,0);assert.equal((await db.doc('review_photo_drafts/'+d.id).get()).data().state,'open');});
 await test('corrupted foreign path refuses before access',async()=>{const d=await draft(),b=fake();await db.doc('review_photo_drafts/'+d.id).update({paths:['profiles/foreign/x.jpg']});await assert.rejects(cleanup(db,b,B,'owner',d.id,true,()=>NOW));assert.equal(b.calls.length,0);});
 await test('exact generation and deletion precondition sent to SDK',async()=>{
  const d=await draft(),b=fake();const result=await cleanup(db,b,B,'owner',d.id,true,()=>NOW);assert.deepEqual(result.deletedPaths,d.paths);
  assert.deepEqual(b.calls,[{path:d.paths[0],opts:undefined},{path:d.paths[0],opts:{generation:'1',preconditionOpts:{ifGenerationMatch:'1'}}}]);
 });
 for(const [name,patch] of [['wrong object name',{name:'elsewhere.jpg'}],['wrong metadata bucket',{bucket:'foreign'}],['zero generation',{generation:'0'}],['numeric generation',{generation:1}],['missing generation',{generation:undefined}]])
  await test(name+' remains retryable with no deletion',async()=>{const d=await draft(),b=fake({[d.paths[0]]:patch});const result=await cleanup(db,b,B,'owner',d.id,true,()=>NOW);assert.deepEqual(result.retryPaths,d.paths);assert.equal(b.calls.length,1);});
 await test('lookup404 is observation, active lease still requires recovery',async()=>{const d=await draft(),b=fake({}, {[d.paths[0]]:{lookup:{code:404}}});const r=await cleanup(db,b,B,'owner',d.id,true,()=>NOW);assert.deepEqual(r.observedAbsentPaths,d.paths);assert.equal(r.leaseExpired,false);assert.equal(r.recoveryRequired,true);});
 await test('lookup403 never treated as absence',async()=>{const d=await draft(),b=fake({}, {[d.paths[0]]:{lookup:{code:403}}});const r=await cleanup(db,b,B,'owner',d.id,true,()=>EXPIRES);assert.deepEqual(r.retryPaths,d.paths);assert.deepEqual(r.observedAbsentPaths,[]);});
 await test('string404 not accepted as absence',async()=>{const d=await draft(),b=fake({}, {[d.paths[0]]:{lookup:{code:'404'}}});assert.deepEqual((await cleanup(db,b,B,'owner',d.id,true,()=>NOW)).retryPaths,d.paths);});
 for(const code of [404,412,503]) await test('delete'+code+' uncertain version retries',async()=>{const d=await draft(),b=fake({}, {[d.paths[0]]:{delete:{code}}});const r=await cleanup(db,b,B,'owner',d.id,true,()=>NOW);assert.deepEqual(r.retryPaths,d.paths);assert.deepEqual(r.observedAbsentPaths,[]);assert.deepEqual(r.deletedPaths,[]);});
 await test('partial deletion records progress and all remaining retries',async()=>{const d=await draft(['one','two','three']),b=fake({}, {[d.paths[1]]:{delete:{code:503}}});const r=await cleanup(db,b,B,'owner',d.id,true,()=>NOW);assert.deepEqual(r.deletedPaths,[d.paths[0],d.paths[2]]);assert.deepEqual(r.retryPaths,[d.paths[1]]);assert.equal(r.recoveryRequired,true);});
 await test('late upload after an absent observation remains recoverable',async()=>{const d=await draft();const r=await cleanup(db,bucket,B,'owner',d.id,true,()=>NOW);assert.equal(r.recoveryRequired,true);await save(d.paths[0]);const r2=await cleanup(db,bucket,B,'owner',d.id,false,()=>EXPIRES);assert.deepEqual(r2.deletedPaths,d.paths);assert.equal(r2.recoveryRequired,true);});
 await test('cleanup blocks late publication after object deletion',async()=>{const d=await draft();await save(d.paths[0]);await readyPhotoDraft(db,'owner',d.id,[{path:d.paths[0],generation:'1',url:'https://fixture.invalid/unlinked.jpg'}],NOW);await cleanup(db,bucket,B,'owner',d.id,true,()=>NOW);await assert.rejects(publishPhotoDraft(db,'owner',d.id,content,NOW));});
 await test('clock rechecked after object deletion',async()=>{const d=await draft();let now=NOW;const b=fake({}, {},async()=>{now=EXPIRES;});assert.equal((await cleanup(db,b,B,'owner',d.id,true,()=>now)).leaseExpired,true);});
 await test('actual SDK replacement before pinned recheck is refused',async()=>{
  const d=await draft();await save(d.paths[0]);let replaced=false;
  const racing={name:B,file(path,opts){const f=bucket.file(path,opts);if(opts)return f;return {async getMetadata(){const [m]=await f.getMetadata();const snapshot={...m};if(!replaced){replaced=true;await save(path,Buffer.from('replacement-object'));}return [snapshot];}};}};
  const r=await cleanup(db,racing,B,'owner',d.id,true,()=>NOW);assert.deepEqual(r.retryPaths,d.paths);const [bytes]=await bucket.file(d.paths[0]).download();assert.equal(bytes.toString(),'replacement-object');
 });

 await test('actual SDK delete request includes generation precondition',async()=>{
  const d=await draft();await save(d.paths[0]);let observed=false;
  const inspected={name:B,file(path,opts){const f=bucket.file(path,opts),original=f.request_.bind(f);f.request_=(req,callback)=>{if(req.method==='DELETE'){observed=true;assert.equal(req.qs.ifGenerationMatch,opts.generation);assert.equal(String(req.qs.generation),opts.generation);}return original(req,callback);};return f;}};
  assert.deepEqual((await cleanup(db,inspected,B,'owner',d.id,true,()=>NOW)).deletedPaths,d.paths);assert.equal(observed,true);
 });
 await test('precondition double refuses a replacement after final read',async()=>{
  const d=await draft();let replacementPresent=true;
  const b=fake({}, {},async(path,opts)=>{if(opts?.preconditionOpts?.ifGenerationMatch==='1')throw {code:412};replacementPresent=false;});
  const r=await cleanup(db,b,B,'owner',d.id,true,()=>NOW);assert.deepEqual(r.retryPaths,d.paths);assert.equal(replacementPresent,true);
 });
 console.log(`SUMMARY ${passed} passed ${failed} failed`);await app.delete();if(failed)process.exitCode=1;
}
run().catch(e=>{console.error(e.message);process.exitCode=1;});
