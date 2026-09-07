// Phase FIX-4B (N-9) — firestore.rules' commissionReversed denylist
// addition to ownerCannotChangeOrderFinancials() and
// orderFulfilmentCannotChangeProtectedFields(). Proves the new entries
// against the real Firestore emulator, following phaseD_rules_test.js's
// own harness shape exactly (that file proved the identical addition for
// productCreditReversed under Phase D-1's DEFECT D-0).
//
// Why this matters: without this denylist entry, an owner or seller could
// pre-set commissionReversed:true on their own order, and
// reverseEmployeeCommissionOnCancellation's own pre-filter
// (`if (after.commissionReversed === true) return`) would silently no-op
// on a genuine future cancellation — permanently letting an associate keep
// commission on an order that was actually cancelled/refunded.
//
// Run with: node scripts/phase44b_commission_reversal_rules_test.js
// (Firestore emulator must be running on 127.0.0.1:8080)
const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertSucceeds } = require("@firebase/rules-unit-testing");

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
  let scenario2 = "NOT RUN";
  let scenario3 = "NOT RUN";
  let scenario4 = "NOT RUN";

  try {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.collection("users").doc("p44b-customer").set({ role: "user" });
      const baseOrder = {
        userId: "p44b-customer",
        sellerId: "p44b-seller",
        orderStatus: "pending",
        status: "pending",
        subtotal: 1000,
        total: 1000,
        employeeUid: "p44b-employee",
        commissionPaid: true,
        commissionAmount: 100,
        commissionReversed: false,
      };
      await db.collection("orders").doc("p44b-order1").set(baseOrder);
      await db.collection("orders").doc("p44b-order2").set(baseOrder);
      await db.collection("orders").doc("p44b-order3").set(baseOrder);
      await db.collection("orders").doc("p44b-order4").set(baseOrder);
    });

    // Same realistic full-claim-set fake token shape phase5b/phaseD's own
    // rules tests established — the rules emulator's CEL evaluator errors
    // on missing claim properties rather than treating them as falsy.
    const customerClaims = {
      email: "p44b-customer@p44b-test.example",
      role: "user", admin: false, seller: false, sellerApproved: false,
      delivery_partner: false, deliveryApproved: false, employee: false, employeeApproved: false,
    };
    const customerDb = testEnv.authenticatedContext("p44b-customer", customerClaims).firestore();

    const sellerClaims = {
      email: "p44b-seller@p44b-test.example",
      role: "seller", admin: false, seller: true, sellerApproved: true,
      delivery_partner: false, deliveryApproved: false, employee: false, employeeApproved: false,
    };
    const sellerDb = testEnv.authenticatedContext("p44b-seller", sellerClaims).firestore();

    // Scenario 1: owner cannot pre-set commissionReversed:true on their own
    // order to suppress a future genuine reversal.
    try {
      await customerDb.collection("orders").doc("p44b-order1").update({
        commissionReversed: true,
      });
      scenario1 = "FAILED — owner was able to pre-set commissionReversed on their own order!";
    } catch (e) {
      scenario1 = `PASSED — rejected as expected. code=${e.code} message=${e.message}`;
    }

    // Scenario 2: owner CAN still cancel their own order — the denylist
    // addition did not break the legitimate cancellation path.
    try {
      await assertSucceeds(
        customerDb.collection("orders").doc("p44b-order2").update({
          orderStatus: "cancelled",
        })
      );
      scenario2 = "PASSED — legitimate owner cancellation still succeeds";
    } catch (e) {
      scenario2 = `FAILED — owner cancel was rejected but should have succeeded: ${e.message}`;
    }

    // Scenario 3: a seller cannot pre-set commissionReversed:true on their
    // own order either (orderFulfilmentCannotChangeProtectedFields()).
    try {
      await sellerDb.collection("orders").doc("p44b-order3").update({
        commissionReversed: true,
      });
      scenario3 = "FAILED — seller was able to pre-set commissionReversed on their own order!";
    } catch (e) {
      scenario3 = `PASSED — rejected as expected. code=${e.code} message=${e.message}`;
    }

    // Scenario 4 (control): the seller's legitimate fulfilment write still
    // succeeds — the denylist addition did not overreach.
    try {
      await assertSucceeds(
        sellerDb.collection("orders").doc("p44b-order4").update({
          orderStatus: "processing",
          status: "processing",
        })
      );
      scenario4 = "PASSED — seller's legitimate fulfilment write still succeeds";
    } catch (e) {
      scenario4 = `FAILED — seller's legitimate write was rejected but should have succeeded: ${e.message}`;
    }
  } finally {
    await testEnv.cleanup();
  }

  console.log("=== PHASE 44B — commissionReversed RULES TEST RESULTS ===");
  console.log("Scenario 1 (owner cannot pre-set commissionReversed):", scenario1);
  console.log("Scenario 2 (owner can still cancel their own order):", scenario2);
  console.log("Scenario 3 (seller cannot pre-set commissionReversed):", scenario3);
  console.log("Scenario 4 (seller's legitimate fulfilment write still succeeds):", scenario4);

  const allPassed = [scenario1, scenario2, scenario3, scenario4].every((s) => s.startsWith("PASSED"));
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phase44b rules test:", e);
  process.exit(1);
});
