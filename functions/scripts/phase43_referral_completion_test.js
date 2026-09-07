// Phase FIX-15B: proves D-REFERRAL-TIMING's actual behaviour — the referrer
// is paid only on the referred user's first delivered order, never at
// redemption.
//
// INVOCATION STYLE. redeemReferralCode is a v2 onCall, invoked via
// test.wrap() as `wrapped({data, auth})` — the same pattern FIX-8's own
// phase42 suite already established as safe for a v2 onCall this session.
//
// completeReferralOnFirstDelivery is a v1 Firestore trigger. This suite
// invokes it via test.wrap() called OFFLINE as `wrapped(change, context)`
// (test.firestore.makeDocumentSnapshot() + test.makeChange()) — mirroring
// functions/scripts/phase16d1_commission_test.js's own established,
// working precedent for payEmployeeCommissionOnDelivery, the closest
// analogous v1 delivery-triggered trigger in this codebase. This calls the
// REAL compiled handler directly in this process; every Firestore
// read/write inside it still hits the REAL Firestore emulator — it is not
// a re-implementation of the trigger's logic, only a bypass of the
// Functions emulator's own live background-dispatch mechanism (which
// phase16d1's own header comment documents as unreliable under a
// concurrent-session load, and which is unrelated to whether the pattern
// is genuine evidence of the handler's own behaviour).
//
// CORRECTION to this phase's own earlier claim/build notes: those notes
// said test.wrap() "crashes v1 background functions" and planned to use a
// genuine live-write to trigger this function instead. That over-
// generalized the P0-FIELDVALUE investigation's actual finding, which was
// specifically about admin.firestore.FieldValue NAMESPACE access crashing
// under the live dispatch path (fixed everywhere by the modular FieldValue
// import, including in this phase's own new trigger) — not about
// test.wrap()'s OFFLINE invocation mode being unsafe. phase16d1's own
// working suite, invoking the SAME class of v1 delivery trigger via
// test.wrap(), is direct proof this pattern is safe and correct here.
// Corrected before writing a single line of this file, not after a
// failure.
//
// Run with:
//   firebase emulators:exec --only firestore,functions,auth \
//     "node scripts/phase43_referral_completion_test.js"
// Requires: functions already built (npm run build).
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });
const db = admin.firestore();

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { redeemReferralCode, completeReferralOnFirstDelivery } = require("../lib/customer/wallet");

const wrappedRedeem = test.wrap(redeemReferralCode);
const wrappedComplete = test.wrap(completeReferralOnFirstDelivery);

async function fireDeliveryTransition(orderId, beforeData, afterData) {
  const beforeSnap = test.firestore.makeDocumentSnapshot(beforeData, `orders/${orderId}`);
  const afterSnap = test.firestore.makeDocumentSnapshot(afterData, `orders/${orderId}`);
  const change = test.makeChange(beforeSnap, afterSnap);
  return wrappedComplete(change, { params: { orderId } });
}

let failures = 0;
function check(label, condition, extra) {
  if (condition) {
    console.log(`PASSED — ${label}`);
  } else {
    failures++;
    console.log(`FAILED — ${label}`);
    if (extra !== undefined) console.log("  detail:", JSON.stringify(extra, null, 2));
  }
}

async function seedWalletConfig() {
  await db.collection("settings").doc("wallet_config").set({
    isReferralEnabled: true,
    referrerBonus: 100,
    referredBonus: 50,
  });
}

async function seedUserAndWallet(uid, { referralCode } = {}) {
  await db.collection("users").doc(uid).set({ uid, profileCompleted: true, role: "customer" });
  const walletDoc = { userId: uid, balance: 0, coins: 0, lifetimeEarnings: 0, lifetimeCoinsEarned: 0 };
  if (referralCode) walletDoc.referralCode = referralCode;
  await db.collection("wallets").doc(uid).set(walletDoc);
}

function baseOrder(userId, overrides = {}) {
  return {
    userId,
    orderNumber: `ORD-${userId}`,
    items: [],
    subtotal: 500,
    total: 500,
    paymentMethod: "cod",
    paymentStatus: "pending",
    orderStatus: "pending",
    status: "pending",
    orderMode: "B2C",
    ...overrides,
  };
}

async function main() {
  console.log("=== Phase FIX-15B referral completion verification ===\n");
  await seedWalletConfig();

  // ------------------------------------------------------------
  // Scenario 1: redemption itself. The referred user gets their own bonus
  // immediately; the referrer gets NOTHING yet — no coins credited, no
  // wallet_transactions doc for them, isCompleted:false.
  // ------------------------------------------------------------
  const referrer1 = "p43-referrer-1";
  const referred1 = "p43-referred-1";
  await seedUserAndWallet(referrer1, { referralCode: "REF-P43-1" });
  await seedUserAndWallet(referred1);

  await wrappedRedeem({
    data: { code: "REF-P43-1" },
    auth: { uid: referred1, token: {} },
  });

  const referrerWalletAfterRedeem = await db.collection("wallets").doc(referrer1).get();
  const referredWalletAfterRedeem = await db.collection("wallets").doc(referred1).get();
  check(
    "REDEMPTION: referred user's own wallet is credited immediately (50 coins)",
    referredWalletAfterRedeem.data().coins === 50,
    referredWalletAfterRedeem.data()
  );
  check(
    "REDEMPTION: referrer's wallet is NOT credited at redemption time (still 0 coins)",
    referrerWalletAfterRedeem.data().coins === 0,
    referrerWalletAfterRedeem.data()
  );
  const referrerTxAtRedeem = await db
    .collection("wallet_transactions")
    .where("userId", "==", referrer1)
    .where("source", "==", "referral")
    .get();
  check(
    "REDEMPTION: no wallet_transactions doc exists yet for the referrer",
    referrerTxAtRedeem.empty,
    { count: referrerTxAtRedeem.size }
  );
  const referralDocsForReferred1 = await db.collection("referrals").where("referredUserId", "==", referred1).get();
  check(
    "REDEMPTION: exactly one referrals doc created, isCompleted:false",
    referralDocsForReferred1.size === 1 && referralDocsForReferred1.docs[0].data().isCompleted === false,
    referralDocsForReferred1.docs.map((d) => d.data())
  );

  // ------------------------------------------------------------
  // Scenario 2: the referred user's first delivered order completes the
  // referral and pays the referrer exactly once.
  // ------------------------------------------------------------
  const orderId1 = "p43-order-1";
  const before1 = baseOrder(referred1, { orderStatus: "pending", status: "pending" });
  const after1 = { ...before1, orderStatus: "delivered", status: "delivered" };
  await db.collection("orders").doc(orderId1).set(before1);
  await fireDeliveryTransition(orderId1, before1, after1);

  const referrerWalletAfterDelivery = await db.collection("wallets").doc(referrer1).get();
  check(
    "FIRST DELIVERY: referrer is now credited exactly the configured referrerBonus (100 coins)",
    referrerWalletAfterDelivery.data().coins === 100,
    referrerWalletAfterDelivery.data()
  );
  check(
    "FIRST DELIVERY: referrer's referralCount incremented to 1",
    referrerWalletAfterDelivery.data().referralCount === 1,
    referrerWalletAfterDelivery.data()
  );
  const referrerTxAfterDelivery = await db
    .collection("wallet_transactions")
    .where("userId", "==", referrer1)
    .where("source", "==", "referral")
    .get();
  check(
    "FIRST DELIVERY: exactly one wallet_transactions doc created for the referrer",
    referrerTxAfterDelivery.size === 1 && referrerTxAfterDelivery.docs[0].data().coins === 100,
    referrerTxAfterDelivery.docs.map((d) => d.data())
  );
  const referralAfterDelivery = await db.collection("referrals").doc(referralDocsForReferred1.docs[0].id).get();
  check(
    "FIRST DELIVERY: referral doc is now isCompleted:true with a completedAt timestamp",
    referralAfterDelivery.data().isCompleted === true && referralAfterDelivery.data().completedAt !== null,
    referralAfterDelivery.data()
  );

  // ------------------------------------------------------------
  // Scenario 3: a SECOND delivered order for the same referred user must
  // NOT double-credit the referrer — the idempotency re-check inside the
  // transaction (isCompleted already true) must refuse it.
  // ------------------------------------------------------------
  const orderId2 = "p43-order-2";
  const before2 = baseOrder(referred1, { orderStatus: "pending", status: "pending" });
  const after2 = { ...before2, orderStatus: "delivered", status: "delivered" };
  await db.collection("orders").doc(orderId2).set(before2);
  await fireDeliveryTransition(orderId2, before2, after2);

  const referrerWalletAfterSecondOrder = await db.collection("wallets").doc(referrer1).get();
  check(
    "SECOND DELIVERY (same referred user): referrer's coins UNCHANGED (still 100, not 200)",
    referrerWalletAfterSecondOrder.data().coins === 100,
    referrerWalletAfterSecondOrder.data()
  );
  const referrerTxAfterSecondOrder = await db
    .collection("wallet_transactions")
    .where("userId", "==", referrer1)
    .where("source", "==", "referral")
    .get();
  check(
    "SECOND DELIVERY (same referred user): still exactly 1 wallet_transactions doc for the referrer (no double pay)",
    referrerTxAfterSecondOrder.size === 1,
    { count: referrerTxAfterSecondOrder.size }
  );

  // ------------------------------------------------------------
  // Scenario 4: a retried/duplicated trigger invocation of the SAME
  // already-completed transition must also refuse (re-check inside the
  // transaction, mirroring commissionPaid's own re-check pattern).
  // ------------------------------------------------------------
  await fireDeliveryTransition(orderId1, before1, after1);
  const referrerWalletAfterRetry = await db.collection("wallets").doc(referrer1).get();
  check(
    "RETRIED TRIGGER on an already-completed referral: referrer's coins still unchanged (100)",
    referrerWalletAfterRetry.data().coins === 100,
    referrerWalletAfterRetry.data()
  );

  // ------------------------------------------------------------
  // Scenario 5: a delivered order for a user with NO referral at all is a
  // cheap, safe no-op — no referrals doc touched, no wallet_transactions
  // written, no crash.
  // ------------------------------------------------------------
  const noReferralUser = "p43-no-referral-user";
  await seedUserAndWallet(noReferralUser);
  const orderId3 = "p43-order-3";
  const before3 = baseOrder(noReferralUser, { orderStatus: "pending", status: "pending" });
  const after3 = { ...before3, orderStatus: "delivered", status: "delivered" };
  await db.collection("orders").doc(orderId3).set(before3);
  await fireDeliveryTransition(orderId3, before3, after3);

  const noReferralTx = await db
    .collection("wallet_transactions")
    .where("userId", "==", noReferralUser)
    .where("source", "==", "referral")
    .get();
  check(
    "NO REFERRAL: a delivered order for a user with no referral writes no referral wallet_transactions (safe no-op)",
    noReferralTx.empty,
    { count: noReferralTx.size }
  );

  // ------------------------------------------------------------
  // Scenario 6: the referrer's wallet no longer exists at delivery time
  // (account deleted between redemption and delivery) — the referral must
  // close out (isCompleted:true) WITHOUT crediting or throwing, so a
  // retried trigger does not loop forever against a wallet that will
  // never come back.
  // ------------------------------------------------------------
  const referrer2 = "p43-referrer-2";
  const referred2 = "p43-referred-2";
  await seedUserAndWallet(referrer2, { referralCode: "REF-P43-2" });
  await seedUserAndWallet(referred2);
  await wrappedRedeem({ data: { code: "REF-P43-2" }, auth: { uid: referred2, token: {} } });
  // Simulate the referrer's account/wallet being deleted before delivery.
  await db.collection("wallets").doc(referrer2).delete();

  const orderId4 = "p43-order-4";
  const before4 = baseOrder(referred2, { orderStatus: "pending", status: "pending" });
  const after4 = { ...before4, orderStatus: "delivered", status: "delivered" };
  await db.collection("orders").doc(orderId4).set(before4);
  await fireDeliveryTransition(orderId4, before4, after4);

  const referralDocsForReferred2 = await db.collection("referrals").where("referredUserId", "==", referred2).get();
  check(
    "MISSING REFERRER WALLET: the referral still closes out to isCompleted:true (no infinite retry)",
    referralDocsForReferred2.size === 1 && referralDocsForReferred2.docs[0].data().isCompleted === true,
    referralDocsForReferred2.docs.map((d) => d.data())
  );

  console.log(`\n=== ${failures === 0 ? "ALL PASSED" : `${failures} FAILURE(S)`} ===`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((error) => {
  console.error("FATAL — unhandled error in verification script:", error);
  process.exit(1);
});
