// ============================================================
//  Wallet hardening (Finding #3): verified balance/coin mutations
// ============================================================
//
// Before this file, apps/marketplace/lib/providers/wallet_provider.dart
// wrote wallets/{userId}'s balance-bearing fields (balance, coins,
// lifetimeEarnings, lifetimeSpent, lifetimeCoinsEarned, lifetimeCoinsUsed,
// referredBy, referralCount) directly from the client, and firestore.rules'
// `wallets` collection allowed any owner to write any of them with zero
// server verification — the single most severe of the tracked findings,
// since it let any authenticated customer grant themselves unlimited wallet
// balance with no payment at all.
//
// These three callables are now the only writers of those fields (the
// Admin SDK bypasses firestore.rules; firestore.rules itself now rejects
// any client attempt to touch them directly — see the `wallets` block).
//
// verifyWalletTopup mirrors verifyRazorpayPayment's HMAC-SHA256 + live
// Razorpay API verification exactly (reusing getRazorpayCredentials from
// ./payment), then additionally cross-checks the captured amount and
// credits the wallet idempotently. redeemReferralCode also fixes a
// currently-broken feature as a side effect: applyReferralCode's referrer
// credit (`wallets/{referrerWallet.userId}`, not the caller's own uid) was
// already being rejected by `isOwner()` under the old rule, so referrers
// have never actually received their bonus. creditSignupBonus replaces the
// signup-bonus credit that used to happen via a direct client
// `_creditCoins` call inside loadWallet() when a new wallet document is
// created — that direct write is now also rejected by the locked-down
// rule, so this callable performs it instead.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as crypto from "crypto";
import axios from "axios";
import { log } from "../common/helpers";
import { getRazorpayCredentials, RAZORPAY_KEY_SECRET } from "./payment";

interface RazorpayPayment {
  id: string;
  amount: number;
  currency: string;
  status: string;
  [key: string]: any;
}

// Ports WalletConfigModel.getBonusForAmount's exact logic
// (packages/agrimore_core/lib/models/wallet_config_model.dart) server-side:
// highest threshold the amount meets or exceeds wins; falls back to the
// same hardcoded defaults WalletConfigModel.fromMap uses when
// settings/wallet_config has no topupBonuses configured yet.
function getBonusForAmount(topupBonusesRaw: unknown, amount: number): number {
  let topupBonuses: Record<string, number> =
    topupBonusesRaw && typeof topupBonusesRaw === "object"
      ? (topupBonusesRaw as Record<string, number>)
      : {};
  if (Object.keys(topupBonuses).length === 0) {
    topupBonuses = { "500": 25, "1000": 75, "2000": 200 };
  }

  const thresholds = Object.keys(topupBonuses)
    .map(Number)
    .filter((n) => !Number.isNaN(n))
    .sort((a, b) => b - a);

  for (const threshold of thresholds) {
    if (amount >= threshold) {
      return topupBonuses[String(threshold)] ?? 0;
    }
  }
  return 0;
}

interface VerifyWalletTopupData {
  amount: number;
  paymentId: string;
  orderId: string;
  signature: string;
}

export const verifyWalletTopup = onCall(
  // Phase 18, Workstream 1 / Trap 3: ONLY this function among wallet.ts's
  // three exports touches Razorpay (via getRazorpayCredentials()) —
  // redeemReferralCode and creditSignupBonus below must NOT receive this
  // grant.
  { minInstances: 0, memory: "256MiB", secrets: [RAZORPAY_KEY_SECRET] },
  async (request) => {
    const data = request.data as VerifyWalletTopupData;
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required");
    }
    const uid = request.auth.uid;

    const amount = Number(data?.amount);
    const { paymentId, orderId, signature } = data || ({} as VerifyWalletTopupData);
    if (!amount || amount <= 0) {
      throw new HttpsError("invalid-argument", "amount must be a positive number");
    }
    if (!paymentId || !orderId || !signature) {
      throw new HttpsError(
        "invalid-argument",
        "Missing Razorpay verification parameters"
      );
    }

    const { keyId: RAZORPAY_KEY_ID, keySecret: RAZORPAY_KEY_SECRET } = getRazorpayCredentials();
    if (!RAZORPAY_KEY_ID || !RAZORPAY_KEY_SECRET) {
      throw new HttpsError("failed-precondition", "Razorpay credentials not configured");
    }

    // Phase 16, Workstream 7: a voluntary, identity-bound financial action
    // (crediting the caller's own wallet) — gated the same way createOrder
    // is, unlike creditSignupBonus (fires automatically at account
    // bootstrap, before profile completion is even possible) or
    // createRazorpayOrder/verifyRazorpayPayment (verify a payment but don't
    // themselves credit/spend anything — the actual value-transfer step,
    // createOrder, is already gated).
    const callerSnap = await admin.firestore().collection("users").doc(uid).get();
    if (!callerSnap.exists || callerSnap.data()?.profileCompleted !== true) {
      throw new HttpsError("failed-precondition", "Please complete your profile before topping up your wallet");
    }

    // STEP 1: HMAC-SHA256 signature check — the primary gate, identical to
    // verifyRazorpayPayment's.
    const expectedSignature = crypto
      .createHmac("sha256", RAZORPAY_KEY_SECRET)
      .update(`${orderId}|${paymentId}`)
      .digest("hex");
    if (expectedSignature !== signature) {
      log.error(`🚨 Wallet top-up signature mismatch for payment ${paymentId}`);
      await admin.firestore().collection("payment_security_logs").add({
        paymentId,
        orderId,
        receivedSignature: signature,
        expectedSignature,
        flaggedAt: admin.firestore.FieldValue.serverTimestamp(),
        type: "wallet_topup_signature_mismatch",
        uid,
      });
      throw new HttpsError("permission-denied", "Payment signature verification failed");
    }

    // STEP 2: live Razorpay API status check — a signature alone doesn't
    // prove the payment was actually captured (only that the IDs were
    // real), same as verifyRazorpayPayment's second gate.
    const authHeader = Buffer.from(`${RAZORPAY_KEY_ID}:${RAZORPAY_KEY_SECRET}`).toString("base64");
    const response = await axios.get(`https://api.razorpay.com/v1/payments/${paymentId}`, {
      headers: { Authorization: `Basic ${authHeader}` },
    });
    const payment = response.data as RazorpayPayment;
    if (payment.status !== "captured") {
      throw new HttpsError("failed-precondition", "Payment was not captured");
    }

    // STEP 3: amount cross-check. Unlike createOrder.ts's order total (which
    // can differ from a client claim by rounding from discounts/tax), a
    // wallet top-up has no such source of legitimate variance — the
    // Razorpay-captured amount (paise) must equal the claimed rupee amount
    // exactly, compared at paise granularity to avoid floating-point noise.
    const capturedAmount = payment.amount / 100;
    if (Math.round(capturedAmount * 100) !== Math.round(amount * 100)) {
      log.error(
        `🚨 Wallet top-up amount mismatch for payment ${paymentId}: captured ₹${capturedAmount}, claimed ₹${amount}`
      );
      throw new HttpsError(
        "failed-precondition",
        "Captured amount does not match the requested top-up amount"
      );
    }

    const db = admin.firestore();
    const walletRef = db.collection("wallets").doc(uid);
    const configRef = db.collection("settings").doc("wallet_config");
    // Idempotency anchor: one document per Razorpay paymentId, written only
    // on the first successful credit. A retried call with the same
    // paymentId (e.g. a client retry after a network blip) must not
    // double-credit — checked and written inside the same transaction that
    // credits the wallet, exactly like payEmployeeCommissionOnDelivery's
    // commissionPaid re-check pattern.
    const topupRef = db.collection("wallet_topups").doc(paymentId);
    const amountTxRef = db.collection("wallet_transactions").doc();
    const bonusTxRef = db.collection("wallet_transactions").doc();

    const result = await db.runTransaction(async (tx) => {
      const [topupSnap, walletSnap, configSnap] = await Promise.all([
        tx.get(topupRef),
        tx.get(walletRef),
        tx.get(configRef),
      ]);

      if (topupSnap.exists) {
        const existing = topupSnap.data()!;
        return {
          alreadyCredited: true,
          bonusCoins: existing.bonusCoins as number,
          balanceAfter: existing.balanceAfter as number,
          coinsAfter: existing.coinsAfter as number,
        };
      }

      const bonusCoins = getBonusForAmount(configSnap.data()?.topupBonuses, amount);
      const currentBalance = (walletSnap.data()?.balance as number | undefined) ?? 0;
      const currentCoins = (walletSnap.data()?.coins as number | undefined) ?? 0;
      const balanceAfter = currentBalance + amount;
      const coinsAfter = currentCoins + bonusCoins;

      // set+merge (not update) since a top-up must succeed even if the
      // wallet document hasn't been created yet — mirrors
      // requestEmployeePayout.ts's wallet write.
      tx.set(
        walletRef,
        {
          userId: uid,
          balance: admin.firestore.FieldValue.increment(amount),
          coins: admin.firestore.FieldValue.increment(bonusCoins),
          lifetimeEarnings: admin.firestore.FieldValue.increment(amount),
          lifetimeCoinsEarned: admin.firestore.FieldValue.increment(bonusCoins),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      tx.set(amountTxRef, {
        walletId: uid,
        userId: uid,
        type: "credit",
        source: "topup",
        amount,
        coins: 0,
        balanceAfter,
        coinsAfter,
        orderId: null,
        description: `Added ₹${amount.toFixed(0)} to wallet`,
        referenceId: paymentId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: null,
        metadata: null,
      });

      if (bonusCoins > 0) {
        tx.set(bonusTxRef, {
          walletId: uid,
          userId: uid,
          type: "credit",
          source: "bonus",
          amount: 0,
          coins: bonusCoins,
          balanceAfter,
          coinsAfter,
          orderId: null,
          description: "Top-up bonus coins",
          referenceId: paymentId,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          expiresAt: null,
          metadata: null,
        });
      }

      tx.set(topupRef, {
        uid,
        paymentId,
        orderId,
        amount,
        bonusCoins,
        balanceAfter,
        coinsAfter,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { alreadyCredited: false, bonusCoins, balanceAfter, coinsAfter };
    });

    log.success(
      `✅ Wallet top-up ${result.alreadyCredited ? "already credited (idempotent no-op)" : "credited"}: uid=${uid} payment=${paymentId} amount=₹${amount}`
    );

    return { success: true, amount, ...result };
  }
);

interface RedeemReferralCodeData {
  code: string;
}

export const redeemReferralCode = onCall(
  { minInstances: 0, memory: "256MiB" },
  async (request) => {
    const data = request.data as RedeemReferralCodeData;
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required");
    }
    const uid = request.auth.uid;
    const code = String(data?.code || "").trim().toUpperCase();
    if (!code) {
      throw new HttpsError("invalid-argument", "code is required");
    }

    const db = admin.firestore();

    // Phase 16, Workstream 7: same reasoning as verifyWalletTopup above —
    // a voluntary, identity-bound financial action.
    const callerSnap = await db.collection("users").doc(uid).get();
    if (!callerSnap.exists || callerSnap.data()?.profileCompleted !== true) {
      throw new HttpsError("failed-precondition", "Please complete your profile before redeeming a referral code");
    }

    const configSnap = await db.collection("settings").doc("wallet_config").get();
    const configData = configSnap.data() || {};
    if (configData.isReferralEnabled === false) {
      throw new HttpsError("failed-precondition", "Referrals are currently disabled");
    }
    const referrerBonus = typeof configData.referrerBonus === "number" ? configData.referrerBonus : 100;
    const referredBonus = typeof configData.referredBonus === "number" ? configData.referredBonus : 50;

    // Resolved with the Admin SDK, which bypasses firestore.rules — this is
    // exactly the read the client-side query in applyReferralCode's old
    // implementation could never reliably perform for another user's
    // wallet under the isOwner()-only rule.
    const referrerQuery = await db
      .collection("wallets")
      .where("referralCode", "==", code)
      .limit(1)
      .get();
    if (referrerQuery.empty) {
      throw new HttpsError("not-found", "Invalid referral code");
    }
    const referrerRef = referrerQuery.docs[0].ref;
    const referrerUid = referrerRef.id;
    if (referrerUid === uid) {
      throw new HttpsError("failed-precondition", "You cannot use your own referral code");
    }

    const callerWalletRef = db.collection("wallets").doc(uid);
    const referralRef = db.collection("referrals").doc();
    const callerTxRef = db.collection("wallet_transactions").doc();
    const referrerTxRef = db.collection("wallet_transactions").doc();

    const result = await db.runTransaction(async (tx) => {
      const [callerSnap, referrerSnap] = await Promise.all([
        tx.get(callerWalletRef),
        tx.get(referrerRef),
      ]);

      if (!callerSnap.exists) {
        throw new HttpsError("failed-precondition", "Wallet not found");
      }
      // Re-checked inside the transaction, mirroring
      // payEmployeeCommissionOnDelivery's idempotency re-check — the
      // client-side `_wallet!.referredBy != null` guard in
      // wallet_provider.dart is UX-only.
      if (callerSnap.data()?.referredBy) {
        throw new HttpsError(
          "failed-precondition",
          "You have already redeemed a referral code"
        );
      }

      const callerCoinsAfter = ((callerSnap.data()?.coins as number | undefined) ?? 0) + referredBonus;
      const referrerCoinsAfter = ((referrerSnap.data()?.coins as number | undefined) ?? 0) + referrerBonus;

      tx.update(callerWalletRef, {
        referredBy: code,
        coins: admin.firestore.FieldValue.increment(referredBonus),
        lifetimeCoinsEarned: admin.firestore.FieldValue.increment(referredBonus),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // The referrer's wallet is proven to exist (it's how it was found via
      // the referralCode query above), so a plain update is safe here.
      tx.update(referrerRef, {
        coins: admin.firestore.FieldValue.increment(referrerBonus),
        lifetimeCoinsEarned: admin.firestore.FieldValue.increment(referrerBonus),
        referralCount: admin.firestore.FieldValue.increment(1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      tx.set(callerTxRef, {
        walletId: uid,
        userId: uid,
        type: "credit",
        source: "referral",
        amount: 0,
        coins: referredBonus,
        balanceAfter: (callerSnap.data()?.balance as number | undefined) ?? 0,
        coinsAfter: callerCoinsAfter,
        orderId: null,
        description: "Referral bonus",
        referenceId: null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: null,
        metadata: null,
      });

      tx.set(referrerTxRef, {
        walletId: referrerUid,
        userId: referrerUid,
        type: "credit",
        source: "referral",
        amount: 0,
        coins: referrerBonus,
        balanceAfter: (referrerSnap.data()?.balance as number | undefined) ?? 0,
        coinsAfter: referrerCoinsAfter,
        orderId: null,
        description: "Referral bonus for inviting a friend",
        referenceId: null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: null,
        metadata: null,
      });

      tx.set(referralRef, {
        referrerUserId: referrerUid,
        referrerEmail: null,
        referredUserId: uid,
        referredEmail: null,
        referralCode: code,
        referrerBonus,
        referredBonus,
        isCompleted: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        completedAt: null,
      });

      return { referrerUid, referredBonus, referrerBonus, callerCoinsAfter, referrerCoinsAfter };
    });

    log.success(
      `✅ Referral redeemed: referred=${uid} referrer=${result.referrerUid} code=${code}`
    );

    return { success: true, ...result };
  }
);

export const creditSignupBonus = onCall(
  { minInstances: 0, memory: "256MiB" },
  async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required");
  }
  const uid = request.auth.uid;
  const db = admin.firestore();

  const configSnap = await db.collection("settings").doc("wallet_config").get();
  const configData = configSnap.data() || {};
  const isCashbackEnabled = configData.isCashbackEnabled !== false;
  const signupBonus = typeof configData.signupBonus === "number" ? configData.signupBonus : 50;

  if (!isCashbackEnabled || signupBonus <= 0) {
    return { success: true, credited: false };
  }

  const walletRef = db.collection("wallets").doc(uid);
  const walletTxRef = db.collection("wallet_transactions").doc();

  const result = await db.runTransaction(async (tx) => {
    const walletSnap = await tx.get(walletRef);
    if (!walletSnap.exists) {
      throw new HttpsError(
        "failed-precondition",
        "Wallet not found — create it before crediting the signup bonus"
      );
    }
    // Idempotency guard: without this, a client could call this callable
    // repeatedly and farm the welcome bonus indefinitely — mirrors
    // commissionPaid's role in employeeCommission.ts.
    if (walletSnap.data()?.signupBonusCredited === true) {
      return { credited: false };
    }

    const coinsAfter = ((walletSnap.data()?.coins as number | undefined) ?? 0) + signupBonus;

    tx.update(walletRef, {
      coins: admin.firestore.FieldValue.increment(signupBonus),
      lifetimeCoinsEarned: admin.firestore.FieldValue.increment(signupBonus),
      signupBonusCredited: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    tx.set(walletTxRef, {
      walletId: uid,
      userId: uid,
      type: "credit",
      source: "bonus",
      amount: 0,
      coins: signupBonus,
      balanceAfter: (walletSnap.data()?.balance as number | undefined) ?? 0,
      coinsAfter,
      orderId: null,
      description: "Welcome bonus",
      referenceId: null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: null,
      metadata: null,
    });

    return { credited: true, coinsAfter };
  });

  return { success: true, ...result };
  }
);
