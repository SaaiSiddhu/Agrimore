// Phase BUSINESS-NETWORK-2 (slice 2) — proves the new business_posts
// firestore.rules block AND the new business_posts/{fileName} storage.rules
// block against the real engines, never a passing compile alone.
//
// Section A mirrors phase31_collection_coverage_test.js's/
// phase47_seller_follow_test.js's @firebase/rules-unit-testing Firestore
// pattern. Section B mirrors phase24_storage_rules_test.js's combined
// storage+firestore testEnv pattern (business_posts' own write rule needs
// no firestore.get() cross-read, but sharing one testEnv with both engines
// configured -- like phase24 already does -- is simpler than two).
//
// Run with:
//   firebase emulators:exec --only firestore,storage \
//     "node scripts/phase48_business_posts_test.js"
const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const { ref, uploadBytes, getBytes } = require("firebase/storage");

const REPO_ROOT = path.join(__dirname, "..", "..");
const PNG = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const IMG = { contentType: "image/png" };
const PDF = { contentType: "application/pdf" };

function unprivilegedClaims(email) {
  return {
    email,
    role: "user",
    admin: false,
    seller: false,
    sellerApproved: false,
    delivery_partner: false,
    deliveryApproved: false,
    employee: false,
    employeeApproved: false,
  };
}
function sellerClaims(email) {
  return { ...unprivilegedClaims(email), role: "seller", seller: true, sellerApproved: true };
}
function adminClaims(email) {
  return { ...unprivilegedClaims(email), role: "admin", admin: true };
}

async function main() {
  const firestoreRules = fs.readFileSync(path.join(REPO_ROOT, "firestore.rules"), "utf8");
  const storageRules = fs.readFileSync(path.join(REPO_ROOT, "storage.rules"), "utf8");
  const testEnv = await initializeTestEnvironment({
    projectId: "agrimore-66a4e",
    firestore: { rules: firestoreRules, host: "127.0.0.1", port: 8080 },
    storage: { rules: storageRules, host: "127.0.0.1", port: 9199 },
  });

  const results = {};
  const record = (k, p) => p.then(
    () => { results[k] = "PASSED"; console.log(`${k}: PASSED`); },
    (e) => { results[k] = `FAILED — ${e.message}`; console.log(`${k}: FAILED — ${e.message}`); }
  );

  try {
    // ============================================================
    // SECTION A — firestore.rules: business_posts/{postId}
    // ============================================================
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      // Seller p48-seller is APPROVED (isSeller() requires it) via the
      // Firestore-doc fallback the rules file's own isSeller() checks:
      // users/{uid}.role=='seller' && (users/{uid}.sellerStatus=='approved'
      // OR sellers/{uid}.status=='approved').
      await ctx.firestore().collection("users").doc("p48-seller").set({ role: "seller", sellerStatus: "approved" });
      await ctx.firestore().collection("users").doc("p48-unapproved").set({ role: "seller", sellerStatus: "pending" });
      await ctx.firestore().collection("business_posts").doc("existing").set({
        sellerId: "p48-seller", text: "hello", createdAt: new Date(),
      });
    });

    const sellerDb = testEnv.authenticatedContext("p48-seller", sellerClaims("seller@phase48-test.example")).firestore();
    const unapprovedSellerDb = testEnv.authenticatedContext("p48-unapproved", unprivilegedClaims("unapproved@phase48-test.example")).firestore();
    const strangerSellerDb = testEnv.authenticatedContext("p48-stranger-seller", sellerClaims("strangerseller@phase48-test.example")).firestore();
    const userDb = testEnv.authenticatedContext("p48-user", unprivilegedClaims("user@phase48-test.example")).firestore();
    const adminDb = testEnv.authenticatedContext("p48-admin", adminClaims("admin@phase48-test.example")).firestore();
    const anonDb = testEnv.unauthenticatedContext().firestore();

    await record("a1_positive_unauthenticated_can_read_posts",
      assertSucceeds(anonDb.collection("business_posts").doc("existing").get()));
    await record("a2_positive_approved_seller_can_create_text_only_post",
      assertSucceeds(sellerDb.collection("business_posts").add({ sellerId: "p48-seller", text: "new stock in!" })));
    await record("a3_positive_approved_seller_can_create_image_only_post",
      assertSucceeds(sellerDb.collection("business_posts").add({ sellerId: "p48-seller", imageUrl: "https://example.test/a.png" })));
    await record("a4_positive_approved_seller_can_create_product_tag_only_post",
      assertSucceeds(sellerDb.collection("business_posts").add({ sellerId: "p48-seller", productId: "prod1" })));
    await record("a5_negative_cannot_create_a_completely_empty_post",
      assertFails(sellerDb.collection("business_posts").add({ sellerId: "p48-seller" })));
    await record("a6_negative_cannot_create_a_post_attributed_to_another_seller",
      assertFails(strangerSellerDb.collection("business_posts").add({ sellerId: "p48-seller", text: "hijacked" })));
    await record("a7_negative_plain_user_cannot_create_a_post",
      assertFails(userDb.collection("business_posts").add({ sellerId: "p48-user", text: "not a seller" })));
    await record("a8_negative_unapproved_seller_cannot_create_a_post",
      assertFails(unapprovedSellerDb.collection("business_posts").add({ sellerId: "p48-unapproved", text: "still pending" })));
    await record("a9_negative_cannot_update_an_existing_post",
      assertFails(sellerDb.collection("business_posts").doc("existing").update({ text: "edited" })));
    await record("a10_positive_owning_seller_can_delete_own_post",
      assertSucceeds(sellerDb.collection("business_posts").doc("existing").delete()));

    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("business_posts").doc("existing2").set({ sellerId: "p48-seller", text: "again" });
    });
    await record("a11_negative_stranger_seller_cannot_delete_someone_elses_post",
      assertFails(strangerSellerDb.collection("business_posts").doc("existing2").delete()));
    await record("a12_positive_admin_can_delete_any_post",
      assertSucceeds(adminDb.collection("business_posts").doc("existing2").delete()));

    console.log("\n=== PHASE 48 SECTION A (firestore.rules) SUMMARY ===");
    const totalA = Object.keys(results).length;
    const passedA = Object.values(results).filter((v) => v === "PASSED").length;
    for (const [k, v] of Object.entries(results)) console.log(`  ${v === "PASSED" ? "PASS" : "FAIL"}  ${k}`);
    console.log(`\n${passedA}/${totalA} scenarios passed`);

    // ============================================================
    // SECTION B — storage.rules: business_posts/{fileName}
    // ============================================================
    const storageResults = [];
    function recordStorage(label, pass, detail) {
      storageResults.push({ label, pass, detail });
    }
    async function scenario(label, expect, fn) {
      try {
        await (expect === "allow" ? assertSucceeds(fn()) : assertFails(fn()));
        recordStorage(label, true, "");
      } catch (e) {
        recordStorage(label, false, `expected ${expect} — ${String(e.message || e).slice(0, 160)}`);
      }
    }
    function ctxStorage(kind, uid) {
      if (kind === "unauth") return testEnv.unauthenticatedContext().storage();
      const claims = kind === "admin" ? adminClaims("x@x.test") : kind === "seller" ? sellerClaims("x@x.test") : unprivilegedClaims("x@x.test");
      return testEnv.authenticatedContext(uid, claims).storage();
    }
    const put = (s, p, meta = IMG) => () => uploadBytes(ref(s, p), PNG, meta);
    const get = (s, p) => () => getBytes(ref(s, p));
    async function seedStorage(p) {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await uploadBytes(ref(ctx.storage(), p), PNG, IMG);
      });
    }

    const S1 = "p48s-seller1";
    const S2 = "p48s-seller2";
    await seedStorage(`business_posts/${S1}_seed.png`);

    await scenario("public (unauthenticated) read is allowed", "allow", get(ctxStorage("unauth"), `business_posts/${S1}_seed.png`));
    await scenario("seller writes an image under their OWN uid prefix", "allow", put(ctxStorage("seller", S1), `business_posts/${S1}_new.png`));
    await scenario("admin writes an image with no uid prefix at all", "allow", put(ctxStorage("admin", S1), "business_posts/admin_upload.png"));
    await scenario("seller writing under ANOTHER seller's uid prefix is denied", "deny", put(ctxStorage("seller", S2), `business_posts/${S1}_evil.png`));
    await scenario("plain user write is denied", "deny", put(ctxStorage("user", S1), `business_posts/${S1}_u.png`));
    await scenario("seller writing a NON-image is denied", "deny", put(ctxStorage("seller", S1), `business_posts/${S1}_doc.pdf`, PDF));

    console.log("\n=== PHASE 48 SECTION B (storage.rules) SUMMARY ===");
    for (const r of storageResults) console.log(`  ${r.pass ? "PASS" : "FAIL"}  ${r.label}${r.pass ? "" : ` :: ${r.detail}`}`);
    const passedB = storageResults.filter((r) => r.pass).length;
    console.log(`\n${passedB}/${storageResults.length} scenarios passed`);

    const totalAll = totalA + storageResults.length;
    const passedAll = passedA + passedB;
    console.log(`\n=== PHASE 48 OVERALL: ${passedAll}/${totalAll} passed — ${passedAll === totalAll ? "ALL PASSED" : "FAILED"} ===`);
    if (passedAll !== totalAll) process.exitCode = 1;
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((e) => {
  console.error("PHASE 48: harness error", e);
  process.exit(1);
});
