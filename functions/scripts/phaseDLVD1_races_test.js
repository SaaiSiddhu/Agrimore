// Phase DLV-D1 — dispatch and presence under real concurrency (Firestore
// emulator; core functions called concurrently with Promise.all).
//
//  a1 two riders accept ONE order at once, 5 rounds → exactly one winner
//  a2 one rider accepts TWO orders at once, 10 rounds → never both
//  a3 a rider who went offline after the offer cannot accept
//  a4 COD order, rider at the cash limit → refused; a5 prepaid still fine
//  a6 retry after a committed accept → alreadyAccepted, nothing doubled
//  a7 a stale reservation (its order delivered) does not block
//  s1 a fresh location arriving between the sweep's read and write keeps
//     the rider online
//  s2 more online riders than one page: a silent rider on a later page is
//     still swept
//
// Run with: firebase emulators:exec --only firestore "node scripts/phaseDLVD1_races_test.js"
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
const PROJECT = process.env.GCLOUD_PROJECT || "demo-dlvd1-races";
if (!PROJECT.startsWith("demo-")) { console.error("REFUSING: not a demo- project"); process.exit(2); }
const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: PROJECT });
const db = admin.firestore();
const { Timestamp } = require("firebase-admin/firestore");
const C = require("../lib/delivery/dispatchCallables");
const P = require("../lib/delivery/riderPresence");

const results = [];
const record = (label, pass, detail) => { results.push(pass); console.log(`${pass ? "PASSED" : "FAILED"} — ${label}${pass ? "" : ` :: ${detail}`}`); };
const NOW = Date.UTC(2026, 8, 24, 8, 0, 0);
const STORE = { lat: 9.9252, lng: 78.1198 };

async function rider(id, extra = {}) {
  await db.doc(`delivery_partners/${id}`).set({ name: id, status: "approved", isOnline: true,
    currentLat: STORE.lat, currentLng: STORE.lng, lastLocationUpdate: Timestamp.fromMillis(NOW), ...extra });
}
async function order(id, extra = {}) {
  await db.doc(`orders/${id}`).set({ orderStatus: "ready_for_pickup", status: "ready_for_pickup", userId: "c1",
    sellerId: "s1", pickupLat: STORE.lat, pickupLng: STORE.lng, paymentMethod: "upi", total: 200,
    deliveryAddress: { latitude: 9.93, longitude: 78.12 }, ...extra });
}
async function offer(orderId, riderId, extra = {}) {
  await db.doc(`delivery_requests/${orderId}_${riderId}`).set({ orderId, riderId, status: "offered",
    expiresAt: Timestamp.fromMillis(NOW + 30000), ...extra });
}
const ok = (v) => v.kind === "accepted" && !v.alreadyAccepted;

async function main() {
  console.log("=== PHASE DLV-D1 — races ===");
  // a1
  let a1ok = true; const a1d = [];
  for (let round = 0; round < 5; round++) {
    const o = `a1-${round}`;
    await order(o);
    for (const r of ["a1x", "a1y", "a1z"]) { await rider(`${r}${round}`); await offer(o, `${r}${round}`); }
    const vs = await Promise.all(["a1x", "a1y", "a1z"].map((r) => C.acceptOfferCore(db, `${r}${round}`, o, NOW)));
    const winners = vs.filter(ok).length;
    const assigned = (await db.doc(`orders/${o}`).get()).data().deliveryPartnerId;
    if (winners !== 1 || !assigned) { a1ok = false; a1d.push({ round, winners, assigned }); }
  }
  record("a1_one_order_one_winner", a1ok, JSON.stringify(a1d));

  // a2
  let a2ok = true; const a2d = [];
  for (let round = 0; round < 10; round++) {
    const r = `a2r${round}`;
    await rider(r);
    await order(`a2-${round}-A`); await order(`a2-${round}-B`);
    await offer(`a2-${round}-A`, r); await offer(`a2-${round}-B`, r);
    const vs = await Promise.all([C.acceptOfferCore(db, r, `a2-${round}-A`, NOW), C.acceptOfferCore(db, r, `a2-${round}-B`, NOW)]);
    const held = (await db.collection("orders").where("deliveryPartnerId", "==", r).get()).size;
    if (vs.filter(ok).length > 1 || held > 1) { a2ok = false; a2d.push({ round, held }); }
  }
  record("a2_one_rider_never_two_orders", a2ok, JSON.stringify(a2d));

  // a3
  await rider("a3r", { isOnline: false }); await order("a3"); await offer("a3", "a3r");
  let v = await C.acceptOfferCore(db, "a3r", "a3", NOW);
  record("a3_offline_rider_cannot_accept", v.kind === "refused" && !(await db.doc("orders/a3").get()).data().deliveryPartnerId, JSON.stringify(v));

  // a4 / a5 (default codCashLimit 2000)
  await rider("a4r"); await db.doc("rider_accounts/a4r").set({ riderId: "a4r", cashHeld: 2500 });
  await order("a4", { paymentMethod: "cod", total: 300 }); await offer("a4", "a4r");
  v = await C.acceptOfferCore(db, "a4r", "a4", NOW);
  record("a4_cod_refused_at_cash_limit", v.kind === "refused" && v.reason === "cash_limit", JSON.stringify(v));
  await order("a5", { paymentMethod: "upi", total: 300 }); await offer("a5", "a4r");
  v = await C.acceptOfferCore(db, "a4r", "a5", NOW);
  record("a5_prepaid_still_accepted_at_cash_limit", ok(v), JSON.stringify(v));

  // a6
  v = await C.acceptOfferCore(db, "a4r", "a5", NOW + 1000);
  const heldA5 = (await db.collection("orders").where("deliveryPartnerId", "==", "a4r").get()).size;
  record("a6_retry_after_commit_is_already_accepted", v.kind === "accepted" && v.alreadyAccepted === true && heldA5 === 1, JSON.stringify(v));

  // a7
  await order("a7-old", { orderStatus: "delivered", status: "delivered", deliveryPartnerId: "a7r" });
  await rider("a7r", { currentOrderId: "a7-old" }); await order("a7"); await offer("a7", "a7r");
  v = await C.acceptOfferCore(db, "a7r", "a7", NOW);
  record("a7_stale_reservation_does_not_block", ok(v), JSON.stringify(v));

  // s1 — a fresh location lands between the sweep's read and its write
  const OLD = Timestamp.fromMillis(NOW - 20 * 60000);
  await rider("s1r", { lastLocationUpdate: OLD, lastStatusUpdate: OLD });
  const off1 = await P.sweepSilentRiders(db, NOW, 400, {
    beforeWrite: () => db.doc("delivery_partners/s1r").update({ lastLocationUpdate: Timestamp.fromMillis(NOW) }),
  });
  record("s1_fresh_location_beats_the_sweep", !off1.includes("s1r") && (await db.doc("delivery_partners/s1r").get()).data().isOnline === true,
    JSON.stringify(off1));

  // s2 — 12 fresh riders + 1 silent that sorts last, page size 5
  for (let i = 0; i < 12; i++) await rider(`s2-a${String(i).padStart(2, "0")}`);
  await rider("s2-zz-silent", { lastLocationUpdate: OLD, lastStatusUpdate: OLD });
  const off2 = await P.sweepSilentRiders(db, NOW, 5);
  record("s2_silent_rider_on_a_later_page_is_swept", off2.includes("s2-zz-silent") &&
    (await db.doc("delivery_partners/s2-zz-silent").get()).data().isOnline === false, JSON.stringify(off2));

  const failed = results.filter((x) => !x).length;
  console.log(`\n${results.length - failed}/${results.length} passed`);
  if (failed) { console.log("PHASE DLV-D1 races: FAILED"); process.exit(1); }
  console.log("PHASE DLV-D1 races: ALL PASSED"); process.exit(0);
}
main().catch((e) => { console.error(e); process.exit(1); });
