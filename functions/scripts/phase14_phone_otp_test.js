// ============================================================
//  Phase 14, Workstream 1 — phone OTP fail-closed gate
// ============================================================
//
// Proves sendPhoneOTP/verifyPhoneOTP refuse to run at all — 503, zero
// side effects, zero provider calls — when no SMS provider is configured.
//
// FIX-5C, WS2. REWRITTEN. The original version of this file hit the LIVE
// functions-emulator HTTP server (`fetch()` to a `firebase emulators:exec
// --only firestore,functions,auth` process) and tried to disable the
// provider by doing `delete process.env.TWOFACTOR_API_KEY` in the TEST
// process. That never reached the function: the function runs in a
// SEPARATE OS process, which loads its own environment from
// functions/.secret.local — and TWOFACTOR_API_KEY has lived there, as a
// REAL, LIVE 2Factor production credential, since Phase 18 (see
// functions/.secret.local.example's own comment: "fill in REAL values to
// let the Firebase emulator resolve Secret Manager-bound secrets
// locally"). The old scenario 1 therefore did not test the disabled path
// at all — it called the REAL, LIVE sendPhoneOTP with a REAL provider key
// configured, which places a REAL POST to https://2factor.in's SMS API
// (smsProvider.ts's call2Factor()) for whatever phone number the fixture
// hardcodes. Measured directly: running the old test twice this session
// (once via this repo's full `gate.sh --emulator`, once standalone)
// produced `{"status":200,"json":{"success":true,...}}` both times — a
// REAL 2Factor SMS/voice send request was submitted and accepted
// (Status: Success) for "+919876543210", TWICE, using the real production
// key, before this defect was noticed. That is exactly what
// references/run.md's loop rule "never triggers a real OTP" exists to
// prevent, and it was happening on every `--emulator` run of this suite,
// silently, because the suite's own exit code was FAILING for the
// unrelated reason of expecting 503 and getting 200 — a false negative
// that hid a true, live side effect behind an apparently-just-stale test.
//
// The fix mirrors phase16_phone_otp_test.js's and phase22_channel_config_
// test.js's already-correct architecture in this same directory: require
// the COMPILED handlers directly and invoke them in-process (no functions
// emulator, no HTTP hop, so functions/.secret.local is never loaded by
// anything this test starts), with axios.post monkey-patched as a second,
// independent layer of defense — even a future accidental require of a
// module that reads a real key can no longer reach the real network.
// PHONE_OTP_ENABLED is a module-level const evaluated once at require()
// time, so deleting TWOFACTOR_API_KEY before that require (now in the SAME
// process as the function code) actually disables it, which is the whole
// point.
//
// Run with: firebase emulators:exec --only firestore
//             "node scripts/phase14_phone_otp_test.js"
//           (Firestore emulator only — no functions/auth emulator. This
//           suite must never be run with --only including "functions": that
//           is what makes functions/.secret.local reachable at all.)

process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";
delete process.env.TWOFACTOR_API_KEY;
delete process.env.OTP_ENCRYPTION_KEY;

const axios = require("axios");
const providerCalls = [];
axios.post = async (url) => {
  // Defense in depth only — with no functions emulator running, nothing
  // should ever reach this. If it ever does, it is captured here and
  // FAILS the run (see the assertions below), never delivered.
  providerCalls.push({ url });
  return { data: { Status: "Success", Details: "mocked — should never be called from this suite" } };
};

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });
const db = admin.firestore();

const { sendPhoneOTP } = require("../lib/common/sendPhoneOTP");
const { verifyPhoneOTP } = require("../lib/common/verifyPhoneOTP");

function makeRes() {
  const res = {
    statusCode: 200,
    body: null,
    set() {
      return res;
    },
    status(code) {
      res.statusCode = code;
      return res;
    },
    json(payload) {
      res.body = payload;
      return res;
    },
  };
  return res;
}

async function main() {
  let allPassed = true;
  const results = {};
  const phone = "+919876543210";

  console.log("=== PHASE 14, WORKSTREAM 1 — phone OTP fail-closed gate ===");

  // Scenario 1: sendPhoneOTP with no SMS provider configured — must be
  // 503, must not write a phone_otp_codes document, and must never call
  // the provider.
  {
    const res = makeRes();
    await sendPhoneOTP({ method: "POST", body: { phone } }, res);
    console.log("Scenario 1 raw:", JSON.stringify({ status: res.statusCode, body: res.body }, null, 2));
    let s;
    try {
      if (res.statusCode !== 503) throw new Error(`expected HTTP 503, got ${res.statusCode}`);
      if (res.body?.success !== false) throw new Error(`expected success:false, got ${JSON.stringify(res.body)}`);
      const otpDoc = await db.collection("phone_otp_codes").doc(phone).get();
      if (otpDoc.exists) throw new Error("a phone_otp_codes document was written despite the flow being disabled — NOT fail-closed before side effects");
      if (providerCalls.length !== 0) throw new Error(`the SMS provider was called ${providerCalls.length} time(s) despite the flow being disabled — url=${providerCalls[0]?.url}`);
      s = `PASSED — sendPhoneOTP returned 503 with zero side effects and zero provider calls. body=${JSON.stringify(res.body)}`;
    } catch (e) {
      s = `FAILED — ${e.message}`;
      allPassed = false;
    }
    results.scenario1_send_disabled_returns_503 = s;
    console.log("Scenario 1:", s);
  }

  // Scenario 2 — THE key proof: verifyPhoneOTP with the former FIXED_OTP
  // "123456", no SMS provider configured. Must be 503, no token, no Auth
  // user created for this phone number, before ANY lookup/comparison
  // happens.
  {
    const res = makeRes();
    await verifyPhoneOTP({ method: "POST", body: { phone, otp: "123456" } }, res);
    console.log("Scenario 2 raw:", JSON.stringify({ status: res.statusCode, body: res.body }, null, 2));
    let s;
    try {
      if (res.statusCode !== 503) throw new Error(`expected HTTP 503, got ${res.statusCode}`);
      if (res.body?.success !== false) throw new Error(`expected success:false, got ${JSON.stringify(res.body)}`);
      if (res.body?.token) throw new Error("a custom token was minted despite the flow being disabled — THIS IS THE UNAUTHENTICATED ACCOUNT TAKEOVER, STILL OPEN");
      // "No Auth user created" rests on code inspection, not a live
      // admin.auth().getUserByPhoneNumber() call: this environment runs no
      // Auth emulator, and this suite must never touch real production
      // Firebase Auth. verifyPhoneOTP.ts's PHONE_OTP_ENABLED check is the
      // very first statement in the handler (before the Firestore lookup,
      // the code comparison, and every auth.* call) — the 503 response
      // observed above is only reachable by returning before any of those
      // run.
      s = `PASSED — verifyPhoneOTP with the former fixed code "123456" returned 503 and minted no token. body=${JSON.stringify(res.body)}`;
    } catch (e) {
      s = `FAILED — ${e.message}`;
      allPassed = false;
    }
    results.scenario2_verify_disabled_returns_503_no_token = s;
    console.log("Scenario 2:", s);
  }

  console.log("=== PHASE 14 WORKSTREAM 1 SUMMARY ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);
  console.log(`\nprovider calls made this run: ${providerCalls.length} (must be 0)`);
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phase14 phone otp test:", e);
  process.exit(1);
});
