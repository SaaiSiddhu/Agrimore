// ============================================================
//  Phase 16, Workstream 2 — 2Factor SMS/voice OTP delivery test
// ============================================================
//
// Never calls a real provider. axios.post is monkey-patched (axios.default
// === axios itself, confirmed empirically, so patching axios.post here is
// visible through the compiled lib's `axios_1.default.post` call site) to
// record calls and return a canned { Status: "Success" } response.
//
// Tests BOTH the disabled (no TWOFACTOR_API_KEY) and enabled (mocked
// provider) paths in one process by deleting the relevant require.cache
// entries between the two halves — PHONE_OTP_ENABLED is a module-level
// const evaluated once at require() time, so this is the only way to
// exercise both states without two separate processes.
//
// Run with: firebase emulators:exec --only firestore
//             "node scripts/phase16_phone_otp_test.js"
//           (Firestore emulator only — no functions/auth emulator needed;
//           handlers are invoked directly, mirroring phase15_email_otp_test.js)

process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";
delete process.env.TWOFACTOR_API_KEY;
delete process.env.OTP_ENCRYPTION_KEY;

const axios = require("axios");
const providerCalls = [];
let providerShouldFail = false;
axios.post = async (url) => {
  providerCalls.push({ url });
  if (providerShouldFail) {
    return { data: { Status: "Error", Details: "mocked provider failure" } };
  }
  return { data: { Status: "Success", Details: "mocked" } };
};

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });
const db = admin.firestore();

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

function reloadPhoneOtpModules() {
  for (const key of Object.keys(require.cache)) {
    if (
      key.includes("/lib/common/sendPhoneOTP.js") ||
      key.includes("/lib/common/verifyPhoneOTP.js") ||
      key.includes("/lib/common/smsProvider.js")
    ) {
      delete require.cache[key];
    }
  }
  return {
    sendPhoneOTP: require("../lib/common/sendPhoneOTP").sendPhoneOTP,
    verifyPhoneOTP: require("../lib/common/verifyPhoneOTP").verifyPhoneOTP,
  };
}

function extractOtpFromUrl(url) {
  // .../SMS/<phone>/<otp> or .../VOICE/<phone>/<otp>
  return url.split("/").pop();
}

async function main() {
  let allPassed = true;
  const results = {};

  console.log("=== PHASE 16, WORKSTREAM 2 — phone OTP (2Factor) ===");

  // ---------------------------------------------------------------
  // PART A — DISABLED (no TWOFACTOR_API_KEY)
  // ---------------------------------------------------------------
  {
    const { sendPhoneOTP, verifyPhoneOTP } = reloadPhoneOtpModules();
    const phone = "+919876500001";

    const sendRes = makeRes();
    await sendPhoneOTP({ method: "POST", body: { phone } }, sendRes);
    const s1 = sendRes.statusCode === 503 && sendRes.body?.success === false;
    results.scenario1_disabled_send_503 = s1;
    console.log(`scenario1_disabled_send_503: ${s1 ? "PASSED" : "FAILED"} — status=${sendRes.statusCode} body=${JSON.stringify(sendRes.body)}`);
    if (!s1) allPassed = false;

    const doc = await db.collection("phone_otp_codes").doc(phone).get();
    const s1b = !doc.exists;
    results.scenario1b_disabled_send_no_side_effects = s1b;
    console.log(`scenario1b_disabled_send_no_side_effects: ${s1b ? "PASSED" : "FAILED"} — doc.exists=${doc.exists}`);
    if (!s1b) allPassed = false;

    const verifyRes = makeRes();
    await verifyPhoneOTP({ method: "POST", body: { phone, otp: "123456" } }, verifyRes);
    const s2 = verifyRes.statusCode === 503 && verifyRes.body?.token === undefined;
    results.scenario2_disabled_verify_503_no_token = s2;
    console.log(`scenario2_disabled_verify_503_no_token: ${s2 ? "PASSED" : "FAILED"} — status=${verifyRes.statusCode} body=${JSON.stringify(verifyRes.body)}`);
    if (!s2) allPassed = false;
  }

  // ---------------------------------------------------------------
  // PART B — ENABLED (mocked provider)
  // ---------------------------------------------------------------
  process.env.TWOFACTOR_API_KEY = "phase16-fake-2factor-key-never-real";
  process.env.OTP_ENCRYPTION_KEY = "phase16-fake-encryption-passphrase";
  // Phase 22 additive fixture note: this part's scenarios (3 and 7 in
  // particular) test a working SMS provider — scenario 3 asserts delivery
  // hits the `/SMS/` endpoint, scenario 7 asserts the voice-specific daily
  // cap. Phase 22 made SMS delivery conditional on PHONE_OTP_SMS_ENABLED
  // (default disabled, to match this account's current DLT-gap reality —
  // see smsProvider.ts's OPEN ISSUE comment), so this part must opt in
  // explicitly to keep testing what it always tested: a provider that can
  // actually deliver SMS. No assertion below changed.
  process.env.PHONE_OTP_SMS_ENABLED = "true";
  const { sendPhoneOTP, verifyPhoneOTP } = reloadPhoneOtpModules();

  // Scenario 3: OTP generated, hashed (not plaintext), handed to provider
  // exactly once. NOTE: sendPhoneOTP.ts's response then does a "does this
  // user already exist" auth.getUserByPhoneNumber() lookup purely to
  // populate the informational `userExists` field — in this environment
  // (no Auth emulator, no real service-account credential) that lookup
  // itself fails and the handler returns 500, even though the actual
  // generate/hash/store/deliver logic (what this scenario tests) already
  // completed correctly beforehand. So this asserts on the Firestore write
  // and the provider call directly, not on the final HTTP status.
  {
    const phone = "+919876500002";
    providerCalls.length = 0;
    const res = makeRes();
    await sendPhoneOTP({ method: "POST", body: { phone } }, res);
    const doc = await db.collection("phone_otp_codes").doc(phone).get();
    const data = doc.data();
    const otpFromProviderCall = providerCalls.length === 1 ? extractOtpFromUrl(providerCalls[0].url) : null;
    const crypto = require("crypto");
    const expectedHash = otpFromProviderCall
      ? crypto.createHash("sha256").update(otpFromProviderCall).digest("hex")
      : null;
    const s3 =
      doc.exists &&
      providerCalls.length === 1 &&
      providerCalls[0].url.includes("/SMS/") &&
      !!data.otpHash &&
      data.otpHash !== otpFromProviderCall &&
      data.otpHash === expectedHash;
    results.scenario3_otp_generated_hashed_delivered_once = s3;
    console.log(
      `scenario3_otp_generated_hashed_delivered_once: ${s3 ? "PASSED" : "FAILED"} (environment-limited: final HTTP status is 500 due to the unrelated userExists auth.getUserByPhoneNumber() lookup failing — no Auth emulator here; the generate/hash/store/deliver logic under test is verified directly against Firestore + the mocked provider call) — providerCalls=${providerCalls.length} otpHash=${data?.otpHash?.slice(0, 8)}...`
    );
    if (!s3) allPassed = false;
  }

  // Scenario 4 — THE voice-reuse proof: a voice request for a number with a
  // live, unexpired SMS OTP redelivers the SAME code, not a new one.
  {
    const phone = "+919876500003";
    providerCalls.length = 0;

    const smsRes = makeRes();
    await sendPhoneOTP({ method: "POST", body: { phone } }, smsRes);
    const smsOtp = extractOtpFromUrl(providerCalls[0].url);

    // Bypass the resend cooldown for THIS test only by backdating createdAt
    // — otherwise this legitimate channel-switch request would itself hit
    // the 30s cooldown gate, which is a separate, correctly-enforced rule
    // this scenario isn't testing.
    await db.collection("phone_otp_codes").doc(phone).update({ createdAt: Date.now() - 31000 });

    const voiceRes = makeRes();
    await sendPhoneOTP({ method: "POST", body: { phone, channel: "voice" } }, voiceRes);
    const voiceOtp = extractOtpFromUrl(providerCalls[1].url);

    // Same environment-limited status-code caveat as scenario 3 — this is
    // THE correctness-trap proof (voice must redeliver the identical code),
    // asserted directly on the provider call payloads.
    const s4 = providerCalls[1].url.includes("/VOICE/") && voiceOtp === smsOtp;
    results.scenario4_voice_reuses_same_code = s4;
    console.log(
      `scenario4_voice_reuses_same_code: ${s4 ? "PASSED" : "FAILED"} — smsOtp=${smsOtp} voiceOtp=${voiceOtp}`
    );
    if (!s4) allPassed = false;
  }

  // Scenario 5: resend cooldown -> 429
  {
    const phone = "+919876500004";
    await sendPhoneOTP({ method: "POST", body: { phone } }, makeRes());
    const res2 = makeRes();
    await sendPhoneOTP({ method: "POST", body: { phone } }, res2);
    const s5 = res2.statusCode === 429 && typeof res2.body?.retryAfterMs === "number";
    results.scenario5_cooldown_429 = s5;
    console.log(`scenario5_cooldown_429: ${s5 ? "PASSED" : "FAILED"} — status=${res2.statusCode} body=${JSON.stringify(res2.body)}`);
    if (!s5) allPassed = false;
  }

  // Scenario 6: daily send cap -> 429. Seeded directly at the cap rather
  // than looping 10 real cooldown-gated sends.
  {
    const phone = "+919876500005";
    await db.collection("phone_otp_codes").doc(phone).set({
      otpHash: "seed",
      otpEncrypted: null,
      phone,
      expiresAt: Date.now() + 5 * 60 * 1000,
      createdAt: Date.now() - 31000,
      verified: false,
      attempts: 0,
      channel: "sms",
      sendCount: 10,
      sendWindowStart: Date.now(),
      voiceSendCount: 0,
      voiceSendWindowStart: Date.now(),
    });
    const res = makeRes();
    await sendPhoneOTP({ method: "POST", body: { phone } }, res);
    const s6 = res.statusCode === 429;
    results.scenario6_daily_cap_429 = s6;
    console.log(`scenario6_daily_cap_429: ${s6 ? "PASSED" : "FAILED"} — status=${res.statusCode} body=${JSON.stringify(res.body)}`);
    if (!s6) allPassed = false;
  }

  // Scenario 7: voice daily cap -> 429 (lower threshold, 3)
  {
    const phone = "+919876500006";
    await db.collection("phone_otp_codes").doc(phone).set({
      otpHash: "seed",
      otpEncrypted: null,
      phone,
      expiresAt: Date.now() + 5 * 60 * 1000,
      createdAt: Date.now() - 31000,
      verified: false,
      attempts: 0,
      channel: "sms",
      sendCount: 1,
      sendWindowStart: Date.now(),
      voiceSendCount: 3,
      voiceSendWindowStart: Date.now(),
    });
    const res = makeRes();
    await sendPhoneOTP({ method: "POST", body: { phone, channel: "voice" } }, res);
    const s7 = res.statusCode === 429;
    results.scenario7_voice_daily_cap_429 = s7;
    console.log(`scenario7_voice_daily_cap_429: ${s7 ? "PASSED" : "FAILED"} — status=${res.statusCode} body=${JSON.stringify(res.body)}`);
    if (!s7) allPassed = false;
  }

  // Scenario 8: wrong OTP rejected; correct OTP authenticates (up to the
  // point the Auth emulator would be needed — same disclosed environment
  // limitation as phase15_email_otp_test.js / phase15_set_user_role_test.js).
  {
    const phone = "+919876500007";
    providerCalls.length = 0;
    await sendPhoneOTP({ method: "POST", body: { phone } }, makeRes());
    const realOtp = extractOtpFromUrl(providerCalls[0].url);

    const wrongRes = makeRes();
    await verifyPhoneOTP({ method: "POST", body: { phone, otp: "000000" } }, wrongRes);
    const s8a = wrongRes.statusCode === 400 && wrongRes.body?.success === false;
    results.scenario8a_wrong_otp_rejected = s8a;
    console.log(`scenario8a_wrong_otp_rejected: ${s8a ? "PASSED" : "FAILED"} — body=${JSON.stringify(wrongRes.body)}`);
    if (!s8a) allPassed = false;

    // verifyPhoneOTP.ts catches its own internal errors and resolves with a
    // 500 response rather than throwing — so there is no exception to
    // catch here. A clean 200+token would be the strongest possible pass;
    // in this environment (no Auth emulator, no real service-account
    // credential), auth.getUserByPhoneNumber()/createCustomToken() fail and
    // the handler returns 500 regardless of whether the OTP was correct —
    // so the correct-vs-wrong distinction is verified via the Firestore
    // side effect instead: verifyPhoneOTP.ts marks the OTP doc
    // `verified: true` immediately BEFORE attempting the Auth call, only on
    // a correct hash match.
    const correctRes = makeRes();
    await verifyPhoneOTP({ method: "POST", body: { phone, otp: realOtp } }, correctRes);
    let s8b;
    if (correctRes.statusCode === 200 && correctRes.body?.token) {
      s8b = true;
      console.log(`scenario8b_correct_otp_authenticates: PASSED (full round-trip) — status=${correctRes.statusCode}`);
    } else {
      const otpDoc = await db.collection("phone_otp_codes").doc(phone).get();
      s8b = otpDoc.exists && otpDoc.data()?.verified === true;
      console.log(
        `scenario8b_correct_otp_authenticates: ${s8b ? "PASSED" : "FAILED"} (partial — environment-limited) — status=${correctRes.statusCode}, hash comparison ${s8b ? "succeeded (otp doc marked verified)" : "could not be confirmed"}; the subsequent auth.createCustomToken() step is not verifiable here (no Auth emulator configured, no real service-account credential available/appropriate). Full token-mint round-trip NOT verified in this environment.`
      );
    }
    results.scenario8b_correct_otp_authenticates = s8b;
    if (!s8b) allPassed = false;
  }

  // Scenario 9: provider failure leaves no usable OTP document behind
  {
    const phone = "+919876500008";
    providerShouldFail = true;
    const res = makeRes();
    await sendPhoneOTP({ method: "POST", body: { phone } }, res);
    providerShouldFail = false;
    const doc = await db.collection("phone_otp_codes").doc(phone).get();
    const s9 = res.statusCode === 502 && !doc.exists;
    results.scenario9_provider_failure_no_leftover_doc = s9;
    console.log(`scenario9_provider_failure_no_leftover_doc: ${s9 ? "PASSED" : "FAILED"} — status=${res.statusCode} docExists=${doc.exists}`);
    if (!s9) allPassed = false;

    const failureLog = await db.collection("otp_delivery_failures").where("phone", "==", phone).get();
    const s9b = !failureLog.empty;
    results.scenario9b_failure_logged_to_diagnostics = s9b;
    console.log(`scenario9b_failure_logged_to_diagnostics: ${s9b ? "PASSED" : "FAILED"} — logged=${!failureLog.empty}`);
    if (!s9b) allPassed = false;
  }

  console.log("");
  console.log(allPassed ? "ALL PASSED" : "SOME FAILED");
  console.log(JSON.stringify(results, null, 2));
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phase16 phone otp test:", e);
  process.exit(1);
});
