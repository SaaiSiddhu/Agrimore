// PHASE ADMR-79 — requestEmployeePayout.ts reads employees/{uid} INSIDE its
// own transaction, not before it (functions/src/customer/requestEmployeePayout.ts).
//
// phase62_employee_payout_method_snapshot_test.js already proves the snapshot
// itself is correct when seeded directly; this file adds the one scenario it
// does not cover — the real cross-file integration with
// functions/src/employee/employeePayoutAccount.ts's own request/review flow,
// which phase62 never exercises (it only ever seeds employees/{uid} directly).
// A true sub-transaction race is not deterministically constructible from a
// plain script without transaction-internal hooks; this suite instead proves
// the two files agree end to end through the REAL approval path, and that
// the underlying regression suite (phase62) is unaffected by moving the read.
//  t1 a payout requested AFTER an approved account change correctly reflects
//     the NEW (approved) destination, through the real
//     requestEmployeePayoutChange -> reviewEmployeePayoutChange ->
//     requestEmployeePayout sequence, not a directly-seeded employees/ doc
//  t2 a pending (not yet approved) change does not affect an in-flight
//     payout request's own snapshot at all — only an APPROVED change does
// Run with:
//   firebase emulators:exec --only firestore \
//     "node scripts/phaseADMR79_employee_payout_transaction_consistency_test.js"
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || "agrimore-66a4e";

const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: "agrimore-66a4e" });
const db = admin.firestore();

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { requestEmployeePayout } = require("../lib/customer/requestEmployeePayout");
const { requestEmployeePayoutChangeCore, reviewEmployeePayoutChangeCore } = require("../lib/employee/employeePayoutAccount");
const wrappedRequest = test.wrap(requestEmployeePayout);

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

  console.log("=== PHASE ADMR-79 — requestEmployeePayout transaction consistency ===");

  // t1
  {
    const uid = "admr79-changed-employee";
    await seedEmployee(uid, { payoutMethod: "upi", upiId: "original79@okhdfc" });
    await seedWallet(uid, 1000);
    const ch = await requestEmployeePayoutChangeCore(db, uid, { payoutMethod: "bank", accountHolder: "Assoc", bankName: "New Bank", accountNumber: "111222333444", ifsc: "NEWB0001234" }, Date.now());
    const rev = await reviewEmployeePayoutChangeCore(db, { adminUid: "adm79" }, ch.id, true, null, Date.now());
    const r = await callRequest({ amount: 200, requestId: "admr79-req-t1" }, { uid, token: {} });
    const p = r.ok ? await payoutFor(r.result.payoutId) : {};
    record("t1_request_after_approved_change_reflects_new_destination",
      ch.kind === "requested" && rev.kind === "approved" && r.ok &&
        p.payoutMethod === "bank" && p.accountNumber === "111222333444" && p.upiId === null,
      `ch=${ch.kind} rev=${rev.kind} ok=${r.ok} payoutMethod=${p.payoutMethod}(expect bank) accountNumber=${p.accountNumber}(expect 111222333444) upiId=${p.upiId}(expect null)`);
  }

  // t2
  {
    const uid = "admr79-pending-employee";
    await seedEmployee(uid, { payoutMethod: "upi", upiId: "stillcurrent79@okhdfc" });
    await seedWallet(uid, 1000);
    const ch = await requestEmployeePayoutChangeCore(db, uid, { payoutMethod: "bank", accountHolder: "Assoc", bankName: "Pending Bank", accountNumber: "555666777888", ifsc: "PEND0001234" }, Date.now());
    const r = await callRequest({ amount: 150, requestId: "admr79-req-t2" }, { uid, token: {} });
    const p = r.ok ? await payoutFor(r.result.payoutId) : {};
    record("t2_pending_unapproved_change_does_not_affect_request_snapshot",
      ch.kind === "requested" && r.ok && p.payoutMethod === "upi" && p.upiId === "stillcurrent79@okhdfc" && p.accountNumber === null,
      `ch=${ch.kind} ok=${r.ok} payoutMethod=${p.payoutMethod}(expect upi, unapproved change must not apply) upiId=${p.upiId}(expect stillcurrent79@okhdfc)`);
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
