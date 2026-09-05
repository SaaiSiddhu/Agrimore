// Phase 15, Workstream 1: proves sendEmailOTP.ts/verifyEmailOTP.ts's
// hardening — CSPRNG + hashed storage, resend cooldown, and no
// account-existence signal — against a real Firestore emulator and the
// real compiled functions.
//
// Phase 16, Workstream 3 fixture update: the transport is now Resend
// (axios), not nodemailer/SMTP — sendEmailOTP.ts no longer imports
// nodemailer at all, so the original nodemailer.createTransport patch
// silently captured nothing (sentEmails stayed empty, crashing
// extractOtpFromLastSentEmail()). This is a pure mock-target swap: same
// in-process-handler-invocation architecture and reasoning as before
// (Functions emulator runs in a separate process a same-process patch
// can't reach), same captured-email shape ({to, subject, html}), same
// downstream helpers — no assertion below changed.
//
// Unlike phase14_phone_otp_test.js (which hits the running Functions
// emulator's HTTP server directly, fine there because phone OTP's success
// path is fully self-contained), sendEmailOTP's success path needs a
// working delivery transport. Both onRequest handlers are required
// directly and invoked in-process with minimal mock req/res objects (a
// standard pattern for testing Express-style handlers without a live
// server) — this makes axios.post patchable exactly like
// phase9_wallet_topup_test.js patches axios.get, while Firestore calls
// still hit the real emulator (a separate service on port 8080, unaffected
// by which process calls it).
// Run with: node scripts/phase15_email_otp_test.js
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";
process.env.RESEND_API_KEY = "phase15-fake-resend-key-never-a-real-credential";
process.env.RESEND_FROM_EMAIL = "noreply@phase15-test.example";

const axios = require("axios");
const sentEmails = [];
axios.post = async (url, data) => {
  // `text` is the live field since the body became plain text (2026-08-30);
  // `html` is captured too so this stays honest if an html part ever returns.
  sentEmails.push({ to: data.to, subject: data.subject, text: data.text, html: data.html });
  return { data: { id: "phase15-fake-email-id" } };
};

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });

const { sendEmailOTP } = require("../lib/common/sendEmailOTP");
const { verifyEmailOTP } = require("../lib/common/verifyEmailOTP");

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
    send(payload) {
      res.body = payload;
      return res;
    },
  };
  return res;
}

async function callSend(body) {
  const res = makeRes();
  await sendEmailOTP({ method: "POST", body }, res);
  return { status: res.statusCode, json: res.body };
}

async function callVerify(body) {
  const res = makeRes();
  await verifyEmailOTP({ method: "POST", body }, res);
  return { status: res.statusCode, json: res.body };
}

function extractOtpFromLastSentEmail() {
  const last = sentEmails[sentEmails.length - 1];
  const match = /^(\d{6})/.exec(last.subject);
  if (!match) throw new Error(`could not extract OTP from captured email subject: "${last.subject}"`);
  return match[1];
}

async function main() {
  const db = admin.firestore();
  let allPassed = true;
  const results = {};
  const email = "phase15-email-otp-test@example.com";

  console.log("=== PHASE 15, WORKSTREAM 1 — email OTP hardening ===");

  // Scenario 1: first send succeeds, and the response contains no
  // account-existence signal at all.
  {
    const r = await callSend({ email });
    console.log("Scenario 1 raw:", JSON.stringify(r, null, 2));
    let s;
    try {
      if (r.status !== 200 || r.json?.success !== true) {
        throw new Error(`expected a successful send, got status=${r.status} body=${JSON.stringify(r.json)}`);
      }
      if (Object.prototype.hasOwnProperty.call(r.json, "userExists")) {
        throw new Error(`response body still contains a userExists field: ${JSON.stringify(r.json)} — THE ENUMERATION ORACLE IS STILL OPEN`);
      }
      if (sentEmails.length !== 1) throw new Error(`expected exactly 1 captured email, got ${sentEmails.length}`);
      s = `PASSED — send succeeded (status=${r.status}) with no userExists field in the response. body=${JSON.stringify(r.json)}`;
    } catch (e) {
      s = `FAILED — ${e.message}`;
      allPassed = false;
    }
    results.scenario1_send_succeeds_no_user_exists_signal = s;
    console.log("Scenario 1:", s);
  }

  // Scenario 2 — THE hashed-storage proof: the stored document holds a
  // hash, never the plaintext code.
  {
    let s;
    try {
      const doc = await db.collection("otp_codes").doc(email).get();
      if (!doc.exists) throw new Error("expected an otp_codes document to exist after a successful send");
      const data = doc.data();
      if (typeof data.otp === "string") {
        throw new Error(`a plaintext 'otp' field is still being stored: ${JSON.stringify(data)} — THE PLAINTEXT-STORAGE BUG IS STILL OPEN`);
      }
      if (typeof data.otpHash !== "string" || data.otpHash.length !== 64) {
        throw new Error(`expected a 64-char SHA-256 hex otpHash field, got: ${JSON.stringify(data.otpHash)}`);
      }
      const realOtp = extractOtpFromLastSentEmail();
      const crypto = require("crypto");
      const expectedHash = crypto.createHash("sha256").update(realOtp).digest("hex");
      if (data.otpHash !== expectedHash) {
        throw new Error("stored otpHash does not match SHA-256(actual generated OTP) — hashing mismatch");
      }
      s = `PASSED — stored document holds only otpHash (${data.otpHash.slice(0, 8)}...), no plaintext otp field, and it correctly hashes the real generated code`;
    } catch (e) {
      s = `FAILED — ${e.message}`;
      allPassed = false;
    }
    results.scenario2_stored_document_holds_hash_not_plaintext = s;
    console.log("Scenario 2:", s);
  }

  // Scenario 3 — THE cooldown proof: a second sendEmailOTP for the same
  // address, immediately after the first, must return 429.
  {
    const r = await callSend({ email });
    console.log("Scenario 3 raw:", JSON.stringify(r, null, 2));
    let s;
    if (r.status !== 429) {
      s = `FAILED — expected HTTP 429 for a resend inside the cooldown, got ${r.status}: ${JSON.stringify(r.json)}`;
      allPassed = false;
    } else if (r.json?.success !== false || typeof r.json?.retryAfterMs !== "number") {
      s = `FAILED — got 429 but with an unexpected body shape: ${JSON.stringify(r.json)}`;
      allPassed = false;
    } else {
      s = `PASSED — a resend inside the 30s cooldown returned 429 with retryAfterMs=${r.json.retryAfterMs}`;
    }
    results.scenario3_resend_inside_cooldown_returns_429 = s;
    console.log("Scenario 3:", s);
  }

  // Scenario 4: a wrong OTP is rejected.
  {
    const r = await callVerify({ email, otp: "000000" });
    console.log("Scenario 4 raw:", JSON.stringify(r, null, 2));
    let s;
    if (r.status !== 400 || r.json?.success !== false) {
      s = `FAILED — expected a 400 rejection for a wrong OTP, got status=${r.status} body=${JSON.stringify(r.json)}`;
      allPassed = false;
    } else {
      s = `PASSED — a wrong OTP was rejected. body=${JSON.stringify(r.json)}`;
    }
    results.scenario4_wrong_otp_rejected = s;
    console.log("Scenario 4:", s);
  }

  // Scenario 5 — the correct OTP passes the hash comparison.
  //
  // FIX-5C, WS1. This used to check the OTP document's `verified` flag
  // FIRST and treat its absence as failure — reasonable when this repo's
  // firebase.json had no Auth emulator and the flow could never reach
  // admin.auth().createCustomToken(). It has one now, so the flow completes
  // end-to-end, and verifyEmailOTP.ts:159 DELETES the otp_codes document on
  // exactly that success path, right before returning. The unconditional
  // flag check ran before this scenario could ever see that: it failed with
  // doc=undefined on the environment getting BETTER, not worse.
  //
  // The full end-to-end response is itself the stronger proof anyway —
  // verifyEmailOTP.ts cannot reach admin.auth() at all without passing the
  // hash comparison first — so it is checked FIRST now, and the document's
  // `verified` flag is only consulted as the fallback for an environment
  // that still can't mint a token (no Auth emulator, no service-account
  // credential). Same two accepted outcomes as before; only which is
  // checked first, and therefore which is possible to reach, changed.
  {
    const realOtp = extractOtpFromLastSentEmail();
    const r = await callVerify({ email, otp: realOtp });
    console.log("Scenario 5 raw:", JSON.stringify(r, null, 2));
    let s;
    try {
      if (r.status === 200 && r.json?.success === true && r.json?.token) {
        s = `PASSED (full end-to-end) — the correct OTP authenticated and minted a real token, and the OTP document was cleaned up as designed (verifyEmailOTP.ts:159). userId=${r.json.userId}`;
      } else {
        const otpDoc = await db.collection("otp_codes").doc(email).get();
        const verifiedFlagSet = otpDoc.exists && otpDoc.data()?.verified === true;
        const failedOnlyAtAuthStep =
          r.status === 500 && typeof r.json?.error === "string" && r.json.error.includes("credential");
        if (verifiedFlagSet && failedOnlyAtAuthStep) {
          s =
            "PASSED (partial — environment-limited) — the hash comparison correctly accepted the real OTP " +
            "(otp_codes verified flag set to true, BEFORE any admin.auth() call), proving Workstream 1's actual " +
            "change works. The subsequent admin.auth().createCustomToken() step failed only because no Auth " +
            "emulator is configured in this repo's firebase.json and no real service account credential is " +
            "available/appropriate here — that is a pre-existing, unrelated environment gap, not a regression " +
            "from this phase. Full token-mint round-trip is NOT verified in this environment.";
        } else {
          throw new Error(
            `unexpected failure shape: status=${r.status} body=${JSON.stringify(r.json)} otpDoc=${JSON.stringify(otpDoc.data())}`
          );
        }
      }
    } catch (e) {
      s = `FAILED — ${e.message}`;
      allPassed = false;
    }
    results.scenario5_correct_otp_passes_hash_check = s;
    console.log("Scenario 5:", s);
  }

  console.log("=== PHASE 15 WORKSTREAM 1 SUMMARY ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phase15 email OTP test:", e);
  process.exit(1);
});
