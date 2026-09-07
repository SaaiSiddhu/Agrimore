// Phase 9, Workstream 2: proves redeemReferralCode credits the caller (the
// referred user) — this is the direct proof that the referrer-credit bug
// (previously rejected by isOwner() since the write targeted
// wallets/{referrerWallet.userId}, not the caller's own uid) is fixed at
// the Firestore-write level, since the Admin SDK bypasses firestore.rules
// entirely.
//
// Phase FIX-15C (2026-09-08): Scenario 1 below used to also assert the
// referrer was credited immediately, in this same call. D-REFERRAL-TIMING
// (owner decision, 2026-09-07, implemented in FIX-15B) moved that credit to
// the referred user's first delivered order instead — see
// functions/scripts/phase43_referral_completion_test.js for that suite.
// Scenario 1 here now asserts the referrer's wallet is UNTOUCHED at
// redemption (still their starting balance) and that a referrals/{id} doc
// exists with isCompleted:false, which is what redeemReferralCode is still
// solely responsible for. Scenarios 2 and 3 are unaffected by this change.
// Run with: node scripts/phase9_referral_test.js
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { redeemReferralCode } = require("../lib/customer/wallet");

const wrapped = test.wrap(redeemReferralCode);

async function callAndCapture(payload, auth) {
  try {
    const result = await wrapped({ data: payload, auth });
    return { ok: true, result };
  } catch (e) {
    return { ok: false, code: e.code, message: e.message };
  }
}

async function main() {
  const db = admin.firestore();
  let allPassed = true;
  const results = {};

  console.log("=== PHASE 9, WORKSTREAM 2 — redeemReferralCode ===");

  await db.collection("settings").doc("wallet_config").set({
    isReferralEnabled: true,
    referrerBonus: 100,
    referredBonus: 50,
  });

  const referrerUid = "phase9-referrer";
  const referredUid = "phase9-referred-customer";
  const referralCode = "PHASE9REF";

  // Phase 18 fixture update (found while running a broader regression
  // sweep than any prior phase's explicit list required): redeemReferralCode
  // has rejected an incomplete-profile caller since Phase 16, Workstream 7
  // — unrelated to what this file actually tests, so the caller is seeded
  // profileCompleted:true up front. Purely additive, no assertion below is
  // touched.
  await db.collection("users").doc(referredUid).set({ uid: referredUid, profileCompleted: true });

  await db.collection("wallets").doc(referrerUid).set({
    userId: referrerUid,
    balance: 0,
    coins: 10,
    lifetimeEarnings: 0,
    lifetimeSpent: 0,
    lifetimeCoinsEarned: 10,
    lifetimeCoinsUsed: 0,
    referralCode,
    referredBy: null,
    referralCount: 0,
    isActive: true,
    signupBonusCredited: true,
  });

  await db.collection("wallets").doc(referredUid).set({
    userId: referredUid,
    balance: 0,
    coins: 0,
    lifetimeEarnings: 0,
    lifetimeSpent: 0,
    lifetimeCoinsEarned: 0,
    lifetimeCoinsUsed: 0,
    referralCode: "REFERREDOWN",
    referredBy: null,
    referralCount: 0,
    isActive: true,
    signupBonusCredited: true,
  });

  // Scenario 1: redeeming a valid code credits the referred user's own
  // wallet immediately and opens an incomplete referrals/ record. The
  // referrer's own wallet is deliberately UNTOUCHED here (Phase FIX-15C,
  // D-REFERRAL-TIMING) — see phase43_referral_completion_test.js for the
  // suite proving the referrer is credited later, on the referred user's
  // first delivered order.
  {
    const r = await callAndCapture({ code: referralCode }, { uid: referredUid, token: {} });
    console.log("Scenario 1 raw:", JSON.stringify(r, null, 2));
    let s;
    try {
      if (!r.ok) throw new Error(`expected success, got error: code=${r.code} message=${r.message}`);

      const referredDoc = await db.collection("wallets").doc(referredUid).get();
      const referredWallet = referredDoc.data();
      if (referredWallet.coins !== 50) throw new Error(`expected referred user's coins to be 50, got ${referredWallet.coins}`);
      if (referredWallet.referredBy !== referralCode) throw new Error(`expected referredBy=${referralCode}, got ${referredWallet.referredBy}`);

      const referrerDoc = await db.collection("wallets").doc(referrerUid).get();
      const referrerWallet = referrerDoc.data();
      // Started at 10 coins. D-REFERRAL-TIMING (FIX-15B) moved the
      // referrer's own credit to completeReferralOnFirstDelivery, fired
      // only once the referred user's first order is delivered — redemption
      // itself must leave the referrer's wallet exactly as it was.
      if (referrerWallet.coins !== 10) {
        throw new Error(`expected referrer's coins to remain at their starting 10 (unpaid until first delivery), got ${referrerWallet.coins}`);
      }
      if (referrerWallet.referralCount !== 0) {
        throw new Error(`expected referrer's referralCount to remain 0 at redemption (incremented only on completion), got ${referrerWallet.referralCount}`);
      }

      const referralQuery = await db.collection("referrals")
        .where("referrerUserId", "==", referrerUid)
        .where("referredUserId", "==", referredUid)
        .get();
      if (referralQuery.empty) throw new Error("expected a referrals/ document to have been created");
      const referral = referralQuery.docs[0].data();
      if (referral.isCompleted !== false) {
        throw new Error(`expected the new referrals/ doc to be isCompleted:false at redemption, got ${referral.isCompleted}`);
      }

      s = `PASSED — referred user's own wallet credited (coins=${referredWallet.coins}); referrer's wallet left untouched at redemption (coins=${referrerWallet.coins}, referralCount=${referrerWallet.referralCount}) pending first delivery, per D-REFERRAL-TIMING; referrals/ doc created with isCompleted:false`;
    } catch (e) {
      s = `FAILED — ${e.message}`;
      allPassed = false;
    }
    results.scenario1_referred_credited_referrer_pending = s;
    console.log("Scenario 1:", s);
  }

  // Scenario 2: the SAME user redeeming a (second) code again must be
  // rejected — already referred.
  {
    const secondReferrerUid = "phase9-referrer-2";
    await db.collection("wallets").doc(secondReferrerUid).set({
      userId: secondReferrerUid,
      balance: 0,
      coins: 0,
      referralCode: "PHASE9REF2",
      referredBy: null,
      referralCount: 0,
      isActive: true,
    });

    const r = await callAndCapture({ code: "PHASE9REF2" }, { uid: referredUid, token: {} });
    console.log("Scenario 2 raw:", JSON.stringify(r, null, 2));
    let s;
    if (r.ok) {
      s = "FAILED — a user who already redeemed a referral code was able to redeem a second one";
      allPassed = false;
    } else if (r.message !== "You have already redeemed a referral code") {
      s = `FAILED — wrong message "${r.message}"`;
      allPassed = false;
    } else {
      s = `PASSED — rejected as expected. code=${r.code} message="${r.message}"`;
    }
    results.scenario2_already_referred_rejected = s;
    console.log("Scenario 2:", s);
  }

  // Scenario 3 (negative control): a user cannot redeem their own code.
  {
    const r = await callAndCapture({ code: "REFERREDOWN" }, { uid: referredUid, token: {} });
    console.log("Scenario 3 raw:", JSON.stringify(r, null, 2));
    let s;
    if (r.ok) {
      s = "FAILED — a user was able to redeem their own referral code";
      allPassed = false;
    } else {
      s = `PASSED — rejected as expected. code=${r.code} message="${r.message}"`;
    }
    results.scenario3_own_code_rejected = s;
    console.log("Scenario 3:", s);
  }

  console.log("=== PHASE 9 WORKSTREAM 2 SUMMARY ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phase9 referral test:", e);
  process.exit(1);
});
