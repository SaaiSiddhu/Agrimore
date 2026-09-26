// Phase ADMR-5 — employeePayoutAccount.ts (request/cancel/review) +
// reviewEmployeePayout.ts's new payout_change_pending guard.
//
// FINDING: payout_account_screen.dart wrote accountNumber/ifscCode/bankName/
// upiId/payoutMethod DIRECTLY onto employees/{uid} with no review step,
// hold or audit trail — an associate could redirect their own payout
// destination the instant before an admin paid them out.
//
// Mirrors functions/src/seller/sellerWallet.ts's own request/review shape;
// all three are v2 onCall — wrapped and invoked as wrapped({data, auth}),
// the same pattern phase27/phase59 already established for this generation.
//
// Run with:
//   firebase emulators:exec --only firestore,functions,auth \
//     "node scripts/phase61_employee_payout_change_test.js"
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: "agrimore-66a4e" });
const db = admin.firestore();

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const {
  requestEmployeePayoutChange,
  cancelEmployeePayoutChange,
  reviewEmployeePayoutChange,
} = require("../lib/employee/employeePayoutAccount");
const { markEmployeePayoutPaid } = require("../lib/customer/reviewEmployeePayout");

const wrappedRequest = test.wrap(requestEmployeePayoutChange);
const wrappedCancel = test.wrap(cancelEmployeePayoutChange);
const wrappedReview = test.wrap(reviewEmployeePayoutChange);
const wrappedPaid = test.wrap(markEmployeePayoutPaid);

async function call(fn, payload, auth) {
  try {
    return { ok: true, result: await fn({ data: payload, auth }) };
  } catch (e) {
    return { ok: false, code: e.code, message: e.message, details: e.details };
  }
}

const ADMIN_AUTH = { uid: "phase61-admin", token: { admin: true } };
const emp = (uid) => ({ uid, token: {} });

async function seedEmployee(uid, fields = {}) {
  await db.collection("employees").doc(uid).set({ uid, status: "approved", ...fields });
}
async function employee(uid) {
  return (await db.collection("employees").doc(uid).get()).data() || {};
}
async function wallet(uid) {
  return (await db.collection("employee_wallets").doc(uid).get()).data() || {};
}
async function seedPayout(id, fields) {
  await db.collection("employee_payouts").doc(id).set({
    employeeId: fields.employeeId, amount: fields.amount, status: fields.status ?? "requested",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function main() {
  const results = {};
  let allPassed = true;
  const record = (k, p, d) => { results[k] = p; console.log(`${k}: ${p ? "PASSED" : "FAILED"} — ${d}`); if (!p) allPassed = false; };

  console.log("=== PHASE ADMR-5 — associate bank/UPI request-review workflow ===");

  // 1 — a bank request creates a pending record and sets the marker; the
  // employees/{uid} document itself is UNTOUCHED until approved.
  {
    const uid = "phase61-e1";
    await seedEmployee(uid);
    const r = await call(wrappedRequest, { payoutMethod: "bank", accountHolder: "A One", bankName: "SBI", accountNumber: "123456789012", ifsc: "SBIN0001234" }, emp(uid));
    const w = await wallet(uid);
    const e = await employee(uid);
    record("s1_request_creates_pending_record_leaves_employee_doc_untouched",
      r.ok && typeof w.payoutChangePending === "string" && w.payoutChangePending.length > 0 && e.accountNumber === undefined,
      `ok=${r.ok} pending=${w.payoutChangePending} employeeDocAccountNumber=${e.accountNumber}`);
  }

  // 2 — a second request while one is already pending is refused.
  {
    const uid = "phase61-e1"; // from scenario 1, still pending
    const r = await call(wrappedRequest, { payoutMethod: "upi", accountHolder: "A One", upiId: "a1@okhdfcbank" }, emp(uid));
    record("s2_second_request_while_pending_refused",
      !r.ok && r.details?.reason === "already_pending", `code=${r.code} reason=${r.details?.reason}`);
  }

  // 3 — invalid IFSC is refused before anything is written.
  {
    const uid = "phase61-e3";
    await seedEmployee(uid);
    const r = await call(wrappedRequest, { payoutMethod: "bank", accountHolder: "B Two", bankName: "HDFC", accountNumber: "999999999", ifsc: "bad" }, emp(uid));
    const w = await wallet(uid);
    record("s3_invalid_ifsc_refused", !r.ok && r.details?.reason === "invalid_ifsc" && !w.payoutChangePending,
      `code=${r.code} reason=${r.details?.reason} pending=${w.payoutChangePending}`);
  }

  // 4 — admin approves: employees/{uid} gets the new destination in ITS OWN
  // field names (accountHolderName/ifscCode), and the pending marker clears.
  let approvedRequestId;
  {
    const uid = "phase61-e4";
    await seedEmployee(uid, { accountNumber: "OLD000", ifscCode: "OLDB0000001" });
    const req = await call(wrappedRequest, { payoutMethod: "bank", accountHolder: "C Three", bankName: "ICICI", accountNumber: "555566667777", ifsc: "ICIC0005555" }, emp(uid));
    approvedRequestId = req.result.requestId;
    const r = await call(wrappedReview, { requestId: approvedRequestId, approve: true }, ADMIN_AUTH);
    const e = await employee(uid);
    const w = await wallet(uid);
    record("s4_approval_writes_employee_own_field_names_and_clears_pending",
      r.ok && r.result.status === "approved" && e.accountNumber === "555566667777" && e.ifscCode === "ICIC0005555" &&
      e.accountHolderName === "C Three" && !w.payoutChangePending,
      `status=${r.ok && r.result.status} accountNumber=${e.accountNumber} ifscCode=${e.ifscCode} pending=${w.payoutChangePending}`);
  }

  // 5 — retry-safety: reviewing the SAME already-reviewed request again is
  // refused, not double-applied.
  {
    const r = await call(wrappedReview, { requestId: approvedRequestId, approve: true }, ADMIN_AUTH);
    record("s5_retried_review_of_already_reviewed_request_refused",
      !r.ok && r.details?.reason === "not_pending", `code=${r.code} reason=${r.details?.reason}`);
  }

  // 6 — admin rejects: employees/{uid} is untouched, pending clears, a
  // reason is required.
  {
    const uid = "phase61-e6";
    await seedEmployee(uid);
    const req = await call(wrappedRequest, { payoutMethod: "upi", accountHolder: "D Four", upiId: "d4@okaxis" }, emp(uid));
    const missingReason = await call(wrappedReview, { requestId: req.result.requestId, approve: false }, ADMIN_AUTH);
    const r = await call(wrappedReview, { requestId: req.result.requestId, approve: false, reason: "ID mismatch" }, ADMIN_AUTH);
    const e = await employee(uid);
    const w = await wallet(uid);
    record("s6_reject_requires_reason_and_leaves_employee_doc_untouched",
      !missingReason.ok && missingReason.details?.reason === "reason_required" &&
      r.ok && r.result.status === "rejected" && e.upiId === undefined && !w.payoutChangePending,
      `missingReasonRefused=${!missingReason.ok} rejectedOk=${r.ok} upiId=${e.upiId} pending=${w.payoutChangePending}`);
  }

  // 7 — the associate can cancel their own pending request; a DIFFERENT
  // associate cannot cancel someone else's.
  {
    const uid = "phase61-e7", other = "phase61-e7-other";
    await seedEmployee(uid);
    const req = await call(wrappedRequest, { payoutMethod: "upi", accountHolder: "E Five", upiId: "e5@okicici" }, emp(uid));
    const wrongCancel = await call(wrappedCancel, { requestId: req.result.requestId }, emp(other));
    const rightCancel = await call(wrappedCancel, { requestId: req.result.requestId }, emp(uid));
    const w = await wallet(uid);
    record("s7_owner_can_cancel_another_associate_cannot",
      !wrongCancel.ok && wrongCancel.details?.reason === "not_yours" && rightCancel.ok && !w.payoutChangePending,
      `wrongCancel=${wrongCancel.code}/${wrongCancel.details?.reason} rightCancel=${rightCancel.ok} pending=${w.payoutChangePending}`);
  }

  // 8 — THE INTEGRATION POINT: markEmployeePayoutPaid refuses while a
  // bank/UPI change is pending for that associate (mirrors
  // markWithdrawalPaidCore's identical seller-side guard).
  {
    const uid = "phase61-e8", pid = "phase61-p8";
    await seedEmployee(uid);
    await seedPayout(pid, { employeeId: uid, amount: 500 });
    await call(wrappedRequest, { payoutMethod: "upi", accountHolder: "F Six", upiId: "f6@okhdfcbank" }, emp(uid));
    const r = await call(wrappedPaid, { payoutId: pid, paymentReference: "UTR123456" }, ADMIN_AUTH);
    record("s8_paying_out_while_bank_change_pending_is_refused",
      !r.ok && r.details?.reason === "payout_change_pending", `code=${r.code} reason=${r.details?.reason}`);
  }

  console.log("\n=== SUMMARY ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}: ${v}`);
  console.log(allPassed ? "\nALL PASSED" : "\nSOME FAILED");
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL", e);
  process.exit(1);
});
