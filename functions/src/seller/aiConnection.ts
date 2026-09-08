// ============================================================
//  Callables: createSellerAiActivationOrder / connectSellerAiProvider
// ============================================================
//
// Phase AI-4 (D-SELLER-AI-FUNDING, owner decision, 2026-09-07): a seller
// pays the SAME ₹50 AI Assistant activation fee AI-1 already charges
// customers, but via a direct Razorpay charge at connect time rather than a
// wallet debit — apps/seller has no wallet balance mechanism at all.
//
// This is deliberately the LIGHTER Razorpay pattern
// (createRazorpayOrder/verifyRazorpayPayment, functions/src/customer/
// payment.ts), not the heavier webhook+reconciler+shared-core architecture
// functions/src/employee/activationCore.ts uses for the ₹500 associate
// onboarding fee. That machinery exists because a lost/dropped onboarding
// payment blocks a whole registration-approval process the associate
// cannot easily retry; a ₹50 AI activation fee is far lower-stakes and the
// seller can simply retry `connectSellerAiProvider` (whose own payment
// check is a synchronous, in-request verification, not a fire-and-forget
// webhook dependency) — proportionate, not a shortcut.
//
// `verifyRazorpayPayment` (customer/payment.ts) is reused UNCHANGED: it is
// already generic (writes `verified_payments/{paymentId}` keyed by
// `userId`, with no assumption about what the payment is FOR), so a seller
// calling it after their own Razorpay checkout completes needs no seller-
// specific variant. `connectSellerAiProvider` below is the ONLY new code
// that decides whether a verified payment actually earns an AI connection.
//
// Cross-consumption: this is now the FIFTH thing a `verified_payments` doc
// can be spent on (alongside an order, associate onboarding, and a wallet
// top-up — the fourth, closed by Phase FIX-1 as a P0 after finding N-1).
// Symmetric checks are added in this same phase to all four existing
// consumers (functions/src/employee/activationCore.ts,
// functions/src/customer/wallet.ts's verifyWalletTopup,
// functions/src/customer/createOrder.ts,
// functions/src/customer/createOrderFromRfq.ts) so a payment already spent
// on an AI connection can never ALSO fund one of those — see those files'
// own diffs in this same phase for the other direction.
//
// Encryption/storage: reuses AI-1's own scheme completely —
// storeAiConnectionInTransaction() (customer/aiConnection.ts, extracted in
// this phase's own WS1) is the only place ai_connections/
// ai_connection_status are ever written, for a customer or a seller alike.
// "Free rotate while already connected, re-charge after a full disconnect"
// is the SAME decision AI-1 already made, applied here without change —
// disconnectAiProvider (customer/aiConnection.ts) is already fully
// uid-generic and needs no seller-specific duplicate at all.
//
// Deliberately generic failure messages for every payment-trust-boundary
// check below — never reveal WHICH check failed (wrong user? not
// captured? already spent elsewhere?) to the caller, mirroring
// activateAssociateOnboarding.ts's own messageForFailure() philosophy for
// the identical class of risk. The specific reason is still logged
// server-side.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import Razorpay from "razorpay";
import { log } from "../common/helpers";
import { getRazorpayCredentials, RAZORPAY_KEY_SECRET } from "../customer/payment";
import {
  AI_KEY_ENCRYPTION_SECRET,
  ALLOWED_PROVIDERS,
  AiProvider,
  ACTIVATION_FEE,
  MAX_API_KEY_LENGTH,
  encryptApiKey,
  storeAiConnectionInTransaction,
} from "../customer/aiConnection";

const SELLER_AI_ORDER_PURPOSE = "seller_ai_activation";

// Mirrors createAssociateOnboardingPayment.ts's own RATE_LIMIT_WINDOW_MS
// reasoning exactly: every call creates a REAL Razorpay order, which has
// its own cost and rate implications even before any payment is made.
const RATE_LIMIT_WINDOW_MS = 30 * 1000;

// Mirrors activationCore.ts's ONBOARDING_AMOUNT_TOLERANCE reasoning
// exactly: this absorbs ONLY Razorpay's paise-to-rupee floating-point
// division noise (payment.ts's `payment.amount / 100`), never a genuine
// under/overpayment — ACTIVATION_FEE itself is a fixed constant, not a
// multi-component computed total.
const SELLER_AI_AMOUNT_TOLERANCE = 0.01;

// Security lane finding (self-caught before VERIFY): createAssociateOnboardingPayment.ts
// requires employees/{uid} to already exist before it will take a payment —
// this is the seller-side mirror of that same precondition, and without it
// NEITHER callable below actually verifies the caller is a seller at all.
// request.auth alone only proves "some authenticated Firebase user"; a plain
// customer could otherwise call these "seller" endpoints, pay their own
// money, and end up with an ai_connections/{uid} entry through a path that
// completely bypasses AI-1's wallet-balance funding gate for the exact same
// resource. Mirrors firestore.rules' own isSeller() precedence exactly:
// claim first (request.auth.token.seller === true, minted by
// syncSellerRoleClaims), then the Firestore-doc fallback
// (sellers/{uid}.status === 'approved') — never a bare request.auth.uid
// existence check, and never trusting a client-supplied role field.
async function requireApprovedSeller(uid: string, token: Record<string, unknown>): Promise<void> {
  if (token.seller === true) return;
  const sellerSnap = await admin.firestore().collection("sellers").doc(uid).get();
  if (sellerSnap.exists && sellerSnap.data()?.status === "approved") return;
  throw new HttpsError("permission-denied", "This feature is only available to approved sellers.");
}

export const createSellerAiActivationOrder = onCall(
  { minInstances: 0, memory: "256MiB", secrets: [RAZORPAY_KEY_SECRET] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required");
    }
    const uid = request.auth.uid;
    await requireApprovedSeller(uid, request.auth.token);
    const db = admin.firestore();

    const connectionSnap = await db.collection("ai_connections").doc(uid).get();
    if (connectionSnap.exists) {
      throw new HttpsError("already-exists", "Your AI Assistant is already connected.");
    }

    // Own, clearly-named rate-limit collection — deliberately NOT
    // onboarding_rate_limits, which is a DIFFERENT, associate-onboarding-
    // specific concern by both name and existing security.md documentation;
    // reusing it here would conflate two unrelated rate limits under one
    // misleadingly-named collection.
    const rateLimitRef = db.collection("seller_ai_rate_limits").doc(uid);
    const rateLimitSnap = await rateLimitRef.get();
    const lastRequestAt = rateLimitSnap.data()?.lastRequestAt as
      | admin.firestore.Timestamp
      | undefined;
    if (lastRequestAt && Date.now() - lastRequestAt.toMillis() < RATE_LIMIT_WINDOW_MS) {
      throw new HttpsError("resource-exhausted", "Please wait a few seconds before trying again.");
    }

    const { keyId: RAZORPAY_KEY_ID, keySecret: RAZORPAY_KEY_SECRET } = getRazorpayCredentials();
    if (!RAZORPAY_KEY_ID || !RAZORPAY_KEY_SECRET) {
      throw new HttpsError(
        "failed-precondition",
        "Payments are not configured. Please contact support."
      );
    }

    const razorpay = new Razorpay({ key_id: RAZORPAY_KEY_ID, key_secret: RAZORPAY_KEY_SECRET });

    log.info(`💳 Creating seller AI activation Razorpay order for uid=${uid} amount=₹${ACTIVATION_FEE}`);

    const order = await razorpay.orders.create({
      amount: Math.round(ACTIVATION_FEE * 100),
      currency: "INR",
      receipt: `seller_ai_${uid}_${Date.now()}`,
      notes: { purpose: SELLER_AI_ORDER_PURPOSE, userId: uid },
    });

    await rateLimitRef.set(
      { lastRequestAt: FieldValue.serverTimestamp() },
      { merge: true }
    );

    // Mirrors createAssociateOnboardingPayment.ts's own razorpay_orders
    // bookkeeping write.
    await db.collection("razorpay_orders").doc(order.id).set({
      orderId: order.id,
      userId: uid,
      purpose: SELLER_AI_ORDER_PURPOSE,
      amount: ACTIVATION_FEE,
      amountPaise: order.amount,
      currency: order.currency,
      status: order.status,
      receipt: order.receipt,
      createdAt: FieldValue.serverTimestamp(),
    });

    log.success(`✅ Seller AI activation Razorpay order created: uid=${uid} order=${order.id}`);

    return {
      success: true,
      orderId: order.id,
      amount: order.amount,
      currency: order.currency,
      // The PUBLIC Razorpay key only — never the secret.
      keyId: RAZORPAY_KEY_ID,
    };
  }
);

interface ConnectSellerAiProviderData {
  provider?: string;
  apiKey?: string;
  paymentId?: string;
}

const GENERIC_PAYMENT_FAILURE_MESSAGE =
  "We could not verify this payment for your AI Assistant activation. If you were charged, please contact support.";

export const connectSellerAiProvider = onCall(
  { minInstances: 0, memory: "256MiB", secrets: [AI_KEY_ENCRYPTION_SECRET] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required");
    }
    const uid = request.auth.uid;
    await requireApprovedSeller(uid, request.auth.token);
    const data = request.data as ConnectSellerAiProviderData;
    const provider = typeof data?.provider === "string" ? data.provider : "";
    const apiKey = typeof data?.apiKey === "string" ? data.apiKey : "";
    const paymentId = typeof data?.paymentId === "string" ? data.paymentId.trim() : "";

    if (!(ALLOWED_PROVIDERS as readonly string[]).includes(provider)) {
      throw new HttpsError(
        "invalid-argument",
        `provider must be one of: ${ALLOWED_PROVIDERS.join(", ")}`
      );
    }
    if (apiKey.trim().length === 0) {
      throw new HttpsError("invalid-argument", "apiKey must not be empty");
    }
    if (apiKey.length > MAX_API_KEY_LENGTH) {
      throw new HttpsError(
        "invalid-argument",
        `apiKey must be at most ${MAX_API_KEY_LENGTH} characters`
      );
    }

    const db = admin.firestore();
    const connectionRef = db.collection("ai_connections").doc(uid);

    // Encrypted outside the transaction — same reasoning as
    // connectAiProvider's own identical comment: pure CPU work, nothing to
    // gain from doing it inside the transaction's retry window.
    const encrypted = encryptApiKey(apiKey);

    try {
      const result = await db.runTransaction(async (tx) => {
        // ============================================
        // ALL READS FIRST.
        // ============================================
        const connectionSnap = await tx.get(connectionRef);
        const alreadyConnected = connectionSnap.exists;

        if (!alreadyConnected) {
          // A fresh connection needs a genuine, unconsumed payment — free
          // rotation while already connected (checked above) needs none,
          // mirroring AI-1's own "one-time per active connection" decision.
          if (!paymentId) {
            throw new HttpsError("invalid-argument", "paymentId is required");
          }
          const paymentRef = db.collection("verified_payments").doc(paymentId);
          const paymentSnap = await tx.get(paymentRef);

          if (!paymentSnap.exists) {
            log.error(`❌ Seller AI activation: payment ${paymentId} not found (uid=${uid})`);
            throw new HttpsError("failed-precondition", GENERIC_PAYMENT_FAILURE_MESSAGE);
          }
          const payment = paymentSnap.data()!;

          if (!payment.userId || payment.userId !== uid) {
            log.error(`❌ Seller AI activation: payment ${paymentId} belongs to a different user (uid=${uid})`);
            throw new HttpsError("failed-precondition", GENERIC_PAYMENT_FAILURE_MESSAGE);
          }
          if (payment.status !== "captured") {
            log.error(`❌ Seller AI activation: payment ${paymentId} not captured (status=${payment.status})`);
            throw new HttpsError("failed-precondition", GENERIC_PAYMENT_FAILURE_MESSAGE);
          }
          const paidAmount = typeof payment.amount === "number" ? payment.amount : -1;
          if (Math.abs(paidAmount - ACTIVATION_FEE) > SELLER_AI_AMOUNT_TOLERANCE) {
            log.error(`❌ Seller AI activation: payment ${paymentId} amount mismatch (paid=${paidAmount})`);
            throw new HttpsError("failed-precondition", GENERIC_PAYMENT_FAILURE_MESSAGE);
          }
          // Cross-consumption guard, all four other directions (S3) — a
          // payment already spent anywhere else can never also fund an AI
          // connection. The reverse direction (those four rejecting a
          // payment already consumed here) is added symmetrically to each
          // of those files in this same phase.
          if (payment.consumedByOrderId) {
            log.error(`❌ Seller AI activation: payment ${paymentId} already consumed by an order`);
            throw new HttpsError("failed-precondition", GENERIC_PAYMENT_FAILURE_MESSAGE);
          }
          if (payment.consumedByOnboardingFor) {
            log.error(`❌ Seller AI activation: payment ${paymentId} already consumed by associate onboarding`);
            throw new HttpsError("failed-precondition", GENERIC_PAYMENT_FAILURE_MESSAGE);
          }
          if (payment.consumedByWalletTopup) {
            log.error(`❌ Seller AI activation: payment ${paymentId} already consumed by a wallet top-up`);
            throw new HttpsError("failed-precondition", GENERIC_PAYMENT_FAILURE_MESSAGE);
          }
          if (payment.consumedBySellerAiActivationFor) {
            log.error(`❌ Seller AI activation: payment ${paymentId} already consumed by a seller AI activation`);
            throw new HttpsError("failed-precondition", GENERIC_PAYMENT_FAILURE_MESSAGE);
          }

          // ============================================
          // ALL WRITES — same transaction, after every read above.
          // ============================================
          tx.set(
            paymentRef,
            {
              consumedBySellerAiActivationFor: uid,
              consumedBySellerAiActivationAt: FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
        }

        storeAiConnectionInTransaction({
          db,
          tx,
          uid,
          provider: provider as AiProvider,
          encrypted,
          alreadyConnected,
        });

        return { activated: !alreadyConnected, rotated: alreadyConnected };
      });

      log.success(`✅ Seller AI connection processed: uid=${uid} activated=${result.activated}`);
      return {
        success: true,
        provider: provider as AiProvider,
        activated: result.activated,
        rotated: result.rotated,
      };
    } catch (error: unknown) {
      if (error instanceof HttpsError) throw error;
      const message = error instanceof Error ? error.message : String(error);
      log.error(`❌ Seller AI connection failed for uid=${uid}: ${message}`);
      throw new HttpsError("internal", "We could not connect your AI Assistant. Please contact support.");
    }
  }
);
