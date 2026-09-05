// Phase FIX-12 — proves the per-IP OTP send limiter (finding N-21) on both
// sendPhoneOTP and sendEmailOTP, independent of the pre-existing per-
// number/per-address caps those two already had (proven by
// phase16/phase22/phase15, untouched by this phase).
//
// Never calls a real provider — axios.post (phone) is monkey-patched
// exactly like phase16's own suite; sendEmailViaResend's HTTP call (email)
// goes through the same axios boundary, mocked the same way phase15 does.
//
// Seeds the otp_ip_limits/{hashedIp} document directly at the cap boundary
// rather than replaying 50 real calls to reach it — same idiom phase27's
// seedProduct() uses for stock levels, faster and just as valid a test of
// the READ-and-compare logic, which is what this phase actually changed.
//
// Run with: firebase emulators:exec --only firestore
//             "node scripts/phase34_otp_abuse_test.js"
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";
delete process.env.TWOFACTOR_API_KEY;
delete process.env.OTP_ENCRYPTION_KEY;
process.env.RESEND_API_KEY = "phase34-fake-resend-key-never-a-real-credential";
process.env.RESEND_FROM_EMAIL = "noreply@phase34-test.example";

const crypto = require("crypto");
const axios = require("axios");
const sentEmails = [];
axios.post = async (url, data) => {
  if (typeof url === "string" && url.includes("2factor.in")) {
    return { data: { Status: "Success", Details: "mocked" } };
  }
  // Resend's send call
  sentEmails.push({ to: data.to, subject: data.subject });
  return { data: { id: "phase34-fake-email-id" } };
};

const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: "agrimore-66a4e" });
const db = admin.firestore();

// PHONE_OTP_ENABLED and PHONE_OTP_SMS_ENABLED are module-level consts
// evaluated once at require() time — force the SMS-enabled state for this
// suite (same as phase16's own PART B) before requiring the module.
process.env.TWOFACTOR_API_KEY = "phase34-fake-2factor-key-never-real";
process.env.PHONE_OTP_SMS_ENABLED = "true";
const { sendPhoneOTP } = require("../lib/common/sendPhoneOTP");
const { sendEmailOTP } = require("../lib/common/sendEmailOTP");

function makeRes() {
  const res = {
    statusCode: 200,
    body: null,
    set() { return res; },
    status(code) { res.statusCode = code; return res; },
    json(payload) { res.body = payload; return res; },
    send(payload) { res.body = payload; return res; },
  };
  return res;
}

function hashIp(ip) {
  return crypto.createHash("sha256").update(ip).digest("hex");
}

async function seedIpLimitAtCap(ip, count) {
  await db.collection("otp_ip_limits").doc(hashIp(ip)).set({ sendCount: count, sendWindowStart: Date.now() });
}

async function main() {
  const results = {};
  let allPassed = true;
  const record = (k, p, d) => { results[k] = p; console.log(`${k}: ${p ? "PASSED" : "FAILED"} — ${d}`); if (!p) allPassed = false; };

  console.log("=== PHASE FIX-12 — per-IP OTP abuse limiter (N-21) ===");

  // --- PHONE ---

  // 1 — positive control: an IP well under the cap can still send.
  // Environment-limited, same shape as phase16's own scenario 3: this repo
  // has no Auth emulator, so sendPhoneOTP's userExists lookup
  // (auth.getUserByPhoneNumber, informational only) fails with a
  // credentials error AFTER the OTP has already been generated, hashed,
  // stored and "delivered" to the mocked provider — i.e. after this
  // phase's own IP-limiter check has already passed. The assertion is "not
  // rejected by the IP limiter" (no 429 with the network-limit message),
  // not "got a clean 200" — a clean 200 is not achievable in this
  // environment for ANY successful send, with or without this phase's fix.
  {
    const res = makeRes();
    await sendPhoneOTP({ method: "POST", body: { phone: "9876500001" }, ip: "phase34-phone-ip-under" }, res);
    const blockedByIpLimiter = res.statusCode === 429 && /network/.test(res.body?.error || "");
    record("phone_ws1_under_cap_ip_can_still_send", !blockedByIpLimiter,
      `status=${res.statusCode} body=${JSON.stringify(res.body)} (environment-limited: 500/credentials is expected here, not a failure of this phase's fix)`);
  }

  // 2 — THE FINDING: an IP already at the cap is refused, even for a
  // BRAND-NEW phone number the per-number cap has never seen.
  {
    const ip = "phase34-phone-ip-at-cap";
    await seedIpLimitAtCap(ip, 50);
    const res = makeRes();
    await sendPhoneOTP({ method: "POST", body: { phone: "9876500002" }, ip }, res);
    record("phone_ws1_ip_at_cap_is_refused_for_a_brand_new_number", res.statusCode === 429,
      `status=${res.statusCode} body=${JSON.stringify(res.body)}`);
  }

  // 3 — a DIFFERENT ip is unaffected by #2's cap — proves isolation, not a
  // global lockout. Same environment-limited assertion shape as #1.
  {
    const res = makeRes();
    await sendPhoneOTP({ method: "POST", body: { phone: "9876500003" }, ip: "phase34-phone-ip-different" }, res);
    const blockedByIpLimiter = res.statusCode === 429 && /network/.test(res.body?.error || "");
    record("phone_ws1_a_different_ip_is_unaffected", !blockedByIpLimiter,
      `status=${res.statusCode} body=${JSON.stringify(res.body)} (environment-limited: 500/credentials is expected here)`);
  }

  // 4 — the missing-req.ip fallback (this codebase's own test suites call
  // these handlers with a bare {method, body}, no ip/headers at all) must
  // degrade to a shared bucket, not throw. Same environment-limited
  // assertion shape as #1/#3 — the point of this scenario is "did not
  // throw", not "got a 200".
  {
    const res = makeRes();
    let threw = false;
    try {
      await sendPhoneOTP({ method: "POST", body: { phone: "9876500004" } }, res);
    } catch (e) {
      threw = true;
    }
    record("phone_ws1_missing_req_ip_does_not_throw", !threw && res.statusCode !== 429,
      `threw=${threw} status=${res.statusCode}`);
  }

  // --- EMAIL ---

  // 5 — positive control.
  {
    const res = makeRes();
    await sendEmailOTP({ method: "POST", body: { email: "phase34-under@test.example" }, ip: "phase34-email-ip-under" }, res);
    record("email_ws1_under_cap_ip_can_still_send", res.statusCode === 200 && res.body?.success === true,
      `status=${res.statusCode} body=${JSON.stringify(res.body)}`);
  }

  // 6 — THE FINDING, email side.
  {
    const ip = "phase34-email-ip-at-cap";
    await seedIpLimitAtCap(ip, 50);
    const res = makeRes();
    await sendEmailOTP({ method: "POST", body: { email: "phase34-newaddr@test.example" }, ip }, res);
    record("email_ws1_ip_at_cap_is_refused_for_a_brand_new_address", res.statusCode === 429,
      `status=${res.statusCode} body=${JSON.stringify(res.body)}`);
  }

  // 7 — a different ip is unaffected.
  {
    const res = makeRes();
    await sendEmailOTP({ method: "POST", body: { email: "phase34-diff@test.example" }, ip: "phase34-email-ip-different" }, res);
    record("email_ws1_a_different_ip_is_unaffected", res.statusCode === 200 && res.body?.success === true,
      `status=${res.statusCode} body=${JSON.stringify(res.body)}`);
  }

  // 8 — missing req.ip does not throw, email side.
  {
    const res = makeRes();
    let threw = false;
    try {
      await sendEmailOTP({ method: "POST", body: { email: "phase34-noip@test.example" } }, res);
    } catch (e) {
      threw = true;
    }
    record("email_ws1_missing_req_ip_does_not_throw", !threw && res.statusCode === 200,
      `threw=${threw} status=${res.statusCode}`);
  }

  console.log("\n=== SUMMARY ===");
  const total = Object.keys(results).length;
  const passed = Object.values(results).filter(Boolean).length;
  for (const [k, v] of Object.entries(results)) console.log(`  ${v ? "PASS" : "FAIL"}  ${k}`);
  console.log(`\n${passed}/${total} scenarios passed`);
  if (!allPassed) { console.error("PHASE 34: FAILED"); process.exit(1); }
  console.log("PHASE 34: ALL PASSED");
  process.exit(0);
}

main().catch((e) => { console.error("PHASE 34: harness error", e); process.exit(1); });
