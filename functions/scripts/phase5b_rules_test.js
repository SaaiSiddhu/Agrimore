// Phase 5b workstream 3, scenarios 1-3: proves the orderStatus rule fix
// against the real Firestore emulator, not just via flutter analyze/tsc.
// Run with: node scripts/phase5b_rules_test.js  (Firestore emulator must be
// running on 127.0.0.1:8080 — see firebase emulators:start --only firestore,functions)
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
  let scenario2 = "NOT RUN";
  let scenario3 = "NOT RUN";

  try {
    // Seed two pending orders as admin (bypasses rules) — one for each scenario.
    // Also seed users/{uid} docs — isDeliveryPartner()'s fallback branch does
    // get(users/{uid}).data.role, which throws a "Null value error" if the
    // doc doesn't exist at all. Every real user has a users/{uid} doc from
    // signup; a fake test user with no doc at all is unrealistic and not
    // what this rule was written to handle.
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.collection("users").doc("customer-1").set({ role: "user" });
      await db.collection("users").doc("seller-1").set({ role: "seller" });
      await db.collection("orders").doc("order-for-cancel").set({
        userId: "customer-1",
        sellerId: "seller-1",
        orderStatus: "pending",
        status: "pending",
        subtotal: 100,
        total: 100,
      });
      await db.collection("orders").doc("order-for-selfreport").set({
        userId: "customer-1",
        sellerId: "seller-1",
        orderStatus: "pending",
        status: "pending",
        subtotal: 100,
        total: 100,
      });
    });

    // Real production tokens always have this full claim set (roleClaims.ts's
    // buildClaims() always returns role/admin/seller/sellerApproved/
    // delivery_partner/deliveryApproved/employee/employeeApproved) — the
    // test harness's default fake token omits all of them, which the rules
    // emulator's CEL evaluator treats as an error on property access rather
    // than falsy/undefined, unlike (apparently) production. Setting them
    // explicitly makes the fake auth context match a realistic production
    // token shape; it does not change what firestore.rules itself does.
    const customerClaims = {
      email: "customer-1@phase5b-test.example",
      role: "user", admin: false, seller: false, sellerApproved: false,
      delivery_partner: false, deliveryApproved: false, employee: false, employeeApproved: false,
    };
    const sellerClaims = {
      email: "seller-1@phase5b-test.example",
      role: "seller", admin: false, seller: true, sellerApproved: true,
      delivery_partner: false, deliveryApproved: false, employee: false, employeeApproved: false,
    };
    const customerDb = testEnv
      .authenticatedContext("customer-1", customerClaims)
      .firestore();

    // Scenario 1: legitimate owner cancel — must succeed.
    try {
      await assertSucceeds(
        customerDb.collection("orders").doc("order-for-cancel").update({
          orderStatus: "cancelled",
          updatedAt: new Date(),
          cancellationReason: "test cancellation",
        })
      );
      scenario1 = "PASSED — owner cancel succeeded as expected";
    } catch (e) {
      scenario1 = `FAILED — owner cancel was rejected but should have succeeded: ${e.message}`;
    }

    // Scenario 2: owner self-reporting 'delivered' — must be REJECTED.
    try {
      await customerDb.collection("orders").doc("order-for-selfreport").update({
        orderStatus: "delivered",
      });
      scenario2 = "FAILED — owner was able to write orderStatus: 'delivered' on their own order!";
    } catch (e) {
      scenario2 = `PASSED — rejected as expected. code=${e.code} message=${e.message}`;
    }

    // Scenario 3: seller updating an order they own — must still succeed.
    const sellerDb = testEnv
      .authenticatedContext("seller-1", sellerClaims)
      .firestore();
    // SELLER-ORDERS-1 (2026-09-23): a seller's direct status write is now
    // denied (callable only); a non-lifecycle seller update must still succeed.
    try {
      await assertFails(
        sellerDb.collection("orders").doc("order-for-selfreport").update({
          orderStatus: "shipped",
        })
      );
      await assertSucceeds(
        sellerDb.collection("orders").doc("order-for-selfreport").update({ sellerNote: "packed" })
      );
      scenario3 = "PASSED — seller non-lifecycle update succeeded; direct status write denied";
    } catch (e) {
      scenario3 = `FAILED — seller update was rejected but should have succeeded: ${e.message}`;
    }
  } finally {
    await testEnv.cleanup();
  }

  console.log("=== PHASE 5b RULES TEST RESULTS ===");
  console.log("Scenario 1 (owner cancel succeeds):", scenario1);
  console.log("Scenario 2 (owner self-report delivered rejected):", scenario2);
  console.log("Scenario 3 (seller update still succeeds):", scenario3);

  const allPassed = [scenario1, scenario2, scenario3].every((s) => s.startsWith("PASSED"));
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running rules test:", e);
  process.exit(1);
});
