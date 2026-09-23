// Phase DLV-2A — firestore.rules for delivery_requests and delivery_dispatch.
//
// delivery_requests had NO rules block (so no client could read its offers;
// default deny). A rider must be able to read — and query — the offers sent
// to it, and nothing else; nobody may write one from a client (an offer a
// rider could write is an order it could award itself — acceptance is the
// acceptDeliveryOffer callable). delivery_dispatch is admin-read only.
//
// Run with:
//   firebase emulators:exec --only firestore "node scripts/phaseDLV2A_dispatch_rules_test.js"
// Honours FIRESTORE_EMULATOR_HOST (set by emulators:exec), falling back to 127.0.0.1:8080.
const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");

const [EMU_HOST, EMU_PORT] = (process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080").split(":");
const base = { admin: false, seller: false, delivery_partner: false, employee: false };
const CLAIMS = {
  rider: { ...base, role: "delivery_partner", delivery_partner: true },
  admin: { ...base, role: "admin", admin: true },
  user: { ...base, role: "user" },
};
const R1 = "dlv2a-rr-1";
const R2 = "dlv2a-rr-2";
const LEGACY = "dlv2a-rr-legacy";
const ADMIN = "dlv2a-rr-admin";
const CUST = "dlv2a-rr-cust";

let testEnv;
const results = [];
async function scenario(label, expect, fn) {
  try {
    await (expect === "allow" ? assertSucceeds(fn()) : assertFails(fn()));
    results.push({ label, pass: true });
    console.log(`PASSED — ${label}`);
  } catch (e) {
    results.push({ label, pass: false });
    console.log(`FAILED — ${label} :: expected ${expect} — ${String(e.message || e).slice(0, 160)}`);
  }
}
const db = (kind, uid) => testEnv.authenticatedContext(uid, CLAIMS[kind]).firestore();
const reqs = (d) => d.collection("delivery_requests");

async function main() {
  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
  testEnv = await initializeTestEnvironment({ projectId: "demo-dlv2a", firestore: { rules, host: EMU_HOST, port: Number(EMU_PORT) } });
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (c) => {
    const f = c.firestore();
    await f.collection("users").doc(ADMIN).set({ role: "admin" });
    const exp = new Date(Date.now() + 30000);
    await f.collection("delivery_requests").doc(`o1_${R1}`).set({ orderId: "o1", riderId: R1, partnerId: R1, status: "offered", expiresAt: exp, codAmount: 450 });
    await f.collection("delivery_requests").doc(`o1_${R2}`).set({ orderId: "o1", riderId: R2, partnerId: R2, status: "offered", expiresAt: exp, codAmount: 450 });
    // Written by the pre-DLV-2A dispatcher: partnerId only.
    await f.collection("delivery_requests").doc(`o0_${LEGACY}`).set({ orderId: "o0", partnerId: LEGACY, status: "pending" });
    await f.collection("delivery_dispatch").doc("o1").set({ orderId: "o1", status: "dispatching", wave: 1, needsAdmin: false });
  });

  console.log("=== PHASE DLV-2A — dispatch rules ===");
  // Positive controls.
  await scenario("q01_rider_reads_its_own_offer", "allow", () => reqs(db("rider", R1)).doc(`o1_${R1}`).get());
  await scenario("q02_rider_queries_its_open_offers", "allow",
    () => reqs(db("rider", R1)).where("riderId", "==", R1).where("status", "==", "offered").get());
  await scenario("q03_legacy_partnerId_offer_readable_by_that_partner", "allow",
    () => reqs(db("rider", LEGACY)).doc(`o0_${LEGACY}`).get());
  await scenario("q04_admin_reads_any_offer", "allow", () => reqs(db("admin", ADMIN)).doc(`o1_${R2}`).get());
  await scenario("q05_admin_reads_dispatch_state", "allow", () => db("admin", ADMIN).collection("delivery_dispatch").doc("o1").get());
  // Denials.
  await scenario("q06_rider_cannot_read_another_riders_offer", "deny", () => reqs(db("rider", R1)).doc(`o1_${R2}`).get());
  await scenario("q07_rider_cannot_list_all_offers", "deny", () => reqs(db("rider", R1)).get());
  await scenario("q08_rider_cannot_query_another_riders_offers", "deny",
    () => reqs(db("rider", R1)).where("riderId", "==", R2).get());
  await scenario("q09_rider_cannot_accept_by_writing_its_offer", "deny",
    () => reqs(db("rider", R1)).doc(`o1_${R1}`).update({ status: "accepted" }));
  await scenario("q10_rider_cannot_extend_its_offer", "deny",
    () => reqs(db("rider", R1)).doc(`o1_${R1}`).update({ expiresAt: new Date(Date.now() + 3600000) }));
  await scenario("q11_rider_cannot_create_an_offer_for_itself", "deny",
    () => reqs(db("rider", R1)).doc(`o9_${R1}`).set({ orderId: "o9", riderId: R1, status: "offered" }));
  await scenario("q12_rider_cannot_delete_a_competitors_offer", "deny", () => reqs(db("rider", R1)).doc(`o1_${R2}`).delete());
  await scenario("q13_customer_cannot_read_offers", "deny", () => reqs(db("user", CUST)).doc(`o1_${R1}`).get());
  await scenario("q14_rider_cannot_read_dispatch_state", "deny", () => db("rider", R1).collection("delivery_dispatch").doc("o1").get());
  await scenario("q15_admin_client_cannot_write_dispatch_state", "deny",
    () => db("admin", ADMIN).collection("delivery_dispatch").doc("o1").update({ needsAdmin: true }));
  await scenario("q16_admin_client_cannot_write_offers", "deny",
    () => reqs(db("admin", ADMIN)).doc(`o1_${R1}`).update({ status: "withdrawn" }));

  await testEnv.clearFirestore();
  await testEnv.cleanup();
  const failed = results.filter((r) => !r.pass);
  console.log(`\n${results.length - failed.length}/${results.length} passed`);
  if (failed.length) { console.log("PHASE DLV-2A dispatch rules: FAILED"); process.exit(1); }
  console.log("PHASE DLV-2A dispatch rules: ALL PASSED");
}

main().catch(async (e) => { console.error(e); try { await testEnv?.cleanup(); } catch (_) { /* ignore */ } process.exit(1); });
