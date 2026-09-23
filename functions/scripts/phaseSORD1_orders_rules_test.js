// ============================================================
//  Phase SELLER-ORDERS-1 — sellers cannot write order status directly
// ============================================================
//
// Run with: JAVA_HOME=/opt/homebrew/opt/openjdk@21 firebase emulators:exec
//             --only firestore "node scripts/phaseSORD1_orders_rules_test.js"

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
  const sellerClaims = { role: "seller", seller: true, sellerApproved: true };
  try {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await db.collection("users").doc("seller1").set({ role: "seller" });
      await db.collection("orders").doc("o1").set({
        userId: "cust1", sellerId: "seller1", orderStatus: "confirmed", status: "confirmed",
        total: 100, paymentStatus: "paid", items: [],
      });
    });
    const seller = testEnv.authenticatedContext("seller1", sellerClaims).firestore();
    const adminDb = testEnv.authenticatedContext("admin1", { role: "admin", admin: true }).firestore();
    const o = () => seller.collection("orders").doc("o1");

    await record("s1_negative_seller_cannot_self_report_delivered",
      assertFails(o().update({ orderStatus: "delivered", status: "delivered" })));
    await record("s2_negative_seller_cannot_advance_status_directly",
      assertFails(o().update({ orderStatus: "processing", status: "processing" })));
    await record("s3_negative_seller_cannot_write_status_alone",
      assertFails(o().update({ status: "cancelled" })));
    await record("s4_negative_seller_cannot_forge_cancellation",
      assertFails(o().update({ cancelledBy: "customer", cancellationReason: "other" })));
    await record("s5_negative_seller_cannot_set_refund_or_stock_flags",
      assertFails(o().update({ refundStatus: "done", stockRestored: true })));
    await record("s6_positive_seller_still_reads_own_order", assertSucceeds(o().get()));
    await record("s7_positive_seller_can_add_a_note",
      assertSucceeds(o().update({ sellerNote: "Packed in two bags", updatedAt: new Date() })));
    await record("s8_positive_admin_can_set_status",
      assertSucceeds(adminDb.collection("orders").doc("o1").update({ orderStatus: "processing", status: "processing" })));

    console.log("\n=== PHASE SELLER-ORDERS-1 (rules) SUMMARY ===");
    const total = Object.keys(results).length;
    const passed = Object.values(results).filter((v) => v === "PASSED").length;
    for (const [k, v] of Object.entries(results)) console.log(`  ${v === "PASSED" ? "PASS" : "FAIL"}  ${k}`);
    console.log(`\n${passed}/${total} scenarios passed`);
    if (passed !== total) { console.error("PHASE SELLER-ORDERS-1 (rules): FAILED"); process.exitCode = 1; }
    else console.log("PHASE SELLER-ORDERS-1 (rules): ALL PASSED");
  } finally {
    await testEnv.cleanup();
  }
}
main().catch((e) => { console.error("harness error", e); process.exit(1); });
