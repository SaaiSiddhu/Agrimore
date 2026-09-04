// Phase FIX-3 — proves stock is actually reserved, and that a repeated
// productId can no longer oversell.
//
// N-3 (P1): nothing in this codebase decremented stock. computeOrderPricing
//   validated product.stock and no path wrote it back, so stock never fell, an
//   out-of-stock product stayed purchasable forever, and soldCount never moved.
// N-4 (P1): stock was validated per ITEM ENTRY, not per product, so a cart of
//   [{p,5},{p,5}] against stock 5 passed the check twice.
// N-49 (P4): stock validation fails OPEN for a missing/non-numeric stock. That
//   is preserved deliberately — scenario 6 pins it, so a future change that
//   flips it becomes a visible test failure rather than a silent one.
//
// Exercises the REAL compiled functions/lib/customer/createOrder.js against the
// Firestore emulator. createOrder is a v2 onCall — wrapped and invoked as
// wrapped({data, auth}).
//
// Run with:
//   firebase emulators:exec --only firestore,functions,auth \
//     "node scripts/phase27_stock_integrity_test.js"
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: "agrimore-66a4e" });
const db = admin.firestore();

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { createOrder } = require("../lib/customer/createOrder");
const { MAX_CART_LINES } = require("../lib/customer/orderPricing");
const wrapped = test.wrap(createOrder);

async function call(payload, auth) {
  try {
    return { ok: true, result: await wrapped({ data: payload, auth }) };
  } catch (e) {
    return { ok: false, code: e.code, message: e.message };
  }
}

async function seedUser(uid) {
  await db.collection("users").doc(uid).set({ uid, profileCompleted: true });
}

async function seedProduct(id, salePrice, stock) {
  const doc = { name: `P ${id}`, salePrice, sellerId: "phase27-seller", images: [], isB2BEnabled: false };
  if (stock !== undefined) doc.stock = stock;
  await db.collection("products").doc(id).set(doc);
}

function payload(items) {
  return {
    items,
    orderMode: "B2C",
    deliveryAddress: { name: "T", phone: "9999999999", addressLine1: "1 St", city: "Chennai", state: "TN", zipcode: "600001", country: "India" },
    paymentMethod: "cod",
    deliveryCharge: 0,
    tax: 0,
  };
}

const prod = (id) => db.collection("products").doc(id).get().then((s) => s.data() || {});

async function main() {
  const results = {};
  let allPassed = true;
  const record = (k, p, d) => { results[k] = p; console.log(`${k}: ${p ? "PASSED" : "FAILED"} — ${d}`); if (!p) allPassed = false; };

  console.log("=== PHASE FIX-3 — stock integrity (N-3, N-4, N-49) ===");

  // 1 — POSITIVE CONTROL. A normal order must still succeed AND move stock.
  // Without this, every refusal below could pass because createOrder refuses
  // everything.
  {
    const uid = "phase27-u1"; const p = "phase27-p1";
    await seedUser(uid); await seedProduct(p, 100, 10);
    const r = await call(payload([{ productId: p, quantity: 3 }]), { uid, token: {} });
    const after = await prod(p);
    record("scenario1_control_order_succeeds_and_stock_moves",
      r.ok && after.stock === 7 && after.soldCount === 3,
      `ok=${r.ok} stock=${after.stock} (expect 7) soldCount=${after.soldCount} (expect 3)`);
  }

  // 2 — N-4, THE FINDING. Duplicate lines summing ABOVE stock must be refused.
  // Before FIX-3 each entry was compared against the full stock independently,
  // so this was accepted and oversold.
  {
    const uid = "phase27-u2"; const p = "phase27-p2";
    await seedUser(uid); await seedProduct(p, 100, 5);
    const r = await call(payload([{ productId: p, quantity: 5 }, { productId: p, quantity: 5 }]), { uid, token: {} });
    const after = await prod(p);
    const orders = await db.collection("orders").where("userId", "==", uid).get();
    record("scenario2_N4_duplicate_lines_cannot_oversell",
      !r.ok && r.code === "failed-precondition" && after.stock === 5 && orders.empty,
      `code=${r.code} msg="${r.message}" stock=${after.stock} (must stay 5) orders=${orders.size}`);
  }

  // 3 — N-4, the legitimate half: duplicate lines summing WITHIN stock must
  // succeed, decrement by the SUM, and collapse to ONE order line.
  {
    const uid = "phase27-u3"; const p = "phase27-p3";
    await seedUser(uid); await seedProduct(p, 100, 10);
    const r = await call(payload([{ productId: p, quantity: 2 }, { productId: p, quantity: 3 }]), { uid, token: {} });
    const after = await prod(p);
    const orders = await db.collection("orders").where("userId", "==", uid).get();
    const lines = orders.empty ? -1 : (orders.docs[0].data().items || []).length;
    record("scenario3_N4_duplicate_lines_merge_and_decrement_by_sum",
      r.ok && after.stock === 5 && after.soldCount === 5 && lines === 1,
      `ok=${r.ok} stock=${after.stock} (expect 5) soldCount=${after.soldCount} (expect 5) orderLines=${lines} (expect 1)`);
  }

  // 4 — N-3, the point of the phase: stock must actually PERSIST down, so a
  // second order that exceeds the remainder is refused. This is the scenario a
  // pre-FIX-3 build cannot pass however the first order behaved, because stock
  // never moved at all.
  {
    const uid = "phase27-u4"; const p = "phase27-p4";
    await seedUser(uid); await seedProduct(p, 100, 5);
    const first = await call(payload([{ productId: p, quantity: 4 }]), { uid, token: {} });
    const mid = await prod(p);
    const second = await call(payload([{ productId: p, quantity: 3 }]), { uid, token: {} });
    const after = await prod(p);
    record("scenario4_N3_stock_persists_so_the_next_order_is_refused",
      first.ok && mid.stock === 1 && !second.ok && second.code === "failed-precondition" && after.stock === 1,
      `first.ok=${first.ok} stockAfterFirst=${mid.stock} (expect 1) second.code=${second.code} stockFinal=${after.stock}`);
  }

  // 5 — single-line oversell stays refused (pre-existing behaviour, kept as a
  // regression control so the de-dup change cannot have loosened it).
  {
    const uid = "phase27-u5"; const p = "phase27-p5";
    await seedUser(uid); await seedProduct(p, 100, 2);
    const r = await call(payload([{ productId: p, quantity: 5 }]), { uid, token: {} });
    const after = await prod(p);
    record("scenario5_control_single_line_oversell_still_refused",
      !r.ok && r.code === "failed-precondition" && after.stock === 2,
      `code=${r.code} stock=${after.stock} (must stay 2)`);
  }

  // 6 — N-49, PINNED. A product with NO stock field fails OPEN (the order is
  // allowed, mirroring ProductModel.fromMap's default of 999) and must NOT have
  // a negative `stock` materialised out of nothing by increment(-qty).
  // soldCount still moves. If a future phase flips the fail-open to fail-closed
  // this scenario fails loudly instead of the behaviour changing silently.
  {
    const uid = "phase27-u6"; const p = "phase27-p6";
    await seedUser(uid); await seedProduct(p, 100, undefined);
    const r = await call(payload([{ productId: p, quantity: 4 }]), { uid, token: {} });
    const after = await prod(p);
    record("scenario6_N49_missing_stock_fails_open_without_materialising_negative_stock",
      r.ok && after.stock === undefined && after.soldCount === 4,
      `ok=${r.ok} stock=${JSON.stringify(after.stock)} (must stay undefined) soldCount=${after.soldCount} (expect 4)`);
  }

  // 7 — the cart-line cap that bounds tx.getAll.
  {
    const uid = "phase27-u7";
    await seedUser(uid);
    const items = [];
    for (let i = 0; i < MAX_CART_LINES + 1; i++) items.push({ productId: `phase27-bulk-${i}`, quantity: 1 });
    const r = await call(payload(items), { uid, token: {} });
    record("scenario7_cart_line_cap_enforced",
      !r.ok && r.code === "invalid-argument" && /more than/.test(r.message || ""),
      `code=${r.code} msg="${r.message}" (cap=${MAX_CART_LINES})`);
  }

  console.log("\n=== SUMMARY ===");
  const total = Object.keys(results).length;
  const passed = Object.values(results).filter(Boolean).length;
  for (const [k, v] of Object.entries(results)) console.log(`  ${v ? "PASS" : "FAIL"}  ${k}`);
  console.log(`\n${passed}/${total} scenarios passed`);
  if (!allPassed) { console.error("PHASE 27: FAILED"); process.exit(1); }
  console.log("PHASE 27: ALL PASSED");
  process.exit(0);
}

main().catch((e) => { console.error("PHASE 27: harness error", e); process.exit(1); });
