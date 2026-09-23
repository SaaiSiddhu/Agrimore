// ============================================================
//  Phase SELLER-RFQ-2 — quote validity, display snapshots, decline reason
// ============================================================
//
// Run with: JAVA_HOME=/opt/homebrew/opt/openjdk@21 firebase emulators:exec
//             --only firestore "node scripts/phaseSRFQ2_quote_test.js"

process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });
const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { createRfq, submitRfqOffer, respondToRfqOffer, DEFAULT_VALID_DAYS } = require("../lib/customer/rfq");

const create = test.wrap(createRfq);
const offer = test.wrap(submitRfqOffer);
const respond = test.wrap(respondToRfqOffer);
const DAY = 24 * 60 * 60 * 1000;

const BUYER = "srfq2-buyer";
const SELLER = "srfq2-seller";
const auth = (uid) => ({ uid, token: {} });

async function call(fn, data, uid) {
  try { return { ok: true, result: await fn({ data, auth: auth(uid) }) }; }
  catch (e) { return { ok: false, code: e.code, message: e.message }; }
}

async function main() {
  const db = admin.firestore();
  const results = {};
  const check = async (name, fn) => {
    try { await fn(); results[name] = "PASSED"; } catch (e) { results[name] = `FAILED — ${e.message}`; }
    console.log(`${name}: ${results[name]}`);
  };
  const expect = (cond, msg) => { if (!cond) throw new Error(msg); };
  const rfqOf = async (id) => (await db.collection("rfqs").doc(id).get()).data();

  await db.collection("products").doc("srfq2-p1").set({
    name: "Basmati Rice 25kg", sellerId: SELLER, isB2BEnabled: true, b2bPrice: 1800, b2bMoq: 10,
    images: ["https://img/1.jpg"], unit: "bag", price: 2000,
  });
  await db.collection("users").doc(BUYER).set({
    name: "Priya", businessName: "Priya Traders", phone: "+919999999999", email: "p@x.in", address: "4 Lake Rd",
  });

  let rfqId;
  await check("t1_create_snapshots_product_and_buyer_name_only", async () => {
    const r = await call(create, { productId: "srfq2-p1", quantity: 20, proposedPrice: 1700 }, BUYER);
    expect(r.ok, JSON.stringify(r));
    rfqId = r.result.rfqId;
    const d = await rfqOf(rfqId);
    expect(d.product.name === "Basmati Rice 25kg" && d.product.imageUrl === "https://img/1.jpg", JSON.stringify(d.product));
    expect(d.product.b2bPrice === 1800 && d.product.b2bMoq === 10 && d.product.unit === "bag", JSON.stringify(d.product));
    expect(d.buyer.name === "Priya" && d.buyer.businessName === "Priya Traders", JSON.stringify(d.buyer));
    expect(Object.keys(d.buyer).sort().join(",") === "businessName,name", `buyer leaks: ${Object.keys(d.buyer)}`);
  });

  await check("t2_buyer_offer_gets_default_validity", async () => {
    const d = await rfqOf(rfqId);
    const ms = d.lastOffer.expiresAt.toMillis() - Date.now();
    expect(Math.abs(ms - DEFAULT_VALID_DAYS * DAY) < 60_000, `expiresAt off by ${ms}`);
  });

  await check("t3_counter_with_custom_validity", async () => {
    const r = await call(offer, { rfqId, price: 1750, quantity: 20, validForDays: 3 }, SELLER);
    expect(r.ok, JSON.stringify(r));
    const d = await rfqOf(rfqId);
    const ms = d.lastOffer.expiresAt.toMillis() - Date.now();
    expect(Math.abs(ms - 3 * DAY) < 60_000, `expiresAt off by ${ms}`);
  });

  await check("t4_validity_out_of_range_rejected", async () => {
    for (const v of [0, 31, 2.5, "7"]) {
      const r = await call(offer, { rfqId, price: 1760, quantity: 20, validForDays: v }, BUYER);
      expect(!r.ok && r.code === "invalid-argument", `validForDays=${v}: ${JSON.stringify(r)}`);
    }
  });

  await check("t5_expired_offer_cannot_be_accepted", async () => {
    await db.collection("rfqs").doc(rfqId).update({
      "lastOffer.expiresAt": admin.firestore.Timestamp.fromMillis(Date.now() - DAY),
    });
    const r = await call(respond, { rfqId, action: "accept" }, BUYER);
    expect(!r.ok && r.code === "failed-precondition" && /expired/.test(r.message), JSON.stringify(r));
    expect((await rfqOf(rfqId)).status === "negotiating", "status changed");
  });

  await check("t6_expired_offer_can_still_be_countered", async () => {
    const r = await call(offer, { rfqId, price: 1740, quantity: 20 }, BUYER);
    expect(r.ok, JSON.stringify(r));
    const d = await rfqOf(rfqId);
    expect(d.lastOffer.expiresAt.toMillis() > Date.now(), "counter did not renew validity");
  });

  await check("t7_valid_offer_accepts", async () => {
    const r = await call(respond, { rfqId, action: "accept" }, SELLER);
    expect(r.ok, JSON.stringify(r));
    const d = await rfqOf(rfqId);
    expect(d.status === "accepted" && d.finalPrice === 1740, JSON.stringify(d));
  });

  await check("t8_legacy_offer_without_expiry_accepts", async () => {
    await db.collection("rfqs").doc("srfq2-legacy").set({
      id: "srfq2-legacy", buyerId: BUYER, sellerId: SELLER, productId: "srfq2-p1", status: "negotiating",
      awaitingResponseFrom: "seller", lastOffer: { price: 1500, quantity: 10, by: "buyer", notes: null },
      history: [],
    });
    const r = await call(respond, { rfqId: "srfq2-legacy", action: "accept" }, SELLER);
    expect(r.ok, JSON.stringify(r));
  });

  await check("t9_decline_records_reason", async () => {
    const c = await call(create, { productId: "srfq2-p1", quantity: 10, proposedPrice: 900 }, BUYER);
    const r = await call(respond, { rfqId: c.result.rfqId, action: "reject", reason: "Below cost price" }, SELLER);
    expect(r.ok, JSON.stringify(r));
    const d = await rfqOf(c.result.rfqId);
    const last = d.history[d.history.length - 1];
    expect(d.status === "rejected" && last.action === "reject" && last.notes === "Below cost price", JSON.stringify(last));
  });

  await check("t10_decline_reason_bounded", async () => {
    const c = await call(create, { productId: "srfq2-p1", quantity: 10, proposedPrice: 900 }, BUYER);
    const r = await call(respond, { rfqId: c.result.rfqId, action: "reject", reason: "x".repeat(501) }, SELLER);
    expect(!r.ok && r.code === "invalid-argument", JSON.stringify(r));
  });

  await check("t11_quote_without_price_has_no_expiry", async () => {
    const c = await call(create, { productId: "srfq2-p1", quantity: 10 }, BUYER);
    const d = await rfqOf(c.result.rfqId);
    expect(d.lastOffer === null, JSON.stringify(d.lastOffer));
  });

  console.log("\n=== PHASE SELLER-RFQ-2 SUMMARY ===");
  const total = Object.keys(results).length;
  const passed = Object.values(results).filter((v) => v === "PASSED").length;
  for (const [k, v] of Object.entries(results)) console.log(`  ${v === "PASSED" ? "PASS" : "FAIL"}  ${k}`);
  console.log(`\n${passed}/${total} scenarios passed`);
  if (passed !== total) { console.error("PHASE SELLER-RFQ-2: FAILED"); process.exitCode = 1; }
  else console.log("PHASE SELLER-RFQ-2: ALL PASSED");
  test.cleanup();
}
main().catch((e) => { console.error("harness error", e); process.exit(1); });
