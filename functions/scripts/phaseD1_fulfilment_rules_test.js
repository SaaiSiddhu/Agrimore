// Phase D-1, Workstream 1 — firestore.rules' orderFulfilmentCannotChangeProtectedFields()
// and deliveryPartnerCanClaimOrder() denylist extension (DEFECT D-0,
// CRITICAL). Proves a seller or a claiming delivery partner can no longer
// write productCreditApplied/productCreditHoldId/productCreditReversed/
// productCreditLedgerEntryId on an order — the runtime-proven credit-mint /
// refund-suppression exploit — while legitimate fulfilment writes (and the
// pre-existing owner-side denial) still work. Same
// @firebase/rules-unit-testing harness shape as phase5b_rules_test.js /
// phase15_rules_test.js / phaseD_rules_test.js.
// Run with: node scripts/phaseD1_fulfilment_rules_test.js  (Firestore
// emulator must be running on 127.0.0.1:8080)
const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertSucceeds } = require("@firebase/rules-unit-testing");

function unprivilegedClaims(email) {
  return {
    email,
    role: "user",
    admin: false,
    seller: false,
    sellerApproved: false,
    delivery_partner: false,
    deliveryApproved: false,
    employee: false,
    employeeApproved: false,
  };
}
function sellerClaims(email) {
  return { ...unprivilegedClaims(email), role: "seller", seller: true, sellerApproved: true };
}
function deliveryPartnerClaims(email) {
  return { ...unprivilegedClaims(email), role: "delivery_partner", delivery_partner: true, deliveryApproved: true };
}

async function main() {
  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
  const testEnv = await initializeTestEnvironment({
    projectId: "agrimore-66a4e",
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });

  const results = {};
  const record = (key, ok, passMsg, failMsg) => {
    results[key] = ok ? `PASSED — ${passMsg}` : `FAILED — ${failMsg}`;
  };

  const SELLER_UID = "phaseD1-fr-seller";
  const CUSTOMER_UID = "phaseD1-fr-customer";
  const DELIVERY_UID = "phaseD1-fr-delivery";

  try {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.collection("users").doc(CUSTOMER_UID).set({ role: "user" });
      await db.collection("users").doc(SELLER_UID).set({ role: "seller" });
      await db.collection("users").doc(DELIVERY_UID).set({ role: "delivery_partner" });

      const baseOrder = {
        userId: CUSTOMER_UID,
        sellerId: SELLER_UID,
        deliveryPartnerId: null,
        orderStatus: "pending",
        status: "pending",
        subtotal: 1000,
        total: 700,
        productCreditApplied: 300,
        productCreditHoldId: "phaseD1-fr-hold",
        productCreditReversed: false,
        productCreditLedgerEntryId: "phaseD1-fr-ledger-entry",
      };
      for (const id of [
        "order-s1", "order-s2", "order-s3", "order-s4",
        "order-claim5", "order-control6", "order-control7", "order-owner8",
      ]) {
        await db.collection("orders").doc(id).set(baseOrder);
      }
    });

    const sellerDb = testEnv.authenticatedContext(SELLER_UID, sellerClaims(`${SELLER_UID}@test.example`)).firestore();
    const deliveryDb = testEnv
      .authenticatedContext(DELIVERY_UID, deliveryPartnerClaims(`${DELIVERY_UID}@test.example`))
      .firestore();
    const customerDb = testEnv
      .authenticatedContext(CUSTOMER_UID, unprivilegedClaims(`${CUSTOMER_UID}@test.example`))
      .firestore();

    // Scenario 1-4: seller cannot set any of the 4 product-credit fields on
    // their OWN order (DEFECT D-0's actual exploit surface).
    const sellerFieldAttempts = [
      ["1_seller_cannot_set_productCreditApplied", "order-s1", { productCreditApplied: 999999 }],
      ["2_seller_cannot_set_productCreditReversed", "order-s2", { productCreditReversed: true }],
      ["3_seller_cannot_set_productCreditHoldId", "order-s3", { productCreditHoldId: "attacker-hold" }],
      ["4_seller_cannot_set_productCreditLedgerEntryId", "order-s4", { productCreditLedgerEntryId: "attacker-entry" }],
    ];
    for (const [key, orderId, patch] of sellerFieldAttempts) {
      try {
        await sellerDb.collection("orders").doc(orderId).update(patch);
        record(key, false, "", `seller was able to write ${JSON.stringify(patch)} on their own order!`);
      } catch (e) {
        record(key, true, `rejected as expected. code=${e.code}`, "");
      }
    }

    // Scenario 5: a delivery partner claiming an UNASSIGNED order cannot
    // sneak a product-credit field into the same write that legitimately
    // sets deliveryPartnerId to their own uid.
    try {
      await deliveryDb.collection("orders").doc("order-claim5").update({
        deliveryPartnerId: DELIVERY_UID,
        productCreditApplied: 999999,
      });
      record("5_delivery_partner_claim_cannot_set_credit_fields", false, "", "delivery partner's claim write, carrying a product-credit field, was allowed!");
    } catch (e) {
      record("5_delivery_partner_claim_cannot_set_credit_fields", true, `rejected as expected. code=${e.code}`, "");
    }

    // Scenario 6 CONTROL: Workstream 1 did not over-block the seller.
    // SELLER-ORDERS-1 (2026-09-23): status now moves only through the
    // sellerTransitionOrder callable, so the control is a non-lifecycle
    // seller write (must succeed) and a direct status write (must be denied).
    try {
      await assertFails(
        sellerDb.collection("orders").doc("order-control6").update({ orderStatus: "processing" })
      );
      await assertSucceeds(
        sellerDb.collection("orders").doc("order-control6").update({ sellerNote: "packed" })
      );
      record("6_control_seller_non_lifecycle_write_succeeds_status_is_callable_only", true, "note write ok; direct status write denied", "");
    } catch (e) {
      record("6_control_seller_non_lifecycle_write_succeeds_status_is_callable_only", false, "", `unexpected: ${e.message}`);
    }

    // Scenario 7 CONTROL: seller changing `total` is still denied — proves
    // the test harness itself is sound (the pre-existing Phase 14 lock).
    try {
      await sellerDb.collection("orders").doc("order-control7").update({ total: 1 });
      record("7_control_seller_total_still_denied", false, "", "seller was able to rewrite total — the harness itself is not proving anything!");
    } catch (e) {
      record("7_control_seller_total_still_denied", true, `rejected as expected (pre-existing lock). code=${e.code}`, "");
    }

    // Scenario 8: owner still cannot set productCreditLedgerEntryId (the
    // field Phase D-1 added to ownerCannotChangeOrderFinancials() — the
    // other three were already proven by phaseD_rules_test.js).
    try {
      await customerDb.collection("orders").doc("order-owner8").update({
        productCreditLedgerEntryId: "attacker-entry",
      });
      record("8_owner_cannot_set_productCreditLedgerEntryId", false, "", "owner was able to rewrite productCreditLedgerEntryId on their own order!");
    } catch (e) {
      record("8_owner_cannot_set_productCreditLedgerEntryId", true, `rejected as expected. code=${e.code}`, "");
    }
  } finally {
    await testEnv.cleanup();
  }

  console.log("=== PHASE D-1 — FULFILMENT/CLAIM RULES TEST (DEFECT D-0) ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);
  const allPassed = Object.values(results).every((v) => v.startsWith("PASSED"));
  console.log(allPassed ? "\nALL PASSED" : "\nSOME FAILED");
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phaseD1 fulfilment rules test:", e);
  process.exit(1);
});
