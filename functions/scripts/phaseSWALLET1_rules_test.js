// SELLER-WALLET-1 — firestore.rules for the seller wallet, payout-account
// changes and the follows fix (functions/src/seller/sellerWallet.ts).
//  - seller_withdrawals / seller_payout_change_requests / seller_wallets:
//    owner + admin read, no client writes
//  - the legacy admin paid-transition on seller_payouts is refused while the
//    seller's bank/UPI change is pending, and for a payout in a withdrawal
//  - follows: a buyer can get their own {uid}_{sellerId} id before it exists;
//    create only under that exact id
//
// Run with:
//   firebase emulators:exec --only firestore "node scripts/phaseSWALLET1_rules_test.js"
const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const { serverTimestamp, Timestamp } = require("firebase/firestore");

const [EMU_HOST, EMU_PORT] = (process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080").split(":");
const base = { admin: false, seller: false, delivery_partner: false, employee: false };
const ADMIN_CLAIMS = { ...base, role: "admin", admin: true };
const SELLER_CLAIMS = { ...base, role: "seller", seller: true };
const ADMIN = "sw-admin", S1 = "sw-seller1", S2 = "sw-seller2", HELD = "sw-held", BUYER = "sw-buyer";

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

async function main() {
  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
  testEnv = await initializeTestEnvironment({ projectId: "demo-swallet1-rules", firestore: { rules, host: EMU_HOST, port: Number(EMU_PORT) } });
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (c) => {
    const f = c.firestore();
    await f.doc(`users/${ADMIN}`).set({ role: "admin" });
    for (const s of [S1, S2, HELD]) {
      await f.doc(`users/${s}`).set({ role: "seller", sellerStatus: "approved" });
      await f.doc(`seller_payouts/${s}_p`).set({ sellerId: s, orderId: "o", netAmount: 100, status: "pending" });
    }
    await f.doc(`seller_wallets/${HELD}`).set({ sellerId: HELD, payoutChangePending: "req-1" });
    await f.doc(`seller_wallets/${S1}`).set({ sellerId: S1, payoutChangePending: null, openWithdrawal: null });
    await f.doc(`seller_payouts/${S1}_inw`).set({ sellerId: S1, orderId: "o2", netAmount: 50, status: "pending", withdrawalId: "w-x" });
    await f.doc(`seller_withdrawals/w-1`).set({ sellerId: S1, status: "requested", amountPaise: 10000 });
    await f.doc(`seller_payout_change_requests/c-1`).set({ sellerId: S1, status: "pending", payoutMethod: "upi", upiId: "a@okbank" });
    await f.doc(`users/${BUYER}`).set({ role: "customer" });
  });
  const adm = testEnv.authenticatedContext(ADMIN, ADMIN_CLAIMS).firestore();
  const s1 = testEnv.authenticatedContext(S1, SELLER_CLAIMS).firestore();
  const s2 = testEnv.authenticatedContext(S2, SELLER_CLAIMS).firestore();
  const buyer = testEnv.authenticatedContext(BUYER, base).firestore();
  const paid = () => ({ status: "paid", paidAt: Timestamp.now(), paymentReference: "UTR123456", paidBy: ADMIN, payoutMethod: "bank", updatedAt: serverTimestamp() });

  await scenario("r01_seller_reads_own_withdrawal", "allow", () => s1.doc("seller_withdrawals/w-1").get());
  await scenario("r02_other_seller_cannot_read_it", "deny", () => s2.doc("seller_withdrawals/w-1").get());
  await scenario("r03_admin_reads_withdrawal", "allow", () => adm.doc("seller_withdrawals/w-1").get());
  await scenario("r04_seller_cannot_create_withdrawal", "deny", () => s1.doc("seller_withdrawals/w-2").set({ sellerId: S1, status: "requested", amountPaise: 1 }));
  await scenario("r05_seller_cannot_mark_own_withdrawal_paid", "deny", () => s1.doc("seller_withdrawals/w-1").update({ status: "paid" }));
  await scenario("r06_admin_cannot_write_withdrawal_directly", "deny", () => adm.doc("seller_withdrawals/w-1").update({ status: "paid" }));
  await scenario("r07_seller_reads_own_change_request", "allow", () => s1.doc("seller_payout_change_requests/c-1").get());
  await scenario("r08_other_seller_cannot_read_change_request", "deny", () => s2.doc("seller_payout_change_requests/c-1").get());
  await scenario("r09_seller_cannot_create_change_request", "deny", () => s1.doc("seller_payout_change_requests/c-2").set({ sellerId: S1, status: "approved" }));
  await scenario("r10_seller_cannot_write_payout_details", "deny", () => s1.doc(`seller_payout_details/${S1}`).set({ upiId: "thief@okbank" }));
  await scenario("r11_seller_reads_own_wallet", "allow", () => s1.doc(`seller_wallets/${S1}`).get());
  await scenario("r12_seller_cannot_clear_pending_flag", "deny", () => s1.doc(`seller_wallets/${HELD}`).set({ payoutChangePending: null }));
  await scenario("r13_admin_pays_payout_no_change_pending", "allow", () => adm.doc(`seller_payouts/${S2}_p`).update(paid()));
  await scenario("r14_admin_pays_payout_wallet_without_pending", "allow", () => adm.doc(`seller_payouts/${S1}_p`).update(paid()));
  await scenario("r15_refused_while_bank_change_pending", "deny", () => adm.doc(`seller_payouts/${HELD}_p`).update(paid()));
  await scenario("r16_refused_for_payout_in_a_withdrawal", "deny", () => adm.doc(`seller_payouts/${S1}_inw`).update(paid()));
  await scenario("r17_buyer_gets_own_follow_before_it_exists", "allow", () => buyer.doc(`follows/${BUYER}_${S1}`).get());
  await scenario("r18_buyer_cannot_get_someone_elses_follow_id", "deny", () => buyer.doc(`follows/${S2}_${S1}`).get());
  await scenario("r19_follow_create_under_wrong_id_refused", "deny", () => buyer.doc(`follows/random-id`).set({ followerId: BUYER, sellerId: S1, createdAt: serverTimestamp() }));
  await scenario("r20_follow_create_under_own_id_allowed", "allow", () => buyer.doc(`follows/${BUYER}_${S1}`).set({ followerId: BUYER, sellerId: S1, createdAt: serverTimestamp() }));
  await scenario("r21_seller_counts_own_followers", "allow", () => s1.collection("follows").where("sellerId", "==", S1).get());

  await testEnv.cleanup();
  const failed = results.filter((x) => !x).length;
  console.log(`\n${results.length - failed}/${results.length} passed`);
  if (failed) { console.log("PHASE SWALLET1 rules: FAILED"); process.exit(1); }
  console.log("PHASE SWALLET1 rules: ALL PASSED"); process.exit(0);
}
main().catch((e) => { console.error(e); process.exit(1); });
