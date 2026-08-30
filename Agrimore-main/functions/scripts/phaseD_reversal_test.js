// Phase D, Workstream 4 — productCreditReversal.ts's cancellation trigger.
//
// Invocation style: firebase-functions-test's OFFLINE-mode direct
// invocation — test.wrap(reverseProductCreditOnCancellation) called as
// `wrapped(change, context)`, where `change` is built from
// test.firestore.makeDocumentSnapshot()/test.makeChange() — the SAME
// pattern phase16d1_commission_test.js already established for
// employeeCommission.ts's onUpdate trigger. This calls the REAL compiled
// handler directly in this process; every Firestore read/write inside it
// still hits the REAL Firestore emulator. The handler reads
// productCreditApplied/userId/productCreditLedgerEntryId from `after` (the
// update event) and re-checks productCreditReversed against the LIVE
// order document inside its own transaction — so each scenario below
// seeds the real orders/{orderId} document with `before` first, exactly
// like phase16d1_commission_test.js does.
// Run with: node scripts/phaseD_reversal_test.js
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });
const db = admin.firestore();

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { reverseProductCreditOnCancellation } = require("../lib/customer/productCreditReversal");
const wrapped = test.wrap(reverseProductCreditOnCancellation);

async function fireCancellation(orderId, beforeData, afterData) {
  const beforeSnap = test.firestore.makeDocumentSnapshot(beforeData, `orders/${orderId}`);
  const afterSnap = test.firestore.makeDocumentSnapshot(afterData, `orders/${orderId}`);
  const change = test.makeChange(beforeSnap, afterSnap);
  return wrapped(change, { params: { orderId } });
}

async function seedBalance(customerId, available) {
  await db
    .collection("product_credit_balances")
    .doc(customerId)
    .set({ available, pending: 0, onHold: 0, lifetimeEarned: available, lifetimeUsed: 0, lifetimeExpired: 0 });
}

async function getBalance(customerId) {
  const snap = await db.collection("product_credit_balances").doc(customerId).get();
  return snap.data() || {};
}

function baseOrder(overrides) {
  return {
    userId: overrides.userId,
    sellerId: overrides.sellerId || "phaseD-rev-seller",
    orderNumber: `ORD-${overrides.orderIdHint || "x"}`,
    items: [],
    subtotal: overrides.total ?? 1000,
    discount: 0,
    deliveryCharge: 0,
    tax: 0,
    total: overrides.total ?? 1000,
    paymentMethod: overrides.paymentMethod || "cod",
    paymentStatus: overrides.paymentStatus || "pending",
    orderStatus: "pending",
    status: "pending",
    orderMode: "B2C",
    productCreditApplied: overrides.productCreditApplied ?? 0,
    productCreditHoldId: overrides.productCreditHoldId ?? null,
    productCreditReversed: overrides.productCreditReversed ?? false,
    productCreditLedgerEntryId: overrides.productCreditLedgerEntryId ?? null,
    ...overrides.extra,
  };
}

async function main() {
  let allPassed = true;
  const results = {};
  const record = (key, ok, passMsg, failMsg) => {
    results[key] = ok ? `PASSED — ${passMsg}` : `FAILED — ${failMsg}`;
    if (!ok) allPassed = false;
  };

  // ============================================================
  // Scenario 1: cancelling a credit-bearing order restores `available` by
  // exactly the applied amount.
  //
  // scenario1Before/scenario1After are hoisted (not re-derived) for
  // scenario 2 below: a real Firestore at-least-once retry redelivers the
  // EXACT SAME event payload — `after.productCreditReversed` in that
  // payload is fixed at dispatch time and still reads `false` even though
  // the order document has since been updated. Only the in-transaction
  // re-check against the LIVE document (not the cheap early-return check
  // against `after`) can catch that retry — reusing the identical payload
  // is what actually proves that guard, not a synthetically-altered one.
  // ============================================================
  const scenario1CustomerId = "phaseD-rev-c1";
  const scenario1OrderId = "phaseD-rev-order1";
  let scenario1Before = null;
  let scenario1After = null;
  {
    const customerId = scenario1CustomerId;
    const orderId = scenario1OrderId;
    await seedBalance(customerId, 200); // e.g. left over after the credit was already spent elsewhere
    const before = baseOrder({
      orderIdHint: "1",
      userId: customerId,
      total: 1000,
      productCreditApplied: 300,
      productCreditHoldId: "phaseD-rev-hold1",
      productCreditLedgerEntryId: "phaseD-rev-redemption1",
    });
    const after = { ...before, orderStatus: "cancelled", status: "cancelled" };
    scenario1Before = before;
    scenario1After = after;
    await db.collection("orders").doc(orderId).set(before);

    const balBefore = await getBalance(customerId);
    await fireCancellation(orderId, before, after);
    const balAfter = await getBalance(customerId);
    const orderSnap = await db.collection("orders").doc(orderId).get();

    const reversalSnap = await db
      .collection("product_credit_ledger")
      .where("orderId", "==", orderId)
      .where("type", "==", "REVERSAL")
      .get();
    const reversalEntry = reversalSnap.empty ? null : reversalSnap.docs[0].data();

    const ok =
      balAfter.available === balBefore.available + 300 &&
      orderSnap.data().productCreditReversed === true &&
      !!reversalEntry &&
      reversalEntry.amount === 300 &&
      reversalEntry.relatedEntryId === "phaseD-rev-redemption1";
    record(
      "1_cancellation_restores_available_exactly",
      ok,
      `available restored from ${balBefore.available} to ${balAfter.available}, order.productCreditReversed=true, REVERSAL entry amount=300 relatedEntryId=${reversalEntry?.relatedEntryId}`,
      `balBefore=${JSON.stringify(balBefore)} balAfter=${JSON.stringify(balAfter)} order=${JSON.stringify(orderSnap.data())} reversal=${JSON.stringify(reversalEntry)}`
    );
  }

  // ============================================================
  // Scenario 2: a real at-least-once retry — the EXACT SAME (before,
  // after) event redelivered — is idempotent. after.productCreditReversed
  // in this payload is still `false` (fixed at original dispatch time), so
  // this exercises the IN-TRANSACTION re-check against the live order
  // document (which scenario 1 already flipped to true), not the cheap
  // early-return check.
  // ============================================================
  {
    const customerId = scenario1CustomerId;
    const orderId = scenario1OrderId;
    const balBefore = await getBalance(customerId);

    await fireCancellation(orderId, scenario1Before, scenario1After);

    const balAfter = await getBalance(customerId);
    const reversalSnap = await db
      .collection("product_credit_ledger")
      .where("orderId", "==", orderId)
      .where("type", "==", "REVERSAL")
      .get();

    const ok = balAfter.available === balBefore.available && reversalSnap.size === 1;
    record(
      "2_double_cancellation_is_idempotent",
      ok,
      `retried event (after.productCreditReversed still false in the payload) changed nothing: balance unchanged (${balAfter.available}), still exactly 1 REVERSAL ledger entry for this order`,
      `balBefore=${JSON.stringify(balBefore)} balAfter=${JSON.stringify(balAfter)} reversalCount=${reversalSnap.size}`
    );
  }

  // ============================================================
  // Scenario 3: cancelling an order with 0 credit writes no ledger entry.
  // ============================================================
  {
    const customerId = "phaseD-rev-c3";
    const orderId = "phaseD-rev-order3";
    await seedBalance(customerId, 50);
    const before = baseOrder({ orderIdHint: "3", userId: customerId, total: 400, productCreditApplied: 0 });
    const after = { ...before, orderStatus: "cancelled", status: "cancelled" };
    await db.collection("orders").doc(orderId).set(before);

    const balBefore = await getBalance(customerId);
    await fireCancellation(orderId, before, after);
    const balAfter = await getBalance(customerId);

    const reversalSnap = await db
      .collection("product_credit_ledger")
      .where("orderId", "==", orderId)
      .where("type", "==", "REVERSAL")
      .get();

    const ok = balAfter.available === balBefore.available && reversalSnap.empty;
    record(
      "3_zero_credit_order_writes_no_ledger_entry",
      ok,
      `balance unchanged (${balAfter.available}), no REVERSAL entry written`,
      `balBefore=${JSON.stringify(balBefore)} balAfter=${JSON.stringify(balAfter)} reversalEmpty=${reversalSnap.empty}`
    );
  }

  // ============================================================
  // Scenario 4: multi-seller — cancelling ONE seller's order reverses only
  // that order's own share, never the sibling order's.
  // ============================================================
  {
    const customerId = "phaseD-rev-c4";
    const orderIdA = "phaseD-rev-order4a";
    const orderIdB = "phaseD-rev-order4b";
    await seedBalance(customerId, 0);

    const beforeA = baseOrder({
      orderIdHint: "4a",
      userId: customerId,
      sellerId: "phaseD-rev-seller4a",
      total: 600,
      productCreditApplied: 180,
      productCreditLedgerEntryId: "phaseD-rev-redemption4",
    });
    const beforeB = baseOrder({
      orderIdHint: "4b",
      userId: customerId,
      sellerId: "phaseD-rev-seller4b",
      total: 400,
      productCreditApplied: 120,
      productCreditLedgerEntryId: "phaseD-rev-redemption4",
    });
    await db.collection("orders").doc(orderIdA).set(beforeA);
    await db.collection("orders").doc(orderIdB).set(beforeB);

    // Cancel ONLY order A.
    const afterA = { ...beforeA, orderStatus: "cancelled", status: "cancelled" };
    await fireCancellation(orderIdA, beforeA, afterA);

    const balAfter = await getBalance(customerId);
    const orderASnap = await db.collection("orders").doc(orderIdA).get();
    const orderBSnap = await db.collection("orders").doc(orderIdB).get();

    const ok =
      balAfter.available === 180 && // only order A's share was reversed
      orderASnap.data().productCreditReversed === true &&
      orderBSnap.data().productCreditReversed === false; // order B untouched
    record(
      "4_multiseller_cancels_only_own_share",
      ok,
      `available restored by 180 (order A's share only, ${balAfter.available}); order A reversed=true, order B reversed=false (untouched)`,
      `balAfter=${JSON.stringify(balAfter)} orderA=${JSON.stringify(orderASnap.data())} orderB=${JSON.stringify(orderBSnap.data())}`
    );
  }

  console.log("=== PHASE D — REVERSAL TRIGGER TEST ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);
  console.log(allPassed ? "\nALL PASSED" : "\nSOME FAILED");
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phaseD reversal test:", e);
  process.exit(1);
});
