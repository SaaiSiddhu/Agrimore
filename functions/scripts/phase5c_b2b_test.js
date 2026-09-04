// Phase 5c, workstream 2: proves createOrder's B2B validation (isB2BEnabled,
// b2bPrice, b2bMoq) and employee-code attribution (employees collection
// query, status == "approved") against a real emulator. Positive AND
// negative scenarios — a suite that only proves the happy path proves
// nothing about the enforcement.
// Run with: node scripts/phase5c_b2b_test.js
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

async function main() {
  const db = admin.firestore();
  let allPassed = true;
  const results = {};

  // Phase 16, Workstream 7 fixture update: createOrder.ts now rejects an
  // incomplete-profile caller — unrelated to this file's B2B validation
  // scenarios, so every test user here is seeded profileCompleted:true up
  // front. Purely additive, no assertion below is touched.
  for (const uid of [
    "phase5c-b2b-customer1",
    "phase5c-b2b-customer2",
    "phase5c-b2b-customer3",
    "phase5c-b2b-customer4a",
    "phase5c-b2b-customer4b",
    "phase5c-b2b-customer5",
  ]) {
    await db.collection("users").doc(uid).set({ uid, profileCompleted: true });
  }

  console.log("=== WORKSTREAM 2 — B2B validation + employee-code attribution ===");

  await db.collection("employees").doc("phase5c-b2b-emp-approved").set({
    employeeCode: "TESTEMP01",
    status: "approved",
    name: "Test Employee",
  });
  await db.collection("employees").doc("phase5c-b2b-emp-pending").set({
    employeeCode: "TESTEMPPENDING",
    status: "pending",
    name: "Pending Employee",
  });
  await db.collection("products").doc("phase5c-b2b-product").set({
    name: "B2B Product",
    salePrice: 500,
    isB2BEnabled: true,
    b2bPrice: 100,
    b2bMoq: 5,
    sellerId: "phase5c-b2b-seller",
    images: [],
  });
  await db.collection("products").doc("phase5c-b2b-nonb2b-product").set({
    name: "Non-B2B Product",
    salePrice: 500,
    isB2BEnabled: false,
    sellerId: "phase5c-b2b-seller",
    images: [],
  });

  // Scenario 1: valid B2B order, quantity meets MOQ — must succeed.
  {
    const r = await callAndCapture(
      {
        items: [{ productId: "phase5c-b2b-product", quantity: 5 }],
        orderMode: "B2B",
        employeeCode: "TESTEMP01",
        paymentMethod: "cod",
      },
      { uid: "phase5c-b2b-customer1", token: {} }
    );
    console.log("Scenario 1 raw:", JSON.stringify(r, null, 2));
    let s;
    try {
      if (!r.ok) throw new Error(`expected success, got error: ${r.message}`);
      const doc = await db.collection("orders").doc(r.result.orders[0].orderId).get();
      const data = doc.data();
      if (data.employeeUid !== "phase5c-b2b-emp-approved") {
        throw new Error(`expected employeeUid phase5c-b2b-emp-approved, got ${data.employeeUid}`);
      }
      if (data.orderMode !== "B2B") throw new Error(`expected orderMode B2B, got ${data.orderMode}`);
      const item = data.items[0];
      if (item.price !== 100) throw new Error(`expected item price 100 (b2bPrice), got ${item.price}`);
      s = `PASSED — B2B order created, employeeUid resolved to ${data.employeeUid}, price=${item.price} (b2bPrice used, not salePrice 500)`;
    } catch (e) {
      s = `FAILED — ${e.message}`;
      allPassed = false;
    }
    results.scenario1 = s;
    console.log("Scenario 1:", s);
  }

  // Scenario 2: quantity below MOQ — must be rejected.
  {
    const r = await callAndCapture(
      {
        items: [{ productId: "phase5c-b2b-product", quantity: 3 }],
        orderMode: "B2B",
        employeeCode: "TESTEMP01",
        paymentMethod: "cod",
      },
      { uid: "phase5c-b2b-customer2", token: {} }
    );
    console.log("Scenario 2 raw:", JSON.stringify(r, null, 2));
    const expectedMsg = "Quantity for product phase5c-b2b-product is below the minimum order quantity (5)";
    let s;
    if (r.ok) {
      s = "FAILED — order succeeded with quantity 3 below MOQ 5, should have been rejected";
      allPassed = false;
    } else if (r.code !== "failed-precondition" || r.message !== expectedMsg) {
      s = `FAILED — wrong rejection: code=${r.code} message="${r.message}" (expected code=failed-precondition message="${expectedMsg}")`;
      allPassed = false;
    } else {
      s = `PASSED — rejected as expected. code=${r.code} message="${r.message}"`;
    }
    results.scenario2 = s;
    console.log("Scenario 2:", s);
  }

  // Scenario 3: product not B2B-enabled — must be rejected.
  {
    const r = await callAndCapture(
      {
        items: [{ productId: "phase5c-b2b-nonb2b-product", quantity: 5 }],
        orderMode: "B2B",
        employeeCode: "TESTEMP01",
        paymentMethod: "cod",
      },
      { uid: "phase5c-b2b-customer3", token: {} }
    );
    console.log("Scenario 3 raw:", JSON.stringify(r, null, 2));
    const expectedMsg = "Product phase5c-b2b-nonb2b-product is not enabled for B2B ordering";
    let s;
    if (r.ok) {
      s = "FAILED — order succeeded for a non-B2B-enabled product in B2B mode";
      allPassed = false;
    } else if (r.message !== expectedMsg) {
      s = `FAILED — wrong rejection message: "${r.message}" (expected "${expectedMsg}")`;
      allPassed = false;
    } else {
      s = `PASSED — rejected as expected. code=${r.code} message="${r.message}"`;
    }
    results.scenario3 = s;
    console.log("Scenario 3:", s);
  }

  // Scenario 4a: employeeCode matches no document at all.
  {
    const r = await callAndCapture(
      {
        items: [{ productId: "phase5c-b2b-product", quantity: 5 }],
        orderMode: "B2B",
        employeeCode: "NOSUCHCODE",
        paymentMethod: "cod",
      },
      { uid: "phase5c-b2b-customer4a", token: {} }
    );
    console.log("Scenario 4a raw:", JSON.stringify(r, null, 2));
    const expectedMsg = "Invalid or unapproved employee code";
    let s;
    if (r.ok) {
      s = "FAILED — order succeeded with a non-existent employee code";
      allPassed = false;
    } else if (r.message !== expectedMsg) {
      s = `FAILED — wrong rejection message: "${r.message}"`;
      allPassed = false;
    } else {
      s = `PASSED — rejected as expected. code=${r.code} message="${r.message}"`;
    }
    results.scenario4a = s;
    console.log("Scenario 4a:", s);
  }

  // Scenario 4b: employeeCode matches a PENDING (not approved) employee.
  {
    const r = await callAndCapture(
      {
        items: [{ productId: "phase5c-b2b-product", quantity: 5 }],
        orderMode: "B2B",
        employeeCode: "TESTEMPPENDING",
        paymentMethod: "cod",
      },
      { uid: "phase5c-b2b-customer4b", token: {} }
    );
    console.log("Scenario 4b raw:", JSON.stringify(r, null, 2));
    const expectedMsg = "Invalid or unapproved employee code";
    let s;
    if (r.ok) {
      s = "FAILED — order succeeded with a pending (not approved) employee code";
      allPassed = false;
    } else if (r.message !== expectedMsg) {
      s = `FAILED — wrong rejection message: "${r.message}"`;
      allPassed = false;
    } else {
      s = `PASSED — rejected as expected. code=${r.code} message="${r.message}"`;
    }
    results.scenario4b = s;
    console.log("Scenario 4b:", s);
  }

  // Scenario 5: employeeCode omitted entirely for a B2B order.
  {
    const r = await callAndCapture(
      {
        items: [{ productId: "phase5c-b2b-product", quantity: 5 }],
        orderMode: "B2B",
        paymentMethod: "cod",
      },
      { uid: "phase5c-b2b-customer5", token: {} }
    );
    console.log("Scenario 5 raw:", JSON.stringify(r, null, 2));
    const expectedMsg = "employeeCode is required for B2B orders";
    let s;
    if (r.ok) {
      s = "FAILED — B2B order succeeded with no employeeCode at all";
      allPassed = false;
    } else if (r.message !== expectedMsg) {
      s = `FAILED — wrong rejection message: "${r.message}"`;
      allPassed = false;
    } else {
      s = `PASSED — rejected as expected. code=${r.code} message="${r.message}"`;
    }
    results.scenario5 = s;
    console.log("Scenario 5:", s);
  }

  console.log("=== WORKSTREAM 2 SUMMARY ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running B2B test:", e);
  process.exit(1);
});
