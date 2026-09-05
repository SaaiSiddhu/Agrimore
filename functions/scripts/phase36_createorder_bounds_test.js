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

  // 2 — N-23 WS1, THE FINDING. A second createOrder call from the SAME uid
  // within the cooldown window must be refused, and must not create a
  // second order.
  {
    const uid = "phase36-u2"; const p = "phase36-p2";
    await seedUser(uid); await seedProduct(p, 100, 20);
    const first = await call(payload([{ productId: p, quantity: 1 }]), { uid, token: {} });
    const second = await call(payload([{ productId: p, quantity: 1 }]), { uid, token: {} });
    const orders = await ordersFor(uid);
    record("scenario2_N23_burst_second_call_refused",
      first.ok && !second.ok && second.code === "resource-exhausted" && orders.size === 1,
      `first.ok=${first.ok} second.code=${second.code} orderCount=${orders.size} (expect 1)`);
  }

  // 3 — the limiter is PER-USER, not global: a different uid's order right
  // after scenario 2's burst must not be affected by it.
  {
    const uid = "phase36-u3"; const p = "phase36-p3";
    await seedUser(uid); await seedProduct(p, 100, 20);
    const r = await call(payload([{ productId: p, quantity: 1 }]), { uid, token: {} });
    record("scenario3_rate_limit_is_per_user_not_global", r.ok, `ok=${r.ok} err=${r.ok ? "" : r.message}`);
  }

  // 4 — the cooldown EXPIRES: once the window has passed, the same uid can
  // order again. Backdates order_rate_limits/{uid}.lastOrderAt directly via
  // the Admin SDK rather than sleeping 10s in the test.
  {
    const uid = "phase36-u4"; const p = "phase36-p4";
    await seedUser(uid); await seedProduct(p, 100, 20);
    const first = await call(payload([{ productId: p, quantity: 1 }]), { uid, token: {} });
    await db.collection("order_rate_limits").doc(uid).set({
      lastOrderAt: admin.firestore.Timestamp.fromMillis(Date.now() - 11000),
    });
    const second = await call(payload([{ productId: p, quantity: 1 }]), { uid, token: {} });
    const orders = await ordersFor(uid);
    record("scenario4_N23_cooldown_expires_after_window",
      first.ok && second.ok && orders.size === 2,
      `first.ok=${first.ok} second.ok=${second.ok} orderCount=${orders.size} (expect 2)`);
  }

  // 5 — N-23 WS2. An oversized deliveryAddress (over MAX_DELIVERY_ADDRESS_BYTES)
  // is refused before any Firestore read.
  {
    const uid = "phase36-u5"; const p = "phase36-p5";
    await seedUser(uid); await seedProduct(p, 100, 20);
    const r = await call(payload([{ productId: p, quantity: 1 }], {
      deliveryAddress: Object.assign({}, REAL_ADDRESS, { addressLine1: "x".repeat(5000) }),
    }), { uid, token: {} });
    record("scenario5_WS2_oversized_deliveryAddress_refused",
      !r.ok && r.code === "invalid-argument", `code=${r.code} msg="${r.message}"`);
  }

  // 6 — N-23 WS2. A deliveryAddress that isn't a plain object (an array) is
  // refused rather than silently written.
  {
    const uid = "phase36-u6"; const p = "phase36-p6";
    await seedUser(uid); await seedProduct(p, 100, 20);
    const r = await call(payload([{ productId: p, quantity: 1 }], { deliveryAddress: [1, 2, 3] }), { uid, token: {} });
    record("scenario6_WS2_deliveryAddress_wrong_shape_refused",
      !r.ok && r.code === "invalid-argument", `code=${r.code} msg="${r.message}"`);
  }

  // 7 — N-23 WS2. Oversized notes (over MAX_NOTES_LENGTH) refused.
  {
    const uid = "phase36-u7"; const p = "phase36-p7";
    await seedUser(uid); await seedProduct(p, 100, 20);
    const r = await call(payload([{ productId: p, quantity: 1 }], { notes: "x".repeat(501) }), { uid, token: {} });
    record("scenario7_WS2_oversized_notes_refused",
      !r.ok && r.code === "invalid-argument", `code=${r.code} msg="${r.message}"`);
  }

  // 8 — N-23 WS2. Oversized deliverySlot (over MAX_SHORT_STRING_FIELD_LENGTH)
  // refused.
  {
    const uid = "phase36-u8"; const p = "phase36-p8";
    await seedUser(uid); await seedProduct(p, 100, 20);
    const r = await call(payload([{ productId: p, quantity: 1 }], { deliverySlot: "x".repeat(101) }), { uid, token: {} });
    record("scenario8_WS2_oversized_deliverySlot_refused",
      !r.ok && r.code === "invalid-argument", `code=${r.code} msg="${r.message}"`);
  }

  // 9 — N-23 WS2. Oversized autoFrequency refused — proves the shared
  // deliverySlot/orderType/autoFrequency loop actually reaches every field,
  // not just the first one checked.
  {
    const uid = "phase36-u9"; const p = "phase36-p9";
    await seedUser(uid); await seedProduct(p, 100, 20);
    const r = await call(payload([{ productId: p, quantity: 1 }], { autoFrequency: "x".repeat(101) }), { uid, token: {} });
    record("scenario9_WS2_oversized_autoFrequency_refused",
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
