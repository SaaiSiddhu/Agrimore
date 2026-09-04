// Phase 15, Workstream 2: proves createOrder.ts's coupon usageLimit
// enforcement, per-user redemption tracking, and stock validation against a
// real emulator and the real compiled createOrder function. Mirrors
// phase14_payment_replay_test.js's firebase-functions-test harness pattern
// exactly — createOrder is a v2 onCall, wrapped and invoked as
// `wrapped({ data: payload, auth })`.
// Run with: node scripts/phase15_order_integrity_test.js
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

async function seedCoupon(db, code, { usageLimit, usedCount = 0, discount = 10 }) {
  await db.collection("coupons").add({
    code,
    type: "flat",
    discount,
    isActive: true,
    usageLimit,
    usedCount,
    minOrderAmount: 0,
    validFrom: admin.firestore.Timestamp.fromMillis(Date.now() - 24 * 60 * 60 * 1000),
    validTo: admin.firestore.Timestamp.fromMillis(Date.now() + 24 * 60 * 60 * 1000),
  });
}

async function getCouponUsedCount(db, code) {
  const snap = await db.collection("coupons").where("code", "==", code).limit(1).get();
  return snap.empty ? null : snap.docs[0].data().usedCount;
}

async function main() {
  const db = admin.firestore();
  let allPassed = true;
  const results = {};

  // Phase 16, Workstream 7 fixture update: createOrder.ts now rejects an
  // incomplete-profile caller (see phase16_enforcement_test.js — this is
  // the new requirement under test there). This file's scenarios are about
  // coupon/stock logic, unrelated to profile completion, so every test
  // user here is seeded profileCompleted:true up front — purely additive,
  // no assertion below is touched.
  for (const uid of [
    "phase15-oi-customer1",
    "phase15-oi-customer-limit-first",
    "phase15-oi-customer2",
    "phase15-oi-customer3",
    "phase15-oi-customer4",
    "phase15-oi-customer5",
  ]) {
    await db.collection("users").doc(uid).set({ uid, profileCompleted: true });
  }

  console.log("=== PHASE 15, WORKSTREAM 2 — coupon limits & stock validation ===");

  // Scenario 1: a coupon with a HIGH usageLimit (so the global limit is
  // nowhere near exhausted — this isolates the PER-USER check tested in
  // scenario 2 from the global-usageLimit check tested separately in
  // scenario 3) is redeemed once — must succeed, and usedCount must
  // actually increment afterward (the first real enforcement — grepped:
  // nothing else in the codebase ever increments it).
  {
    const productId = "phase15-oi-product1";
    const couponCode = "PHASE15PERUSER";
    const uid = "phase15-oi-customer1";
    await seedProduct(db, productId, "phase15-oi-seller1", 100, 5);
    await seedCoupon(db, couponCode, { usageLimit: 10 });

    const r = await callAndCapture(
      {
        items: [{ productId, quantity: 1 }],
        orderMode: "B2C",
        paymentMethod: "cod",
        couponCode,
      },
      { uid, token: {} }
    );
    console.log("Scenario 1 raw:", JSON.stringify(r, null, 2));
    let s;
    try {
      if (!r.ok) throw new Error(`expected success, got error: code=${r.code} message=${r.message}`);
      if (r.result.orders[0].total !== 90) throw new Error(`expected total 90 (100 - 10 flat discount), got ${r.result.orders[0].total}`);
      const usedCount = await getCouponUsedCount(db, couponCode);
      if (usedCount !== 1) throw new Error(`expected usedCount 1 after redemption, got ${usedCount}`);
      const redemptionDoc = await db.collection("coupon_redemptions").doc(`${couponCode}_${uid}`).get();
      if (!redemptionDoc.exists) throw new Error("expected a coupon_redemptions/{code}_{uid} document to exist after redemption");
      s = `PASSED — order created with coupon discount (total=${r.result.orders[0].total}), usedCount incremented to ${usedCount}, redemption doc recorded`;
    } catch (e) {
      s = `FAILED — ${e.message}`;
      allPassed = false;
    }
    results.scenario1_coupon_redeemed_and_used_count_incremented = s;
    console.log("Scenario 1:", s);
  }

  // Scenario 2 — THE per-user proof: the SAME user tries to redeem the
  // SAME coupon a second time (on a different order). The coupon's
  // usageLimit (10) is nowhere near exhausted (usedCount is 1), so a
  // rejection here can only come from the per-user redemption check, not
  // the global limit — isolating exactly what this scenario claims to prove.
  {
    const productId = "phase15-oi-product1"; // same product, still in stock
    const couponCode = "PHASE15PERUSER"; // same coupon as scenario 1
    const uid = "phase15-oi-customer1"; // same user as scenario 1

    const r = await callAndCapture(
      {
        items: [{ productId, quantity: 1 }],
        orderMode: "B2C",
        paymentMethod: "cod",
        couponCode,
      },
      { uid, token: {} }
    );
    console.log("Scenario 2 raw:", JSON.stringify(r, null, 2));
    let s;
    if (r.ok) {
      s = "FAILED — the same user redeemed the same coupon TWICE — per-user redemption tracking is not working";
      allPassed = false;
    } else if (r.message !== "You have already redeemed this coupon") {
      s = `FAILED — rejected, but with the wrong message: "${r.message}" (code=${r.code})`;
      allPassed = false;
    } else {
      s = `PASSED — the second redemption by the same user was rejected. code=${r.code} message="${r.message}"`;
    }
    results.scenario2_same_user_cannot_redeem_twice = s;
    console.log("Scenario 2:", s);
  }

  // Scenario 3 — THE usageLimit proof: a SEPARATE coupon with
  // usageLimit:1, already consumed once by a first user, is tried by a
  // DIFFERENT user. Deliberately a different coupon code from scenarios
  // 1-2 so this failure can only be attributed to the global usageLimit
  // check, not per-user reuse (proves the two checks are independent).
  {
    const productId = "phase15-oi-product1";
    const couponCode = "PHASE15LIMIT1";
    const firstUid = "phase15-oi-customer-limit-first";
    const secondUid = "phase15-oi-customer2";
    await seedCoupon(db, couponCode, { usageLimit: 1 });

    const first = await callAndCapture(
      { items: [{ productId, quantity: 1 }], orderMode: "B2C", paymentMethod: "cod", couponCode },
      { uid: firstUid, token: {} }
    );
    if (!first.ok) throw new Error(`scenario 3 setup: first redemption of ${couponCode} unexpectedly failed: ${first.message}`);

    const r = await callAndCapture(
      {
        items: [{ productId, quantity: 1 }],
        orderMode: "B2C",
        paymentMethod: "cod",
        couponCode,
      },
      { uid: secondUid, token: {} }
    );
    console.log("Scenario 3 raw:", JSON.stringify(r, null, 2));
    let s;
    if (r.ok) {
      s = "FAILED — a coupon at its usageLimit was redeemed by a different user — usageLimit is unenforceable, THE ORIGINAL BUG IS STILL OPEN";
      allPassed = false;
    } else if (r.message !== "This coupon has expired or reached its usage limit") {
      s = `FAILED — rejected, but with the wrong message: "${r.message}" (code=${r.code})`;
      allPassed = false;
    } else {
      s = `PASSED — a coupon at its usageLimit was rejected for a different user too. code=${r.code} message="${r.message}"`;
    }
    results.scenario3_coupon_at_usage_limit_rejected = s;
    console.log("Scenario 3:", s);
  }

  // Scenario 4 — stock validation: ordering more units than are in stock
  // must be rejected.
  {
    const productId = "phase15-oi-product-lowstock";
    const uid = "phase15-oi-customer3";
    await seedProduct(db, productId, "phase15-oi-seller2", 50, 2); // only 2 in stock

    const r = await callAndCapture(
      {
        items: [{ productId, quantity: 5 }], // requesting 5, only 2 available
        orderMode: "B2C",
        paymentMethod: "cod",
      },
      { uid, token: {} }
    );
    console.log("Scenario 4 raw:", JSON.stringify(r, null, 2));
    const expectedMsg = `Product ${productId} does not have enough stock (available: 2, requested: 5)`;
    let s;
    if (r.ok) {
      s = "FAILED — an order for more units than in stock succeeded — OVERSELLING IS STILL POSSIBLE";
      allPassed = false;
    } else if (r.message !== expectedMsg) {
      s = `FAILED — rejected, but with the wrong message: "${r.message}" (code=${r.code})`;
      allPassed = false;
    } else {
      s = `PASSED — an order exceeding available stock was rejected. code=${r.code} message="${r.message}"`;
    }
    results.scenario4_insufficient_stock_rejected = s;
    console.log("Scenario 4:", s);
  }

  // Scenario 5 — fail-open control: a product with NO stock field at all
  // (mirrors ProductModel.fromMap's own default of 999 for a
  // missing/non-numeric stock) must still allow a normal-sized order —
  // proves the deliberate fail-open choice for legacy/incomplete product
  // data, not just the fail-closed path above.
  {
    const productId = "phase15-oi-product-nostock";
    const uid = "phase15-oi-customer4";
    await db.collection("products").doc(productId).set({
      name: "Legacy product with no stock field",
      salePrice: 20,
      sellerId: "phase15-oi-seller3",
      images: [],
      isB2BEnabled: false,
      // Deliberately no `stock` field at all.
    });

    const r = await callAndCapture(
      { items: [{ productId, quantity: 3 }], orderMode: "B2C", paymentMethod: "cod" },
      { uid, token: {} }
    );
    console.log("Scenario 5 raw:", JSON.stringify(r, null, 2));
    const s = r.ok
      ? `PASSED — a product with no stock field still allowed a normal order (fail-open, mirroring ProductModel.fromMap's default of 999). total=${r.result.orders[0].total}`
      : `FAILED — a legacy product with no stock field was rejected: code=${r.code} message="${r.message}"`;
    if (!r.ok) allPassed = false;
    results.scenario5_missing_stock_field_fails_open = s;
    console.log("Scenario 5:", s);
  }

  // Scenario 6 — POSITIVE CONTROL: a normal in-stock, first-time-coupon
  // order still succeeds with the correct total, proving none of the above
  // broke the ordinary checkout path.
  {
    const productId = "phase15-oi-product-normal";
    const couponCode = "PHASE15NORMAL";
    const uid = "phase15-oi-customer5";
    await seedProduct(db, productId, "phase15-oi-seller4", 200, 10);
    await seedCoupon(db, couponCode, { usageLimit: 5, discount: 20 });

    const r = await callAndCapture(
      {
        items: [{ productId, quantity: 2 }], // 400 subtotal
        orderMode: "B2C",
        paymentMethod: "cod",
        couponCode,
      },
      { uid, token: {} }
    );
    console.log("Scenario 6 raw:", JSON.stringify(r, null, 2));
    let s;
    try {
      if (!r.ok) throw new Error(`expected success, got error: code=${r.code} message=${r.message}`);
      const expectedTotal = 400 - 20; // flat discount 20
      if (r.result.orders[0].total !== expectedTotal) {
        throw new Error(`expected total ${expectedTotal}, got ${r.result.orders[0].total}`);
      }
      const usedCount = await getCouponUsedCount(db, couponCode);
      if (usedCount !== 1) throw new Error(`expected usedCount 1, got ${usedCount}`);
      s = `PASSED — a normal in-stock, first-time-coupon order succeeded with the correct total (${r.result.orders[0].total}) and usedCount=${usedCount}`;
    } catch (e) {
      s = `FAILED — ${e.message}`;
      allPassed = false;
    }
    results.scenario6_normal_order_still_succeeds = s;
    console.log("Scenario 6:", s);
  }

  console.log("=== PHASE 15 WORKSTREAM 2 SUMMARY ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phase15 order integrity test:", e);
  process.exit(1);
});
