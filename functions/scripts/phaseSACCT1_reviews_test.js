// ============================================================
//  Phase SELLER-ACCOUNT-1a — server ratings, verified purchase, seller replies
// ============================================================
//
// Run with: JAVA_HOME=/opt/homebrew/opt/openjdk@21 firebase emulators:exec
//             --only firestore "node scripts/phaseSACCT1_reviews_test.js"

process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const fs = require("fs");
const path = require("path");
const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });
const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const { summarise, refreshProductReviews, replyToReview, REPLY_EDIT_WINDOW_MS } = require("../lib/seller/reviews");

const reply = test.wrap(replyToReview);
const SELLER = "sacct1-seller";
const BUYER = "sacct1-buyer";
const LIAR = "sacct1-liar";

async function main() {
  const db = admin.firestore();
  const results = {};
  const check = async (name, fn) => {
    try { await fn(); results[name] = "PASSED"; } catch (e) { results[name] = `FAILED — ${e.message}`; }
    console.log(`${name}: ${results[name]}`);
  };
  const expect = (cond, msg) => { if (!cond) throw new Error(msg); };
  const call = async (data, uid) => {
    try { return { ok: true, r: await reply({ data, auth: { uid, token: {} } }) }; }
    catch (e) { return { ok: false, code: e.code, message: e.message }; }
  };

  const P = "sacct1-p1";
  const P2 = "sacct1-p2";
  const productRef = db.collection("products").doc(P);
  await productRef.set({ name: "Basmati Rice", sellerId: SELLER, rating: 0, reviewCount: 0 });
  await db.collection("products").doc(P2).set({ name: "Toor Dal", sellerId: SELLER, rating: 4, reviewCount: 2 });
  await db.collection("sellers").doc(SELLER).set({ status: "approved", shopName: "Ravi" });
  await db.collection("orders").doc("sacct1-o1").set({ userId: BUYER, orderStatus: "delivered", items: [{ productId: P, quantity: 1 }] });
  await db.collection("orders").doc("sacct1-o2").set({ userId: LIAR, orderStatus: "pending", items: [{ productId: P, quantity: 1 }] });
  await productRef.collection("reviews").doc("r1").set({ userId: BUYER, rating: 5, isVerifiedPurchase: false });
  await productRef.collection("reviews").doc("r2").set({ userId: LIAR, rating: 2, isVerifiedPurchase: true });

  await check("v1_summary_ignores_out_of_range", async () => {
    const s = summarise([5, 4, 0, 6, "5", 3.4, null]);
    expect(s.total === 3 && s.average === 4 && s.distribution["3"] === 1, JSON.stringify(s));
  });

  await check("v2_product_stats_and_rating_recomputed", async () => {
    await refreshProductReviews(db, P, "r1");
    await refreshProductReviews(db, P, "r2");
    const p = (await productRef.get()).data();
    const stats = (await productRef.collection("reviewStats").doc("stats").get()).data();
    expect(p.rating === 3.5 && p.reviewCount === 2, JSON.stringify(p));
    expect(stats.totalReviews === 2 && stats.fiveStarCount === 1 && stats.twoStarCount === 1, JSON.stringify(stats));
  });

  await check("v3_verified_purchase_is_server_truth", async () => {
    const r1 = (await productRef.collection("reviews").doc("r1").get()).data();
    const r2 = (await productRef.collection("reviews").doc("r2").get()).data();
    expect(r1.isVerifiedPurchase === true, "delivered buyer not verified");
    expect(r2.isVerifiedPurchase === false, "undelivered claim kept");
    expect(r1.sellerId === SELLER && r1.productName === "Basmati Rice", JSON.stringify(r1));
  });

  await check("v4_seller_rating_is_review_weighted", async () => {
    const s = (await db.collection("sellers").doc(SELLER).get()).data();
    // (3.5×2 + 4×2) / 4 = 3.75 → 3.8
    expect(s.rating === 3.8 && s.reviewCount === 4, JSON.stringify(s));
  });

  await check("v5_only_the_products_seller_may_reply", async () => {
    const r = await call({ productId: P, reviewId: "r1", text: "Thank you!" }, "sacct1-other-seller");
    expect(!r.ok && r.code === "permission-denied", JSON.stringify(r));
  });

  await check("v6_seller_replies_and_edits_within_24h", async () => {
    let r = await call({ productId: P, reviewId: "r1", text: "Thank you!" }, SELLER);
    expect(r.ok, JSON.stringify(r));
    r = await call({ productId: P, reviewId: "r1", text: "Thank you, Priya!" }, SELLER);
    expect(r.ok, JSON.stringify(r));
    const rep = (await productRef.collection("reviews").doc("r1").get()).data().sellerReply;
    expect(rep.text === "Thank you, Priya!" && rep.editedAt !== null, JSON.stringify(rep));
  });

  await check("v7_reply_locked_after_24h", async () => {
    await productRef.collection("reviews").doc("r2").update({
      sellerReply: { text: "old", at: admin.firestore.Timestamp.fromMillis(Date.now() - REPLY_EDIT_WINDOW_MS - 1000), editedAt: null },
    });
    const r = await call({ productId: P, reviewId: "r2", text: "new" }, SELLER);
    expect(!r.ok && r.code === "failed-precondition", JSON.stringify(r));
  });

  await check("v8_reply_bounds", async () => {
    for (const text of ["", "   ", "x".repeat(501)]) {
      const r = await call({ productId: P, reviewId: "r1", text }, SELLER);
      expect(!r.ok && r.code === "invalid-argument", `${text.length}: ${JSON.stringify(r)}`);
    }
  });

  // Rules
  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
  const env = await initializeTestEnvironment({ projectId: "agrimore-66a4e", firestore: { rules, host: "127.0.0.1", port: 8080 } });
  try {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc(`products/${P}/reviews/mine`).set({ userId: "u1", rating: 4, comment: "ok" });
    });
    const u1 = env.authenticatedContext("u1").firestore();
    const rev = (id) => u1.doc(`products/${P}/reviews/${id}`);
    await check("w1_positive_buyer_reviews", () => assertSucceeds(rev("n1").set({ userId: "u1", rating: 5, comment: "Great" })));
    await check("w2_negative_rating_out_of_range", () =>
      Promise.all([assertFails(rev("n2").set({ userId: "u1", rating: 50 })), assertFails(rev("n3").set({ userId: "u1", rating: 0 })),
        assertFails(rev("n4").set({ userId: "u1", rating: "5" }))]));
    await check("w3_negative_buyer_cannot_forge_reply", () =>
      assertFails(rev("n5").set({ userId: "u1", rating: 5, sellerReply: { text: "Best buyer ever" } })));
    await check("w4_negative_buyer_cannot_add_reply_later", () => assertFails(rev("mine").update({ sellerReply: { text: "x" } })));
    await check("w5_positive_buyer_edits_own_text", () => assertSucceeds(rev("mine").update({ comment: "Actually great", rating: 5 })));
    await check("w6_negative_buyer_cannot_edit_to_bad_rating", () => assertFails(rev("mine").update({ rating: 9 })));
    await env.withSecurityRulesDisabled(async (ctx) => {
      const d = ctx.firestore();
      await d.doc(`products/${P}/reviews/sr1`).set({ userId: "u9", sellerId: "s-own", rating: 4, createdAt: new Date() });
      await d.doc(`products/${P}/reviews/sr2`).set({ userId: "u8", sellerId: "s-other", rating: 3, createdAt: new Date() });
      await d.doc("orders/o9/reviews/or1").set({ userId: "u9", rating: 2, note: "late" });
    });
    const sOwn = env.authenticatedContext("s-own").firestore();
    await check("w7_positive_seller_lists_own_reviews", () =>
      assertSucceeds(sOwn.collectionGroup("reviews").where("sellerId", "==", "s-own").get()));
    await check("w8_negative_seller_cannot_list_others", () =>
      assertFails(sOwn.collectionGroup("reviews").where("sellerId", "==", "s-other").get()));
    await check("w9_negative_unfiltered_collection_group_denied", () => assertFails(sOwn.collectionGroup("reviews").get()));
    await check("w10_positive_writer_lists_own_reviews", () =>
      assertSucceeds(env.authenticatedContext("u9").firestore().collectionGroup("reviews").where("userId", "==", "u9").get()));
    await check("w11_positive_admin_lists_all", () =>
      assertSucceeds(env.authenticatedContext("adm", { role: "admin", admin: true }).firestore().collectionGroup("reviews").limit(50).get()));
    await check("w12_negative_stranger_cannot_read_order_rating", () =>
      assertFails(env.authenticatedContext("u7").firestore().doc("orders/o9/reviews/or1").get()));
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc("sellers/g1").set({ status: "approved", gstin: "OLD-UNCHECKED" });
    });
    const g1 = env.authenticatedContext("g1").firestore().doc("sellers/g1");
    await check("w13_positive_valid_gstin_saves_both_keys", () =>
      assertSucceeds(g1.update({ gstin: "33ABCDE1234F1Z5", gstNumber: "33ABCDE1234F1Z5" })));
    await check("w14_negative_malformed_gstin", () => assertFails(g1.update({ gstin: "33abcde1234f1z5" })));
    await check("w15_positive_gstin_cleared", () => assertSucceeds(g1.update({ gstin: "" })));
  } finally {
    await env.cleanup();
  }

  console.log("\n=== PHASE SELLER-ACCOUNT-1a SUMMARY ===");
  const total = Object.keys(results).length;
  const passed = Object.values(results).filter((v) => v === "PASSED").length;
  for (const [k, v] of Object.entries(results)) console.log(`  ${v === "PASSED" ? "PASS" : "FAIL"}  ${k}`);
  console.log(`\n${passed}/${total} scenarios passed`);
  if (passed !== total) { console.error("PHASE SELLER-ACCOUNT-1a: FAILED"); process.exitCode = 1; }
  else console.log("PHASE SELLER-ACCOUNT-1a: ALL PASSED");
  test.cleanup();
}
main().catch((e) => { console.error("harness error", e); process.exit(1); });
