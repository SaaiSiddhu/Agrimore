// Phase FIX-16 — proves createOrder now bounds both HOW FAST and HOW LARGE
// an authenticated caller can create orders (finding N-23).
//
// N-23 (P2/P3): createOrder had no per-user rate limit anywhere, and a COD
//   order costs the caller nothing to create, so a script could hammer the
//   callable without bound. deliveryAddress/notes/deliverySlot/orderType/
//   autoFrequency were all written into the order document verbatim from
//   client input with no shape or size check.
//
// Exercises the REAL compiled functions/lib/customer/createOrder.js against
// the Firestore emulator. createOrder is a v2 onCall — wrapped and invoked
// as wrapped({data, auth}).
//
// Run with:
//   firebase emulators:exec --only firestore,functions,auth \
//     "node scripts/phase36_createorder_bounds_test.js"
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: "agrimore-66a4e" });
const db = admin.firestore();

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { createOrder } = require("../lib/customer/createOrder");
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
  await db.collection("products").doc(id).set({
    name: `P ${id}`, salePrice, stock, sellerId: "phase36-seller", images: [], isB2BEnabled: false,
  });
}

const REAL_ADDRESS = {
  name: "Test User", phone: "9999999999", addressLine1: "1 Main St", addressLine2: "Near the market",
  city: "Chennai", state: "TN", zipcode: "600001", country: "India", latitude: 13.08, longitude: 80.27,
  addressType: "home", landmark: "Opposite the bank",
};

function payload(items, overrides) {
  return Object.assign({
    items,
    orderMode: "B2C",
    deliveryAddress: REAL_ADDRESS,
    paymentMethod: "cod",
    deliveryCharge: 0,
    tax: 0,
    notes: "Please call before delivery",
    deliverySlot: "morning",
    orderType: "One Time",
  }, overrides);
}

async function ordersFor(uid) {
  return db.collection("orders").where("userId", "==", uid).get();
}

async function main() {
  const results = {};
  let allPassed = true;
  const record = (k, p, d) => { results[k] = p; console.log(`${k}: ${p ? "PASSED" : "FAILED"} — ${d}`); if (!p) allPassed = false; };

  console.log("=== PHASE FIX-16 — createOrder abuse bounds (N-23) ===");

  // 1 — POSITIVE CONTROL. A realistic order (real-shape address, notes,
  // deliverySlot, orderType, all within bounds) must still succeed. Without
  // this, every refusal below could pass because createOrder refuses
  // everything.
  {
    const uid = "phase36-u1"; const p = "phase36-p1";
    await seedUser(uid); await seedProduct(p, 100, 20);
    const r = await call(payload([{ productId: p, quantity: 1 }]), { uid, token: {} });
    record("scenario1_control_realistic_order_succeeds", r.ok, `ok=${r.ok} err=${r.ok ? "" : r.message}`);
  }

  // 2 — legitimate back-to-back distinct orders from the SAME uid, up to
  // the cap, must ALL succeed. This is the exact real-world pattern (and
  // the pattern this codebase's own phase14/phase15/phase27/phaseD suites
  // already rely on) that a flat per-call cooldown broke — see WS1's
  // comment in createOrder.ts for the full story.
  {
    const uid = "phase36-u2"; const p = "phase36-p2";
    await seedUser(uid); await seedProduct(p, 100, 100);
    let allOk = true; const codes = [];
    for (let i = 0; i < 8; i++) {
      const r = await call(payload([{ productId: p, quantity: 1 }]), { uid, token: {} });
      codes.push(r.ok ? "ok" : r.code);
      if (!r.ok) allOk = false;
    }
    const orders = await ordersFor(uid);
    record("scenario2_eight_backtoback_orders_within_cap_all_succeed",
      allOk && orders.size === 8,
      `codes=${JSON.stringify(codes)} orderCount=${orders.size} (expect 8)`);
  }

  // 3 — N-23 WS1, THE FINDING. The (MAX_ORDERS_PER_WINDOW + 1)th order in
  // the same window is refused, and creates no order.
  {
    const uid = "phase36-u3"; const p = "phase36-p3";
    await seedUser(uid); await seedProduct(p, 100, 100);
    for (let i = 0; i < 8; i++) await call(payload([{ productId: p, quantity: 1 }]), { uid, token: {} });
    const ninth = await call(payload([{ productId: p, quantity: 1 }]), { uid, token: {} });
    const orders = await ordersFor(uid);
    record("scenario3_N23_ninth_order_in_window_refused",
      !ninth.ok && ninth.code === "resource-exhausted" && orders.size === 8,
      `ninth.code=${ninth.code} orderCount=${orders.size} (expect 8, not 9)`);
  }

  // 4 — the limiter is PER-USER, not global: a different uid's order right
  // after scenario 3's cap-out must not be affected by it.
  {
    const uid = "phase36-u4"; const p = "phase36-p4";
    await seedUser(uid); await seedProduct(p, 100, 20);
    const r = await call(payload([{ productId: p, quantity: 1 }]), { uid, token: {} });
    record("scenario4_rate_limit_is_per_user_not_global", r.ok, `ok=${r.ok} err=${r.ok ? "" : r.message}`);
  }

  // 5 — the window EXPIRES: once it has passed, the same uid's count resets
  // and a new order succeeds even though the prior window was maxed out.
  // Backdates order_rate_limits/{uid}.windowStart directly via the Admin
  // SDK rather than sleeping 60s in the test.
  {
    const uid = "phase36-u5"; const p = "phase36-p5";
    await seedUser(uid); await seedProduct(p, 100, 20);
    const first = await call(payload([{ productId: p, quantity: 1 }]), { uid, token: {} });
    await db.collection("order_rate_limits").doc(uid).set({
      windowStart: admin.firestore.Timestamp.fromMillis(Date.now() - 61000),
      count: 8,
    });
    const second = await call(payload([{ productId: p, quantity: 1 }]), { uid, token: {} });
    const orders = await ordersFor(uid);
    record("scenario5_N23_window_expires_and_count_resets",
      first.ok && second.ok && orders.size === 2,
      `first.ok=${first.ok} second.ok=${second.ok} orderCount=${orders.size} (expect 2)`);
  }

  // 6 — N-23 WS2. An oversized deliveryAddress (over MAX_DELIVERY_ADDRESS_BYTES)
  // is refused before any Firestore read.
  {
    const uid = "phase36-u6"; const p = "phase36-p6";
    await seedUser(uid); await seedProduct(p, 100, 20);
    const r = await call(payload([{ productId: p, quantity: 1 }], {
      deliveryAddress: Object.assign({}, REAL_ADDRESS, { addressLine1: "x".repeat(5000) }),
    }), { uid, token: {} });
    record("scenario6_WS2_oversized_deliveryAddress_refused",
      !r.ok && r.code === "invalid-argument", `code=${r.code} msg="${r.message}"`);
  }

  // 7 — N-23 WS2. A deliveryAddress that isn't a plain object (an array) is
  // refused rather than silently written.
  {
    const uid = "phase36-u7"; const p = "phase36-p7";
    await seedUser(uid); await seedProduct(p, 100, 20);
    const r = await call(payload([{ productId: p, quantity: 1 }], { deliveryAddress: [1, 2, 3] }), { uid, token: {} });
    record("scenario7_WS2_deliveryAddress_wrong_shape_refused",
      !r.ok && r.code === "invalid-argument", `code=${r.code} msg="${r.message}"`);
  }

  // 8 — N-23 WS2. Oversized notes (over MAX_NOTES_LENGTH) refused.
  {
    const uid = "phase36-u8"; const p = "phase36-p8";
    await seedUser(uid); await seedProduct(p, 100, 20);
    const r = await call(payload([{ productId: p, quantity: 1 }], { notes: "x".repeat(501) }), { uid, token: {} });
    record("scenario8_WS2_oversized_notes_refused",
      !r.ok && r.code === "invalid-argument", `code=${r.code} msg="${r.message}"`);
  }

  // 9 — N-23 WS2. Oversized deliverySlot (over MAX_SHORT_STRING_FIELD_LENGTH)
  // refused.
  {
    const uid = "phase36-u9"; const p = "phase36-p9";
    await seedUser(uid); await seedProduct(p, 100, 20);
    const r = await call(payload([{ productId: p, quantity: 1 }], { deliverySlot: "x".repeat(101) }), { uid, token: {} });
    record("scenario9_WS2_oversized_deliverySlot_refused",
      !r.ok && r.code === "invalid-argument", `code=${r.code} msg="${r.message}"`);
  }

  // 10 — N-23 WS2. Oversized autoFrequency refused — proves the shared
  // deliverySlot/orderType/autoFrequency loop actually reaches every field,
  // not just the first one checked.
  {
    const uid = "phase36-u10"; const p = "phase36-p10";
    await seedUser(uid); await seedProduct(p, 100, 20);
    const r = await call(payload([{ productId: p, quantity: 1 }], { autoFrequency: "x".repeat(101) }), { uid, token: {} });
    record("scenario10_WS2_oversized_autoFrequency_refused",
      !r.ok && r.code === "invalid-argument", `code=${r.code} msg="${r.message}"`);
  }

  console.log("\n=== SUMMARY ===");
  const total = Object.keys(results).length;
  const passed = Object.values(results).filter(Boolean).length;
  for (const [k, v] of Object.entries(results)) console.log(`  ${v ? "PASS" : "FAIL"}  ${k}`);
  console.log(`\n${passed}/${total} scenarios passed`);
  if (!allPassed) { console.error("PHASE 36: FAILED"); process.exit(1); }
  console.log("PHASE 36: ALL PASSED");
  process.exit(0);
}

main().catch((e) => { console.error("PHASE 36: harness error", e); process.exit(1); });
