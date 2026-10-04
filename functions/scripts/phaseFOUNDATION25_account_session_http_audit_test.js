// Existing-behavior audit, not active-session safety acceptance.
// Genuine demo JWTs + actual v1 SDK/HTTP, no verification mocks or live data.
const assert=require('node:assert/strict'),{randomUUID}=require('node:crypto');
for(const key of ['FIRESTORE_EMULATOR_HOST','FIREBASE_AUTH_EMULATOR_HOST','FIREBASE_STORAGE_EMULATOR_HOST']) {
 if(!/^(127\.0\.0\.1|localhost|\[::1\]):\d+$/.test(process.env[key]||''))throw Error('Loopback emulator required.');
}
if(process.env.FIREBASE_DEBUG_MODE||process.env.FIREBASE_DEBUG_FEATURES)throw Error('Verification bypass prohibited.');
const P='demo-agrimore-account-session';process.env.GCLOUD_PROJECT=P;process.env.STORAGE_EMULATOR_HOST='http://'+process.env.FIREBASE_STORAGE_EMULATOR_HOST;
const admin=require('firebase-admin'),express=require('express');
const app=admin.initializeApp({projectId:P,storageBucket:P+'.appspot.com'}),db=app.firestore(),auth=app.auth();
const remove=require('../lib/customer/deleteUserData').deleteUserData;
let server,passed=0,failed=0,sequence=0;
async function fixture(){
 const uid='account-audit-'+(++sequence),email=uid+'@fixture.invalid',password=randomUUID();
 await auth.createUser({uid,email,password});await db.doc('users/'+uid).set({name:'Synthetic account',role:'user'});
 // Early balance refusal guarantees no deletion/business mutation for admitted stale sessions.
 await db.doc('wallets/'+uid).set({userId:uid,balance:5});
 const r=await fetch('http://'+process.env.FIREBASE_AUTH_EMULATOR_HOST+'/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({email,password,returnSecureToken:true})});
 const d=await r.json();if(r.status!==200||typeof d.idToken!=='string')throw Error('Synthetic sign-in failed.');return {uid,jwt:d.idToken,decoded:await auth.verifyIdToken(d.idToken)};
}
async function call(u,data={}){
 const headers={'content-type':'application/json'};if(u)headers.authorization='Bearer '+u.jwt;
 const r=await fetch('http://127.0.0.1:9972/deleteUserData',{method:'POST',headers,body:JSON.stringify({data})}),b=await r.json();
 return {status:r.status,error:b.error?.status,result:b.result};
}
async function unchanged(u){
 assert.deepEqual((await db.doc('users/'+u.uid).get()).data(),{name:'Synthetic account',role:'user'});
 assert.deepEqual((await db.doc('wallets/'+u.uid).get()).data(),{userId:u.uid,balance:5});
 assert.equal((await db.doc('account_deletion_audit/'+u.uid).get()).exists,false);
}
async function observedRefusal(u){const r=await call(u,{expectedOwnerId:u.uid});assert.equal(r.error,'FAILED_PRECONDITION');assert.equal(r.result,undefined);await unchanged(u);}
async function check(name,fn){try{await fn();passed++;console.log('PASS '+name);}catch(e){failed++;console.error('FAIL '+name+': '+e.name+' '+e.message);}}
async function run(){
 const web=express();web.use(express.json());web.post('/deleteUserData',remove);
 server=await new Promise(resolve=>{const s=web.listen(9972,'127.0.0.1',()=>resolve(s));});
 await check('fresh genuine JWT reaches wallet refusal without mutation',async()=>{const u=await fixture();assert.equal((await auth.verifyIdToken(u.jwt)).uid,u.uid);await observedRefusal(u);});
 for(const kind of ['disabled','revoked','deleted']){
  await check(kind+' existing JWT rejected by genuine emulator HTTP verification',async()=>{
   const u=await fixture();
   if(kind==='disabled')await auth.updateUser(u.uid,{disabled:true});
   if(kind==='revoked'){await new Promise(resolve=>setTimeout(resolve,1100));await auth.revokeRefreshTokens(u.uid);}
   if(kind==='deleted')await auth.deleteUser(u.uid);
   const expected={disabled:'auth/user-disabled',revoked:'auth/id-token-revoked',deleted:'auth/user-not-found'}[kind];
   await assert.rejects(()=>auth.verifyIdToken(u.jwt,true),e=>e.code===expected);
   assert.equal((await call(u,{expectedOwnerId:u.uid})).error,'UNAUTHENTICATED');await unchanged(u);
   // Explicit handler-boundary simulation: decoded identity was captured before lifecycle change.
   // This is NOT actual HTTP admission or a live exploit assertion.
   await assert.rejects(()=>remove.run({expectedOwnerId:u.uid},{auth:{uid:u.uid,token:u.decoded,rawToken:u.jwt}}),e=>e.code==='failed-precondition');
   await unchanged(u);
   console.log('OBSERVATION '+kind+': emulator HTTP rejects; handler accepts preverified context until wallet refusal.');
  });
 }
 await check('missing JWT denied before business handler',async()=>{const u=await fixture();assert.equal((await call(null,{expectedOwnerId:u.uid})).error,'UNAUTHENTICATED');await unchanged(u);});
 await check('invalid bearer denied by actual SDK',async()=>{const u=await fixture();assert.equal((await call({jwt:randomUUID()},{expectedOwnerId:u.uid})).error,'UNAUTHENTICATED');await unchanged(u);});
 await check('client auth envelope cannot authenticate caller',async()=>{const u=await fixture();assert.equal((await call(null,{auth:{uid:u.uid},expectedOwnerId:u.uid})).error,'UNAUTHENTICATED');await unchanged(u);});
 await check('fresh JWT cannot select another deletion owner',async()=>{const u=await fixture(),other=await fixture();assert.equal((await call(u,{expectedOwnerId:other.uid})).error,'PERMISSION_DENIED');await unchanged(u);await unchanged(other);});
 console.log(`AUDIT ${passed} observations confirmed; ${failed} failed. Emulator transport denies stale sessions; handler active-session recheck remains OPEN.`);if(failed)process.exitCode=1;
}
run().catch(e=>{console.error('Audit failed: '+e.name+' '+e.message);process.exitCode=1;}).finally(async()=>{if(server)await new Promise(resolve=>server.close(resolve));await app.delete();});
