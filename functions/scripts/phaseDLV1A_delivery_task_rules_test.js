// Phase DLV-1A — firestore.rules for delivery_tasks/{orderId}.
//
// The collection is written only by the syncDeliveryTask trigger (Admin SDK).
// Read: the assigned rider, the order's customer, its seller, admin. Nobody
// else — in particular not other riders: a task carries pickup/drop
// coordinates and the COD amount. No client may write it, including the
// assigned rider (a rider that could write its own task could fake progress
// or COD).
//
// Run with:
//   firebase emulators:exec --only firestore "node scripts/phaseDLV1A_delivery_task_rules_test.js"
// Honours FIRESTORE_EMULATOR_HOST (set by emulators:exec), falling back to 127.0.0.1:8080.
const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");

const [EMU_HOST, EMU_PORT] = (process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080").split(":");

const base = { admin: false, seller: false, delivery_partner: false, employee: false };
const CLAIMS = {
  user: { ...base, role: "user" },
  delivery: { ...base, role: "delivery_partner", delivery_partner: true },
  seller: { ...base, role: "seller", seller: true },
  admin: { ...base, role: "admin", admin: true },
};

const RIDER = "dlv1a-r-rider";
const OTHER_RIDER = "dlv1a-r-other-rider";
const CUSTOMER = "dlv1a-r-customer";
const OTHER_CUSTOMER = "dlv1a-r-other-customer";
const SELLER = "dlv1a-r-seller";
const OTHER_SELLER = "dlv1a-r-other-seller";
const ADMIN = "dlv1a-r-admin";

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
const task = (d, id) => d.collection("delivery_tasks").doc(id);

async function main() {
  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
  testEnv = await initializeTestEnvironment({
    projectId: "demo-dlv1a",
    firestore: { rules, host: EMU_HOST, port: Number(EMU_PORT) },
  });
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (c) => {
    const f = c.firestore();
    await f.collection("users").doc(ADMIN).set({ role: "admin" });
    for (const r of [RIDER, OTHER_RIDER]) {
      await f.collection("users").doc(r).set({ role: "delivery_partner" });
      await f.collection("delivery_partners").doc(r).set({ status: "approved" });
    }
    await f.collection("delivery_tasks").doc("t-assigned").set({
      orderId: "t-assigned", status: "en_route", riderId: RIDER, customerId: CUSTOMER, sellerId: SELLER,
      codAmount: 450, drop: { lat: 9.9, lng: 78.1, pincode: "625001" },
    });
    await f.collection("delivery_tasks").doc("t-searching").set({
      orderId: "t-searching", status: "searching", riderId: null, customerId: CUSTOMER, sellerId: SELLER,
    });
  });

  console.log("=== PHASE DLV-1A — delivery_tasks rules ===");

  // Positive controls.
  await scenario("r01_assigned_rider_reads_its_task", "allow", () => task(db("delivery", RIDER), "t-assigned").get());
  await scenario("r02_customer_reads_own_task", "allow", () => task(db("user", CUSTOMER), "t-assigned").get());
  await scenario("r03_seller_reads_own_task", "allow", () => task(db("seller", SELLER), "t-assigned").get());
  await scenario("r04_admin_reads_any_task", "allow", () => task(db("admin", ADMIN), "t-searching").get());
  await scenario("r05_rider_lists_own_tasks_by_riderId", "allow",
    () => db("delivery", RIDER).collection("delivery_tasks").where("riderId", "==", RIDER).get());
  await scenario("r06_customer_lists_own_tasks_by_customerId", "allow",
    () => db("user", CUSTOMER).collection("delivery_tasks").where("customerId", "==", CUSTOMER).get());

  // Denials.
  await scenario("r07_other_rider_cannot_read_an_assigned_task", "deny", () => task(db("delivery", OTHER_RIDER), "t-assigned").get());
  await scenario("r08_rider_cannot_read_an_unassigned_task", "deny", () => task(db("delivery", RIDER), "t-searching").get());
  await scenario("r09_other_customer_cannot_read", "deny", () => task(db("user", OTHER_CUSTOMER), "t-assigned").get());
  await scenario("r10_other_seller_cannot_read", "deny", () => task(db("seller", OTHER_SELLER), "t-assigned").get());
  await scenario("r11_rider_cannot_list_all_tasks", "deny", () => db("delivery", RIDER).collection("delivery_tasks").get());
  await scenario("r12_unauthenticated_cannot_read", "deny", () => task(testEnv.unauthenticatedContext().firestore(), "t-assigned").get());
  await scenario("r13_assigned_rider_cannot_update_its_task", "deny",
    () => task(db("delivery", RIDER), "t-assigned").update({ status: "delivered" }));
  await scenario("r14_rider_cannot_zero_the_cod_amount", "deny",
    () => task(db("delivery", RIDER), "t-assigned").update({ codAmount: 0 }));
  await scenario("r15_customer_cannot_create_a_task", "deny",
    () => task(db("user", CUSTOMER), "t-new").set({ customerId: CUSTOMER, status: "searching" }));
  await scenario("r16_admin_client_cannot_write_either", "deny",
    () => task(db("admin", ADMIN), "t-assigned").update({ status: "cancelled" }));
  await scenario("r17_nobody_can_delete", "deny", () => task(db("admin", ADMIN), "t-assigned").delete());

  await testEnv.clearFirestore();
  await testEnv.cleanup();
  const failed = results.filter((r) => !r.pass);
  console.log(`\n${results.length - failed.length}/${results.length} passed`);
  if (failed.length) { console.log("PHASE DLV-1A rules: FAILED"); process.exit(1); }
  console.log("PHASE DLV-1A rules: ALL PASSED");
}

main().catch(async (e) => { console.error(e); try { await testEnv?.cleanup(); } catch (_) { /* ignore */ } process.exit(1); });
