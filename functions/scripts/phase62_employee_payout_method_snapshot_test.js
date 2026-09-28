// Phase ADMR-17 — requestEmployeePayout.ts snapshots payoutMethod/destination
//
// FINDING: requestEmployeePayout.ts created each `employee_payouts` document
// with only {employeeId, amount, status, createdAt} — even though it already
// fetches the full employees/{uid} record (payoutMethod/accountNumber/upiId)
// two lines earlier to check approval status. Two apps/employee screens read
// these exact field names directly off the persisted document with silent,
// wrong fallbacks: payout_history_screen.dart always tagged every payout
// "BANK" (the field was never present, so its `?? 'BANK'` fallback fired on
// every render, even for UPI associates); payout_details_screen.dart briefly
// showed the true method/destination via the navigation-time initialData,
// then silently replaced it with "BANK" / the generic literal "Registered
// account" the instant its live Firestore stream delivered the real (fewer
// -field) document.
//
// This is also the first test to genuinely dispatch requestEmployeePayout.ts
// itself (previously only reviewEmployeePayout.ts's callables were exercised
// by phase59/phase61) — exercises the REAL compiled
// functions/lib/customer/requestEmployeePayout.js against the Firestore
// emulator, wrapped and invoked the same way as phase59's
// markEmployeePayoutPaid/rejectEmployeePayout (test.wrap({data, auth})).
//
// Run with:
//   firebase emulators:exec --only firestore,functions,auth \
//     "node scripts/phase62_employee_payout_method_snapshot_test.js"
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || "agrimore-66a4e";

const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: "agrimore-66a4e" });
const db = admin.firestore();

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { requestEmployeePayout } = require("../lib/customer/requestEmployeePayout");
const wrappedRequest = test.wrap(requestEmployeePayout);

// requestEmployeePayout is a v1 (`firebase-functions/v1`) onCall, whose
// handler signature is (data, context) — two separate arguments — unlike
// reviewEmployeePayout.ts's v2 onCall (data merged into one {data, auth}
// object, per phase59_employee_payout_review_test.js's own wrap style).
async function callRequest(payload, auth) {
  try {
    return { ok: true, result: await wrappedRequest(payload, { auth }) };
  } catch (e) {
    return { ok: false, code: e.code, message: e.message, details: e.details };
  }
}

async function seedEmployee(uid, fields) {
  await db.collection("employees").doc(uid).set({ status: "approved", ...fields });
}
async function seedWallet(uid, balance) {
  await db.collection("wallets").doc(uid).set({ balance, coins: 0 });
}
async function payoutFor(payoutId) {
  return (await db.collection("employee_payouts").doc(payoutId).get()).data() || {};
}

async function main() {
  const results = {};
  let allPassed = true;
  const record = (k, p, d) => { results[k] = p; console.log(`${k}: ${p ? "PASSED" : "FAILED"} — ${d}`); if (!p) allPassed = false; };

  console.log("=== PHASE ADMR-17 — requestEmployeePayout snapshots payoutMethod/destination ===");

  // 1 — a UPI-registered associate's payout doc carries payoutMethod: 'upi'
  // and the real upiId, not the field-absent-so-'BANK' shape this finding
  // describes.
  {
    const uid = "phase62-upi-employee";
    await seedEmployee(uid, { payoutMethod: "upi", upiId: "assoc62@okhdfc" });
    await seedWallet(uid, 1000);
    const r = await callRequest({ amount: 300, requestId: "phase62-req-s1" }, { uid, token: {} });
    const p = r.ok ? await payoutFor(r.result.payoutId) : {};
    record("s1_upi_associate_snapshot_correct",
      r.ok && p.payoutMethod === "upi" && p.upiId === "assoc62@okhdfc" && p.accountNumber === null,
      `ok=${r.ok} payoutMethod=${p.payoutMethod}(expect upi) upiId=${p.upiId}(expect assoc62@okhdfc) accountNumber=${p.accountNumber}(expect null)`);
  }

  // 2 — a bank-registered associate's payout doc carries payoutMethod: 'bank'
  // and the real accountNumber, with upiId null (not the other way around).
  {
    const uid = "phase62-bank-employee";
    await seedEmployee(uid, { payoutMethod: "bank", accountNumber: "000111222333", bankName: "Test Bank" });
    await seedWallet(uid, 1000);
    const r = await callRequest({ amount: 250, requestId: "phase62-req-s2" }, { uid, token: {} });
    const p = r.ok ? await payoutFor(r.result.payoutId) : {};
    record("s2_bank_associate_snapshot_correct",
      r.ok && p.payoutMethod === "bank" && p.accountNumber === "000111222333" && p.upiId === null,
      `ok=${r.ok} payoutMethod=${p.payoutMethod}(expect bank) accountNumber=${p.accountNumber}(expect 000111222333) upiId=${p.upiId}(expect null)`);
  }

  // 3 — an approved associate with no payout account registered at all gets
  // honest nulls on the payout doc, never a fabricated non-null default —
  // guards against the bug reappearing one layer deeper (a false "bank"
  // baked into the record itself, instead of just the old display fallback).
  {
    const uid = "phase62-no-account-employee";
    await seedEmployee(uid, {});
    await seedWallet(uid, 1000);
    const r = await callRequest({ amount: 100, requestId: "phase62-req-s3" }, { uid, token: {} });
    const p = r.ok ? await payoutFor(r.result.payoutId) : {};
    record("s3_no_registered_account_is_honest_null_not_fabricated_bank",
      r.ok && p.payoutMethod === null && p.accountNumber === null && p.upiId === null,
      `ok=${r.ok} payoutMethod=${p.payoutMethod}(expect null) accountNumber=${p.accountNumber}(expect null) upiId=${p.upiId}(expect null)`);
  }

  // 4 — pre-existing behaviour untouched: insufficient balance is still
  // refused and still writes no payout doc at all (this phase only adds
  // fields to the success path's write, it does not touch the guard).
  {
    const uid = "phase62-insufficient-employee";
    await seedEmployee(uid, { payoutMethod: "upi", upiId: "x@y" });
    await seedWallet(uid, 50);
    const before = (await db.collection("employee_payouts").where("employeeId", "==", uid).get()).size;
    const r = await callRequest({ amount: 999, requestId: "phase62-req-s4" }, { uid, token: {} });
    const after = (await db.collection("employee_payouts").where("employeeId", "==", uid).get()).size;
    record("s4_insufficient_balance_still_refused_no_doc_written",
      !r.ok && r.code === "failed-precondition" && before === 0 && after === 0,
      `ok=${r.ok} code=${r.code} docsBefore=${before} docsAfter=${after}(expect 0/0)`);
  }

  // 5 — ADMR-43: a retried call with the SAME requestId (an ambiguous
  // failure followed by a retry) debits the wallet exactly once and
  // returns the original payoutId, not a second document.
  {
    const uid = "phase62-retry-employee";
    await seedEmployee(uid, { payoutMethod: "upi", upiId: "retry62@okhdfc" });
    await seedWallet(uid, 1000);
    const r1 = await callRequest({ amount: 400, requestId: "phase62-req-s5" }, { uid, token: {} });
    const r2 = await callRequest({ amount: 400, requestId: "phase62-req-s5" }, { uid, token: {} });
    const walletAfter = (await db.collection("wallets").doc(uid).get()).data() || {};
    const docCount = (await db.collection("employee_payouts").where("employeeId", "==", uid).get()).size;
    record("s5_same_requestId_retry_debits_wallet_once",
      r1.ok && r2.ok && r1.result.payoutId === r2.result.payoutId &&
        !r1.result.alreadyApplied && r2.result.alreadyApplied === true &&
        walletAfter.balance === 600 && docCount === 1,
      `first=${r1.result && r1.result.payoutId} second=${r2.result && r2.result.payoutId}(expect same) ` +
      `firstAlready=${r1.result && r1.result.alreadyApplied}(expect falsy) secondAlready=${r2.result && r2.result.alreadyApplied}(expect true) ` +
      `walletBalance=${walletAfter.balance}(expect 600, debited once) docCount=${docCount}(expect 1)`);
  }

  // 6 — a DIFFERENT requestId for the same associate is a genuinely new
  // request — debits again, writes a second document.
  {
    const uid = "phase62-tworequests-employee";
    await seedEmployee(uid, { payoutMethod: "upi", upiId: "two62@okhdfc" });
    await seedWallet(uid, 1000);
    const r1 = await callRequest({ amount: 200, requestId: "phase62-req-s6a" }, { uid, token: {} });
    const r2 = await callRequest({ amount: 150, requestId: "phase62-req-s6b" }, { uid, token: {} });
    const walletAfter = (await db.collection("wallets").doc(uid).get()).data() || {};
    const docCount = (await db.collection("employee_payouts").where("employeeId", "==", uid).get()).size;
    record("s6_different_requestId_is_a_genuinely_new_request",
      r1.ok && r2.ok && r1.result.payoutId !== r2.result.payoutId &&
        walletAfter.balance === 650 && docCount === 2,
      `first=${r1.result && r1.result.payoutId} second=${r2.result && r2.result.payoutId}(expect different) ` +
      `walletBalance=${walletAfter.balance}(expect 650, both debited) docCount=${docCount}(expect 2)`);
  }

  // 7 — reusing the SAME requestId for a DIFFERENT amount is refused, not
  // silently replayed with the original (now-mismatched) amount.
  {
    const uid = "phase62-mismatch-employee";
    await seedEmployee(uid, { payoutMethod: "upi", upiId: "mismatch62@okhdfc" });
    await seedWallet(uid, 1000);
    const r1 = await callRequest({ amount: 300, requestId: "phase62-req-s7" }, { uid, token: {} });
    const r2 = await callRequest({ amount: 500, requestId: "phase62-req-s7" }, { uid, token: {} });
    const walletAfter = (await db.collection("wallets").doc(uid).get()).data() || {};
    record("s7_same_requestId_different_amount_is_refused",
      r1.ok && r1.result.amount === 300 &&
        !r2.ok && r2.code === "invalid-argument" && /different amount/i.test(r2.message || "") &&
        walletAfter.balance === 700,
      `first=${r1.ok && r1.result.amount} second_ok=${r2.ok} second_code=${r2.code} second_message=${r2.message} walletBalance=${walletAfter.balance}(expect 700, only the first debit)`);
  }

  // 8 — a missing/malformed requestId is refused outright, not silently
  // defaulted (the old, un-idempotent behaviour must not reappear).
  {
    const uid = "phase62-norequestid-employee";
    await seedEmployee(uid, { payoutMethod: "upi", upiId: "none62@okhdfc" });
    await seedWallet(uid, 1000);
    const r = await callRequest({ amount: 100 }, { uid, token: {} });
    const docCount = (await db.collection("employee_payouts").where("employeeId", "==", uid).get()).size;
    record("s8_missing_requestId_is_refused_not_silently_defaulted",
      !r.ok && r.code === "invalid-argument" && docCount === 0,
      `ok=${r.ok} code=${r.code}(expect invalid-argument) docCount=${docCount}(expect 0)`);
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
