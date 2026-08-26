// Phase 5c, workstream 1: proves createOrder's multi-seller cart splitting
// (itemsBySeller grouping -> one order doc per seller) against a real
// emulator, not just by reading the TypeScript.
// Run with: node scripts/phase5c_multiseller_test.js
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { createOrder } = require("../lib/customer/createOrder");

const wrapped = test.wrap(createOrder);

async function main() {
  const db = admin.firestore();
  let allPassed = true;
  const results = {};

  console.log("=== WORKSTREAM 1 — Multi-seller cart splitting ===");

  // Scenario 1: two products from two different sellers in one cart.
  await db.collection("products").doc("phase5c-ms-prod-a").set({
    name: "MS Product A",
    salePrice: 100,
    sellerId: "phase5c-ms-seller-a",
    isB2BEnabled: false,
    images: [],
  });
  await db.collection("products").doc("phase5c-ms-prod-b").set({
    name: "MS Product B",
    salePrice: 200,
    sellerId: "phase5c-ms-seller-b",
    isB2BEnabled: false,
    images: [],
  });

  {
    const result = await wrapped({
      data: {
        items: [
          { productId: "phase5c-ms-prod-a", quantity: 2 }, // 200
          { productId: "phase5c-ms-prod-b", quantity: 1 }, // 200
        ],
        orderMode: "B2C",
        paymentMethod: "cod",
      },
      auth: { uid: "phase5c-ms-customer", token: {} },
    });
    console.log("Scenario 1 result:", JSON.stringify(result, null, 2));

    let s;
    try {
      if (result.orders.length !== 2) {
        throw new Error(`expected 2 orders, got ${result.orders.length}`);
      }
      const docs = await Promise.all(
        result.orders.map((o) => db.collection("orders").doc(o.orderId).get())
      );
      const dataA = docs.find((d) => d.data().sellerId === "phase5c-ms-seller-a").data();
      const dataB = docs.find((d) => d.data().sellerId === "phase5c-ms-seller-b").data();
      if (dataA.total !== 200) throw new Error(`seller A total expected 200, got ${dataA.total}`);
      if (dataB.total !== 200) throw new Error(`seller B total expected 200, got ${dataB.total}`);
      if (dataA.subtotal !== 200) throw new Error(`seller A subtotal expected 200, got ${dataA.subtotal}`);
      if (dataB.subtotal !== 200) throw new Error(`seller B subtotal expected 200, got ${dataB.subtotal}`);
      const combined = dataA.subtotal + dataB.subtotal;
      if (combined !== 400) throw new Error(`combined subtotal expected 400, got ${combined}`);
      s = `PASSED — 2 separate order docs created, per-seller totals correct (A=200, B=200), combined subtotal=400 matches expected cart total`;
    } catch (e) {
      s = `FAILED — ${e.message}`;
      allPassed = false;
    }
    results.scenario1 = s;
    console.log("Scenario 1:", s);
  }

  // Scenario 2: product with no sellerId at all -> groups under "_unassigned"
  // internally, writes sellerId: null on the order. Must not crash.
  await db.collection("products").doc("phase5c-ms-prod-noseller").set({
    name: "MS Product No Seller",
    salePrice: 50,
    isB2BEnabled: false,
    images: [],
    // sellerId deliberately omitted
  });

  {
    let s;
    try {
      const result2 = await wrapped({
        data: {
          items: [{ productId: "phase5c-ms-prod-noseller", quantity: 1 }],
          orderMode: "B2C",
          paymentMethod: "cod",
        },
        auth: { uid: "phase5c-ms-customer-2", token: {} },
      });
      console.log("Scenario 2 result:", JSON.stringify(result2, null, 2));
      if (result2.orders.length !== 1) throw new Error(`expected 1 order, got ${result2.orders.length}`);
      const doc = await db.collection("orders").doc(result2.orders[0].orderId).get();
      const data = doc.data();
      if (data.sellerId !== null) throw new Error(`expected sellerId null, got ${JSON.stringify(data.sellerId)}`);
      if (data.total !== 50) throw new Error(`expected total 50, got ${data.total}`);
      s = `PASSED — order created with sellerId: null for a product with no sellerId, total=50, order ${result2.orders[0].orderId}`;
    } catch (e) {
      s = `FAILED — ${e.message}`;
      allPassed = false;
    }
    results.scenario2 = s;
    console.log("Scenario 2:", s);
  }

  console.log("=== WORKSTREAM 1 SUMMARY ===");
  console.log("Scenario 1 (multi-seller split):", results.scenario1);
  console.log("Scenario 2 (unassigned-seller product):", results.scenario2);
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running multi-seller test:", e);
  process.exit(1);
});
