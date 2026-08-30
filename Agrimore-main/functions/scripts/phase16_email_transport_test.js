// ============================================================
//  Phase 16, Workstream 3 — Resend email transport test
// ============================================================
//
// Narrower than a full OTP-logic test on purpose: the CSPRNG/hash/cooldown/
// cap/no-enumeration proof already exists in phase15_email_otp_test.js
// (re-run unmodified as a regression, not duplicated here). This test
// covers only what Phase 16 actually changed — the transport.
//
// Never calls the real Resend API. axios.post is monkey-patched exactly
// like phase16_phone_otp_test.js's 2Factor mock.
//
// Run with: firebase emulators:exec --only firestore
//             "node scripts/phase16_email_transport_test.js"

process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";
process.env.RESEND_API_KEY = "phase16-fake-resend-key-never-real";
process.env.RESEND_FROM_EMAIL = "noreply@phase16-test.example";

const axios = require("axios");
const resendCalls = [];
let resendShouldFail = false;
axios.post = async (url, data, config) => {
  resendCalls.push({ url, data, config });
  if (resendShouldFail) {
    const err = new Error("mocked Resend failure");
    err.response = { status: 422, data: { message: "mocked validation error" } };
    throw err;
  }
  return { data: { id: "phase16-fake-email-id" } };
};

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });
const db = admin.firestore();

const { sendEmailOTP } = require("../lib/common/sendEmailOTP");

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

  console.log("=== PHASE 16, WORKSTREAM 3 — Resend email transport ===");

  // Scenario 1: Resend receives the correct payload
  {
    const email = "phase16-email-transport-test@example.com";
    resendCalls.length = 0;
    const res = makeRes();
    await sendEmailOTP({ method: "POST", body: { email } }, res);

    const call = resendCalls[0];
    const s1 =
      res.statusCode === 200 &&
      resendCalls.length === 1 &&
      call.url === "https://api.resend.com/emails" &&
      call.data.to === email &&
      call.data.from === "noreply@phase16-test.example" &&
      typeof call.data.subject === "string" &&
      call.data.subject.includes("Agrimore") &&
      // 2026-08-30: the body is now PLAIN TEXT ONLY (owner decision) — Resend
      // is sent `text`, never `html`. The previous assertion here was
      // `html.includes(email)`, which proved the themed template had rendered
      // with the right recipient; the plain-text body deliberately does not
      // repeat the address back, so that check is replaced rather than
      // dropped: assert a real text body went out AND that no html part was
      // sent at all, which is the property that actually matters now.
      typeof call.data.text === "string" &&
      call.data.text.includes("Agrimore") &&
      call.data.html === undefined &&
      call.config.headers.Authorization === "Bearer phase16-fake-resend-key-never-real";
    results.scenario1_resend_receives_correct_payload = s1;
    console.log(`scenario1_resend_receives_correct_payload: ${s1 ? "PASSED" : "FAILED"} — call=${JSON.stringify({ url: call?.url, to: call?.data?.to, from: call?.data?.from })}`);
    if (!s1) allPassed = false;
  }

  // Scenario 2: API key never appears in the response body or a log-visible field
  {
    const email = "phase16-email-transport-test2@example.com";
    const res = makeRes();
    await sendEmailOTP({ method: "POST", body: { email } }, res);
    const bodyStr = JSON.stringify(res.body);
    const s2 = !bodyStr.includes("phase16-fake-resend-key-never-real");
    results.scenario2_api_key_never_in_response = s2;
    console.log(`scenario2_api_key_never_in_response: ${s2 ? "PASSED" : "FAILED"} — body=${bodyStr}`);
    if (!s2) allPassed = false;
  }

  // Scenario 3: Resend failure surfaces as an error, no usable OTP left behind
  {
    const email = "phase16-email-transport-test3@example.com";
    resendShouldFail = true;
    const res = makeRes();
    await sendEmailOTP({ method: "POST", body: { email } }, res);
    resendShouldFail = false;

    const doc = await db.collection("otp_codes").doc(email).get();
    const s3 = res.statusCode === 502 && res.body?.success === false && !doc.exists;
    results.scenario3_resend_failure_no_leftover_otp = s3;
    console.log(`scenario3_resend_failure_no_leftover_otp: ${s3 ? "PASSED" : "FAILED"} — status=${res.statusCode} docExists=${doc.exists}`);
    if (!s3) allPassed = false;
  }

  console.log("");
  console.log(allPassed ? "ALL PASSED" : "SOME FAILED");
  console.log(JSON.stringify(results, null, 2));
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phase16 email transport test:", e);
  process.exit(1);
});
