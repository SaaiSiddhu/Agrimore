// ============================================================
//  Phase SELLER-ORDERS-2 — invoices are server-written and party-readable
// ============================================================
//
// Run with: JAVA_HOME=/opt/homebrew/opt/openjdk@21 firebase emulators:exec
//             --only firestore "node scripts/phaseSORD2_invoice_rules_test.js"

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
  const sellerClaims = { role: "seller", seller: true };
  try {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await db.collection("invoices").doc("inv1").set({ sellerId: "seller1", buyerId: "cust1", invoiceNumber: "INV/2026-27/000001" });
      await db.collection("seller_invoice_counters").doc("seller1_2026-27").set({ last: 1 });
      await db.collection("orders").doc("o1").set({ userId: "cust1", sellerId: "seller1", orderStatus: "confirmed", status: "confirmed" });
    });
    const seller = testEnv.authenticatedContext("seller1", sellerClaims).firestore();
    const buyer = testEnv.authenticatedContext("cust1", { role: "user" }).firestore();
    const stranger = testEnv.authenticatedContext("x", { role: "user" }).firestore();
    const otherSeller = testEnv.authenticatedContext("seller2", sellerClaims).firestore();
    const adminDb = testEnv.authenticatedContext("admin1", { role: "admin", admin: true }).firestore();

    await record("s1_positive_seller_reads_own_invoice", assertSucceeds(seller.collection("invoices").doc("inv1").get()));
    await record("s2_positive_buyer_reads_their_invoice", assertSucceeds(buyer.collection("invoices").doc("inv1").get()));
    await record("s3_positive_admin_reads", assertSucceeds(adminDb.collection("invoices").doc("inv1").get()));
    await record("s4_negative_stranger_cannot_read", assertFails(stranger.collection("invoices").doc("inv1").get()));
    await record("s5_negative_other_seller_cannot_read", assertFails(otherSeller.collection("invoices").doc("inv1").get()));
    await record("s6_negative_seller_cannot_write_invoice",
      assertFails(seller.collection("invoices").doc("inv1").update({ invoiceNumber: "INV/2026-27/999999" })));
    await record("s7_negative_seller_cannot_create_invoice",
      assertFails(seller.collection("invoices").doc("forged").set({ sellerId: "seller1", buyerId: "cust1" })));
    await record("s8_negative_seller_cannot_touch_counter",
      assertFails(seller.collection("seller_invoice_counters").doc("seller1_2026-27").set({ last: 0 })));
    await record("s9_negative_seller_cannot_read_counter",
      assertFails(seller.collection("seller_invoice_counters").doc("seller1_2026-27").get()));
    await record("s10_negative_seller_cannot_forge_order_invoice_link",
      assertFails(seller.collection("orders").doc("o1").update({ invoiceId: "forged", invoiceNumber: "X" })));

    console.log("\n=== PHASE SELLER-ORDERS-2 (rules) SUMMARY ===");
    const total = Object.keys(results).length;
    const passed = Object.values(results).filter((v) => v === "PASSED").length;
    for (const [k, v] of Object.entries(results)) console.log(`  ${v === "PASSED" ? "PASS" : "FAIL"}  ${k}`);
    console.log(`\n${passed}/${total} scenarios passed`);
    if (passed !== total) { console.error("PHASE SELLER-ORDERS-2 (rules): FAILED"); process.exitCode = 1; }
    else console.log("PHASE SELLER-ORDERS-2 (rules): ALL PASSED");
  } finally {
    await testEnv.cleanup();
  }
}
main().catch((e) => { console.error("harness error", e); process.exit(1); });
