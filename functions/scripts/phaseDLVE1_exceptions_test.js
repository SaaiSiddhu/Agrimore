// Phase DLV-E1 — proof of delivery and delivery exceptions
// (functions/src/delivery/riderExceptions.ts) on the Firestore emulator;
// Storage is a fake lookup here (the rules suite covers the real bucket rules).
//
//  p — attachProofCore: only the assigned rider, only a delivered order,
//      only its own fixed object, image under the limit, within 24 h;
//      idempotent; a path never points at another order
//  e — reportExceptionCore: assigned rider, after pickup only, known reason,
//      idempotent per request id, one open exception per order, order marker
//      and timeline written, custody with the rider
//  u — updateExceptionCore: acknowledge once; resolve needs a disposition and
//      a written resolution; custody follows the disposition; the order's
//      marker is cleared; money fields untouched
//
// Run with: firebase emulators:exec --only firestore "node scripts/phaseDLVE1_exceptions_test.js"
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
const PROJECT = process.env.GCLOUD_PROJECT || "demo-dlve1-exceptions";
if (!PROJECT.startsWith("demo-")) { console.error("REFUSING: not a demo- project"); process.exit(2); }
const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: PROJECT });
const db = admin.firestore();
const { Timestamp } = require("firebase-admin/firestore");
const X = require("../lib/delivery/riderExceptions");

const results = [];
const record = (label, pass, detail) => { results.push(pass); console.log(`${pass ? "PASSED" : "FAILED"} — ${label}${pass ? "" : ` :: ${detail}`}`); };
const NOW = Date.UTC(2026, 8, 24, 12, 0, 0);
const get = async (p) => (await db.doc(p).get()).data();
const photo = (over = {}) => async (path) => (path in over ? over[path] : { size: 150000, contentType: "image/jpeg" });

async function main() {
  console.log("=== PHASE DLV-E1 — proof and exceptions ===");
  await db.doc("orders/p1").set({ deliveryPartnerId: "r1", orderStatus: "delivered", status: "delivered", deliveredAt: Timestamp.fromMillis(NOW - 60000), total: 300 });
  await db.doc("orders/p-active").set({ deliveryPartnerId: "r1", orderStatus: "out_for_delivery" });
  await db.doc("orders/p-old").set({ deliveryPartnerId: "r1", orderStatus: "delivered", deliveredAt: Timestamp.fromMillis(NOW - 2 * 86400000) });

  // ── proof ──
  let v = await X.attachProofCore(db, "r2", "p1", photo(), NOW);
  record("p01_other_rider_refused", v.reason === "not_assigned" && !(await get("orders/p1")).deliveryProofPath, JSON.stringify(v));
  v = await X.attachProofCore(db, "r1", "p-active", photo(), NOW);
  record("p02_not_yet_delivered_refused", v.reason === "not_delivered", JSON.stringify(v));
  v = await X.attachProofCore(db, "r1", "p1", photo({ "delivery_proofs/p1_proof": null }), NOW);
  record("p03_no_photo_refused", v.reason === "no_photo", JSON.stringify(v));
  v = await X.attachProofCore(db, "r1", "p1", photo({ "delivery_proofs/p1_proof": { size: 900, contentType: "text/html" } }), NOW);
  record("p04_non_image_refused", v.reason === "not_image", JSON.stringify(v));
  v = await X.attachProofCore(db, "r1", "p-old", photo(), NOW);
  record("p05_after_24h_refused", v.reason === "too_late", JSON.stringify(v));
  const seen = [];
  v = await X.attachProofCore(db, "r1", "p1", async (path) => { seen.push(path); return { size: 150000, contentType: "image/jpeg" }; }, NOW);
  const p1 = await get("orders/p1");
  record("p06_attached_as_own_fixed_path", v.kind === "attached" && p1.deliveryProofPath === "delivery_proofs/p1_proof" &&
    seen.join() === "delivery_proofs/p1_proof" && p1.deliveryProofAttachedBy === "r1" && p1.total === 300, JSON.stringify(p1));
  v = await X.attachProofCore(db, "r1", "p1", photo(), NOW + 5000);
  record("p07_retry_is_already", v.kind === "already", JSON.stringify(v));

  // ── exceptions ──
  await db.doc("orders/e1").set({ deliveryPartnerId: "r1", orderStatus: "out_for_delivery", status: "out_for_delivery", userId: "c1", sellerId: "s1", paymentMethod: "cod", total: 450, orderNumber: "AGR-1" });
  await db.doc("orders/e-before").set({ deliveryPartnerId: "r1", orderStatus: "delivery_accepted" });
  let r = await X.reportExceptionCore(db, "r1", { orderId: "e-before", requestId: "req-00000001", reason: "customer_unreachable" }, NOW);
  record("e01_before_pickup_refused", r.reason === "not_after_pickup", JSON.stringify(r));
  r = await X.reportExceptionCore(db, "r2", { orderId: "e1", requestId: "req-00000002", reason: "customer_unreachable" }, NOW);
  record("e02_unassigned_rider_refused", r.reason === "not_assigned", JSON.stringify(r));
  r = await X.reportExceptionCore(db, "r1", { orderId: "e1", requestId: "req-00000003", reason: "made_up" }, NOW);
  record("e03_unknown_reason_refused", r.reason === "bad_request", JSON.stringify(r));
  r = await X.reportExceptionCore(db, "r1", { orderId: "e1", requestId: "req-00000004", reason: "damaged_goods", note: "Box crushed", lat: 9.93, lng: 78.12, accuracy: 10, isMocked: false }, NOW);
  const ex = await get(`delivery_exceptions/${r.exceptionId}`);
  const o1 = await get("orders/e1");
  const tl = await db.collection("orders/e1/timeline").get();
  record("e04_reported_with_custody_marker_and_timeline", r.kind === "reported" && ex.custody === "rider" && ex.status === "reported" &&
    ex.location.lat === 9.93 && o1.openDeliveryException.id === r.exceptionId && o1.orderStatus === "out_for_delivery" &&
    o1.total === 450 && tl.docs.some((d) => d.data().status === "delivery_problem"), JSON.stringify({ ex, o1 }));
  const again = await X.reportExceptionCore(db, "r1", { orderId: "e1", requestId: "req-00000004", reason: "damaged_goods" }, NOW + 1000);
  record("e05_same_request_is_already", again.kind === "already" && again.exceptionId === r.exceptionId, JSON.stringify(again));
  const second = await X.reportExceptionCore(db, "r1", { orderId: "e1", requestId: "req-00000005", reason: "safety" }, NOW + 2000);
  record("e06_one_open_exception_per_order", second.reason === "open_exception", JSON.stringify(second));

  // ── admin ──
  let u = await X.updateExceptionCore(db, "a1", r.exceptionId, "acknowledge", null, null, NOW + 3000);
  const u2 = await X.updateExceptionCore(db, "a2", r.exceptionId, "acknowledge", null, null, NOW + 4000);
  record("u01_acknowledge_once", u.kind === "updated" && u2.kind === "unchanged" && (await get(`delivery_exceptions/${r.exceptionId}`)).acknowledgedBy === "a1", JSON.stringify(u2));
  u = await X.updateExceptionCore(db, "a1", r.exceptionId, "resolve", "refund_customer", "done", NOW + 5000);
  record("u02_unknown_disposition_refused", u.reason === "bad_request", JSON.stringify(u));
  u = await X.updateExceptionCore(db, "a1", r.exceptionId, "resolve", "returned_to_seller", "ok", NOW + 5000);
  record("u03_resolution_text_required", u.reason === "resolution_required", JSON.stringify(u));
  u = await X.updateExceptionCore(db, "a1", r.exceptionId, "resolve", "returned_to_seller", "Seller received the box back.", NOW + 6000);
  const exR = await get(`delivery_exceptions/${r.exceptionId}`);
  const o1b = await get("orders/e1");
  record("u04_resolved_custody_seller_marker_cleared_money_untouched", u.kind === "updated" && exR.custody === "seller" &&
    exR.disposition === "returned_to_seller" && o1b.openDeliveryException === undefined &&
    o1b.lastDeliveryException.disposition === "returned_to_seller" && o1b.total === 450 && o1b.paymentMethod === "cod" &&
    o1b.orderStatus === "out_for_delivery", JSON.stringify({ exR, o1b }));
  u = await X.updateExceptionCore(db, "a2", r.exceptionId, "resolve", "reattempt", "Again", NOW + 7000);
  record("u05_resolved_stays_resolved", u.reason === "already_resolved", JSON.stringify(u));
  const next = await X.reportExceptionCore(db, "r1", { orderId: "e1", requestId: "req-00000006", reason: "customer_refused" }, NOW + 8000);
  record("u06_after_resolution_a_new_report_is_allowed", next.kind === "reported", JSON.stringify(next));

  const failed = results.filter((x) => !x).length;
  console.log(`\n${results.length - failed}/${results.length} passed`);
  if (failed) { console.log("PHASE DLV-E1: FAILED"); process.exit(1); }
  console.log("PHASE DLV-E1: ALL PASSED"); process.exit(0);
}
main().catch((e) => { console.error(e); process.exit(1); });
