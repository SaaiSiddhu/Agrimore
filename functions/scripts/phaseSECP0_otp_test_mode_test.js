// ============================================================
//  Phase SEC-P0 — server-side, allow-listed, expiring phone-OTP test mode
// ============================================================
//
// Replaces the client-side mock OTP that commit 9e77189 put in the shared
// AuthService (OTP generated on the device, derivable passwords, a second
// Auth account per phone). The server-side test mode changes exactly ONE
// thing about sendPhoneOTP: for a number on the allowlist, inside the
// window, the code is returned in the response instead of being delivered
// by the provider. Generation, hashing, storage, caps and verifyPhoneOTP
// are identical to the real path, so the custom token is minted for the
// phone's REAL uid.
//
// Never calls a real provider (axios.post is monkey-patched, the same
// technique as phase16_phone_otp_test.js).
//
// Run with: JAVA_HOME=/opt/homebrew/opt/openjdk@21 firebase emulators:exec
//             --only firestore,auth "node scripts/phaseSECP0_otp_test_mode_test.js"

process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";
process.env.TWOFACTOR_API_KEY = "secp0-fake-2factor-key-never-real";
process.env.OTP_ENCRYPTION_KEY = "secp0-fake-encryption-passphrase";

const axios = require("axios");
const providerCalls = [];
axios.post = async (url) => {
  providerCalls.push({ url });
  return { data: { Status: "Success", Details: "mocked" } };
};

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });
const db = admin.firestore();
const auth = admin.auth();

const { sendPhoneOTP } = require("../lib/common/sendPhoneOTP");
const { verifyPhoneOTP } = require("../lib/common/verifyPhoneOTP");
const { hashOtp } = require("../lib/common/sendPhoneOTP");

const HOUR_MS = 60 * 60 * 1000;
const CONFIG = db.collection("auth_test_mode").doc("config");

function makeRes() {
  const res = {
    statusCode: 200,
    body: null,
    set() { return res; },
    status(code) { res.statusCode = code; return res; },
    json(payload) { res.body = payload; return res; },
  };
  return res;
}

async function send(phone, extra = {}) {
  const res = makeRes();
  const before = providerCalls.length;
  await sendPhoneOTP({ method: "POST", body: { phone, ...extra } }, res);
  return { res, providerCalled: providerCalls.length > before };
}

async function setConfig(data) {
  if (data === null) {
    await CONFIG.delete();
  } else {
    await CONFIG.set(data);
  }
}

function ts(ms) {
  return admin.firestore.Timestamp.fromMillis(ms);
}

async function main() {
  const results = {};
  const check = (k, ok, detail) => {
    results[k] = ok ? "PASSED" : `FAILED — ${detail}`;
    console.log(`${k}: ${ok ? "PASSED" : "FAILED"} — ${detail}`);
  };

  console.log("=== PHASE SEC-P0 — phone OTP test mode ===");

  // Pre-existing account for the allow-listed number: proves the test path
  // signs into the SAME uid instead of creating a second account.
  const PHONE_EXISTING = "+919876511001";
  let existingUid;
  try {
    existingUid = (await auth.createUser({ phoneNumber: PHONE_EXISTING })).uid;
  } catch (e) {
    existingUid = (await auth.getUserByPhoneNumber(PHONE_EXISTING)).uid;
  }
  await db.collection("users").doc(existingUid).set({ role: "user", phone: PHONE_EXISTING });

  // s1 — no config doc: the real path, provider called, no code in response
  {
    await setConfig(null);
    const { res, providerCalled } = await send("+919876511002");
    check("s1_no_config_real_delivery",
      res.statusCode === 200 && providerCalled && res.body?.testOtp === undefined && res.body?.testMode === undefined,
      `status=${res.statusCode} providerCalled=${providerCalled} body=${JSON.stringify(res.body)}`);
  }

  // s2 — enabled, allow-listed, inside window: no delivery, code returned, hash stored
  let testOtp;
  {
    await setConfig({ enabled: true, allowlist: [PHONE_EXISTING], expiresAt: ts(Date.now() + HOUR_MS) });
    const { res, providerCalled } = await send("9876511001");
    testOtp = res.body?.testOtp;
    const doc = await db.collection("phone_otp_codes").doc(PHONE_EXISTING).get();
    const hashMatches = !!testOtp && doc.exists && doc.data().otpHash === hashOtp(testOtp);
    check("s2_allowlisted_gets_test_otp_no_delivery",
      res.statusCode === 200 && !providerCalled && res.body?.testMode === true &&
        /^\d{6}$/.test(testOtp || "") && hashMatches,
      `status=${res.statusCode} providerCalled=${providerCalled} testMode=${res.body?.testMode} otpShape=${/^\d{6}$/.test(testOtp || "")} hashMatches=${hashMatches}`);
  }

  // s3 — the returned code verifies through the UNCHANGED verifyPhoneOTP and
  //      mints a token for the pre-existing uid (no duplicate account)
  {
    const wrong = makeRes();
    await verifyPhoneOTP({ method: "POST", body: { phone: PHONE_EXISTING, otp: testOtp === "000000" ? "111111" : "000000" } }, wrong);
    check("s3a_wrong_code_still_rejected_in_test_mode",
      wrong.statusCode === 400 && !wrong.body?.token,
      `status=${wrong.statusCode} body=${JSON.stringify(wrong.body)}`);

    const res = makeRes();
    await verifyPhoneOTP({ method: "POST", body: { phone: PHONE_EXISTING, otp: testOtp } }, res);
    const listed = await auth.getUserByPhoneNumber(PHONE_EXISTING);
    check("s3b_test_code_authenticates_same_uid",
      res.statusCode === 200 && typeof res.body?.token === "string" && res.body?.userId === existingUid &&
        res.body?.isNewUser === false && listed.uid === existingUid,
      `status=${res.statusCode} userId=${res.body?.userId} expected=${existingUid} isNewUser=${res.body?.isNewUser}`);
  }

  // s4 — enabled but the number is NOT on the allowlist: real delivery
  {
    await setConfig({ enabled: true, allowlist: [PHONE_EXISTING], expiresAt: ts(Date.now() + HOUR_MS) });
    const { res, providerCalled } = await send("+919876511004");
    check("s4_unlisted_number_real_delivery",
      res.statusCode === 200 && providerCalled && res.body?.testOtp === undefined,
      `status=${res.statusCode} providerCalled=${providerCalled} body=${JSON.stringify(res.body)}`);
  }

  // s5 — window expired: real delivery
  {
    await setConfig({ enabled: true, allowlist: ["+919876511005"], expiresAt: ts(Date.now() - 1000) });
    const { res, providerCalled } = await send("+919876511005");
    check("s5_expired_window_real_delivery",
      providerCalled && res.body?.testOtp === undefined,
      `status=${res.statusCode} providerCalled=${providerCalled}`);
  }

  // s6 — window longer than the 7-day cap: fails closed to real delivery
  {
    await setConfig({ enabled: true, allowlist: ["+919876511006"], expiresAt: ts(Date.now() + 8 * 24 * HOUR_MS) });
    const { res, providerCalled } = await send("+919876511006");
    check("s6_window_over_cap_fails_closed",
      providerCalled && res.body?.testOtp === undefined,
      `status=${res.statusCode} providerCalled=${providerCalled}`);
  }

  // s7 — enabled as the STRING "true", not a boolean: fails closed
  {
    await setConfig({ enabled: "true", allowlist: ["+919876511007"], expiresAt: ts(Date.now() + HOUR_MS) });
    const { res, providerCalled } = await send("+919876511007");
    check("s7_non_boolean_enabled_fails_closed",
      providerCalled && res.body?.testOtp === undefined,
      `status=${res.statusCode} providerCalled=${providerCalled}`);
  }

  // s8 — no "allow everyone" switch exists: an allowAll flag with an empty
  //      allowlist does nothing
  {
    await setConfig({ enabled: true, allowAll: true, allowlist: [], expiresAt: ts(Date.now() + HOUR_MS) });
    const { res, providerCalled } = await send("+919876511008");
    check("s8_no_allow_all_switch",
      providerCalled && res.body?.testOtp === undefined,
      `status=${res.statusCode} providerCalled=${providerCalled}`);
  }

  // s9 — expiresAt missing: fails closed
  {
    await setConfig({ enabled: true, allowlist: ["+919876511009"] });
    const { res, providerCalled } = await send("+919876511009");
    check("s9_missing_expiry_fails_closed",
      providerCalled && res.body?.testOtp === undefined,
      `status=${res.statusCode} providerCalled=${providerCalled}`);
  }

  // s10 — every test-mode issue is logged, with a masked number and no code
  {
    const logs = await db.collection("auth_test_mode_log").get();
    const entries = logs.docs.map((d) => d.data());
    const ok = entries.length === 1 &&
      !JSON.stringify(entries).includes(testOtp) &&
      !JSON.stringify(entries).includes(PHONE_EXISTING) &&
      typeof entries[0].phoneMasked === "string";
    check("s10_test_mode_logged_masked_no_code",
      ok, `entries=${entries.length} sample=${JSON.stringify(entries[0] || {})}`);
  }

  // s11 — a test-mode send still counts toward the per-number daily cap and
  //       the resend cooldown (it is the real path minus delivery)
  {
    await setConfig({ enabled: true, allowlist: ["+919876511011"], expiresAt: ts(Date.now() + HOUR_MS) });
    const first = await send("+919876511011");
    const second = await send("+919876511011");
    const doc = await db.collection("phone_otp_codes").doc("+919876511011").get();
    check("s11_test_mode_respects_cooldown_and_counts",
      first.res.statusCode === 200 && second.res.statusCode === 429 && doc.data()?.sendCount === 1,
      `first=${first.res.statusCode} second=${second.res.statusCode} sendCount=${doc.data()?.sendCount}`);
  }

  // s12/s13 — SEC-P0b (OWNER_DECISION D-DEBUG-MOCK-OTP): debugMock:true
  // returns the code for ANY number without delivery (accepted risk); a
  // request without it (release builds) still gets real delivery.
  {
    await setConfig(null);
    const { res, providerCalled } = await send("+919876511012", { debugMock: true });
    check("s12_debug_mock_any_number_no_delivery",
      res.statusCode === 200 && !providerCalled && res.body?.testMode === true && /^\d{6}$/.test(res.body?.testOtp || ""),
      `status=${res.statusCode} providerCalled=${providerCalled}`);
  }
  {
    const { res, providerCalled } = await send("+919876511013", { debugMock: "true" });
    check("s13_non_boolean_debug_flag_is_real_delivery",
      providerCalled && res.body?.testOtp === undefined, `providerCalled=${providerCalled}`);
  }

  // s14 — without a provider, a release (non-debug) request still fails
  // closed; a debug-mock request still works (provider-free testing).
  {
    const saved = process.env.TWOFACTOR_API_KEY;
    delete process.env.TWOFACTOR_API_KEY;
    for (const key of Object.keys(require.cache)) {
      if (key.includes("/lib/common/sendPhoneOTP.js") || key.includes("/lib/common/smsProvider.js")) delete require.cache[key];
    }
    const fresh = require("../lib/common/sendPhoneOTP").sendPhoneOTP;
    const relRes = makeRes();
    await fresh({ method: "POST", body: { phone: "+919876511014" } }, relRes);
    const dbgRes = makeRes();
    await fresh({ method: "POST", body: { phone: "+919876511015", debugMock: true } }, dbgRes);
    process.env.TWOFACTOR_API_KEY = saved;
    check("s14_no_provider_release_503_debug_still_works",
      relRes.statusCode === 503 && dbgRes.statusCode === 200 && /^\d{6}$/.test(dbgRes.body?.testOtp || ""),
      `release=${relRes.statusCode} debug=${dbgRes.statusCode}`);
  }

  console.log("\n=== PHASE SEC-P0 (test mode) SUMMARY ===");
  const total = Object.keys(results).length;
  const passed = Object.values(results).filter((v) => v === "PASSED").length;
  for (const [k, v] of Object.entries(results)) console.log(`  ${v === "PASSED" ? "PASS" : "FAIL"}  ${k}`);
  console.log(`\n${passed}/${total} scenarios passed`);
  if (passed !== total) { console.error("PHASE SEC-P0 (test mode): FAILED"); process.exitCode = 1; }
  else console.log("PHASE SEC-P0 (test mode): ALL PASSED");
}

main().catch((e) => {
  console.error("PHASE SEC-P0 (test mode): harness error", e);
  process.exit(1);
});
