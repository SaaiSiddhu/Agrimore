// ============================================================
//  Phase 22 — configurable phone-OTP channel test
// ============================================================
//
// Never calls a real provider. Mirrors phase16_phone_otp_test.js's
// structure exactly: axios.post is monkey-patched to record calls and
// return a canned response; PHONE_OTP_SMS_ENABLED and PHONE_OTP_ENABLED
// are module-level consts evaluated once at require() time, so switching
// either between scenarios means deleting the relevant require.cache
// entries and re-requiring.
//
// ENVIRONMENT LIMITATION (same as phase16_phone_otp_test.js's scenario 3):
// this environment runs only the Firestore emulator, no Auth emulator, no
// real service-account credential. sendPhoneOTP.ts's final step — an
// auth.getUserByPhoneNumber() lookup purely to populate the informational
// `userExists` field — can itself fail here and turn the final HTTP
// response into a 500 whose body has no `channel` field at all, even
// though the actual channel-resolution/cap/delivery logic under test
// already completed correctly. So channel assertions below check the
// Firestore-stored `channel` field (written unconditionally, before that
// lookup) and the mocked provider call's URL shape, not res.body.channel.
//
// Run with: firebase emulators:exec --only firestore
//             "node scripts/phase22_channel_config_test.js"

process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";
process.env.TWOFACTOR_API_KEY = "phase22-fake-2factor-key-never-real";
process.env.OTP_ENCRYPTION_KEY = "phase22-fake-encryption-passphrase";

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

// PHONE_OTP_SMS_ENABLED is read at require() time, same as PHONE_OTP_ENABLED
// — must reload after every process.env.PHONE_OTP_SMS_ENABLED change.
function reloadSendPhoneOTP() {
  for (const key of Object.keys(require.cache)) {
    if (
      key.includes("/lib/common/sendPhoneOTP.js") ||
      key.includes("/lib/common/smsProvider.js")
    ) {
      delete require.cache[key];
    }
  }
  return require("../lib/common/sendPhoneOTP").sendPhoneOTP;
}

function extractOtpFromUrl(url) {
  // .../SMS/<phone>/<otp> or .../VOICE/<phone>/<otp>
  return url.split("/").pop();
}

function callTypeFromUrl(url) {
  if (url.includes("/SMS/")) return "SMS";
  if (url.includes("/VOICE/")) return "VOICE";
  return "UNKNOWN";
}

async function seedPhoneDoc(phone, overrides) {
  await db.collection("phone_otp_codes").doc(phone).set({
    otpHash: "seed",
    otpEncrypted: null,
    phone,
    expiresAt: Date.now() + 5 * 60 * 1000,
    createdAt: Date.now() - 31000, // clear of the 30s resend cooldown
    verified: false,
    attempts: 0,
    channel: "voice",
    sendCount: 0,
    sendWindowStart: Date.now(),
    voiceSendCount: 0,
    voiceSendWindowStart: Date.now(),
    ...overrides,
  });
}

async function main() {
  let allPassed = true;
  const results = {};
  function record(name, pass, detail) {
    results[name] = pass;
    console.log(`${name}: ${pass ? "PASSED" : "FAILED"} — ${detail}`);
    if (!pass) allPassed = false;
  }

  console.log("=== PHASE 22 — configurable phone-OTP channel ===");

  // ---------------------------------------------------------------
  // Scenario 1 — flag off, requested "sms" -> delivered by voice, and the
  // stored/effective channel says "voice" (never claims what it didn't do)
  // ---------------------------------------------------------------
  {
    delete process.env.PHONE_OTP_SMS_ENABLED;
    const sendPhoneOTP = reloadSendPhoneOTP();
    const phone = "+919876510001";
    providerCalls.length = 0;
    const res = makeRes();
    await sendPhoneOTP({ method: "POST", body: { phone, channel: "sms" } }, res);
    const onlyCall = providerCalls.length === 1 ? providerCalls[0] : null;
    const doc = await db.collection("phone_otp_codes").doc(phone).get();
    const pass = !!onlyCall && callTypeFromUrl(onlyCall.url) === "VOICE" && doc.data()?.channel === "voice";
    record(
      "scenario1_flag_off_sms_request_delivers_voice",
      pass,
      `providerCalls=${providerCalls.map((c) => callTypeFromUrl(c.url)).join(",")} firestoreChannel=${doc.data()?.channel}`
    );
  }

  // ---------------------------------------------------------------
  // Scenario 2 — flag off, explicit "voice" request -> unchanged: voice
  // call either way
  // ---------------------------------------------------------------
  {
    const sendPhoneOTP = reloadSendPhoneOTP(); // flag still unset from scenario 1
    const phone = "+919876510002";
    providerCalls.length = 0;
    const res = makeRes();
    await sendPhoneOTP({ method: "POST", body: { phone, channel: "voice" } }, res);
    const onlyCall = providerCalls.length === 1 ? providerCalls[0] : null;
    const doc = await db.collection("phone_otp_codes").doc(phone).get();
    const pass = !!onlyCall && callTypeFromUrl(onlyCall.url) === "VOICE" && doc.data()?.channel === "voice";
    record(
      "scenario2_flag_off_voice_request_unchanged",
      pass,
      `providerCalls=${providerCalls.map((c) => callTypeFromUrl(c.url)).join(",")} firestoreChannel=${doc.data()?.channel}`
    );
  }

  // ---------------------------------------------------------------
  // Scenario 3 — flag on, requested "sms" -> delivered by SMS
  // ---------------------------------------------------------------
  {
    process.env.PHONE_OTP_SMS_ENABLED = "true";
    const sendPhoneOTP = reloadSendPhoneOTP();
    const phone = "+919876510003";
    providerCalls.length = 0;
    const res = makeRes();
    await sendPhoneOTP({ method: "POST", body: { phone, channel: "sms" } }, res);
    const onlyCall = providerCalls.length === 1 ? providerCalls[0] : null;
    const doc = await db.collection("phone_otp_codes").doc(phone).get();
    const pass = !!onlyCall && callTypeFromUrl(onlyCall.url) === "SMS" && doc.data()?.channel === "sms";
    record(
      "scenario3_flag_on_sms_request_delivers_sms",
      pass,
      `providerCalls=${providerCalls.map((c) => callTypeFromUrl(c.url)).join(",")} firestoreChannel=${doc.data()?.channel}`
    );
  }

  // ---------------------------------------------------------------
  // Scenario 4 — flag off: a number can receive MORE than 3 voice
  // deliveries in a day (the old lockout is gone), blocked only at 10
  // (the combined cap)
  // ---------------------------------------------------------------
  {
    delete process.env.PHONE_OTP_SMS_ENABLED;
    const sendPhoneOTP = reloadSendPhoneOTP();
    const phone = "+919876510004";

    // Seeded at 3 prior sends (== the OLD voice cap) — the next request is
    // the "4th voice delivery" the acceptance criteria describes, and must
    // NOT be blocked now that the voice cap is inert while SMS is off.
    await seedPhoneDoc(phone, { sendCount: 3, voiceSendCount: 3 });
    const fourthRes = makeRes();
    await sendPhoneOTP({ method: "POST", body: { phone, channel: "sms" } }, fourthRes);
    // Not asserting exactly 200: the userExists-lookup environment
    // limitation (see header) can turn a fully successful send into a 500
    // here. Only 429 (rate-limited) is the failure this scenario checks for.
    const fourthPass = fourthRes.statusCode !== 429;
    record(
      "scenario4a_flag_off_fourth_voice_delivery_succeeds",
      fourthPass,
      `status=${fourthRes.statusCode} body=${JSON.stringify(fourthRes.body)}`
    );

    // Now seeded at the combined cap (10) — THAT is what blocks it.
    await seedPhoneDoc(phone, { sendCount: 10, voiceSendCount: 7 });
    const tenthRes = makeRes();
    await sendPhoneOTP({ method: "POST", body: { phone, channel: "sms" } }, tenthRes);
    const tenthPass = tenthRes.statusCode === 429;
    record(
      "scenario4b_flag_off_tenth_delivery_429s_on_combined_cap",
      tenthPass,
      `status=${tenthRes.statusCode} body=${JSON.stringify(tenthRes.body)}`
    );
  }

  // ---------------------------------------------------------------
  // Scenario 5 — flag on: the 4th voice delivery in a day 429s (the
  // stricter fallback cap is back)
  // ---------------------------------------------------------------
  {
    process.env.PHONE_OTP_SMS_ENABLED = "true";
    const sendPhoneOTP = reloadSendPhoneOTP();
    const phone = "+919876510005";
    await seedPhoneDoc(phone, { sendCount: 3, voiceSendCount: 3 });
    const res = makeRes();
    await sendPhoneOTP({ method: "POST", body: { phone, channel: "voice" } }, res);
    const pass = res.statusCode === 429;
    record("scenario5_flag_on_fourth_voice_delivery_429s", pass, `status=${res.statusCode} body=${JSON.stringify(res.body)}`);
  }

  // ---------------------------------------------------------------
  // Scenario 6 — every non-"true" value (and unset) is treated as
  // disabled: "false", "", "1", "yes", unset
  // ---------------------------------------------------------------
  {
    const cases = [
      { label: "false", value: "false" },
      { label: "empty string", value: "" },
      { label: "1", value: "1" },
      { label: "yes", value: "yes" },
      { label: "unset", value: undefined },
    ];
    let allDisabled = true;
    const detail = [];
    for (let i = 0; i < cases.length; i++) {
      const { label, value } = cases[i];
      if (value === undefined) {
        delete process.env.PHONE_OTP_SMS_ENABLED;
      } else {
        process.env.PHONE_OTP_SMS_ENABLED = value;
      }
      const sendPhoneOTP = reloadSendPhoneOTP();
      const phone = `+919876520${(10 + i).toString().padStart(3, "0")}`;
      providerCalls.length = 0;
      const res = makeRes();
      await sendPhoneOTP({ method: "POST", body: { phone, channel: "sms" } }, res);
      const doc = await db.collection("phone_otp_codes").doc(phone).get();
      const treatedAsDisabled =
        providerCalls.length === 1 && callTypeFromUrl(providerCalls[0].url) === "VOICE" && doc.data()?.channel === "voice";
      detail.push(`${label}=>${doc.data()?.channel}`);
      if (!treatedAsDisabled) allDisabled = false;
    }
    record("scenario6_all_non_true_values_treated_as_disabled", allDisabled, detail.join(", "));
  }

  // ---------------------------------------------------------------
  // Scenario 7 — provider failure with the flag off: still 502, still no
  // usable OTP document left behind, still logged to otp_delivery_failures
  // ---------------------------------------------------------------
  {
    delete process.env.PHONE_OTP_SMS_ENABLED;
    const sendPhoneOTP = reloadSendPhoneOTP();
    const phone = "+919876510007";
    providerShouldFail = true;
    const res = makeRes();
    await sendPhoneOTP({ method: "POST", body: { phone, channel: "sms" } }, res);
    providerShouldFail = false;
    const doc = await db.collection("phone_otp_codes").doc(phone).get();
    const failureLog = await db.collection("otp_delivery_failures").where("phone", "==", phone).get();
    const pass = res.statusCode === 502 && !doc.exists && !failureLog.empty;
    record(
      "scenario7_flag_off_provider_failure_502_no_leftover_doc_logged",
      pass,
      `status=${res.statusCode} docExists=${doc.exists} failureLogged=${!failureLog.empty}`
    );
  }

  // ---------------------------------------------------------------
  // Scenario 8 — TRAP C proof: with the flag off, an ORDINARY resend
  // (nominally "sms") generates a FRESH code every time, exactly like it
  // always has — the code-reuse gate is keyed on the REQUESTED channel,
  // not the effective one. An explicit "call me instead" (channel:"voice")
  // request still reuses the live session's code, unaffected by the flag.
  // ---------------------------------------------------------------
  {
    delete process.env.PHONE_OTP_SMS_ENABLED;
    const sendPhoneOTP = reloadSendPhoneOTP();
    const phone = "+919876510008";
    providerCalls.length = 0;

    const first = makeRes();
    await sendPhoneOTP({ method: "POST", body: { phone, channel: "sms" } }, first);
    const firstOtp = extractOtpFromUrl(providerCalls[0].url);

    // Bypass the 30s resend cooldown for this test only — same technique
    // phase16_phone_otp_test.js's scenario 4 uses.
    await db.collection("phone_otp_codes").doc(phone).update({ createdAt: Date.now() - 31000 });

    const second = makeRes();
    await sendPhoneOTP({ method: "POST", body: { phone, channel: "sms" } }, second); // ordinary resend
    const secondOtp = extractOtpFromUrl(providerCalls[1].url);
    const freshOnOrdinaryResend = secondOtp !== firstOtp;

    await db.collection("phone_otp_codes").doc(phone).update({ createdAt: Date.now() - 31000 });

    const third = makeRes();
    await sendPhoneOTP({ method: "POST", body: { phone, channel: "voice" } }, third); // explicit "call me instead"
    const thirdOtp = extractOtpFromUrl(providerCalls[2].url);
    const reuseOnExplicitVoice = thirdOtp === secondOtp;

    const pass = freshOnOrdinaryResend && reuseOnExplicitVoice;
    record(
      "scenario8_trapC_ordinary_resend_fresh_explicit_voice_reuses",
      pass,
      `firstOtp=${firstOtp} secondOtp(resend)=${secondOtp} thirdOtp(explicit voice)=${thirdOtp} freshOnOrdinaryResend=${freshOnOrdinaryResend} reuseOnExplicitVoice=${reuseOnExplicitVoice}`
    );
  }

  console.log("");
  console.log(allPassed ? "ALL PASSED" : "SOME FAILED");
  console.log(JSON.stringify(results, null, 2));
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phase22 channel config test:", e);
  process.exit(1);
});
