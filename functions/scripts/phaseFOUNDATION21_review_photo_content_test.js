// Internal trusted core against synthetic Admin SDK demo transactions; no real provider calls.
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
const admin = require('firebase-admin');
admin.initializeApp({projectId:'demo-agrimore-photo-content'});
const assert = require('node:assert/strict');
const {createPhotoDraft:create,readyPhotoDraft:ready,publishPhotoDraft:publish,
 freezePhotoContent:freeze,claimPhotoCleanup:cleanup} = require('../lib/seller/reviewPhotoDraftCore');
const db=admin.firestore(), at=100000, expiry=at+30*60*1000;
const original={rating:4,title:'Title',comment:'Comment',userName:'Original name',userAvatar:'https://fixture.invalid/original'};
const changed={...original,userName:'Changed name',userAvatar:'https://fixture.invalid/changed'};
const ref=id=>db.collection('review_photo_drafts').doc(id);
const row=id=>db.doc('products/p/reviews/'+id);
async function draft(id){await create(db,id,id,'p',id,['photo'],at);}
async function staged(id){await draft(id);await ready(db,id,id,[{path:`review_drafts/${id}/${id}/photo.jpg`,url:'https://fixture.invalid/'+id,generation:'1'}],at);}
let passed=0,failed=0;
async function check(name,fn){try{await fn();passed++;console.log('PASS '+name);}catch(e){failed++;console.log('FAIL '+name+': '+e.message);}}
async function denied(action,code){await assert.rejects(action,e=>e.code===code);}
async function main(){
await db.doc('products/p').set({name:'Synthetic product'});
await draft('snapshot');
await check('first submission freezes full content without publication',async()=>{assert.deepEqual(await freeze(db,'snapshot','snapshot',original,at),original);assert.equal((await row('snapshot').get()).exists,false);assert.equal((await ref('snapshot').get()).data().state,'open');});
await check('profile changes retain original profile for same intent',async()=>assert.deepEqual(await freeze(db,'snapshot','snapshot',changed,at),original));
await check('rating change rejected',()=>denied(freeze(db,'snapshot','snapshot',{...original,rating:1},at),'already-exists'));
await check('title change rejected',()=>denied(freeze(db,'snapshot','snapshot',{...original,title:'Changed'},at),'already-exists'));
await check('comment change rejected',()=>denied(freeze(db,'snapshot','snapshot',{...original,comment:'Changed'},at),'already-exists'));
await check('foreign snapshot access rejected',()=>denied(freeze(db,'foreign','snapshot',original,at),'permission-denied'));
await check('caller mutation does not mutate durable snapshot',async()=>{const value=await freeze(db,'snapshot','snapshot',original,at);value.comment='Local mutation';assert.deepEqual(await freeze(db,'snapshot','snapshot',changed,at),original);});
await ready(db,'snapshot','snapshot',[{path:'review_drafts/snapshot/snapshot/photo.jpg',url:'https://fixture.invalid/snapshot',generation:'1'}],at);
await check('publisher cannot bypass frozen profile',()=>denied(publish(db,'snapshot','snapshot',changed,at),'already-exists'));
await check('publisher cannot bypass frozen user intent',()=>denied(publish(db,'snapshot','snapshot',{...original,comment:'Other'},at),'already-exists'));
await check('frozen submission publishes atomically',async()=>{assert.equal((await publish(db,'snapshot','snapshot',original,at)).stillCurrent,true);assert.equal((await row('snapshot').get()).data().userName,original.userName);assert.equal((await ref('snapshot').get()).data().state,'linked');});
await check('expired linked retry retrieves original snapshot',async()=>{const frozen=await freeze(db,'snapshot','snapshot',changed,expiry);assert.deepEqual(frozen,original);assert.equal((await publish(db,'snapshot','snapshot',frozen,expiry)).stillCurrent,true);});
await row('snapshot').delete();
await check('lost response retry does not resurrect deleted review',async()=>{assert.equal((await publish(db,'snapshot','snapshot',await freeze(db,'snapshot','snapshot',changed,expiry),expiry)).stillCurrent,false);assert.equal((await row('snapshot').get()).exists,false);});
await draft('expired');
await check('expired unlinked draft cannot freeze',()=>denied(freeze(db,'expired','expired',original,expiry),'deadline-exceeded'));
await draft('abandoned');await freeze(db,'abandoned','abandoned',original,at);await cleanup(db,'abandoned','abandoned',true,at);
await check('cleanup tombstone forbids snapshot retry',()=>denied(freeze(db,'abandoned','abandoned',original,at),'failed-precondition'));
await staged('ready');
await check('ready draft can freeze before first publication',async()=>assert.deepEqual(await freeze(db,'ready','ready',original,at),original));
await staged('legacy');await publish(db,'legacy','legacy',original,at);
await check('historical linked draft cannot acquire invented snapshot',()=>denied(freeze(db,'legacy','legacy',changed,at),'failed-precondition'));
await check('historical linked retry remains compatible',async()=>assert.equal((await publish(db,'legacy','legacy',original,expiry)).stillCurrent,true));
await draft('race');
await check('concurrent same intent profile snapshots select one durable winner',async()=>{const values=await Promise.all([freeze(db,'race','race',original,at),freeze(db,'race','race',changed,at)]);assert.deepEqual(values[0],values[1]);assert.deepEqual((await ref('race').get()).data().publication.content,values[0]);});
await draft('intent-race');
await check('concurrent differing intent allows exactly one',async()=>{const results=await Promise.allSettled([freeze(db,'intent-race','intent-race',original,at),freeze(db,'intent-race','intent-race',{...original,rating:1},at)]);assert.equal(results.filter(x=>x.status==='fulfilled').length,1);assert.equal(results.find(x=>x.status==='rejected').reason.code,'already-exists');});
await staged('corrupt');await freeze(db,'corrupt','corrupt',original,at);
await ref('corrupt').update({'publication.content.comment':'Tampered'});
await check('snapshot content digest corruption blocks retry',()=>denied(freeze(db,'corrupt','corrupt',original,at),'failed-precondition'));
await check('snapshot corruption blocks publication without review write',async()=>{await denied(publish(db,'corrupt','corrupt',original,at),'failed-precondition');assert.equal((await row('corrupt').get()).exists,false);assert.equal((await ref('corrupt').get()).data().state,'ready');});
await draft('null');await ref('null').update({publication:null});
await check('explicit null snapshot fails closed',()=>denied(freeze(db,'null','null',original,at),'failed-precondition'));
await draft('invalid');
await check('invalid proposed profile rejected before write',async()=>{await denied(freeze(db,'invalid','invalid',{...original,userName:7},at),'invalid-argument');assert.equal((await ref('invalid').get()).data().publication,undefined);});
await draft('clock');
await check('expiry rechecked after transaction read',async()=>{let calls=0;await denied(freeze(db,'clock','clock',original,()=>++calls===1?at:expiry),'deadline-exceeded');assert.equal((await ref('clock').get()).data().publication,undefined);});
console.log(`SUMMARY ${passed} passed ${failed} failed`);if(failed)process.exitCode=1;
}
main().catch(e=>{console.error(e);process.exitCode=1;}).finally(()=>admin.app().delete());
