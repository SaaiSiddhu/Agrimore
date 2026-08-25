// Phase 5b workstream 3, scenario 4: proves createOrder actually runs
// against emulated Firestore, not just that tsc accepts it.
// Run with: node scripts/phase5b_createorder_test.js
// Requires: Firestore emulator on 127.0.0.1:8080 (env vars below point the
// Admin SDK at it instead of production), and functions already built
// (npm run build) so lib/customer/createOrder.js exists.
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { createOrder } = require("../lib/customer/createOrder");

const wrapped = test.wrap(createOrder);

async function main() {
  const db = admin.firestore();

  await db.collection("products").doc("phase5b-test-product").set({
    name: "Phase 5b Test Product",
    salePrice: 150,
    sellerId: "phase5b-seller",
    isB2BEnabled: false,
    images: [],
  });

  const result = await wrapped(
    {
      items: [{ productId: "phase5b-test-product", quantity: 3 }],
      orderMode: "B2C",
      paymentMethod: "cod",
      deliveryAddress: { name: "Test Customer", phone: "9999999999" },
    },
    { auth: { uid: "phase5b-test-customer", token: {} } }
  );

  console.log("=== PHASE 5b createOrder EMULATOR TEST ===");
  console.log("createOrder() result:", JSON.stringify(result, null, 2));

  if (!result.success || !Array.isArray(result.orders) || result.orders.length !== 1) {
    console.log("FAILED — unexpected result shape");
    process.exit(1);
  }

  const orderId = result.orders[0].orderId;
  const orderDoc = await db.collection("orders").doc(orderId).get();

  console.log("Fetched order document from emulated Firestore:");
  console.log(JSON.stringify(orderDoc.data(), null, 2));

  const data = orderDoc.data();
  const expectedTotal = 150 * 3;
  if (!orderDoc.exists) {
    console.log("FAILED — order document was not actually written to Firestore");
    process.exit(1);
  }
  if (data.total !== expectedTotal) {
    console.log(`FAILED — expected total ${expectedTotal}, got ${data.total}`);
    process.exit(1);
  }
  if (data.orderMode !== "B2C" || data.orderStatus !== "pending") {
    console.log("FAILED — orderMode/orderStatus did not match expectations");
    process.exit(1);
  }

  console.log(`PASSED — order ${orderId} created in emulated Firestore with server-computed total ₹${data.total}`);
  process.exit(0);
}

main().catch((e) => {
  console.error("FATAL ERROR running createOrder emulator test:", e);
  process.exit(1);
});
