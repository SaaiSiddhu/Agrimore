// ============================================================
//  Phase SELLER-MONEY-1 — seller payouts: one admin transition, immutable amounts
// ============================================================
//
// Run with: JAVA_HOME=/opt/homebrew/opt/openjdk@21 firebase emulators:exec
//             --only firestore "node scripts/phaseSMONEY1_payout_rules_test.js"

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
  const payout = { sellerId: "seller1", orderId: "o1", grossAmount: 500, commissionAmount: 50, netAmount: 450, amount: 450, status: "pending" };
  try {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      for (const id of ["p1", "p2", "p3", "p4", "p5", "p6"]) await db.collection("seller_payouts").doc(id).set(payout);
      await db.collection("seller_payouts").doc("paid1").set({ ...payout, status: "paid", paymentReference: "UTR1" });
    });
    const adminDb = testEnv.authenticatedContext("admin1", { role: "admin", admin: true }).firestore();
    const seller = testEnv.authenticatedContext("seller1", { role: "seller", seller: true }).firestore();
    const other = testEnv.authenticatedContext("seller2", { role: "seller", seller: true }).firestore();
    const paid = (extra = {}) => ({ status: "paid", paidAt: new Date(), paymentReference: "UTR123456", paidBy: "admin1", payoutMethod: "bank", updatedAt: new Date(), ...extra });

    await record("s1_positive_admin_marks_paid_with_reference",
      assertSucceeds(adminDb.collection("seller_payouts").doc("p1").update(paid())));
    await record("s2_negative_admin_cannot_change_amount",
      assertFails(adminDb.collection("seller_payouts").doc("p2").update(paid({ netAmount: 9999 }))));
    await record("s3_negative_paid_needs_reference",
      assertFails(adminDb.collection("seller_payouts").doc("p3").update({ status: "paid", paidAt: new Date() })));
    await record("s4_negative_reference_too_short",
      assertFails(adminDb.collection("seller_payouts").doc("p4").update(paid({ paymentReference: "1" }))));
    await record("s5_negative_cannot_unpay",
      assertFails(adminDb.collection("seller_payouts").doc("paid1").update({ status: "pending", updatedAt: new Date() })));
    await record("s6_negative_cannot_repay_already_paid",
      assertFails(adminDb.collection("seller_payouts").doc("paid1").update(paid({ paymentReference: "UTR999999" }))));
    await record("s7_negative_seller_cannot_mark_own_paid",
      assertFails(seller.collection("seller_payouts").doc("p5").update(paid())));
    await record("s8_positive_seller_reads_own", assertSucceeds(seller.collection("seller_payouts").doc("p5").get()));
    await record("s9_negative_other_seller_cannot_read", assertFails(other.collection("seller_payouts").doc("p5").get()));
    await record("s10_negative_nobody_creates",
      assertFails(adminDb.collection("seller_payouts").doc("new").set(payout)));
    await record("s11_negative_admin_cannot_change_seller",
      assertFails(adminDb.collection("seller_payouts").doc("p6").update(paid({ sellerId: "seller2" }))));

    console.log("\n=== PHASE SELLER-MONEY-1 (rules) SUMMARY ===");
    const total = Object.keys(results).length;
    const passed = Object.values(results).filter((v) => v === "PASSED").length;
    for (const [k, v] of Object.entries(results)) console.log(`  ${v === "PASSED" ? "PASS" : "FAIL"}  ${k}`);
    console.log(`\n${passed}/${total} scenarios passed`);
    if (passed !== total) { console.error("PHASE SELLER-MONEY-1 (rules): FAILED"); process.exitCode = 1; }
    else console.log("PHASE SELLER-MONEY-1 (rules): ALL PASSED");
  } finally {
    await testEnv.cleanup();
  }
}
main().catch((e) => { console.error("harness error", e); process.exit(1); });
