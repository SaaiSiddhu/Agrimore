// Phase D-1, Workstreams 2 & 3 — productCreditReversal.ts hardening.
// Proves (a) DEFECT D-1: the trigger now fires on a transition into
// 'cancelled' signalled by EITHER `orderStatus` OR the mirrored `status`
// field (seller_panel_screen.dart writes only `status`), and (b) DEFECT
// D-0/Workstream 2 defence-in-depth: the refund amount/customerId/
// relatedEntryId are re-derived from the REAL order document inside the
// transaction, never trusted from the trigger's `after` payload — so even
// a tampered/inflated `after.productCreditApplied` cannot dictate the
// refund. Same direct-invocation harness shape as phase16d1_commission_test.js
// / phaseD_reversal_test.js: test.wrap(reverseProductCreditOnCancellation)
// called as `wrapped(change, context)`.
// Run with: node scripts/phaseD1_reversal_hardening_test.js
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
async function reversalCountFor(orderId) {
  const snap = await db.collection("product_credit_ledger").where("orderId", "==", orderId).where("type", "==", "REVERSAL").get();
  return snap.size;
}

function baseOrder(overrides) {
  return {
    userId: overrides.userId,
    sellerId: overrides.sellerId || "phaseD1-rev-seller",
    orderNumber: `ORD-${overrides.orderIdHint || "x"}`,
    items: [],
    subtotal: overrides.total ?? 1000,
    discount: 0,
    deliveryCharge: 0,
    tax: 0,
    total: overrides.total ?? 1000,
    paymentMethod: "cod",
    paymentStatus: "pending",
    orderStatus: overrides.orderStatus ?? "pending",
    status: overrides.status ?? "pending",
    orderMode: "B2C",
    productCreditApplied: overrides.productCreditApplied ?? 0,
    productCreditHoldId: overrides.productCreditHoldId ?? null,
    productCreditReversed: overrides.productCreditReversed ?? false,
    productCreditLedgerEntryId: overrides.productCreditLedgerEntryId ?? null,
  };
}

async function main() {
  const results = {};
  const record = (key, ok, passMsg, failMsg) => {
    results[key] = ok ? `PASSED — ${passMsg}` : `FAILED — ${failMsg}`;
  };

  // ============================================================
  // Scenario 1 (DEFECT D-1): cancellation signalled by `status` ALONE
  // fires the reversal. `orderStatus` stays 'pending' throughout — exactly
  // what seller_panel_screen.dart's _updateOrderStatus does.
  // ============================================================
  {
    const customerId = "phaseD1-rev-c1";
    const orderId = "phaseD1-rev-order1";
    await seedBalance(customerId, 100);
    const before = baseOrder({ orderIdHint: "1", userId: customerId, total: 500, productCreditApplied: 250, productCreditLedgerEntryId: "phaseD1-rev-entry1" });
    const after = { ...before, status: "cancelled" }; // orderStatus untouched — still 'pending'
    await db.collection("orders").doc(orderId).set(after); // the REAL document after the (simulated) seller write

    const balBefore = await getBalance(customerId);
    await fireCancellation(orderId, before, after);
    const balAfter = await getBalance(customerId);
    const orderSnap = await db.collection("orders").doc(orderId).get();

    const ok = balAfter.available === balBefore.available + 250 && orderSnap.data().productCreditReversed === true;
    record(
      "1_status_field_alone_fires_reversal",
      ok,
      `status-only cancellation reversed 250 (available ${balBefore.available} -> ${balAfter.available}), productCreditReversed=true`,
      `before=${balBefore.available} after=${JSON.stringify(balAfter)} order=${JSON.stringify(orderSnap.data())}`
    );
  }

  // ============================================================
  // Scenario 2 (no regression): cancellation signalled by `orderStatus`
  // ALONE still fires — `status` stays 'pending' throughout, exactly what
  // order_provider.dart's cancelOrder() (customer path) does.
  // ============================================================
  {
    const customerId = "phaseD1-rev-c2";
    const orderId = "phaseD1-rev-order2";
    await seedBalance(customerId, 100);
    const before = baseOrder({ orderIdHint: "2", userId: customerId, total: 500, productCreditApplied: 180, productCreditLedgerEntryId: "phaseD1-rev-entry2" });
    const after = { ...before, orderStatus: "cancelled" }; // status untouched — still 'pending'
    await db.collection("orders").doc(orderId).set(after);

    const balBefore = await getBalance(customerId);
    await fireCancellation(orderId, before, after);
    const balAfter = await getBalance(customerId);
    const orderSnap = await db.collection("orders").doc(orderId).get();

    const ok = balAfter.available === balBefore.available + 180 && orderSnap.data().productCreditReversed === true;
    record(
      "2_orderStatus_field_alone_still_fires",
      ok,
      `orderStatus-only cancellation still reversed 180 (available ${balBefore.available} -> ${balAfter.available})`,
      `before=${balBefore.available} after=${JSON.stringify(balAfter)} order=${JSON.stringify(orderSnap.data())}`
    );
  }

  // ============================================================
  // Scenario 3: a single write setting BOTH fields to cancelled at once
  // fires exactly ONCE (one invocation, one REVERSAL entry).
  // ============================================================
  {
    const customerId = "phaseD1-rev-c3";
    const orderId = "phaseD1-rev-order3";
    await seedBalance(customerId, 0);
    const before = baseOrder({ orderIdHint: "3", userId: customerId, total: 900, productCreditApplied: 400, productCreditLedgerEntryId: "phaseD1-rev-entry3" });
    const after = { ...before, orderStatus: "cancelled", status: "cancelled" };
    await db.collection("orders").doc(orderId).set(after);

    await fireCancellation(orderId, before, after);
    const balAfter = await getBalance(customerId);
    const count = await reversalCountFor(orderId);

    const ok = balAfter.available === 400 && count === 1;
    record(
      "3_both_fields_at_once_fires_exactly_once",
      ok,
      `available=400, exactly 1 REVERSAL entry written`,
      `available=${balAfter.available} reversalCount=${count}`
    );
  }

  // ============================================================
  // Scenario 4: flipping the OTHER field AFTER the order is already
  // cancelled (scenario 1's order — cancelled via `status`, orderStatus
  // still 'pending') must NOT double-refund. The top-level wasCancelled
  // guard must short-circuit before a transaction ever opens.
  // ============================================================
  {
    const customerId = "phaseD1-rev-c1"; // scenario 1's customer/order
    const orderId = "phaseD1-rev-order1";
    const balBefore = await getBalance(customerId);
    const currentDoc = (await db.collection("orders").doc(orderId).get()).data(); // status:'cancelled', orderStatus:'pending', reversed:true

    const before2 = currentDoc;
    const after2 = { ...currentDoc, orderStatus: "cancelled" }; // now BOTH fields cancelled
    await db.collection("orders").doc(orderId).set(after2);

    await fireCancellation(orderId, before2, after2);
    const balAfter = await getBalance(customerId);
    const count = await reversalCountFor(orderId);

    const ok = balAfter.available === balBefore.available && count === 1;
    record(
      "4_flipping_other_field_after_cancelled_no_double_refund",
      ok,
      `flipping orderStatus after the order was already cancelled via status changed nothing: available unchanged (${balAfter.available}), still exactly 1 REVERSAL entry`,
      `balBefore=${balBefore.available} balAfter=${JSON.stringify(balAfter)} reversalCount=${count}`
    );
  }

  // ============================================================
  // Scenario 5 (DEFECT D-0/Workstream 2): a trigger payload whose
  // `after.productCreditApplied` is inflated far above the value actually
  // STORED on the order document refunds only the stored amount — proving
  // the trigger no longer trusts `after` for the refund amount.
  // ============================================================
  {
    const customerId = "phaseD1-rev-c5";
    const orderId = "phaseD1-rev-order5";
    await seedBalance(customerId, 0);
    const realStoredAmount = 150;
    // The REAL Firestore document — what a legitimate write actually left,
    // and what the hardened trigger's transaction will read.
    const realDoc = baseOrder({
      orderIdHint: "5",
      userId: customerId,
      total: 500,
      productCreditApplied: realStoredAmount,
      productCreditReversed: false,
      productCreditLedgerEntryId: "phaseD1-rev-entry5",
      orderStatus: "cancelled",
      status: "cancelled",
    });
    await db.collection("orders").doc(orderId).set(realDoc);

    // A TAMPERED trigger payload — simulates what an attacker-influenced
    // `after` snapshot could claim, independent of what firestore.rules
    // would allow in production. Workstream 2 exists precisely so this
    // payload cannot dictate the refund.
    const before = { ...realDoc, orderStatus: "pending", status: "pending", productCreditApplied: realStoredAmount, productCreditReversed: false };
    const tamperedAfter = { ...realDoc, productCreditApplied: 999999 };

    await fireCancellation(orderId, before, tamperedAfter);
    const balAfter = await getBalance(customerId);
    const orderSnap = await db.collection("orders").doc(orderId).get();

    const ok = balAfter.available === realStoredAmount && orderSnap.data().productCreditReversed === true;
    record(
      "5_tampered_after_payload_refunds_only_stored_amount",
      ok,
      `after.productCreditApplied=999999 in the payload; refund was the STORED amount (${realStoredAmount}), not the tampered one — available=${balAfter.available}`,
      `available=${JSON.stringify(balAfter)} order=${JSON.stringify(orderSnap.data())}`
    );
  }

  // ============================================================
  // Scenario 6: redelivery of an identical event still writes exactly one
  // REVERSAL (at-least-once trigger delivery semantics).
  // ============================================================
  {
    const customerId = "phaseD1-rev-c6";
    const orderId = "phaseD1-rev-order6";
    await seedBalance(customerId, 0);
    const before = baseOrder({ orderIdHint: "6", userId: customerId, total: 700, productCreditApplied: 220, productCreditLedgerEntryId: "phaseD1-rev-entry6" });
    const after = { ...before, orderStatus: "cancelled", status: "cancelled" };
    await db.collection("orders").doc(orderId).set(after);

    await fireCancellation(orderId, before, after);
    const balAfterFirst = await getBalance(customerId);

    // Redeliver the EXACT SAME event.
    await fireCancellation(orderId, before, after);
    const balAfterSecond = await getBalance(customerId);
    const count = await reversalCountFor(orderId);

    const ok = balAfterFirst.available === 220 && balAfterSecond.available === 220 && count === 1;
    record(
      "6_redelivery_of_identical_event_is_idempotent",
      ok,
      `first delivery reversed 220, redelivery changed nothing (still ${balAfterSecond.available}), exactly 1 REVERSAL entry`,
      `first=${balAfterFirst.available} second=${balAfterSecond.available} reversalCount=${count}`
    );
  }

  // ============================================================
  // Scenario 7: an order with zero applied credit writes no ledger entry
  // at all.
  // ============================================================
  {
    const customerId = "phaseD1-rev-c7";
    const orderId = "phaseD1-rev-order7";
    await seedBalance(customerId, 50);
    const before = baseOrder({ orderIdHint: "7", userId: customerId, total: 300, productCreditApplied: 0 });
    const after = { ...before, orderStatus: "cancelled", status: "cancelled" };
    await db.collection("orders").doc(orderId).set(after);

    const balBefore = await getBalance(customerId);
    await fireCancellation(orderId, before, after);
    const balAfter = await getBalance(customerId);
    const count = await reversalCountFor(orderId);

    const ok = balAfter.available === balBefore.available && count === 0;
    record(
      "7_zero_credit_order_writes_no_ledger_entry",
      ok,
      `balance unchanged (${balAfter.available}), no REVERSAL entry written`,
      `balBefore=${balBefore.available} balAfter=${JSON.stringify(balAfter)} reversalCount=${count}`
    );
  }

  console.log("=== PHASE D-1 — REVERSAL TRIGGER HARDENING TEST (DEFECT D-0 W2 / DEFECT D-1) ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);
  const allPassed = Object.values(results).every((v) => v.startsWith("PASSED"));
  console.log(allPassed ? "\nALL PASSED" : "\nSOME FAILED");
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phaseD1 reversal hardening test:", e);
  process.exit(1);
});
