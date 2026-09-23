// ============================================================
//  Phase SELLER-HOME-1a — seller_stats_daily rollup
// ============================================================
//
// Run with: JAVA_HOME=/opt/homebrew/opt/openjdk@21 firebase emulators:exec
//             --only firestore "node scripts/phaseSHOME1_stats_test.js"

process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });
const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { istDay, contributionOf, applyOrderContribution, rebuildMySellerStats } = require("../lib/seller/sellerStats");

const rebuild = test.wrap(rebuildMySellerStats);
const TS = (iso) => admin.firestore.Timestamp.fromDate(new Date(iso));
const S = "shome1-seller";

async function main() {
  const db = admin.firestore();
  const results = {};
  const check = async (name, fn) => {
    try { await fn(); results[name] = "PASSED"; } catch (e) { results[name] = `FAILED — ${e.message}`; }
    console.log(`${name}: ${results[name]}`);
  };
  const expect = (cond, msg) => { if (!cond) throw new Error(msg); };
  const day = async (d) => (await db.collection("seller_stats_daily").doc(`${S}_${d}`).get()).data() || {};
  const order = (over = {}) => ({
    sellerId: S, total: 500, orderStatus: "pending", createdAt: TS("2026-09-22T10:00:00Z"),
    items: [{ quantity: 2 }, { quantity: 3 }], ...over,
  });

  await check("t1_ist_day_boundaries", async () => {
    // 18:29:59Z = 23:59:59 IST same day; 18:30Z = next IST day.
    expect(istDay(Date.parse("2026-09-22T18:29:59Z")) === "20260922", istDay(Date.parse("2026-09-22T18:29:59Z")));
    expect(istDay(Date.parse("2026-09-22T18:30:00Z")) === "20260923", "18:30Z should be the next IST day");
    expect(istDay(Date.parse("2026-12-31T18:30:00Z")) === "20270101", "new year boundary");
  });

  await check("t2_contribution_shapes", async () => {
    const c = contributionOf(order());
    expect(c.gross === 500 && c.units === 5 && c.orders === 1 && c.delivered === 0, JSON.stringify(c));
    const x = contributionOf(order({ orderStatus: "Cancelled" }));
    expect(x.gross === 0 && x.units === 0 && x.cancelled === 1, JSON.stringify(x));
    const b = contributionOf(order({ rfqId: "r1", orderStatus: "delivered" }));
    expect(b.b2bGross === 500 && b.delivered === 1, JSON.stringify(b));
    expect(contributionOf({ total: 5 }) === null, "no seller → null");
    expect(contributionOf(order({ total: -9 })).gross === 0, "negative total ignored");
  });

  await check("t3_create_applies_once_even_on_retry", async () => {
    await applyOrderContribution(db, "shome1-o1", order());
    await applyOrderContribution(db, "shome1-o1", order()); // retried event
    const d = await day("20260922");
    expect(d.orders === 1 && d.gross === 500 && d.units === 5, JSON.stringify(d));
  });

  await check("t4_second_order_same_day_adds", async () => {
    await applyOrderContribution(db, "shome1-o2", order({ total: 250, items: [{ quantity: 1 }] }));
    const d = await day("20260922");
    expect(d.orders === 2 && d.gross === 750 && d.units === 6, JSON.stringify(d));
  });

  await check("t5_status_change_moves_counts", async () => {
    await applyOrderContribution(db, "shome1-o1", order({ orderStatus: "delivered" }));
    let d = await day("20260922");
    expect(d.delivered === 1 && d.gross === 750, JSON.stringify(d));
    await applyOrderContribution(db, "shome1-o2", order({ total: 250, items: [{ quantity: 1 }], orderStatus: "cancelled" }));
    d = await day("20260922");
    expect(d.orders === 2 && d.cancelled === 1 && d.gross === 500 && d.units === 5, JSON.stringify(d));
  });

  await check("t6_delete_removes_contribution", async () => {
    await applyOrderContribution(db, "shome1-o2", undefined);
    const d = await day("20260922");
    expect(d.orders === 1 && d.cancelled === 0 && d.gross === 500, JSON.stringify(d));
    expect(!(await db.collection("seller_stats_contrib").doc("shome1-o2").get()).exists, "marker left behind");
  });

  await check("t7_late_night_order_lands_on_next_ist_day", async () => {
    await applyOrderContribution(db, "shome1-o3", order({ createdAt: TS("2026-09-22T19:00:00Z"), total: 100 }));
    const d = await day("20260923");
    expect(d.orders === 1 && d.gross === 100, JSON.stringify(d));
  });

  await check("t8_rebuild_requires_approved_seller", async () => {
    let r;
    try { await rebuild({ data: {}, auth: { uid: "shome1-nobody", token: {} } }); r = "ok"; } catch (e) { r = e.code; }
    expect(r === "permission-denied", r);
  });

  await check("t9_rebuild_matches_recomputation_and_repairs_drift", async () => {
    await db.collection("sellers").doc(S).set({ status: "approved" });
    const fixtures = [
      ["shome1-r1", order({ total: 300, createdAt: TS("2026-09-20T05:00:00Z") })],
      ["shome1-r2", order({ total: 200, createdAt: TS("2026-09-20T20:00:00Z"), orderStatus: "delivered" })],
      ["shome1-r3", order({ total: 999, createdAt: TS("2026-09-20T06:00:00Z"), orderStatus: "rejected" })],
    ];
    for (const [id, o] of fixtures) await db.collection("orders").doc(id).set(o);
    // Earlier test orders exist only as markers/stats, not orders — the rebuild
    // must zero those days. Also corrupt one day to prove it is overwritten.
    await db.collection("seller_stats_daily").doc(`${S}_20260920`).set({ sellerId: S, day: "20260920", orders: 42, gross: 1 });
    const res = await rebuild({ data: {}, auth: { uid: S, token: {} } });
    expect(res.orders === 3, JSON.stringify(res));
    const d20 = await day("20260920");
    const d21 = await day("20260921");
    expect(d20.orders === 2 && d20.gross === 300 && d20.cancelled === 1, `20th ${JSON.stringify(d20)}`);
    expect(d21.orders === 1 && d21.gross === 200 && d21.delivered === 1, `21st (IST) ${JSON.stringify(d21)}`);
    const d22 = await day("20260922");
    expect(d22.orders === 0 && d22.gross === 0, `stale day not zeroed ${JSON.stringify(d22)}`);
  });

  await check("t10_rebuild_then_trigger_stays_consistent", async () => {
    // A later status change after rebuild applies only the difference.
    await applyOrderContribution(db, "shome1-r1", order({ total: 300, createdAt: TS("2026-09-20T05:00:00Z"), orderStatus: "cancelled" }));
    const d20 = await day("20260920");
    expect(d20.orders === 2 && d20.gross === 0 && d20.cancelled === 2, JSON.stringify(d20));
  });

  await check("t11_rebuild_cooldown", async () => {
    let r;
    try { await rebuild({ data: {}, auth: { uid: S, token: {} } }); r = "ok"; } catch (e) { r = e.code; }
    expect(r === "resource-exhausted", r);
  });

  console.log("\n=== PHASE SELLER-HOME-1a SUMMARY ===");
  const total = Object.keys(results).length;
  const passed = Object.values(results).filter((v) => v === "PASSED").length;
  for (const [k, v] of Object.entries(results)) console.log(`  ${v === "PASSED" ? "PASS" : "FAIL"}  ${k}`);
  console.log(`\n${passed}/${total} scenarios passed`);
  if (passed !== total) { console.error("PHASE SELLER-HOME-1a: FAILED"); process.exitCode = 1; }
  else console.log("PHASE SELLER-HOME-1a: ALL PASSED");
  test.cleanup();
}
main().catch((e) => { console.error("harness error", e); process.exit(1); });
