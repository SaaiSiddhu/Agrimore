// Phase DLV-3C — firestore.rules, the assigned rider's order-status writes
// (OWNER_DECISION D-DLV-RIDERALLOW, 2026-09-23).
//
// BEFORE (bab71df, demo-dlv3c-probe): the assigned rider could write any
// status — cancelled after pickup (productCreditReversal.ts then refunds the
// customer's product credit), or backwards. NOW: only a delivery step, never
// behind the current one, never on a finished order. Every write the RELEASED
// rider app (0ea1e53) makes must still pass — including the direct
// `delivered` (D-DLV-OTPLOCK keeps it until DLV-3D). The step evidence and
// flags written by the callables are not writable by any client.
// DLV-3D (release-gated): the a-series status writes are now DENIED — every
// step goes through the callables; see phaseDLV3D_status_lock_test.
//
// Run with:
//   firebase emulators:exec --only firestore "node scripts/phaseDLV3C_rider_rules_test.js"
// Honours FIRESTORE_EMULATOR_HOST (set by emulators:exec), falling back to 127.0.0.1:8080.
const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const { serverTimestamp, deleteField } = require("firebase/firestore");

const [EMU_HOST, EMU_PORT] = (process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080").split(":");

const base = { admin: false, seller: false, delivery_partner: false, employee: false };
const CLAIMS = {
  delivery: { ...base, role: "delivery_partner", delivery_partner: true },
  seller: { ...base, role: "seller", seller: true },
};
const RIDER = "dlv3c-r-rider";
const OTHER = "dlv3c-r-other";
const SELLER = "dlv3c-r-seller";
const CUSTOMER = "dlv3c-r-customer";

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
  const id = `dlv3c-o${++n}`;
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
    projectId: "demo-dlv3c",
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
  });
  const rider = db("delivery", RIDER);
  const o = (id, d = rider) => d.collection("orders").doc(id);

  console.log("=== PHASE DLV-3C — rider status rules ===");
  // ── what the released app did directly: DLV-3D denies every status write ──
  await scenario("a01 released app: accept → arrived_at_store", "deny", async () => o(await order("delivery_accepted")).update({ ...set("arrived_at_store"), arrivedAtStoreAt: serverTimestamp() }));
  await scenario("a02 released app: arrived → picked_up", "deny", async () => o(await order("arrived_at_store")).update({ ...set("picked_up"), pickedUpAt: serverTimestamp() }));
  await scenario("a03 released app: picked_up → out_for_delivery", "deny", async () => o(await order("picked_up")).update({ ...set("out_for_delivery"), outForDeliveryAt: serverTimestamp() }));
  await scenario("a04 released app: out_for_delivery → delivered (DLV-3D: the code bypass is closed)", "deny", async () => o(await order("out_for_delivery")).update({ ...set("delivered"), deliveredAt: serverTimestamp(), codSettlementStatus: "pending" }));
  await scenario("a05 admin-assigned order (still ready_for_pickup) → arrived_at_store", "deny", async () => o(await order("ready_for_pickup")).update(set("arrived_at_store")));
  await scenario("a06 claimless rider (users.role fallback) → picked_up", "deny", async () => o(await order("arrived_at_store"), dbNoClaim(RIDER)).update(set("picked_up")));
  await scenario("a07 same step again (a retry) is allowed", "allow", async () => o(await order("picked_up")).update(set("picked_up")));
  await scenario("a08 a write that does not touch the status (deliveryIssue) is unaffected", "allow", async () => o(await order("picked_up")).update({ deliveryIssue: "gate closed", updatedAt: serverTimestamp() }));
  await scenario("a09 released app's claim of an unassigned order still works", "allow", async () => o(await order("ready_for_pickup", { deliveryPartnerId: null })).update({ ...set("delivery_accepted"), deliveryPartnerId: RIDER, deliveryAcceptedAt: serverTimestamp() }));
  await scenario("a10 released app: skip ahead (accept → out_for_delivery) — only the callable moves steps", "deny", async () => o(await order("delivery_accepted")).update(set("out_for_delivery")));

  // ── the holes this phase closes ──
  await scenario("d01 picked_up → cancelled (the credit-refund hole)", "deny", async () => o(await order("picked_up")).update(set("cancelled")));
  await scenario("d02 delivery_accepted → cancelled", "deny", async () => o(await order("delivery_accepted")).update(set("cancelled")));
  await scenario("d03 out_for_delivery → delivery_accepted (backwards)", "deny", async () => o(await order("out_for_delivery")).update(set("delivery_accepted")));
  await scenario("d04 picked_up → arrived_at_store (backwards)", "deny", async () => o(await order("picked_up")).update(set("arrived_at_store")));
  await scenario("d05 cancelled order → delivered (payout on a cancelled order)", "deny", async () => o(await order("cancelled")).update(set("delivered")));
  await scenario("d06 delivered order → out_for_delivery", "deny", async () => o(await order("delivered")).update(set("out_for_delivery")));
  await scenario("d07 an arbitrary status (refunded / returned / garbage)", "deny", async () => o(await order("picked_up")).update(set("refunded")));
  await scenario("d08 only one field moved backwards (status alone)", "deny", async () => o(await order("out_for_delivery")).update({ status: "delivery_accepted" }));
  await scenario("d09 deleting orderStatus", "deny", async () => o(await order("picked_up")).update({ orderStatus: deleteField() }));
  await scenario("d10 rider back to ready_for_pickup (release must use the callable)", "deny", async () => o(await order("delivery_accepted")).update(set("ready_for_pickup")));
  await scenario("d11 another rider cannot touch the order at all", "deny", async () => o(await order("delivery_accepted"), db("delivery", OTHER)).update(set("arrived_at_store")));

  // ── server-written evidence is not client-writable ──
  await scenario("e01 rider clears deliveryFlags", "deny", async () => o(await order("picked_up", { deliveryFlags: [{ step: "picked_up" }], deliveryFlagged: true })).update({ deliveryFlags: [] }));
  await scenario("e02 rider sets deliveryFlagged=false", "deny", async () => o(await order("picked_up", { deliveryFlagged: true })).update({ deliveryFlagged: false }));
  await scenario("e03 rider forges deliveryStepChecks", "deny", async () => o(await order("picked_up")).update({ "deliveryStepChecks.picked_up": { distanceMeters: 0 } }));
  await scenario("e04 seller clears deliveryFlags", "deny", async () => o(await order("picked_up", { deliveryFlags: [{ step: "x" }] }), db("seller", SELLER)).update({ deliveryFlags: [] }));
  await scenario("e05 claiming rider pre-sets deliveryReleasedBy", "deny", async () => o(await order("ready_for_pickup", { deliveryPartnerId: null })).update({ ...set("delivery_accepted"), deliveryPartnerId: RIDER, deliveryReleasedBy: RIDER }));

  await testEnv.cleanup();
  const failed = results.filter((r) => !r.pass);
  console.log(`\n${results.length - failed.length}/${results.length} passed`);
  if (failed.length) { console.log("PHASE DLV-3C rider rules: FAILED"); process.exit(1); }
  console.log("PHASE DLV-3C rider rules: ALL PASSED");
  process.exit(0);
}
main().catch((e) => { console.error(e); process.exit(1); });
