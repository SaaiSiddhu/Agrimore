// Phase DLV-3A — firestore.rules for delivery_tasks/{orderId}/live/rider,
// the rider's live position for one delivery leg.
//
// Write: only the task's own rider (approved delivery partner), only while
// the leg is active (assigned … returning_to_seller), exact keys, bounded
// numbers, `at` = server time, `riderId` = the writer. Read: whoever may read
// the task — the rider, the customer, the seller, admin. Never deletable.
//
// Run with:
//   firebase emulators:exec --only firestore "node scripts/phaseDLV3A_live_rules_test.js"
// Honours FIRESTORE_EMULATOR_HOST (set by emulators:exec), falling back to 127.0.0.1:8080.
const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const { serverTimestamp, Timestamp } = require("firebase/firestore");

const [EMU_HOST, EMU_PORT] = (process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080").split(":");

const base = { admin: false, seller: false, delivery_partner: false, employee: false };
const CLAIMS = {
  user: { ...base, role: "user" },
  delivery: { ...base, role: "delivery_partner", delivery_partner: true },
  seller: { ...base, role: "seller", seller: true },
  admin: { ...base, role: "admin", admin: true },
};

const RIDER = "dlv3a-r-rider";
const OTHER_RIDER = "dlv3a-r-other-rider";
const CUSTOMER = "dlv3a-r-customer";
const OTHER_CUSTOMER = "dlv3a-r-other-customer";
const SELLER = "dlv3a-r-seller";
const ADMIN = "dlv3a-r-admin";

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
// Old-style claimless rider (no delivery_partner claim): isDeliveryPartner()
// falls back to users.role + delivery_partners.status.
const dbNoClaim = (uid) => testEnv.authenticatedContext(uid, { ...base, role: "delivery_partner" }).firestore();
const live = (d, task, doc = "rider") => d.collection("delivery_tasks").doc(task).collection("live").doc(doc);
const point = (uid, extra = {}) => ({
  riderId: uid, lat: 9.9252, lng: 78.1198, accuracy: 12.5, speed: 6.2, heading: 270, isMocked: false,
  at: serverTimestamp(), ...extra,
});

async function main() {
  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
  testEnv = await initializeTestEnvironment({
    projectId: "demo-dlv3a",
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
    await f.collection("users").doc("dlv3a-r-suspended").set({ role: "delivery_partner" });
    await f.collection("delivery_partners").doc("dlv3a-r-suspended").set({ status: "suspended" });
    const t = (id, status, riderId = RIDER) => f.collection("delivery_tasks").doc(id).set({
      orderId: id, status, riderId, customerId: CUSTOMER, sellerId: SELLER,
    });
    for (const s of ["assigned", "at_pickup", "picked_up", "en_route", "at_drop", "failed_attempt", "returning_to_seller"]) {
      await t(`t-${s}`, s);
    }
    for (const s of ["searching", "delivered", "returned", "cancelled"]) await t(`t-${s}`, s);
    await t("t-suspended", "en_route", "dlv3a-r-suspended");
    await f.collection("delivery_tasks").doc("t-en_route").collection("live").doc("rider").set({
      riderId: RIDER, lat: 9.9, lng: 78.1, at: Timestamp.now(),
    });
  });

  // --- the task's rider writes while the leg is active
  for (const s of ["assigned", "at_pickup", "picked_up", "en_route", "at_drop", "failed_attempt", "returning_to_seller"]) {
    await scenario(`l01_rider_writes_live_point_while_${s}`, "allow", () => live(db("delivery", RIDER), `t-${s}`).set(point(RIDER)));
  }
  await scenario("l02_rider_updates_existing_point", "allow",
    () => live(db("delivery", RIDER), "t-en_route").update({ lat: 9.93, lng: 78.12, at: serverTimestamp() }));
  await scenario("l03_minimal_point_without_optional_fields", "allow",
    () => live(db("delivery", RIDER), "t-assigned").set({ riderId: RIDER, lat: 1, lng: 2, at: serverTimestamp() }));
  await scenario("l04_null_optional_fields_allowed", "allow",
    () => live(db("delivery", RIDER), "t-assigned").set(point(RIDER, { accuracy: null, speed: null, heading: null })));
  await scenario("l05_claimless_approved_rider_allowed", "allow",
    () => live(dbNoClaim(RIDER), "t-en_route").set(point(RIDER)));

  // --- not while the leg is inactive
  for (const s of ["searching", "delivered", "returned", "cancelled"]) {
    await scenario(`l06_refused_when_task_${s}`, "deny", () => live(db("delivery", RIDER), `t-${s}`).set(point(RIDER)));
  }
  await scenario("l07_refused_when_task_missing", "deny", () => live(db("delivery", RIDER), "t-none").set(point(RIDER)));

  // --- only that rider
  await scenario("l08_other_rider_cannot_write", "deny", () => live(db("delivery", OTHER_RIDER), "t-en_route").set(point(OTHER_RIDER)));
  await scenario("l09_other_rider_cannot_forge_riderId", "deny", () => live(db("delivery", OTHER_RIDER), "t-en_route").set(point(RIDER)));
  await scenario("l10_rider_cannot_write_someone_elses_riderId", "deny", () => live(db("delivery", RIDER), "t-en_route").set(point(OTHER_RIDER)));
  await scenario("l11_customer_cannot_write", "deny", () => live(db("user", CUSTOMER), "t-en_route").set(point(CUSTOMER)));
  await scenario("l12_seller_cannot_write", "deny", () => live(db("seller", SELLER), "t-en_route").set(point(SELLER)));
  await scenario("l13_suspended_claimless_rider_cannot_write", "deny",
    () => live(dbNoClaim("dlv3a-r-suspended"), "t-suspended").set(point("dlv3a-r-suspended")));
  await scenario("l14_only_the_rider_doc", "deny", () => live(db("delivery", RIDER), "t-en_route", "other").set(point(RIDER)));

  // --- shape
  await scenario("l15_extra_key_refused", "deny", () => live(db("delivery", RIDER), "t-en_route").set(point(RIDER, { note: "x" })));
  await scenario("l16_client_time_refused", "deny", () => live(db("delivery", RIDER), "t-en_route").set(point(RIDER, { at: Timestamp.now() })));
  await scenario("l17_lat_out_of_range", "deny", () => live(db("delivery", RIDER), "t-en_route").set(point(RIDER, { lat: 91 })));
  await scenario("l18_lng_out_of_range", "deny", () => live(db("delivery", RIDER), "t-en_route").set(point(RIDER, { lng: -181 })));
  await scenario("l19_lat_as_string", "deny", () => live(db("delivery", RIDER), "t-en_route").set(point(RIDER, { lat: "9.9" })));
  await scenario("l20_missing_lng", "deny", () => {
    const p = point(RIDER); delete p.lng; return live(db("delivery", RIDER), "t-en_route").set(p);
  });
  await scenario("l21_speed_out_of_range", "deny", () => live(db("delivery", RIDER), "t-en_route").set(point(RIDER, { speed: 500 })));
  await scenario("l22_heading_out_of_range", "deny", () => live(db("delivery", RIDER), "t-en_route").set(point(RIDER, { heading: 400 })));
  await scenario("l23_isMocked_not_bool", "deny", () => live(db("delivery", RIDER), "t-en_route").set(point(RIDER, { isMocked: "no" })));
  await scenario("l24_update_that_drops_riderId", "deny",
    () => live(db("delivery", RIDER), "t-en_route").set({ lat: 1, lng: 2, at: serverTimestamp() }));
  await scenario("l25_nobody_deletes", "deny", () => live(db("delivery", RIDER), "t-en_route").delete());
  await scenario("l26_admin_client_cannot_write", "deny", () => live(db("admin", ADMIN), "t-en_route").set(point(ADMIN)));

  // --- read
  await scenario("l27_customer_reads", "allow", () => live(db("user", CUSTOMER), "t-en_route").get());
  await scenario("l28_seller_reads", "allow", () => live(db("seller", SELLER), "t-en_route").get());
  await scenario("l29_rider_reads", "allow", () => live(db("delivery", RIDER), "t-en_route").get());
  await scenario("l30_admin_reads", "allow", () => live(db("admin", ADMIN), "t-en_route").get());
  await scenario("l31_other_customer_cannot_read", "deny", () => live(db("user", OTHER_CUSTOMER), "t-en_route").get());
  await scenario("l32_other_rider_cannot_read", "deny", () => live(db("delivery", OTHER_RIDER), "t-en_route").get());
  await scenario("l33_unauthenticated_cannot_read", "deny", () => live(testEnv.unauthenticatedContext().firestore(), "t-en_route").get());
  // The parent task stays server-only (DLV-1A r13).
  await scenario("l34_task_itself_still_not_writable_by_rider", "deny",
    () => db("delivery", RIDER).collection("delivery_tasks").doc("t-en_route").update({ status: "delivered" }));

  await testEnv.clearFirestore();
  await testEnv.cleanup();
  const failed = results.filter((r) => !r.pass);
  console.log(`\n${results.length - failed.length}/${results.length} passed`);
  if (failed.length) { console.log("PHASE DLV-3A live rules: FAILED"); process.exit(1); }
  console.log("PHASE DLV-3A live rules: ALL PASSED");
}

main().catch(async (e) => { console.error(e); try { await testEnv?.cleanup(); } catch (_) { /* ignore */ } process.exit(1); });
