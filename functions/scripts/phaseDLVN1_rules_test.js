// Phase DLV-N1 — firestore.rules for what the rider app now reads.
//  r01 the history filter query (deliveryPartnerId AND (orderStatus IN … OR status IN …)) is allowed for the rider
//  r02 the same filter without the rider constraint is refused
//  r03 the rider reads their own inbox and marks a notice read
//  r04 … but cannot rewrite what it says, nor create one
//  r05 another rider cannot read it
//  r06 the rider reads their own pay for one order; not another rider's
// Run with:
//   firebase emulators:exec --only firestore "node scripts/phaseDLVN1_rules_test.js"
const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const { collection, query, where, and, or, orderBy, limit, getDocs, doc, getDoc, updateDoc, setDoc, serverTimestamp } = require("firebase/firestore");

const [EMU_HOST, EMU_PORT] = (process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080").split(":");
const base = { admin: false, seller: false, delivery_partner: false, employee: false };
const R1 = "n1-r1", R2 = "n1-r2";
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
const DELIVERED = ["delivered", "completed", "Delivered", "Completed"];

async function main() {
  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
  testEnv = await initializeTestEnvironment({ projectId: "demo-dlvn1-rules", firestore: { rules, host: EMU_HOST, port: Number(EMU_PORT) } });
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (c) => {
    const f = c.firestore();
    for (const r of [R1, R2]) {
      await setDoc(doc(f, `users/${r}`), { role: "delivery_partner" });
      await setDoc(doc(f, `delivery_partners/${r}`), { status: "approved" });
    }
    await setDoc(doc(f, "orders/o1"), { deliveryPartnerId: R1, orderStatus: "out_for_delivery", status: "delivered", userId: "c1", createdAt: new Date() });
    await setDoc(doc(f, "orders/o2"), { deliveryPartnerId: R2, orderStatus: "delivered", userId: "c2", createdAt: new Date() });
    await setDoc(doc(f, `users/${R1}/notifications/payout_sent_x`), { type: "payout_sent", title: "Money sent", body: "₹10.00", unread: true, audience: "rider" });
    await setDoc(doc(f, "rider_earnings/o1"), { riderId: R1, total: 40, totalPaise: 4000, statementId: null });
    await setDoc(doc(f, "rider_earnings/o2"), { riderId: R2, total: 50, totalPaise: 5000, statementId: null });
  });
  const r1 = testEnv.authenticatedContext(R1, RIDER).firestore();
  const r2 = testEnv.authenticatedContext(R2, RIDER).firestore();
  await scenario("r01_history_filter_query_allowed", "allow", async () => {
    const q = query(collection(r1, "orders"),
      and(where("deliveryPartnerId", "==", R1), or(where("orderStatus", "in", DELIVERED), where("status", "in", DELIVERED))),
      orderBy("createdAt", "desc"), limit(21));
    const s = await getDocs(q);
    if (s.size !== 1 || s.docs[0].id !== "o1") throw new Error(`got ${s.size}`);
  });
  await scenario("r02_filter_without_rider_constraint_refused", "deny", () => getDocs(query(collection(r1, "orders"),
    or(where("orderStatus", "in", DELIVERED), where("status", "in", DELIVERED)), limit(21))));
  const note = `users/${R1}/notifications/payout_sent_x`;
  await scenario("r03_rider_reads_and_marks_read", "allow", async () => {
    await getDoc(doc(r1, note));
    await updateDoc(doc(r1, note), { unread: false, read: true, readAt: serverTimestamp() });
  });
  await scenario("r04_rider_cannot_rewrite_a_notice", "deny", () => updateDoc(doc(r1, note), { body: "₹10,000.00" }));
  await scenario("r04b_rider_cannot_create_a_notice", "deny", () => setDoc(doc(r1, `users/${R1}/notifications/fake`), { title: "x", unread: true }));
  await scenario("r05_other_rider_cannot_read_inbox", "deny", () => getDoc(doc(r2, note)));
  await scenario("r06_own_pay_for_an_order", "allow", () => getDoc(doc(r1, "rider_earnings/o1")));
  await scenario("r06b_not_another_riders_pay", "deny", () => getDoc(doc(r1, "rider_earnings/o2")));

  await testEnv.cleanup();
  const failed = results.filter((x) => !x).length;
  console.log(`\n${results.length - failed}/${results.length} passed`);
  if (failed) { console.log("PHASE DLV-N1 rules: FAILED"); process.exit(1); }
  console.log("PHASE DLV-N1 rules: ALL PASSED"); process.exit(0);
}
main().catch((e) => { console.error(e); process.exit(1); });
