// ============================================================
//  Phase SELLER-ORDERS-1 — sellerTransitionOrder callable
// ============================================================
//
// Run with: JAVA_HOME=/opt/homebrew/opt/openjdk@21 firebase emulators:exec
//             --only firestore "node scripts/phaseSORD1_transition_test.js"

process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });
const db = admin.firestore();

const { sellerTransitionOrder, checkTransition, TRANSITIONS } = require("../lib/seller/sellerTransitionOrder");

const SELLER = { uid: "seller1", token: { seller: true, role: "seller" } };
const OTHER_SELLER = { uid: "seller2", token: { seller: true, role: "seller" } };
const CUSTOMER = { uid: "cust1", token: { role: "user" } };

async function call(auth, data) {
  try {
    return { ok: true, res: await sellerTransitionOrder.run({ auth, data }) };
  } catch (e) {
    return { ok: false, code: e.code, message: e.message };
  }
}

async function order(id, extra = {}) {
  await db.collection("orders").doc(id).set({
    userId: "cust1",
    sellerId: "seller1",
    orderNumber: `ORD-${id}`,
    orderStatus: "pending",
    status: "pending",
    paymentMethod: "cod",
    paymentStatus: "pending",
    items: [
      { productId: "pA", quantity: 2 },
      { productId: "pB", quantity: 1 },
      { productId: "pA", quantity: 1 },
    ],
    ...extra,
  });
}

async function product(id, stock) {
  await db.collection("products").doc(id).set(stock === undefined ? { name: id } : { name: id, stock });
}

async function stockOf(id) {
  return (await db.collection("products").doc(id).get()).data().stock;
}

async function main() {
  const results = {};
  const check = (k, ok, detail) => {
    results[k] = ok ? "PASSED" : `FAILED — ${detail}`;
    console.log(`${k}: ${ok ? "PASSED" : "FAILED"} — ${detail}`);
  };

  // ── pure transition table ────────────────────────────────────────────────
  check("t1_pending_accept_cod_ok", checkTransition("accept", "pending", { paymentMethod: "cod" }) === null, "");
  check("t2_accept_unpaid_online_blocked",
    checkTransition("accept", "pending", { paymentMethod: "razorpay", paymentStatus: "pending" })?.code === "failed-precondition", "");
  check("t3_accept_paid_online_ok",
    checkTransition("accept", "pending", { paymentMethod: "razorpay", paymentStatus: "paid" }) === null, "");
  check("t4_cannot_skip_to_ready", checkTransition("ready", "pending", {})?.code === "failed-precondition", "");
  check("t5_reject_needs_reason", checkTransition("reject", "pending", {}, undefined)?.code === "invalid-argument", "");
  check("t6_reject_with_reason_ok", checkTransition("reject", "pending", {}, "out_of_stock") === null, "");
  {
    const targets = Object.values(TRANSITIONS).map((t) => t.to);
    check("t7_no_seller_action_reaches_delivery_states",
      !targets.some((t) => ["delivered", "out_for_delivery", "picked_up", "completed"].includes(t)),
      JSON.stringify(targets));
  }
  check("t8_cannot_cancel_after_pickup", checkTransition("cancel", "ready_for_pickup", {}, "other")?.code === "failed-precondition", "");
  check("t9_unknown_action", checkTransition("deliver", "processing", {})?.code === "invalid-argument", "");

  // ── callable, end to end ─────────────────────────────────────────────────
  await product("pA", 10);
  await product("pB", 5);
  await product("pNoStock");

  {
    const r = await call(undefined, { orderId: "o1", action: "accept" });
    check("c1_unauthenticated", !r.ok && r.code === "unauthenticated", JSON.stringify(r));
  }
  {
    await order("o1");
    const r = await call(CUSTOMER, { orderId: "o1", action: "accept" });
    check("c2_non_seller_denied", !r.ok && r.code === "permission-denied", JSON.stringify(r));
  }
  {
    const r = await call(OTHER_SELLER, { orderId: "o1", action: "accept" });
    check("c3_other_sellers_order_denied", !r.ok && r.code === "permission-denied", JSON.stringify(r));
  }
  {
    const before = await stockOf("pA");
    const r = await call(SELLER, { orderId: "o1", action: "accept" });
    const o = (await db.collection("orders").doc("o1").get()).data();
    const after = await stockOf("pA");
    const tl = await db.collection("orders").doc("o1").collection("timeline").get();
    check("c4_accept_confirms_without_touching_stock",
      r.ok && o.orderStatus === "confirmed" && o.status === "confirmed" && o.sellerDecision === "accepted" &&
        before === after && tl.size === 1,
      `ok=${r.ok} status=${o.orderStatus} stock ${before}->${after} timeline=${tl.size}`);
  }
  {
    const r = await call(SELLER, { orderId: "o1", action: "accept" });
    check("c5_double_accept_rejected", !r.ok && r.code === "failed-precondition", JSON.stringify(r));
  }
  {
    const r1 = await call(SELLER, { orderId: "o1", action: "pack" });
    const r2 = await call(SELLER, { orderId: "o1", action: "ready" });
    const o = (await db.collection("orders").doc("o1").get()).data();
    check("c6_pack_then_ready", r1.ok && r2.ok && o.orderStatus === "ready_for_pickup" && o.readyForPickupAt,
      `status=${o.orderStatus}`);
  }
  {
    const r = await call(SELLER, { orderId: "o1", action: "cancel", reason: "other" });
    check("c7_cannot_cancel_once_ready", !r.ok && r.code === "failed-precondition", JSON.stringify(r));
  }
  {
    // Phase ADMR-1: sellerTransitionOrder no longer restores stock itself
    // — that invariant moved to restoreStockOnCancellation.ts (a generic
    // trigger, so it also covers the customer/admin cancellation paths
    // this callable never did), proven in phase57_stock_restoration_test.js.
    // This callable's own remaining contract is: transition to cancelled,
    // record provenance, leave stock and stockRestored strictly alone.
    await order("o2");
    const a = await stockOf("pA");
    const b = await stockOf("pB");
    const r = await call(SELLER, { orderId: "o2", action: "reject", reason: "out_of_stock", note: "Tomatoes finished" });
    const o = (await db.collection("orders").doc("o2").get()).data();
    check("c8_reject_records_cancellation_but_leaves_stock_to_the_trigger",
      r.ok && o.orderStatus === "cancelled" && o.cancelledBy === "seller" && o.cancellationReason === "out_of_stock" &&
        !o.stockRestored && (await stockOf("pA")) === a && (await stockOf("pB")) === b,
      `status=${o.orderStatus} stockRestored=${o.stockRestored} pA ${a}->${await stockOf("pA")} pB ${b}->${await stockOf("pB")}`);
    const again = await call(SELLER, { orderId: "o2", action: "cancel", reason: "other" });
    check("c9_cannot_cancel_an_already_cancelled_order", !again.ok && (await stockOf("pA")) === a, JSON.stringify(again));
  }
  {
    await order("o3", { paymentMethod: "razorpay", paymentStatus: "paid" });
    await call(SELLER, { orderId: "o3", action: "accept" });
    const r = await call(SELLER, { orderId: "o3", action: "cancel", reason: "shop_closed" });
    const o = (await db.collection("orders").doc("o3").get()).data();
    check("c10_prepaid_cancel_flags_refund", r.ok && o.refundStatus === "pending", `refund=${o.refundStatus}`);
  }
  {
    await order("o4", { paymentMethod: "razorpay", paymentStatus: "pending" });
    const r = await call(SELLER, { orderId: "o4", action: "accept" });
    check("c11_unpaid_online_cannot_be_accepted", !r.ok && r.code === "failed-precondition", JSON.stringify(r));
  }
  {
    await order("o5", { items: [{ productId: "pNoStock", quantity: 4 }] });
    const r = await call(SELLER, { orderId: "o5", action: "reject", reason: "other" });
    const p = (await db.collection("products").doc("pNoStock").get()).data();
    check("c12_untracked_stock_left_untouched", r.ok && p.stock === undefined, JSON.stringify(p));
  }
  {
    await order("o6");
    const r = await call(SELLER, { orderId: "o6", action: "reject" });
    check("c13_reject_without_reason_denied", !r.ok && r.code === "invalid-argument", JSON.stringify(r));
  }
  {
    const r = await call(SELLER, { orderId: "missing", action: "accept" });
    check("c14_missing_order", !r.ok && r.code === "not-found", JSON.stringify(r));
  }

  console.log("\n=== PHASE SELLER-ORDERS-1 (callable) SUMMARY ===");
  const total = Object.keys(results).length;
  const passed = Object.values(results).filter((v) => v === "PASSED").length;
  for (const [k, v] of Object.entries(results)) console.log(`  ${v === "PASSED" ? "PASS" : "FAIL"}  ${k}`);
  console.log(`\n${passed}/${total} scenarios passed`);
  if (passed !== total) { console.error("PHASE SELLER-ORDERS-1 (callable): FAILED"); process.exitCode = 1; }
  else console.log("PHASE SELLER-ORDERS-1 (callable): ALL PASSED");
}

main().catch((e) => { console.error("harness error", e); process.exit(1); });
