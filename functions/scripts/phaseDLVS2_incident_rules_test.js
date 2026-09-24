// ============================================================
//  Phase DLV-S2 — rider_incidents / rider_incident_limits rules
// ============================================================
// A rider reads only their own incidents (single doc and list); an admin
// reads all; no client — rider or admin — creates, edits or deletes one
// (reportRiderIncident / updateRiderIncident are the only writers); the
// rate-limit docs are invisible to clients.
//
// Run with: JAVA_HOME=/opt/homebrew/opt/openjdk@21 firebase emulators:exec
//             --only firestore "node scripts/phaseDLVS2_incident_rules_test.js"
// Honours FIRESTORE_EMULATOR_HOST.

const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");

async function main() {
  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
  const [host, port] = (process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080").split(":");
  const testEnv = await initializeTestEnvironment({
    projectId: "demo-dlvs2-incident-rules",
    firestore: { rules, host, port: Number(port) },
  });
  const results = {};
  const record = (k, p) => p.then(
    () => { results[k] = "PASSED"; console.log(`${k}: PASSED`); },
    (e) => { results[k] = `FAILED — ${e.message}`; console.log(`${k}: FAILED — ${e.message}`); }
  );
  const incident = (riderId) => ({ incidentId: `${riderId}_req00001`, riderId, kind: "sos", status: "reported", activeOrderIds: [], location: { freshness: "unavailable" } });
  try {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await db.doc("rider_incidents/r1_req00001").set(incident("r1"));
      await db.doc("rider_incidents/r2_req00001").set(incident("r2"));
      await db.doc("rider_incident_limits/r1").set({ recent: [1] });
    });
    const rider = testEnv.authenticatedContext("r1", { role: "delivery_partner" }).firestore();
    const otherRider = testEnv.authenticatedContext("r2", { role: "delivery_partner" }).firestore();
    const adminDb = testEnv.authenticatedContext("admin1", { role: "admin", admin: true }).firestore();
    const anon = testEnv.unauthenticatedContext().firestore();

    await record("i01_positive_rider_reads_own", assertSucceeds(rider.doc("rider_incidents/r1_req00001").get()));
    await record("i02_positive_rider_lists_own", assertSucceeds(rider.collection("rider_incidents").where("riderId", "==", "r1").get()));
    await record("i03_negative_rider_cannot_read_others", assertFails(rider.doc("rider_incidents/r2_req00001").get()));
    await record("i04_negative_rider_cannot_list_all", assertFails(rider.collection("rider_incidents").get()));
    await record("i05_negative_signed_out_cannot_read", assertFails(anon.doc("rider_incidents/r1_req00001").get()));
    await record("i06_positive_admin_lists_all", assertSucceeds(adminDb.collection("rider_incidents").get()));
    await record("i07_negative_rider_cannot_create", assertFails(rider.doc("rider_incidents/r1_forged01").set(incident("r1"))));
    await record("i08_negative_rider_cannot_mark_own_resolved",
      assertFails(rider.doc("rider_incidents/r1_req00001").update({ status: "resolved", resolution: "self-closed" })));
    await record("i09_negative_rider_cannot_delete_own", assertFails(rider.doc("rider_incidents/r1_req00001").delete()));
    await record("i10_negative_admin_cannot_write_directly",
      assertFails(adminDb.doc("rider_incidents/r2_req00001").update({ status: "acknowledged" })));
    await record("i11_negative_other_rider_cannot_create_for_r1", assertFails(otherRider.doc("rider_incidents/r1_x0000001").set(incident("r1"))));
    await record("i12_negative_rider_cannot_read_or_reset_limits",
      assertFails(rider.doc("rider_incident_limits/r1").get()).then(() => assertFails(rider.doc("rider_incident_limits/r1").set({ recent: [] }))));
    await record("i13_negative_admin_cannot_read_limits", assertFails(adminDb.doc("rider_incident_limits/r1").get()));

    console.log("\n=== PHASE DLV-S2 (rules) SUMMARY ===");
    const total = Object.keys(results).length;
    const passed = Object.values(results).filter((v) => v === "PASSED").length;
    console.log(`\n${passed}/${total} scenarios passed`);
    await testEnv.cleanup();
    if (passed !== total) { console.log("PHASE DLV-S2 rules: FAILED"); process.exit(1); }
    console.log("PHASE DLV-S2 rules: ALL PASSED");
    process.exit(0);
  } catch (e) {
    console.error(e);
    await testEnv.cleanup();
    process.exit(1);
  }
}
main();
