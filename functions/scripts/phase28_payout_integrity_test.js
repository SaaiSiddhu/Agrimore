// Phase FIX-4 — proves seller payouts are idempotent, complete, correctly
// attributed and validated.
//
// N-7 (P1): the existence check and the write were a non-transactional
//   check-then-act ending in a bare .add() with a RANDOM id. v1 Firestore
//   triggers are at-least-once and can be delivered concurrently, so two
//   invocations both saw `empty` and both added — the seller was paid twice.
// N-8 (P1): fired only on the exact string "delivered" while
//   employeeCommission.ts accepts delivered AND completed. An order closed as
//   completed by apps/admin's bulk action paid the associate and created NO
//   seller_payouts document.
// N-26 (P1): sellerId was re-derived from the LIVE product document, so a
//   reassigned product paid the wrong seller and a deleted one dropped the line.
// N-28 (P1): rates were used unvalidated — NaN or a negative netAmount.
//
// calculateSellerPayout is a v1 Firestore onUpdate trigger. It is wrapped with
// firebase-functions-test's v1 `wrap`, which takes a Change object; v1 wrap
// takes (data, context) — calling it the v2 way would silently yield an empty
// context (hazards.md).
//
// Run with:
//   firebase emulators:exec --only firestore,functions \
//     "node scripts/phase28_payout_integrity_test.js"
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: "agrimore-66a4e" });
const db = admin.firestore();

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { calculateSellerPayout } = require("../lib/customer/sellerNotifications");
const wrapped = test.wrap(calculateSellerPayout);

// Builds the (before, after) Change a v1 onUpdate trigger receives.
function change(orderId, beforeData, afterData) {
  const beforeSnap = test.firestore.makeDocumentSnapshot(beforeData, `orders/${orderId}`);
  const afterSnap = test.firestore.makeDocumentSnapshot(afterData, `orders/${orderId}`);
  return test.makeChange(beforeSnap, afterSnap);
}

async function fire(orderId, beforeData, afterData) {
  return wrapped(change(orderId, beforeData, afterData), { params: { orderId } });
}

function order(items, status, total) {
  return { userId: "phase28-customer", orderNumber: "ORD-PHASE28", items, total, orderStatus: status, status };
}

const payoutsFor = (orderId) =>
  db.collection("seller_payouts").where("orderId", "==", orderId).get();

async function seedProduct(id, sellerId, categoryId) {
  const d = { name: `P ${id}`, salePrice: 100, sellerId };
  if (categoryId) d.categoryId = categoryId;
  await db.collection("products").doc(id).set(d);
}

async function main() {
  const results = {};
  let allPassed = true;
  const record = (k, p, d) => { results[k] = p; console.log(`${k}: ${p ? "PASSED" : "FAILED"} — ${d}`); if (!p) allPassed = false; };

  console.log("=== PHASE FIX-4 — payout integrity (N-7, N-8, N-26, N-28) ===");

  await db.collection("settings").doc("commission").set({ defaultRate: 10, categoryRates: {} });

  // 1 — POSITIVE CONTROL. A delivered order produces exactly one payout with
  // the right arithmetic. Without this, every assertion below could pass
  // because the trigger silently does nothing.
  {
    const oid = "phase28-o1";
    await seedProduct("phase28-p1", "phase28-seller1");
    const items = [{ productId: "phase28-p1", sellerId: "phase28-seller1", price: 100, quantity: 2 }];
    await fire(oid, order(items, "pending", 200), order(items, "delivered", 200));
    const p = await payoutsFor(oid);
    const d = p.empty ? {} : p.docs[0].data();
    record("scenario1_control_delivered_order_pays_once_correctly",
      p.size === 1 && d.grossAmount === 200 && d.commissionRate === 10 && d.netAmount === 180,
      `payouts=${p.size} gross=${d.grossAmount} rate=${d.commissionRate} net=${d.netAmount} (expect 1/200/10/180)`);
  }

  // 2 — N-7, THE FINDING. Two CONCURRENT invocations of the same transition.
  // This is what at-least-once delivery actually looks like; a sequential
  // double-call would be caught by almost any check and proves much less.
  {
    const oid = "phase28-o2";
    await seedProduct("phase28-p2", "phase28-seller2");
    const items = [{ productId: "phase28-p2", sellerId: "phase28-seller2", price: 100, quantity: 1 }];
    const before = order(items, "pending", 100);
    const after = order(items, "delivered", 100);
    await Promise.all([fire(oid, before, after), fire(oid, before, after)]);
    const p = await payoutsFor(oid);
    record("scenario2_N7_concurrent_invocations_produce_exactly_one_payout",
      p.size === 1,
      `payouts=${p.size} (expect exactly 1; pre-FIX-4 this produced 2)`);
  }

  // 3 — N-8. An order closed as "completed" (apps/admin's bulk action) must pay
  // the seller. Before FIX-4 this produced no payout document at all.
  {
    const oid = "phase28-o3";
    await seedProduct("phase28-p3", "phase28-seller3");
    const items = [{ productId: "phase28-p3", sellerId: "phase28-seller3", price: 100, quantity: 1 }];
    await fire(oid, order(items, "pending", 100), order(items, "completed", 100));
    const p = await payoutsFor(oid);
    record("scenario3_N8_completed_status_also_pays_the_seller",
      p.size === 1 && p.docs[0].data().sellerId === "phase28-seller3",
      `payouts=${p.size} seller=${p.empty ? "-" : p.docs[0].data().sellerId}`);
  }

  // 4 — N-26. The product is REASSIGNED to a different seller after the order.
  // The payout must follow the ORDER, not the product's current owner.
  {
    const oid = "phase28-o4";
    await seedProduct("phase28-p4", "phase28-NEW-owner");           // product now belongs to someone else
    const items = [{ productId: "phase28-p4", sellerId: "phase28-ORIGINAL-seller", price: 100, quantity: 1 }];
    await fire(oid, order(items, "pending", 100), order(items, "delivered", 100));
    const p = await payoutsFor(oid);
    const seller = p.empty ? "-" : p.docs[0].data().sellerId;
    record("scenario4_N26_payout_follows_the_order_not_the_reassigned_product",
      p.size === 1 && seller === "phase28-ORIGINAL-seller",
      `payouts=${p.size} seller=${seller} (must be phase28-ORIGINAL-seller, NOT phase28-NEW-owner)`);
  }

  // 5 — N-26 second half. The product is DELETED after the order. The line must
  // still be paid; before FIX-4 `if (!sellerId) continue;` dropped it silently.
  {
    const oid = "phase28-o5";
    const items = [{ productId: "phase28-DELETED", sellerId: "phase28-seller5", price: 100, quantity: 3 }];
    await fire(oid, order(items, "pending", 300), order(items, "delivered", 300));
    const p = await payoutsFor(oid);
    record("scenario5_N26_deleted_product_does_not_drop_the_payout_line",
      p.size === 1 && p.docs[0].data().grossAmount === 300,
      `payouts=${p.size} gross=${p.empty ? "-" : p.docs[0].data().grossAmount} (expect 1/300)`);
  }

  // 6 — N-28. A garbage category rate must not produce NaN or a negative
  // payout; it must fall back to the validated default.
  {
    await db.collection("settings").doc("commission").set({
      defaultRate: 10,
      categoryRates: { "phase28-bad-cat": "not-a-number" },
    });
    const oid = "phase28-o6";
    await seedProduct("phase28-p6", "phase28-seller6", "phase28-bad-cat");
    const items = [{ productId: "phase28-p6", sellerId: "phase28-seller6", price: 100, quantity: 1 }];
    await fire(oid, order(items, "pending", 100), order(items, "delivered", 100));
    const p = await payoutsFor(oid);
    const d = p.empty ? {} : p.docs[0].data();
    record("scenario6_N28_non_numeric_category_rate_falls_back_not_NaN",
      p.size === 1 && Number.isFinite(d.netAmount) && d.netAmount === 90 && d.commissionRate === 10,
      `net=${d.netAmount} rate=${d.commissionRate} (expect 90/10, never NaN)`);
  }

  // 7 — N-28. A rate above 100% is REFUSED, not clamped and not applied: a
  // negative netAmount would mean the seller owes AgriMore for making a sale.
  {
    await db.collection("settings").doc("commission").set({
      defaultRate: 10,
      categoryRates: { "phase28-huge-cat": 500 },
    });
    const oid = "phase28-o7";
    await seedProduct("phase28-p7", "phase28-seller7", "phase28-huge-cat");
    const items = [{ productId: "phase28-p7", sellerId: "phase28-seller7", price: 100, quantity: 1 }];
    await fire(oid, order(items, "pending", 100), order(items, "delivered", 100));
    const p = await payoutsFor(oid);
    const d = p.empty ? {} : p.docs[0].data();
    record("scenario7_N28_rate_above_100_percent_is_refused_not_applied",
      p.size === 1 && d.netAmount === 90 && d.commissionRate === 10,
      `net=${d.netAmount} rate=${d.commissionRate} (expect 90/10; applying 500% would give net=-400)`);
  }

  // 8 — CONTROL, the other direction: an order that did NOT transition into a
  // payout-eligible status must produce nothing. Without this, a trigger that
  // paid on every write would pass everything above.
  {
    const oid = "phase28-o8";
    await seedProduct("phase28-p8", "phase28-seller8");
    const items = [{ productId: "phase28-p8", sellerId: "phase28-seller8", price: 100, quantity: 1 }];
    await fire(oid, order(items, "pending", 100), order(items, "packing", 100));
    const p = await payoutsFor(oid);
    record("scenario8_control_non_terminal_transition_pays_nothing", p.empty,
      `payouts=${p.size} (expect 0)`);
  }

  console.log("\n=== SUMMARY ===");
  const total = Object.keys(results).length;
  const passed = Object.values(results).filter(Boolean).length;
  for (const [k, v] of Object.entries(results)) console.log(`  ${v ? "PASS" : "FAIL"}  ${k}`);
  console.log(`\n${passed}/${total} scenarios passed`);
  if (!allPassed) { console.error("PHASE 28: FAILED"); process.exit(1); }
  console.log("PHASE 28: ALL PASSED");
  process.exit(0);
}

main().catch((e) => { console.error("PHASE 28: harness error", e); process.exit(1); });
