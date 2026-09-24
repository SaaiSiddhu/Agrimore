// Phase DLV-K1 — firestore.rules for chat threads (audit G17).
// Parties are fixed at creation and bound to the caller and, for an order
// thread, to the order; a party can only move the last-message summary; a
// message's sender is the caller.
// Run with:
//   firebase emulators:exec --only firestore "node scripts/phaseDLVK1_thread_rules_test.js"
const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const { serverTimestamp } = require("firebase/firestore");

const [EMU_HOST, EMU_PORT] = (process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080").split(":");
const base = { admin: false, seller: false, delivery_partner: false, employee: false };
const C = "k1-cust", S = "k1-seller", R = "k1-rider", R2 = "k1-rider2", X = "k1-outsider", ADMIN = "k1-admin", S2 = "k1-seller2";
const CLAIMS = {
  [C]: { ...base, role: "user" }, [X]: { ...base, role: "user" },
  [S]: { ...base, role: "seller", seller: true }, [S2]: { ...base, role: "seller", seller: true },
  [R]: { ...base, role: "delivery_partner", delivery_partner: true }, [R2]: { ...base, role: "delivery_partner", delivery_partner: true },
  [ADMIN]: { ...base, role: "admin", admin: true },
};
let testEnv;
const results = [];
async function scenario(label, expect, fn) {
  try {
    await (expect === "allow" ? assertSucceeds(fn()) : assertFails(fn()));
    results.push(true); console.log(`PASSED — ${label}`);
  } catch (e) {
    results.push(false); console.log(`FAILED — ${label} :: expected ${expect} — ${String(e.message || e).slice(0, 160)}`);
  }
}
const as = (uid) => testEnv.authenticatedContext(uid, CLAIMS[uid]).firestore();

async function main() {
  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
  testEnv = await initializeTestEnvironment({ projectId: "demo-dlvk1-rules", firestore: { rules, host: EMU_HOST, port: Number(EMU_PORT) } });
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (c) => {
    const f = c.firestore();
    await f.doc(`users/${ADMIN}`).set({ role: "admin" });
    for (const u of [C, X]) await f.doc(`users/${u}`).set({ role: "user" });
    for (const u of [S, S2]) await f.doc(`users/${u}`).set({ role: "seller" });
    for (const u of [R, R2]) await f.doc(`users/${u}`).set({ role: "delivery_partner" });
    await f.doc("orders/o1").set({ userId: C, sellerId: S, deliveryPartnerId: R, orderStatus: "out_for_delivery" });
    await f.doc("orders/o2").set({ userId: C, sellerId: S, orderStatus: "confirmed" });
    await f.doc("threads/o1_seller_customer").set({ orderId: "o1", customerId: C, sellerId: S, participantIds: [C, S], type: "seller_customer", lastMessage: "" });
    await f.doc(`threads/${C}_${S}`).set({ customerId: C, sellerId: S, lastMessage: "", unreadCount: 0 });
    await f.doc("threads/o1_seller_customer/messages/m0").set({ senderId: S, text: "hello", isSeller: true });
  });
  const T = "threads/o1_seller_customer";
  await scenario("k01_party_reads_thread", "allow", () => as(C).doc(T).get());
  await scenario("k02_outsider_cannot_read", "deny", () => as(X).doc(T).get());
  await scenario("k03_party_cannot_add_outsider", "deny", () => as(C).doc(T).update({ participantIds: [C, S, X] }));
  await scenario("k04_party_cannot_swap_the_seller", "deny", () => as(C).doc(`threads/${C}_${S}`).update({ sellerId: X }));
  await scenario("k05_party_moves_last_message", "allow", () => as(C).doc(T).update({ lastMessage: "hi", lastMessageTime: serverTimestamp(), lastSenderId: C, updatedAt: serverTimestamp() }));
  await scenario("k06_outsider_cannot_open_thread_naming_others", "deny", () => as(X).doc(`threads/${C}_${X}`).set({ customerId: C, sellerId: X, participantIds: [C, X] }));
  await scenario("k07_outsider_cannot_join_an_order_as_its_rider", "deny", () => as(X).doc("threads/o1_rider_customer").set({ orderId: "o1", customerId: C, deliveryPartnerId: X, participantIds: [C, X] }));
  await scenario("k08_seller_opens_thread_for_own_order", "allow", () => as(S).doc("threads/o2_seller_customer").set({ orderId: "o2", orderNumber: "ORD-2", customerId: C, sellerId: S, participantIds: [C, S], type: "seller_customer", createdAt: serverTimestamp(), updatedAt: serverTimestamp() }));
  await scenario("k08b_other_seller_cannot_for_that_order", "deny", () => as(S2).doc("threads/o2_other").set({ orderId: "o2", customerId: C, sellerId: S2, participantIds: [C, S2] }));
  await scenario("k09_customer_asks_a_seller", "allow", () => as(C).doc(`threads/${C}_${S2}`).set({ customerId: C, sellerId: S2, lastMessage: "", unreadCount: 0 }));
  await scenario("k09b_orderless_id_must_be_customer_seller", "deny", () => as(C).doc("threads/anything").set({ customerId: C, sellerId: S2 }));
  await scenario("k09c_participants_limited_to_parties", "deny", () => as(C).doc(`threads/${C}_${X}`).set({ customerId: C, sellerId: X, participantIds: [C, X, R] }));
  await scenario("k10_rider_of_the_order_opens_rider_thread", "allow", () => as(R).doc("threads/o1_rider_customer").set({ orderId: "o1", customerId: C, deliveryPartnerId: R, participantIds: [C, R] }));
  await scenario("k10b_another_rider_cannot", "deny", () => as(R2).doc("threads/o1_rider_customer2").set({ orderId: "o1", customerId: C, deliveryPartnerId: R2, participantIds: [C, R2] }));
  const msg = (extra) => ({ senderId: C, text: "Is it on the way?", isSeller: false, timestamp: serverTimestamp(), read: false, ...extra });
  await scenario("k11_party_sends_as_self", "allow", () => as(C).collection(`${T}/messages`).add(msg({})));
  await scenario("k12_party_cannot_send_as_the_other_party", "deny", () => as(C).collection(`${T}/messages`).add(msg({ senderId: S })));
  await scenario("k13_customer_cannot_claim_isSeller", "deny", () => as(C).collection(`${T}/messages`).add(msg({ isSeller: true })));
  await scenario("k13b_seller_is_seller", "allow", () => as(S).collection(`${T}/messages`).add(msg({ senderId: S, isSeller: true })));
  await scenario("k14_outsider_cannot_post", "deny", () => as(X).collection(`${T}/messages`).add(msg({ senderId: X })));
  await scenario("k15_messages_are_never_edited", "deny", () => as(S).doc(`${T}/messages/m0`).update({ text: "edited" }));
  await scenario("k16_empty_text_refused", "deny", () => as(C).collection(`${T}/messages`).add(msg({ text: "" })));
  await scenario("k16b_overlong_text_refused", "deny", () => as(C).collection(`${T}/messages`).add(msg({ text: "x".repeat(2001) })));
  await scenario("k19_get_of_a_thread_not_made_yet", "allow", () => as(S).doc("threads/o9_seller_customer").get());
  await scenario("k19b_outsider_still_cannot_list_threads", "deny", () => as(X).collection("threads").get());
  await scenario("k17_admin_reads", "allow", () => as(ADMIN).doc(T).get());
  await scenario("k18_outsider_cannot_read_messages", "deny", () => as(X).collection(`${T}/messages`).get());

  await testEnv.cleanup();
  const failed = results.filter((x) => !x).length;
  console.log(`\n${results.length - failed}/${results.length} passed`);
  if (failed) { console.log("PHASE DLV-K1 rules: FAILED"); process.exit(1); }
  console.log("PHASE DLV-K1 rules: ALL PASSED"); process.exit(0);
}
main().catch((e) => { console.error(e); process.exit(1); });
