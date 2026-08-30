// Phase 16D-1, Workstreams 2 & 3: proves payEmployeeCommissionOnDelivery's
// widened eligibility (employeeUid presence, any orderMode) and its new
// fail-closed rate resolution.
//
// Invocation style: firebase-functions-test's OFFLINE-mode direct
// invocation — test.wrap(payEmployeeCommissionOnDelivery) called as
// `wrapped(change, context)`, where `change` is built from
// test.firestore.makeDocumentSnapshot()/test.makeChange() and `context`
// supplies `params.orderId`. This calls the REAL compiled handler
// directly in this process; every Firestore read/write inside it still
// hits the REAL Firestore emulator (FIRESTORE_EMULATOR_HOST) — it is NOT
// a re-implementation of the trigger logic. What it does NOT prove: that
// the live `.document("orders/{orderId}").onUpdate(...)` Cloud Firestore
// trigger wiring itself fires correctly when a real client write happens
// in production — only that the handler's OWN logic is correct once
// invoked. Deliberately chosen over relying on the Functions emulator's
// live background-trigger dispatch: this environment has a THIRD,
// concurrent Claude Code session actively creating/editing Cloud
// Functions source files during this run (confirmed via `git status` —
// see the completion report), which caused the Functions emulator to
// hot-reload mid-test and corrupt several in-flight trigger invocations
// (including totally unrelated, pre-existing functions failing with the
// same "Cannot read properties of undefined" pattern at the same moment)
// on an earlier attempt using real-write-and-poll. Direct invocation
// avoids that dependency entirely — only the Firestore emulator needs to
// be running for this script.
// Run with: node scripts/phase16d1_commission_test.js
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });
const db = admin.firestore();

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { payEmployeeCommissionOnDelivery } = require("../lib/customer/employeeCommission");
const wrapped = test.wrap(payEmployeeCommissionOnDelivery);

async function fireDeliveryTransition(orderId, beforeData, afterData) {
  const beforeSnap = test.firestore.makeDocumentSnapshot(beforeData, `orders/${orderId}`);
  const afterSnap = test.firestore.makeDocumentSnapshot(afterData, `orders/${orderId}`);
  const change = test.makeChange(beforeSnap, afterSnap);
  return wrapped(change, { params: { orderId } });
}

async function setCommissionSettings(fields) {
  await db.collection("settings").doc("commission").set(fields);
}
async function clearCommissionSettings() {
  await db.collection("settings").doc("commission").delete();
}

function baseOrder(overrides) {
  return {
    userId: "p16d1-commission-customer",
    orderNumber: `ORD-${overrides.orderIdHint || "x"}`,
    items: [],
    subtotal: overrides.total ?? 1000,
    discount: 0,
    deliveryCharge: 0,
    tax: 0,
    total: overrides.total ?? 1000,
    paymentMethod: "cod",
    paymentStatus: "pending",
    orderStatus: "pending",
    status: "pending",
    orderMode: overrides.orderMode || "B2C",
    employeeCode: null,
    employeeUid: overrides.employeeUid ?? null,
    commissionPaid: false,
    ...overrides.extra,
  };
}

async function main() {
  let allPassed = true;
  const results = {};
  const record = (key, ok, passMsg, failMsg) => {
    results[key] = ok ? `PASSED — ${passMsg}` : `FAILED — ${failMsg}`;
    if (!ok) allPassed = false;
    console.log(`${key}:`, results[key]);
  };

  console.log("=== PHASE 16D-1, WORKSTREAMS 2 & 3 — commission eligibility + rate resolution ===");

  // ============================================
  // Scenario 1: delivered B2C order WITH employeeUid, employee override
  // rate configured -> pays commission.
  //
  // NOTE (Workstream 2d honesty): this seeds orders/{id} directly with
  // orderMode:'B2C' and a non-null employeeUid — a shape the LIVE
  // createOrder.ts can never itself produce today (see
  // employeeCommission.ts's own header comment and this phase's
  // completion report Section L). This test exercises the TRIGGER's own
  // logic in isolation, exactly as Phase 16A's suites seed documents
  // directly to test trigger/core logic decoupled from whichever client
  // flow may or may not be able to reach that state yet.
  // ============================================
  {
    const employeeUid = "p16d1-w2-emp1";
    const orderId = "p16d1-w2-order1";
    await clearCommissionSettings();
    await db.collection("employees").doc(employeeUid).set({ userId: employeeUid, status: "pending", commissionRate: 10 });
    const before = baseOrder({ orderIdHint: "w2-1", orderMode: "B2C", employeeUid, total: 1000 });
    const after = { ...before, orderStatus: "delivered", status: "delivered" };
    await db.collection("orders").doc(orderId).set(before);
    await fireDeliveryTransition(orderId, before, after);

    const txnSnap = await db.collection("wallet_transactions").where("orderId", "==", orderId).limit(1).get();
    const txn = txnSnap.empty ? null : txnSnap.docs[0].data();
    const orderSnap = await db.collection("orders").doc(orderId).get();
    const ok =
      !!txn &&
      txn.amount === 100 &&
      txn.metadata?.orderMode === "B2C" &&
      txn.metadata?.rateSource === "employee_override" &&
      orderSnap.data().commissionPaid === true &&
      orderSnap.data().commissionAmount === 100;
    record(
      "1_delivered_b2c_order_with_employeeUid_pays_commission",
      ok,
      "a delivered B2C order carrying employeeUid paid commission (₹100 at 10% employee-override rate)",
      `txn=${JSON.stringify(txn)} order=${JSON.stringify(orderSnap.data())}`
    );
  }

  // ============================================
  // Scenario 2: delivered B2C order WITHOUT employeeUid -> pays nothing,
  // no wallet_transactions written, no Firestore reads attempted.
  // ============================================
  {
    const orderId = "p16d1-w2-order2";
    const before = baseOrder({ orderIdHint: "w2-2", orderMode: "B2C", employeeUid: null, total: 500 });
    const after = { ...before, orderStatus: "delivered", status: "delivered" };
    await db.collection("orders").doc(orderId).set(before);
    await fireDeliveryTransition(orderId, before, after);

    const txnSnap = await db.collection("wallet_transactions").where("orderId", "==", orderId).limit(1).get();
    const ok = txnSnap.empty;
    record(
      "2_delivered_b2c_order_without_employeeUid_pays_nothing",
      ok,
      "no wallet_transactions written for an order with no employeeUid",
      `wallet_transactions empty=${txnSnap.empty}`
    );
  }

  // ============================================
  // Scenario 3: delivered B2B order still pays exactly as before
  // (regression) — configured settings/commission.employeeDefaultRate.
  // ============================================
  {
    const employeeUid = "p16d1-w2-emp3";
    const orderId = "p16d1-w2-order3";
    await setCommissionSettings({ employeeDefaultRate: 8 });
    await db.collection("employees").doc(employeeUid).set({ userId: employeeUid, status: "pending", commissionRate: 0 });
    const before = baseOrder({ orderIdHint: "w2-3", orderMode: "B2B", employeeUid, total: 2000 });
    const after = { ...before, orderStatus: "delivered", status: "delivered" };
    await db.collection("orders").doc(orderId).set(before);
    await fireDeliveryTransition(orderId, before, after);

    const txnSnap = await db.collection("wallet_transactions").where("orderId", "==", orderId).limit(1).get();
    const txn = txnSnap.empty ? null : txnSnap.docs[0].data();
    const ok = !!txn && txn.amount === 160 && txn.metadata?.orderMode === "B2B" && txn.metadata?.rateSource === "configured_mode_rate";
    record(
      "3_delivered_b2b_order_still_pays_as_before",
      ok,
      "a delivered B2B order still pays via the configured employeeDefaultRate (₹160 at 8% of ₹2000) — regression intact",
      `txn=${JSON.stringify(txn)}`
    );
  }

  // ============================================
  // Scenario 4: a second genuine transition-into-delivered on an order
  // that already has commissionPaid:true must not pay twice.
  // ============================================
  {
    const employeeUid = "p16d1-w2-emp4";
    const orderId = "p16d1-w2-order4";
    await db.collection("employees").doc(employeeUid).set({ userId: employeeUid, status: "pending", commissionRate: 10 });
    const initial = baseOrder({ orderIdHint: "w2-4", orderMode: "B2C", employeeUid, total: 1000 });
    const delivered = { ...initial, orderStatus: "delivered", status: "delivered" };
    await db.collection("orders").doc(orderId).set(initial);
    await fireDeliveryTransition(orderId, initial, delivered);

    // Read back the REAL post-first-payout state (commissionPaid:true) to
    // use as the "before" of a second, genuine transition-into-delivered
    // — mirrors a retried/duplicated invocation of the same event.
    const afterFirstSnap = await db.collection("orders").doc(orderId).get();
    const afterFirst = afterFirstSnap.data();
    const processing = { ...afterFirst, orderStatus: "processing", status: "processing" };
    await db.collection("orders").doc(orderId).update({ orderStatus: "processing", status: "processing" });
    const deliveredAgain = { ...processing, orderStatus: "delivered", status: "delivered" };
    await fireDeliveryTransition(orderId, processing, deliveredAgain);

    const txnSnap = await db.collection("wallet_transactions").where("orderId", "==", orderId).get();
    const ok = txnSnap.size === 1;
    record(
      "4_retried_trigger_invocation_pays_nothing_extra",
      ok,
      "a second transition-into-delivered on an already commissionPaid order created exactly 1 wallet_transactions doc (no double pay)",
      `${txnSnap.size} wallet_transactions docs exist for order ${orderId}, expected exactly 1`
    );
  }

  // ============================================
  // Scenario 5: employee override WINS over the configured mode rate.
  // ============================================
  {
    const employeeUid = "p16d1-w3-emp5";
    const orderId = "p16d1-w3-order5";
    await setCommissionSettings({ employeeRetailRate: 20 });
    await db.collection("employees").doc(employeeUid).set({ userId: employeeUid, status: "pending", commissionRate: 5 });
    const before = baseOrder({ orderIdHint: "w3-5", orderMode: "B2C", employeeUid, total: 1000 });
    const after = { ...before, orderStatus: "delivered", status: "delivered" };
    await db.collection("orders").doc(orderId).set(before);
    await fireDeliveryTransition(orderId, before, after);

    const txnSnap = await db.collection("wallet_transactions").where("orderId", "==", orderId).limit(1).get();
    const txn = txnSnap.empty ? null : txnSnap.docs[0].data();
    const ok = !!txn && txn.amount === 50 && txn.metadata?.rateSource === "employee_override";
    record(
      "5_employee_override_wins_over_configured_rate",
      ok,
      "the employee's own 5% override was used, not the configured 20% mode rate",
      `txn=${JSON.stringify(txn)}`
    );
  }

  // ============================================
  // Scenario 6: configured mode rate used when no (usable) override.
  // ============================================
  {
    const employeeUid = "p16d1-w3-emp6";
    const orderId = "p16d1-w3-order6";
    await setCommissionSettings({ employeeRetailRate: 15 });
    await db.collection("employees").doc(employeeUid).set({ userId: employeeUid, status: "pending", commissionRate: 0 });
    const before = baseOrder({ orderIdHint: "w3-6", orderMode: "B2C", employeeUid, total: 1000 });
    const after = { ...before, orderStatus: "delivered", status: "delivered" };
    await db.collection("orders").doc(orderId).set(before);
    await fireDeliveryTransition(orderId, before, after);

    const txnSnap = await db.collection("wallet_transactions").where("orderId", "==", orderId).limit(1).get();
    const txn = txnSnap.empty ? null : txnSnap.docs[0].data();
    const ok = !!txn && txn.amount === 150 && txn.metadata?.rateSource === "configured_mode_rate";
    record(
      "6_configured_mode_rate_used_when_no_override",
      ok,
      "the configured 15% employeeRetailRate was used when the employee override was 0 (unconfigured, not 'explicit zero')",
      `txn=${JSON.stringify(txn)}`
    );
  }

  // ============================================
  // Scenario 7: unresolvable rate -> pays nothing, writes
  // commission_exceptions, leaves commissionPaid FALSE (retryable).
  // ============================================
  {
    const employeeUid = "p16d1-w3-emp7";
    const orderId = "p16d1-w3-order7";
    await clearCommissionSettings();
    await db.collection("employees").doc(employeeUid).set({ userId: employeeUid, status: "pending", commissionRate: 0 });
    const before = baseOrder({ orderIdHint: "w3-7", orderMode: "B2C", employeeUid, total: 1000 });
    const after = { ...before, orderStatus: "delivered", status: "delivered" };
    await db.collection("orders").doc(orderId).set(before);
    await fireDeliveryTransition(orderId, before, after);

    const exceptionSnap = await db.collection("commission_exceptions").where("orderId", "==", orderId).limit(1).get();
    const exception = exceptionSnap.empty ? null : exceptionSnap.docs[0].data();
    const orderSnap = await db.collection("orders").doc(orderId).get();
    const txnSnap = await db.collection("wallet_transactions").where("orderId", "==", orderId).get();
    const ok = !!exception && exception.reason === "no_rate_configured" && orderSnap.data().commissionPaid !== true && txnSnap.empty;
    record(
      "7_unresolvable_rate_pays_nothing_and_leaves_retryable",
      ok,
      `no rate resolved -> commission_exceptions written (reason=${exception && exception.reason}), commissionPaid left false, nothing paid`,
      `exception=${JSON.stringify(exception)} order=${JSON.stringify(orderSnap.data())} txnEmpty=${txnSnap.empty}`
    );
  }

  // ============================================
  // Scenario 8: an over-ceiling rate is REFUSED, not clamped.
  // ============================================
  {
    const employeeUid = "p16d1-w3-emp8";
    const orderId = "p16d1-w3-order8";
    await setCommissionSettings({ employeeRetailRate: 250 });
    await db.collection("employees").doc(employeeUid).set({ userId: employeeUid, status: "pending", commissionRate: 0 });
    const before = baseOrder({ orderIdHint: "w3-8", orderMode: "B2C", employeeUid, total: 1000 });
    const after = { ...before, orderStatus: "delivered", status: "delivered" };
    await db.collection("orders").doc(orderId).set(before);
    await fireDeliveryTransition(orderId, before, after);

    const exceptionSnap = await db.collection("commission_exceptions").where("orderId", "==", orderId).limit(1).get();
    const exception = exceptionSnap.empty ? null : exceptionSnap.docs[0].data();
    const txnSnap = await db.collection("wallet_transactions").where("orderId", "==", orderId).get();
    const ok = !!exception && exception.reason === "rate_exceeds_ceiling" && txnSnap.empty;
    record(
      "8_over_ceiling_rate_refused_not_clamped",
      ok,
      "a 250% configured rate was refused (rate_exceeds_ceiling), never clamped to 100% and paid",
      `exception=${JSON.stringify(exception)} txnEmpty=${txnSnap.empty}`
    );
    await clearCommissionSettings();
  }

  console.log("=== PHASE 16D-1 WORKSTREAMS 2 & 3 SUMMARY ===");
  console.log(allPassed ? "\nALL PASSED" : "\nSOME FAILED");
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phase16d1 commission test:", e);
  process.exit(1);
});
