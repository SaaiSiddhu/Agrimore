// ============================================================
//  Phase SELLER-OPS-2 — weekly off days and holidays close checkout
// ============================================================
//
// Run with: JAVA_HOME=/opt/homebrew/opt/openjdk@21 firebase emulators:exec
//             --only firestore "node scripts/phaseSOPS2_store_schedule_test.js"

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
const { sellerClosedReason, istDay } = require("../lib/common/sellerAvailability");
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

  await check("a1_pure_indian_day_boundaries", async () => {
    // Wed 23 Sep 2026 23:00 IST = 17:30 UTC; Thu 24 Sep 00:30 IST = 19:00 UTC.
    const wed = Date.UTC(2026, 8, 23, 17, 30);
    const thu = Date.UTC(2026, 8, 23, 19, 0);
    expect(istDay(wed).weekday === 3 && istDay(wed).key === "2026-09-23", JSON.stringify(istDay(wed)));
    expect(istDay(thu).weekday === 4 && istDay(thu).key === "2026-09-24", JSON.stringify(istDay(thu)));
    expect(sellerClosedReason({ weeklyOff: [3] }, wed) === "weeklyOff", "wed off");
    expect(sellerClosedReason({ weeklyOff: [3] }, thu) === null, "thu open");
    expect(sellerClosedReason({ holidays: ["2026-09-24"] }, thu) === "holiday", "holiday");
    expect(sellerClosedReason({ weeklyOff: ["3", 10], holidays: [20260924] }, wed) === null, "malformed ignored");
    expect(sellerClosedReason({ acceptingOrders: false, weeklyOff: [3] }, wed) === "paused", "pause wins");
    expect(sellerClosedReason(undefined, wed) === null, "missing");
  });

  const now = Date.now();
  const today = istDay(now);
  const tomorrow = istDay(now + 86400e3);
  const U = "sops2-buyer";
  await db.doc(`users/${U}`).set({ uid: U, profileCompleted: true });
  const sellers = {
    "sops2-off": { weeklyOff: [today.weekday] },
    "sops2-hol": { holidays: [today.key] },
    "sops2-later": { weeklyOff: [tomorrow.weekday], holidays: [tomorrow.key] },
  };
  for (const [s, extra] of Object.entries(sellers)) {
    await db.doc(`sellers/${s}`).set({ status: "approved", shopName: `Shop ${s}`, ...extra });
    await db.doc(`products/${s}-p`).set({ name: s, salePrice: 100, stock: 50, sellerId: s, images: [], isB2BEnabled: false });
  }

  await check("a2_weekly_off_today_refused", async () => {
    const r = await call(order([{ productId: "sops2-off-p", quantity: 1 }]), U);
    expect(!r.ok && r.code === "failed-precondition" && /Shop sops2-off is closed today/.test(r.message), JSON.stringify(r));
  });

  await check("a3_holiday_today_refused_nothing_written", async () => {
    const before = (await db.collection("orders").where("userId", "==", U).get()).size;
    const r = await call(order([{ productId: "sops2-hol-p", quantity: 1 }]), U);
    expect(!r.ok && r.code === "failed-precondition", JSON.stringify(r));
    const after = (await db.collection("orders").where("userId", "==", U).get()).size;
    expect(after === before, `orders written: ${after - before}`);
  });

  await check("a4_off_tomorrow_still_open_today", async () => {
    const r = await call(order([{ productId: "sops2-later-p", quantity: 1 }]), U);
    expect(r.ok, JSON.stringify(r));
  });

  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
  const env = await initializeTestEnvironment({ projectId: "agrimore-66a4e", firestore: { rules, host: "127.0.0.1", port: 8080 } });
  try {
    await env.withSecurityRulesDisabled(async (ctx) => ctx.firestore().doc("sellers/r1").set({ status: "approved", shopName: "R" }));
    const me = env.authenticatedContext("r1").firestore().doc("sellers/r1");
    await check("b1_owner_sets_schedule", () => assertSucceeds(me.update({ weeklyOff: [7], holidays: ["2026-10-02"] })));
    await check("b2_owner_clears_schedule", () => assertSucceeds(me.update({ weeklyOff: [], holidays: [] })));
    await check("b3_bad_weekday_denied", () =>
      Promise.all([assertFails(me.update({ weeklyOff: [0] })), assertFails(me.update({ weeklyOff: [8] })), assertFails(me.update({ weeklyOff: "sun" }))]));
    await check("b4_too_many_holidays_denied", () =>
      assertFails(me.update({ holidays: Array.from({ length: 31 }, (_, i) => `2026-10-${String((i % 28) + 1).padStart(2, "0")}`) })));
    await check("b5_other_user_cannot_set_schedule", () =>
      assertFails(env.authenticatedContext("r2").firestore().doc("sellers/r1").update({ weeklyOff: [1] })));
  } finally {
    await env.cleanup();
  }

  console.log("\n=== PHASE SELLER-OPS-2 SUMMARY ===");
  const total = Object.keys(results).length;
  const passed = Object.values(results).filter((v) => v === "PASSED").length;
  for (const [k, v] of Object.entries(results)) console.log(`  ${v === "PASSED" ? "PASS" : "FAIL"}  ${k}`);
  console.log(`\n${passed}/${total} scenarios passed`);
  if (passed !== total) { console.error("PHASE SELLER-OPS-2: FAILED"); process.exitCode = 1; }
  else console.log("PHASE SELLER-OPS-2: ALL PASSED");
  test.cleanup();
}
main().catch((e) => { console.error("harness error", e); process.exit(1); });
