// Phase 16D-2 — Retail (B2C) Associate Attribution. Proves the FULL chain
// end to end: a real createOrder callable invocation resolves an
// employeeCode to an employeeUid for a B2C order, the order is delivered,
// and the REAL commission trigger pays the associate's wallet — the first
// time in this programme anything has proven an associate can actually
// earn a rupee, rather than proving the trigger's logic against a
// hand-seeded order (Phase 16D-1's suites) or the payment-consumption fix
// in isolation (Phase 16D-1/17's suites).
//
// Harness: firebase-functions-test's OFFLINE `test.wrap()` for both
// createOrder (a v2 onCall, invoked as `wrapped({data, auth})` — mirrors
// phase14_payment_replay_test.js exactly) and payEmployeeCommissionOnDelivery
// (a v1 Firestore trigger, invoked as `wrapped(change, context)` via
// test.firestore.makeDocumentSnapshot()/test.makeChange() — mirrors
// phase16d1_commission_test.js exactly). Real Firestore reads/writes
// against the emulator throughout; no live Functions-emulator dispatch
// needed (see this phase's completion report for why that matters in this
// environment). Rules scenarios (16-17) use a SEPARATE harness —
// @firebase/rules-unit-testing's initializeTestEnvironment — since rules
// enforcement cannot be exercised through test.wrap()'s direct invocation
// (which uses the Admin SDK and bypasses rules entirely, like every Cloud
// Function does in production).
//
// Run with: node scripts/phase16d2_attribution_test.js
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });
const db = admin.firestore();

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { createOrder } = require("../lib/customer/createOrder");
const { payEmployeeCommissionOnDelivery } = require("../lib/customer/employeeCommission");

const wrappedCreateOrder = test.wrap(createOrder);
const wrappedCommission = test.wrap(payEmployeeCommissionOnDelivery);

async function callCreateOrder(payload, auth) {
  try {
    const result = await wrappedCreateOrder({ data: payload, auth });
    return { ok: true, result };
  } catch (e) {
    return { ok: false, code: e.code, message: e.message };
  }
}

async function fireDeliveryTransition(orderId, beforeData, afterData) {
  const beforeSnap = test.firestore.makeDocumentSnapshot(beforeData, `orders/${orderId}`);
  const afterSnap = test.firestore.makeDocumentSnapshot(afterData, `orders/${orderId}`);
  const change = test.makeChange(beforeSnap, afterSnap);
  return wrappedCommission(change, { params: { orderId } });
}

async function seedCustomer(uid) {
  await db.collection("users").doc(uid).set({ uid, profileCompleted: true });
}

async function seedAssociate(uid, overrides = {}) {
  await db.collection("employees").doc(uid).set({
    userId: uid,
    name: "Test Associate",
    status: "approved",
    commissionRate: 0,
    createdBy: "self",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    ...overrides,
  });
}

async function seedProduct(id, salePrice, sellerId) {
  await db.collection("products").doc(id).set({
    name: `Product ${id}`,
    salePrice,
    sellerId,
    images: [],
    stock: 100,
    isB2BEnabled: false,
  });
}

async function seedB2BProduct(id, sellerId) {
  await db.collection("products").doc(id).set({
    name: `B2B Product ${id}`,
    salePrice: 500,
    isB2BEnabled: true,
    b2bPrice: 100,
    b2bMoq: 1,
    sellerId,
    images: [],
  });
}

async function setCommissionSettings(fields) {
  await db.collection("settings").doc("commission").set(fields);
}
async function clearCommissionSettings() {
  await db.collection("settings").doc("commission").delete();
}

async function main() {
  let allPassed = true;
  const results = {};
  const record = (key, ok, passMsg, failMsg) => {
    results[key] = ok ? `PASSED — ${passMsg}` : `FAILED — ${failMsg}`;
    if (!ok) allPassed = false;
    console.log(`${key}:`, results[key]);
  };

  console.log("=== PHASE 16D-2 — RETAIL ASSOCIATE ATTRIBUTION (end to end) ===");

  // ============================================
  // Scenarios 1-9: THE FULL CHAIN — no hand-seeded order.
  // ============================================
  {
    const associateUid = "p16d2-e2e-associate";
    const associateCode = "E2ECODE1";
    const customerUid = "p16d2-e2e-customer";
    const productId = "p16d2-e2e-product";

    await seedAssociate(associateUid, {
      employeeCode: associateCode,
      onboardingPaid: true,
      onboardingFeeAmount: 500,
      onboardingPaymentId: "pay_e2e_onboarding",
    });
    await setCommissionSettings({ employeeRetailRate: 12 });
    await seedCustomer(customerUid);
    await seedProduct(productId, 1000, "p16d2-e2e-seller");

    // Step 4: real createOrder call.
    const r = await callCreateOrder(
      {
        items: [{ productId, quantity: 1 }],
        orderMode: "B2C",
        employeeCode: associateCode,
        paymentMethod: "cod",
      },
      { uid: customerUid, token: {} }
    );
    const step4ok = r.ok && r.result.orders && r.result.orders.length === 1;
    record("1_createOrder_call_succeeds", step4ok, "real createOrder call succeeded", `r=${JSON.stringify(r)}`);
    // Balance-BEFORE read, so scenario 5's assertion is the DELTA this
    // scenario caused, not an absolute value — robust to this script
    // having been run more than once against the same long-lived,
    // REUSED emulator instance (Section 3: reuse, don't kill, another
    // session's emulator), which is exactly what happened once already
    // while authoring this suite.
    const walletBeforeSnap = await db.collection("wallets").doc(associateUid).get();
    const balanceBefore = walletBeforeSnap.exists ? walletBeforeSnap.data().balance || 0 : 0;
    if (!step4ok) {
      console.error("FATAL: cannot continue the end-to-end chain — createOrder itself failed");
    } else {
      const orderId = r.result.orders[0].orderId;

      // Step 5: order carries the correct employeeUid AND employeeCode.
      const orderSnap = await db.collection("orders").doc(orderId).get();
      const order = orderSnap.data();
      record(
        "2_order_carries_resolved_employeeUid",
        order.employeeUid === associateUid,
        `employeeUid=${order.employeeUid}`,
        `expected ${associateUid}, got ${order.employeeUid}`
      );
      record(
        "3_order_carries_resolved_employeeCode",
        order.employeeCode === associateCode,
        `employeeCode=${order.employeeCode}`,
        `expected ${associateCode}, got ${order.employeeCode}`
      );

      // Step 6: drive to delivered, invoke the REAL commission trigger.
      const before = order;
      const after = { ...before, orderStatus: "delivered", status: "delivered" };
      await db.collection("orders").doc(orderId).update({ orderStatus: "delivered", status: "delivered" });
      await fireDeliveryTransition(orderId, before, after);
      record("4_delivery_transition_fired", true, "delivery transition invoked the commission trigger", "");

      // Step 7: wallet balance increased by exactly the expected amount
      // (1000 total * 12% = 120) — asserted as a DELTA from balanceBefore,
      // not an absolute value (see the comment above balanceBefore).
      const walletSnap = await db.collection("wallets").doc(associateUid).get();
      const balance = walletSnap.exists ? walletSnap.data().balance : null;
      const delta = balance === null ? null : balance - balanceBefore;
      record(
        "5_wallet_balance_increased_by_expected_amount",
        delta === 120,
        `wallets/${associateUid}.balance went from ${balanceBefore} to ${balance} (delta=${delta})`,
        `expected a delta of 120, got ${delta} (before=${balanceBefore}, after=${balance})`
      );

      // Step 8: wallet_transactions doc exists with the right shape.
      const txnSnap = await db.collection("wallet_transactions").where("orderId", "==", orderId).limit(1).get();
      const txn = txnSnap.empty ? null : txnSnap.docs[0].data();
      record(
        "6_wallet_transaction_recorded",
        !!txn && txn.source === "commission" && txn.metadata?.orderMode === "B2C" && txn.amount === 120,
        `wallet_transactions doc: ${JSON.stringify(txn)}`,
        `txn=${JSON.stringify(txn)}`
      );

      // Step 9: order now commissionPaid:true with the right amount.
      const finalOrderSnap = await db.collection("orders").doc(orderId).get();
      const finalOrder = finalOrderSnap.data();
      record(
        "7_order_marked_commissionPaid_with_correct_amount",
        finalOrder.commissionPaid === true && finalOrder.commissionAmount === 120,
        `commissionPaid=${finalOrder.commissionPaid} commissionAmount=${finalOrder.commissionAmount}`,
        `order=${JSON.stringify(finalOrder)}`
      );

      // Overall headline assertion.
      record(
        "8_HEADLINE_associate_earned_a_real_rupee_end_to_end",
        order.employeeUid === associateUid && delta === 120 && finalOrder.commissionPaid === true,
        "an associate's ₹500-onboarding-fee-paying account earned ₹120 commission on a real retail order it never hand-seeded",
        "the end-to-end chain did not complete successfully — see scenarios 1-7 above"
      );
      record("9_no_hand_seeded_order_was_used", true, "the order used throughout this scenario was created via the REAL createOrder callable, never db.collection('orders').doc(...).set(...) directly", "");
    }
  }

  // ============================================
  // Scenario 10: unknown code -> order created, employeeUid null, no error.
  // ============================================
  {
    const customerUid = "p16d2-w1-customer10";
    const productId = "p16d2-w1-product10";
    await seedCustomer(customerUid);
    await seedProduct(productId, 200, "p16d2-w1-seller");
    const r = await callCreateOrder(
      { items: [{ productId, quantity: 1 }], orderMode: "B2C", employeeCode: "NOSUCHCODE10", paymentMethod: "cod" },
      { uid: customerUid, token: {} }
    );
    const orderSnap = r.ok ? await db.collection("orders").doc(r.result.orders[0].orderId).get() : null;
    const ok = r.ok && orderSnap.data().employeeUid === null && orderSnap.data().employeeCode === null;
    record("10_unknown_code_creates_order_with_no_attribution", ok, `order created, employeeUid=${orderSnap && orderSnap.data().employeeUid}`, `r=${JSON.stringify(r)}`);
  }

  // ============================================
  // Scenario 11: pending associate's code -> no attribution, order created.
  // ============================================
  {
    const associateUid = "p16d2-w1-pending-assoc";
    const code = "PENDINGCODE11";
    const customerUid = "p16d2-w1-customer11";
    const productId = "p16d2-w1-product11";
    await seedAssociate(associateUid, { employeeCode: code, status: "pending" });
    await seedCustomer(customerUid);
    await seedProduct(productId, 200, "p16d2-w1-seller");
    const r = await callCreateOrder(
      { items: [{ productId, quantity: 1 }], orderMode: "B2C", employeeCode: code, paymentMethod: "cod" },
      { uid: customerUid, token: {} }
    );
    const orderSnap = r.ok ? await db.collection("orders").doc(r.result.orders[0].orderId).get() : null;
    const ok = r.ok && orderSnap.data().employeeUid === null;
    record("11_pending_associate_code_no_attribution_not_blocked", ok, "order created, no attribution for a pending associate's code", `r=${JSON.stringify(r)}`);
  }

  // ============================================
  // Scenario 12: suspended associate's code -> no attribution, order created.
  // ============================================
  {
    const associateUid = "p16d2-w1-suspended-assoc";
    const code = "SUSPENDEDCODE12";
    const customerUid = "p16d2-w1-customer12";
    const productId = "p16d2-w1-product12";
    await seedAssociate(associateUid, { employeeCode: code, status: "suspended" });
    await seedCustomer(customerUid);
    await seedProduct(productId, 200, "p16d2-w1-seller");
    const r = await callCreateOrder(
      { items: [{ productId, quantity: 1 }], orderMode: "B2C", employeeCode: code, paymentMethod: "cod" },
      { uid: customerUid, token: {} }
    );
    const orderSnap = r.ok ? await db.collection("orders").doc(r.result.orders[0].orderId).get() : null;
    const ok = r.ok && orderSnap.data().employeeUid === null;
    record("12_suspended_associate_code_no_attribution_not_blocked", ok, "order created, no attribution for a suspended associate's code", `r=${JSON.stringify(r)}`);
  }

  // ============================================
  // Scenario 13: self-attribution (B2C) -> no attribution, order created,
  // NEVER throws.
  // ============================================
  {
    const associateUid = "p16d2-w2-self-attrib";
    const code = "SELFCODE13";
    const productId = "p16d2-w2-product13";
    await seedAssociate(associateUid, { employeeCode: code, status: "approved", onboardingPaid: true, onboardingFeeAmount: 500 });
    await seedCustomer(associateUid); // the associate IS the ordering customer
    await seedProduct(productId, 200, "p16d2-w2-seller");
    const r = await callCreateOrder(
      { items: [{ productId, quantity: 1 }], orderMode: "B2C", employeeCode: code, paymentMethod: "cod" },
      { uid: associateUid, token: {} } // same uid as the associate's own code
    );
    const orderSnap = r.ok ? await db.collection("orders").doc(r.result.orders[0].orderId).get() : null;
    const ok = r.ok && orderSnap.data().employeeUid === null;
    record("13_b2c_self_attribution_dropped_not_blocked", ok, "order created successfully, self-attribution silently dropped", `r=${JSON.stringify(r)}`);
  }

  // ============================================
  // Scenario 14: B2B with a bad code -> still throws (regression control).
  // ============================================
  {
    const customerUid = "p16d2-w1-b2b-bad-customer";
    const productId = "p16d2-w1-b2b-bad-product";
    await seedCustomer(customerUid);
    await seedB2BProduct(productId, "p16d2-w1-b2b-seller");
    const r = await callCreateOrder(
      { items: [{ productId, quantity: 1 }], orderMode: "B2B", employeeCode: "NOSUCHB2BCODE14", paymentMethod: "cod" },
      { uid: customerUid, token: {} }
    );
    const ok = !r.ok && r.code === "failed-precondition" && r.message === "Invalid or unapproved employee code";
    record("14_b2b_bad_code_still_throws_unchanged", ok, `rejected exactly as before: code=${r.code} message="${r.message}"`, `r=${JSON.stringify(r)}`);
  }

  // ============================================
  // Scenario 15: B2B with a good code -> still attributes exactly as before.
  // ============================================
  {
    const associateUid = "p16d2-w1-b2b-good-assoc";
    const code = "B2BGOODCODE15";
    const customerUid = "p16d2-w1-b2b-good-customer";
    const productId = "p16d2-w1-b2b-good-product";
    await seedAssociate(associateUid, { employeeCode: code, status: "approved" });
    await seedCustomer(customerUid);
    await seedB2BProduct(productId, "p16d2-w1-b2b-seller2");
    const r = await callCreateOrder(
      { items: [{ productId, quantity: 1 }], orderMode: "B2B", employeeCode: code, paymentMethod: "cod" },
      { uid: customerUid, token: {} }
    );
    const orderSnap = r.ok ? await db.collection("orders").doc(r.result.orders[0].orderId).get() : null;
    const ok = r.ok && orderSnap.data().employeeUid === associateUid && orderSnap.data().employeeCode === code;
    record("15_b2b_good_code_still_attributes_unchanged", ok, `B2B order attributed to ${orderSnap && orderSnap.data().employeeUid}, exactly as before`, `r=${JSON.stringify(r)}`);
  }

  // ============================================
  // Scenario 18: no employeeRetailRate configured -> commission_exceptions
  // written, commissionPaid false — reached through the REAL chain.
  // ============================================
  {
    const associateUid = "p16d2-w3-unresolved-assoc";
    const code = "UNRESOLVEDCODE18";
    const customerUid = "p16d2-w3-unresolved-customer";
    const productId = "p16d2-w3-unresolved-product";
    // onboardingPaid:true is required for retail attribution to resolve at
    // all (createOrder.ts's candidateGateCleared check) — this scenario
    // needs attribution to SUCCEED so the chain reaches the commission
    // trigger's own rate-resolution failure, not createOrder's.
    await seedAssociate(associateUid, {
      employeeCode: code,
      status: "approved",
      commissionRate: 0,
      onboardingPaid: true,
      onboardingFeeAmount: 500,
    });
    await seedCustomer(customerUid);
    await seedProduct(productId, 500, "p16d2-w3-seller");
    await clearCommissionSettings(); // no employeeRetailRate configured at all

    const r = await callCreateOrder(
      { items: [{ productId, quantity: 1 }], orderMode: "B2C", employeeCode: code, paymentMethod: "cod" },
      { uid: customerUid, token: {} }
    );
    const orderId = r.ok ? r.result.orders[0].orderId : null;
    if (orderId) {
      const orderSnap = await db.collection("orders").doc(orderId).get();
      const before = orderSnap.data();
      const after = { ...before, orderStatus: "delivered", status: "delivered" };
      await db.collection("orders").doc(orderId).update({ orderStatus: "delivered", status: "delivered" });
      await fireDeliveryTransition(orderId, before, after);

      const exceptionSnap = await db.collection("commission_exceptions").where("orderId", "==", orderId).limit(1).get();
      const finalOrderSnap = await db.collection("orders").doc(orderId).get();
      const ok = !exceptionSnap.empty && finalOrderSnap.data().commissionPaid !== true;
      record(
        "18_unresolved_rate_reached_through_real_chain",
        ok,
        `commission_exceptions written (reason=${exceptionSnap.empty ? "N/A" : exceptionSnap.docs[0].data().reason}), commissionPaid=${finalOrderSnap.data().commissionPaid}`,
        `exceptionEmpty=${exceptionSnap.empty} order=${JSON.stringify(finalOrderSnap.data())}`
      );
    } else {
      record("18_unresolved_rate_reached_through_real_chain", false, "", `createOrder call itself failed: r=${JSON.stringify(r)}`);
    }
  }

  console.log("=== END-TO-END + WORKSTREAM 1/2 SUMMARY ===");
  console.log(allPassed ? "\nALL PASSED (so far — rules scenarios below)" : "\nSOME FAILED (so far — rules scenarios below)");

  // ============================================
  // Scenarios 16-17: RULES — separate harness, real rules engine.
  // ============================================
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

  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
  const testEnv = await initializeTestEnvironment({
    projectId: "agrimore-66a4e",
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });

  try {
    const BASE_ORDER = {
      userId: "p16d2-rules-owner",
      sellerId: "p16d2-rules-seller",
      orderNumber: "ORD-P16D2-RULES",
      items: [{ productId: "p1", quantity: 1, price: 100 }],
      subtotal: 100,
      discount: 0,
      deliveryCharge: 0,
      tax: 0,
      total: 100,
      paymentMethod: "cod",
      paymentStatus: "pending",
      orderStatus: "pending",
      status: "pending",
      employeeUid: null,
      employeeCode: null,
      orderMode: "B2C",
      commissionPaid: false,
    };

    // Scenario 16: customer cannot update employeeUid on their own order.
    {
      const orderId = "p16d2-rules-order16";
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("orders").doc(orderId).set(BASE_ORDER);
      });
      const ownerDb = testEnv
        .authenticatedContext("p16d2-rules-owner", unprivilegedClaims("owner16@p16d2-test.example"))
        .firestore();
      try {
        await assertFails(
          ownerDb.collection("orders").doc(orderId).update({ employeeUid: "p16d2-rules-hijack-target" })
        );
        record("16_customer_cannot_write_employeeUid", true, "a customer could not set employeeUid on their own order", "");
      } catch (e) {
        record("16_customer_cannot_write_employeeUid", false, "", `customer wrote employeeUid: ${e.message}`);
      }
    }

    // Scenario 17: customer cancellation still succeeds (positive control).
    {
      const orderId = "p16d2-rules-order17";
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection("orders").doc(orderId).set(BASE_ORDER);
      });
      const ownerDb = testEnv
        .authenticatedContext("p16d2-rules-owner", unprivilegedClaims("owner17@p16d2-test.example"))
        .firestore();
      try {
        await assertSucceeds(ownerDb.collection("orders").doc(orderId).update({ orderStatus: "cancelled" }));
        record("17_customer_cancellation_still_succeeds", true, "a legitimate owner cancellation still succeeds after the new employeeUid/employeeCode denylist entries", "");
      } catch (e) {
        record("17_customer_cancellation_still_succeeds", false, "", `legitimate cancellation was rejected: ${e.message}`);
      }
    }
  } finally {
    await testEnv.cleanup();
  }

  console.log("=== PHASE 16D-2 FULL SUMMARY ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);
  console.log(allPassed ? "\nALL PASSED" : "\nSOME FAILED");
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phase16d2 attribution test:", e);
  process.exit(1);
});
