// Demo-only pending activation lock: real Firestore rules + internal Admin SDK publication.
process.env.FIRESTORE_EMULATOR_HOST='127.0.0.1:8080';
const fs=require('fs'),path=require('path'),assert=require('node:assert/strict'),admin=require('firebase-admin');
const {initializeTestEnvironment,assertFails,assertSucceeds}=require('@firebase/rules-unit-testing');
const {doc,setDoc,updateDoc,deleteDoc,getDoc}=require('firebase/firestore');
const {createPhotoDraft:create,readyPhotoDraft:ready,freezePhotoContent:freeze,publishPhotoDraft:publish}=require('../lib/seller/reviewPhotoDraftCore');
const project='demo-agrimore-review-photo-lock',app=admin.initializeApp({projectId:project}),db=app.firestore();
let passed=0,failed=0;
const check=async(name,fn)=>{try{await fn();passed++;console.log('PASS '+name);}catch(e){failed++;console.log('FAIL '+name+': '+e.message);}};
async function main(){
const env=await initializeTestEnvironment({projectId:project,firestore:{host:'127.0.0.1',port:8080,rules:fs.readFileSync(path.join(__dirname,'../../firestore.rules'),'utf8')}});
const user=(uid,claims={})=>uid?env.authenticatedContext(uid,claims).firestore():env.unauthenticatedContext().firestore();
const row=(uid,id,claims)=>doc(user(uid,claims),'products/p/reviews/'+id);
const base={userId:'owner',productId:'p',rating:4,comment:'Original',imageUrls:['https://fixture.invalid/photo'],helpfulUsers:[],unhelpfulUsers:[],helpfulCount:0,unhelpfulCount:0};
const fixture=(id,extra={})=>env.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),'products/p/reviews/'+id),{...base,...extra}));
const pending={photoDraftId:'draft',photoActivationState:'pending'};
const edit=async(name,patch,extra=pending)=>{await fixture(name,extra);await check(name,()=>assertFails(updateDoc(row('owner',name),patch)));};
try{
await fixture('read',pending);await check('pending review remains publicly readable',()=>assertSucceeds(getDoc(row(null,'read'))));
await edit('pending text edit denied',{comment:'Changed'});
await edit('pending photo removal denied',{imageUrls:[]});
await edit('pending rating edit denied',{rating:1});
await edit('owner cannot clear pending marker',{photoActivationState:'complete'});
await edit('owner cannot replace draft identity',{photoDraftId:'other'});
await fixture('delete',pending);await check('pending author delete denied',()=>assertFails(deleteDoc(row('owner','delete'))));
await fixture('admin-delete',pending);await check('pending admin client delete denied',()=>assertFails(deleteDoc(row('admin','admin-delete',{admin:true}))));
await fixture('vote',pending);await check('pending reader vote allowed',()=>assertSucceeds(updateDoc(row('reader','vote'),{helpfulUsers:['reader'],helpfulCount:1})));
await fixture('author-vote',pending);await check('pending author self vote allowed',()=>assertSucceeds(updateDoc(row('owner','author-vote'),{helpfulUsers:['owner'],helpfulCount:1})));
await fixture('mixed-vote',pending);await check('pending author mixed vote and edit denied',()=>assertFails(updateDoc(row('owner','mixed-vote'),{helpfulUsers:['owner'],helpfulCount:1,comment:'Changed'})));
for(const [key,value] of [['photoDraftId','forged'],['photoActivationState','pending'],['photoActivationState','complete']]){
 await check('new author cannot forge '+key+' '+value,()=>assertFails(setDoc(row('owner','create-'+key+'-'+value),{...base,[key]:value})));
}
await edit('legacy owner cannot inject activation marker',{photoActivationState:'complete'},{});
await edit('legacy owner cannot inject draft identity',{photoDraftId:'fake'},{});
await fixture('legacy-edit');await check('legacy author edit preserved',()=>assertSucceeds(updateDoc(row('owner','legacy-edit'),{comment:'Changed'})));
await fixture('legacy-delete');await check('legacy author delete preserved',()=>assertSucceeds(deleteDoc(row('owner','legacy-delete'))));
await fixture('complete-edit',{photoDraftId:'old',photoActivationState:'complete'});await check('completed author edit allowed',()=>assertSucceeds(updateDoc(row('owner','complete-edit'),{comment:'Changed'})));
await fixture('complete-delete',{photoDraftId:'old',photoActivationState:'complete'});await check('completed author delete allowed',()=>assertSucceeds(deleteDoc(row('owner','complete-delete'))));
await edit('completed owner cannot mutate server marker',{photoActivationState:'pending'},{photoDraftId:'old',photoActivationState:'complete'});
await edit('malformed marker fails closed',{comment:'Changed'},{photoDraftId:'draft',photoActivationState:null});
await db.doc('products/p').set({name:'Synthetic'});
const content={rating:4,title:'Title',comment:'Comment',userName:'Owner',userAvatar:''};
await create(db,'managed','managed','p','managed',['photo'],1000);await freeze(db,'managed','managed',content,1000);
await ready(db,'managed','managed',[{path:'review_drafts/managed/managed/photo.jpg',url:'https://fixture.invalid/managed',generation:'1'}],1000);
await create(db,'managed','competitor','p','managed',['photo'],1000);
await ready(db,'managed','competitor',[{path:'review_drafts/managed/competitor/photo.jpg',url:'https://fixture.invalid/competitor',generation:'1'}],1000);
await check('snapshot publication atomically locks linked review and draft',async()=>{await publish(db,'managed','managed',content,1000);const [r,d]=await Promise.all([db.doc('products/p/reviews/managed').get(),db.doc('review_photo_drafts/managed').get()]);assert.equal(r.data().photoActivationState,'pending');assert.equal(d.data().photoActivationState,'pending');assert.equal(d.data().state,'linked');});
await check('actual managed publication client edit denied',()=>assertFails(updateDoc(row('managed','managed'),{comment:'Changed'})));
await check('same managed publication retry retains lock',async()=>{assert.equal((await publish(db,'managed','managed',content,1801000)).stillCurrent,true);assert.equal((await db.doc('products/p/reviews/managed').get()).data().photoActivationState,'pending');});
await check('previously prepared competing draft cannot overwrite pending review',()=>assert.rejects(publish(db,'managed','competitor',content,1000),e=>e.code==='failed-precondition'));
await check('new trusted draft cannot replace pending managed review',()=>assert.rejects(create(db,'managed','next-draft','p','managed',['photo'],1000),e=>e.code==='failed-precondition'));
console.log(`SUMMARY ${passed} passed ${failed} failed`);if(failed)process.exitCode=1;
}finally{await env.cleanup();await app.delete();}
}
main().catch(e=>{console.error(e);process.exitCode=1;});
