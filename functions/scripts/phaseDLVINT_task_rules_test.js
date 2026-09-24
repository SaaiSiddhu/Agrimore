// Phase DLV-INT — delivery_tasks reads of a task not made yet. The rider app
// opens an accepted order before syncDeliveryTask writes the task; a denied
// listener never recovers, so the route card stayed empty (integration pass).
// A missing task (or live point) now reads as absent; everything else is as
// before (phaseDLV1A_delivery_task_rules_test, phaseDLV3A_live_rules_test).
// Run with: firebase emulators:exec --only firestore "node scripts/phaseDLVINT_task_rules_test.js"
const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const { doc, getDoc, collection, getDocs, query, where, setDoc } = require("firebase/firestore");

const [EMU_HOST, EMU_PORT] = (process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080").split(":");
const base = { admin: false, seller: false, delivery_partner: false, employee: false };
const RIDER = { ...base, role: "delivery_partner", delivery_partner: true };
let testEnv;
const results = [];
async function scenario(label, expect, fn) {
  try {
    await (expect === "allow" ? assertSucceeds(fn()) : assertFails(fn()));
    results.push(true); console.log(`PASSED — ${label}`);
  } catch (e) {
    results.push(false); console.log(`FAILED — ${label} :: expected ${expect} — ${String(e.message || e).slice(0, 160)}`);
  }
}
async function main() {
  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
  testEnv = await initializeTestEnvironment({ projectId: "demo-dlvint-task-rules", firestore: { rules, host: EMU_HOST, port: Number(EMU_PORT) } });
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (c) => {
    const f = c.firestore();
    for (const r of ["r1", "r2"]) await setDoc(doc(f, `users/${r}`), { role: "delivery_partner" });
    await setDoc(doc(f, "delivery_tasks/o1"), { orderId: "o1", riderId: "r1", customerId: "c1", sellerId: "s1", status: "en_route" });
    await setDoc(doc(f, "delivery_tasks/o1/live/rider"), { riderId: "r1", lat: 9.9, lng: 78.1 });
  });
  const r1 = testEnv.authenticatedContext("r1", RIDER).firestore();
  const r2 = testEnv.authenticatedContext("r2", RIDER).firestore();
  await scenario("t01_missing_task_reads_as_absent", "allow", async () => {
    const s = await getDoc(doc(r1, "delivery_tasks/o-new"));
    if (s.exists()) throw new Error("should not exist");
  });
  await scenario("t02_missing_live_point_reads_as_absent", "allow", () => getDoc(doc(r1, "delivery_tasks/o-new/live/rider")));
  await scenario("t03_own_task_readable", "allow", () => getDoc(doc(r1, "delivery_tasks/o1")));
  await scenario("t04_other_riders_task_denied", "deny", () => getDoc(doc(r2, "delivery_tasks/o1")));
  await scenario("t05_other_riders_live_point_denied", "deny", () => getDoc(doc(r2, "delivery_tasks/o1/live/rider")));
  await scenario("t06_unconstrained_list_denied", "deny", () => getDocs(collection(r2, "delivery_tasks")));
  await scenario("t07_list_by_other_rider_denied", "deny", () => getDocs(query(collection(r2, "delivery_tasks"), where("riderId", "==", "r1"))));
  await scenario("t08_unauthenticated_missing_read_denied", "deny", () => getDoc(doc(testEnv.unauthenticatedContext().firestore(), "delivery_tasks/o-new")));
  await testEnv.cleanup();
  const failed = results.filter((x) => !x).length;
  console.log(`\n${results.length - failed}/${results.length} passed`);
  process.exit(failed ? 1 : 0);
}
main().catch((e) => { console.error(e); process.exit(1); });
