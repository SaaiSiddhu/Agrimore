// ============================================================
//  Phase SELLER-HOME-1a — seller_stats_daily / seller_stats_contrib rules
// ============================================================

const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");

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
  try {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await db.collection("seller_stats_daily").doc("s1_20260922").set({ sellerId: "s1", day: "20260922", orders: 3, gross: 900 });
      await db.collection("seller_stats_contrib").doc("o1").set({ c: { sellerId: "s1" } });
    });
    const s1 = testEnv.authenticatedContext("s1").firestore();
    const s2 = testEnv.authenticatedContext("s2").firestore();
    const adminDb = testEnv.authenticatedContext("admin1", { role: "admin", admin: true }).firestore();

    await record("s1_positive_seller_reads_own_day", assertSucceeds(s1.collection("seller_stats_daily").doc("s1_20260922").get()));
    await record("s2_positive_seller_queries_own_range",
      assertSucceeds(s1.collection("seller_stats_daily").where("sellerId", "==", "s1").where("day", ">=", "20260901").get()));
    await record("s3_negative_other_seller_cannot_read", assertFails(s2.collection("seller_stats_daily").doc("s1_20260922").get()));
    await record("s4_negative_seller_cannot_inflate", assertFails(s1.collection("seller_stats_daily").doc("s1_20260922").update({ gross: 99999 })));
    await record("s5_negative_seller_cannot_create", assertFails(s1.collection("seller_stats_daily").doc("s1_20260923").set({ sellerId: "s1", day: "20260923", gross: 1 })));
    await record("s6_positive_admin_reads", assertSucceeds(adminDb.collection("seller_stats_daily").doc("s1_20260922").get()));
    await record("s7_negative_admin_cannot_write", assertFails(adminDb.collection("seller_stats_daily").doc("s1_20260922").update({ gross: 1 })));
    await record("s8_negative_markers_closed_to_owner", assertFails(s1.collection("seller_stats_contrib").doc("o1").get()));
    await record("s9_negative_markers_closed_to_admin", assertFails(adminDb.collection("seller_stats_contrib").doc("o1").get()));

    console.log("\n=== PHASE SELLER-HOME-1a (rules) SUMMARY ===");
    const total = Object.keys(results).length;
    const passed = Object.values(results).filter((v) => v === "PASSED").length;
    for (const [k, v] of Object.entries(results)) console.log(`  ${v === "PASSED" ? "PASS" : "FAIL"}  ${k}`);
    console.log(`\n${passed}/${total} scenarios passed`);
    if (passed !== total) { console.error("PHASE SELLER-HOME-1a (rules): FAILED"); process.exitCode = 1; }
    else console.log("PHASE SELLER-HOME-1a (rules): ALL PASSED");
  } finally {
    await testEnv.cleanup();
  }
}
main().catch((e) => { console.error("harness error", e); process.exit(1); });
