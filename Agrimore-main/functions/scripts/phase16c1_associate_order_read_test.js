// Phase 16C-1, Workstream 1 — proves a Sales Associate can now read orders
// attributed to them via employeeUid, the exact query shape
// apps/employee/lib/screens/home/dashboard_screen.dart has always run
// (orders.where('employeeUid', isEqualTo: uid)) and which has ALWAYS failed
// closed: firestore.rules' orders/{orderId} read rule never named
// employeeUid, and Firestore requires a list query's rule to be provably
// satisfiable from the query's own where() constraints, so no seeded data
// could ever have satisfied it. Also proves the negative cases (no
// cross-associate read, no unfiltered list) and that no other role's
// existing access was disturbed. Mirrors phase16_rules_test.js /
// phaseD1_fulfilment_rules_test.js's @firebase/rules-unit-testing pattern
// exactly. Run with: node scripts/phase16c1_associate_order_read_test.js
// (Firestore emulator must be running on 127.0.0.1:8080)
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
// Deliberately the SAME shape as unprivilegedClaims — the whole point of
// this phase's decision (see firestore.rules' own comment on the new
// branch) is that the read rule does NOT gate on isEmployee()/approval
// status, so an associate's custom claims are irrelevant to whether this
// rule grants them read. No `employee: true` claim is set anywhere in this
// file, on purpose — proving the rule works from resource.data.employeeUid
// alone, not from a role claim this rule never checks.
function associateClaims(email) {
  return unprivilegedClaims(email);
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

  const ASSOCIATE_A = "phase16c1-associate-a";
  const ASSOCIATE_B = "phase16c1-associate-b";
  const SUSPENDED_ASSOCIATE = "phase16c1-associate-suspended";
  const CUSTOMER_UID = "phase16c1-customer";
  const SELLER_UID = "phase16c1-seller";
  const DELIVERY_UID = "phase16c1-delivery";
  const OTHER_CUSTOMER = "phase16c1-other-customer";

  try {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();

      // The order Associate A is attributed to. sellerId is deliberately a
      // THIRD, unrelated uid (not SELLER_UID, which the regression
      // scenarios below authenticate as) — otherwise scenario 13 (a seller
      // must NOT be able to read an order they have no relationship to)
      // would trivially pass via the pre-existing sellerId branch, proving
      // nothing about the new employeeUid branch specifically.
      await db.collection("orders").doc("order-a-owned").set({
        userId: CUSTOMER_UID,
        sellerId: "phase16c1-unrelated-seller",
        employeeUid: ASSOCIATE_A,
        employeeCode: "ASSA01",
        orderMode: "B2C",
        orderNumber: "ORD-16C1-A",
        total: 500,
        orderStatus: "delivered",
        status: "delivered",
      });

      // A second order, attributed to a DIFFERENT associate (B) — the
      // negative-case fixture for "cannot read another associate's order".
      await db.collection("orders").doc("order-b-owned").set({
        userId: OTHER_CUSTOMER,
        sellerId: SELLER_UID,
        employeeUid: ASSOCIATE_B,
        employeeCode: "ASSB01",
        orderMode: "B2C",
        orderNumber: "ORD-16C1-B",
        total: 700,
        orderStatus: "delivered",
        status: "delivered",
      });

      // An order attributed to the SUSPENDED associate — proves suspension
      // does not revoke read access to already-earned history.
      await db.collection("orders").doc("order-suspended-owned").set({
        userId: CUSTOMER_UID,
        sellerId: SELLER_UID,
        employeeUid: SUSPENDED_ASSOCIATE,
        employeeCode: "SUSP01",
        orderMode: "B2B",
        orderNumber: "ORD-16C1-SUSP",
        total: 300,
        orderStatus: "delivered",
        status: "delivered",
      });
      await db.collection("employees").doc(SUSPENDED_ASSOCIATE).set({ status: "suspended" });

      // An ordinary order with NO employeeUid at all (the overwhelming
      // majority of real orders) — edge case: absent field must not
      // accidentally satisfy anyone's read.
      await db.collection("orders").doc("order-no-employee").set({
        userId: CUSTOMER_UID,
        sellerId: SELLER_UID,
        orderNumber: "ORD-16C1-NOEMP",
        total: 200,
        orderStatus: "pending",
        status: "pending",
      });

      // An order with employeeUid explicitly null — same edge case, other
      // representation.
      await db.collection("orders").doc("order-null-employee").set({
        userId: CUSTOMER_UID,
        sellerId: SELLER_UID,
        employeeUid: null,
        orderNumber: "ORD-16C1-NULLEMP",
        total: 150,
        orderStatus: "pending",
        status: "pending",
      });

      // Fixtures for the "existing roles unaffected" regression scenarios.
      await db.collection("orders").doc("order-regression-owner").set({
        userId: CUSTOMER_UID,
        sellerId: SELLER_UID,
        orderNumber: "ORD-16C1-OWNER",
        total: 100,
        orderStatus: "pending",
        status: "pending",
      });
      await db.collection("orders").doc("order-regression-seller").set({
        userId: OTHER_CUSTOMER,
        sellerId: SELLER_UID,
        orderNumber: "ORD-16C1-SELLER",
        total: 100,
        orderStatus: "pending",
        status: "pending",
      });
      await db.collection("orders").doc("order-regression-delivery").set({
        userId: OTHER_CUSTOMER,
        sellerId: SELLER_UID,
        deliveryPartnerId: DELIVERY_UID,
        orderNumber: "ORD-16C1-DELIVERY",
        total: 100,
        orderStatus: "out_for_delivery",
        status: "out_for_delivery",
      });
    });

    const associateADb = testEnv
      .authenticatedContext(ASSOCIATE_A, associateClaims(`${ASSOCIATE_A}@test.example`))
      .firestore();
    const associateBDb = testEnv
      .authenticatedContext(ASSOCIATE_B, associateClaims(`${ASSOCIATE_B}@test.example`))
      .firestore();
    const suspendedDb = testEnv
      .authenticatedContext(SUSPENDED_ASSOCIATE, associateClaims(`${SUSPENDED_ASSOCIATE}@test.example`))
      .firestore();
    const customerDb = testEnv
      .authenticatedContext(CUSTOMER_UID, unprivilegedClaims(`${CUSTOMER_UID}@test.example`))
      .firestore();
    const sellerDb = testEnv
      .authenticatedContext(SELLER_UID, sellerClaims(`${SELLER_UID}@test.example`))
      .firestore();
    const deliveryDb = testEnv
      .authenticatedContext(DELIVERY_UID, deliveryPartnerClaims(`${DELIVERY_UID}@test.example`))
      .firestore();
    const unauthDb = testEnv.unauthenticatedContext().firestore();

    // ============================================================
    // 1. THE LOAD-BEARING TEST — the dashboard's actual list query shape.
    // ============================================================
    try {
      const snap = await assertSucceeds(
        associateADb.collection("orders").where("employeeUid", "==", ASSOCIATE_A).get()
      );
      const ids = snap.docs.map((d) => d.id).sort();
      const ok = ids.length === 1 && ids[0] === "order-a-owned";
      record(
        "1_load_bearing_list_query_returns_own_orders",
        ok,
        `the real dashboard query (where employeeUid == uid) returned exactly [${ids.join(", ")}]`,
        `expected exactly ["order-a-owned"], got [${ids.join(", ")}]`
      );
    } catch (e) {
      record("1_load_bearing_list_query_returns_own_orders", false, "", `the dashboard's list query still fails: ${e.message}`);
    }

    // ============================================================
    // 2. Single-document read of an order the associate IS attributed to.
    // ============================================================
    try {
      await assertSucceeds(associateADb.collection("orders").doc("order-a-owned").get());
      record("2_associate_can_read_own_attributed_order", true, "single-document get() of an order the associate is attributed to succeeded", "");
    } catch (e) {
      record("2_associate_can_read_own_attributed_order", false, "", `get() failed: ${e.message}`);
    }

    // ============================================================
    // 3. NEGATIVE — cannot read another associate's attributed order.
    // ============================================================
    try {
      await associateADb.collection("orders").doc("order-b-owned").get();
      record("3_cannot_read_other_associates_order", false, "", "Associate A successfully read an order attributed to Associate B!");
    } catch (e) {
      record("3_cannot_read_other_associates_order", true, `rejected as expected. code=${e.code}`, "");
    }

    // ============================================================
    // 4. NEGATIVE — cannot list orders unfiltered.
    // ============================================================
    try {
      await associateADb.collection("orders").get();
      record("4_cannot_list_orders_unfiltered", false, "", "Associate A successfully listed the ENTIRE orders collection unfiltered!");
    } catch (e) {
      record("4_cannot_list_orders_unfiltered", true, `rejected as expected. code=${e.code}`, "");
    }

    // ============================================================
    // 5. NEGATIVE — a differently-filtered list (e.g. by userId, not
    // employeeUid) as an associate, where the associate is not the owner,
    // must still fail — proves the new branch didn't accidentally widen
    // ANY other query shape.
    // ============================================================
    try {
      await associateADb.collection("orders").where("userId", "==", CUSTOMER_UID).get();
      record("5_cannot_list_by_userId_as_associate", false, "", "Associate A successfully listed orders filtered by someone else's userId!");
    } catch (e) {
      record("5_cannot_list_by_userId_as_associate", true, `rejected as expected. code=${e.code}`, "");
    }

    // ============================================================
    // 6. EDGE CASE — employeeUid absent entirely.
    // ============================================================
    try {
      await associateADb.collection("orders").doc("order-no-employee").get();
      record("6_cannot_read_order_with_no_employeeUid", false, "", "Associate A read an order with no employeeUid field at all!");
    } catch (e) {
      record("6_cannot_read_order_with_no_employeeUid", true, `rejected as expected. code=${e.code}`, "");
    }

    // ============================================================
    // 7. EDGE CASE — employeeUid explicitly null.
    // ============================================================
    try {
      await associateADb.collection("orders").doc("order-null-employee").get();
      record("7_cannot_read_order_with_null_employeeUid", false, "", "Associate A read an order whose employeeUid is explicitly null!");
    } catch (e) {
      record("7_cannot_read_order_with_null_employeeUid", true, `rejected as expected. code=${e.code}`, "");
    }

    // ============================================================
    // 8. EDGE CASE — unauthenticated reader, even with the right id, must
    // still fail (isAuthenticated() gate untouched).
    // ============================================================
    try {
      await unauthDb.collection("orders").doc("order-a-owned").get();
      record("8_unauthenticated_reader_still_rejected", false, "", "an UNAUTHENTICATED read of Associate A's own order succeeded!");
    } catch (e) {
      record("8_unauthenticated_reader_still_rejected", true, `rejected as expected. code=${e.code}`, "");
    }

    // ============================================================
    // 9. CTO decision, proven — a SUSPENDED associate can still read an
    // order attributed to them (commission/history already earned).
    // ============================================================
    try {
      await assertSucceeds(suspendedDb.collection("orders").doc("order-suspended-owned").get());
      record(
        "9_suspended_associate_retains_read_access",
        true,
        "a suspended associate could still read an order attributed to them — matches the CTO's explicit decision that suspension must not revoke already-earned history",
        ""
      );
    } catch (e) {
      record("9_suspended_associate_retains_read_access", false, "", `a suspended associate's read was rejected: ${e.message}`);
    }

    // ============================================================
    // 10-13. REGRESSION — every other role's existing access, unchanged.
    // ============================================================
    try {
      await assertSucceeds(customerDb.collection("orders").doc("order-regression-owner").get());
      record("10_regression_customer_can_still_read_own_order", true, "a plain customer can still read their own order", "");
    } catch (e) {
      record("10_regression_customer_can_still_read_own_order", false, "", `customer's own-order read was rejected: ${e.message}`);
    }
    try {
      await assertSucceeds(sellerDb.collection("orders").doc("order-regression-seller").get());
      record("11_regression_seller_can_still_read_their_order", true, "a seller can still read an order carrying their sellerId", "");
    } catch (e) {
      record("11_regression_seller_can_still_read_their_order", false, "", `seller's order read was rejected: ${e.message}`);
    }
    try {
      await assertSucceeds(deliveryDb.collection("orders").doc("order-regression-delivery").get());
      record("12_regression_delivery_partner_can_still_read_assigned_order", true, "a delivery partner can still read an order assigned to them", "");
    } catch (e) {
      record("12_regression_delivery_partner_can_still_read_assigned_order", false, "", `delivery partner's assigned-order read was rejected: ${e.message}`);
    }
    // A seller must still NOT be able to read an order that isn't theirs
    // (the new employeeUid branch must not have widened the seller path).
    try {
      await sellerDb.collection("orders").doc("order-a-owned").get();
      record("13_regression_seller_still_cannot_read_unrelated_order", false, "", "a seller read an order that names neither their sellerId nor them as anything else!");
    } catch (e) {
      record("13_regression_seller_still_cannot_read_unrelated_order", true, `rejected as expected. code=${e.code}`, "");
    }
  } finally {
    await testEnv.cleanup();
  }

  console.log("=== PHASE 16C-1 — ASSOCIATE ORDER READ RULES TEST ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);
  const allPassed = Object.values(results).every((v) => v.startsWith("PASSED"));
  console.log(allPassed ? "\nALL PASSED" : "\nSOME FAILED");
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phase16c1 associate order read rules test:", e);
  process.exit(1);
});
