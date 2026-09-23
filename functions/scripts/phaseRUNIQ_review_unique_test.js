// ============================================================
//  Phase REVIEW-UNIQUE-1 — one review per buyer per product
// ============================================================
//
// Run with: JAVA_HOME=/opt/homebrew/opt/openjdk@21 firebase emulators:exec
//             --only firestore "node scripts/phaseRUNIQ_review_unique_test.js"

process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const fs = require("fs");
const path = require("path");
const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const { latestPerUser, refreshProductReviews } = require("../lib/seller/reviews");

async function main() {
  const db = admin.firestore();
  const results = {};
  const check = async (name, fn) => {
    try { await fn(); results[name] = "PASSED"; } catch (e) { results[name] = `FAILED — ${e.message}`; }
    console.log(`${name}: ${results[name]}`);
  };
  const expect = (cond, msg) => { if (!cond) throw new Error(msg); };
  const ts = (ms) => admin.firestore.Timestamp.fromMillis(ms);

  await check("u1_uid_keyed_review_beats_newer_auto_id", async () => {
    const r = latestPerUser([
      { id: "A", data: { userId: "A", createdAt: ts(1000) } },
      { id: "x9", data: { userId: "A", createdAt: ts(9000) } },
    ]);
    expect(r.kept.map((d) => d.id).join() === "A" && r.supersededBy.get("x9") === "A", JSON.stringify([...r.supersededBy]));
  });

  await check("u2_latest_wins_among_legacy_ids_and_anonymous_stand_alone", async () => {
    const r = latestPerUser([
      { id: "old", data: { userId: "B", createdAt: ts(1000) } },
      { id: "new", data: { userId: "B", createdAt: ts(2000), updatedAt: ts(5000) } },
      { id: "anon1", data: { rating: 4 } },
      { id: "anon2", data: { rating: 2 } },
    ]);
    expect(r.kept.length === 3 && r.supersededBy.get("old") === "new" && r.supersededBy.size === 1, JSON.stringify([...r.supersededBy]));
  });

  const P = "runiq-p1";
  const productRef = db.collection("products").doc(P);
  await productRef.set({ name: "Groundnut Oil", sellerId: "runiq-seller", rating: 0, reviewCount: 0 });
  await db.collection("sellers").doc("runiq-seller").set({ status: "approved" });
  const rev = (id) => productRef.collection("reviews").doc(id);
  await rev("legacy1").set({ userId: "runiq-a", rating: 1, createdAt: ts(1000) });
  await rev("runiq-a").set({ userId: "runiq-a", rating: 5, createdAt: ts(2000) });
  await rev("legacy2").set({ userId: "runiq-b", rating: 3, createdAt: ts(1500) });

  await check("e1_stats_count_one_review_per_buyer", async () => {
    await refreshProductReviews(db, P, "runiq-a");
    const p = (await productRef.get()).data();
    const stats = (await productRef.collection("reviewStats").doc("stats").get()).data();
    expect(p.reviewCount === 2 && p.rating === 4, JSON.stringify(p));
    expect(stats.totalReviews === 2 && stats.oneStarCount === 0, JSON.stringify(stats));
  });

  await check("e2_older_review_stamped_superseded", async () => {
    const [l1, a, l2] = await Promise.all([rev("legacy1").get(), rev("runiq-a").get(), rev("legacy2").get()]);
    expect(l1.data().supersededBy === "runiq-a", JSON.stringify(l1.data()));
    expect(a.data().supersededBy === undefined && l2.data().supersededBy === undefined, "winner stamped");
  });

  await check("e3_deleting_the_winner_restores_the_older_review", async () => {
    await rev("runiq-a").delete();
    await refreshProductReviews(db, P, null);
    const l1 = (await rev("legacy1").get()).data();
    const p = (await productRef.get()).data();
    expect(l1.supersededBy === undefined, JSON.stringify(l1));
    expect(p.reviewCount === 2 && p.rating === 2, JSON.stringify(p));
  });

  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
  const env = await initializeTestEnvironment({ projectId: "agrimore-66a4e", firestore: { rules, host: "127.0.0.1", port: 8080 } });
  try {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc("products/rp/reviews/u1").set({ userId: "u1", rating: 4 });
    });
    const u1 = env.authenticatedContext("u1").firestore();
    const r = (id) => u1.doc(`products/rp/reviews/${id}`);
    await check("w1_negative_client_cannot_create_superseded_stamp", () =>
      assertFails(r("n1").set({ userId: "u1", rating: 5, supersededBy: "someone" })));
    await check("w2_negative_client_cannot_clear_or_set_stamp", () => assertFails(r("u1").update({ supersededBy: "x" })));
    await check("w3_positive_re_review_edits_own_uid_doc", () =>
      assertSucceeds(r("u1").set({ userId: "u1", rating: 2, comment: "changed my mind" }, { merge: true })));
    await check("w4_negative_cannot_write_another_buyers_uid_doc", () =>
      assertFails(env.authenticatedContext("u2").firestore().doc("products/rp/reviews/u1").set({ userId: "u2", rating: 1 }, { merge: true })));
  } finally {
    await env.cleanup();
  }

  console.log("\n=== PHASE REVIEW-UNIQUE-1 SUMMARY ===");
  const total = Object.keys(results).length;
  const passed = Object.values(results).filter((v) => v === "PASSED").length;
  for (const [k, v] of Object.entries(results)) console.log(`  ${v === "PASSED" ? "PASS" : "FAIL"}  ${k}`);
  console.log(`\n${passed}/${total} scenarios passed`);
  if (passed !== total) { console.error("PHASE REVIEW-UNIQUE-1: FAILED"); process.exitCode = 1; }
  else console.log("PHASE REVIEW-UNIQUE-1: ALL PASSED");
}
main().catch((e) => { console.error("harness error", e); process.exit(1); });
