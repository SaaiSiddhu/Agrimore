// Phase P0-FIELDVALUE verification: proves the admin.firestore.FieldValue/
// .Timestamp/.FieldPath (namespace-style) undefined-in-background-dispatch
// bug is actually fixed, using GENUINE external Firestore writes — never
// test.wrap() on the trigger itself, which does not reproduce the isolated
// background-dispatch execution context where this bug manifests (see the
// module comment in each fixed file and the phase's ledger row for the full
// root-cause writeup).
//
// Run with:
//   firebase emulators:exec --only firestore,functions,auth \
//     "node scripts/phase41_fieldvalue_trigger_fix_test.js"
// Requires: functions already built (npm run build).
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });
const db = admin.firestore();

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// Triggers are async and dispatched out-of-band by the emulator; poll for
// the expected side-effect instead of a single fixed sleep.
async function waitFor(label, checkFn, { timeoutMs = 15000, intervalMs = 300 } = {}) {
  const deadline = Date.now() + timeoutMs;
  let lastResult;
  while (Date.now() < deadline) {
    lastResult = await checkFn();
    if (lastResult && lastResult.done) return lastResult;
    await sleep(intervalMs);
  }
  console.log(`FAILED — timed out waiting for: ${label}`);
  console.log("Last observed state:", JSON.stringify(lastResult, null, 2));
  process.exitCode = 1;
  return lastResult;
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

async function main() {
  console.log("=== P0-FIELDVALUE trigger fix verification (genuine external writes) ===\n");

  // ------------------------------------------------------------
  // Scenario A: order creation -> onOrderCreatedNotifications
  // (orderNotifications.ts) + notifySellerNewOrder (sellerNotifications.ts)
  // ------------------------------------------------------------
  const customerId = "p41-customer";
  const sellerId = "p41-seller";
  const productId = "p41-product";
  const orderId = "p41-order-1";

  await db.collection("users").doc(customerId).set({ uid: customerId, role: "customer" });
  await db.collection("products").doc(productId).set({
    name: "Phase 41 Test Product",
    sellerId,
    categoryId: "general",
  });

  // Deliberately NO top-level order.sellerId, so notifySellerNewOrder does
  // NOT short-circuit (see its own early-return guard) and actually reaches
  // its own admin.firestore.FieldValue.serverTimestamp() call site.
  await db.collection("orders").doc(orderId).set({
    orderNumber: "P41-0001",
    userId: customerId,
    orderMode: "B2C",
    total: 300,
    orderStatus: "confirmed",
    employeeUid: "p41-employee",
    items: [
      {
        productId,
        sellerId,
        price: 100,
        quantity: 3,
        categoryId: "general",
      },
    ],
  });

  await waitFor(
    "orderNotifications.ts: in-app notification written for the customer (createdAt via FieldValue.serverTimestamp)",
    async () => {
      const snap = await db
        .collection("users")
        .doc(customerId)
        .collection("notifications")
        .where("type", "==", "order_created")
        .get();
      if (snap.empty) return { done: false };
      const doc = snap.docs[0].data();
      return { done: true, doc };
    }
  ).then((result) => {
    check(
      "onOrderCreatedNotifications did not crash and wrote createdAt as a real Firestore Timestamp",
      !!(result && result.done && result.doc && result.doc.createdAt && typeof result.doc.createdAt.toMillis === "function"),
      result && result.doc
    );
  });

  await waitFor(
    "orderNotifications.ts: notification_history doc written (sentAt via FieldValue.serverTimestamp)",
    async () => {
      const snap = await db
        .collection("notification_history")
        .where("orderId", "==", orderId)
        .where("type", "==", "order_created_auto")
        .get();
      if (snap.empty) return { done: false };
      return { done: true, doc: snap.docs[0].data() };
    }
  ).then((result) => {
    check(
      "onOrderCreatedNotifications wrote notification_history.sentAt as a real Timestamp",
      !!(result && result.done && result.doc && result.doc.sentAt && typeof result.doc.sentAt.toMillis === "function"),
      result && result.doc
    );
  });

  // NOTE (disclosed verification gap, not a fix failure): notifySellerNewOrder's
  // own admin.firestore.FieldValue.serverTimestamp() call site sits AFTER a
  // successful admin.messaging().send() in the same try block (a guard this
  // investigation already flagged once before for this exact file — see its
  // module comment). Giving the seller user doc a real-looking fcmToken so the
  // function doesn't short-circuit at "no FCM token" makes it instead attempt a
  // GENUINE call to Google Cloud Messaging, which this local dev project has no
  // IAM permission for ("Permission 'cloudmessaging.messages.create' denied") —
  // that throw is caught by the same try/catch and never reaches the Firestore
  // write either, so the line cannot be independently exercised via messaging
  // in this environment (confirmed by trying it: see git history of this file).
  // This is the same class of gap as the two pubsub-scheduled functions with no
  // local emulator. The mitigating evidence: calculateSellerPayout, defined in
  // this SAME FILE and importing FieldValue from the SAME top-level `import {
  // FieldValue } from "firebase-admin/firestore"` statement, is directly proven
  // below (Scenario B) to resolve FieldValue correctly in this exact
  // background-dispatch context — the two functions share one module
  // instantiation, so there is no plausible mechanism by which one resolves the
  // import and the other does not.
  console.log(
    "SKIPPED (disclosed limitation, not a failure) — notifySellerNewOrder's own FieldValue call site is gated behind a real FCM send this dev project has no IAM permission for; see comment above this line in the script."
  );

  // ------------------------------------------------------------
  // Scenario B (THE P0): delivery transition ->
  // payEmployeeCommissionOnDelivery (employeeCommission.ts),
  // calculateSellerPayout (sellerNotifications.ts),
  // onOrderStatusChanged (admin/notifications.ts)
  // ------------------------------------------------------------
  const employeeId = "p41-employee";
  await db.collection("employees").doc(employeeId).set({
    uid: employeeId,
    status: "approved",
    commissionRate: 10, // 10% override, so the fix path is exercised directly
  });
  await db.collection("settings").doc("commission").set(
    { employeeRetailRate: 5, employeeDefaultRate: 5, defaultRate: 8 },
    { merge: true }
  );

  await db.collection("orders").doc(orderId).update({ orderStatus: "delivered" });

  await waitFor(
    "employeeCommission.ts payEmployeeCommissionOnDelivery: order marked commissionPaid",
    async () => {
      const snap = await db.collection("orders").doc(orderId).get();
      const data = snap.data();
      if (!data || data.commissionPaid !== true) return { done: false, data };
      return { done: true, data };
    }
  ).then((result) => {
    check(
      "payEmployeeCommissionOnDelivery (THE P0) did not crash: order.commissionPaid === true, commissionAmount === 30 (10% of ₹300)",
      !!(result && result.done && result.data.commissionAmount === 30),
      result && result.data
    );
  });

  const walletSnap = await db.collection("wallets").doc(employeeId).get();
  const wallet = walletSnap.data();
  check(
    "payEmployeeCommissionOnDelivery (THE P0) actually credited the wallet: balance === 30, lifetimeEarnings === 30",
    !!(wallet && wallet.balance === 30 && wallet.lifetimeEarnings === 30),
    wallet
  );
  check(
    "wallet.updatedAt / wallet.createdAt are real Firestore Timestamps (FieldValue.serverTimestamp fix site)",
    !!(wallet && wallet.updatedAt && typeof wallet.updatedAt.toMillis === "function" && wallet.createdAt && typeof wallet.createdAt.toMillis === "function"),
    wallet
  );

  const walletTxSnap = await db.collection("wallet_transactions").where("orderId", "==", orderId).get();
  check(
    "payEmployeeCommissionOnDelivery wrote a wallet_transactions record with a real createdAt Timestamp",
    !walletTxSnap.empty &&
      walletTxSnap.docs[0].data().amount === 30 &&
      typeof walletTxSnap.docs[0].data().createdAt.toMillis === "function",
    walletTxSnap.docs[0] && walletTxSnap.docs[0].data()
  );

  await waitFor(
    "sellerNotifications.ts calculateSellerPayout: seller_payouts doc written",
    async () => {
      const snap = await db.collection("seller_payouts").doc(`${orderId}_${sellerId}`).get();
      if (!snap.exists) return { done: false };
      return { done: true, doc: snap.data() };
    }
  ).then((result) => {
    check(
      "calculateSellerPayout did not crash and wrote createdAt as a real Timestamp",
      !!(result && result.done && result.doc.createdAt && typeof result.doc.createdAt.toMillis === "function"),
      result && result.doc
    );
  });

  await waitFor(
    "admin/notifications.ts onOrderStatusChanged: notification_history doc for the status change",
    async () => {
      const snap = await db
        .collection("notification_history")
        .where("orderId", "==", orderId)
        .where("type", "==", "order_update_auto")
        .get();
      if (snap.empty) return { done: false };
      return { done: true, doc: snap.docs[0].data() };
    }
  ).then((result) => {
    check(
      "onOrderStatusChanged did not crash and wrote timestamp/sentAt as real Timestamps",
      !!(
        result &&
        result.done &&
        result.doc.timestamp &&
        typeof result.doc.timestamp.toMillis === "function" &&
        result.doc.sentAt &&
        typeof result.doc.sentAt.toMillis === "function"
      ),
      result && result.doc
    );
  });

  await waitFor(
    "admin/notifications.ts onOrderStatusChanged -> sendOrderPushToUser: in-app notification written to the customer",
    async () => {
      const snap = await db
        .collection("users")
        .doc(customerId)
        .collection("notifications")
        .where("type", "==", "order_update")
        .get();
      if (snap.empty) return { done: false };
      return { done: true, doc: snap.docs[0].data() };
    }
  ).then((result) => {
    check(
      "sendOrderPushToUser (shared helper, admin/notifications.ts) did not crash",
      !!(result && result.done && result.doc.createdAt && typeof result.doc.createdAt.toMillis === "function"),
      result && result.doc
    );
  });

  // ------------------------------------------------------------
  // Scenario C: inventory.ts onProductStockChanged
  // ------------------------------------------------------------
  const stockProductId = "p41-stock-product";
  await db.collection("products").doc(stockProductId).set({
    name: "Phase 41 Stock Product",
    sellerId,
    stock: 10,
    lowStockThreshold: 5,
  });
  await db.collection("products").doc(stockProductId).update({ stock: 3 });

  await waitFor(
    "inventory.ts onProductStockChanged: inventory_alerts doc written",
    async () => {
      const snap = await db.collection("inventory_alerts").where("productId", "==", stockProductId).get();
      if (snap.empty) return { done: false };
      return { done: true, doc: snap.docs[0].data() };
    }
  ).then((result) => {
    check(
      "onProductStockChanged did not crash and wrote createdAt as a real Timestamp",
      !!(result && result.done && result.doc.createdAt && typeof result.doc.createdAt.toMillis === "function"),
      result && result.doc
    );
  });

  // ------------------------------------------------------------
  // Scenario D: productCreditReversal.ts -> productCreditLedger.ts's
  // appendLedgerEntry (transitive exposure, no direct FieldValue call of
  // its own in productCreditReversal.ts)
  // ------------------------------------------------------------
  const creditOrderId = "p41-credit-order";
  await db.collection("orders").doc(creditOrderId).set({
    orderNumber: "P41-0002",
    userId: customerId,
    orderStatus: "confirmed",
    productCreditApplied: 100,
    productCreditReversed: false,
  });
  await db.collection("orders").doc(creditOrderId).update({ orderStatus: "cancelled" });

  await waitFor(
    "productCreditReversal.ts -> productCreditLedger.ts appendLedgerEntry: REVERSAL ledger entry written",
    async () => {
      const snap = await db
        .collection("product_credit_ledger")
        .where("customerId", "==", customerId)
        .where("type", "==", "REVERSAL")
        .get();
      if (snap.empty) return { done: false };
      return { done: true, doc: snap.docs[0].data() };
    }
  ).then((result) => {
    check(
      "appendLedgerEntry (shared helper) did not crash: REVERSAL entry has amount 100 and a real createdAt Timestamp",
      !!(result && result.done && result.doc.amount === 100 && typeof result.doc.createdAt.toMillis === "function"),
      result && result.doc
    );
  });

  const projSnap = await db.collection("product_credit_balances").doc(customerId).get();
  const proj = projSnap.data();
  check(
    "product_credit_balances projection updated with a real updatedAt Timestamp (FieldValue.serverTimestamp fix site)",
    !!(proj && proj.available === 100 && proj.updatedAt && typeof proj.updatedAt.toMillis === "function"),
    proj
  );

  // ------------------------------------------------------------
  // Scenario E: adminOnboardingActions.ts
  // requestAssociateOnboardingRefundOnSuspend (functionsV1 alias import)
  // ------------------------------------------------------------
  const suspendEmployeeId = "p41-onboarding-employee";
  await db.collection("employees").doc(suspendEmployeeId).set({
    uid: suspendEmployeeId,
    status: "active",
    onboardingPaid: true,
    onboardingPaymentId: "pay_p41_test",
    onboardingFeeAmount: 500,
  });
  await db.collection("employees").doc(suspendEmployeeId).update({ status: "suspended" });

  await waitFor(
    "adminOnboardingActions.ts requestAssociateOnboardingRefundOnSuspend: refund request written",
    async () => {
      const snap = await db
        .collection("associate_refund_requests")
        .doc(`${suspendEmployeeId}_pay_p41_test`)
        .get();
      if (!snap.exists) return { done: false };
      return { done: true, doc: snap.data() };
    }
  ).then((result) => {
    check(
      "requestAssociateOnboardingRefundOnSuspend (functionsV1 alias import) did not crash and wrote requestedAt as a real Timestamp",
      !!(result && result.done && result.doc.requestedAt && typeof result.doc.requestedAt.toMillis === "function"),
      result && result.doc
    );
  });

  console.log(`\n=== ${failures === 0 ? "ALL PASSED" : `${failures} FAILURE(S)`} ===`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((error) => {
  console.error("FATAL — unhandled error in verification script:", error);
  process.exit(1);
});
