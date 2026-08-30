// Phase 16, Workstream 7: proves createOrder.ts rejects an incomplete-profile
// caller — even via direct callable invocation, not just client routing —
// with a positive control proving a grandfathered complete-profile user's
// order still succeeds with the correct total. Mirrors
// phase15_order_integrity_test.js's firebase-functions-test harness exactly;
// createOrder is a v2 onCall, wrapped and invoked as
// `wrapped({ data: payload, auth })`.
// Run with: node scripts/phase16_enforcement_test.js
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { createOrder } = require("../lib/customer/createOrder");

const wrapped = test.wrap(createOrder);

async function callAndCapture(payload, auth) {
  try {
    const result = await wrapped({ data: payload, auth });
    return { ok: true, result };
  } catch (e) {
    return { ok: false, code: e.code, message: e.message };
  }
}

async function seedProduct(db, productId, sellerId, salePrice, stock) {
  await db.collection("products").doc(productId).set({
    name: `Product ${productId}`,
    salePrice,
    sellerId,
    images: [],
    stock,
    isB2BEnabled: false,
  });
}

function orderPayload(productId) {
  return {
    items: [{ productId, quantity: 2 }],
    orderMode: "B2C",
    deliveryAddress: {
      name: "Phase16 Enforcement Test",
      phone: "9999999997",
      addressLine1: "1 Test Street",
      addressLine2: "",
      city: "Chennai",
      state: "Tamil Nadu",
      zipcode: "600001",
      country: "India",
      latitude: 13.0827,
      longitude: 80.2707,
    },
    paymentMethod: "cod",
    deliveryCharge: 0,
    tax: 0,
  };
}

async function main() {
  const db = admin.firestore();
  let allPassed = true;
  const results = {};

  console.log("=== PHASE 16, WORKSTREAM 7 — profile-completion enforcement ===");

  // Scenario 1 — THE enforcement proof: an incomplete-profile user calling
  // createOrder DIRECTLY (bypassing any client-side routing/gate entirely)
  // is rejected.
  {
    const uid = "phase16-enforce-incomplete-user";
    const sellerId = "phase16-enforce-seller1";
    const productId = "phase16-enforce-product1";
    await seedProduct(db, productId, sellerId, 100, 50);
    await db.collection("users").doc(uid).set({
      uid,
      email: "",
      name: "Incomplete User",
      phone: "+919876500030",
      role: "user",
      profileCompleted: false,
    });

    const r = await callAndCapture(orderPayload(productId), { uid, token: {} });
    console.log("Scenario 1 raw:", JSON.stringify(r, null, 2));
    const s = !r.ok && r.code === "failed-precondition" && r.message.toLowerCase().includes("profile");
    results.scenario1_incomplete_profile_createorder_rejected = s;
    console.log(`Scenario 1: ${s ? "PASSED" : "FAILED"} — code=${r.code} message="${r.message}"`);
    if (!s) allPassed = false;

    // Confirm no order was actually created despite the rejection.
    const orders = await db.collection("orders").where("userId", "==", uid).get();
    const s1b = orders.empty;
    results.scenario1b_no_order_created = s1b;
    console.log(`Scenario 1b: ${s1b ? "PASSED" : "FAILED"} — orders found=${orders.size}`);
    if (!s1b) allPassed = false;
  }

  // Scenario 2 — no users/{uid} document at all (never signed in through
  // any real flow) — also rejected, not a crash.
  {
    const uid = "phase16-enforce-no-doc";
    const sellerId = "phase16-enforce-seller2";
    const productId = "phase16-enforce-product2";
    await seedProduct(db, productId, sellerId, 100, 50);

    const r = await callAndCapture(orderPayload(productId), { uid, token: {} });
    const s = !r.ok && r.code === "failed-precondition";
    results.scenario2_missing_user_doc_rejected = s;
    console.log(`Scenario 2: ${s ? "PASSED" : "FAILED"} — code=${r.code} message="${r.message}"`);
    if (!s) allPassed = false;
  }

  // Scenario 3 — POSITIVE CONTROL: a grandfathered, complete-profile user's
  // order still succeeds with the correct total.
  {
    const uid = "phase16-enforce-complete-user";
    const sellerId = "phase16-enforce-seller3";
    const productId = "phase16-enforce-product3";
    await seedProduct(db, productId, sellerId, 100, 50);
    await db.collection("users").doc(uid).set({
      uid,
      email: "grandfathered@example.com",
      name: "Grandfathered User",
      phone: "+919876500031",
      role: "user",
      profileCompleted: true,
    });

    const r = await callAndCapture(orderPayload(productId), { uid, token: {} });
    console.log("Scenario 3 raw:", JSON.stringify(r, null, 2));
    const s = r.ok && r.result.success === true && r.result.orders[0].total === 200;
    results.scenario3_grandfathered_user_order_succeeds = s;
    console.log(`Scenario 3: ${s ? "PASSED" : "FAILED"} — total=${r.result?.orders?.[0]?.total}`);
    if (!s) allPassed = false;
  }

  console.log("");
  console.log(allPassed ? "ALL PASSED" : "SOME FAILED");
  console.log(JSON.stringify(results, null, 2));
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phase16 enforcement test:", e);
  process.exit(1);
});
