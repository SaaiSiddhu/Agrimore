// Phase D, Workstream 3 — firestore.rules' ownerCannotChangeOrderFinancials()
// denylist extension (productCreditApplied/productCreditHoldId/
// productCreditReversed). Proves the new entries against the real
// Firestore emulator, and that the pre-existing legitimate owner-cancel
// path (order_provider.dart's cancelOrder(), which writes only
// orderStatus) still works — same harness shape as phase5b_rules_test.js.
// Run with: node scripts/phaseD_rules_test.js  (Firestore emulator must be
// running on 127.0.0.1:8080)
const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertSucceeds, assertFails } = require("@firebase/rules-unit-testing");

async function main() {
  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");

  const testEnv = await initializeTestEnvironment({
    projectId: "agrimore-66a4e",
    firestore: {
      rules,
      host: "127.0.0.1",
      port: 8080,
    },
  });

  let scenario1 = "NOT RUN";
  let scenario2a = "NOT RUN";
  let scenario2b = "NOT RUN";
  let scenario3 = "NOT RUN";

  try {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.collection("users").doc("phaseD-rules-customer").set({ role: "user" });
      const baseOrder = {
        userId: "phaseD-rules-customer",
        sellerId: "phaseD-rules-seller",
        orderStatus: "pending",
        status: "pending",
        subtotal: 1000,
        total: 700,
        productCreditApplied: 300,
        productCreditHoldId: "phaseD-rules-hold",
        productCreditReversed: false,
      };
      await db.collection("orders").doc("phaseD-rules-order1").set(baseOrder);
      await db.collection("orders").doc("phaseD-rules-order2").set(baseOrder);
      await db.collection("orders").doc("phaseD-rules-order3").set(baseOrder);
    });

    // Same realistic full-claim-set fake token shape phase5b_rules_test.js
    // established — the rules emulator's CEL evaluator errors on missing
    // claim properties rather than treating them as falsy.
    const customerClaims = {
      email: "phaseD-rules-customer@phaseD-rules-test.example",
      role: "user", admin: false, seller: false, sellerApproved: false,
      delivery_partner: false, deliveryApproved: false, employee: false, employeeApproved: false,
    };
    const customerDb = testEnv
      .authenticatedContext("phaseD-rules-customer", customerClaims)
      .firestore();

    // Scenario 1: owner cannot update productCreditApplied on their own order.
    try {
      await customerDb.collection("orders").doc("phaseD-rules-order1").update({
        productCreditApplied: 999,
      });
      scenario1 = "FAILED — owner was able to rewrite productCreditApplied on their own order!";
    } catch (e) {
      scenario1 = `PASSED — rejected as expected. code=${e.code} message=${e.message}`;
    }

    // Scenario 2: owner cannot update productCreditHoldId or
    // productCreditReversed either.
    try {
      await customerDb.collection("orders").doc("phaseD-rules-order2").update({
        productCreditHoldId: "some-other-hold",
      });
      scenario2a = "FAILED — owner was able to rewrite productCreditHoldId on their own order!";
    } catch (e) {
      scenario2a = `PASSED — rejected as expected. code=${e.code} message=${e.message}`;
    }
    try {
      await customerDb.collection("orders").doc("phaseD-rules-order2").update({
        productCreditReversed: true,
      });
      scenario2b = "FAILED — owner was able to rewrite productCreditReversed on their own order!";
    } catch (e) {
      scenario2b = `PASSED — rejected as expected. code=${e.code} message=${e.message}`;
    }

    // Scenario 3: owner CAN still cancel their own order — proves the
    // denylist extension did not break the legitimate cancellation path
    // (order_provider.dart's cancelOrder() writes only orderStatus/status).
    try {
      await assertSucceeds(
        customerDb.collection("orders").doc("phaseD-rules-order3").update({
          orderStatus: "cancelled",
        })
      );
      scenario3 = "PASSED — legitimate owner cancellation still succeeds";
    } catch (e) {
      scenario3 = `FAILED — owner cancel was rejected but should have succeeded: ${e.message}`;
    }
  } finally {
    await testEnv.cleanup();
  }

  console.log("=== PHASE D — RULES TEST RESULTS (ownerCannotChangeOrderFinancials denylist) ===");
  console.log("Scenario 1 (owner cannot change productCreditApplied):", scenario1);
  console.log("Scenario 2a (owner cannot change productCreditHoldId):", scenario2a);
  console.log("Scenario 2b (owner cannot change productCreditReversed):", scenario2b);
  console.log("Scenario 3 (owner can still cancel their own order):", scenario3);

  const allPassed = [scenario1, scenario2a, scenario2b, scenario3].every((s) => s.startsWith("PASSED"));
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phaseD rules test:", e);
  process.exit(1);
});
