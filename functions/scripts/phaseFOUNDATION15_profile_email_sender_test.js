// Synthetic failure responses from the real compiled HTTP handler. Every
// database/provider operation is blocked or replaced; no sockets or live IO.
const assert = require('node:assert/strict');
if (!/^demo-agrimore-/.test(process.env.GCLOUD_PROJECT || '') ||
    !/^(127\.0\.0\.1|localhost):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST || '')) {
  throw new Error('Requires explicit demo project and loopback Firestore host');
}
const provider = require.resolve('../lib/common/emailProvider');
require.cache[provider] = { id: provider, filename: provider, loaded: true,
  exports: { sendEmailViaResend: async () => { throw new Error('Provider must not run in synthetic error controls'); } } };
const admin = require('firebase-admin');
if (!admin.apps.length) admin.initializeApp({projectId: process.env.GCLOUD_PROJECT});
const db = admin.firestore();
const {sendEmailOTP} = require('../lib/common/sendEmailOTP');
const originalCollection = db.collection;
const errors = [new Error('private fixture diagnostic'), new TypeError('private fixture type diagnostic'),
  {message: 'private fixture object diagnostic'}, {message: null}, {message: ''}, {message: {private: 'fixture'}}];
let passed = 0, failed = 0, calls = 0;
function response() {
  return {statusCode: 200, body: null, set() { return this; }, status(value) {this.statusCode=value; return this;},
    json(value) {this.body=value; return this;}, send(value) {this.body=value; return this;}};
}
async function test(name, run) {
  try { await run(); passed++; console.log('PASS '+name); }
  catch (error) { failed++; console.log('FAIL '+name+': '+error.message); }
}
(async () => {
  try {
    for (const [index, error] of errors.entries()) {
      await test('unexpected database failure '+index+' returns static public error', async () => {
        calls = 0; db.collection = () => {calls++; throw error;};
        const res = response(); await sendEmailOTP({method:'POST',body:{email:'fixture@example.invalid'}},res);
        assert.equal(res.statusCode,500); assert.deepEqual(res.body,{success:false,error:'Failed to send verification code. Please try again.'});
        assert.equal(calls,1); assert.equal(JSON.stringify(res.body).includes('private'),false);
      });
    }
    db.collection = () => {calls++; throw new Error('Unexpected database IO in validation control');};
    for (const [name,req,status,error] of [
      ['missing email',{method:'POST',body:{}},400,'Email is required'],
      ['non-string email',{method:'POST',body:{email:42}},400,'Email is required'],
      ['bad email',{method:'POST',body:{email:'invalid'}},400,'Invalid email format'],
      ['GET',{method:'GET',body:{}},405,'Method not allowed'],
      ['OPTIONS',{method:'OPTIONS',body:{}},204,null],
    ]) {
      await test('existing '+name+' control before IO', async () => {
        calls=0; const res=response(); await sendEmailOTP(req,res); assert.equal(res.statusCode,status); assert.equal(calls,0);
        if(error) assert.deepEqual(res.body,{success:false,error}); else assert.equal(res.body,'');
      });
    }
  } finally { db.collection = originalCollection; }
  console.log('FOUNDATION15 '+passed+' passed; '+failed+' failed');
  if(failed) process.exitCode=1;
})().catch(error => {console.error(error);process.exitCode=1;});
