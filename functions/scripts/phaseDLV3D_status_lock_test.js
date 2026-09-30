// Phase DLV-3D — firestore.rules: the rider status lock (D-DLV-OTPLOCK,
// RELEASE-GATED). The assigned rider may not write orderStatus, status,
// deliveredAt or codSettlementStatus from a client at all; steps and delivery
// go through advanceDeliveryStep / releaseDeliveryOrder / confirmDelivery
// (Admin SDK). Closes audit G20: a direct `delivered` write skipped the
// customer's code. Deploy only after the new rider app is adopted.
//
// Run with:
//   firebase emulators:exec --only firestore "node scripts/phaseDLV3D_status_lock_test.js"
const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const { serverTimestamp, deleteField } = require("firebase/firestore");

const [EMU_HOST, EMU_PORT] = (process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080").split(":");

const base = { admin: false, seller: false, delivery_partner: false, employee: false };
const CLAIMS = {
  delivery: { ...base, role: "delivery_partner", delivery_partner: true },
  seller: { ...base, role: "seller", seller: true },
  admin: { ...base, role: "admin", admin: true },
};
const RIDER = "dlv3d-r-rider";
const OTHER = "dlv3d-r-other";
const SELLER = "dlv3d-r-seller";
const CUSTOMER = "dlv3d-r-customer";

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
// A claimless rider on the released app: isDeliveryPartner() via users.role + delivery_partners.status.
const dbNoClaim = (uid) => testEnv.authenticatedContext(uid, { ...base, role: "delivery_partner" }).firestore();

let n = 0;
/** A fresh order at `status`, assigned to RIDER unless `partner` says otherwise. */
async function order(status, extra = {}) {
  const id = `dlv3d-o${++n}`;
  await testEnv.withSecurityRulesDisabled(async (c) => {
    await c.firestore().collection("orders").doc(id).set({
      userId: CUSTOMER, sellerId: SELLER, total: 500, paymentMethod: "cod",
      orderStatus: status, status, deliveryPartnerId: RIDER, ...extra,
    });
  });
  return id;
}
const set = (status) => ({ orderStatus: status, status, updatedAt: serverTimestamp() });

async function main() {
  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
  testEnv = await initializeTestEnvironment({
    projectId: "demo-dlv3d",
    firestore: { rules, host: EMU_HOST, port: Number(EMU_PORT) },
  });
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (c) => {
    const f = c.firestore();
    for (const r of [RIDER, OTHER]) {
      await f.collection("users").doc(r).set({ role: "delivery_partner" });
      await f.collection("delivery_partners").doc(r).set({ status: "approved" });
    }
    await f.collection("users").doc(SELLER).set({ role: "seller" });
    await f.collection("users").doc(CUSTOMER).set({ role: "user" });
    await f.collection("users").doc("dlv3d-admin").set({ role: "admin" });
  });
  const rider = db("delivery", RIDER);
  const o = (id, d = rider) => d.collection("orders").doc(id);

  console.log("=== PHASE DLV-3D — rider status lock ===");
  // ── the code bypass (G20): no client path marks an order delivered ──
  await scenario("l01 out_for_delivery → delivered (both fields)", "deny", async () => o(await order("out_for_delivery")).update({ ...set("delivered"), deliveredAt: serverTimestamp() }));
  await scenario("l02 orderStatus alone → delivered", "deny", async () => o(await order("out_for_delivery")).update({ orderStatus: "delivered" }));
  await scenario("l03 status alone → delivered", "deny", async () => o(await order("out_for_delivery")).update({ status: "delivered" }));
  await scenario("l04 deliveredAt alone", "deny", async () => o(await order("out_for_delivery")).update({ deliveredAt: serverTimestamp() }));
  await scenario("l05 codSettlementStatus", "deny", async () => o(await order("out_for_delivery")).update({ codSettlementStatus: "collected" }));
  await scenario("l06 claimless rider (users.role fallback) → delivered", "deny", async () => o(await order("out_for_delivery"), dbNoClaim(RIDER)).update(set("delivered")));
  // ── no step from the client either: advanceDeliveryStep is the only way ──
  await scenario("l07 accept → arrived_at_store", "deny", async () => o(await order("delivery_accepted")).update(set("arrived_at_store")));
  await scenario("l08 picked_up → out_for_delivery", "deny", async () => o(await order("picked_up")).update(set("out_for_delivery")));
  await scenario("l09 → cancelled", "deny", async () => o(await order("picked_up")).update(set("cancelled")));
  // ── unaffected ──
  await scenario("k01 same status value rewritten (no change) passes", "allow", async () => o(await order("picked_up")).update(set("picked_up")));
  await scenario("k02 a non-status field (deliveryIssue)", "allow", async () => o(await order("picked_up")).update({ deliveryIssue: "gate closed", updatedAt: serverTimestamp() }));
  await scenario("k03 another rider still cannot touch it", "deny", async () => o(await order("delivery_accepted"), db("delivery", OTHER)).update({ deliveryIssue: "x" }));
  await scenario("k04 admin can still set a status", "allow", async () => o(await order("out_for_delivery"), db("admin", "dlv3d-admin")).update(set("delivered")));

  await testEnv.cleanup();
  const failed = results.filter((r) => !r.pass).length;
  console.log(`\n${results.length - failed}/${results.length} passed`);
  if (failed) { console.log("PHASE DLV-3D rules: FAILED"); process.exit(1); }
  console.log("PHASE DLV-3D rules: ALL PASSED");
  process.exit(0);
}
main().catch((e) => { console.error(e); process.exit(1); });
