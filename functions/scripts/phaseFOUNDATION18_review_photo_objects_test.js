// Synthetic demo SDK objects only. No public handler or production credentials.
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.STORAGE_EMULATOR_HOST = 'http://127.0.0.1:9199';
const admin = require('firebase-admin'), assert = require('assert').strict;
const { randomUUID } = require('crypto');
const { createPhotoDraft, claimPhotoCleanup } = require('../lib/seller/reviewPhotoDraftCore');
const { verifyPhotoDraftObjects } = require('../lib/seller/reviewPhotoObjectVerifier');
const app = admin.initializeApp({ projectId: 'demo-agrimore-review-photos', storageBucket: 'demo-agrimore-review-photos.appspot.com' });
const db = app.firestore(), bucket = app.storage().bucket(), B = bucket.name;
let passed = 0, failed = 0, seq = 0;
async function test(name, fn) { try { await fn(); ++passed; console.log('PASS '+name); } catch(e) { ++failed; console.error('FAIL '+name+': '+e.message); } }
async function draft() {
 const id = 'objects'+(++seq); await createPhotoDraft(db, 'owner', id, 'p', 'owner', ['one'], 1000);
 return { id, path: `review_drafts/owner/${id}/one.jpg` };
}
function meta(path, patch = {}) { return { name: path, bucket: B, size: '32', generation: '1', metageneration: '1', contentType: 'image/jpeg', ...patch }; }
function fake(path, patch = {}, onRead = async()=>{}, secondPatch = {}) {
 let reads=0; const calls=[];
 return { name:B, calls, file(p, opts) { calls.push({p,opts}); return { async getMetadata() { await onRead(++reads); return [meta(path,{...patch,...(reads===2?secondPatch:{})})]; } }; } };
}
async function run() {
 await db.collection('products').doc('p').set({owner:'seller'});
 await test('actual SDK saved object metadata and pinned generation',async()=>{
  const d=await draft(); await bucket.file(d.path).save(Buffer.from([255,216,255,217]),{resumable:false,metadata:{contentType:'image/jpeg'}});
  const result=await verifyPhotoDraftObjects(db,bucket,B,'owner',d.id,()=>1001);
  assert.equal(result.length,1);assert.equal(result[0].path,d.path);assert.equal(result[0].size,4);assert.match(result[0].generation,/^[1-9]\d*$/);
 });
 await test('missing actual SDK object refuses',async()=>{const d=await draft();await assert.rejects(verifyPhotoDraftObjects(db,bucket,B,'owner',d.id,()=>1001));});
 await test('actual SDK wrong MIME refuses',async()=>{const d=await draft();await bucket.file(d.path).save(Buffer.from('x'),{resumable:false,metadata:{contentType:'text/plain'}});await assert.rejects(verifyPhotoDraftObjects(db,bucket,B,'owner',d.id,()=>1001));});
 await test('actual SDK draft download token metadata refuses',async()=>{const d=await draft();await bucket.file(d.path).save(Buffer.from('x'),{resumable:false,metadata:{contentType:'image/jpeg',metadata:{firebaseStorageDownloadTokens:randomUUID()}}});await assert.rejects(verifyPhotoDraftObjects(db,bucket,B,'owner',d.id,()=>1001));});
 await test('configured bucket mismatch refused before reads',async()=>{const d=await draft(),b=fake(d.path);await assert.rejects(verifyPhotoDraftObjects(db,b,'different-bucket','owner',d.id,()=>1001));assert.equal(b.calls.length,0);});
 await test('foreign actor refused before object access',async()=>{const d=await draft(),b=fake(d.path);await assert.rejects(verifyPhotoDraftObjects(db,b,B,'foreign',d.id,()=>1001));assert.equal(b.calls.length,0);});
 await test('expired lease refused before object access',async()=>{const d=await draft(),b=fake(d.path);await assert.rejects(verifyPhotoDraftObjects(db,b,B,'owner',d.id,()=>1801000));assert.equal(b.calls.length,0);});
 for(const [name,patch] of [
  ['wrong name',{name:'profiles/owner/x.jpg'}],['wrong metadata bucket',{bucket:'foreign'}],['wrong content type',{contentType:'image/png'}],
  ['zero size',{size:'0'}],['empty size',{size:''}],['negative size',{size:-1}],['fractional size',{size:1.2}],['size unit',{size:'32bytes'}],
  ['size limit',{size:10*1024*1024}],['unsafe size',{size:'9007199254740992'}],['generation zero',{generation:'0'}],
  ['generation numeric',{generation:1}],['generation malformed',{generation:'1e2'}],['missing metageneration',{metageneration:undefined}],
  ['empty download token',{metadata:{firebaseStorageDownloadTokens:String()}}],
 ]) await test(name+' refused',async()=>{const d=await draft();await assert.rejects(verifyPhotoDraftObjects(db,fake(d.path,patch),B,'owner',d.id,()=>1001));});
 await test('accepted metadata pins generation on second SDK read',async()=>{const d=await draft(),b=fake(d.path);assert.equal((await verifyPhotoDraftObjects(db,b,B,'owner',d.id,()=>1001))[0].generation,'1');assert.deepEqual(b.calls,[{p:d.path,opts:undefined},{p:d.path,opts:{generation:'1'}}]);});
 await test('metageneration drift refuses',async()=>{const d=await draft();await assert.rejects(verifyPhotoDraftObjects(db,fake(d.path,{},async()=>{},{metageneration:'2'}),B,'owner',d.id,()=>1001));});
 await test('generation drift refuses',async()=>{const d=await draft();await assert.rejects(verifyPhotoDraftObjects(db,fake(d.path,{},async()=>{},{generation:'2'}),B,'owner',d.id,()=>1001));});
 await test('token issued during verification refuses',async()=>{const d=await draft();await assert.rejects(verifyPhotoDraftObjects(db,fake(d.path,{},async()=>{},{metadata:{firebaseStorageDownloadTokens:randomUUID()}}),B,'owner',d.id,()=>1001));});
 await test('lease expires during SDK reads refuses',async()=>{const d=await draft();let now=1001;await assert.rejects(verifyPhotoDraftObjects(db,fake(d.path,{},async()=>{now=1801000;}),B,'owner',d.id,()=>now));});
 await test('cleanup claimed during reads refuses',async()=>{const d=await draft();await assert.rejects(verifyPhotoDraftObjects(db,fake(d.path,{},async n=>{if(n===1)await claimPhotoCleanup(db,'owner',d.id,true,1001);}),B,'owner',d.id,()=>1001));});
 await test('all asset paths required, no partial receipt',async()=>{const id='multi'+(++seq);await createPhotoDraft(db,'owner',id,'p','owner',['one','two'],1000);const p=`review_drafts/owner/${id}/one.jpg`;await assert.rejects(verifyPhotoDraftObjects(db,fake(p),B,'owner',id,()=>1001));});
 console.log(`${passed} passed, ${failed} failed`); await app.delete();if(failed)process.exitCode=1;
}
run().catch(e=>{console.error(e.message);process.exitCode=1;});
