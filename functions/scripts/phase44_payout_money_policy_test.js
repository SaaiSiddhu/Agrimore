// Phase FIX-4B: proves all three payout money-policy decisions actually
// compute correctly against emulated Firestore — WS1 (D-COMMISSION-BASE,
// N-29), WS2 (D-PAYOUT-MIXED-CATEGORY, N-27), WS3 (D-COMMISSION-REVERSAL,
// N-9).
//
// INVOCATION STYLE: both payEmployeeCommissionOnDelivery and
// calculateSellerPayout and the new reverseEmployeeCommissionOnCancellation
// are v1 Firestore .onUpdate triggers, invoked via test.wrap() called
// OFFLINE as wrapped(change, context) — the established, working pattern
// this codebase already uses for this exact class of trigger
// (phase16d1_commission_test.js, phase28_payout_integrity_test.js,
// phase43_referral_completion_test.js). This calls the REAL compiled
// handler directly; every Firestore read/write inside it still hits the
// REAL Firestore emulator.
//
// Run with:
//   firebase emulators:exec --only firestore,functions,auth \
//     "node scripts/phase44_payout_money_policy_test.js"
// Requires: functions already built (npm run build).
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });
const db = admin.firestore();

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { payEmployeeCommissionOnDelivery, reverseEmployeeCommissionOnCancellation } = require("../lib/customer/employeeCommission");
const { calculateSellerPayout } = require("../lib/customer/sellerNotifications");

const wrappedCommission = test.wrap(payEmployeeCommissionOnDelivery);
const wrappedReversal = test.wrap(reverseEmployeeCommissionOnCancellation);
const wrappedPayout = test.wrap(calculateSellerPayout);

async function fireTransition(wrapped, orderId, beforeData, afterData) {
  const beforeSnap = test.firestore.makeDocumentSnapshot(beforeData, `orders/${orderId}`);
  const afterSnap = test.firestore.makeDocumentSnapshot(afterData, `orders/${orderId}`);
  const change = test.makeChange(beforeSnap, afterSnap);
  return wrapped(change, { params: { orderId } });
}

let failures = 0;
function check(label, condition, extra) {
  if (condition) {
    console.log(`PASSED — ${label}`);
  } else {
    failures++;
    console.log(`FAILED — ${label}`);
    if (extra !== undefined) console.log("  detail:", JSON.stringify(extra, null, 2));
  }
}

async function clearCommissionSettings() {
  await db.collection("settings").doc("commission").delete();
}

console.log("=== Phase FIX-4B payout money-policy verification ===\n");

async function main() {
  // ==========================================================
  // WS1 (N-29, D-COMMISSION-BASE): commission excludes delivery + tax.
  // ==========================================================
  {
    const employeeUid = "p44-ws1-emp";
    const orderId = "p44-ws1-order";
    await clearCommissionSettings();
    await db.collection("employees").doc(employeeUid).set({ userId: employeeUid, status: "pending", commissionRate: 10 });

    const before = {
      userId: "p44-ws1-customer",
      orderNumber: "ORD-P44-WS1",
      subtotal: 1000,
      discount: 100,
      deliveryCharge: 50,
      tax: 20,
      total: 970, // 1000 - 100 + 50 + 20
      orderMode: "B2C",
      orderStatus: "pending",
      status: "pending",
      employeeUid,
      commissionPaid: false,
    };
    const after = { ...before, orderStatus: "delivered", status: "delivered" };
    await db.collection("orders").doc(orderId).set(before);
    await fireTransition(wrappedCommission, orderId, before, after);

    const orderSnap = await db.collection("orders").doc(orderId).get();
    const order = orderSnap.data();
    // OLD basis would be 970 * 10% = 97. NEW basis: max(0, 1000-100) * 10% = 90.
    check(
      "WS1: commission is computed on goods subtotal (900) not order.total (970) — 90, not 97",
      order.commissionAmount === 90,
      order
    );
  }

  // ==========================================================
  // WS2 (N-27, D-PAYOUT-MIXED-CATEGORY): weighted average across categories.
  // ==========================================================
  {
    await db.collection("settings").doc("commission").set({
      defaultRate: 8,
      categoryRates: { "p44-cat-fruit": 5, "p44-cat-electronics": 15 },
    });
    await db.collection("products").doc("p44-prod-fruit").set({ categoryId: "p44-cat-fruit" });
    await db.collection("products").doc("p44-prod-electronics").set({ categoryId: "p44-cat-electronics" });

    const orderId = "p44-ws2-order";
    const sellerId = "p44-ws2-seller";
    const before = {
      userId: "p44-ws2-customer",
      orderNumber: "ORD-P44-WS2",
      items: [
        { productId: "p44-prod-fruit", sellerId, price: 600, quantity: 1 },
        { productId: "p44-prod-electronics", sellerId, price: 400, quantity: 1 },
      ],
      total: 1000,
      orderStatus: "pending",
      status: "pending",
    };
    const after = { ...before, orderStatus: "delivered", status: "delivered" };
    await db.collection("orders").doc(orderId).set(before);
    await fireTransition(wrappedPayout, orderId, before, after);

    const payoutSnap = await db.collection("seller_payouts").doc(`${orderId}_${sellerId}`).get();
    const payout = payoutSnap.data();
    // OLD (first-item-category) behaviour would use fruit's 5% on the whole
    // ₹1000 -> commissionAmount 50. NEW (weighted average): 600*5% + 400*15%
    // = 30 + 60 = 90.
    check(
      "WS2: mixed-category payout sums each item's OWN category rate (90), not the first item's rate applied to everything (50)",
      Math.abs(payout.commissionAmount - 90) < 0.01,
      payout
    );
    check(
      "WS2: stored commissionRate is the derived weighted average (9%, = 90/1000*100)",
      Math.abs(payout.commissionRate - 9) < 0.01,
      payout
    );
    check(
      "WS2: netAmount reflects the weighted commission (1000 - 90 = 910)",
      Math.abs(payout.netAmount - 910) < 0.01,
      payout
    );
  }

  // WS2 regression: a single-category order's weighted average must equal
  // that category's own plain rate (phase28's own single-category
  // assumption must still hold).
  {
    const orderId = "p44-ws2b-order";
    const sellerId = "p44-ws2b-seller";
    const before = {
      userId: "p44-ws2b-customer",
      orderNumber: "ORD-P44-WS2B",
      items: [{ productId: "p44-prod-fruit", sellerId, price: 500, quantity: 2 }],
      total: 1000,
      orderStatus: "pending",
      status: "pending",
    };
    const after = { ...before, orderStatus: "delivered", status: "delivered" };
    await db.collection("orders").doc(orderId).set(before);
    await fireTransition(wrappedPayout, orderId, before, after);

    const payoutSnap = await db.collection("seller_payouts").doc(`${orderId}_${sellerId}`).get();
    const payout = payoutSnap.data();
    check(
      "WS2 REGRESSION: single-category order still pays exactly that category's own rate (5% of 1000 = 50)",
      Math.abs(payout.commissionAmount - 50) < 0.01 && Math.abs(payout.commissionRate - 5) < 0.01,
      payout
    );
  }

  // ==========================================================
  // CAT-17: a legacy-shaped product (no top-level categoryId, only a
  // `category` map) must still resolve to its own configured category rate,
  // not silently fall back to the default rate.
  // ==========================================================
  {
    await db.collection("settings").doc("commission").set({
      defaultRate: 8,
      categoryRates: { "p44-cat-fruit": 5, "p44-cat-electronics": 15, "p44-cat-legacy": 20 },
    });
    await db.collection("products").doc("p44-prod-legacy").set({
      category: { id: "p44-cat-legacy", name: "Legacy Category" },
    });

    const orderId = "p44-cat17-order";
    const sellerId = "p44-cat17-seller";
    const before = {
      userId: "p44-cat17-customer",
      orderNumber: "ORD-P44-CAT17",
      items: [{ productId: "p44-prod-legacy", sellerId, price: 1000, quantity: 1 }],
      total: 1000,
      orderStatus: "pending",
      status: "pending",
    };
    const after = { ...before, orderStatus: "delivered", status: "delivered" };
    await db.collection("orders").doc(orderId).set(before);
    await fireTransition(wrappedPayout, orderId, before, after);

    const payoutSnap = await db.collection("seller_payouts").doc(`${orderId}_${sellerId}`).get();
    const payout = payoutSnap.data();
    // Pre-CAT-17 bug: a bare `.categoryId` read returns undefined for this
    // legacy-shaped product, so this would silently use defaultRate (8%) ->
    // commissionAmount 80. Fixed: resolveProductCategoryId recovers
    // "p44-cat-legacy" from the `category` map, applying its own 20% rate.
    check(
      "CAT-17: a legacy-shaped (category-as-map) product pays its OWN category rate (20% of 1000 = 200), not the default rate (80)",
      Math.abs(payout.commissionAmount - 200) < 0.01 && Math.abs(payout.commissionRate - 20) < 0.01,
      payout
    );
    check(
      "CAT-17: netAmount reflects the real category rate (1000 - 200 = 800)",
      Math.abs(payout.netAmount - 800) < 0.01,
      payout
    );
  }

  // ==========================================================
  // WS3 (N-9, D-COMMISSION-REVERSAL): claw back on cancellation.
  // ==========================================================
  {
    // Full pipeline: pay commission for real (using the WS1 basis), THEN
    // cancel the order and confirm the exact paid amount is reversed.
    const employeeUid = "p44-ws3-emp";
    const orderId = "p44-ws3-order";
    await clearCommissionSettings();
    await db.collection("employees").doc(employeeUid).set({ userId: employeeUid, status: "pending", commissionRate: 10 });
    await db.collection("wallets").doc(employeeUid).set({ userId: employeeUid, balance: 50, coins: 0, createdAt: admin.firestore.Timestamp.now() });

    const pending = {
      userId: "p44-ws3-customer",
      orderNumber: "ORD-P44-WS3",
      subtotal: 1000,
      discount: 0,
      deliveryCharge: 0,
      tax: 0,
      total: 1000,
      orderMode: "B2C",
      orderStatus: "pending",
      status: "pending",
      employeeUid,
      commissionPaid: false,
    };
    const delivered = { ...pending, orderStatus: "delivered", status: "delivered" };
    await db.collection("orders").doc(orderId).set(pending);
    await fireTransition(wrappedCommission, orderId, pending, delivered);

    const afterPaySnap = await db.collection("orders").doc(orderId).get();
    const afterPay = afterPaySnap.data();
    check("WS3 setup: commission was actually paid (100 = 10% of 1000)", afterPay.commissionAmount === 100, afterPay);

    const walletAfterPay = await db.collection("wallets").doc(employeeUid).get();
    check("WS3 setup: wallet credited to 150 (50 starting + 100 commission)", walletAfterPay.data().balance === 150, walletAfterPay.data());

    // Now cancel the delivered order.
    const cancelled = { ...afterPay, orderStatus: "cancelled", status: "cancelled" };
    await db.collection("orders").doc(orderId).update({ orderStatus: "cancelled", status: "cancelled" });
    await fireTransition(wrappedReversal, orderId, afterPay, cancelled);

    const walletAfterReversal = await db.collection("wallets").doc(employeeUid).get();
    check(
      "WS3: reversal debits the exact commission amount (150 - 100 = 50)",
      walletAfterReversal.data().balance === 50,
      walletAfterReversal.data()
    );

    const orderAfterReversal = await db.collection("orders").doc(orderId).get();
    check(
      "WS3: order marked commissionReversed:true",
      orderAfterReversal.data().commissionReversed === true,
      orderAfterReversal.data()
    );

    const reversalTx = await db
      .collection("wallet_transactions")
      .where("orderId", "==", orderId)
      .where("type", "==", "debit")
      .get();
    check(
      "WS3: a debit wallet_transactions doc was created for the reversal (amount 100)",
      reversalTx.size === 1 && reversalTx.docs[0].data().amount === 100,
      reversalTx.docs.map((d) => d.data())
    );

    // Retry: a second (duplicated/retried) trigger invocation of the SAME
    // already-reversed transition must not double-debit.
    await fireTransition(wrappedReversal, orderId, afterPay, cancelled);
    const walletAfterRetry = await db.collection("wallets").doc(employeeUid).get();
    check(
      "WS3 RETRY: a repeated reversal invocation does not double-debit (still 50)",
      walletAfterRetry.data().balance === 50,
      walletAfterRetry.data()
    );
  }

  // WS3: balance CAN go negative — no floor, per D-COMMISSION-REVERSAL.
  {
    const employeeUid = "p44-ws3neg-emp";
    const orderId = "p44-ws3neg-order";
    await db.collection("wallets").doc(employeeUid).set({ userId: employeeUid, balance: 20, coins: 0 });
    const paidOrder = {
      userId: "p44-ws3neg-customer",
      orderNumber: "ORD-P44-WS3NEG",
      orderStatus: "delivered",
      status: "delivered",
      employeeUid,
      commissionPaid: true,
      commissionAmount: 100,
    };
    await db.collection("orders").doc(orderId).set(paidOrder);
    const cancelled = { ...paidOrder, orderStatus: "refunded", status: "refunded" };
    await fireTransition(wrappedReversal, orderId, paidOrder, cancelled);

    const wallet = await db.collection("wallets").doc(employeeUid).get();
    check(
      "WS3 NEGATIVE BALANCE: reversal via 'refunded' status debits unconditionally, balance goes negative (20 - 100 = -80), not floored at 0",
      wallet.data().balance === -80,
      wallet.data()
    );
  }

  // WS3: an order that never paid commission is a safe no-op on cancellation.
  {
    const orderId = "p44-ws3none-order";
    const neverPaid = {
      userId: "p44-ws3none-customer",
      orderNumber: "ORD-P44-WS3NONE",
      orderStatus: "delivered",
      status: "delivered",
      employeeUid: null,
      commissionPaid: false,
    };
    await db.collection("orders").doc(orderId).set(neverPaid);
    const cancelled = { ...neverPaid, orderStatus: "cancelled", status: "cancelled" };
    await fireTransition(wrappedReversal, orderId, neverPaid, cancelled);

    const orderAfter = await db.collection("orders").doc(orderId).get();
    check(
      "WS3 NO-OP: an order that never paid commission is untouched by the reversal trigger (no commissionReversed flag written)",
      orderAfter.data().commissionReversed === undefined,
      orderAfter.data()
    );
  }

  console.log(`\n=== ${failures === 0 ? "ALL PASSED" : `${failures} FAILURE(S)`} ===`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((error) => {
  console.error("FATAL — unhandled error in verification script:", error);
  process.exit(1);
});
