// Phase 17, Workstream 1: proves the payment cross-consumption fix —
// createOrder.ts now rejects a payment already consumed by onboarding
// (functions/src/employee/activationCore.ts's `consumedByOnboardingFor`
// marker), symmetric with activationCore.ts's own pre-existing rejection of
// a payment already consumed by an order (`consumedByOrderId`, proven here
// as a regression control). Exercises the REAL compiled
// functions/lib/customer/createOrder.js and
// functions/lib/employee/activationCore.js against the Firestore emulator.
// createOrder is a v2 onCall, wrapped and invoked as
// `wrapped({ data: payload, auth })`. performOnboardingActivation is called
// directly (it is not itself an onCall — activateAssociateOnboarding.ts is
// the thin onCall wrapper around it).
// Run with: node scripts/phase17_payment_consumption_test.js
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
if (admin.apps.length === 0) {
  admin.initializeApp({ projectId: "agrimore-66a4e" });
}
const db = admin.firestore();

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { createOrder } = require("../lib/customer/createOrder");
const { performOnboardingActivation } = require("../lib/employee/activationCore");

const wrappedCreateOrder = test.wrap(createOrder);

async function callCreateOrder(payload, auth) {
  try {
    const result = await wrappedCreateOrder({ data: payload, auth });
    return { ok: true, result };
  } catch (e) {
    return { ok: false, code: e.code, message: e.message };
  }
}

async function seedUser(uid) {
  await db.collection("users").doc(uid).set({ uid, profileCompleted: true });
}

async function seedProduct(productId, sellerId, salePrice, stock) {
  await db.collection("products").doc(productId).set({
    name: `Product ${productId}`,
    salePrice,
    sellerId,
    images: [],
    stock,
    isB2BEnabled: false,
  });
}

const ONBOARDING_CONFIG = {
  isEnabled: true,
  feeAmount: 500,
  currency: "INR",
  feeIsOneTime: true,
  version: 1,
  copy: {
    headline: "h",
    feeLabel: "f",
    supportingStatement: "s",
    whyTheFeeExists: { title: "t", body: ["a"] },
    benefitGroups: [{ key: "g1", title: "G", items: ["i"] }],
    earningsExplainer: { title: "t", body: ["a"], flowSteps: ["a"], variabilityFactors: ["a"] },
    journeySteps: [{ step: 1, title: "t", body: "b" }],
    summaryCard: { title: "t", feeLine: "f", includes: ["i"], ctaLabel: "c", ctaSubtext: "s" },
    supportContact: { title: "t", body: "b", email: "e@example.com", phone: "" },
  },
};

async function seedOnboardingConfig() {
  await db.collection("settings").doc("associate_onboarding").set(ONBOARDING_CONFIG);
}

async function seedEmployee(uid) {
  await db.collection("employees").doc(uid).set({
    userId: uid,
    name: "Test Associate",
    email: `${uid}@phase17-test.example`,
    phone: "9999999999",
    employeeCode: uid.toUpperCase().slice(0, 6),
    status: "pending",
    commissionRate: 0,
    createdBy: "self",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

function orderPayload(productId, paymentId, orderId) {
  return {
    items: [{ productId, quantity: 1 }],
    orderMode: "B2C",
    deliveryAddress: {
      name: "Phase17 Test",
      phone: "9999999996",
      addressLine1: "1 Test Street",
      addressLine2: "",
      city: "Chennai",
      state: "Tamil Nadu",
      zipcode: "600001",
      country: "India",
      latitude: 13.0827,
      longitude: 80.2707,
    },
    paymentMethod: "razorpay",
    razorpayPaymentId: paymentId,
    razorpayOrderId: orderId,
    deliveryCharge: 0,
    tax: 0,
  };
}

async function main() {
  let allPassed = true;
  const results = {};

  console.log("=== PHASE 17, WORKSTREAM 1 — payment cross-consumption fix ===");

  // Scenario 1 — THE fix: a payment already consumed by onboarding cannot
  // create an order.
  {
    const uid = "phase17-pc-customer1";
    const productId = "phase17-pc-product1";
    const paymentId = "phase17-pay-onboarding-consumed";
    const orderId = "phase17-order-1";
    await seedUser(uid);
    await seedProduct(productId, "phase17-pc-seller1", 500, 50);
    await db.collection("verified_payments").doc(paymentId).set({
      orderId,
      paymentId,
      userId: uid,
      status: "captured",
      amount: 500,
      consumedByOnboardingFor: uid,
      consumedByOnboardingAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const r = await callCreateOrder(orderPayload(productId, paymentId, orderId), { uid, token: {} });
    console.log("Scenario 1 raw:", JSON.stringify(r, null, 2));
    const s =
      !r.ok &&
      r.code === "failed-precondition" &&
      r.message.toLowerCase().includes("onboarding");
    results.scenario1_onboarding_consumed_payment_cannot_create_order = s;
    console.log(`Scenario 1: ${s ? "PASSED" : "FAILED"} — code=${r.code} message="${r.message}"`);
    if (!s) allPassed = false;

    const orders = await db.collection("orders").where("userId", "==", uid).get();
    const s1b = orders.empty;
    results.scenario1b_no_order_created = s1b;
    console.log(`Scenario 1b: ${s1b ? "PASSED" : "FAILED"} — orders found=${orders.size}`);
    if (!s1b) allPassed = false;
  }

  // Scenario 2 — CONTROL: a payment already consumed by an order still
  // cannot activate onboarding (pre-existing behaviour — must not regress).
  {
    const uid = "phase17-pc-customer2";
    const paymentId = "phase17-pay-order-consumed";
    await seedOnboardingConfig();
    await seedEmployee(uid);
    await db.collection("verified_payments").doc(paymentId).set({
      orderId: `order_${paymentId}`,
      paymentId,
      userId: uid,
      status: "captured",
      amount: 500,
      consumedByOrderId: "some-real-order-id",
      consumedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const result = await performOnboardingActivation({ db, uid, paymentId, source: "client" });
    console.log("Scenario 2 raw:", JSON.stringify(result, null, 2));
    const s = result.ok === false && result.failureCode === "payment_already_consumed_by_order";
    results.scenario2_order_consumed_payment_cannot_activate_onboarding = s;
    console.log(`Scenario 2: ${s ? "PASSED" : "FAILED"} — ${JSON.stringify(result)}`);
    if (!s) allPassed = false;

    const employeeDoc = await db.collection("employees").doc(uid).get();
    const s2b = employeeDoc.data()?.onboardingPaid !== true;
    results.scenario2b_employee_not_activated = s2b;
    console.log(`Scenario 2b: ${s2b ? "PASSED" : "FAILED"} — onboardingPaid=${employeeDoc.data()?.onboardingPaid}`);
    if (!s2b) allPassed = false;
  }

  // Scenario 3 — CONTROL: an unconsumed, user-matched, captured payment
  // still creates an order with the correct total.
  {
    const uid = "phase17-pc-customer3";
    const productId = "phase17-pc-product3";
    const paymentId = "phase17-pay-clean";
    const orderId = "phase17-order-3";
    await seedUser(uid);
    await seedProduct(productId, "phase17-pc-seller3", 250, 50);
    await db.collection("verified_payments").doc(paymentId).set({
      orderId,
      paymentId,
      userId: uid,
      status: "captured",
      amount: 250,
    });

    const r = await callCreateOrder(orderPayload(productId, paymentId, orderId), { uid, token: {} });
    console.log("Scenario 3 raw:", JSON.stringify(r, null, 2));
    const s = r.ok && r.result.success === true && r.result.orders[0].total === 250;
    results.scenario3_unconsumed_payment_creates_order = s;
    console.log(`Scenario 3: ${s ? "PASSED" : "FAILED"} — total=${r.result?.orders?.[0]?.total}`);
    if (!s) allPassed = false;

    const paymentDoc = await db.collection("verified_payments").doc(paymentId).get();
    const s3b = !!paymentDoc.data()?.consumedByOrderId;
    results.scenario3b_payment_marked_consumed = s3b;
    console.log(`Scenario 3b: ${s3b ? "PASSED" : "FAILED"} — consumedByOrderId=${paymentDoc.data()?.consumedByOrderId}`);
    if (!s3b) allPassed = false;
  }

  // Scenario 4 — Phase 14 regression control: a payment belonging to a
  // different user still cannot create an order.
  {
    const attackerUid = "phase17-pc-attacker";
    const victimUid = "phase17-pc-victim";
    const productId = "phase17-pc-product4";
    const paymentId = "phase17-pay-victim";
    const orderId = "phase17-order-4";
    await seedUser(attackerUid);
    await seedProduct(productId, "phase17-pc-seller4", 300, 50);
    await db.collection("verified_payments").doc(paymentId).set({
      orderId,
      paymentId,
      userId: victimUid,
      status: "captured",
      amount: 300,
    });

    const r = await callCreateOrder(orderPayload(productId, paymentId, orderId), { uid: attackerUid, token: {} });
    console.log("Scenario 4 raw:", JSON.stringify(r, null, 2));
    const s = !r.ok && r.code === "failed-precondition" && r.message.includes("this user");
    results.scenario4_cross_user_payment_rejected = s;
    console.log(`Scenario 4: ${s ? "PASSED" : "FAILED"} — code=${r.code} message="${r.message}"`);
    if (!s) allPassed = false;
  }

  console.log("");
  console.log(allPassed ? "ALL PASSED" : "SOME FAILED");
  console.log(JSON.stringify(results, null, 2));
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phase17 payment consumption test:", e);
  process.exit(1);
});
