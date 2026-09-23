// ============================================================
//  Phase SELLER-HOME-1b — quote and payout notifications reach the inbox
// ============================================================
//
// Run with: JAVA_HOME=/opt/homebrew/opt/openjdk@21 firebase emulators:exec
//             --only firestore "node scripts/phaseSHOME1B_notify_test.js"

process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });
const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { createRfq, submitRfqOffer, respondToRfqOffer } = require("../lib/customer/rfq");
const { notifySellerPayoutPaid } = require("../lib/seller/payoutNotifications");

const create = test.wrap(createRfq);
const offer = test.wrap(submitRfqOffer);
const respond = test.wrap(respondToRfqOffer);
const payoutPaid = test.wrap(notifySellerPayoutPaid);

const BUYER = "shome1b-buyer";
const SELLER = "shome1b-seller";
const auth = (uid) => ({ uid, token: {} });

async function main() {
  const db = admin.firestore();
  const results = {};
  const check = async (name, fn) => {
    try { await fn(); results[name] = "PASSED"; } catch (e) { results[name] = `FAILED — ${e.message}`; }
    console.log(`${name}: ${results[name]}`);
  };
  const expect = (cond, msg) => { if (!cond) throw new Error(msg); };
  const inbox = async (uid, type) =>
    (await db.collection("users").doc(uid).collection("notifications").where("type", "==", type).get()).docs.map((d) => d.data());

  // No fcmTokens: notifyUser writes the inbox entry and sends nothing.
  await db.collection("users").doc(BUYER).set({ name: "Priya", businessName: "Priya Traders" });
  await db.collection("users").doc(SELLER).set({ name: "Ravi" });
  await db.collection("products").doc("shome1b-p").set({ name: "Basmati Rice 25kg", sellerId: SELLER, isB2BEnabled: true, b2bPrice: 1800 });

  let rfqId;
  await check("n1_new_quote_request_notifies_seller", async () => {
    const r = await create({ data: { productId: "shome1b-p", quantity: 20, proposedPrice: 1700 }, auth: auth(BUYER) });
    rfqId = r.rfqId;
    const n = await inbox(SELLER, "rfq_new");
    expect(n.length === 1, `got ${n.length}`);
    expect(n[0].data.actionUrl === `rfq/${rfqId}` && n[0].unread === true, JSON.stringify(n[0]));
    expect(n[0].body.includes("Priya Traders") && n[0].body.includes("Basmati"), n[0].body);
    expect((await inbox(BUYER, "rfq_new")).length === 0, "buyer notified of own request");
  });

  await check("n2_counter_notifies_the_other_party", async () => {
    await offer({ data: { rfqId, price: 1750, quantity: 20, validForDays: 3 }, auth: auth(SELLER) });
    const n = await inbox(BUYER, "rfq_offer");
    expect(n.length === 1 && n[0].body.includes("3 days"), JSON.stringify(n));
    expect((await inbox(SELLER, "rfq_offer")).length === 0, "seller notified of own offer");
  });

  await check("n3_accept_notifies_the_offerer", async () => {
    await respond({ data: { rfqId, action: "accept" }, auth: auth(BUYER) });
    const n = await inbox(SELLER, "rfq_accepted");
    expect(n.length === 1, `got ${n.length}`);
  });

  await check("n4_decline_carries_the_reason", async () => {
    const r = await create({ data: { productId: "shome1b-p", quantity: 5, proposedPrice: 900 }, auth: auth(BUYER) });
    await respond({ data: { rfqId: r.rfqId, action: "reject", reason: "Price is too low" }, auth: auth(SELLER) });
    const n = await inbox(BUYER, "rfq_declined");
    expect(n.length === 1 && n[0].body.includes("Price is too low"), JSON.stringify(n));
  });

  const payout = { sellerId: SELLER, orderId: "o1", orderNumber: "ORD-9", netAmount: 450, status: "pending" };
  const snap = (id, data) => test.firestore.makeDocumentSnapshot(data, `seller_payouts/${id}`);

  await check("n5_payout_paid_notifies_seller", async () => {
    await payoutPaid(test.makeChange(snap("p1", payout), snap("p1", { ...payout, status: "paid", paymentReference: "UTR12345" })),
      { params: { payoutId: "p1" } });
    const n = await inbox(SELLER, "payout_paid");
    expect(n.length === 1 && n[0].body.includes("UTR12345") && n[0].body.includes("450.00"), JSON.stringify(n));
    expect(n[0].data.actionUrl === "payout/p1", JSON.stringify(n[0].data));
  });

  await check("n6_other_payout_updates_are_silent", async () => {
    await payoutPaid(test.makeChange(snap("p2", payout), snap("p2", { ...payout, note: "x" })), { params: { payoutId: "p2" } });
    const paid = { ...payout, status: "paid", paymentReference: "UTR1" };
    await payoutPaid(test.makeChange(snap("p3", paid), snap("p3", { ...paid, updatedAt: 1 })), { params: { payoutId: "p3" } });
    expect((await inbox(SELLER, "payout_paid")).length === 1, "extra payout notification");
  });

  await check("n7_negotiation_still_succeeds_without_a_user_doc", async () => {
    await db.collection("products").doc("shome1b-p2").set({ name: "Oil", sellerId: "shome1b-ghost", isB2BEnabled: true });
    const r = await create({ data: { productId: "shome1b-p2", quantity: 1 }, auth: auth(BUYER) });
    expect(typeof r.rfqId === "string", JSON.stringify(r));
  });

  console.log("\n=== PHASE SELLER-HOME-1b (notify) SUMMARY ===");
  const total = Object.keys(results).length;
  const passed = Object.values(results).filter((v) => v === "PASSED").length;
  for (const [k, v] of Object.entries(results)) console.log(`  ${v === "PASSED" ? "PASS" : "FAIL"}  ${k}`);
  console.log(`\n${passed}/${total} scenarios passed`);
  if (passed !== total) { console.error("PHASE SELLER-HOME-1b (notify): FAILED"); process.exitCode = 1; }
  else console.log("PHASE SELLER-HOME-1b (notify): ALL PASSED");
  test.cleanup();
}
main().catch((e) => { console.error("harness error", e); process.exit(1); });
