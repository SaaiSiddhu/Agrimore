// ============================================================
//  Phase SELLER-CATALOGUE-2 — variants reach checkout: price, stock, record
// ============================================================
//
// Run with: JAVA_HOME=/opt/homebrew/opt/openjdk@21 firebase emulators:exec
//             --only firestore "node scripts/phaseSCAT2_variant_checkout_test.js"

process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: "agrimore-66a4e" });
const db = admin.firestore();
const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { createOrder } = require("../lib/customer/createOrder");
const { normalizeOrderItems } = require("../lib/customer/orderPricing");
const { computeCartFingerprint } = require("../lib/customer/productCreditHold");
const wrapped = test.wrap(createOrder);

const ADDRESS = {
  name: "Test User", phone: "9999999999", addressLine1: "1 Main St", addressLine2: "Near the market",
  city: "Chennai", state: "TN", zipcode: "600001", country: "India", latitude: 13.08, longitude: 80.27,
  addressType: "home", landmark: "Opposite the bank",
};
const order = (items) => ({
  items, orderMode: "B2C", deliveryAddress: ADDRESS, paymentMethod: "cod", deliveryCharge: 0, tax: 0,
  notes: "", deliverySlot: "morning", orderType: "One Time",
});

async function main() {
  const results = {};
  const check = async (name, fn) => {
    try { await fn(); results[name] = "PASSED"; } catch (e) { results[name] = `FAILED — ${e.message}`; }
    console.log(`${name}: ${results[name]}`);
  };
  const expect = (cond, msg) => { if (!cond) throw new Error(msg); };
  const call = async (payload, uid) => {
    try { return { ok: true, r: await wrapped({ data: payload, auth: { uid, token: {} } }) }; }
    catch (e) { return { ok: false, code: e.code, message: e.message }; }
  };
  const lastOrderItems = async (uid) => {
    const snap = await db.collection("orders").where("userId", "==", uid).get();
    const docs = snap.docs.sort((a, b) => (b.data().createdAt?.toMillis?.() ?? 0) - (a.data().createdAt?.toMillis?.() ?? 0));
    return docs[0].data();
  };

  const U = "scat2-buyer";
  await db.doc(`users/${U}`).set({ uid: U, profileCompleted: true });
  await db.doc("sellers/scat2-seller").set({ status: "approved", shopName: "S" });
  await db.doc("products/scat2-rice").set({
    name: "Rice", salePrice: 100, stock: 50, sellerId: "scat2-seller", images: ["base.jpg"], isB2BEnabled: false,
    variants: [
      { id: "v1kg", name: "1 kg", salePrice: 100, stock: 10, images: [] },
      { id: "v5kg", name: "5 kg", salePrice: 450, stock: 3, images: ["5kg.jpg"] },
      { name: "10 kg", price: 850, stock: 2 }, // legacy: no id, `price` field
    ],
  });

  await check("c1_variant_price_and_record", async () => {
    const r = await call(order([{ productId: "scat2-rice", quantity: 2, variantId: "v5kg" }]), U);
    expect(r.ok, JSON.stringify(r));
    const o = await lastOrderItems(U);
    expect(o.total >= 900 && o.subtotal === 900, `subtotal ${o.subtotal}`);
    const it = o.items[0];
    expect(it.price === 450 && it.variant === "5 kg" && it.variantId === "v5kg" && it.productImage === "5kg.jpg", JSON.stringify(it));
  });

  await check("c2_variant_stock_decremented_base_untouched", async () => {
    const p = (await db.doc("products/scat2-rice").get()).data();
    expect(p.variants[1].stock === 1, `5 kg stock ${p.variants[1].stock}`);
    expect(p.stock === 50, `base stock ${p.stock}`);
    expect(p.soldCount === 2, `soldCount ${p.soldCount}`);
  });

  await check("c3_two_variants_one_cart", async () => {
    const r = await call(order([
      { productId: "scat2-rice", quantity: 1, variantId: "v1kg" },
      { productId: "scat2-rice", quantity: 1, variantId: "v5kg" },
    ]), U);
    expect(r.ok, JSON.stringify(r));
    const o = await lastOrderItems(U);
    expect(o.items.length === 2 && o.subtotal === 550, JSON.stringify(o.items.map((i) => [i.variant, i.price])));
    const p = (await db.doc("products/scat2-rice").get()).data();
    expect(p.variants[0].stock === 9 && p.variants[1].stock === 0, JSON.stringify(p.variants.map((v) => v.stock)));
  });

  await check("c4_legacy_variant_matched_by_name", async () => {
    const r = await call(order([{ productId: "scat2-rice", quantity: 1, variantId: "10 kg" }]), U);
    expect(r.ok, JSON.stringify(r));
    const o = await lastOrderItems(U);
    expect(o.items[0].price === 850 && o.items[0].variant === "10 kg", JSON.stringify(o.items[0]));
  });

  await check("c5_over_variant_stock_refused", async () => {
    const r = await call(order([{ productId: "scat2-rice", quantity: 1, variantId: "v5kg" }]), U);
    expect(!r.ok && r.code === "failed-precondition" && /stock/.test(r.message), JSON.stringify(r));
  });

  await check("c6_unknown_variant_refused", async () => {
    const r = await call(order([{ productId: "scat2-rice", quantity: 1, variantId: "v99" }]), U);
    expect(!r.ok && r.code === "not-found", JSON.stringify(r));
  });

  await check("c7_no_variant_keeps_base_price_and_stock", async () => {
    const r = await call(order([{ productId: "scat2-rice", quantity: 3 }]), U);
    expect(r.ok, JSON.stringify(r));
    const o = await lastOrderItems(U);
    expect(o.items[0].price === 100 && o.items[0].variant === undefined, JSON.stringify(o.items[0]));
    expect((await db.doc("products/scat2-rice").get()).data().stock === 47, "base stock not decremented");
  });

  await check("c8_bad_variant_id_rejected", async () => {
    const r = await call(order([{ productId: "scat2-rice", quantity: 1, variantId: "x".repeat(500) }]), U);
    expect(!r.ok && r.code === "invalid-argument", JSON.stringify(r));
  });

  await check("c9_fingerprint_unchanged_for_variant_free_carts", async () => {
    const plain = normalizeOrderItems([{ productId: "a", quantity: 1 }, { productId: "b", quantity: 2 }]);
    const legacy = require("crypto").createHash("sha256").update(JSON.stringify({
      items: [{ productId: "a", quantity: 1 }, { productId: "b", quantity: 2 }], orderMode: "B2C", couponCode: null,
    })).digest("hex");
    expect(computeCartFingerprint(plain, "B2C", null) === legacy, "fingerprint changed for a plain cart");
    const v = normalizeOrderItems([{ productId: "a", quantity: 1, variantId: "x" }, { productId: "a", quantity: 1, variantId: "y" }]);
    expect(v.length === 2, "variants merged");
  });

  console.log("\n=== PHASE SELLER-CATALOGUE-2 (checkout) SUMMARY ===");
  const total = Object.keys(results).length;
  const passed = Object.values(results).filter((v) => v === "PASSED").length;
  for (const [k, v] of Object.entries(results)) console.log(`  ${v === "PASSED" ? "PASS" : "FAIL"}  ${k}`);
  console.log(`\n${passed}/${total} scenarios passed`);
  if (passed !== total) { console.error("PHASE SELLER-CATALOGUE-2: FAILED"); process.exitCode = 1; }
  else console.log("PHASE SELLER-CATALOGUE-2: ALL PASSED");
  test.cleanup();
}
main().catch((e) => { console.error("harness error", e); process.exit(1); });
