// Phase 9, Workstream 2: proves redeemReferralCode credits BOTH the caller
// and the referrer in one call — this is the direct proof that the
// referrer-credit bug (previously rejected by isOwner() since the write
// targeted wallets/{referrerWallet.userId}, not the caller's own uid) is
// now fixed, since the Admin SDK bypasses firestore.rules entirely.
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

  // Scenario 1: redeeming a valid code credits BOTH wallets in one call.
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
      // Started at 10 coins, +100 referrer bonus = 110. Under the OLD
      // direct-write code, this write was rejected by isOwner() and the
      // referrer's coins would have stayed at 10 forever.
      if (referrerWallet.coins !== 110) {
        throw new Error(`expected referrer's coins to be 110 (10 starting + 100 bonus), got ${referrerWallet.coins} — REFERRER BUG NOT FIXED`);
      }
      if (referrerWallet.referralCount !== 1) throw new Error(`expected referrer's referralCount to be 1, got ${referrerWallet.referralCount}`);

      const referralQuery = await db.collection("referrals")
        .where("referrerUserId", "==", referrerUid)
        .where("referredUserId", "==", referredUid)
        .get();
      if (referralQuery.empty) throw new Error("expected a referrals/ document to have been created");

      s = `PASSED — BOTH wallets credited in one call. referred.coins=${referredWallet.coins}, referrer.coins=${referrerWallet.coins} (was 10, +100 bonus — proves the referrer-credit bug is fixed), referrer.referralCount=${referrerWallet.referralCount}`;
    } catch (e) {
      s = `FAILED — ${e.message}`;
      allPassed = false;
    }
    results.scenario1_both_wallets_credited = s;
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
