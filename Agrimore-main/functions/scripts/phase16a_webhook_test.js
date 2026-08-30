// Phase 16A — razorpayOnboardingWebhook signature-handling test. Invokes
// the REAL compiled handler directly — for onRequest() (unlike onCall(),
// which attaches a separate `.run`), the exported constant IS ITSELF the
// callable (req, res) handler; see node_modules/firebase-functions/lib/v2/
// providers/https.js's onRequest(), which returns `handler` directly
// (wrapped only in wrapTraceContext/withInit/withErrorHandler — no Express
// app, no CloudEvent decoding) — with hand-built mock req/res objects.
// This bypasses only the top-of-stack cors middleware (opts.cors:false
// means none is installed anyway), while exercising the actual handler
// body: signature verification, event/purpose filtering, and idempotency.
// No real Razorpay network call is ever made (every scenario below either
// fails before that point or pre-seeds verified_payments so the live-API
// branch is skipped).
//
// process.env.RAZORPAY_WEBHOOK_SECRET is read at MODULE LOAD TIME, so
// switching it between scenarios requires evicting the module from
// require.cache and re-requiring it — loadWebhookModule() below does
// exactly that.
//
// Requires `npm run build` to have been run first and the Firestore
// emulator running on 127.0.0.1:8080 (scenario 33 seeds real documents).
// Run with: node scripts/phase16a_webhook_test.js
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const crypto = require("crypto");
const admin = require("firebase-admin");
if (admin.apps.length === 0) {
  admin.initializeApp({ projectId: "agrimore-66a4e" });
}
const db = admin.firestore();

const WEBHOOK_MODULE_PATH = require.resolve("../lib/employee/razorpayOnboardingWebhook");
const TEST_SECRET = "phase16a_test_webhook_secret_do_not_use_in_prod";

function loadWebhookModule() {
  delete require.cache[WEBHOOK_MODULE_PATH];
  return require(WEBHOOK_MODULE_PATH).razorpayOnboardingWebhook;
}

// onRequest() wraps every handler with the `cors` npm middleware whenever
// the `cors` KEY is present in its options at all — including
// `cors: false` (see node_modules/firebase-functions/lib/v2/providers/
// https.js's onRequest(): `"cors" in opts` is true regardless of the
// value). That middleware still touches a few plain-Node-response-style
// methods (res.setHeader/res.end, req.headers) even though `origin: false`
// means it never sets a permissive Access-Control-Allow-Origin header —
// so the mock below needs to be a minimal EventEmitter with those methods,
// not just {status, send}.
const { EventEmitter } = require("events");

function makeMockRes() {
  const res = new EventEmitter();
  res.statusCode = null;
  res.body = null;
  res.status = function (code) {
    this.statusCode = code;
    return this;
  };
  res.send = function (text) {
    this.body = text;
    // Mirrors a real http.ServerResponse: .send()/.end() completing is
    // what fires 'finish' — the onRequest cors wrapper's Promise only
    // resolves once this fires (`res.on("finish", resolve)`).
    this.emit("finish");
    return this;
  };
  res.setHeader = function () {};
  res.getHeader = function () {
    return undefined;
  };
  res.removeHeader = function () {};
  res.end = function (data) {
    if (data !== undefined) this.body = data;
    this.emit("finish");
    return this;
  };
  return res;
}

function makeMockReq(bodyString, headers) {
  const lowerHeaders = {};
  for (const [k, v] of Object.entries(headers)) lowerHeaders[k.toLowerCase()] = v;
  return {
    method: "POST",
    rawBody: Buffer.from(bodyString, "utf8"),
    // No real Origin header — this is a server-to-server webhook, never
    // browser-called, so `headers.origin` is genuinely always absent.
    headers: lowerHeaders,
    get(name) {
      return lowerHeaders[name.toLowerCase()];
    },
  };
}

function sign(secret, bodyString) {
  return crypto.createHmac("sha256", secret).update(bodyString).digest("hex");
}

function paymentPayload(paymentId, orderId, uid) {
  return JSON.stringify({
    event: "payment.captured",
    payload: {
      payment: {
        entity: {
          id: paymentId,
          order_id: orderId,
          status: "captured",
          notes: { purpose: "associate_onboarding", userId: uid },
        },
      },
    },
  });
}

const GOOD_CONFIG_COPY = {
  headline: "h",
  feeLabel: "f",
  supportingStatement: "s",
  whyTheFeeExists: { title: "t", body: ["a"] },
  benefitGroups: [{ key: "g", title: "g", items: ["i"] }],
  earningsExplainer: { title: "t", body: ["a"], flowSteps: ["a"], variabilityFactors: ["a"] },
  journeySteps: [{ step: 1, title: "t", body: "b" }],
  summaryCard: { title: "t", feeLine: "f", includes: ["i"], ctaLabel: "c", ctaSubtext: "s" },
  supportContact: { title: "t", body: "b", email: "e@example.com", phone: "" },
};

async function main() {
  const results = {};

  // ============================================
  // 30: Wrong signature rejected
  // ============================================
  {
    process.env.RAZORPAY_WEBHOOK_SECRET = TEST_SECRET;
    const webhook = loadWebhookModule();
    const body = paymentPayload("pay_w30", "order_w30", "uid_w30");
    const req = makeMockReq(body, { "x-razorpay-signature": "0".repeat(64) });
    const res = makeMockRes();
    await webhook(req, res);
    const ok = res.statusCode === 400;
    results["30_wrong_signature_rejected"] = ok
      ? "PASSED — a wrong X-Razorpay-Signature is rejected with 400"
      : `FAILED — status=${res.statusCode} body=${res.body}`;
  }

  // ============================================
  // 31: Missing signature rejected
  // ============================================
  {
    process.env.RAZORPAY_WEBHOOK_SECRET = TEST_SECRET;
    const webhook = loadWebhookModule();
    const body = paymentPayload("pay_w31", "order_w31", "uid_w31");
    const req = makeMockReq(body, {});
    const res = makeMockRes();
    await webhook(req, res);
    const ok = res.statusCode === 400;
    results["31_missing_signature_rejected"] = ok
      ? "PASSED — a missing X-Razorpay-Signature header is rejected with 400"
      : `FAILED — status=${res.statusCode} body=${res.body}`;
  }

  // ============================================
  // 32: Unset RAZORPAY_WEBHOOK_SECRET fails closed
  // ============================================
  {
    delete process.env.RAZORPAY_WEBHOOK_SECRET;
    const webhook = loadWebhookModule();
    const body = paymentPayload("pay_w32", "order_w32", "uid_w32");
    // The signature value here is irrelevant — an unset secret must
    // refuse EVERY delivery before it ever reaches signature comparison.
    const req = makeMockReq(body, { "x-razorpay-signature": sign("whatever", body) });
    const res = makeMockRes();
    await webhook(req, res);
    const ok = res.statusCode === 500;
    results["32_unset_secret_fails_closed"] = ok
      ? "PASSED — an unset RAZORPAY_WEBHOOK_SECRET rejects ALL deliveries with 500 — never falls open"
      : `FAILED — status=${res.statusCode} body=${res.body}`;
  }

  // ============================================
  // 33: Correct signature, duplicate event id -> no-op
  // ============================================
  {
    process.env.RAZORPAY_WEBHOOK_SECRET = TEST_SECRET;
    const webhook = loadWebhookModule();

    const uid = "p16a-webhook-33";
    const paymentId = "pay_w33";
    const orderId = "order_w33";

    await db.collection("settings").doc("associate_onboarding").set({
      isEnabled: true,
      feeAmount: 500,
      currency: "INR",
      version: 1,
      copy: GOOD_CONFIG_COPY,
    });
    await db.collection("employees").doc(uid).set({
      userId: uid,
      name: "Webhook Test",
      email: `${uid}@p16a-test.example`,
      phone: "9999999999",
      employeeCode: "WEBHK1",
      status: "pending",
      commissionRate: 0,
      createdBy: "self",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    // Pre-seeded so the webhook's "verified_payments missing" branch
    // (which would otherwise call the LIVE Razorpay API) is never
    // exercised in this test.
    await db.collection("verified_payments").doc(paymentId).set({
      orderId,
      paymentId,
      userId: uid,
      signatureVerified: true,
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      method: "upi",
      amount: 500,
      currency: "INR",
      status: "captured",
    });

    const body = paymentPayload(paymentId, orderId, uid);
    const sig = sign(TEST_SECRET, body);

    const req1 = makeMockReq(body, { "x-razorpay-signature": sig, "x-razorpay-event-id": "evt_w33_fixed" });
    const res1 = makeMockRes();
    await webhook(req1, res1);
    const employeeAfterFirst = await db.collection("employees").doc(uid).get();

    const req2 = makeMockReq(body, { "x-razorpay-signature": sig, "x-razorpay-event-id": "evt_w33_fixed" });
    const res2 = makeMockRes();
    await webhook(req2, res2);

    const eventsSnap = await db.collection("onboarding_events").where("uid", "==", uid).get();
    const activationEvents = eventsSnap.docs.filter((d) => d.data().type === "activation");

    const ok =
      res1.statusCode === 200 &&
      employeeAfterFirst.data().onboardingPaid === true &&
      res2.statusCode === 200 &&
      /already processed/i.test(res2.body || "") &&
      activationEvents.length === 1;
    results["33_duplicate_event_is_noop"] = ok
      ? "PASSED — first delivery activates (200), redelivery of the SAME event id is a no-op (200 'Already processed', no second activation event)"
      : `FAILED — res1=${res1.statusCode}/${res1.body} res2=${res2.statusCode}/${res2.body} activationEventCount=${activationEvents.length} employeePaid=${employeeAfterFirst.data().onboardingPaid}`;
  }

  console.log("=== PHASE 16A — ASSOCIATE ONBOARDING WEBHOOK TEST ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);

  const allPassed = Object.values(results).every((v) => v.startsWith("PASSED"));
  console.log(allPassed ? "\nALL PASSED" : "\nSOME FAILED");
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phase16a webhook test:", e);
  process.exit(1);
});
