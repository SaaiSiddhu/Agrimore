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
import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import * as crypto from "crypto";
import axios from "axios";
import { log } from "../common/helpers";
import { getRazorpayCredentials, RAZORPAY_KEY_SECRET } from "./payment";
import { isSafeProviderId, isSpendableCapturedPayment, razorpayModeFromKey } from "../common/paymentIntegrity";

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

    const requestedAmount = data?.amount;
    const { paymentId, orderId, signature } = data || ({} as VerifyWalletTopupData);
    if (typeof requestedAmount !== "number" || !Number.isFinite(requestedAmount) || requestedAmount <= 0 ||
        !Number.isSafeInteger(Math.round(requestedAmount * 100)) || Math.round(requestedAmount * 100) < 1) {
      throw new HttpsError("invalid-argument", "amount must be a positive number");
    }
    const amountPaise = Math.round(requestedAmount * 100);
    const amount = amountPaise / 100;
    if (!isSafeProviderId(paymentId) || !isSafeProviderId(orderId) ||
        typeof signature !== "string" || !signature || signature.length > 256) {
      throw new HttpsError(
        "invalid-argument",
        "Missing Razorpay verification parameters"
      );
    }

    const { keyId: RAZORPAY_KEY_ID, keySecret: RAZORPAY_KEY_SECRET } = getRazorpayCredentials();
    const providerMode = razorpayModeFromKey(RAZORPAY_KEY_ID);
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
    const signatureMatches = /^[a-fA-F0-9]{64}$/.test(signature) &&
      crypto.timingSafeEqual(Buffer.from(expectedSignature, "hex"), Buffer.from(signature, "hex"));
    if (!signatureMatches) {
      log.error(`🚨 Wallet top-up signature mismatch for payment ${paymentId}`);
      // FIX-9, WS1. Mirrors payment.ts's identical fix: never persist the
      // correct signature, even into an admin-read-only collection — see
      // that file's own comment for why "admin-only" isn't "safe to store".
      await admin.firestore().collection("payment_security_logs").add({
        paymentId,
        orderId,
        receivedSignatureLength: signature ? String(signature).length : 0,
        signatureMatched: false,
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
    if (!payment || payment.id !== paymentId || payment.order_id !== orderId || payment.currency !== "INR") {
      throw new HttpsError("failed-precondition", "Payment does not match the requested top-up");
    }
    if (!Number.isSafeInteger(payment.amount) || !isSpendableCapturedPayment({
      ...payment, amount: payment.amount / 100, paymentId, orderId,
    }, paymentId)) {
      throw new HttpsError("failed-precondition", "Payment was not captured");
    }

    // STEP 3: amount cross-check. Unlike createOrder.ts's order total (which
    // can differ from a client claim by rounding from discounts/tax), a
    // wallet top-up has no such source of legitimate variance — the
    // Razorpay-captured amount (paise) must equal the claimed rupee amount
    // exactly, compared at paise granularity to avoid floating-point noise.
    const capturedAmount = payment.amount / 100;
    if (payment.amount !== amountPaise) {
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
    // Phase FIX-1 (finding N-1, P0). Before this change wallet_topups/{paymentId}
    // above was this function's ONLY idempotency anchor, and it lives in a
    // collection nothing else reads. createOrder.ts and employee/activationCore.ts
    // both anchor on verified_payments/{paymentId}'s consumedBy* markers, and
    // neither reads wallet_topups. The two namespaces were therefore DISJOINT,
    // so one captured Razorpay payment could buy goods AND credit the wallet —
    // pay ₹5,000 once, receive ₹5,000 of goods plus ₹5,000 of balance plus the
    // bonus coins, in either order. verified_payments/{paymentId} is now the
    // single consumption namespace for all three spending paths; wallet_topups
    // stays as the top-up record and its own retry anchor, it is simply no
    // longer the only thing standing between a payment and a second spend.
    const paymentRef = db.collection("verified_payments").doc(paymentId);
    // Phase FIX-1 (finding N-6, P1). createRazorpayOrder writes this document for
    // every Razorpay order it creates, stamped with the caller's uid — it is the
    // binding between a payment and the person who actually paid. This function
    // never read it, so anyone holding a valid (orderId, paymentId, signature)
    // triple could credit THEIR OWN wallet with someone else's money.
    const razorpayOrderRef = db.collection("razorpay_orders").doc(orderId);

    const result = await db.runTransaction(async (tx) => {
      const [topupSnap, walletSnap, configSnap, paymentSnap, razorpayOrderSnap] = await Promise.all([
        tx.get(topupRef),
        tx.get(walletRef),
        tx.get(configRef),
        tx.get(paymentRef),
        tx.get(razorpayOrderRef),
      ]);

      // ============================================
      // Phase FIX-1, N-6: bind this payment to the caller BEFORE crediting.
      // ============================================
      // Fail-closed and ordered cheapest-signal-first. razorpay_orders/{orderId}
      // is written by createRazorpayOrder for every order it creates, so a real
      // top-up always has one; verified_payments/{paymentId}.userId is written by
      // verifyRazorpayPayment when that path was used. A mismatch on EITHER is a
      // hard refusal. Requiring at least one of them to exist is deliberate: a
      // payment that went through neither cannot have been created by this
      // platform for this user, and "no evidence of ownership" must not read as
      // "owned by whoever asked" — that was exactly the N-6 hole.
      const orderOwner = razorpayOrderSnap.exists
        ? (razorpayOrderSnap.data()?.userId as string | undefined)
        : undefined;
      const paymentOwner = paymentSnap.exists
        ? (paymentSnap.data()?.userId as string | undefined)
        : undefined;
      if (orderOwner && orderOwner !== uid) {
        log.error(
          `🚨 Wallet top-up ownership mismatch: payment ${paymentId} / order ${orderId} belongs to another user; caller=${uid}`
        );
        throw new HttpsError("permission-denied", "This payment does not belong to you");
      }
      if (paymentOwner && paymentOwner !== uid) {
        log.error(
          `🚨 Wallet top-up ownership mismatch: verified_payments/${paymentId} belongs to another user; caller=${uid}`
        );
        throw new HttpsError("permission-denied", "This payment does not belong to you");
      }
      if (!orderOwner && !paymentOwner) {
        log.error(
          `🚨 Wallet top-up with no ownership evidence: neither razorpay_orders/${orderId} nor verified_payments/${paymentId} names an owner; caller=${uid}`
        );
        throw new HttpsError(
          "failed-precondition",
          "This payment could not be verified for your account"
        );
      }

      // A retry is a financial read too: establish its owner and immutable
      // binding before returning the saved balance. Never reuse another UID's
      // anchor, or let it hide a mismatched provider/order relationship.
      const existing = topupSnap.data();
      if (existing && existing.uid !== uid) {
        throw new HttpsError("permission-denied", "This payment does not belong to you");
      }
      const order = razorpayOrderSnap.data();
      if (order && (order.userId !== uid || order.orderId !== orderId ||
          order.currency !== "INR" || order.amountPaise !== amountPaise ||
          (order.providerMode !== undefined && order.providerMode !== providerMode) ||
          typeof order.amount !== "number" || !Number.isFinite(order.amount) ||
          Math.round(order.amount * 100) !== amountPaise)) {
        throw new HttpsError("failed-precondition", "Payment order does not match the requested top-up");
      }
      const verified = paymentSnap.data();
      if (verified && (verified.userId !== uid || verified.orderId !== orderId ||
          (!order && verified.paymentId !== paymentId) ||
          !isSpendableCapturedPayment(verified, paymentId) ||
          (verified.providerMode !== undefined && verified.providerMode !== providerMode) ||
          Math.round(verified.amount * 100) !== amountPaise)) {
        throw new HttpsError("failed-precondition", "Verified payment does not match the requested top-up");
      }
      if (existing) {
        if (existing.paymentId !== paymentId || existing.orderId !== orderId ||
            existing.amount !== amount ||
            (existing.providerMode !== undefined && existing.providerMode !== providerMode) ||
            (existing.amountPaise !== undefined && existing.amountPaise !== amountPaise)) {
          throw new HttpsError("failed-precondition", "Previous top-up does not match this payment");
        }
        return {
          alreadyCredited: true,
          bonusCoins: existing.bonusCoins as number,
          balanceAfter: existing.balanceAfter as number,
          coinsAfter: existing.coinsAfter as number,
        };
      }

      // ============================================
      // Phase FIX-1, N-1: cross-namespace double-spend guard.
      // ============================================
      // Mirrors createOrder.ts's own trust block field-for-field. A payment
      // already spent on an order or on an associate's onboarding activation
      // must never also credit a wallet, and vice versa — createOrder.ts and
      // activationCore.ts reject consumedByWalletTopup in the same way, so all
      // three paths now refuse each other's markers. Checked here, before any
      // write, and the marker is written below inside this same transaction.
      const payment = paymentSnap.exists ? paymentSnap.data()! : null;
      if (payment?.consumedByOrderId) {
        throw new HttpsError(
          "failed-precondition",
          "This payment has already been used for an order"
        );
      }
      if (payment?.consumedByOnboardingFor) {
        throw new HttpsError(
          "failed-precondition",
          "This payment has already been used for onboarding"
        );
      }
      if (payment?.consumedByWalletTopup) {
        throw new HttpsError(
          "failed-precondition",
          "This payment has already been used for a wallet top-up"
        );
      }
      // Phase AI-4 (D-SELLER-AI-FUNDING): fourth direction, symmetric with the
      // three above. A payment already spent on a seller's ₹50 AI Assistant
      // activation (functions/src/seller/aiConnection.ts's
      // connectSellerAiProvider) must never also credit a wallet.
      if (payment?.consumedBySellerAiActivationFor) {
        throw new HttpsError(
          "failed-precondition",
          "This payment has already been used for a seller AI Assistant activation"
        );
      }

      if (payment && !isSpendableCapturedPayment(payment, paymentId)) {
        throw new HttpsError("failed-precondition", "Payment was not captured");
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
        amountPaise,
        currency: "INR",
        providerMode,
        bonusCoins,
        balanceAfter,
        coinsAfter,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Phase FIX-1, N-1: claim this payment in the SHARED namespace, inside the
      // same transaction that credits the wallet — the identical idempotency-
      // anchor shape createOrder.ts uses for consumedByOrderId. set+merge, not
      // update, because a wallet top-up does not require verifyRazorpayPayment to
      // have run first, so verified_payments/{paymentId} may not exist yet; the
      // seeded fields below are the same ones verifyRazorpayPayment writes, so a
      // document created here is indistinguishable to createOrder.ts's own trust
      // block (which is precisely what makes the guard work in both directions).
      tx.set(
        paymentRef,
        {
          paymentId,
          orderId,
          userId: uid,
          amount,
          amountPaise,
          currency: "INR",
          providerMode,
          status: "captured",
          consumedByWalletTopup: uid,
          consumedByWalletTopupPaymentId: paymentId,
          consumedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

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

    const result = await db.runTransaction(async (tx) => {
      // Phase FIX-15B (D-REFERRAL-TIMING) moved the referrer's own credit to
      // completeReferralOnFirstDelivery below, so this transaction no longer
      // reads the referrer's wallet at all — its existence was already
      // confirmed by the referralCode query above.
      const callerSnap = await tx.get(callerWalletRef);

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

      tx.update(callerWalletRef, {
        referredBy: code,
        coins: admin.firestore.FieldValue.increment(referredBonus),
        lifetimeCoinsEarned: admin.firestore.FieldValue.increment(referredBonus),
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

      // Phase FIX-15B (D-REFERRAL-TIMING, 2026-09-07): the referrer's
      // `referrerBonus` is deliberately NOT credited here any more. It used
      // to be credited immediately, in this same transaction, alongside an
      // `isCompleted: false` field that nothing ever read or updated
      // (finding N-44). The owner decided the referrer should be paid only
      // after the referred user's first delivered order — see
      // completeReferralOnFirstDelivery below, which is the ONLY other
      // writer of this document and the only place `referrerBonus` is ever
      // actually credited now. `isCompleted`/`completedAt` are therefore no
      // longer dead fields; they are this document's own real state machine.
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

      return { referrerUid, referredBonus, referrerBonus, callerCoinsAfter };
    });

    log.success(
      `✅ Referral redeemed: referred=${uid} referrer=${result.referrerUid} code=${code}`
    );

    return { success: true, ...result };
  }
);

// ============================================================
//  completeReferralOnFirstDelivery (Phase FIX-15B, D-REFERRAL-TIMING)
// ============================================================
//
// redeemReferralCode above no longer credits the referrer — it only opens a
// `referrals/{id}` doc with `isCompleted: false`. This trigger is the ONLY
// place that ever sets `isCompleted: true` or credits `referrerBonus`, and it
// does so exactly once, on the transition into a delivered-equivalent status
// for the REFERRED user's order — i.e. their first delivered order, by
// construction: `isCompleted` only exists in the false state until the first
// such transition observes it, so there is nothing further to check to prove
// "first" beyond the flag's own one-way flip inside a transaction.
//
// v1 TRIGGER SAFETY. This is a v1 Firestore trigger, not the v2 onCall
// redeemReferralCode is. The P0-FIELDVALUE investigation (this session)
// found that v1 background functions crash on `admin.firestore.FieldValue`
// namespace access; every write below uses the modular `FieldValue` import
// instead, mirroring employeeCommission.ts's own fix for the identical class
// of function.
//
// STATUS FIELD: deliberately checks BOTH `orderStatus` and `status` (mirrors
// confirmDelivery.ts's own statusIsIn(), not employeeCommission.ts's
// narrower orderStatus-only check) — confirmDelivery.ts's own comment
// documents that seller-panel and admin writes set only `status`, so a
// single-field check would silently miss a real delivery. (This same gap
// likely exists in payEmployeeCommissionOnDelivery's own narrower check —
// out of scope here, flagged in the ledger for a future phase, not fixed on
// this branch.)
const REFERRAL_DELIVERED_EQUIVALENT = new Set(["delivered", "completed"]);
function referralOrderIsDelivered(order: FirebaseFirestore.DocumentData | undefined): boolean {
  if (!order) return false;
  const a = typeof order.orderStatus === "string" ? order.orderStatus.toLowerCase() : "";
  const b = typeof order.status === "string" ? order.status.toLowerCase() : "";
  return REFERRAL_DELIVERED_EQUIVALENT.has(a) || REFERRAL_DELIVERED_EQUIVALENT.has(b);
}

export const completeReferralOnFirstDelivery = functions.firestore
  .document("orders/{orderId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const orderId = context.params.orderId as string;

    // Only fire on the transition INTO delivered, not on every write while
    // already delivered/completed (mirrors payEmployeeCommissionOnDelivery).
    if (referralOrderIsDelivered(before) || !referralOrderIsDelivered(after)) {
      return null;
    }

    const referredUserId = typeof after?.userId === "string" ? after.userId : undefined;
    if (!referredUserId) {
      return null;
    }

    const db = admin.firestore();

    // Cheap no-op for the overwhelming majority of orders, which belong to a
    // user with no referral at all.
    const referralQuery = await db
      .collection("referrals")
      .where("referredUserId", "==", referredUserId)
      .where("isCompleted", "==", false)
      .limit(1)
      .get();
    if (referralQuery.empty) {
      return null;
    }
    const referralRef = referralQuery.docs[0].ref;

    await db.runTransaction(async (tx) => {
      const referralSnap = await tx.get(referralRef);
      if (!referralSnap.exists) {
        return;
      }
      const referral = referralSnap.data()!;
      // Re-checked inside the transaction against concurrent/retried trigger
      // invocations — the same reasoning as commissionPaid's own re-check.
      if (referral.isCompleted === true) {
        console.log(`⚠️ Referral ${referralRef.id} already completed — skipping`);
        return;
      }

      const referrerUid = referral.referrerUserId as string | undefined;
      const referrerBonus = typeof referral.referrerBonus === "number" ? referral.referrerBonus : 0;
      if (!referrerUid || referrerBonus <= 0) {
        // Nothing to pay — still close out the referral so a malformed or
        // zero-bonus record does not sit open forever re-querying on every
        // future delivery for this user.
        tx.update(referralRef, {
          isCompleted: true,
          completedAt: FieldValue.serverTimestamp(),
        });
        return;
      }

      const referrerRef = db.collection("wallets").doc(referrerUid);
      const referrerSnap = await tx.get(referrerRef);
      if (!referrerSnap.exists) {
        // The referrer's wallet existed at redemption time (redeemReferralCode
        // only ever finds a referral code via a wallets query) but no longer
        // does now — an account deletion between redemption and delivery.
        // Close out the referral without paying rather than throw: a thrown
        // error here would make Cloud Functions retry this trigger
        // indefinitely against a wallet that will never come back.
        console.log(`⚠️ Referrer wallet ${referrerUid} not found for referral ${referralRef.id} — closing without payment`);
        tx.update(referralRef, {
          isCompleted: true,
          completedAt: FieldValue.serverTimestamp(),
        });
        return;
      }

      const referrerCoinsAfter = ((referrerSnap.data()?.coins as number | undefined) ?? 0) + referrerBonus;
      const referrerTxRef = db.collection("wallet_transactions").doc();

      tx.update(referrerRef, {
        coins: FieldValue.increment(referrerBonus),
        lifetimeCoinsEarned: FieldValue.increment(referrerBonus),
        referralCount: FieldValue.increment(1),
        updatedAt: FieldValue.serverTimestamp(),
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
        orderId,
        description: "Referral bonus — friend's first delivered order",
        referenceId: null,
        createdAt: FieldValue.serverTimestamp(),
        expiresAt: null,
        metadata: null,
      });

      tx.update(referralRef, {
        isCompleted: true,
        completedAt: FieldValue.serverTimestamp(),
      });
    });

    return null;
  });

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

// ============================================================
// Phase FIX-N6F (finding N-6F) — server-side, collision-safe referral codes
// ============================================================
//
// wallets/{userId} is still created directly by the client
// (wallet_provider.dart's loadWallet()) — this phase does not move that,
// only what the CREATE is allowed to contain. Before this phase,
// WalletModel.empty() generated referralCode itself as <4-char name
// prefix><2-digit userId.hashCode % 100> — not just client-tamperable (a
// crafted create could set it to any string, including one someone else
// already publicises) but genuinely COLLISION-PRONE for two entirely
// honest users: only 100 possible sequence values per name prefix, and
// Dart's String.hashCode has no cross-version/cross-platform stability
// guarantee. firestore.rules now requires referralCode to be absent or ''
// at create (walletBalanceFieldsAreZero()) — the client can no longer set
// any value — so this trigger is what actually assigns one, with a real
// uniqueness check, the moment the wallet document lands.
const REFERRAL_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // no 0/O/1/I — avoids transcription confusion
function randomReferralSuffix(length: number): string {
  let out = "";
  for (let i = 0; i < length; i++) {
    out += REFERRAL_CODE_ALPHABET[Math.floor(Math.random() * REFERRAL_CODE_ALPHABET.length)];
  }
  return out;
}

export const assignReferralCode = functions.firestore
  .document("wallets/{userId}")
  .onCreate(async (snap, context) => {
    const userId = context.params.userId as string;
    const data = snap.data() || {};

    // Defense-in-depth alongside the rules change above: if a code somehow
    // already exists (e.g. this trigger re-runs after a retry), never
    // overwrite an already-assigned one.
    if (typeof data.referralCode === "string" && data.referralCode.length > 0) {
      return null;
    }

    const db = admin.firestore();

    let namePrefix = "AGRI";
    try {
      const userSnap = await db.collection("users").doc(userId).get();
      const name = userSnap.data()?.name;
      if (typeof name === "string" && name.trim().length > 0) {
        const clean = name.replace(/[^A-Za-z]/g, "").toUpperCase();
        namePrefix = clean.length >= 4 ? clean.slice(0, 4) : clean.padEnd(4, "X");
      }
    } catch (e) {
      // A profile-read hiccup must never block referral-code assignment —
      // fall back to the generic prefix, mirroring WalletModel.empty()'s
      // own original default.
      log.error(`assignReferralCode: profile read failed for ${userId}, using generic prefix: ${e}`);
    }

    let code = "";
    const MAX_ATTEMPTS = 8;
    for (let attempt = 0; attempt < MAX_ATTEMPTS; attempt++) {
      // The first few attempts keep the personalized prefix; if that name
      // space is unusually crowded, fall back to a fully random 8-char
      // code rather than looping forever on one prefix.
      const candidate = attempt < 5 ? `${namePrefix}${randomReferralSuffix(4)}` : randomReferralSuffix(8);
      const existing = await db.collection("wallets").where("referralCode", "==", candidate).limit(1).get();
      if (existing.empty) {
        code = candidate;
        break;
      }
    }
    if (!code) {
      // Astronomically unlikely to be reached given the 8-char fully-random
      // fallback space above, but a wallet must never be left with no code
      // at all — this final fallback mixes in the current timestamp so it
      // cannot collide with anything generated by the loop above.
      code = `${Date.now().toString(36).toUpperCase()}${randomReferralSuffix(4)}`;
    }

    await snap.ref.update({ referralCode: code });
    return null;
  });
