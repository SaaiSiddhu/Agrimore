// ============================================================
//  Phase SELLER-OPS-1 — a paused store takes no orders
// ============================================================
//
// Run with: JAVA_HOME=/opt/homebrew/opt/openjdk@21 firebase emulators:exec
//             --only firestore "node scripts/phaseSOPS1_accepting_orders_test.js"

process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const fs = require("fs");
const path = require("path");
const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: "agrimore-66a4e" });
const db = admin.firestore();
const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const { createOrder } = require("../lib/customer/createOrder");
const { isSellerPaused } = require("../lib/common/sellerAvailability");
const wrapped = test.wrap(createOrder);

const ADDRESS = {
  name: "Test User", phone: "9999999999", addressLine1: "1 Main St", addressLine2: "Near the market",
  city: "Chennai", state: "TN", zipcode: "600001", country: "India", latitude: 13.08, longitude: 80.27,
  addressType: "home", landmark: "Opposite the bank",
};
const order = (items) => ({
  items, orderMode: "B2C", deliveryAddress: ADDRESS, paymentMethod: "cod", deliveryCharge: 0, tax: 0,
  notes: "", deliverySlot: "morning", orderType: "One Time",
});
const TS = (ms) => admin.firestore.Timestamp.fromMillis(ms);

async function main() {
  const results = {};
  const check = async (name, fn) => {
    try { await fn(); results[name] = "PASSED"; } catch (e) { results[name] = `FAILED — ${e.message}`; }
    console.log(`${name}: ${results[name]}`);
  };
  const expect = (cond, msg) => { if (!cond) throw new Error(msg); };
  const call = async (payload, uid) => {
    try { return { ok: true, r: await wrapped({ data: payload, auth: { uid, token: {} } }) }; }
    catch (e) { return { ok: false, code: e.code, message: e.message }; }
  };

  const U = "sops1-buyer";
  await db.doc(`users/${U}`).set({ uid: U, profileCompleted: true });
  for (const [s, p] of [["sops1-open", "sops1-p1"], ["sops1-paused", "sops1-p2"], ["sops1-until", "sops1-p3"], ["sops1-legacy", "sops1-p4"]]) {
    await db.doc(`products/${p}`).set({ name: p, salePrice: 100, stock: 50, sellerId: s, images: [], isB2BEnabled: false });
  }
  await db.doc("sellers/sops1-open").set({ status: "approved", shopName: "Open", acceptingOrders: true });
  await db.doc("sellers/sops1-paused").set({ status: "approved", shopName: "Ravi Stores", acceptingOrders: false });
  await db.doc("sellers/sops1-until").set({ status: "approved", shopName: "Until", acceptingOrders: false, pausedUntil: TS(Date.now() - 60000) });
  await db.doc("sellers/sops1-legacy").set({ status: "approved", shopName: "Legacy" });

  await check("a1_pure_rules", async () => {
    const now = Date.now();
    expect(isSellerPaused({ acceptingOrders: false }, now) === true, "explicit pause");
    expect(isSellerPaused({ acceptingOrders: false, pausedUntil: TS(now + 3600e3) }, now) === true, "future resume");
    expect(isSellerPaused({ acceptingOrders: false, pausedUntil: TS(now - 1) }, now) === false, "past resume");
    expect(isSellerPaused({}, now) === false && isSellerPaused(undefined, now) === false, "missing = open");
  });

  await check("a2_open_seller_takes_orders", async () => {
    const r = await call(order([{ productId: "sops1-p1", quantity: 1 }]), U);
    expect(r.ok, JSON.stringify(r));
  });

  await check("a3_paused_seller_refused_with_its_name", async () => {
    const r = await call(order([{ productId: "sops1-p2", quantity: 1 }]), U);
    expect(!r.ok && r.code === "failed-precondition" && /Ravi Stores/.test(r.message), JSON.stringify(r));
  });

  await check("a4_mixed_cart_with_a_paused_seller_refused_and_nothing_written", async () => {
    const before = (await db.collection("orders").where("userId", "==", U).get()).size;
    const r = await call(order([{ productId: "sops1-p1", quantity: 1 }, { productId: "sops1-p2", quantity: 1 }]), U);
    expect(!r.ok && r.code === "failed-precondition", JSON.stringify(r));
    const after = (await db.collection("orders").where("userId", "==", U).get()).size;
    expect(after === before, `orders written: ${after - before}`);
  });

  await check("a5_pause_expired_resumes_automatically", async () => {
    const r = await call(order([{ productId: "sops1-p3", quantity: 1 }]), U);
    expect(r.ok, JSON.stringify(r));
  });

  await check("a6_legacy_seller_without_the_field_is_open", async () => {
    const r = await call(order([{ productId: "sops1-p4", quantity: 1 }]), U);
    expect(r.ok, JSON.stringify(r));
  });

  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
  const env = await initializeTestEnvironment({ projectId: "agrimore-66a4e", firestore: { rules, host: "127.0.0.1", port: 8080 } });
  try {
    await env.withSecurityRulesDisabled(async (ctx) => ctx.firestore().doc("sellers/r1").set({ status: "approved", shopName: "R" }));
    const me = env.authenticatedContext("r1").firestore().doc("sellers/r1");
    await check("b1_owner_pauses_until_a_date", () => assertSucceeds(me.update({ acceptingOrders: false, pausedUntil: new Date(Date.now() + 86400e3) })));
    await check("b2_owner_resumes", () => assertSucceeds(me.update({ acceptingOrders: true, pausedUntil: null })));
    await check("b3_bad_types_denied", () =>
      Promise.all([assertFails(me.update({ acceptingOrders: "no" })), assertFails(me.update({ pausedUntil: "tomorrow" }))]));
    await check("b4_other_user_cannot_pause_a_store", () =>
      assertFails(env.authenticatedContext("r2").firestore().doc("sellers/r1").update({ acceptingOrders: false })));
  } finally {
    await env.cleanup();
  }

  console.log("\n=== PHASE SELLER-OPS-1 SUMMARY ===");
  const total = Object.keys(results).length;
  const passed = Object.values(results).filter((v) => v === "PASSED").length;
  for (const [k, v] of Object.entries(results)) console.log(`  ${v === "PASSED" ? "PASS" : "FAIL"}  ${k}`);
  console.log(`\n${passed}/${total} scenarios passed`);
  if (passed !== total) { console.error("PHASE SELLER-OPS-1: FAILED"); process.exitCode = 1; }
  else console.log("PHASE SELLER-OPS-1: ALL PASSED");
  test.cleanup();
}
main().catch((e) => { console.error("harness error", e); process.exit(1); });
