// ============================================================
//  Phase SEC-EMPPAYOUT-1 — employee payouts: one admin transition, immutable amounts
// ============================================================
//
// Run with: JAVA_HOME=/opt/homebrew/opt/openjdk@21 firebase emulators:exec
//             --only firestore "node scripts/phaseSECEMPAY_payout_rules_test.js"

const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const { serverTimestamp } = require("firebase/firestore");

async function main() {
  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
  const env = await initializeTestEnvironment({ projectId: "agrimore-66a4e", firestore: { rules, host: "127.0.0.1", port: 8080 } });
  const results = {};
  const record = (k, p) => p.then(
    () => { results[k] = "PASSED"; console.log(`${k}: PASSED`); },
    (e) => { results[k] = `FAILED — ${e.message}`; console.log(`${k}: FAILED — ${e.message}`); }
  );
  const payout = { employeeId: "emp1", amount: 750, status: "requested" };
  try {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      for (const id of ["q1", "q2", "q3", "q4", "q5", "q6", "q7"]) await db.collection("employee_payouts").doc(id).set(payout);
      await db.collection("employee_payouts").doc("pend1").set({ ...payout, status: "pending" });
      await db.collection("employee_payouts").doc("paid1").set({ ...payout, status: "paid" });
    });
    const adminDb = env.authenticatedContext("admin1", { role: "admin", admin: true }).firestore();
    const emp = env.authenticatedContext("emp1", { role: "employee" }).firestore();
    const doc = (db, id) => db.collection("employee_payouts").doc(id);
    // Exactly what apps/admin/.../employee_payouts_screen.dart _markPaid writes.
    const adminAppWrite = () => ({ status: "paid", paidAt: serverTimestamp(), updatedAt: serverTimestamp() });

    await record("e1_positive_admin_app_mark_paid", assertSucceeds(doc(adminDb, "q1").update(adminAppWrite())));
    await record("e2_positive_pending_with_reference_and_payer",
      assertSucceeds(doc(adminDb, "pend1").update({ ...adminAppWrite(), paymentReference: "UTR123456", paidBy: "admin1" })));
    await record("e3_negative_admin_cannot_change_amount", assertFails(doc(adminDb, "q2").update({ ...adminAppWrite(), amount: 99999 })));
    await record("e4_negative_admin_cannot_reassign_employee", assertFails(doc(adminDb, "q3").update({ ...adminAppWrite(), employeeId: "emp2" })));
    await record("e5_negative_cannot_unpay_paid", assertFails(doc(adminDb, "paid1").update({ status: "requested" })));
    await record("e6_negative_amount_only_edit", assertFails(doc(adminDb, "q4").update({ amount: 1 })));
    await record("e7_negative_paid_by_someone_else", assertFails(doc(adminDb, "q5").update({ ...adminAppWrite(), paidBy: "admin2" })));
    await record("e8_negative_paid_without_paidAt", assertFails(doc(adminDb, "q6").update({ status: "paid" })));
    await record("e9_negative_employee_cannot_mark_own_paid", assertFails(doc(emp, "q7").update(adminAppWrite())));
    await record("e10_positive_employee_reads_own", assertSucceeds(doc(emp, "q7").get()));
  } finally {
    await env.cleanup();
  }
  console.log("\n=== PHASE SEC-EMPPAYOUT-1 SUMMARY ===");
  const total = Object.keys(results).length;
  const passed = Object.values(results).filter((v) => v === "PASSED").length;
  for (const [k, v] of Object.entries(results)) console.log(`  ${v === "PASSED" ? "PASS" : "FAIL"}  ${k}`);
  console.log(`\n${passed}/${total} scenarios passed`);
  if (passed !== total) { console.error("PHASE SEC-EMPPAYOUT-1: FAILED"); process.exitCode = 1; }
  else console.log("PHASE SEC-EMPPAYOUT-1: ALL PASSED");
}
main().catch((e) => { console.error("harness error", e); process.exit(1); });
