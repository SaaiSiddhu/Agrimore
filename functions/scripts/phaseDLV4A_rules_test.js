// Phase DLV-4A — firestore.rules for the rider money collections.
// Phase DLVID1 added rider_identity_change_requests to the same generic
// loop below (identical shape: owner-or-admin read, no client write).
//
// rider_earnings, rider_accounts, rider_cash_ledger, rider_bank_change_requests,
// rider_identity_change_requests, rider_payouts: a rider reads only their
// own, admin reads all, no client writes anything — except admin moving a
// PENDING statement to paid with a bank/UPI reference (the seller_payouts
// rule). Riders still cannot write their own bank fields on
// delivery_partners (DLV-0; changes go through requestRiderBankChange /
// requestRiderIdentityChange).
//
// Run with:
//   firebase emulators:exec --only firestore "node scripts/phaseDLV4A_rules_test.js"
// Honours FIRESTORE_EMULATOR_HOST (set by emulators:exec), falling back to 127.0.0.1:8080.
const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const { serverTimestamp, Timestamp } = require("firebase/firestore");

const [EMU_HOST, EMU_PORT] = (process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080").split(":");
const base = { admin: false, seller: false, delivery_partner: false, employee: false };
const CLAIMS = {
  delivery: { ...base, role: "delivery_partner", delivery_partner: true },
  admin: { ...base, role: "admin", admin: true },
  user: { ...base, role: "user" },
};
const R1 = "dlv4a-r1", R2 = "dlv4a-r2", ADMIN = "dlv4a-admin", CUST = "dlv4a-cust";

let testEnv;
const results = [];
async function scenario(label, expect, fn) {
  try {
    await (expect === "allow" ? assertSucceeds(fn()) : assertFails(fn()));
    results.push({ label, pass: true });
    console.log(`PASSED — ${label}`);
  } catch (e) {
    results.push({ label, pass: false });
    console.log(`FAILED — ${label} :: expected ${expect} — ${String(e.message || e).slice(0, 160)}`);
  }
}
const db = (kind, uid) => testEnv.authenticatedContext(uid, CLAIMS[kind]).firestore();

async function main() {
  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
  testEnv = await initializeTestEnvironment({ projectId: "demo-dlv4a-rules", firestore: { rules, host: EMU_HOST, port: Number(EMU_PORT) } });
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (c) => {
    const f = c.firestore();
    await f.doc(`users/${ADMIN}`).set({ role: "admin" });
    await f.doc(`users/${CUST}`).set({ role: "user" });
    for (const r of [R1, R2]) {
      await f.doc(`users/${r}`).set({ role: "delivery_partner" });
      await f.doc(`delivery_partners/${r}`).set({ status: "approved", bankAccountNumber: "123456789012", ifscCode: "SBIN0001234" });
      await f.doc(`rider_earnings/o-${r}`).set({ riderId: r, total: 55, statementId: null });
      await f.doc(`rider_accounts/${r}`).set({ riderId: r, cashHeld: 480 });
      await f.doc(`rider_cash_ledger/l-${r}`).set({ riderId: r, type: "cash_collected", amount: 480 });
      await f.doc(`rider_bank_change_requests/b-${r}`).set({ riderId: r, status: "pending", upiId: "x@upi" });
      await f.doc(`rider_identity_change_requests/i-${r}`).set({ riderId: r, status: "pending", changeType: "name", proposedValue: "New Name" });
      for (const st of ["pending", "on_hold", "paid"]) {
        await f.doc(`rider_payouts/${r}_${st}`).set({ riderId: r, weekKey: "2026-W38", amount: 100, status: st });
      }
    }
  });
  const r1 = db("delivery", R1), adm = db("admin", ADMIN), cust = db("user", CUST);

  console.log("=== PHASE DLV-4A — rider money rules ===");
  const cols = [["rider_earnings", (r) => `o-${r}`], ["rider_accounts", (r) => r], ["rider_cash_ledger", (r) => `l-${r}`],
    ["rider_bank_change_requests", (r) => `b-${r}`], ["rider_identity_change_requests", (r) => `i-${r}`],
    ["rider_payouts", (r) => `${r}_pending`]];
  for (const [col, id] of cols) {
    await scenario(`r_${col}_own_read`, "allow", () => r1.doc(`${col}/${id(R1)}`).get());
    await scenario(`r_${col}_other_riders_read`, "deny", () => r1.doc(`${col}/${id(R2)}`).get());
    await scenario(`r_${col}_customer_read`, "deny", () => cust.doc(`${col}/${id(R1)}`).get());
    await scenario(`r_${col}_admin_read`, "allow", () => adm.doc(`${col}/${id(R1)}`).get());
  }
  await scenario("q_rider_lists_own_earnings", "allow", () => r1.collection("rider_earnings").where("riderId", "==", R1).get());
  await scenario("q_rider_lists_everyones_earnings", "deny", () => r1.collection("rider_earnings").get());

  // No client writes.
  await scenario("w_rider_edits_own_earning", "deny", () => r1.doc(`rider_earnings/o-${R1}`).update({ total: 9999 }));
  await scenario("w_rider_creates_earning", "deny", () => r1.doc("rider_earnings/fake").set({ riderId: R1, total: 9999 }));
  await scenario("w_rider_zeroes_cash_held", "deny", () => r1.doc(`rider_accounts/${R1}`).update({ cashHeld: 0 }));
  await scenario("w_rider_creates_own_account", "deny", () => r1.doc("rider_accounts/new").set({ riderId: "new", cashHeld: -500 }));
  await scenario("w_rider_deletes_ledger_line", "deny", () => r1.doc(`rider_cash_ledger/l-${R1}`).delete());
  await scenario("w_rider_approves_own_bank_change", "deny", () => r1.doc(`rider_bank_change_requests/b-${R1}`).update({ status: "approved" }));
  await scenario("w_rider_approves_own_identity_change", "deny", () => r1.doc(`rider_identity_change_requests/i-${R1}`).update({ status: "approved" }));
  await scenario("w_rider_marks_own_payout_paid", "deny", () => r1.doc(`rider_payouts/${R1}_pending`).update({
    status: "paid", paidAt: Timestamp.now(), paymentReference: "UTR123456", paidBy: R1 }));
  await scenario("w_admin_edits_cash_directly", "deny", () => adm.doc(`rider_accounts/${R1}`).update({ cashHeld: 0 }));
  await scenario("w_admin_creates_earning", "deny", () => adm.doc("rider_earnings/fake2").set({ riderId: R1, total: 10 }));
  await scenario("w_rider_writes_own_bank_fields", "deny", () => r1.doc(`delivery_partners/${R1}`).update({ bankAccountNumber: "999999999999" }));

  // The admin paid-transition.
  const paid = (extra = {}) => ({ status: "paid", paidAt: Timestamp.now(), paymentReference: "UTR123456", paidBy: ADMIN, payoutMethod: "upi", updatedAt: serverTimestamp(), ...extra });
  await scenario("t01_admin_pays_pending_with_reference", "allow", () => adm.doc(`rider_payouts/${R1}_pending`).update(paid()));
  await scenario("t02_admin_cannot_pay_an_on_hold_statement", "deny", () => adm.doc(`rider_payouts/${R1}_on_hold`).update(paid()));
  await scenario("t03_admin_cannot_unpay", "deny", () => adm.doc(`rider_payouts/${R1}_paid`).update({ status: "pending" }));
  await scenario("t04_admin_cannot_change_the_amount", "deny", () => adm.doc(`rider_payouts/${R2}_pending`).update(paid({ amount: 1 })));
  await scenario("t05_reference_required", "deny", () => adm.doc(`rider_payouts/${R2}_pending`).update(paid({ paymentReference: "x" })));
  await scenario("t06_paid_by_must_be_the_admin", "deny", () => adm.doc(`rider_payouts/${R2}_pending`).update(paid({ paidBy: "someone" })));
  await scenario("t07_method_bank_or_upi_only", "deny", () => adm.doc(`rider_payouts/${R2}_pending`).update(paid({ payoutMethod: "cash" })));
  await scenario("t08_admin_cannot_create_or_delete", "deny", () => adm.doc("rider_payouts/new").set({ riderId: R1, amount: 5, status: "pending" }));
  await scenario("t09_admin_cannot_delete", "deny", () => adm.doc(`rider_payouts/${R2}_paid`).delete());

  await testEnv.cleanup();
  const failed = results.filter((r) => !r.pass);
  console.log(`\n${results.length - failed.length}/${results.length} passed`);
  if (failed.length) { console.log("PHASE DLV-4A rules: FAILED"); process.exit(1); }
  console.log("PHASE DLV-4A rules: ALL PASSED");
  process.exit(0);
}
main().catch((e) => { console.error(e); process.exit(1); });
