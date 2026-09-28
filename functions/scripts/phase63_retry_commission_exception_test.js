// Phase ADMR-19 — retryCommissionException (employeeCommission.ts)
//
// FINDING: payEmployeeCommissionOnDelivery only fires on the transition INTO
// a delivered-equivalent status. An order whose commission rate could not be
// resolved gets a commission_exceptions record and commissionPaid stays
// false — but nothing else ever re-writes that order's orderStatus, so the
// trigger structurally cannot retry itself. Before this phase, nothing in
// the codebase ever read commission_exceptions at all (confirmed by
// exhaustive grep), despite firestore.rules already gating it `allow read:
// if isAdmin()` "for admin visibility" — the rule anticipated a screen and
// a resolution path that were never built. The only working recovery was a
// manual, --apply-gated script hitting the LIVE Firestore REST API directly
// with the runner's own OAuth token and three non-atomic writes — not
// something this skill permits running, not admin-discoverable, not atomic.
//
// This test exercises the REAL compiled
// functions/lib/customer/employeeCommission.js's retryCommissionException
// against the Firestore emulator — a v2 onCall, wrapped and invoked the same
// way as phase59's markEmployeePayoutPaid/rejectEmployeePayout.
//
// Run with:
//   firebase emulators:exec --only firestore,functions,auth \
//     "node scripts/phase63_retry_commission_exception_test.js"
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || "agrimore-66a4e";

const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: "agrimore-66a4e" });
const db = admin.firestore();

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { retryCommissionException } = require("../lib/customer/employeeCommission");
const wrapped = test.wrap(retryCommissionException);

async function callRetry(payload, auth) {
  try {
    return { ok: true, result: await wrapped({ data: payload, auth }) };
  } catch (e) {
    return { ok: false, code: e.code, message: e.message, details: e.details };
  }
}

const ADMIN_AUTH = { uid: "phase63-admin", token: { admin: true } };
const NON_ADMIN_AUTH = { uid: "phase63-not-admin", token: {} };

async function seedException(id, fields) {
  await db.collection("commission_exceptions").doc(id).set({
    orderId: fields.orderId,
    orderNumber: fields.orderNumber ?? null,
    employeeUid: fields.employeeUid,
    orderMode: fields.orderMode ?? "B2C",
    total: fields.total ?? null,
    reason: fields.reason ?? "no_rate_configured",
    status: fields.status ?? "unresolved",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}
async function seedOrder(id, fields) {
  await db.collection("orders").doc(id).set({
    orderNumber: fields.orderNumber ?? id,
    employeeUid: fields.employeeUid,
    orderMode: fields.orderMode ?? "B2C",
    orderStatus: "delivered",
    subtotal: fields.subtotal ?? 0,
    discount: fields.discount ?? 0,
    total: fields.total ?? 0,
    commissionPaid: fields.commissionPaid ?? false,
  });
}
async function seedEmployee(uid, fields) {
  await db.collection("employees").doc(uid).set({ status: "approved", ...fields });
}
async function seedWallet(uid, balance) {
  await db.collection("wallets").doc(uid).set({ balance, coins: 0 });
}
async function exceptionDoc(id) {
  return (await db.collection("commission_exceptions").doc(id).get()).data() || {};
}
async function orderDoc(id) {
  return (await db.collection("orders").doc(id).get()).data() || {};
}
async function wallet(uid) {
  return (await db.collection("wallets").doc(uid).get()).data() || {};
}
async function creditTxCount(orderId) {
  const snap = await db.collection("wallet_transactions")
    .where("orderId", "==", orderId).where("source", "==", "commission").get();
  return snap.size;
}

async function main() {
  const results = {};
  let allPassed = true;
  const record = (k, p, d) => { results[k] = p; console.log(`${k}: ${p ? "PASSED" : "FAILED"} — ${d}`); if (!p) allPassed = false; };

  console.log("=== PHASE ADMR-19 — retryCommissionException ===");

  // 1 — non-admin cannot retry.
  {
    const eid = "phase63-e1";
    await seedException(eid, { orderId: "phase63-o1", employeeUid: "phase63-emp1" });
    const r = await callRetry({ exceptionId: eid }, NON_ADMIN_AUTH);
    const e = await exceptionDoc(eid);
    record("s1_non_admin_denied", !r.ok && r.code === "permission-denied" && e.status === "unresolved",
      `code=${r.code} status=${e.status}(expect unresolved)`);
  }

  // 2 — still unresolved: settings/commission has no employeeRetailRate at
  // all, employee has no override. Retry correctly refuses without
  // mutating anything.
  {
    const eid = "phase63-e2", oid = "phase63-o2", uid = "phase63-emp2";
    await seedEmployee(uid, {});
    await seedOrder(oid, { employeeUid: uid, subtotal: 1000, discount: 0 });
    await seedException(eid, { orderId: oid, employeeUid: uid, reason: "no_rate_configured" });
    // settings/commission deliberately left unset/empty for this scenario.
    await db.collection("settings").doc("commission").set({});
    const r = await callRetry({ exceptionId: eid }, ADMIN_AUTH);
    const e = await exceptionDoc(eid);
    const o = await orderDoc(oid);
    record("s2_still_unresolved_refused_no_mutation",
      !r.ok && r.code === "failed-precondition" && r.details?.reason === "no_rate_configured" &&
      e.status === "unresolved" && o.commissionPaid === false,
      `code=${r.code} reason=${r.details?.reason} exceptionStatus=${e.status} orderPaid=${o.commissionPaid}`);
  }

  // 3 — THE FIX: settings/commission now has a real employeeRetailRate ->
  // retry pays the associate atomically and marks the exception resolved.
  {
    const eid = "phase63-e3", oid = "phase63-o3", uid = "phase63-emp3";
    await seedEmployee(uid, {});
    await seedWallet(uid, 0);
    await seedOrder(oid, { orderNumber: "ORD-3", employeeUid: uid, subtotal: 1000, discount: 100 });
    await seedException(eid, { orderId: oid, orderNumber: "ORD-3", employeeUid: uid, total: 900, reason: "no_rate_configured" });
    await db.collection("settings").doc("commission").set({ employeeRetailRate: 10, employeeDefaultRate: 5 });

    const r = await callRetry({ exceptionId: eid }, ADMIN_AUTH);
    const e = await exceptionDoc(eid);
    const o = await orderDoc(oid);
    const w = await wallet(uid);
    const txCount = await creditTxCount(oid);
    // grossAmount = max(0, 1000-100) = 900; commission = 900 * 10% = 90.
    record("s3_retry_pays_associate_and_resolves_exception",
      r.ok && r.result.alreadyResolved === false &&
      o.commissionPaid === true && o.commissionAmount === 90 &&
      w.balance === 90 && txCount === 1 &&
      e.status === "resolved" && e.resolvedRate === 10 && e.resolvedRateSource === "configured_mode_rate",
      `ok=${r.ok} orderPaid=${o.commissionPaid} amount=${o.commissionAmount}(expect 90) walletBalance=${w.balance}(expect 90) txCount=${txCount}(expect 1) exceptionStatus=${e.status} resolvedRate=${e.resolvedRate}`);
  }

  // 4 — retrying an already-resolved exception is a harmless no-op, no
  // double credit.
  {
    const eid = "phase63-e3", oid = "phase63-o3", uid = "phase63-emp3"; // same as scenario 3
    const r = await callRetry({ exceptionId: eid }, ADMIN_AUTH);
    const w = await wallet(uid);
    const txCount = await creditTxCount(oid);
    record("s4_retry_already_resolved_is_noop",
      r.ok && r.result.alreadyResolved === true && w.balance === 90 && txCount === 1,
      `ok=${r.ok} alreadyResolved=${r.result?.alreadyResolved} balance=${w.balance}(expect 90, unchanged) txCount=${txCount}(expect 1, unchanged)`);
  }

  // 5 — the order was paid some other way since the exception was recorded
  // (e.g. the manual reconciliation script) — retry closes the loop on the
  // exception without crediting a second time.
  {
    const eid = "phase63-e5", oid = "phase63-o5", uid = "phase63-emp5";
    await seedEmployee(uid, {});
    await seedWallet(uid, 500);
    await seedOrder(oid, { employeeUid: uid, subtotal: 1000, discount: 0, commissionPaid: true });
    await seedException(eid, { orderId: oid, employeeUid: uid, reason: "no_rate_configured" });

    const r = await callRetry({ exceptionId: eid }, ADMIN_AUTH);
    const e = await exceptionDoc(eid);
    const w = await wallet(uid);
    const txCount = await creditTxCount(oid);
    record("s5_already_paid_elsewhere_closes_loop_no_double_credit",
      r.ok && r.result.alreadyResolved === true && e.status === "resolved" &&
      e.resolution === "already_paid_elsewhere" && w.balance === 500 && txCount === 0,
      `ok=${r.ok} exceptionStatus=${e.status} resolution=${e.resolution} balance=${w.balance}(expect 500, untouched) txCount=${txCount}(expect 0)`);
  }

  // 6 — a wallet that EXISTS but has no createdAt field (the exact shape
  // requestEmployeePayout.ts's own {merge:true} debit write produces for a
  // brand-new associate whose first-ever wallet touch is a payout request,
  // not a commission credit) must not crash the payment transaction.
  // Caught by this test itself on the first run, pre-fix: "Cannot use
  // \"undefined\" as a Firestore value (found in field \"createdAt\")".
  {
    const eid = "phase63-e6", oid = "phase63-o6", uid = "phase63-emp6";
    await seedEmployee(uid, {});
    await db.collection("wallets").doc(uid).set({ balance: 0, coins: 0 }); // no createdAt, deliberately
    await seedOrder(oid, { employeeUid: uid, subtotal: 500, discount: 0 });
    await seedException(eid, { orderId: oid, employeeUid: uid, reason: "no_rate_configured" });
    await db.collection("settings").doc("commission").set({ employeeRetailRate: 10, employeeDefaultRate: 5 });

    const r = await callRetry({ exceptionId: eid }, ADMIN_AUTH);
    const w = await wallet(uid);
    record("s6_wallet_missing_createdAt_field_does_not_crash",
      r.ok && r.result.alreadyResolved === false && w.balance === 50 && w.createdAt !== undefined,
      `ok=${r.ok} message=${r.message} balance=${w.balance}(expect 50) createdAt=${w.createdAt ? "set" : "MISSING"}`);
  }

  // 7 — a missing exception id is refused as not-found, not a crash.
  {
    const r = await callRetry({ exceptionId: "phase63-does-not-exist" }, ADMIN_AUTH);
    record("s7_missing_exception_is_not_found", !r.ok && r.code === "not-found", `code=${r.code}`);
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
