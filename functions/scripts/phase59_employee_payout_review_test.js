// Phase ADMR-3 — reviewEmployeePayout.ts (markEmployeePayoutPaid, rejectEmployeePayout)
//
// FINDING: firestore.rules' employee_payouts update rule only ever permitted
// a transition INTO 'paid' — there was no branch for 'rejected' at all, so
// employee_payout_detail_screen.dart's reject write had ALWAYS failed
// permission-denied, and the associate's wallet — debited immediately at
// request time by requestEmployeePayout.ts — had no way back. Separately,
// the paid write's field name (transactionRef) was never in the rules'
// hasOnly() allowlist (paymentReference), so entering a reference failed the
// whole update; leaving it blank silently succeeded with zero payment
// evidence.
//
// Exercises the REAL compiled functions/lib/customer/reviewEmployeePayout.js
// against the Firestore emulator. Both are v2 onCall — wrapped and invoked
// as wrapped({data, auth}), mirroring phase27_stock_integrity_test.js's
// createOrder pattern (same generation, same test style).
//
// Run with:
//   firebase emulators:exec --only firestore,functions,auth \
//     "node scripts/phase59_employee_payout_review_test.js"
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: "agrimore-66a4e" });
const db = admin.firestore();

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { markEmployeePayoutPaid, rejectEmployeePayout } = require("../lib/customer/reviewEmployeePayout");
const wrappedPaid = test.wrap(markEmployeePayoutPaid);
const wrappedReject = test.wrap(rejectEmployeePayout);

async function callPaid(payload, auth) {
  try {
    return { ok: true, result: await wrappedPaid({ data: payload, auth }) };
  } catch (e) {
    return { ok: false, code: e.code, message: e.message, details: e.details };
  }
}
async function callReject(payload, auth) {
  try {
    return { ok: true, result: await wrappedReject({ data: payload, auth }) };
  } catch (e) {
    return { ok: false, code: e.code, message: e.message, details: e.details };
  }
}

const ADMIN_AUTH = { uid: "phase59-admin", token: { admin: true } };
const EMPLOYEE_AUTH = { uid: "phase59-employee-caller", token: {} };

async function seedWallet(uid, balance) {
  await db.collection("wallets").doc(uid).set({ balance, coins: 0 });
}
async function seedPayout(id, fields) {
  await db.collection("employee_payouts").doc(id).set({
    employeeId: fields.employeeId,
    amount: fields.amount,
    status: fields.status ?? "requested",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    ...fields.extra,
  });
}
async function payout(id) {
  return (await db.collection("employee_payouts").doc(id).get()).data() || {};
}
async function wallet(uid) {
  return (await db.collection("wallets").doc(uid).get()).data() || {};
}
async function creditTxCount(payoutId) {
  const snap = await db.collection("wallet_transactions").where("referenceId", "==", payoutId).where("type", "==", "credit").get();
  return snap.size;
}

async function main() {
  const results = {};
  let allPassed = true;
  const record = (k, p, d) => { results[k] = p; console.log(`${k}: ${p ? "PASSED" : "FAILED"} — ${d}`); if (!p) allPassed = false; };

  console.log("=== PHASE ADMR-3 — employee payout review (reject-recredit, paid reference) ===");

  // 1 — non-admin cannot reject or mark paid.
  {
    await seedWallet("phase59-e1", 500);
    await seedPayout("phase59-p1", { employeeId: "phase59-e1", amount: 200 });
    const r1 = await callReject({ payoutId: "phase59-p1", reason: "bad details" }, EMPLOYEE_AUTH);
    const r2 = await callPaid({ payoutId: "phase59-p1", paymentReference: "UTR12345" }, EMPLOYEE_AUTH);
    record("s1_non_admin_denied_both_actions",
      !r1.ok && r1.code === "permission-denied" && !r2.ok && r2.code === "permission-denied",
      `reject=${r1.code} paid=${r2.code}`);
  }

  // 2 — THE FINDING, reject path: wallet is credited back exactly once, a
  // compensating wallet_transactions credit entry exists, status flips.
  {
    const uid = "phase59-e2", pid = "phase59-p2";
    await seedWallet(uid, 500);
    await seedPayout(pid, { employeeId: uid, amount: 300 });
    const r = await callReject({ payoutId: pid, reason: "Incorrect bank details" }, ADMIN_AUTH);
    const w = await wallet(uid);
    const p = await payout(pid);
    const txCount = await creditTxCount(pid);
    record("s2_reject_credits_wallet_back_exactly_once",
      r.ok && w.balance === 800 && p.status === "rejected" && p.rejectionReason === "Incorrect bank details" && txCount === 1,
      `ok=${r.ok} balance=${w.balance}(expect 800) status=${p.status} creditTxCount=${txCount}(expect 1)`);
  }

  // 3 — retry-safety: rejecting an ALREADY-rejected payout does not
  // double-credit (the live in-transaction re-check, not a stale payload).
  {
    const uid = "phase59-e2", pid = "phase59-p2"; // same as scenario 2, already rejected
    const again = await callReject({ payoutId: pid, reason: "retry" }, ADMIN_AUTH);
    const w = await wallet(uid);
    const txCount = await creditTxCount(pid);
    record("s3_retried_reject_does_not_double_credit",
      again.ok && again.result.alreadyRejected === true && w.balance === 800 && txCount === 1,
      `alreadyRejected=${again.ok && again.result.alreadyRejected} balance=${w.balance}(expect 800, unchanged) creditTxCount=${txCount}(expect 1)`);
  }

  // 4 — reject without a reason is refused (no state change, no credit).
  {
    const uid = "phase59-e4", pid = "phase59-p4";
    await seedWallet(uid, 100);
    await seedPayout(pid, { employeeId: uid, amount: 50 });
    const r = await callReject({ payoutId: pid, reason: "" }, ADMIN_AUTH);
    const w = await wallet(uid);
    const p = await payout(pid);
    record("s4_reject_without_reason_refused",
      !r.ok && r.details?.reason === "reason_required" && w.balance === 100 && p.status === "requested",
      `code=${r.code} reason=${r.details?.reason} balance=${w.balance}(expect 100, untouched) status=${p.status}`);
  }

  // 5 — THE OTHER FINDING, paid path: a valid payment reference is recorded
  // (the old client field name, transactionRef, is gone — paymentReference
  // is now the one and only field, matching the pre-existing rules'
  // hasOnly() allowlist that no callable ever satisfied before this phase).
  {
    const uid = "phase59-e5", pid = "phase59-p5";
    await seedWallet(uid, 900);
    await seedPayout(pid, { employeeId: uid, amount: 400 });
    const r = await callPaid({ payoutId: pid, paymentReference: "UTR998877" }, ADMIN_AUTH);
    const p = await payout(pid);
    const w = await wallet(uid);
    record("s5_paid_records_reference_and_does_not_touch_wallet",
      r.ok && p.status === "paid" && p.paymentReference === "UTR998877" && p.paidBy === "phase59-admin" && w.balance === 900,
      `ok=${r.ok} status=${p.status} ref=${p.paymentReference} paidBy=${p.paidBy} balance=${w.balance}(expect 900, paid does not move wallet money — it was already debited at request time)`);
  }

  // 6 — a too-short reference is refused (this is what "leave it blank"
  // used to silently satisfy before this phase — now it is a real,
  // enforced minimum instead of an accidental rules loophole).
  {
    const uid = "phase59-e6", pid = "phase59-p6";
    await seedWallet(uid, 100);
    await seedPayout(pid, { employeeId: uid, amount: 60 });
    const r = await callPaid({ payoutId: pid, paymentReference: "ab" }, ADMIN_AUTH);
    const p = await payout(pid);
    record("s6_too_short_reference_refused",
      !r.ok && r.details?.reason === "bad_reference" && p.status === "requested",
      `code=${r.code} reason=${r.details?.reason} status=${p.status}`);
  }

  // 7 — retry-safety on paid: the SAME (payoutId, reference) retried is a
  // harmless "already"; a DIFFERENT reference on an already-paid row is
  // refused rather than silently overwriting the recorded evidence.
  {
    const uid = "phase59-e5", pid = "phase59-p5"; // already paid with UTR998877 in scenario 5
    const same = await callPaid({ payoutId: pid, paymentReference: "UTR998877" }, ADMIN_AUTH);
    const different = await callPaid({ payoutId: pid, paymentReference: "UTR000000" }, ADMIN_AUTH);
    const p = await payout(pid);
    record("s7_paid_retry_idempotent_different_reference_refused",
      same.ok && same.result.alreadyPaid === true &&
      !different.ok && different.details?.reason === "not_requested" &&
      p.paymentReference === "UTR998877",
      `same.alreadyPaid=${same.ok && same.result.alreadyPaid} different.code=${different.code}/${different.details?.reason} finalRef=${p.paymentReference}(expect unchanged UTR998877)`);
  }

  // 8 — cross-state guards: cannot reject an already-paid row; cannot
  // mark-paid an already-rejected row.
  {
    const paidPid = "phase59-p5"; // already paid
    const rejectedPid = "phase59-p2"; // already rejected
    const r1 = await callReject({ payoutId: paidPid, reason: "too late" }, ADMIN_AUTH);
    const r2 = await callPaid({ payoutId: rejectedPid, paymentReference: "UTR555555" }, ADMIN_AUTH);
    record("s8_cross_state_guards_hold",
      !r1.ok && r1.details?.reason === "not_requested" && !r2.ok && r2.details?.reason === "not_requested",
      `reject-a-paid-row=${r1.code}/${r1.details?.reason} pay-a-rejected-row=${r2.code}/${r2.details?.reason}`);
  }

  // 9 — a missing payout is refused as not_found, not a crash.
  {
    const r = await callReject({ payoutId: "phase59-does-not-exist", reason: "n/a" }, ADMIN_AUTH);
    record("s9_missing_payout_is_not_found", !r.ok && r.details?.reason === "not_found", `code=${r.code} reason=${r.details?.reason}`);
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
