// Phase 5c, workstream 3: proves createOrder's server-side coupon
// re-validation (validateAndComputeCouponDiscount, porting
// CouponModel.calculateDiscount) against a real emulator, for both discount
// types and every rejection path, not just the happy path.
// Run with: node scripts/phase5c_coupon_test.js
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
  const now = Date.now();

  // Phase 16, Workstream 7 fixture update: createOrder.ts now rejects an
  // incomplete-profile caller — unrelated to this file's coupon
  // scenarios, so every test user here is seeded profileCompleted:true up
  // front. Purely additive, no assertion below is touched.
  for (const uid of [
    "phase5c-coupon-customer1",
    "phase5c-coupon-customer2",
    "phase5c-coupon-customer3",
    "phase5c-coupon-customer4",
    "phase5c-coupon-customer5",
    "phase5c-coupon-customer6",
  ]) {
    await db.collection("users").doc(uid).set({ uid, profileCompleted: true });
  }

  console.log("=== WORKSTREAM 3 — Server-side coupon re-validation ===");

  await db.collection("products").doc("phase5c-coupon-product").set({
    name: "Coupon Test Product",
    salePrice: 1000,
    isB2BEnabled: false,
    sellerId: "phase5c-coupon-seller",
    images: [],
  });

  await db.collection("coupons").doc("phase5c-coupon-pct").set({
    code: "SAVE10",
    type: "percentage",
    discount: 10,
    isActive: true,
    validFrom: admin.firestore.Timestamp.fromMillis(now - 86400000),
    validTo: admin.firestore.Timestamp.fromMillis(now + 86400000),
    minOrderAmount: 0,
    usageLimit: 0,
    usedCount: 0,
  });
  await db.collection("coupons").doc("phase5c-coupon-flat").set({
    code: "FLAT50",
    type: "flat",
    discount: 50,
    isActive: true,
    validFrom: admin.firestore.Timestamp.fromMillis(now - 86400000),
    validTo: admin.firestore.Timestamp.fromMillis(now + 86400000),
    minOrderAmount: 0,
    usageLimit: 0,
    usedCount: 0,
  });
  await db.collection("coupons").doc("phase5c-coupon-expired").set({
    code: "EXPIRED1",
    type: "flat",
    discount: 50,
    isActive: true,
    validFrom: admin.firestore.Timestamp.fromMillis(now - 172800000),
    validTo: admin.firestore.Timestamp.fromMillis(now - 86400000),
    minOrderAmount: 0,
    usageLimit: 0,
    usedCount: 0,
  });
  await db.collection("coupons").doc("phase5c-coupon-exhausted").set({
    code: "USEDUP1",
    type: "flat",
    discount: 50,
    isActive: true,
    validFrom: admin.firestore.Timestamp.fromMillis(now - 86400000),
    validTo: admin.firestore.Timestamp.fromMillis(now + 86400000),
    minOrderAmount: 0,
    usageLimit: 1,
    usedCount: 1,
  });
  await db.collection("coupons").doc("phase5c-coupon-minorder").set({
    code: "BIGORDER1",
    type: "flat",
    discount: 50,
    isActive: true,
    validFrom: admin.firestore.Timestamp.fromMillis(now - 86400000),
    validTo: admin.firestore.Timestamp.fromMillis(now + 86400000),
    minOrderAmount: 5000,
    usageLimit: 0,
    usedCount: 0,
  });

  // Scenario 1: percentage coupon, lowercase input code (confirms
  // .toUpperCase() normalization).
  {
    const r = await callAndCapture(
      {
        items: [{ productId: "phase5c-coupon-product", quantity: 1 }],
        orderMode: "B2C",
        paymentMethod: "cod",
        couponCode: "save10",
      },
      { uid: "phase5c-coupon-customer1", token: {} }
    );
    console.log("Scenario 1 raw:", JSON.stringify(r, null, 2));
    let s;
    try {
      if (!r.ok) throw new Error(`expected success, got error: ${r.message}`);
      const doc = await db.collection("orders").doc(r.result.orders[0].orderId).get();
      const data = doc.data();
      if (data.discount !== 100) throw new Error(`expected discount 100 (10% of 1000), got ${data.discount}`);
      if (data.total !== 900) throw new Error(`expected total 900, got ${data.total}`);
      s = `PASSED — percentage coupon applied via lowercase input "save10": discount=${data.discount}, total=${data.total}`;
    } catch (e) {
      s = `FAILED — ${e.message}`;
      allPassed = false;
    }
    results.scenario1 = s;
    console.log("Scenario 1:", s);
  }

  // Scenario 2: flat coupon.
  {
    const r = await callAndCapture(
      {
        items: [{ productId: "phase5c-coupon-product", quantity: 1 }],
        orderMode: "B2C",
        paymentMethod: "cod",
        couponCode: "FLAT50",
      },
      { uid: "phase5c-coupon-customer2", token: {} }
    );
    console.log("Scenario 2 raw:", JSON.stringify(r, null, 2));
    let s;
    try {
      if (!r.ok) throw new Error(`expected success, got error: ${r.message}`);
      const doc = await db.collection("orders").doc(r.result.orders[0].orderId).get();
      const data = doc.data();
      if (data.discount !== 50) throw new Error(`expected discount 50 (flat), got ${data.discount}`);
      if (data.total !== 950) throw new Error(`expected total 950, got ${data.total}`);
      s = `PASSED — flat coupon applied: discount=${data.discount}, total=${data.total}`;
    } catch (e) {
      s = `FAILED — ${e.message}`;
      allPassed = false;
    }
    results.scenario2 = s;
    console.log("Scenario 2:", s);
  }

  // Scenario 3: expired coupon.
  {
    const r = await callAndCapture(
      {
        items: [{ productId: "phase5c-coupon-product", quantity: 1 }],
        orderMode: "B2C",
        paymentMethod: "cod",
        couponCode: "EXPIRED1",
      },
      { uid: "phase5c-coupon-customer3", token: {} }
    );
    console.log("Scenario 3 raw:", JSON.stringify(r, null, 2));
    const expectedMsg = "This coupon has expired or reached its usage limit";
    let s;
    if (r.ok) {
      s = "FAILED — expired coupon was accepted";
      allPassed = false;
    } else if (r.message !== expectedMsg) {
      s = `FAILED — wrong message "${r.message}"`;
      allPassed = false;
    } else {
      s = `PASSED — rejected as expected. code=${r.code} message="${r.message}"`;
    }
    results.scenario3 = s;
    console.log("Scenario 3:", s);
  }

  // Scenario 4: usage-exhausted coupon (usageLimit reached).
  {
    const r = await callAndCapture(
      {
        items: [{ productId: "phase5c-coupon-product", quantity: 1 }],
        orderMode: "B2C",
        paymentMethod: "cod",
        couponCode: "USEDUP1",
      },
      { uid: "phase5c-coupon-customer4", token: {} }
    );
    console.log("Scenario 4 raw:", JSON.stringify(r, null, 2));
    const expectedMsg = "This coupon has expired or reached its usage limit";
    let s;
    if (r.ok) {
      s = "FAILED — usage-exhausted coupon was accepted";
      allPassed = false;
    } else if (r.message !== expectedMsg) {
      s = `FAILED — wrong message "${r.message}"`;
      allPassed = false;
    } else {
      s = `PASSED — rejected as expected. code=${r.code} message="${r.message}"`;
    }
    results.scenario4 = s;
    console.log("Scenario 4:", s);
  }

  // Scenario 5: cart subtotal below coupon's minOrderAmount.
  {
    const r = await callAndCapture(
      {
        items: [{ productId: "phase5c-coupon-product", quantity: 1 }],
        orderMode: "B2C",
        paymentMethod: "cod",
        couponCode: "BIGORDER1",
      },
      { uid: "phase5c-coupon-customer5", token: {} }
    );
    console.log("Scenario 5 raw:", JSON.stringify(r, null, 2));
    const expectedMsg = "Minimum order amount is ₹5000";
    let s;
    if (r.ok) {
      s = "FAILED — coupon below its minOrderAmount was accepted";
      allPassed = false;
    } else if (r.message !== expectedMsg) {
      s = `FAILED — wrong message "${r.message}" (expected "${expectedMsg}")`;
      allPassed = false;
    } else {
      s = `PASSED — rejected as expected. code=${r.code} message="${r.message}"`;
    }
    results.scenario5 = s;
    console.log("Scenario 5:", s);
  }

  // Scenario 6: no coupon at all — base case must still work.
  {
    const r = await callAndCapture(
      {
        items: [{ productId: "phase5c-coupon-product", quantity: 1 }],
        orderMode: "B2C",
        paymentMethod: "cod",
      },
      { uid: "phase5c-coupon-customer6", token: {} }
    );
    console.log("Scenario 6 raw:", JSON.stringify(r, null, 2));
    let s;
    try {
      if (!r.ok) throw new Error(`expected success, got error: ${r.message}`);
      const doc = await db.collection("orders").doc(r.result.orders[0].orderId).get();
      const data = doc.data();
      if (data.discount !== 0) throw new Error(`expected discount 0, got ${data.discount}`);
      if (data.total !== 1000) throw new Error(`expected total 1000, got ${data.total}`);
      s = `PASSED — no-coupon order succeeded with zero discount, total=${data.total}`;
    } catch (e) {
      s = `FAILED — ${e.message}`;
      allPassed = false;
    }
    results.scenario6 = s;
    console.log("Scenario 6:", s);
  }

  console.log("=== WORKSTREAM 3 SUMMARY ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running coupon test:", e);
  process.exit(1);
});
