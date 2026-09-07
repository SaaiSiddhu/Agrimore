// Phase RFQ-1: proves the rfqs/{rfqId} rule against the real rules engine —
// only the buyer, the seller, or an admin may read a given RFQ; nobody may
// write it directly (Cloud-Functions-only). Mirrors phase9_wallet_rules_test.js's
// @firebase/rules-unit-testing pattern.
// Run with: node scripts/phase39b_rfq_rules_test.js
const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");

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

function adminClaims(email) {
  return { ...unprivilegedClaims(email), admin: true };
}

const RFQ_DOC = {
  id: "phase39b-rfq",
  buyerId: "phase39b-buyer",
  sellerId: "phase39b-seller",
  productId: "phase39b-product",
  status: "pending",
  awaitingResponseFrom: "seller",
  lastOffer: null,
  finalPrice: null,
  finalQuantity: null,
  history: [],
};

async function main() {
  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
  const testEnv = await initializeTestEnvironment({
    projectId: "agrimore-66a4e",
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });

  const results = {};

  try {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("rfqs").doc("phase39b-rfq").set(RFQ_DOC);
    });

    // Scenario 1 (positive control): the buyer can read their own RFQ.
    {
      const db = testEnv
        .authenticatedContext("phase39b-buyer", unprivilegedClaims("buyer@phase39b-test.example"))
        .firestore();
      try {
        await assertSucceeds(db.collection("rfqs").doc("phase39b-rfq").get());
        results.scenario1_buyer_can_read = "PASSED — buyer read their own RFQ successfully";
      } catch (e) {
        results.scenario1_buyer_can_read = `FAILED — ${e.message}`;
      }
    }

    // Scenario 2 (positive control): the seller can read the same RFQ.
    {
      const db = testEnv
        .authenticatedContext("phase39b-seller", unprivilegedClaims("seller@phase39b-test.example"))
        .firestore();
      try {
        await assertSucceeds(db.collection("rfqs").doc("phase39b-rfq").get());
        results.scenario2_seller_can_read = "PASSED — seller read the RFQ successfully";
      } catch (e) {
        results.scenario2_seller_can_read = `FAILED — ${e.message}`;
      }
    }

    // Scenario 3: a stranger cannot read this RFQ.
    {
      const db = testEnv
        .authenticatedContext("phase39b-stranger", unprivilegedClaims("stranger@phase39b-test.example"))
        .firestore();
      try {
        await assertFails(db.collection("rfqs").doc("phase39b-rfq").get());
        results.scenario3_stranger_denied = "PASSED — a non-party's read was denied as expected";
      } catch (e) {
        results.scenario3_stranger_denied = `FAILED — ${e.message}`;
      }
    }

    // Scenario 4 (positive control): admin can read any RFQ.
    {
      const db = testEnv
        .authenticatedContext("phase39b-admin", adminClaims("admin@phase39b-test.example"))
        .firestore();
      try {
        await assertSucceeds(db.collection("rfqs").doc("phase39b-rfq").get());
        results.scenario4_admin_can_read = "PASSED — admin read succeeded as expected";
      } catch (e) {
        results.scenario4_admin_can_read = `FAILED — ${e.message}`;
      }
    }

    // Scenario 5: the buyer cannot write to their own RFQ directly (e.g.
    // self-granting status:'accepted' or a favourable finalPrice).
    {
      const db = testEnv
        .authenticatedContext("phase39b-buyer", unprivilegedClaims("buyer@phase39b-test.example"))
        .firestore();
      try {
        await assertFails(
          db.collection("rfqs").doc("phase39b-rfq").update({ status: "accepted", finalPrice: 1 })
        );
        results.scenario5_buyer_cannot_write = "PASSED — direct client write to an RFQ was denied as expected";
      } catch (e) {
        results.scenario5_buyer_cannot_write = `FAILED — ${e.message}`;
      }
    }

    // Scenario 6: nobody can create a fresh RFQ document directly (must go
    // through createRfq, which resolves sellerId server-side).
    {
      const db = testEnv
        .authenticatedContext("phase39b-buyer", unprivilegedClaims("buyer@phase39b-test.example"))
        .firestore();
      try {
        await assertFails(
          db.collection("rfqs").doc("phase39b-fake").set({
            ...RFQ_DOC,
            id: "phase39b-fake",
            sellerId: "phase39b-buyer", // attempting to name themselves the seller too
          })
        );
        results.scenario6_direct_create_denied = "PASSED — a direct client-created RFQ doc was denied as expected";
      } catch (e) {
        results.scenario6_direct_create_denied = `FAILED — ${e.message}`;
      }
    }
  } finally {
    await testEnv.cleanup();
  }

  console.log("=== PHASE RFQ-1B (RULES) SUMMARY ===");
  let allPassed = true;
  for (const [k, v] of Object.entries(results)) {
    console.log(`${k}:`, v);
    if (!v.startsWith("PASSED")) allPassed = false;
  }
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phase39b RFQ rules test:", e);
  process.exit(1);
});
