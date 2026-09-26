// Phase ADMR-4 — onProductStockChanged (variant-aware, crossing-based)
//
// FINDING: compared only before.stock/after.stock — a variant-line sale
// never moved that field (createOrder.ts decrements a variant's own stock
// inside product.variants[]), so a variant-only product never fired this
// trigger. It also fired on every further decrease while already at/below
// threshold, not just the first crossing, and shared one try block between
// the push send and the inventory_alerts write, so a stale FCM token lost
// the alert record too, not just the notification.
//
// Invocation style: firebase-functions-test's OFFLINE-mode direct
// invocation — test.wrap(onProductStockChanged) called as
// `wrapped(change, context)`, the same pattern phaseD_reversal_test.js and
// phase16d1_commission_test.js already established for this codebase's
// other v1 Firestore triggers.
//
// Run with:
//   firebase emulators:exec --only firestore,functions,auth \
//     "node scripts/phase60_low_stock_variant_test.js"
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: "agrimore-66a4e" });
const db = admin.firestore();

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { onProductStockChanged } = require("../lib/customer/inventory");
const wrapped = test.wrap(onProductStockChanged);

async function fireUpdate(productId, beforeData, afterData) {
  const beforeSnap = test.firestore.makeDocumentSnapshot(beforeData, `products/${productId}`);
  const afterSnap = test.firestore.makeDocumentSnapshot(afterData, `products/${productId}`);
  const change = test.makeChange(beforeSnap, afterSnap);
  return wrapped(change, { params: { productId } });
}

function baseProduct(overrides) {
  return {
    name: "Tomato",
    sellerId: overrides.sellerId ?? "phase60-seller",
    lowStockThreshold: overrides.lowStockThreshold ?? 5,
    stock: overrides.stock,
    variants: overrides.variants,
    ...overrides.extra,
  };
}

async function seedSeller(uid) {
  // No fcmToken/fcmTokens — notifyUser() should still write the in-app
  // inbox entry and simply skip the push (0 tokens), never throwing.
  await db.collection("users").doc(uid).set({ uid });
}

async function alertsFor(productId) {
  const snap = await db.collection("inventory_alerts").where("productId", "==", productId).get();
  return snap.docs.map((d) => d.data());
}
async function inboxCount(uid) {
  const snap = await db.collection("users").doc(uid).collection("notifications").where("type", "==", "low_stock").get();
  return snap.size;
}

async function main() {
  const results = {};
  let allPassed = true;
  const record = (k, p, d) => { results[k] = p; console.log(`${k}: ${p ? "PASSED" : "FAILED"} — ${d}`); if (!p) allPassed = false; };

  console.log("=== PHASE ADMR-4 — variant-aware, crossing-based low-stock alerts ===");

  // 1 — THE FINDING: a variant-only stock change (base stock unchanged)
  // must still fire, and the alert must name the variant.
  {
    const uid = "phase60-s1", pid = "phase60-p1";
    await seedSeller(uid);
    const before = baseProduct({ sellerId: uid, stock: 20, variants: [{ id: "v1", name: "500g", stock: 10 }] });
    const after = { ...before, variants: [{ id: "v1", name: "500g", stock: 3 }] }; // base stock untouched
    await fireUpdate(pid, before, after);
    const alerts = await alertsFor(pid);
    const inbox = await inboxCount(uid);
    record("s1_variant_only_change_now_fires_and_names_the_variant",
      alerts.length === 1 && alerts[0].variantId === "v1" && alerts[0].variantName === "500g" &&
      alerts[0].alertType === "low_stock" && inbox === 1,
      `alerts=${alerts.length} variantId=${alerts[0] && alerts[0].variantId} inboxEntries=${inbox}`);
  }

  // 2 — base-only change (no variants at all) still works exactly as before.
  {
    const uid = "phase60-s2", pid = "phase60-p2";
    await seedSeller(uid);
    const before = baseProduct({ sellerId: uid, stock: 10, variants: undefined });
    const after = { ...before, stock: 0 };
    await fireUpdate(pid, before, after);
    const alerts = await alertsFor(pid);
    record("s2_base_only_product_still_fires_out_of_stock",
      alerts.length === 1 && alerts[0].variantId === null && alerts[0].alertType === "out_of_stock",
      `alerts=${alerts.length} type=${alerts[0] && alerts[0].alertType}`);
  }

  // 3 — no double-counting: base above threshold, one variant crosses, a
  // second variant stays healthy — exactly one alert, for the crossing one.
  {
    const uid = "phase60-s3", pid = "phase60-p3";
    await seedSeller(uid);
    const before = baseProduct({
      sellerId: uid, stock: 50,
      variants: [{ id: "vA", name: "A", stock: 20 }, { id: "vB", name: "B", stock: 40 }],
    });
    const after = { ...before, variants: [{ id: "vA", name: "A", stock: 2 }, { id: "vB", name: "B", stock: 39 }] };
    await fireUpdate(pid, before, after);
    const alerts = await alertsFor(pid);
    record("s3_only_the_crossing_variant_alerts_not_the_healthy_one",
      alerts.length === 1 && alerts[0].variantId === "vA",
      `alerts=${alerts.length} variantIds=${alerts.map((a) => a.variantId).join(",")}`);
  }

  // 4 — THE OTHER FINDING: a further decrease while ALREADY at/below
  // threshold must NOT re-fire (the old "any decrease" check did).
  {
    const uid = "phase60-s4", pid = "phase60-p4";
    await seedSeller(uid);
    // First crossing: 6 -> 3 (already below threshold 5) — one alert.
    await fireUpdate(pid, baseProduct({ sellerId: uid, stock: 6, variants: undefined }), baseProduct({ sellerId: uid, stock: 3, variants: undefined }));
    // Further decrease while still below threshold: 3 -> 2 — must NOT alert again.
    await fireUpdate(pid, baseProduct({ sellerId: uid, stock: 3, variants: undefined }), baseProduct({ sellerId: uid, stock: 2, variants: undefined }));
    const alerts = await alertsFor(pid);
    record("s4_further_decrease_while_already_low_does_not_refire",
      alerts.length === 1 && alerts[0].currentStock === 3,
      `alerts=${alerts.length} (expect exactly 1, from the FIRST crossing only) recordedCurrentStock=${alerts[0] && alerts[0].currentStock}`);
  }

  // 5 — recovery: restock above threshold, then drop below again — a NEW
  // crossing, a NEW alert (the crossing-based check naturally allows this).
  {
    const uid = "phase60-s5", pid = "phase60-p5";
    await seedSeller(uid);
    await fireUpdate(pid, baseProduct({ sellerId: uid, stock: 6, variants: undefined }), baseProduct({ sellerId: uid, stock: 3, variants: undefined })); // 1st crossing
    await fireUpdate(pid, baseProduct({ sellerId: uid, stock: 3, variants: undefined }), baseProduct({ sellerId: uid, stock: 50, variants: undefined })); // restocked, no alert
    await fireUpdate(pid, baseProduct({ sellerId: uid, stock: 50, variants: undefined }), baseProduct({ sellerId: uid, stock: 4, variants: undefined })); // 2nd crossing
    const alerts = await alertsFor(pid);
    record("s5_restock_then_redecline_fires_a_new_alert",
      alerts.length === 2,
      `alerts=${alerts.length} (expect 2 — one per real crossing)`);
  }

  // 6 — no crossing at all (stayed comfortably above threshold) never fires.
  {
    const uid = "phase60-s6", pid = "phase60-p6";
    await seedSeller(uid);
    await fireUpdate(pid, baseProduct({ sellerId: uid, stock: 100, variants: undefined }), baseProduct({ sellerId: uid, stock: 90, variants: undefined }));
    const alerts = await alertsFor(pid);
    record("s6_no_crossing_never_fires", alerts.length === 0, `alerts=${alerts.length} (expect 0)`);
  }

  // 7 — a NEW variant present only in `after` (no `before` counterpart) is
  // skipped, not treated as a crossing from undefined.
  {
    const uid = "phase60-s7", pid = "phase60-p7";
    await seedSeller(uid);
    const before = baseProduct({ sellerId: uid, stock: 50, variants: [] });
    const after = { ...before, variants: [{ id: "new-variant", name: "New", stock: 1 }] };
    await fireUpdate(pid, before, after);
    const alerts = await alertsFor(pid);
    record("s7_brand_new_variant_is_not_a_crossing", alerts.length === 0, `alerts=${alerts.length} (expect 0 — nothing to compare it against)`);
  }

  // 8 — alert persistence does not depend on the seller having any FCM
  // token at all (notifyUser must never throw for "0 tokens").
  {
    const uid = "phase60-s8", pid = "phase60-p8";
    // Deliberately do NOT seed a users/{uid} doc at all.
    await fireUpdate(pid, baseProduct({ sellerId: uid, stock: 10, variants: undefined }), baseProduct({ sellerId: uid, stock: 1, variants: undefined }));
    const alerts = await alertsFor(pid);
    record("s8_alert_persists_even_with_no_seller_doc_or_token",
      alerts.length === 1, `alerts=${alerts.length} (expect 1 — persistence must not depend on push delivery)`);
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
