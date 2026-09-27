// Phase ADMR-1 — restoreStockOnCancellation.ts's cancellation trigger.
//
// FINDING: sellerTransitionOrder.ts's own inline restoration only ever
// incremented the BASE `stock` field, never a variant's own stock inside
// product.variants[] — even though createOrder.ts decrements variant lines
// there specifically (SELLER-CATALOGUE-2). Worse, restoration lived ONLY
// inside that one callable's transaction, so the customer's own cancel path
// and apps/admin's direct orderStatus write — both real, both live, neither
// going through sellerTransitionOrder — never restored any stock at all,
// base or variant, ever.
//
// Invocation style: firebase-functions-test's OFFLINE-mode direct
// invocation — test.wrap(restoreStockOnCancellation) called as
// `wrapped(change, context)`, where `change` is built from
// test.firestore.makeDocumentSnapshot()/test.makeChange() — the exact
// pattern phaseD_reversal_test.js and phase16d1_commission_test.js already
// established for this codebase's other cancellation triggers. This calls
// the REAL compiled handler directly; every Firestore read/write inside it
// still hits the REAL Firestore emulator.
//
// Run with:
//   firebase emulators:exec --only firestore,functions,auth \
//     "node scripts/phase57_stock_restoration_test.js"
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: "agrimore-66a4e" });
const db = admin.firestore();

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { restoreStockOnCancellation } = require("../lib/customer/restoreStockOnCancellation");
const { sellerTransitionOrder } = require("../lib/seller/sellerTransitionOrder");
const { confirmOrderReturnReceived } = require("../lib/admin/confirmOrderReturnReceived");
const wrapped = test.wrap(restoreStockOnCancellation);
const wrappedSeller = test.wrap(sellerTransitionOrder);
const wrappedConfirmReturn = test.wrap(confirmOrderReturnReceived);

async function callConfirmReturn(payload, auth) {
  try {
    return { ok: true, result: await wrappedConfirmReturn({ data: payload, auth }) };
  } catch (e) {
    return { ok: false, code: e.code, message: e.message };
  }
}
const ADMIN_AUTH = { uid: "phase57-admin", token: { admin: true } };
const NON_ADMIN_AUTH = { uid: "phase57-not-admin", token: {} };

async function fireCancellation(orderId, beforeData, afterData) {
  const beforeSnap = test.firestore.makeDocumentSnapshot(beforeData, `orders/${orderId}`);
  const afterSnap = test.firestore.makeDocumentSnapshot(afterData, `orders/${orderId}`);
  const change = test.makeChange(beforeSnap, afterSnap);
  return wrapped(change, { params: { orderId } });
}

async function seedProduct(id, fields) {
  await db.collection("products").doc(id).set({ name: `P ${id}`, sellerId: "phase57-seller", ...fields });
}

async function product(id) {
  return (await db.collection("products").doc(id).get()).data() || {};
}

function baseOrder(overrides) {
  return {
    userId: overrides.userId || "phase57-customer",
    sellerId: overrides.sellerId || "phase57-seller",
    orderNumber: `ORD-${overrides.orderIdHint || "x"}`,
    items: overrides.items || [],
    subtotal: 1000,
    total: 1000,
    paymentMethod: overrides.paymentMethod || "cod",
    paymentStatus: overrides.paymentStatus || "pending",
    orderStatus: overrides.orderStatus ?? "pending",
    status: overrides.status ?? overrides.orderStatus ?? "pending",
    orderMode: "B2C",
    ...overrides.extra,
  };
}

async function order(orderId, fields) {
  await db.collection("orders").doc(orderId).set(baseOrder(fields));
}

async function orderDoc(orderId) {
  return (await db.collection("orders").doc(orderId).get()).data() || {};
}

async function main() {
  let allPassed = true;
  const results = {};
  const record = (key, ok, passMsg, failMsg) => {
    results[key] = ok ? `PASSED — ${passMsg}` : `FAILED — ${failMsg}`;
    console.log(`${key}: ${ok ? "PASSED" : "FAILED"} — ${ok ? passMsg : failMsg}`);
    if (!ok) allPassed = false;
  };

  console.log("=== PHASE ADMR-1 — stock restoration on cancellation ===");

  // ============================================================
  // Scenario 1 — THE LIVE GAP. A customer/admin-style direct write
  // (no sellerTransitionOrder involved at all) must now restore base
  // stock. Before this phase, nothing watched for this transition, so
  // stock was NEVER restored on this path.
  // ============================================================
  {
    const orderId = "phase57-o1";
    const productId = "phase57-p1";
    await seedProduct(productId, { stock: 5 });
    await order(orderId, { orderIdHint: "1", items: [{ productId, quantity: 3 }] });
    const before = await orderDoc(orderId);
    const after = { ...before, orderStatus: "cancelled", status: "cancelled" };
    await fireCancellation(orderId, before, after);
    const p = await product(productId);
    const o = await orderDoc(orderId);
    record("s1_direct_admin_or_customer_cancel_now_restores_base_stock",
      p.stock === 8 && o.stockRestored === true,
      `stock=8 stockRestored=true`,
      `stock=${p.stock} (expect 8) stockRestored=${o.stockRestored}`);
  }

  // ============================================================
  // Scenario 2 — THE BUG ITSELF. A variant line's own stock must be
  // restored into product.variants[], NOT into base stock. The old
  // sellerTransitionOrder.ts restoration always incremented base stock
  // regardless — this proves the fix targets the right field.
  // ============================================================
  {
    const orderId = "phase57-o2";
    const productId = "phase57-p2";
    await seedProduct(productId, {
      stock: 20, // untouched by this order — no line of this order is a base line
      variants: [
        { id: "v1", name: "500g", stock: 10 },
        { id: "v2", name: "1kg", stock: 4 },
      ],
    });
    await order(orderId, { orderIdHint: "2", items: [{ productId, quantity: 3, variantId: "v1" }] });
    const before = await orderDoc(orderId);
    const after = { ...before, orderStatus: "cancelled", status: "cancelled" };
    await fireCancellation(orderId, before, after);
    const p = await product(productId);
    const v1 = p.variants.find((v) => v.id === "v1");
    const v2 = p.variants.find((v) => v.id === "v2");
    record("s2_variant_line_restores_that_variants_own_stock_not_base",
      p.stock === 20 && v1.stock === 13 && v2.stock === 4,
      `base=20(unchanged) v1=13 v2=4(unchanged)`,
      `base=${p.stock}(expect 20) v1=${v1 && v1.stock}(expect 13) v2=${v2 && v2.stock}(expect 4)`);
  }

  // ============================================================
  // Scenario 3 — mixed order: one base line, one variant line on the SAME
  // product, in the SAME cancellation. Both must land correctly.
  // ============================================================
  {
    const orderId = "phase57-o3";
    const productId = "phase57-p3";
    await seedProduct(productId, {
      stock: 9,
      variants: [{ id: "vA", name: "Small", stock: 2 }],
    });
    await order(orderId, {
      orderIdHint: "3",
      items: [
        { productId, quantity: 2 }, // base line, no variantId
        { productId, quantity: 5, variantId: "vA" },
      ],
    });
    const before = await orderDoc(orderId);
    const after = { ...before, orderStatus: "cancelled", status: "cancelled" };
    await fireCancellation(orderId, before, after);
    const p = await product(productId);
    const vA = p.variants.find((v) => v.id === "vA");
    record("s3_mixed_base_and_variant_lines_both_restored_correctly",
      p.stock === 11 && vA.stock === 7,
      `base=11 vA=7`,
      `base=${p.stock}(expect 11) vA=${vA && vA.stock}(expect 7)`);
  }

  // ============================================================
  // Scenario 4 — idempotency. A retried/redelivered trigger event (the
  // identical before/after payload, Firestore triggers are at-least-once)
  // must not restore twice. The in-transaction re-check against the LIVE
  // order (not the cheap early-return against the stale `after` payload)
  // is what actually proves this — reusing the identical payload is what
  // exercises that guard, not a synthetically-altered one.
  // ============================================================
  {
    const orderId = "phase57-o4";
    const productId = "phase57-p4";
    await seedProduct(productId, { stock: 5 });
    await order(orderId, { orderIdHint: "4", items: [{ productId, quantity: 2 }] });
    const before = await orderDoc(orderId);
    const after = { ...before, orderStatus: "cancelled", status: "cancelled" };
    await fireCancellation(orderId, before, after); // first delivery
    await fireCancellation(orderId, before, after); // retried delivery, SAME payload
    const p = await product(productId);
    record("s4_retried_trigger_event_does_not_double_restore",
      p.stock === 7,
      `stock=7 (restored once, not twice)`,
      `stock=${p.stock} (expect 7 — 5+2 once, not 5+2+2)`);
  }

  // ============================================================
  // Scenario 5 — no real transition (already cancelled → still cancelled)
  // must not fire at all.
  // ============================================================
  {
    const orderId = "phase57-o5";
    const productId = "phase57-p5";
    await seedProduct(productId, { stock: 5 });
    await order(orderId, { orderIdHint: "5", orderStatus: "cancelled", items: [{ productId, quantity: 2 }] });
    const before = await orderDoc(orderId);
    const after = { ...before }; // no change at all
    await fireCancellation(orderId, before, after);
    const p = await product(productId);
    record("s5_no_new_transition_into_cancelled_is_a_no_op",
      p.stock === 5,
      `stock=5 (untouched)`,
      `stock=${p.stock} (expect 5, unrestored — this order was already cancelled before this write)`);
  }

  // ============================================================
  // Scenario 6 — N-49 parity: a product with untracked (non-numeric)
  // stock is left untouched, exactly like createOrder.ts's own decrement
  // fails open rather than materialising a negative/fabricated value.
  // ============================================================
  {
    const orderId = "phase57-o6";
    const productId = "phase57-p6";
    await seedProduct(productId, {}); // no `stock` field at all
    await order(orderId, { orderIdHint: "6", items: [{ productId, quantity: 4 }] });
    const before = await orderDoc(orderId);
    const after = { ...before, orderStatus: "cancelled", status: "cancelled" };
    await fireCancellation(orderId, before, after);
    const p = await product(productId);
    const o = await orderDoc(orderId);
    record("s6_untracked_stock_left_untouched_but_still_marked_restored",
      p.stock === undefined && o.stockRestored === true,
      `stock=undefined(untouched) stockRestored=true(no infinite retry)`,
      `stock=${p.stock} stockRestored=${o.stockRestored}`);
  }

  // ============================================================
  // Scenario 7 — a variant referenced by the order no longer exists
  // (deleted since the order was placed). Must NOT be folded into base
  // stock (that would misattribute the unit to the wrong SKU).
  // ============================================================
  {
    const orderId = "phase57-o7";
    const productId = "phase57-p7";
    await seedProduct(productId, { stock: 10, variants: [{ id: "still-here", stock: 1 }] });
    await order(orderId, { orderIdHint: "7", items: [{ productId, quantity: 3, variantId: "deleted-variant" }] });
    const before = await orderDoc(orderId);
    const after = { ...before, orderStatus: "cancelled", status: "cancelled" };
    await fireCancellation(orderId, before, after);
    const p = await product(productId);
    const o = await orderDoc(orderId);
    record("s7_deleted_variant_not_folded_into_base_stock",
      p.stock === 10 && o.stockRestored === true,
      `base=10(unchanged, not misattributed) stockRestored=true`,
      `base=${p.stock}(expect 10) stockRestored=${o.stockRestored}`);
  }

  // ============================================================
  // Scenario 8 — END TO END, the seller path. sellerTransitionOrder no
  // longer touches stock itself (verified: stock and stockRestored are
  // untouched immediately after the callable returns); firing this
  // trigger with the callable's own resulting before/after then restores
  // the variant correctly, exactly as it would for any other path.
  // ============================================================
  {
    const orderId = "phase57-o8";
    const productId = "phase57-p8";
    const SELLER = "phase57-seller";
    await seedProduct(productId, { stock: 6, variants: [{ id: "vX", stock: 2 }] });
    await order(orderId, {
      orderIdHint: "8",
      sellerId: SELLER,
      orderStatus: "pending",
      items: [{ productId, quantity: 5, variantId: "vX" }],
      extra: { paymentMethod: "cod" },
    });
    const beforeCall = await orderDoc(orderId);
    const r = await wrappedSeller({
      data: { orderId, action: "reject", reason: "out_of_stock" },
      auth: { uid: SELLER, token: { seller: true } },
    });
    const pMid = await product(productId);
    const oMid = await orderDoc(orderId);
    const calleeLeavesStockAlone =
      r.status === "cancelled" && pMid.stock === 6 && pMid.variants[0].stock === 2 && !oMid.stockRestored;

    const after = { ...beforeCall, orderStatus: "cancelled", status: "cancelled" };
    await fireCancellation(orderId, beforeCall, after);
    const pFinal = await product(productId);
    const oFinal = await orderDoc(orderId);
    record("s8_seller_callable_leaves_stock_alone_trigger_restores_variant",
      calleeLeavesStockAlone && pFinal.stock === 6 && pFinal.variants[0].stock === 7 && oFinal.stockRestored === true,
      `callable untouched stock; trigger then restored vX 2->7, base unchanged`,
      `calleeLeavesStockAlone=${calleeLeavesStockAlone} finalBase=${pFinal.stock}(expect 6) finalVariant=${pFinal.variants && pFinal.variants[0] && pFinal.variants[0].stock}(expect 7)`);
  }

  // ============================================================
  // Scenario 9 — ADMR-37: a cancellation reached FROM 'delivered' must NOT
  // auto-restore stock — the customer already has physical possession.
  // Instead the order is flagged stockRestorePending, stock is untouched,
  // and stockRestored stays unset.
  // ============================================================
  {
    const orderId = "phase57-o9";
    const productId = "phase57-p9";
    await seedProduct(productId, { stock: 4 });
    await order(orderId, { orderIdHint: "9", orderStatus: "delivered", items: [{ productId, quantity: 2 }] });
    const before = await orderDoc(orderId);
    const after = { ...before, orderStatus: "cancelled", status: "cancelled" };
    await fireCancellation(orderId, before, after);
    const p = await product(productId);
    const o = await orderDoc(orderId);
    record("s9_delivered_to_cancelled_does_not_auto_restore",
      p.stock === 4 && o.stockRestorePending === true && !o.stockRestored,
      `stock=4(untouched) stockRestorePending=true stockRestored=unset`,
      `stock=${p.stock}(expect 4) stockRestorePending=${o.stockRestorePending} stockRestored=${o.stockRestored}`);
  }

  // ============================================================
  // Scenario 10 — confirmOrderReturnReceived: an admin confirming a
  // pending return actually restores stock (base + variant mix), via the
  // SAME restoreOrderItemStock the trigger itself uses.
  // ============================================================
  {
    const orderId = "phase57-o10";
    const productId = "phase57-p10";
    await seedProduct(productId, { stock: 6, variants: [{ id: "vR", stock: 1 }] });
    await order(orderId, {
      orderIdHint: "10",
      orderStatus: "delivered",
      items: [
        { productId, quantity: 2 },
        { productId, quantity: 3, variantId: "vR" },
      ],
    });
    const before = await orderDoc(orderId);
    const afterCancel = { ...before, orderStatus: "cancelled", status: "cancelled" };
    // fireCancellation only feeds the trigger a SYNTHETIC before/after pair —
    // it does not itself write the real document (matching how a real
    // caller like adminUpdateOrderStatus already would have, before this
    // trigger ever fires). confirmOrderReturnReceived reads the REAL
    // document, so the test must actually write the transition too.
    await db.collection("orders").doc(orderId).set(afterCancel, { merge: true });
    await fireCancellation(orderId, before, afterCancel); // sets stockRestorePending, no restore yet

    const r = await callConfirmReturn({ orderId }, ADMIN_AUTH);
    const p = await product(productId);
    const o = await orderDoc(orderId);
    const vR = p.variants && p.variants.find((v) => v.id === "vR");
    record("s10_admin_confirm_return_restores_base_and_variant",
      r.ok && r.result.outcome === "restored" &&
        p.stock === 8 && vR && vR.stock === 4 &&
        o.stockRestored === true && o.stockRestorePending === false && o.stockRestoreConfirmedBy === ADMIN_AUTH.uid,
      `outcome=restored base=8 vR=4 stockRestored=true stockRestorePending=false confirmedBy set`,
      `ok=${r.ok} outcome=${r.result && r.result.outcome} base=${p.stock}(expect 8) vR=${vR && vR.stock}(expect 4) stockRestored=${o.stockRestored} stockRestorePending=${o.stockRestorePending}`);
  }

  // ============================================================
  // Scenario 11 — idempotency: confirming twice restores stock once.
  // ============================================================
  {
    const orderId = "phase57-o11";
    const productId = "phase57-p11";
    await seedProduct(productId, { stock: 5 });
    await order(orderId, { orderIdHint: "11", orderStatus: "delivered", items: [{ productId, quantity: 2 }] });
    const before = await orderDoc(orderId);
    const afterCancel = { ...before, orderStatus: "cancelled", status: "cancelled" };
    await db.collection("orders").doc(orderId).set(afterCancel, { merge: true });
    await fireCancellation(orderId, before, afterCancel);

    const r1 = await callConfirmReturn({ orderId }, ADMIN_AUTH);
    const r2 = await callConfirmReturn({ orderId }, ADMIN_AUTH);
    const p = await product(productId);
    record("s11_confirming_twice_restores_stock_once",
      r1.ok && r1.result.outcome === "restored" && r2.ok && r2.result.outcome === "already_restored" && p.stock === 7,
      `first=restored second=already_restored stock=7(once)`,
      `first=${r1.result && r1.result.outcome} second=${r2.result && r2.result.outcome} stock=${p.stock}(expect 7)`);
  }

  // ============================================================
  // Scenario 12 — confirming an order that was never pending (a normal
  // pre-delivery cancellation, already auto-restored) is refused, not a
  // silent no-op that could look like success.
  // ============================================================
  {
    const orderId = "phase57-o12";
    const productId = "phase57-p12";
    await seedProduct(productId, { stock: 5 });
    await order(orderId, { orderIdHint: "12", items: [{ productId, quantity: 2 }] }); // default pending
    const before = await orderDoc(orderId);
    const afterCancel = { ...before, orderStatus: "cancelled", status: "cancelled" };
    await fireCancellation(orderId, before, afterCancel); // ordinary path — auto-restores immediately

    const r = await callConfirmReturn({ orderId }, ADMIN_AUTH);
    const p = await product(productId);
    record("s12_confirming_a_non_pending_order_is_refused_not_a_silent_noop",
      r.ok && r.result.outcome === "already_restored" && p.stock === 7,
      `outcome=already_restored stock=7(unchanged by the confirm call itself)`,
      `ok=${r.ok} outcome=${r.result && r.result.outcome} stock=${p.stock}(expect 7)`);
  }

  // ============================================================
  // Scenario 13 — permission: a non-admin cannot confirm a return.
  // ============================================================
  {
    const orderId = "phase57-o13";
    const productId = "phase57-p13";
    await seedProduct(productId, { stock: 3 });
    await order(orderId, { orderIdHint: "13", orderStatus: "delivered", items: [{ productId, quantity: 1 }] });
    const before = await orderDoc(orderId);
    const afterCancel = { ...before, orderStatus: "cancelled", status: "cancelled" };
    await fireCancellation(orderId, before, afterCancel);

    const r = await callConfirmReturn({ orderId }, NON_ADMIN_AUTH);
    const p = await product(productId);
    const o = await orderDoc(orderId);
    record("s13_non_admin_cannot_confirm_return",
      !r.ok && r.code === "permission-denied" && p.stock === 3 && o.stockRestorePending === true,
      `refused permission-denied, stock untouched, still pending`,
      `ok=${r.ok} code=${r.code} stock=${p.stock}(expect 3) stockRestorePending=${o.stockRestorePending}`);
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
