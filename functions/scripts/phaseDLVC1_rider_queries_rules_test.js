// ============================================================
//  Phase DLV-C1 — the rider app's own queries against firestore.rules
// ============================================================
// The rider app (apps/delivery, DLV-C1) reads:
//   q1 active work:  orders where deliveryPartnerId == me AND orderStatus in
//                    riderActiveOrderStatuses, limit 10
//   q2 today:        orders where deliveryPartnerId == me AND deliveredAt >= midnight
//                    (sent as count(); an aggregation is allowed exactly when
//                    the same list query is)
//   q3 history:      orders where deliveryPartnerId == me orderBy createdAt desc,
//                    limit 21, then startAfter the last row
//   t1 token:        users/{me}: arrayRemove this device's token, delete fcmToken
// A query is allowed only if the rules can prove every result is readable, so
// each is run as the rider (claim), as another rider, as a suspended rider
// and signed out.
//
// Run with: JAVA_HOME=/opt/homebrew/opt/openjdk@21 firebase emulators:exec
//             --only firestore "node scripts/phaseDLVC1_rider_queries_rules_test.js"
// Honours FIRESTORE_EMULATOR_HOST.
const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const { collection, query, where, and, or, orderBy, getDocs, getCountFromServer } = require("firebase/firestore");

const ACTIVE = JSON.parse(fs.readFileSync(path.join(__dirname, "..", "..", "packages", "agrimore_core", "test",
  "fixtures", "delivery_status_table.json"), "utf8")).riderActiveOrderStatuses;

async function main() {
  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
  const [host, port] = (process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080").split(":");
  const testEnv = await initializeTestEnvironment({
    projectId: "demo-dlvc1-rider-queries",
    firestore: { rules, host, port: Number(port) },
  });
  const results = {};
  const record = (k, p) => p.then(
    () => { results[k] = "PASSED"; console.log(`${k}: PASSED`); },
    (e) => { results[k] = `FAILED — ${e.message}`; console.log(`${k}: FAILED — ${e.message}`); }
  );
  const midnight = new Date(Date.UTC(2026, 8, 23, 18, 30));
  try {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await db.doc("users/r1").set({ role: "delivery_partner", fcmTokens: ["T1", "T9"], fcmToken: "T1" });
      await db.doc("users/r2").set({ role: "delivery_partner", fcmTokens: ["T2"], fcmToken: "T2" });
      await db.doc("users/r3").set({ role: "delivery_partner" });
      await db.doc("delivery_partners/r1").set({ status: "approved" });
      await db.doc("delivery_partners/r2").set({ status: "approved" });
      await db.doc("delivery_partners/r3").set({ status: "suspended" });
      for (let i = 0; i < 25; i++) {
        await db.doc(`orders/h${String(i).padStart(2, "0")}`).set({
          userId: "c1", deliveryPartnerId: "r1", orderStatus: i === 0 ? "picked_up" : "delivered",
          createdAt: new Date(Date.UTC(2026, 8, 1 + i)), deliveredAt: i === 0 ? null : new Date(Date.UTC(2026, 8, 1 + i, 12)),
        });
      }
      await db.doc("orders/other").set({ userId: "c2", deliveryPartnerId: "r2", orderStatus: "picked_up", createdAt: new Date() });
    });
    // r1/r2 carry the claim roleClaims.ts grants to approved riders; r3 (suspended) has none.
    const r1 = testEnv.authenticatedContext("r1", { delivery_partner: true }).firestore();
    const r2 = testEnv.authenticatedContext("r2", { delivery_partner: true }).firestore();
    const r3 = testEnv.authenticatedContext("r3", {}).firestore();
    const anon = testEnv.unauthenticatedContext().firestore();
    const q1 = (db, uid) => db.collection("orders").where("deliveryPartnerId", "==", uid).where("orderStatus", "in", ACTIVE).limit(10).get();
    const q2 = (db, uid) => db.collection("orders").where("deliveryPartnerId", "==", uid).where("deliveredAt", ">=", midnight).get();
    const q3 = (db, uid) => db.collection("orders").where("deliveryPartnerId", "==", uid).orderBy("createdAt", "desc").limit(21).get();

    await record("q1_rider_active_query_allowed", assertSucceeds(q1(r1, "r1")).then(async () => {
      const s = await q1(r1, "r1");
      if (s.size !== 1 || s.docs[0].id !== "h00") throw new Error(`got ${s.docs.map((d) => d.id)}`);
    }));
    await record("q1_other_riders_orders_refused", assertFails(q1(r1, "r2")));
    await record("q1_suspended_rider_refused", assertFails(q1(r3, "r3")));
    await record("q1_signed_out_refused", assertFails(q1(anon, "r1")));
    await record("q2_today_query_allowed", assertSucceeds(q2(r1, "r1")));
    await record("q2_other_rider_refused", assertFails(q2(r2, "r1")));
    await record("q3_history_pages_continue_from_cursor", (async () => {
      const first = await assertSucceeds(q3(r1, "r1"));
      if (first.size !== 21) throw new Error(`first page ${first.size}`);
      const cursor = first.docs[19];
      const second = await assertSucceeds(r1.collection("orders").where("deliveryPartnerId", "==", "r1")
        .orderBy("createdAt", "desc").startAfter(cursor).limit(21).get());
      const ids = new Set(first.docs.slice(0, 20).map((d) => d.id));
      if (second.size !== 5 || second.docs.some((d) => ids.has(d.id))) throw new Error(`second page ${second.docs.map((d) => d.id)}`);
    })());
    await record("q3_other_rider_history_refused", assertFails(q3(r2, "r1")));
    // Match rider_history.dart's conditional AND/OR status + date-range builder,
    // rather than treating its simple owner-only history query as exhaustive.
    const filteredHistory = (db, uid) => query(collection(db, "orders"),
      and(where("deliveryPartnerId", "==", uid),
        or(where("orderStatus", "in", ["delivered", "completed", "Delivered", "Completed"]),
           where("status", "in", ["delivered", "completed", "Delivered", "Completed"])),
        where("createdAt", ">=", new Date(Date.UTC(2026, 8, 10))),
        where("createdAt", "<", new Date(Date.UTC(2026, 8, 20)))),
      orderBy("createdAt", "desc"));
    await record("q4_conditional_history_matches_owner_and_date_window", (async () => {
      const page = await assertSucceeds(getDocs(filteredHistory(r1, "r1")));
      if (page.size !== 10 || page.docs.some(d => d.data().deliveryPartnerId !== "r1"))
        throw new Error(`unexpected filtered page size ${page.size}`);
    })());
    await record("q4_conditional_history_other_owner_refused", assertFails(getDocs(filteredHistory(r2, "r1"))));
    await record("q4_conditional_history_signed_out_refused", assertFails(getDocs(filteredHistory(anon, "r1"))));
    await record("q4_conditional_history_suspended_refused", assertFails(getDocs(filteredHistory(r3, "r3"))));
    await record("q4_conditional_history_count_allowed", (async () => {
      const count = await assertSucceeds(getCountFromServer(filteredHistory(r1, "r1")));
      if (count.data().count !== 10) throw new Error(`unexpected filtered count ${count.data().count}`);
    })());
    const FV = require("firebase/compat/app").default.firestore.FieldValue;
    await record("t1_rider_removes_own_device_token",
      assertSucceeds(r1.doc("users/r1").update({ fcmTokens: FV.arrayRemove("T1"), fcmToken: FV.delete() })));
    await record("t1_other_user_cannot_touch_tokens",
      assertFails(r2.doc("users/r1").update({ fcmTokens: FV.arrayRemove("T9") })));
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const u = (await ctx.firestore().doc("users/r1").get()).data();
      results.t1_state = (JSON.stringify(u.fcmTokens) === JSON.stringify(["T9"]) && u.fcmToken === undefined) ? "PASSED" : `FAILED — ${JSON.stringify(u)}`;
      console.log(`t1_state_only_this_device_removed: ${results.t1_state}`);
    });

    const total = Object.keys(results).length;
    const passed = Object.values(results).filter((v) => v === "PASSED").length;
    console.log(`\n${passed}/${total} scenarios passed`);
    await testEnv.cleanup();
    if (passed !== total) { console.log("PHASE DLV-C1 rider queries: FAILED"); process.exit(1); }
    console.log("PHASE DLV-C1 rider queries: ALL PASSED");
    process.exit(0);
  } catch (e) {
    console.error(e);
    await testEnv.cleanup();
    process.exit(1);
  }
}
main();
