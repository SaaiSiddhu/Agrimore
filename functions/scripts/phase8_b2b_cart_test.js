// Phase 8: proves that mobile_cart_screen.dart's new B2B-aware payload shape
// (orderMode derived from CartProvider.cartMode, employeeCode collected via
// the new _employeeCodeController field) is accepted by the real createOrder
// callable and correctly priced via b2bPrice/b2bMoq — not salePrice — which
// is the exact gap this phase closes. Field-by-field cross-check against the
// literal Dart map now built in _createOrderInFirestore when
// cartProvider.cartMode == 'B2B':
//
//   {
//     'items': [...],
//     'orderMode': 'B2B',
//     'employeeCode': employeeCode,             // NEW in Phase 8
//     'deliveryAddress': address.toMap(),
//     'paymentMethod': normalizedPaymentMethod,
//     'deliveryCharge': deliveryCharge,
//     'tax': 0.0,
//   }
//
// Run with: node scripts/phase8_b2b_cart_test.js
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

function fakeAddressMap() {
  return {
    name: "Phase8 B2B Test Customer",
    phone: "9999999998",
    addressLine1: "456 Wholesale Ave",
    addressLine2: "",
    city: "Chennai",
    state: "Tamil Nadu",
    zipcode: "600002",
    country: "India",
    latitude: 13.0827,
    longitude: 80.2707,
  };
}

async function main() {
  const db = admin.firestore();
  let allPassed = true;
  const results = {};

  // Phase 16, Workstream 7 fixture update: createOrder.ts now rejects an
  // incomplete-profile caller. This file's scenarios are about B2B payload
  // shape, unrelated to profile completion, so every test user here is
  // seeded profileCompleted:true up front — purely additive, no assertion
  // below is touched.
  for (const uid of ["phase8-b2b-customer", "phase8-b2b-customer2"]) {
    await db.collection("users").doc(uid).set({ uid, profileCompleted: true });
  }

  console.log("=== PHASE 8 — mobile_cart_screen.dart B2B payload shape ===");

  // salePrice 250 (B2C) vs b2bPrice 180 (B2B) — deliberately different so a
  // passing test that priced via salePrice instead of b2bPrice would be
  // caught (this is exactly the bug this phase fixes: the OLD code always
  // sent orderMode:'B2C', so a B2B cart would have been priced at 250, not
  // 180).
  await db.collection("products").doc("phase8-b2b-product").set({
    name: "Cart B2B Checkout Test Product",
    salePrice: 250,
    isB2BEnabled: true,
    b2bPrice: 180,
    b2bMoq: 3,
    sellerId: "phase8-b2b-seller",
    images: [],
  });

  await db.collection("employees").doc("phase8-employee-uid").set({
    employeeCode: "EMP-PHASE8-001",
    status: "approved",
    name: "Phase8 Test Employee",
    commissionRate: 5,
  });

  // Scenario 1: B2B order, exact NEW payload shape — qty 3 (meets b2bMoq),
  // employeeCode present, orderMode 'B2B'. Must price via b2bPrice (180),
  // NOT salePrice (250): 180*3 = 540 subtotal + 40 delivery = 580 total.
  {
    const payload = {
      items: [{ productId: "phase8-b2b-product", quantity: 3 }],
      orderMode: "B2B",
      employeeCode: "EMP-PHASE8-001",
      deliveryAddress: fakeAddressMap(),
      paymentMethod: "cod",
      deliveryCharge: 40,
      tax: 0.0,
    };
    console.log("Scenario 1 payload:", JSON.stringify(payload, null, 2));
    const r = await callAndCapture(payload, { uid: "phase8-b2b-customer", token: {} });
    console.log("Scenario 1 raw response:", JSON.stringify(r, null, 2));
    let s;
    try {
      if (!r.ok) throw new Error(`expected success, got error: code=${r.code} message=${r.message}`);
      const orderId = r.result.orders[0].orderId;
      const doc = await db.collection("orders").doc(orderId).get();
      const data = doc.data();
      if (data.orderMode !== "B2B") throw new Error(`expected orderMode "B2B", got ${data.orderMode}`);
      if (data.employeeCode !== "EMP-PHASE8-001") {
        throw new Error(`expected employeeCode "EMP-PHASE8-001", got ${data.employeeCode}`);
      }
      if (data.employeeUid !== "phase8-employee-uid") {
        throw new Error(`expected employeeUid "phase8-employee-uid", got ${data.employeeUid}`);
      }
      // 180 * 3 = 540 subtotal (b2bPrice), + 40 delivery = 580. If this were
      // wrongly priced via salePrice (250), it would be 250*3+40 = 790 —
      // asserting the exact number proves which price list was used.
      if (data.total !== 580) {
        throw new Error(`expected total 580 (b2bPrice-based), got ${data.total} — wrong price list was used if this is 790`);
      }
      if (data.items[0].price !== 180) {
        throw new Error(`expected item price 180 (b2bPrice), got ${data.items[0].price}`);
      }
      s = `PASSED — B2B order priced via b2bPrice, not salePrice. orderId=${orderId} total=${data.total} itemPrice=${data.items[0].price} employeeUid=${data.employeeUid}`;
    } catch (e) {
      s = `FAILED — ${e.message}`;
      allPassed = false;
    }
    results.scenario1_b2b_correct_pricing = s;
    console.log("Scenario 1:", s);
  }

  // Scenario 2 (negative control): B2B order with an invalid/unapproved
  // employee code is rejected server-side — proves the client-side
  // "Employee ID is required" check added in this phase is UX-only, not the
  // real trust boundary; createOrder.ts's own employee-approval check (only
  // an 'approved' employees doc, already covered generally by
  // phase5c_b2b_test.js) still gates this exact new payload shape too.
  {
    const payload = {
      items: [{ productId: "phase8-b2b-product", quantity: 3 }],
      orderMode: "B2B",
      employeeCode: "NOT-A-REAL-CODE",
      deliveryAddress: fakeAddressMap(),
      paymentMethod: "cod",
      deliveryCharge: 40,
      tax: 0.0,
    };
    const r = await callAndCapture(payload, { uid: "phase8-b2b-customer2", token: {} });
    console.log("Scenario 2 raw response:", JSON.stringify(r, null, 2));
    const expectedMsg = "Invalid or unapproved employee code";
    let s;
    if (r.ok) {
      s = "FAILED — a B2B order with a bogus employee code was accepted";
      allPassed = false;
    } else if (r.message !== expectedMsg) {
      s = `FAILED — wrong message "${r.message}"`;
      allPassed = false;
    } else {
      s = `PASSED — rejected as expected. code=${r.code} message="${r.message}"`;
    }
    results.scenario2_negative_bogus_employee_code = s;
    console.log("Scenario 2:", s);
  }

  console.log("=== PHASE 8 SUMMARY ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phase8 b2b cart test:", e);
  process.exit(1);
});
