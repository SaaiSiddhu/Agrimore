// ============================================================
//  Phase SELLER-AUTH-1b — sellerRequests rules: the owner only writes drafts
// ============================================================
//
// Run with: JAVA_HOME=/opt/homebrew/opt/openjdk@21 firebase emulators:exec
//             --only firestore "node scripts/phaseSAUTH1B_seller_requests_rules_test.js"

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
      await db.collection("users").doc("s1").set({ role: "user" });
      await db.collection("users").doc("s2").set({ role: "user" });
      await db.collection("sellerRequests").doc("pendingSeller").set({ userId: "pendingSeller", status: "pending", shopName: "A" });
      await db.collection("sellerRequests").doc("rejectedSeller").set({ userId: "rejectedSeller", status: "rejected", shopName: "B" });
      await db.collection("sellerRequests").doc("approvedSeller").set({ userId: "approvedSeller", status: "approved", shopName: "C" });
      await db.collection("sellerRequests").doc("s2").set({ userId: "s2", status: "draft", shopName: "Other" });
    });

    const s1 = testEnv.authenticatedContext("s1", { role: "user" }).firestore();
    const s2 = testEnv.authenticatedContext("s2", { role: "user" }).firestore();
    const pendingSeller = testEnv.authenticatedContext("pendingSeller", { role: "user" }).firestore();
    const rejectedSeller = testEnv.authenticatedContext("rejectedSeller", { role: "user" }).firestore();
    const approvedSeller = testEnv.authenticatedContext("approvedSeller", { role: "user" }).firestore();
    const adminDb = testEnv.authenticatedContext("admin1", { role: "admin", admin: true }).firestore();
    const anon = testEnv.unauthenticatedContext().firestore();

    // positive: the owner creates and edits a draft
    await record("s1_positive_owner_creates_draft",
      assertSucceeds(s1.collection("sellerRequests").doc("s1").set({ userId: "s1", status: "draft", shopName: "Ravi Stores" })));
    await record("s2_positive_owner_edits_draft",
      assertSucceeds(s1.collection("sellerRequests").doc("s1").update({ city: "Madurai", status: "draft" })));
    await record("s3_positive_owner_reads_own",
      assertSucceeds(s1.collection("sellerRequests").doc("s1").get()));

    // negative: no self-submission or self-approval
    await record("s4_negative_owner_cannot_create_pending",
      assertFails(s2.collection("sellerRequests").doc("s2x").set({ userId: "s2x", status: "pending" })));
    await record("s5_negative_owner_cannot_submit_draft",
      assertFails(s1.collection("sellerRequests").doc("s1").update({ status: "pending" })));
    await record("s6_negative_owner_cannot_approve",
      assertFails(s1.collection("sellerRequests").doc("s1").update({ status: "approved" })));
    await record("s7_negative_owner_cannot_create_approved",
      assertFails(s2.collection("sellerRequests").doc("s2").set({ userId: "s2", status: "approved" })));

    // negative: other people's applications
    await record("s8_negative_cannot_read_other",
      assertFails(s1.collection("sellerRequests").doc("s2").get()));
    await record("s9_negative_cannot_write_other",
      assertFails(s1.collection("sellerRequests").doc("s2").update({ shopName: "hijack", status: "draft" })));
    await record("s10_negative_cannot_reassign_userId",
      assertFails(s1.collection("sellerRequests").doc("s1").update({ userId: "s2", status: "draft" })));
    await record("s11_negative_anonymous_cannot_read",
      assertFails(anon.collection("sellerRequests").doc("s1").get()));

    // submitted applications are frozen; rejected can be reopened as a draft
    await record("s12_negative_pending_is_frozen",
      assertFails(pendingSeller.collection("sellerRequests").doc("pendingSeller").update({ shopName: "changed" })));
    await record("s13_negative_pending_cannot_go_back_to_draft",
      assertFails(pendingSeller.collection("sellerRequests").doc("pendingSeller").update({ status: "draft" })));
    await record("s14_positive_rejected_reopens_as_draft",
      assertSucceeds(rejectedSeller.collection("sellerRequests").doc("rejectedSeller").update({ status: "draft", shopName: "B fixed" })));
    await record("s15_negative_approved_cannot_reopen",
      assertFails(approvedSeller.collection("sellerRequests").doc("approvedSeller").update({ status: "draft" })));

    // admin keeps full control
    await record("s16_positive_admin_reads_any",
      assertSucceeds(adminDb.collection("sellerRequests").doc("s2").get()));
    await record("s17_positive_admin_approves",
      assertSucceeds(adminDb.collection("sellerRequests").doc("pendingSeller").update({ status: "approved" })));

    console.log("\n=== PHASE SELLER-AUTH-1b (rules) SUMMARY ===");
    const total = Object.keys(results).length;
    const passed = Object.values(results).filter((v) => v === "PASSED").length;
    for (const [k, v] of Object.entries(results)) console.log(`  ${v === "PASSED" ? "PASS" : "FAIL"}  ${k}`);
    console.log(`\n${passed}/${total} scenarios passed`);
    if (passed !== total) { console.error("PHASE SELLER-AUTH-1b (rules): FAILED"); process.exitCode = 1; }
    else console.log("PHASE SELLER-AUTH-1b (rules): ALL PASSED");
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((e) => { console.error("harness error", e); process.exit(1); });
