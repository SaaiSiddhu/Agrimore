// Phase DLV-1A — syncDeliveryTask projects each order's rider leg into
// delivery_tasks/{orderId}.
//
// Drives the REAL trigger (v1 onUpdate, wrapped as wrapped(change, {params}))
// through an order's life against the Firestore emulator, reading back what it
// wrote. What this proves: the projection's status, riderId, points, COD,
// stepAt history, transition flag, PII absence and no-op skipping. What it
// does not prove: that the trigger is deployed, or anything a client does with
// delivery_tasks (none reads it yet — DLV-2/3).
//
// Run with:
//   firebase emulators:exec --only firestore "node scripts/phaseDLV1A_delivery_task_projection_test.js"
// Honours FIRESTORE_EMULATOR_HOST (set by emulators:exec), falling back to 127.0.0.1:8080.
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: "agrimore-66a4e" });
const db = admin.firestore();

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { syncDeliveryTask } = require("../lib/delivery/syncDeliveryTask");
const wrapped = test.wrap(syncDeliveryTask);

const RIDER = "dlv1a-rider";
const SELLER = "dlv1a-seller";
const CUSTOMER = "dlv1a-customer";

function baseOrder(extra = {}) {
  return {
    userId: CUSTOMER,
    sellerId: SELLER,
    orderNumber: "ORD-DLV1A",
    total: 450,
    paymentMethod: "cod",
    orderStatus: "processing",
    status: "processing",
    deliveryVerificationCode: "123456",
    deliveryAddress: {
      name: "Customer Name", phone: "9000000000", addressLine1: "12 Main St",
      city: "Madurai", pincode: "625001", latitude: 9.92, longitude: 78.12,
    },
    ...extra,
  };
}

// The trigger reads only change.after; `before` is passed for fidelity.
let previous = {};
async function update(orderId, after) {
  const before = test.firestore.makeDocumentSnapshot(previous[orderId] || after, `orders/${orderId}`);
  const afterSnap = test.firestore.makeDocumentSnapshot(after, `orders/${orderId}`);
  previous[orderId] = after;
  await wrapped(test.makeChange(before, afterSnap), { params: { orderId } });
}

const taskRef = (id) => db.collection("delivery_tasks").doc(id);
const task = async (id) => { const s = await taskRef(id).get(); return s.exists ? s.data() : null; };

const results = [];
function record(label, pass, detail) {
  results.push({ label, pass });
  console.log(`${pass ? "PASSED" : "FAILED"} — ${label}${pass ? "" : ` :: ${detail}`}`);
}

async function main() {
  console.log("=== PHASE DLV-1A — delivery_tasks projection ===");
  await db.collection("sellers").doc(SELLER).set({ storeLat: 9.95, storeLng: 78.15 });

  // ── One order's whole life ────────────────────────────────────────────
  const O = "dlv1a-life";

  // 1 — no rider leg yet: nothing written.
  await update(O, baseOrder());
  record("p01_processing_order_gets_no_task", (await task(O)) === null, "task exists");

  // 2 — ready for pickup: a searching task, points, COD, no PII.
  await update(O, baseOrder({ orderStatus: "ready_for_pickup", status: "ready_for_pickup" }));
  let t = await task(O);
  const keys = t ? Object.keys(t).sort() : [];
  const pii = keys.filter((k) => ["deliveryAddress", "name", "phone", "address", "deliveryVerificationCode", "customerName"].includes(k));
  record("p02_ready_for_pickup_creates_searching_task",
    t && t.status === "searching" && t.riderId === null && t.customerId === CUSTOMER && t.sellerId === SELLER &&
    t.stepAt && t.stepAt.searching && t.lastTransitionAllowed === true,
    JSON.stringify(t));
  record("p03_drop_is_coordinates_and_pincode_only",
    t && t.drop && t.drop.lat === 9.92 && t.drop.lng === 78.12 && t.drop.pincode === "625001" &&
    Object.keys(t.drop).length === 3 && pii.length === 0,
    `drop=${JSON.stringify(t && t.drop)} piiKeys=${pii} keys=${keys}`);
  record("p04_pickup_falls_back_to_the_sellers_store",
    t && t.pickup && t.pickup.lat === 9.95 && t.pickup.lng === 78.15, JSON.stringify(t && t.pickup));
  record("p05_cod_amount_is_the_order_total", t && t.codAmount === 450 && t.paymentMethod === "cod",
    `codAmount=${t && t.codAmount}`);
  const searchingAt = t.stepAt.searching.toMillis();

  // 3 — rider accepts.
  await update(O, baseOrder({ orderStatus: "delivery_accepted", status: "delivery_accepted", deliveryPartnerId: RIDER }));
  t = await task(O);
  record("p06_accept_moves_to_assigned_and_keeps_history",
    t.status === "assigned" && t.riderId === RIDER && t.stepAt.assigned &&
    t.stepAt.searching.toMillis() === searchingAt && t.lastTransitionAllowed === true,
    JSON.stringify({ status: t.status, riderId: t.riderId, steps: Object.keys(t.stepAt) }));

  // 4 — an unrelated order write is a no-op (no task write at all).
  const beforeNoop = (await taskRef(O).get()).updateTime.toMillis();
  await update(O, baseOrder({ orderStatus: "delivery_accepted", status: "delivery_accepted", deliveryPartnerId: RIDER, updatedAt: new Date(), notes: "ring bell" }));
  const afterNoop = (await taskRef(O).get()).updateTime.toMillis();
  record("p07_unrelated_order_change_does_not_rewrite_the_task", beforeNoop === afterNoop,
    `updateTime ${beforeNoop} -> ${afterNoop}`);

  // 5 — a legacy jump (assigned straight to out_for_delivery) is recorded and flagged.
  await update(O, baseOrder({ orderStatus: "out_for_delivery", status: "out_for_delivery", deliveryPartnerId: RIDER }));
  t = await task(O);
  record("p08_legacy_jump_recorded_but_flagged", t.status === "en_route" && t.lastTransitionAllowed === false,
    `status=${t.status} allowed=${t.lastTransitionAllowed}`);

  // 6 — delivered.
  await update(O, baseOrder({ orderStatus: "delivered", status: "delivered", deliveryPartnerId: RIDER }));
  t = await task(O);
  record("p09_delivered", t.status === "delivered" && t.stepAt.delivered && t.lastTransitionAllowed === true,
    `status=${t.status} allowed=${t.lastTransitionAllowed}`);

  // ── Single-case scenarios ─────────────────────────────────────────────

  // 7 — seller/admin panels write only `status`.
  {
    const id = "dlv1a-status-only";
    await update(id, baseOrder({ orderStatus: "arrived_at_store", status: "arrived_at_store", deliveryPartnerId: RIDER }));
    await update(id, baseOrder({ orderStatus: "arrived_at_store", status: "cancelled", deliveryPartnerId: RIDER }));
    const x = await task(id);
    record("p10_cancel_written_only_to_status_is_seen", x && x.status === "cancelled" && x.lastTransitionAllowed === true,
      JSON.stringify(x && { status: x.status, allowed: x.lastTransitionAllowed }));
  }

  // 8 — an order cancelled before it was ever ready never gets a task.
  {
    const id = "dlv1a-early-cancel";
    await update(id, baseOrder({ orderStatus: "cancelled", status: "cancelled" }));
    record("p11_order_cancelled_before_pickup_ready_gets_no_task", (await task(id)) === null, "task created");
  }

  // 9 — rider releases the order ("Seller Not Ready"): back to searching.
  {
    const id = "dlv1a-release";
    await update(id, baseOrder({ orderStatus: "delivery_accepted", status: "delivery_accepted", deliveryPartnerId: RIDER }));
    await update(id, baseOrder({ orderStatus: "ready_for_pickup", status: "ready_for_pickup" }));
    const x = await task(id);
    record("p12_release_returns_to_searching_with_no_rider",
      x && x.status === "searching" && x.riderId === null && x.lastTransitionAllowed === true && x.stepAt.assigned,
      JSON.stringify(x && { status: x.status, riderId: x.riderId, allowed: x.lastTransitionAllowed }));
  }

  // 10 — prepaid order: no cash to collect.
  {
    const id = "dlv1a-prepaid";
    await update(id, baseOrder({ paymentMethod: "razorpay", orderStatus: "ready_for_pickup", status: "ready_for_pickup" }));
    const x = await task(id);
    record("p13_prepaid_order_has_zero_cod", x && x.codAmount === 0, `codAmount=${x && x.codAmount}`);
  }

  // 11 — the order's own pickup point beats the seller's store.
  {
    const id = "dlv1a-order-pickup";
    await update(id, baseOrder({ pickupLat: 10.1, pickupLng: 77.9, orderStatus: "ready_for_pickup", status: "ready_for_pickup" }));
    const x = await task(id);
    record("p14_order_pickup_point_wins", x && x.pickup.lat === 10.1 && x.pickup.lng === 77.9, JSON.stringify(x && x.pickup));
  }

  // 12 — `shipped` without a rider is seller/courier fulfilment, not a rider leg.
  {
    const id = "dlv1a-shipped";
    await update(id, baseOrder({ orderStatus: "shipped", status: "shipped" }));
    record("p15_shipped_without_rider_gets_no_task", (await task(id)) === null, "task created");
  }

  // 13 — a drop point that loses its pincode loses it on the task too
  // (fields are replaced whole, not deep-merged), and the next identical
  // update is then a no-op again.
  {
    const id = "dlv1a-pincode";
    await update(id, baseOrder({ orderStatus: "ready_for_pickup", status: "ready_for_pickup" }));
    const noPin = baseOrder({ orderStatus: "ready_for_pickup", status: "ready_for_pickup" });
    delete noPin.deliveryAddress.pincode;
    await update(id, noPin);
    const x = await task(id);
    const t1 = (await taskRef(id).get()).updateTime.toMillis();
    await update(id, { ...noPin, notes: "unrelated" });
    const t2 = (await taskRef(id).get()).updateTime.toMillis();
    record("p16_removed_pincode_is_removed_and_then_stable",
      x && x.drop && x.drop.pincode === undefined && t1 === t2,
      `drop=${JSON.stringify(x && x.drop)} stable=${t1 === t2}`);
  }

  // 14 — the trigger never writes the order.
  {
    const id = "dlv1a-no-order-write";
    await db.collection("orders").doc(id).set({ marker: 1 });
    const before = (await db.collection("orders").doc(id).get()).updateTime.toMillis();
    await update(id, baseOrder({ orderStatus: "ready_for_pickup", status: "ready_for_pickup" }));
    const after = (await db.collection("orders").doc(id).get()).updateTime.toMillis();
    record("p17_trigger_never_writes_the_order", before === after && (await task(id)) !== null,
      `order updateTime ${before} -> ${after}`);
  }

  const failed = results.filter((r) => !r.pass);
  console.log(`\n${results.length - failed.length}/${results.length} passed`);
  test.cleanup();
  if (failed.length) { console.log("PHASE DLV-1A projection: FAILED"); process.exit(1); }
  console.log("PHASE DLV-1A projection: ALL PASSED");
  process.exit(0);
}

main().catch((e) => { console.error("PHASE DLV-1A projection: harness error", e); process.exit(1); });
