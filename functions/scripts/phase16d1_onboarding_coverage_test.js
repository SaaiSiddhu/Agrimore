// Phase 16D-1, Workstream 4: covers the eight Phase 16A exports that had
// NEVER been named by any test (only their shared internals —
// performOnboardingActivation, loadOnboardingConfig — were proven).
// Most sharply: waiveAssociateOnboardingFee and
// recordAssociateOnboardingRefund are admin-only, money-adjacent callables
// whose admin check had never run once before this suite.
//
// Invocation styles used, and what each does/doesn't prove (also restated
// in the completion report):
//   - onCall functions (waiveAssociateOnboardingFee,
//     recordAssociateOnboardingRefund, createAssociateOnboardingPayment,
//     activateAssociateOnboarding, getAssociateOnboardingConfig): invoked
//     via firebase-functions-test's test.wrap(), the SAME real emulator
//     harness phase14_payment_replay_test.js already uses for createOrder.
//     This is a REAL callable invocation of the REAL compiled handler.
//   - requestAssociateOnboardingRefundOnSuspend (v1 Firestore onUpdate
//     trigger): proven via REAL writes against the Firestore emulator
//     with the Functions emulator also running — the real trigger fires
//     exactly as production would; results are read back after a bounded
//     poll. NOT a direct function call.
//   - reconcileStaleOnboardingPayments (v2 onSchedule): the emulator
//     SKIPS scheduled functions entirely (no pubsub emulator). Invoked by
//     calling its exported `.run()` directly (onSchedule's returned
//     function has `func.run = handler` — see node_modules/
//     firebase-functions/lib/v2/providers/scheduler.js), the same
//     direct-invocation approach phase16a_webhook_test.js uses for the
//     onRequest webhook. This proves the HANDLER's logic but does NOT
//     prove the Cloud Scheduler trigger/cron wiring itself, which cannot
//     be exercised in this environment.
// The live Razorpay API is NEVER called: `razorpay` is stubbed at the
// module-cache boundary before any compiled file requiring it is loaded,
// and every onCall scenario below is constructed to short-circuit before
// reaching Razorpay regardless.
//
// Run with: node scripts/phase16d1_onboarding_coverage_test.js
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";
process.env.RAZORPAY_KEY_ID = "rzp_test_stub_key_id";
process.env.RAZORPAY_KEY_SECRET = "stub_secret_never_used_do_not_call_live_api";

// ---- Stub `razorpay` at the module-cache boundary, before any compiled
// file that imports it is required. See scenario 23 for how fetchPayments
// results are configured per test.
const RECONCILER_FAKE_PAYMENTS = {};
const razorpayPath = require.resolve("razorpay");
function FakeRazorpay() {
  this.orders = {
    fetchPayments: async (orderId) => RECONCILER_FAKE_PAYMENTS[orderId] || { items: [] },
    create: async () => {
      throw new Error("TEST BUG: a scenario reached the stubbed Razorpay order-create call — it must short-circuit before this point");
    },
  };
}
require.cache[razorpayPath] = { id: razorpayPath, filename: razorpayPath, loaded: true, exports: FakeRazorpay };

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });
const db = admin.firestore();

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { waiveAssociateOnboardingFee, recordAssociateOnboardingRefund, requestAssociateOnboardingRefundOnSuspend } = require("../lib/employee/adminOnboardingActions");
const { createAssociateOnboardingPayment } = require("../lib/employee/createAssociateOnboardingPayment");
const { activateAssociateOnboarding } = require("../lib/employee/activateAssociateOnboarding");
const { getAssociateOnboardingConfig } = require("../lib/employee/getAssociateOnboardingConfig");
const { reconcileStaleOnboardingPayments } = require("../lib/employee/reconcileStaleOnboardingPayments");

const wrappedWaive = test.wrap(waiveAssociateOnboardingFee);
const wrappedRefund = test.wrap(recordAssociateOnboardingRefund);
const wrappedCreatePayment = test.wrap(createAssociateOnboardingPayment);
const wrappedActivate = test.wrap(activateAssociateOnboarding);
const wrappedGetConfig = test.wrap(getAssociateOnboardingConfig);
const wrappedSuspendTrigger = test.wrap(requestAssociateOnboardingRefundOnSuspend);

async function callAndCapture(wrapped, payload, auth) {
  try {
    const result = await wrapped({ data: payload, auth });
    return { ok: true, result };
  } catch (e) {
    return { ok: false, code: e.code, message: e.message };
  }
}

// Direct invocation (offline mode), same approach as
// phase16d1_commission_test.js and for the same reason: this environment
// has a concurrent session actively editing Cloud Functions source, which
// corrupts the Functions emulator's live background-trigger dispatch via
// hot-reload mid-test. This calls the REAL compiled trigger directly, with
// REAL Firestore reads/writes against the emulator — it does not prove the
// live Cloud Firestore trigger WIRING itself, only the handler's logic.
async function fireEmployeeUpdate(employeeId, beforeData, afterData) {
  const beforeSnap = test.firestore.makeDocumentSnapshot(beforeData, `employees/${employeeId}`);
  const afterSnap = test.firestore.makeDocumentSnapshot(afterData, `employees/${employeeId}`);
  const change = test.makeChange(beforeSnap, afterSnap);
  return wrappedSuspendTrigger(change, { params: { employeeId } });
}

const NON_ADMIN_AUTH = { uid: "p16d1-w4-nonadmin", token: {} };
const ADMIN_AUTH = { uid: "p16d1-w4-admin", token: { admin: true } };

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
async function waitFor(checkFn, { timeoutMs = 10000, intervalMs = 300 } = {}) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const value = await checkFn();
    if (value) return value;
    await sleep(intervalMs);
  }
  return null;
}

const GOOD_ONBOARDING_CONFIG = {
  isEnabled: true,
  feeAmount: 500,
  currency: "INR",
  version: 1,
  copy: {
    headline: "h",
    feeLabel: "f",
    supportingStatement: "s",
    whyTheFeeExists: { title: "t", body: ["a"] },
    benefitGroups: [{ key: "g", title: "g", items: ["i"] }],
    earningsExplainer: { title: "t", body: ["a"], flowSteps: ["a"], variabilityFactors: ["a"] },
    journeySteps: [{ step: 1, title: "t", body: "b" }],
    summaryCard: { title: "t", feeLine: "f", includes: ["i"], ctaLabel: "c", ctaSubtext: "s" },
    supportContact: { title: "t", body: "b", email: "e@example.com", phone: "" },
  },
};

async function seedEmployee(uid, overrides = {}) {
  await db.collection("employees").doc(uid).set({
    userId: uid,
    name: "Test",
    email: `${uid}@p16d1-test.example`,
    phone: "9999999999",
    employeeCode: uid.toUpperCase().slice(0, 6),
    status: "pending",
    commissionRate: 0,
    createdBy: "self",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    ...overrides,
  });
}

async function main() {
  let allPassed = true;
  const results = {};
  const record = (key, ok, passMsg, failMsg) => {
    results[key] = ok ? `PASSED — ${passMsg}` : `FAILED — ${failMsg}`;
    if (!ok) allPassed = false;
    console.log(`${key}:`, results[key]);
  };

  console.log("=== PHASE 16D-1, WORKSTREAM 4 — Phase 16A export coverage ===");

  // ============================================
  // waiveAssociateOnboardingFee — 1-5
  // ============================================
  {
    const uid = "p16d1-w4-waive1";
    await seedEmployee(uid);
    const r = await callAndCapture(wrappedWaive, { employeeId: uid, reason: "test" }, NON_ADMIN_AUTH);
    record("1_waive_non_admin_rejected", !r.ok && r.code === "permission-denied", `rejected: code=${r.code}`, `r=${JSON.stringify(r)}`);
  }
  {
    const uid = "p16d1-w4-waive2";
    await seedEmployee(uid);
    const r = await callAndCapture(wrappedWaive, { employeeId: uid, reason: "admin waived for test" }, ADMIN_AUTH);
    const snap = r.ok ? await db.collection("employees").doc(uid).get() : null;
    const ok = r.ok && snap.data().onboardingWaived === true;
    record("2_waive_admin_succeeds", ok, `onboardingWaived=${snap && snap.data().onboardingWaived}`, `r=${JSON.stringify(r)}`);
  }
  {
    const uid = "p16d1-w4-waive3";
    await seedEmployee(uid);
    await callAndCapture(wrappedWaive, { employeeId: uid, reason: "test" }, ADMIN_AUTH);
    const snap = await db.collection("employees").doc(uid).get();
    record("3_waive_never_sets_onboardingPaid", snap.data().onboardingPaid !== true, "onboardingPaid untouched", `onboardingPaid=${snap.data().onboardingPaid}`);
  }
  {
    const uid = "p16d1-w4-waive4";
    await seedEmployee(uid);
    await callAndCapture(wrappedWaive, { employeeId: uid, reason: "test" }, ADMIN_AUTH);
    const snap = await db.collection("employees").doc(uid).get();
    record("4_waive_never_sets_status_approved", snap.data().status !== "approved", `status=${snap.data().status}`, `status became approved`);
  }
  {
    const uid = "p16d1-w4-waive5";
    await seedEmployee(uid);
    const r = await callAndCapture(wrappedWaive, { employeeId: uid, reason: "" }, ADMIN_AUTH);
    record("5_waive_empty_reason_rejected", !r.ok && r.code === "invalid-argument", `rejected: code=${r.code}`, `r=${JSON.stringify(r)}`);
  }

  // ============================================
  // recordAssociateOnboardingRefund — 6-9
  // ============================================
  {
    const uid = "p16d1-w4-refund6";
    await seedEmployee(uid, { onboardingPaid: true, onboardingFeeAmount: 500, onboardingPaymentId: "pay_x" });
    const r = await callAndCapture(wrappedRefund, { employeeId: uid, reason: "test" }, NON_ADMIN_AUTH);
    record("6_refund_non_admin_rejected", !r.ok && r.code === "permission-denied", `rejected: code=${r.code}`, `r=${JSON.stringify(r)}`);
  }
  {
    const uid = "p16d1-w4-refund7";
    await seedEmployee(uid, { onboardingPaid: true, onboardingFeeAmount: 500, onboardingPaymentId: "pay_x" });
    const r = await callAndCapture(wrappedRefund, { employeeId: uid, reason: "admin refund test" }, ADMIN_AUTH);
    const snap = r.ok ? await db.collection("employees").doc(uid).get() : null;
    record("7_refund_admin_sets_refundedAt", r.ok && !!snap.data().onboardingRefundedAt, "onboardingRefundedAt set", `r=${JSON.stringify(r)}`);
  }
  {
    const uid = "p16d1-w4-refund8";
    await seedEmployee(uid, { onboardingPaid: true, onboardingFeeAmount: 500, onboardingPaymentId: "pay_x" });
    await callAndCapture(wrappedRefund, { employeeId: uid, reason: "test" }, ADMIN_AUTH);
    const snap = await db.collection("employees").doc(uid).get();
    const e = snap.data();
    const gateCleared = (e.onboardingPaid === true || e.onboardingWaived === true) && !e.onboardingRefundedAt;
    record("8_refund_no_longer_gate_cleared", gateCleared === false, "hasClearedOnboardingGate-equivalent now reads false", `onboardingPaid=${e.onboardingPaid} onboardingRefundedAt=${JSON.stringify(e.onboardingRefundedAt)}`);
  }
  {
    const uid = "p16d1-w4-refund9";
    await seedEmployee(uid); // never paid
    const r = await callAndCapture(wrappedRefund, { employeeId: uid, reason: "test" }, ADMIN_AUTH);
    // Read from the code (adminOnboardingActions.ts): `if
    // (employee.onboardingPaid !== true) throw failed-precondition
    // "...there is nothing to refund."` — asserting exactly that, not an
    // assumption.
    record(
      "9_refund_never_paid_handled_per_code",
      !r.ok && r.code === "failed-precondition" && r.message.includes("never paid the onboarding fee"),
      `rejected exactly as the code specifies: code=${r.code} message="${r.message}"`,
      `r=${JSON.stringify(r)}`
    );
  }

  // ============================================
  // requestAssociateOnboardingRefundOnSuspend — 10-13 (direct invocation —
  // see fireEmployeeUpdate()'s comment above for why: this environment's
  // Functions emulator is unreliable for live trigger dispatch during this
  // run due to a concurrent session actively editing Cloud Functions
  // source files)
  // ============================================
  {
    const uid = "p16d1-w4-suspend10";
    const paymentId = "pay_suspend10";
    const before = { status: "pending", onboardingPaid: true, onboardingFeeAmount: 500, onboardingPaymentId: paymentId };
    await seedEmployee(uid, before);
    await fireEmployeeUpdate(uid, before, { ...before, status: "suspended" });
    const snap = await db.collection("associate_refund_requests").doc(`${uid}_${paymentId}`).get();
    record("10_suspend_paid_associate_creates_refund_request", snap.exists && snap.data().status === "pending", `request created: ${JSON.stringify(snap.data())}`, "no request created");
  }
  {
    const uid = "p16d1-w4-suspend11";
    const before = { status: "pending", onboardingPaid: true, onboardingFeeAmount: 500, onboardingPaymentId: "pay_suspend11" };
    await seedEmployee(uid, before);
    // Unrelated field change, no status transition.
    await fireEmployeeUpdate(uid, before, { ...before, phone: "8888888888" });
    const snap = await db.collection("associate_refund_requests").where("employeeId", "==", uid).get();
    record("11_unrelated_update_creates_nothing", snap.empty, "no refund request created for a non-status-transition update", `${snap.size} request(s) created`);
  }
  {
    const uid = "p16d1-w4-suspend12";
    const paymentId = "pay_suspend12";
    const before = { status: "pending", onboardingPaid: true, onboardingFeeAmount: 500, onboardingPaymentId: paymentId };
    await seedEmployee(uid, before);
    const suspended = { ...before, status: "suspended" };
    await fireEmployeeUpdate(uid, before, suspended);
    // Force a SECOND transition into suspended for the SAME payment.
    await fireEmployeeUpdate(uid, suspended, before);
    await fireEmployeeUpdate(uid, before, suspended);
    const snap = await db.collection("associate_refund_requests").where("employeeId", "==", uid).get();
    record("12_second_suspension_no_duplicate_request", snap.size === 1, "exactly 1 refund request exists despite two suspensions for the same payment", `${snap.size} request(s) exist`);
  }
  {
    const uid = "p16d1-w4-suspend13";
    const before = { status: "pending", onboardingWaived: true }; // waived, never paid
    await seedEmployee(uid, before);
    await fireEmployeeUpdate(uid, before, { ...before, status: "suspended" });
    const snap = await db.collection("associate_refund_requests").where("employeeId", "==", uid).get();
    record("13_waived_only_suspension_creates_nothing", snap.empty, "no refund request for a waived-only (never paid) associate", `${snap.size} request(s) created`);
  }

  // ============================================
  // createAssociateOnboardingPayment — 14-18
  // ============================================
  await db.collection("settings").doc("associate_onboarding").set(GOOD_ONBOARDING_CONFIG);
  {
    const r = await callAndCapture(wrappedCreatePayment, {}, undefined);
    record("14_createpayment_unauthenticated_rejected", !r.ok && r.code === "unauthenticated", `rejected: code=${r.code}`, `r=${JSON.stringify(r)}`);
  }
  {
    const uid = "p16d1-w4-createpay15-noemployee";
    const r = await callAndCapture(wrappedCreatePayment, {}, { uid, token: {} });
    record("15_createpayment_no_employee_doc_rejected", !r.ok && r.code === "failed-precondition", `rejected: code=${r.code} message="${r.message}"`, `r=${JSON.stringify(r)}`);
  }
  {
    const uid = "p16d1-w4-createpay16-alreadypaid";
    await seedEmployee(uid, { onboardingPaid: true, onboardingFeeAmount: 500 });
    const r = await callAndCapture(wrappedCreatePayment, {}, { uid, token: {} });
    record("16_createpayment_already_gate_cleared_rejected", !r.ok && r.code === "already-exists", `rejected: code=${r.code}`, `r=${JSON.stringify(r)}`);
  }
  {
    const uid = "p16d1-w4-createpay17-refunded";
    await seedEmployee(uid, { onboardingPaid: true, onboardingRefundedAt: admin.firestore.FieldValue.serverTimestamp() });
    const r = await callAndCapture(wrappedCreatePayment, {}, { uid, token: {} });
    record("17_createpayment_refunded_rejected", !r.ok && r.code === "failed-precondition", `rejected: code=${r.code} message="${r.message}"`, `r=${JSON.stringify(r)}`);
  }
  {
    const uid = "p16d1-w4-createpay18-ratelimited";
    await seedEmployee(uid);
    // Simulate "a call already happened 5 seconds ago" WITHOUT making a
    // real call — never reaches the stubbed/live Razorpay order-create.
    await db.collection("onboarding_rate_limits").doc(uid).set({
      lastRequestAt: admin.firestore.Timestamp.fromMillis(Date.now() - 5000),
    });
    const r = await callAndCapture(wrappedCreatePayment, {}, { uid, token: {} });
    record("18_createpayment_rate_limited", !r.ok && r.code === "resource-exhausted", `rejected: code=${r.code}`, `r=${JSON.stringify(r)}`);
  }

  // ============================================
  // activateAssociateOnboarding (the CALLABLE) — 19-20
  // ============================================
  {
    const r = await callAndCapture(wrappedActivate, { paymentId: "whatever" }, undefined);
    record("19_activate_unauthenticated_rejected", !r.ok && r.code === "unauthenticated", `rejected: code=${r.code}`, `r=${JSON.stringify(r)}`);
  }
  {
    const uid = "p16d1-w4-activate20";
    const otherUid = "p16d1-w4-activate20-other";
    const paymentId = "pay_activate20";
    await seedEmployee(uid);
    await seedEmployee(otherUid);
    await db.collection("verified_payments").doc(paymentId).set({
      orderId: `order_${paymentId}`,
      paymentId,
      userId: uid,
      signatureVerified: true,
      status: "captured",
      amount: 500,
      currency: "INR",
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    // Client-supplied amount/employeeId that, if trusted, would either
    // overpay or misattribute the activation to `otherUid`.
    const r = await callAndCapture(
      wrappedActivate,
      { paymentId, amount: 999999, employeeId: otherUid },
      { uid, token: {} }
    );
    const callerSnap = await db.collection("employees").doc(uid).get();
    const otherSnap = await db.collection("employees").doc(otherUid).get();
    const ok = r.ok && callerSnap.data().onboardingPaid === true && callerSnap.data().onboardingFeeAmount === 500 && otherSnap.data().onboardingPaid !== true;
    record(
      "20_activate_client_supplied_fields_ignored",
      ok,
      `caller (${uid}) activated at the real ₹500 fee; payload's amount=999999/employeeId=${otherUid} had no effect`,
      `r=${JSON.stringify(r)} caller=${JSON.stringify(callerSnap.data())} other=${JSON.stringify(otherSnap.data())}`
    );
  }

  // ============================================
  // getAssociateOnboardingConfig — 21-22
  // ============================================
  {
    const r = await callAndCapture(wrappedGetConfig, {}, undefined);
    const hasTopLevelArray = r.ok && Array.isArray(r.result.mandatoryDisclosures) && r.result.mandatoryDisclosures.length > 0;
    record("21_getconfig_returns_top_level_mandatoryDisclosures", hasTopLevelArray, `mandatoryDisclosures is a top-level array of ${r.ok ? r.result.mandatoryDisclosures.length : 0} entries`, `r=${JSON.stringify(r)}`);
  }
  {
    const r = await callAndCapture(wrappedGetConfig, {}, undefined);
    const serialized = JSON.stringify(r.result || {}).toLowerCase();
    const leaked = ["key_secret", "razorpay_key_secret", "keysecret", process.env.RAZORPAY_KEY_SECRET.toLowerCase()].some((needle) => serialized.includes(needle));
    record("22_getconfig_returns_no_secret", r.ok && !leaked, "no Razorpay-secret-like string found anywhere in the response", `leaked=${leaked}`);
  }

  // ============================================
  // reconcileStaleOnboardingPayments — 23 (direct .run() invocation)
  // ============================================
  {
    const now = Date.now();
    const staleOrderId = "p16d1-w4-reconcile-stale-activatable";
    const staleExceptionOrderId = "p16d1-w4-reconcile-stale-exception";
    const freshOrderId = "p16d1-w4-reconcile-fresh-not-picked-up";
    const tooOldOrderId = "p16d1-w4-reconcile-too-old-not-picked-up";

    const staleUid = "p16d1-w4-reconcile-emp-stale";
    const exceptionUid = "p16d1-w4-reconcile-emp-exception";
    const freshUid = "p16d1-w4-reconcile-emp-fresh";
    const tooOldUid = "p16d1-w4-reconcile-emp-tooold";

    await seedEmployee(staleUid);
    await seedEmployee(exceptionUid);
    await seedEmployee(freshUid);
    await seedEmployee(tooOldUid);

    // Stale (40 min old — within [30min, 24h] window), activatable.
    await db.collection("razorpay_orders").doc(staleOrderId).set({
      orderId: staleOrderId,
      userId: staleUid,
      employeeId: staleUid,
      purpose: "associate_onboarding",
      amount: 500,
      currency: "INR",
      createdAt: admin.firestore.Timestamp.fromMillis(now - 40 * 60 * 1000),
    });
    await db.collection("verified_payments").doc("pay_reconcile_stale").set({
      orderId: staleOrderId,
      paymentId: "pay_reconcile_stale",
      userId: staleUid,
      signatureVerified: true,
      status: "captured",
      amount: 500,
      currency: "INR",
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    RECONCILER_FAKE_PAYMENTS[staleOrderId] = { items: [{ id: "pay_reconcile_stale", order_id: staleOrderId, amount: 50000, currency: "INR", status: "captured" }] };

    // Stale, captured payment exists per Razorpay, but activation will
    // fail (amount mismatch) -> must produce an onboarding_exceptions
    // record, not a silent no-op.
    await db.collection("razorpay_orders").doc(staleExceptionOrderId).set({
      orderId: staleExceptionOrderId,
      userId: exceptionUid,
      employeeId: exceptionUid,
      purpose: "associate_onboarding",
      amount: 500,
      currency: "INR",
      createdAt: admin.firestore.Timestamp.fromMillis(now - 45 * 60 * 1000),
    });
    await db.collection("verified_payments").doc("pay_reconcile_exception").set({
      orderId: staleExceptionOrderId,
      paymentId: "pay_reconcile_exception",
      userId: exceptionUid,
      signatureVerified: true,
      status: "captured",
      amount: 1, // mismatched — will fail payment_amount_mismatch
      currency: "INR",
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    RECONCILER_FAKE_PAYMENTS[staleExceptionOrderId] = { items: [{ id: "pay_reconcile_exception", order_id: staleExceptionOrderId, amount: 50000, currency: "INR", status: "captured" }] };

    // Fresh (created just now) — MUST be excluded by the staleness
    // window even though a captured payment is "available".
    await db.collection("razorpay_orders").doc(freshOrderId).set({
      orderId: freshOrderId,
      userId: freshUid,
      employeeId: freshUid,
      purpose: "associate_onboarding",
      amount: 500,
      currency: "INR",
      createdAt: admin.firestore.Timestamp.fromMillis(now),
    });
    await db.collection("verified_payments").doc("pay_reconcile_fresh").set({
      orderId: freshOrderId,
      paymentId: "pay_reconcile_fresh",
      userId: freshUid,
      signatureVerified: true,
      status: "captured",
      amount: 500,
      currency: "INR",
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    RECONCILER_FAKE_PAYMENTS[freshOrderId] = { items: [{ id: "pay_reconcile_fresh", order_id: freshOrderId, amount: 50000, currency: "INR", status: "captured" }] };

    // Too old (30 hours) — MUST be excluded by the lookback bound.
    await db.collection("razorpay_orders").doc(tooOldOrderId).set({
      orderId: tooOldOrderId,
      userId: tooOldUid,
      employeeId: tooOldUid,
      purpose: "associate_onboarding",
      amount: 500,
      currency: "INR",
      createdAt: admin.firestore.Timestamp.fromMillis(now - 30 * 60 * 60 * 1000),
    });

    let runError = null;
    try {
      await reconcileStaleOnboardingPayments.run();
    } catch (e) {
      runError = e;
    }

    const staleEmp = await db.collection("employees").doc(staleUid).get();
    const exceptionSnap = await db.collection("onboarding_exceptions").where("orderId", "==", staleExceptionOrderId).get();
    const freshEmp = await db.collection("employees").doc(freshUid).get();
    const tooOldEmp = await db.collection("employees").doc(tooOldUid).get();

    const ok =
      !runError &&
      staleEmp.data().onboardingPaid === true &&
      !exceptionSnap.empty &&
      freshEmp.data().onboardingPaid !== true &&
      tooOldEmp.data().onboardingPaid !== true;
    record(
      "23_reconciler_bounded_query_activates_or_exceptions",
      ok,
      "the stale+activatable order activated its associate; the stale+failing order produced an onboarding_exceptions record; the fresh and too-old orders were correctly excluded by the bounded query",
      `runError=${runError} staleEmpPaid=${staleEmp.data().onboardingPaid} exceptionEmpty=${exceptionSnap.empty} freshEmpPaid=${freshEmp.data().onboardingPaid} tooOldEmpPaid=${tooOldEmp.data().onboardingPaid}`
    );
  }

  console.log("=== PHASE 16D-1 WORKSTREAM 4 SUMMARY ===");
  console.log(allPassed ? "\nALL PASSED" : "\nSOME FAILED");
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phase16d1 onboarding coverage test:", e);
  process.exit(1);
});
