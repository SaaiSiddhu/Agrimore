// Phase ADMR-24 — adminUpdateOrderStatus (admin/adminOrderActions.ts)
// Extended by ADMR-25 (scenarios s11-s13) — the callable did not set
// refundStatus on a prepaid cancellation at all (stock/commission/credit
// reversal are unaffected generic triggers, but nothing ever flagged the
// order as needing a refund), and did not stamp cancelledBy/cancelledAt/
// cancellationReason the way sellerTransitionOrder.ts's own cancelling
// branch already does for every other actor.
//
// FINDING: admin's only order-status write path was a raw client Firestore
// update (OrderProvider.updateOrderStatus) with no server-side actor stamp,
// no audit record, no idempotency — and, separately, the widget calling it
// never checked the returned bool, so a genuine failure was reported to the
// admin as a green "Status updated successfully" toast (confirmed by
// reading order_status_updater.dart's own _updateStatus). This test
// exercises the REAL compiled functions/lib/admin/adminOrderActions.js's
// adminUpdateOrderStatus against the Firestore emulator — same in-process
// wrap-and-invoke pattern as phase63_retry_commission_exception_test.js.
//
// Run with:
//   firebase emulators:exec --only firestore,auth \
//     "node scripts/phase64_admin_order_status_command_test.js"
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: "agrimore-66a4e" });
const db = admin.firestore();

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { adminUpdateOrderStatus } = require("../lib/admin/adminOrderActions");
const wrapped = test.wrap(adminUpdateOrderStatus);

async function call(payload, auth) {
  try {
    return { ok: true, result: await wrapped({ data: payload, auth }) };
  } catch (e) {
    return { ok: false, code: e.code, message: e.message, details: e.details };
  }
}

const ADMIN_AUTH = { uid: "phase64-admin", token: { admin: true } };
const NON_ADMIN_AUTH = { uid: "phase64-not-admin", token: {} };
let rid = 0;
const nextRequestId = () => `phase64-req-${++rid}`;

async function seedOrder(id, orderStatus, extra) {
  await db.collection("orders").doc(id).set({ orderNumber: id, orderStatus, status: orderStatus, ...(extra || {}) });
}
async function orderDoc(id) {
  return (await db.collection("orders").doc(id).get()).data() || {};
}
async function timelineCount(orderId) {
  return (await db.collection("orders").doc(orderId).collection("timeline").get()).size;
}
async function actionDoc(orderId, requestId) {
  const snap = await db.collection("orders").doc(orderId).collection("adminActions").doc(requestId).get();
  return snap.exists ? snap.data() : null;
}

async function main() {
  const results = {};
  let allPassed = true;
  const record = (k, p, d) => { results[k] = p; console.log(`${k}: ${p ? "PASSED" : "FAILED"} — ${d}`); if (!p) allPassed = false; };

  console.log("=== PHASE ADMR-24 — adminUpdateOrderStatus ===");

  // 1 — non-admin cannot transition an order's status.
  {
    const oid = "phase64-o1";
    await seedOrder(oid, "pending");
    const r = await call({ orderId: oid, newStatus: "confirmed", requestId: nextRequestId() }, NON_ADMIN_AUTH);
    const o = await orderDoc(oid);
    record("s1_non_admin_denied", !r.ok && r.code === "permission-denied" && o.orderStatus === "pending",
      `code=${r.code} orderStatus=${o.orderStatus}(expect pending, unchanged)`);
  }

  // 2 — missing requestId is refused (idempotency key is mandatory, not optional).
  {
    const oid = "phase64-o2";
    await seedOrder(oid, "pending");
    const r = await call({ orderId: oid, newStatus: "confirmed" }, ADMIN_AUTH);
    record("s2_missing_requestId_refused", !r.ok && r.code === "invalid-argument", `code=${r.code}`);
  }

  // 3 — an unknown status string is refused as validation_failed (a typed
  // result, not a thrown error — the client can render it inline).
  {
    const oid = "phase64-o3";
    await seedOrder(oid, "pending");
    const r = await call({ orderId: oid, newStatus: "not_a_real_status", requestId: nextRequestId() }, ADMIN_AUTH);
    const o = await orderDoc(oid);
    record("s3_invalid_status_is_validation_failed",
      r.ok && r.result.outcome === "validation_failed" && o.orderStatus === "pending",
      `ok=${r.ok} outcome=${r.result?.outcome} orderStatus=${o.orderStatus}(expect pending, unchanged)`);
  }

  // 4 — a non-existent order is refused as not_found, not a crash.
  {
    const r = await call({ orderId: "phase64-does-not-exist", newStatus: "confirmed", requestId: nextRequestId() }, ADMIN_AUTH);
    record("s4_missing_order_is_not_found", r.ok && r.result.outcome === "not_found", `outcome=${r.result?.outcome}`);
  }

  // 5 — THE REAL TRANSITION: pending -> confirmed applies, stamps the
  // actor, and appends exactly one timeline entry.
  {
    const oid = "phase64-o5";
    await seedOrder(oid, "pending");
    const reqId = nextRequestId();
    const r = await call({ orderId: oid, newStatus: "confirmed", requestId: reqId }, ADMIN_AUTH);
    const o = await orderDoc(oid);
    const tl = await timelineCount(oid);
    const action = await actionDoc(oid, reqId);
    record("s5_real_transition_applies_and_records_actor",
      r.ok && r.result.outcome === "applied" && o.orderStatus === "confirmed" && o.status === "confirmed" &&
      tl === 1 && action?.adminUid === "phase64-admin" && action?.fromStatus === "pending" && action?.toStatus === "confirmed",
      `ok=${r.ok} outcome=${r.result?.outcome} orderStatus=${o.orderStatus}(expect confirmed) timelineCount=${tl}(expect 1) action=${JSON.stringify(action)}`);
  }

  // 6 — IDEMPOTENCY: replaying the SAME requestId does not duplicate the
  // timeline entry or move the status again.
  {
    const oid = "phase64-o6";
    await seedOrder(oid, "pending");
    const reqId = "phase64-req-idem";
    const first = await call({ orderId: oid, newStatus: "confirmed", requestId: reqId }, ADMIN_AUTH);
    const second = await call({ orderId: oid, newStatus: "confirmed", requestId: reqId }, ADMIN_AUTH);
    const tl = await timelineCount(oid);
    record("s6_replaying_same_requestId_is_idempotent",
      first.result?.outcome === "applied" && second.result?.outcome === "already_applied" && tl === 1,
      `first=${first.result?.outcome} second=${second.result?.outcome} timelineCount=${tl}(expect 1, not 2)`);
  }

  // 7 — a no-op transition (already at the requested status) is reported
  // as already_applied without a duplicate timeline entry.
  {
    const oid = "phase64-o7";
    await seedOrder(oid, "confirmed");
    const r = await call({ orderId: oid, newStatus: "confirmed", requestId: nextRequestId() }, ADMIN_AUTH);
    const tl = await timelineCount(oid);
    record("s7_noop_transition_is_already_applied_no_timeline",
      r.ok && r.result.outcome === "already_applied" && tl === 0,
      `outcome=${r.result?.outcome} timelineCount=${tl}(expect 0)`);
  }

  // 8 — THE DANGEROUS TRANSITION, server-enforced: leaving 'delivered'
  // WITHOUT a reason is refused — no longer only a client-side dialog that
  // any other caller of this same server command could bypass.
  {
    const oid = "phase64-o8";
    await seedOrder(oid, "delivered");
    const r = await call({ orderId: oid, newStatus: "cancelled", requestId: nextRequestId() }, ADMIN_AUTH);
    const o = await orderDoc(oid);
    record("s8_leaving_delivered_without_reason_refused",
      r.ok && r.result.outcome === "validation_failed" && /reason/i.test(r.result.message || "") && o.orderStatus === "delivered",
      `outcome=${r.result?.outcome} message=${r.result?.message} orderStatus=${o.orderStatus}(expect delivered, unchanged)`);
  }

  // 9 — the SAME dangerous transition WITH a reason is applied and the
  // reason is recorded on the timeline entry.
  {
    const oid = "phase64-o9";
    await seedOrder(oid, "delivered");
    const r = await call({ orderId: oid, newStatus: "cancelled", requestId: nextRequestId(), reason: "Customer requested return" }, ADMIN_AUTH);
    const o = await orderDoc(oid);
    const tlSnap = await db.collection("orders").doc(oid).collection("timeline").get();
    const entry = tlSnap.docs[0]?.data();
    record("s9_leaving_delivered_with_reason_applies_and_records_it",
      r.ok && r.result.outcome === "applied" && o.orderStatus === "cancelled" && entry?.reason === "Customer requested return",
      `outcome=${r.result?.outcome} orderStatus=${o.orderStatus}(expect cancelled) timelineReason=${entry?.reason}`);
  }

  // 10 — STALE STATE: caller's expectedCurrentStatus no longer matches the
  // real current status (another admin session changed it first) — refused
  // without mutating, rather than blindly overwriting.
  {
    const oid = "phase64-o10";
    await seedOrder(oid, "confirmed"); // real current status
    const r = await call({ orderId: oid, newStatus: "shipped", requestId: nextRequestId(), expectedCurrentStatus: "pending" }, ADMIN_AUTH);
    const o = await orderDoc(oid);
    record("s10_stale_expected_status_refused_no_mutation",
      r.ok && r.result.outcome === "stale_state" && o.orderStatus === "confirmed",
      `outcome=${r.result?.outcome} orderStatus=${o.orderStatus}(expect confirmed, unchanged)`);
  }

  // 11 — ADMR-25: cancelling a PREPAID, non-COD order sets refundStatus
  // and stamps the same cancellation shape sellerTransitionOrder.ts uses.
  {
    const oid = "phase64-o11";
    await seedOrder(oid, "delivered", { paymentStatus: "paid", paymentMethod: "razorpay" });
    const r = await call({ orderId: oid, newStatus: "cancelled", requestId: nextRequestId(), reason: "Customer requested return" }, ADMIN_AUTH);
    const o = await orderDoc(oid);
    record("s11_prepaid_cancel_sets_refund_pending_and_cancellation_fields",
      r.ok && r.result.outcome === "applied" && o.refundStatus === "pending" &&
      o.cancelledBy === "admin" && o.cancellationReason === "Customer requested return" && !!o.cancelledAt,
      `outcome=${r.result?.outcome} refundStatus=${o.refundStatus}(expect pending) cancelledBy=${o.cancelledBy} cancellationReason=${o.cancellationReason} cancelledAt=${o.cancelledAt ? "set" : "MISSING"}`);
  }

  // 12 — a COD order has nothing to refund — cancelling it stamps the same
  // audit fields but must NOT set refundStatus.
  {
    const oid = "phase64-o12";
    await seedOrder(oid, "delivered", { paymentStatus: "pending", paymentMethod: "cod" });
    const r = await call({ orderId: oid, newStatus: "cancelled", requestId: nextRequestId(), reason: "Damaged in transit" }, ADMIN_AUTH);
    const o = await orderDoc(oid);
    record("s12_cod_cancel_no_refund_status",
      r.ok && r.result.outcome === "applied" && o.refundStatus === undefined && o.cancelledBy === "admin",
      `outcome=${r.result?.outcome} refundStatus=${o.refundStatus}(expect undefined) cancelledBy=${o.cancelledBy}`);
  }

  // 13 — a prepaid order that was never actually confirmed paid
  // (paymentStatus not in the isPaid() set) also must NOT set refundStatus
  // — there is nothing captured to refund.
  {
    const oid = "phase64-o13";
    await seedOrder(oid, "confirmed", { paymentStatus: "created", paymentMethod: "razorpay" });
    const r = await call({ orderId: oid, newStatus: "cancelled", requestId: nextRequestId() }, ADMIN_AUTH);
    const o = await orderDoc(oid);
    record("s13_unpaid_prepaid_method_cancel_no_refund_status",
      r.ok && r.result.outcome === "applied" && o.refundStatus === undefined,
      `outcome=${r.result?.outcome} paymentStatus=created refundStatus=${o.refundStatus}(expect undefined)`);
  }

  // 14 — ADMR-26: 'cancelled' is terminal — no transition OUT of it is
  // allowed, even with a reason, even to a status that would otherwise be
  // perfectly ordinary.
  {
    const oid = "phase64-o14";
    await seedOrder(oid, "cancelled");
    const r = await call({ orderId: oid, newStatus: "confirmed", requestId: nextRequestId(), reason: "Customer changed their mind" }, ADMIN_AUTH);
    const o = await orderDoc(oid);
    record("s14_cancelled_is_terminal_no_transition_out",
      r.ok && r.result.outcome === "validation_failed" && /cancelled order/i.test(r.result.message || "") && o.orderStatus === "cancelled",
      `outcome=${r.result?.outcome} message=${r.result?.message} orderStatus=${o.orderStatus}(expect cancelled, unchanged)`);
  }

  // 15 — ADMR-26: a delivered order can ONLY leave to 'cancelled' — every
  // other target is refused, even with a reason supplied.
  {
    const oid = "phase64-o15";
    await seedOrder(oid, "delivered");
    const r = await call({ orderId: oid, newStatus: "processing", requestId: nextRequestId(), reason: "Reopening for re-packing" }, ADMIN_AUTH);
    const o = await orderDoc(oid);
    record("s15_delivered_can_only_leave_to_cancelled",
      r.ok && r.result.outcome === "validation_failed" && /only be moved to .cancelled./i.test(r.result.message || "") && o.orderStatus === "delivered",
      `outcome=${r.result?.outcome} message=${r.result?.message} orderStatus=${o.orderStatus}(expect delivered, unchanged)`);
  }

  console.log("\n=== SUMMARY ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}: ${v}`);
  console.log(allPassed ? "\nALL PASSED" : "\nSOME FAILED");
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL", e);
  process.exit(1);
});
