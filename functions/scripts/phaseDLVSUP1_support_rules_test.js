// ============================================================
//  Phase DLVSUP1 — rider_support_tickets rules
// ============================================================
// A rider reads only their own tickets (single doc and list); an admin
// reads all; no client — rider or admin — creates, edits or deletes one
// (submitSupportRequest / updateSupportRequest are the only writers).
//
// Run with: JAVA_HOME=/opt/homebrew/opt/openjdk@21 firebase emulators:exec
//             --only firestore "node scripts/phaseDLVSUP1_support_rules_test.js"
// Honours FIRESTORE_EMULATOR_HOST.

const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");

async function main() {
  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
  const [host, port] = (process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080").split(":");
  const testEnv = await initializeTestEnvironment({
    projectId: "demo-dlvsup1-support-rules",
    firestore: { rules, host, port: Number(port) },
  });
  const results = {};
  const record = (k, p) => p.then(
    () => { results[k] = "PASSED"; console.log(`${k}: PASSED`); },
    (e) => { results[k] = `FAILED — ${e.message}`; console.log(`${k}: FAILED — ${e.message}`); }
  );
  const ticket = (riderId) => ({
    ticketId: `${riderId}_req00001`, riderId, category: "delivery_issue", relatedTo: null,
    message: "Something went wrong", attachmentPath: null, status: "submitted",
  });
  try {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await db.doc("rider_support_tickets/r1_req00001").set(ticket("r1"));
      await db.doc("rider_support_tickets/r2_req00001").set(ticket("r2"));
    });
    const rider = testEnv.authenticatedContext("r1", { role: "delivery_partner" }).firestore();
    const otherRider = testEnv.authenticatedContext("r2", { role: "delivery_partner" }).firestore();
    const adminDb = testEnv.authenticatedContext("admin1", { role: "admin", admin: true }).firestore();
    const anon = testEnv.unauthenticatedContext().firestore();

    await record("t01_positive_rider_reads_own", assertSucceeds(rider.doc("rider_support_tickets/r1_req00001").get()));
    await record("t02_positive_rider_lists_own", assertSucceeds(rider.collection("rider_support_tickets").where("riderId", "==", "r1").get()));
    await record("t03_negative_rider_cannot_read_others", assertFails(rider.doc("rider_support_tickets/r2_req00001").get()));
    await record("t04_negative_rider_cannot_list_all", assertFails(rider.collection("rider_support_tickets").get()));
    await record("t05_negative_signed_out_cannot_read", assertFails(anon.doc("rider_support_tickets/r1_req00001").get()));
    await record("t06_positive_admin_lists_all", assertSucceeds(adminDb.collection("rider_support_tickets").get()));
    await record("t07_negative_rider_cannot_create", assertFails(rider.doc("rider_support_tickets/r1_forged01").set(ticket("r1"))));
    await record("t08_negative_rider_cannot_mark_own_closed",
      assertFails(rider.doc("rider_support_tickets/r1_req00001").update({ status: "closed", resolutionNote: "self-closed" })));
    await record("t09_negative_rider_cannot_delete_own", assertFails(rider.doc("rider_support_tickets/r1_req00001").delete()));
    await record("t10_negative_admin_cannot_write_directly",
      assertFails(adminDb.doc("rider_support_tickets/r2_req00001").update({ status: "seen" })));
    await record("t11_negative_other_rider_cannot_create_for_r1", assertFails(otherRider.doc("rider_support_tickets/r1_x0000001").set(ticket("r1"))));

    console.log("\n=== PHASE DLVSUP1 (rules) SUMMARY ===");
    const total = Object.keys(results).length;
    const passed = Object.values(results).filter((v) => v === "PASSED").length;
    console.log(`\n${passed}/${total} scenarios passed`);
    await testEnv.cleanup();
    if (passed !== total) { console.log("PHASE DLVSUP1 rules: FAILED"); process.exit(1); }
    console.log("PHASE DLVSUP1 rules: ALL PASSED");
    process.exit(0);
  } catch (e) {
    console.error(e);
    await testEnv.cleanup();
    process.exit(1);
  }
}
main();
