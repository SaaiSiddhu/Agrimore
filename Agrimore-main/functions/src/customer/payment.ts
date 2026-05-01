import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import axios from "axios";
import Razorpay from "razorpay";
import { log } from "../common/helpers";

function getRazorpayCredentials(): { keyId: string; keySecret: string } {
  const config =
    typeof (functions as any).config === "function"
      ? (functions as any).config()
      : {};
  return {
    keyId: process.env.RAZORPAY_KEY_ID || config.razorpay?.key_id || "",
    keySecret:
      process.env.RAZORPAY_KEY_SECRET || config.razorpay?.key_secret || "",
  };
}

interface CreateOrderData {
  amount: number;
  currency?: string;
  receipt?: string;
  notes?: Record<string, string>;
}

export const createRazorpayOrder = functions.https.onCall(
  async (data: CreateOrderData, context) => {
    try {
      if (!context.auth) {
        throw new functions.https.HttpsError(
          "unauthenticated",
          "User must be authenticated to create an order"
        );
      }

      const { amount, currency = "INR", receipt, notes } = data;

      if (!amount || amount <= 0) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Amount must be a positive number"
        );
      }

      const { keyId: RAZORPAY_KEY_ID, keySecret: RAZORPAY_KEY_SECRET } =
        getRazorpayCredentials();

      if (!RAZORPAY_KEY_ID || !RAZORPAY_KEY_SECRET) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Razorpay credentials not configured. Run: firebase functions:config:set razorpay.key_id=YOUR_KEY razorpay.key_secret=YOUR_SECRET"
        );
      }

      const razorpay = new Razorpay({
        key_id: RAZORPAY_KEY_ID,
        key_secret: RAZORPAY_KEY_SECRET,
      });

      const orderOptions = {
        amount: Math.round(amount * 100),
        currency: currency,
        receipt: receipt || `order_${Date.now()}`,
        notes: {
          userId: context.auth.uid,
          ...notes,
        },
      };

      log.info(`💳 Creating Razorpay order for amount: ₹${amount}`);

      const order = await razorpay.orders.create(orderOptions);

      log.success(`✅ Razorpay order created: ${order.id}`);

      await admin.firestore().collection("razorpay_orders").doc(order.id).set({
        orderId: order.id,
        userId: context.auth.uid,
        amount: amount,
        amountPaise: order.amount,
        currency: order.currency,
        status: order.status,
        receipt: order.receipt,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        orderId: order.id,
        amount: order.amount,
        currency: order.currency,
        keyId: RAZORPAY_KEY_ID,
      };
    } catch (error: any) {
      log.error(`❌ Create order error: ${error.message}`);
      if (error instanceof functions.https.HttpsError) throw error;
      throw new functions.https.HttpsError("internal", `Failed to create order: ${error.message}`);
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

export const verifyRazorpayPayment = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated to verify a payment"
      );
    }
    const { paymentId, orderId, signature, upiId } = data;
    if (!paymentId || !orderId || !signature)
      throw new functions.https.HttpsError("invalid-argument", "Missing Razorpay verification parameters");

    const { keyId: RAZORPAY_KEY_ID, keySecret: RAZORPAY_KEY_SECRET } =
      getRazorpayCredentials();
    if (!RAZORPAY_KEY_ID || !RAZORPAY_KEY_SECRET)
      throw new functions.https.HttpsError("failed-precondition", "Razorpay credentials not configured");

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
        receivedSignature: signature,
        expectedSignature: generatedSignature,
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
      return { success: true, verified: true, payment };
    } else {
      log.warn(`⚠️ Payment not captured: ${paymentId}, status: ${payment.status}`);
      return { success: true, verified: false, payment };
    }
  } catch (error: any) {
    log.error(`❌ Razorpay verification error: ${error.message}`);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

