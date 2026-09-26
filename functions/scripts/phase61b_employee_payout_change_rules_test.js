// ============================================================
//  Phase ADMR-5 — firestore.rules: employees payout-field denylist,
//  employee_payout_change_requests, employee_wallets
// ============================================================
//
// Complements phase61_employee_payout_change_test.js, which exercises the
// callables directly via the Admin SDK (bypassing rules entirely) and so
// proves nothing about what a CLIENT can or cannot do. This file proves the
// rules themselves: the associate can no longer write payout fields
// directly to employees/{uid}, and the two new collections are
// Cloud-Functions-only with owner-or-admin read.
//
// Mirrors phaseSECEMPAY_payout_rules_test.js's own initializeTestEnvironment
// pattern exactly.
//
// Run with: JAVA_HOME=/opt/homebrew/opt/openjdk@21 firebase emulators:exec
//             --only firestore "node scripts/phase61b_employee_payout_change_rules_test.js"

const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");

async function main() {
  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
  const env = await initializeTestEnvironment({ projectId: "agrimore-66a4e", firestore: { rules, host: "127.0.0.1", port: 8080 } });
  const results = {};
  const record = (k, p) => p.then(
    () => { results[k] = "PASSED"; console.log(`${k}: PASSED`); },
    (e) => { results[k] = `FAILED — ${e.message}`; console.log(`${k}: FAILED — ${e.message}`); }
  );

  try {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await db.collection("employees").doc("assoc1").set({ uid: "assoc1", status: "pending" });
      await db.collection("employee_payout_change_requests").doc("req1").set({ employeeId: "assoc1", status: "pending" });
      await db.collection("employee_wallets").doc("assoc1").set({ employeeId: "assoc1", payoutChangePending: "req1" });
    });

    const owner = env.authenticatedContext("assoc1", { role: "employee" }).firestore();
    const otherEmployee = env.authenticatedContext("assoc2", { role: "employee" }).firestore();
    const admin = env.authenticatedContext("admin1", { role: "admin", admin: true }).firestore();
    const anon = env.unauthenticatedContext().firestore();

    // ── employees/{uid} payout-field denylist ──
    await record("d1_owner_cannot_write_accountNumber_directly",
      assertFails(owner.collection("employees").doc("assoc1").update({ accountNumber: "999999999999" })));
    await record("d2_owner_cannot_write_ifscCode_directly",
      assertFails(owner.collection("employees").doc("assoc1").update({ ifscCode: "HACK0000001" })));
    await record("d3_owner_cannot_write_upiId_directly",
      assertFails(owner.collection("employees").doc("assoc1").update({ upiId: "attacker@upi" })));
    await record("d4_owner_cannot_write_payoutMethod_directly",
      assertFails(owner.collection("employees").doc("assoc1").update({ payoutMethod: "upi" })));
    await record("d5_admin_still_can_write_payout_fields",
      assertSucceeds(admin.collection("employees").doc("assoc1").update({ accountNumber: "111122223333" })));
    // Positive control: the update rule as a WHOLE is not accidentally
    // denying everything — an already-allowed value-guarded field still works.
    await record("d6_owner_can_still_write_an_unrelated_allowed_field",
      assertSucceeds(owner.collection("employees").doc("assoc1").update({ status: "pending" })));

    // ── employee_payout_change_requests ──
    await record("r1_owner_reads_own_request", assertSucceeds(owner.collection("employee_payout_change_requests").doc("req1").get()));
    await record("r2_admin_reads_any_request", assertSucceeds(admin.collection("employee_payout_change_requests").doc("req1").get()));
    await record("r3_other_employee_cannot_read", assertFails(otherEmployee.collection("employee_payout_change_requests").doc("req1").get()));
    await record("r4_unauthenticated_cannot_read", assertFails(anon.collection("employee_payout_change_requests").doc("req1").get()));
    await record("r5_owner_cannot_write_directly", assertFails(owner.collection("employee_payout_change_requests").doc("req1").update({ status: "approved" })));
    await record("r6_admin_cannot_write_directly_either", assertFails(admin.collection("employee_payout_change_requests").doc("req1").update({ status: "approved" })));

    // ── employee_wallets ──
    await record("w1_owner_reads_own_wallet_marker", assertSucceeds(owner.collection("employee_wallets").doc("assoc1").get()));
    await record("w2_admin_reads_any_wallet_marker", assertSucceeds(admin.collection("employee_wallets").doc("assoc1").get()));
    await record("w3_other_employee_cannot_read", assertFails(otherEmployee.collection("employee_wallets").doc("assoc1").get()));
    await record("w4_owner_cannot_write_directly", assertFails(owner.collection("employee_wallets").doc("assoc1").update({ payoutChangePending: null })));
  } finally {
    await env.cleanup();
  }

  console.log("\n=== PHASE ADMR-5 RULES SUMMARY ===");
  const total = Object.keys(results).length;
  const passed = Object.values(results).filter((v) => v === "PASSED").length;
  for (const [k, v] of Object.entries(results)) console.log(`  ${v === "PASSED" ? "PASS" : "FAIL"}  ${k}`);
  console.log(`\n${passed}/${total} scenarios passed`);
  if (passed !== total) { console.error("PHASE ADMR-5 RULES: FAILED"); process.exitCode = 1; }
  else console.log("PHASE ADMR-5 RULES: ALL PASSED");
}
main().catch((e) => { console.error("harness error", e); process.exit(1); });
