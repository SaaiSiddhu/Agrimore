// Phase 14, Workstream 1: proves the phone-OTP flow is fail-closed with
// PHONE_OTP_ENABLED unset — a POST to verifyPhoneOTP carrying the former
// FIXED_OTP "123456" for any phone number must return 503 and mint no
// token, with zero side effects (no Auth user created, no Firestore write).
// Hits the real HTTP-triggered emulator functions directly (these are
// functions.https.onRequest, not onCall), the same way a browser's fetch()
// would.
// Run with: node scripts/phase14_phone_otp_test.js
// IMPORTANT: run this in a process where TWOFACTOR_API_KEY is NOT set — it
// specifically proves the default-disabled (no SMS provider configured)
// state.
//
// Phase 16, Workstream 2 fix: the gate's underlying flag changed from a
// standalone PHONE_OTP_ENABLED boolean to isSmsProviderConfigured()
// (TWOFACTOR_API_KEY presence) — see sendPhoneOTP.ts/verifyPhoneOTP.ts's
// truth-table comment. This is AT LEAST as safe as the old flag: the old
// PHONE_OTP_ENABLED="true" could be set by mistake with no real provider
// wired up (issuing OTPs nobody could receive); the new gate can only be
// "on" when a real delivery credential is actually present, so it is
// impossible to be in an accept-but-can't-deliver state. Only the env var
// this test clears changed — the assertions below (still 503, still zero
// side effects, the former FIXED_OTP "123456" still rejected) are
// byte-for-byte unchanged.
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";
delete process.env.TWOFACTOR_API_KEY;

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });

const BASE_URL = "http://127.0.0.1:5001/agrimore-66a4e/us-central1";

async function post(path, body) {
  const res = await fetch(`${BASE_URL}/${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const json = await res.json().catch(() => null);
  return { status: res.status, json };
}

async function main() {
  let allPassed = true;
  const results = {};
  const phone = "9876543210";

  console.log("=== PHASE 14, WORKSTREAM 1 — phone OTP fail-closed gate ===");

  // Scenario 1: sendPhoneOTP with PHONE_OTP_ENABLED unset — must be 503,
  // and must not write a phone_otp_codes document.
  {
    const r = await post("sendPhoneOTP", { phone });
    console.log("Scenario 1 raw:", JSON.stringify(r, null, 2));
    let s;
    try {
      if (r.status !== 503) throw new Error(`expected HTTP 503, got ${r.status}`);
      if (r.json?.success !== false) throw new Error(`expected success:false, got ${JSON.stringify(r.json)}`);
      const otpDoc = await admin.firestore().collection("phone_otp_codes").doc("+91" + phone).get();
      if (otpDoc.exists) throw new Error("a phone_otp_codes document was written despite the flow being disabled — NOT fail-closed before side effects");
      s = `PASSED — sendPhoneOTP returned 503 with zero side effects. body=${JSON.stringify(r.json)}`;
    } catch (e) {
      s = `FAILED — ${e.message}`;
      allPassed = false;
    }
    results.scenario1_send_disabled_returns_503 = s;
    console.log("Scenario 1:", s);
  }

  // Scenario 2 — THE key proof: verifyPhoneOTP with the former FIXED_OTP
  // "123456", PHONE_OTP_ENABLED unset. Must be 503, no token, no Auth user
  // created for this phone number, before ANY lookup/comparison happens.
  {
    const r = await post("verifyPhoneOTP", { phone, otp: "123456" });
    console.log("Scenario 2 raw:", JSON.stringify(r, null, 2));
    let s;
    try {
      if (r.status !== 503) throw new Error(`expected HTTP 503, got ${r.status}`);
      if (r.json?.success !== false) throw new Error(`expected success:false, got ${JSON.stringify(r.json)}`);
      if (r.json?.token) throw new Error("a custom token was minted despite the flow being disabled — THIS IS THE UNAUTHENTICATED ACCOUNT TAKEOVER, STILL OPEN");
      // Not independently re-verified via admin.auth().getUserByPhoneNumber
      // here — this environment only runs the Firestore/Functions
      // emulators (no Auth emulator), so that call would hit real
      // production Firebase Auth, which this phase must never touch. The
      // "no Auth user created" claim instead rests on code inspection:
      // verifyPhoneOTP.ts's PHONE_OTP_ENABLED check is the very first
      // statement in the handler (before the Firestore lookup, the code
      // comparison, and every auth.* call) — the 503 response observed
      // above is only reachable by returning before any of those run.
      s = `PASSED — verifyPhoneOTP with the former fixed code "123456" returned 503 and minted no token. body=${JSON.stringify(r.json)}`;
    } catch (e) {
      s = `FAILED — ${e.message}`;
      allPassed = false;
    }
    results.scenario2_verify_disabled_returns_503_no_token = s;
    console.log("Scenario 2:", s);
  }

  console.log("=== PHASE 14 WORKSTREAM 1 SUMMARY ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phase14 phone otp test:", e);
  process.exit(1);
});
