import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import * as admin from "firebase-admin";
import axios from "axios";
import Razorpay from "razorpay";
import { log } from "../common/helpers";

// Phase 18, Workstream 1: Secret Manager binding. Every function below (and
// every indirect importer of getRazorpayCredentials() — wallet.ts,
// employee/createAssociateOnboardingPayment.ts,
// employee/reconcileStaleOnboardingPayments.ts,
// employee/razorpayOnboardingWebhook.ts) must list this in its own
// `secrets` option array. Declaring it here does NOT bind it anywhere by
// itself — `defineSecret` only registers the parameter; each function's own
// options object is what actually grants it access at deploy time. Once
// bound, Cloud Functions injects the resolved value into that function's
// `process.env.RAZORPAY_KEY_SECRET` at runtime automatically — the read
// site below needs no change at all.
export const RAZORPAY_KEY_SECRET = defineSecret("RAZORPAY_KEY_SECRET");

// Phase 18, Workstream 3 decision: RAZORPAY_KEY_ID is deliberately NOT in
// Secret Manager — it is returned to the client in createRazorpayOrder's
// response below (`keyId: RAZORPAY_KEY_ID`) so the checkout SDK can use it;
// Razorpay key IDs are public by design, and putting a value the client
// already receives into Secret Manager would cost real money/IAM overhead
// for zero security benefit. Chose plain functions/.env over `defineString`
// specifically so this function needs ZERO code change (see the completion
// report's Workstream 3 section for the full justification, including why
// `defineString` was rejected here) — it already reads
// `process.env.RAZORPAY_KEY_ID` exactly as it always has.
export function getRazorpayCredentials(): { keyId: string; keySecret: string } {
  return {
    keyId: process.env.RAZORPAY_KEY_ID || "",
    keySecret: process.env.RAZORPAY_KEY_SECRET || "",
  };
}

interface CreateOrderData {
  amount: number;
  currency?: string;
  receipt?: string;
  notes?: Record<string, string>;
  // FIX-9, WS8. `transfers` removed — accepted from the client, destructured,
  // and never referenced again anywhere in this function. Agrimore does not
  // use Razorpay Route; seller payouts are computed and disbursed by this
  // codebase's own calculateSellerPayout, not by Razorpay-native transfers.
}

export const createRazorpayOrder = onCall(
  { minInstances: 0, memory: "256MiB", secrets: [RAZORPAY_KEY_SECRET] },
  async (request) => {
    const data = request.data as CreateOrderData;
    try {
      if (!request.auth) {
        throw new HttpsError(
          "unauthenticated",
          "User must be authenticated to create an order"
        );
      }

      const { amount, currency = "INR", receipt, notes } = data;

      if (!amount || amount <= 0) {
        throw new HttpsError(
          "invalid-argument",
          "Amount must be a positive number"
        );
      }

      const { keyId: RAZORPAY_KEY_ID, keySecret: RAZORPAY_KEY_SECRET } =
        getRazorpayCredentials();

      const orderOptions = {
        amount: Math.round(amount * 100),
        currency: currency,
        receipt: receipt || `order_${Date.now()}`,
        // FIX-9, WS2. userId now comes AFTER the spread — it used to come
        // first, so a client-supplied `notes.userId` silently overwrote the
        // server's own value. This is order metadata attached to a real
        // payment record, not an access-control field, but a forged userId
        // here is still a forged attribution on a financial record.
        notes: {
          ...notes,
          userId: request.auth.uid,
        },
      };

      log.info(`💳 Creating Razorpay order for amount: ₹${amount}`);

      let order: any = null;
      let isTestMode = false;

      // Attempt live Razorpay order if credentials exist
      if (RAZORPAY_KEY_ID && RAZORPAY_KEY_SECRET) {
        try {
          const razorpay = new Razorpay({
            key_id: RAZORPAY_KEY_ID,
            key_secret: RAZORPAY_KEY_SECRET,
          });
          order = await razorpay.orders.create(orderOptions);
          log.success(`✅ Razorpay order created: ${order.id}`);
        } catch (rzpError: any) {
          const rzpErrMsg =
            rzpError?.error?.description ||
            rzpError?.description ||
            rzpError?.message ||
            JSON.stringify(rzpError);
          log.warn(
            `⚠️ Razorpay order creation failed (${rzpErrMsg}). Activating sandbox test order for development/emulator.`
          );
        }
      }

      // If live creation failed or credentials missing, generate sandbox test order
      if (!order) {
        isTestMode = true;
        const testOrderId = `order_test_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
        order = {
          id: testOrderId,
          amount: Math.round(amount * 100),
          currency: currency,
          status: "created",
          receipt: orderOptions.receipt,
        };
        log.info(`🧪 Sandbox test order created: ${order.id}`);
      }

      await admin.firestore().collection("razorpay_orders").doc(order.id).set({
        orderId: order.id,
        userId: request.auth.uid,
        amount: amount,
        amountPaise: order.amount,
        currency: order.currency,
        status: order.status,
        receipt: order.receipt,
        isTestOrder: isTestMode,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        orderId: order.id,
        amount: order.amount,
        currency: order.currency,
        keyId: RAZORPAY_KEY_ID || "rzp_test_sandbox",
        isTestMode: isTestMode,
      };
    } catch (error: any) {
      const errMsg =
        error?.error?.description ||
        error?.description ||
        error?.message ||
        (typeof error === "string" ? error : JSON.stringify(error));
      log.error(`❌ Create order error: ${errMsg}`);
      if (error instanceof HttpsError) throw error;
      throw new HttpsError("internal", `Failed to create order: ${errMsg}`);
    }
  }
);

interface RazorpayPayment {
  id: string;
  entity: string;
  amount: number;
  currency: string;
  status: string;
  method: string;
  bank?: string;
  email?: string;
  contact?: string;
  [key: string]: any;
}

export const verifyRazorpayPayment = onCall(
  { minInstances: 0, memory: "256MiB", secrets: [RAZORPAY_KEY_SECRET] },
  async (request) => {
  const data = request.data;
  try {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "User must be authenticated to verify a payment"
      );
    }
    const { paymentId, orderId, signature, upiId } = data;
    if (!paymentId || !orderId || !signature)
      throw new HttpsError("invalid-argument", "Missing Razorpay verification parameters");

    // ═══════════════════════════════════════════════════
    // 🧪 SANDBOX / TEST MODE CHECK
    // If created via sandbox test fallback or using test prefix
    // ═══════════════════════════════════════════════════
    const isTestPayment =
      orderId.startsWith("order_test_") ||
      paymentId.startsWith("pay_test_") ||
      signature.startsWith("test_sig_");

    if (isTestPayment) {
      log.info(`🧪 Verifying sandbox test payment: ${paymentId} for order: ${orderId}`);
      const orderSnap = await admin
        .firestore()
        .collection("razorpay_orders")
        .doc(orderId)
        .get();

      const orderData = orderSnap.data();
      const testAmount = orderData ? orderData.amount : 0;
      const testCurrency = orderData?.currency || "INR";

      await admin.firestore().collection("verified_payments").doc(paymentId).set({
        orderId,
        paymentId,
        userId: request.auth.uid,
        signatureVerified: true,
        upiId: upiId || null,
        verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        method: "test_sandbox",
        bank: "SANDBOX_TEST_BANK",
        email: request.auth.token.email || null,
        contact: request.auth.token.phone_number || null,
        amount: testAmount,
        currency: testCurrency,
        status: "captured",
        isTest: true,
      });

      log.success(`✅ Verified sandbox test payment: ${paymentId}`);
      return {
        success: true,
        verified: true,
        payment: { id: paymentId, status: "captured", method: "test_sandbox" },
      };
    }

    const { keyId: RAZORPAY_KEY_ID, keySecret: RAZORPAY_KEY_SECRET } =
      getRazorpayCredentials();
    if (!RAZORPAY_KEY_ID || !RAZORPAY_KEY_SECRET)
      throw new HttpsError("failed-precondition", "Razorpay credentials not configured");

    // ═══════════════════════════════════════════════════
    // 🔐 STEP 1: Verify signature using HMAC-SHA256
    // This is the PRIMARY security gate — prevents payment spoofing
    // ═══════════════════════════════════════════════════
    const crypto = require("crypto");
    const generatedSignature = crypto
      .createHmac("sha256", RAZORPAY_KEY_SECRET)
      .update(`${orderId}|${paymentId}`)
      .digest("hex");

    if (generatedSignature !== signature) {
      log.error(`🚨 SIGNATURE MISMATCH for payment ${paymentId}. Possible spoofing attempt.`);
      await admin.firestore().collection("payment_security_logs").add({
        paymentId,
        orderId,
        receivedSignatureLength: signature ? String(signature).length : 0,
        signatureMatched: false,
        flaggedAt: admin.firestore.FieldValue.serverTimestamp(),
        type: "signature_mismatch",
      });
      return { success: false, verified: false, error: "Payment signature verification failed" };
    }

    log.info(`🔐 Signature verified for payment ${paymentId}`);

    // ═══════════════════════════════════════════════════
    // 🔐 STEP 2: Verify payment status via Razorpay API
    // Double-check that payment is actually captured
    // ═══════════════════════════════════════════════════
    const authHeader = Buffer.from(`${RAZORPAY_KEY_ID}:${RAZORPAY_KEY_SECRET}`).toString("base64");

    const response = await axios.get(`https://api.razorpay.com/v1/payments/${paymentId}`, {
      headers: { Authorization: `Basic ${authHeader}` },
    });

    const payment = response.data as RazorpayPayment;
    const isValid = payment.status === "captured";

    if (isValid) {
      await admin.firestore().collection("verified_payments").doc(paymentId).set({
        orderId,
        paymentId,
        userId: request.auth.uid,
        signatureVerified: true,
        upiId: upiId || null,
        verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        method: payment.method,
        bank: payment.bank || null,
        email: payment.email || null,
        contact: payment.contact || null,
        amount: payment.amount / 100,
        currency: payment.currency,
        status: payment.status,
      });
      log.success(`✅ Verified Razorpay payment: ${paymentId}`);
      return {
        success: true,
        verified: true,
        payment: { id: payment.id, status: payment.status, method: payment.method },
      };
    } else {
      log.warn(`⚠️ Payment not captured: ${paymentId}, status: ${payment.status}`);
      return {
        success: true,
        verified: false,
        payment: { id: payment.id, status: payment.status, method: payment.method },
      };
    }
  } catch (error: any) {
    const errMsg =
      error?.response?.data?.error?.description ||
      error?.error?.description ||
      error?.description ||
      error?.message ||
      (typeof error === "string" ? error : JSON.stringify(error));
    log.error(`❌ Razorpay verification error: ${errMsg}`);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "Could not verify this payment. Please contact support.");
  }
  }
);

