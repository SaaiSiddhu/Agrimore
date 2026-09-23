// ============================================================
//  Phase SELLER-ACCOUNT-1b — notification preferences are honoured by senders
// ============================================================
//
// Run with: JAVA_HOME=/opt/homebrew/opt/openjdk@21 firebase emulators:exec
//             --only firestore "node scripts/phaseSACCT1B_prefs_test.js"
// Never seeds FCM tokens: with no messaging emulator a send would reach
// live FCM. Push suppression is proven at the decision point instead.

process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const fs = require("fs");
const path = require("path");
const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const { categoryOfType, istMinuteOfDay, pushAllowed, shouldPush } = require("../lib/common/notificationPrefs");
const { notifyUser } = require("../lib/customer/orderNotifications");

// 2026-09-23 10:00 IST = 04:30 UTC; 23:30 IST = 18:00 UTC.
const AT_10_IST = Date.UTC(2026, 8, 23, 4, 30);
const AT_2330_IST = Date.UTC(2026, 8, 23, 18, 0);

async function main() {
  const db = admin.firestore();
  const results = {};
  const check = async (name, fn) => {
    try { await fn(); results[name] = "PASSED"; } catch (e) { results[name] = `FAILED — ${e.message}`; }
    console.log(`${name}: ${results[name]}`);
  };
  const expect = (cond, msg) => { if (!cond) throw new Error(msg); };

  await check("p1_categories", async () => {
    const m = { seller_new_order: "orders", order_update: "orders", rfq_offer: "quotes", payout_paid: "payments",
      low_stock: "stock", review_reply: "reviews", admin_broadcast: "announcements" };
    for (const [t, c] of Object.entries(m)) expect(categoryOfType(t) === c, `${t} → ${categoryOfType(t)}`);
  });

  await check("p2_ist_minutes", async () => {
    expect(istMinuteOfDay(AT_10_IST) === 600, String(istMinuteOfDay(AT_10_IST)));
    expect(istMinuteOfDay(AT_2330_IST) === 1410, String(istMinuteOfDay(AT_2330_IST)));
  });

  await check("p3_no_prefs_allows_everything", async () => {
    expect(pushAllowed(undefined, "rfq_new", AT_10_IST) === true, "denied");
  });

  await check("p4_category_off_blocks_only_that_category", async () => {
    const prefs = { quotes: false };
    expect(pushAllowed(prefs, "rfq_new", AT_10_IST) === false, "quotes pushed");
    expect(pushAllowed(prefs, "seller_new_order", AT_10_IST) === true, "orders blocked");
  });

  await check("p5_quiet_hours_across_midnight", async () => {
    const prefs = { quietHours: true, quietStartMin: 22 * 60, quietEndMin: 7 * 60 };
    expect(pushAllowed(prefs, "seller_new_order", AT_2330_IST) === false, "pushed at 23:30");
    expect(pushAllowed(prefs, "seller_new_order", AT_10_IST) === true, "blocked at 10:00");
    expect(pushAllowed({ ...prefs, quietHours: false }, "seller_new_order", AT_2330_IST) === true, "switch ignored");
  });

  await check("p6_should_push_reads_the_stored_prefs", async () => {
    await db.doc("users/sacct1b-s/settings/notifications").set({ orders: false });
    expect((await shouldPush("sacct1b-s", "seller_new_order", AT_10_IST)) === false, "stored pref ignored");
    expect((await shouldPush("sacct1b-none", "seller_new_order", AT_10_IST)) === true, "missing prefs denied");
  });

  await check("p7_inbox_still_written_when_push_is_off", async () => {
    await db.doc("users/sacct1b-s").set({ role: "seller" }); // no fcmTokens
    const r = await notifyUser("sacct1b-s", "New order received", "Order 1", "seller_new_order", { orderId: "o1" }, "🛒");
    const inbox = await db.collection("users/sacct1b-s/notifications").where("type", "==", "seller_new_order").get();
    expect(inbox.size === 1 && r.successCount === 0, `inbox ${inbox.size} ${JSON.stringify(r)}`);
  });

  // Rules for the preferences document.
  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
  const env = await initializeTestEnvironment({ projectId: "agrimore-66a4e", firestore: { rules, host: "127.0.0.1", port: 8080 } });
  try {
    const me = env.authenticatedContext("u1").firestore().doc("users/u1/settings/notifications");
    const other = env.authenticatedContext("u2").firestore().doc("users/u1/settings/notifications");
    await check("r1_positive_owner_saves_prefs", () =>
      assertSucceeds(me.set({ orders: true, quotes: false, payments: true, stock: true, reviews: true, announcements: false,
        quietHours: true, quietStartMin: 1320, quietEndMin: 420, updatedAt: new Date() })));
    await check("r2_positive_owner_reads", () => assertSucceeds(me.get()));
    await check("r3_negative_other_user", () => Promise.all([assertFails(other.get()), assertFails(other.set({ orders: false }))]));
    await check("r4_negative_unknown_key", () => assertFails(me.set({ orders: true, isAdmin: true })));
    await check("r5_negative_bad_types", () =>
      Promise.all([assertFails(me.set({ orders: "no" })), assertFails(me.set({ quietStartMin: 2000 })), assertFails(me.set({ quietEndMin: -1 }))]));
  } finally {
    await env.cleanup();
  }

  console.log("\n=== PHASE SELLER-ACCOUNT-1b SUMMARY ===");
  const total = Object.keys(results).length;
  const passed = Object.values(results).filter((v) => v === "PASSED").length;
  for (const [k, v] of Object.entries(results)) console.log(`  ${v === "PASSED" ? "PASS" : "FAIL"}  ${k}`);
  console.log(`\n${passed}/${total} scenarios passed`);
  if (passed !== total) { console.error("PHASE SELLER-ACCOUNT-1b: FAILED"); process.exitCode = 1; }
  else console.log("PHASE SELLER-ACCOUNT-1b: ALL PASSED");
}
main().catch((e) => { console.error("harness error", e); process.exit(1); });
