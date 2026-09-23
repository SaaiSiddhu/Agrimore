// ============================================================
//  Phase SELLER-CATALOGUE-1 — sellers cannot write product trust fields
// ============================================================
//
// Before this phase a seller could set rating/reviewCount/isVerified/
// isFeatured/isTrending/soldCount on their own products (self-verify,
// self-feature, fake reviews and sales). Those are admin or server writes.
//
// Run with: JAVA_HOME=/opt/homebrew/opt/openjdk@21 firebase emulators:exec
//             --only firestore "node scripts/phaseSCAT1_product_rules_test.js"

const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");

// The shape ProductModel.toMap() writes for a new seller product.
function newProduct(extra = {}) {
  return {
    name: "Tomato", description: "Fresh", salePrice: 40, originalPrice: 50, categoryId: "veg",
    images: [], stock: 20, rating: 0, reviewCount: 0, isFeatured: false, isActive: true,
    isNew: true, isVerified: false, isTrending: false, sellerId: "seller1",
    hsnCode: "0702", gstRate: 0, isDraft: false,
    ...extra,
  };
}

async function main() {
  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
  const testEnv = await initializeTestEnvironment({
    projectId: "agrimore-66a4e",
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });
  const results = {};
  const record = (k, p) => p.then(
    () => { results[k] = "PASSED"; console.log(`${k}: PASSED`); },
    (e) => { results[k] = `FAILED — ${e.message}`; console.log(`${k}: FAILED — ${e.message}`); }
  );
  const sellerClaims = { role: "seller", seller: true, sellerApproved: true };
  try {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await db.collection("users").doc("seller1").set({ role: "seller" });
      await db.collection("products").doc("p1").set(newProduct({ rating: 4.2, reviewCount: 7, soldCount: 12 }));
    });
    const seller = testEnv.authenticatedContext("seller1", sellerClaims).firestore();
    const other = testEnv.authenticatedContext("seller2", sellerClaims).firestore();
    const adminDb = testEnv.authenticatedContext("admin1", { role: "admin", admin: true }).firestore();
    const p1 = () => seller.collection("products").doc("p1");

    // creates
    await record("s1_positive_seller_creates_normal_product",
      assertSucceeds(seller.collection("products").doc("n1").set(newProduct())));
    await record("s2_positive_seller_creates_draft",
      assertSucceeds(seller.collection("products").doc("n2").set(newProduct({ isDraft: true, isActive: false }))));
    await record("s3_negative_create_self_verified",
      assertFails(seller.collection("products").doc("n3").set(newProduct({ isVerified: true }))));
    await record("s4_negative_create_self_featured",
      assertFails(seller.collection("products").doc("n4").set(newProduct({ isFeatured: true }))));
    await record("s5_negative_create_fake_rating",
      assertFails(seller.collection("products").doc("n5").set(newProduct({ rating: 5, reviewCount: 200 }))));
    await record("s6_negative_create_fake_sales",
      assertFails(seller.collection("products").doc("n6").set(newProduct({ soldCount: 500 }))));
    await record("s6b_negative_create_trending",
      assertFails(seller.collection("products").doc("n6b").set(newProduct({ isTrending: true }))));

    // updates
    await record("s7_positive_seller_updates_price_stock_tax",
      assertSucceeds(p1().update({ salePrice: 38, stock: 15, hsnCode: "0702", gstRate: 5 })));
    await record("s8_positive_full_rewrite_keeping_existing_trust_values",
      assertSucceeds(p1().set(newProduct({ rating: 4.2, reviewCount: 7, soldCount: 12, salePrice: 36 }))));
    await record("s9_negative_update_rating", assertFails(p1().update({ rating: 5 })));
    await record("s10_negative_update_review_count", assertFails(p1().update({ reviewCount: 99 })));
    await record("s11_negative_update_verified", assertFails(p1().update({ isVerified: true })));
    await record("s12_negative_update_featured", assertFails(p1().update({ isFeatured: true })));
    await record("s13_negative_update_sold_count", assertFails(p1().update({ soldCount: 1000 })));
    await record("s14_negative_other_seller_cannot_edit",
      assertFails(other.collection("products").doc("p1").update({ salePrice: 1 })));

    // admin keeps control
    await record("s15_positive_admin_verifies_and_features",
      assertSucceeds(adminDb.collection("products").doc("p1").update({ isVerified: true, isFeatured: true })));

    console.log("\n=== PHASE SELLER-CATALOGUE-1 (rules) SUMMARY ===");
    const total = Object.keys(results).length;
    const passed = Object.values(results).filter((v) => v === "PASSED").length;
    for (const [k, v] of Object.entries(results)) console.log(`  ${v === "PASSED" ? "PASS" : "FAIL"}  ${k}`);
    console.log(`\n${passed}/${total} scenarios passed`);
    if (passed !== total) { console.error("PHASE SELLER-CATALOGUE-1 (rules): FAILED"); process.exitCode = 1; }
    else console.log("PHASE SELLER-CATALOGUE-1 (rules): ALL PASSED");
  } finally {
    await testEnv.cleanup();
  }
}
main().catch((e) => { console.error("harness error", e); process.exit(1); });
