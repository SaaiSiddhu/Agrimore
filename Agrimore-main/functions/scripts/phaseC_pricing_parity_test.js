// Phase C, Workstream 4 — pricing extraction safety net.
// Proves functions/src/customer/orderPricing.ts's computeOrderPricing
// produces the SAME numbers createOrder.ts's pre-extraction inline logic
// always did, for: a single-seller B2C cart, a multi-seller cart (the
// subtlest part — the ratio-based split), a B2B cart with MOQ (including
// the below-MOQ rejection), and a coupon-discounted cart. computeOrderPricing
// is a pure function (no Firestore access), so this test needs no emulator
// at all — it hand-builds mock DocumentSnapshot/QuerySnapshot objects.
// Run with: node scripts/phaseC_pricing_parity_test.js
const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });

const { computeOrderPricing } = require("../lib/customer/orderPricing");

function mockProductSnap(data) {
  return { exists: true, data: () => data };
}

function mockCouponSnap(data) {
  return data ? { empty: false, docs: [{ ref: {}, data: () => data }] } : { empty: true, docs: [] };
}

function roundMoney(v) {
  return Math.round(v * 100) / 100;
}

function main() {
  let allPassed = true;
  const results = {};

  // --- Scenario A: single-seller B2C cart ---
  {
    const productSnaps = [
      mockProductSnap({ name: "P1", salePrice: 100, sellerId: "sellerA", images: [] }),
      mockProductSnap({ name: "P2", salePrice: 50, sellerId: "sellerA", images: [] }),
    ];
    const pricing = computeOrderPricing({
      items: [
        { productId: "p1", quantity: 2 },
        { productId: "p2", quantity: 3 },
      ],
      productSnaps,
      orderMode: "B2C",
      uid: "test-uid",
      couponSnap: null,
      deliveryCharge: 40,
      tax: 10,
    });

    const expectedCartSubtotal = 100 * 2 + 50 * 3; // 350
    const expectedGrandTotal = roundMoney(expectedCartSubtotal + 40 + 10); // 400
    const pass =
      pricing.cartSubtotal === expectedCartSubtotal &&
      pricing.grandTotal === expectedGrandTotal &&
      pricing.perSeller.length === 1 &&
      pricing.perSeller[0].sellerId === "sellerA" &&
      pricing.perSeller[0].total === expectedGrandTotal;
    results.scenarioA_single_seller_b2c = pass
      ? `PASSED — cartSubtotal=${pricing.cartSubtotal}, grandTotal=${pricing.grandTotal}, matches hand-computed ${expectedCartSubtotal}/${expectedGrandTotal}`
      : `FAILED — ${JSON.stringify(pricing)}`;
    if (!pass) allPassed = false;
  }

  // --- Scenario B: multi-seller cart (ratio-based split) ---
  {
    const productSnaps = [
      mockProductSnap({ name: "P1", salePrice: 100, sellerId: "sellerA", images: [] }),
      mockProductSnap({ name: "P3", salePrice: 300, sellerId: "sellerB", images: [] }),
    ];
    const pricing = computeOrderPricing({
      items: [
        { productId: "p1", quantity: 2 }, // 200, sellerA
        { productId: "p3", quantity: 1 }, // 300, sellerB
      ],
      productSnaps,
      orderMode: "B2C",
      uid: "test-uid",
      couponSnap: null,
      deliveryCharge: 50,
      tax: 0,
    });

    const cartSubtotal = 500;
    const grandTotal = roundMoney(cartSubtotal + 50);
    const sellerA = pricing.perSeller.find((s) => s.sellerId === "sellerA");
    const sellerB = pricing.perSeller.find((s) => s.sellerId === "sellerB");
    const expectedSellerADelivery = roundMoney(50 * (200 / 500)); // 20
    const expectedSellerBDelivery = roundMoney(50 * (300 / 500)); // 30
    const pass =
      pricing.cartSubtotal === cartSubtotal &&
      pricing.grandTotal === grandTotal &&
      pricing.perSeller.length === 2 &&
      sellerA.subtotal === 200 &&
      sellerA.deliveryCharge === expectedSellerADelivery &&
      sellerA.total === roundMoney(200 + expectedSellerADelivery) &&
      sellerB.subtotal === 300 &&
      sellerB.deliveryCharge === expectedSellerBDelivery &&
      sellerB.total === roundMoney(300 + expectedSellerBDelivery) &&
      roundMoney(sellerA.total + sellerB.total) === grandTotal;
    results.scenarioB_multi_seller_ratio_split = pass
      ? `PASSED — sellerA=${JSON.stringify(sellerA)}, sellerB=${JSON.stringify(sellerB)}, sums to grandTotal=${grandTotal}`
      : `FAILED — ${JSON.stringify(pricing)}`;
    if (!pass) allPassed = false;
  }

  // --- Scenario C: B2B cart with MOQ ---
  {
    const productSnaps = [
      mockProductSnap({ name: "P4", isB2BEnabled: true, b2bPrice: 80, b2bMoq: 5, sellerId: "sellerC", images: [] }),
    ];
    const pricing = computeOrderPricing({
      items: [{ productId: "p4", quantity: 10 }],
      productSnaps,
      orderMode: "B2B",
      uid: "test-uid",
      couponSnap: null,
    });
    const expectedTotal = 80 * 10; // 800
    const pass = pricing.cartSubtotal === expectedTotal && pricing.grandTotal === expectedTotal;
    results.scenarioC_b2b_moq_pricing = pass
      ? `PASSED — B2B price selected correctly, total=${pricing.grandTotal}`
      : `FAILED — ${JSON.stringify(pricing)}`;
    if (!pass) allPassed = false;

    // Negative control: quantity BELOW moq must still throw, exactly as before extraction.
    let threw = false;
    let message = "";
    try {
      computeOrderPricing({
        items: [{ productId: "p4", quantity: 3 }], // below moq=5
        productSnaps,
        orderMode: "B2B",
        uid: "test-uid",
        couponSnap: null,
      });
    } catch (e) {
      threw = true;
      message = e.message;
    }
    const passMoq = threw && message.includes("minimum order quantity");
    results.scenarioC2_below_moq_rejected = passMoq
      ? `PASSED — quantity below MOQ rejected: "${message}"`
      : `FAILED — threw=${threw} message="${message}"`;
    if (!passMoq) allPassed = false;
  }

  // --- Scenario D: coupon-discounted cart ---
  {
    const productSnaps = [mockProductSnap({ name: "P5", salePrice: 1000, sellerId: "sellerD", images: [] })];
    const couponSnap = mockCouponSnap({
      code: "TESTCOUPON",
      type: "percentage",
      discount: 10,
      isActive: true,
      usageLimit: 0,
      usedCount: 0,
      minOrderAmount: 0,
      validFrom: admin.firestore.Timestamp.fromMillis(Date.now() - 86400000),
      validTo: admin.firestore.Timestamp.fromMillis(Date.now() + 86400000),
    });
    const pricing = computeOrderPricing({
      items: [{ productId: "p5", quantity: 1 }],
      productSnaps,
      orderMode: "B2C",
      uid: "test-uid",
      couponSnap,
      couponCode: "TESTCOUPON",
    });
    const expectedDiscount = 100; // 10% of 1000
    const expectedGrandTotal = roundMoney(1000 - expectedDiscount);
    const pass =
      pricing.discountAmount === expectedDiscount &&
      pricing.couponCode === "TESTCOUPON" &&
      pricing.grandTotal === expectedGrandTotal &&
      pricing.perSeller[0].discount === expectedDiscount &&
      pricing.perSeller[0].total === expectedGrandTotal;
    results.scenarioD_coupon_discount = pass
      ? `PASSED — discountAmount=${pricing.discountAmount}, grandTotal=${pricing.grandTotal}`
      : `FAILED — ${JSON.stringify(pricing)}`;
    if (!pass) allPassed = false;
  }

  console.log("=== PHASE C — PRICING EXTRACTION PARITY TEST ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);
  console.log(allPassed ? "\nALL PASSED" : "\nSOME FAILED");
  process.exit(allPassed ? 0 : 1);
}

main();
