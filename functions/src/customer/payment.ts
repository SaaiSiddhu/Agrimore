import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import * as admin from "firebase-admin";
import axios from "axios";
import Razorpay from "razorpay";
import { createHmac, randomBytes, timingSafeEqual } from "crypto";
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

// This server environment, never a request field or a test-looking provider
// key, is the only authority for simulated captures. Require a local database
// as well so a misconfigured emulator cannot mint production payment records.
function isLocalPaymentEmulator(): boolean {
  return process.env.FUNCTIONS_EMULATOR === "true" &&
    /^(127\.0\.0\.1|localhost|\[::1\]):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST || "");
}

function isSafeProviderId(value: unknown): value is string {
  return typeof value === "string" && /^[A-Za-z0-9_-]{1,200}$/.test(value);
}

function requireOwnedOrder(
  order: admin.firestore.DocumentData | undefined,
  orderId: string,
  uid: string,
  sandbox: boolean
): admin.firestore.DocumentData {
  if (!order || !order.userId) {
    throw new HttpsError("failed-precondition", "Payment could not be verified for your account");
  }
  if (order.userId !== uid) {
    throw new HttpsError("permission-denied", "This payment does not belong to you");
  }
  if (order.orderId !== orderId || !Number.isSafeInteger(order.amountPaise) ||
      order.amountPaise <= 0 || typeof order.amount !== "number" ||
      !Number.isFinite(order.amount) || Math.round(order.amount * 100) !== order.amountPaise ||
      order.currency !== "INR" || (sandbox ? order.isTestOrder !== true : order.isTestOrder === true)) {
    throw new HttpsError("failed-precondition", "Payment could not be verified for your account");
  }
  return order;
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

      const { amount, currency = "INR", receipt, notes } = data || {};
      const amountPaise = Math.round(amount * 100);

      if (typeof amount !== "number" || !Number.isFinite(amount) || amount <= 0 ||
          !Number.isSafeInteger(amountPaise) || amountPaise < 1) {
        throw new HttpsError(
          "invalid-argument",
          "Amount must be a positive number"
        );
      }
      if (currency !== "INR") {
        throw new HttpsError("invalid-argument", "Currency must be INR");
      }

      const { keyId: RAZORPAY_KEY_ID, keySecret: RAZORPAY_KEY_SECRET } =
        getRazorpayCredentials();

      const orderOptions = {
        amount: amountPaise,
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
          // Do not leak provider payloads or turn a live provider outage into
          // a successful, zero-cost payment.
          log.warn("Razorpay order creation failed");
          if (!isLocalPaymentEmulator()) {
            throw new HttpsError("unavailable", "Payments are temporarily unavailable. Please try again later.");
          }
        }
      }

      // Only the explicitly local emulator may substitute a simulated order.
      if (!order) {
        if (!isLocalPaymentEmulator()) {
          throw new HttpsError("failed-precondition", "Razorpay credentials not configured");
        }
        isTestMode = true;
        const testOrderId = `order_test_${randomBytes(12).toString("hex")}`;
        order = {
          id: testOrderId,
          amount: amountPaise,
          currency: currency,
          status: "created",
          receipt: orderOptions.receipt,
        };
        log.info(`🧪 Sandbox test order created: ${order.id}`);
      }

      if (!isSafeProviderId(order.id) || (!isTestMode && order.id.startsWith("order_test_")) ||
          order.amount !== amountPaise || order.currency !== currency) {
        throw new HttpsError("failed-precondition", "Payment order did not match the requested amount and currency");
      }

      await admin.firestore().collection("razorpay_orders").doc(order.id).set({
        orderId: order.id,
        userId: request.auth.uid,
        amount: amountPaise / 100,
        amountPaise: order.amount,
        currency: order.currency,
        status: order.status,
        receipt: order.receipt || orderOptions.receipt,
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
      throw new HttpsError("internal", "Failed to create payment order. Please try again later.");
    }
  }
);

interface RazorpayPayment {
  id: string;
  order_id: string;
  amount: number;
  currency: string;
  status: string;
  method: string;
  bank?: string;
  email?: string;
  contact?: string;
}

export const verifyRazorpayPayment = onCall(
  { minInstances: 0, memory: "256MiB", secrets: [RAZORPAY_KEY_SECRET] },
  async (request) => {
    try {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "User must be authenticated to verify a payment");
      }
      const { paymentId, orderId, signature, upiId } = request.data || {};
      if (!isSafeProviderId(paymentId) || !isSafeProviderId(orderId) ||
          typeof signature !== "string" || !signature || signature.length > 256 ||
          (upiId != null && (typeof upiId !== "string" || upiId.length > 256))) {
        throw new HttpsError("invalid-argument", "Missing Razorpay verification parameters");
      }
      const uid = request.auth.uid;
      const sandbox = orderId.startsWith("order_test_") ||
        paymentId.startsWith("pay_test_") || signature.startsWith("test_sig_");
      if (sandbox && !isLocalPaymentEmulator()) {
        throw new HttpsError("failed-precondition", "Simulated payments are only available in the local emulator");
      }
      if (sandbox && !(orderId.startsWith("order_test_") &&
          paymentId.startsWith("pay_test_") && signature.startsWith("test_sig_"))) {
        throw new HttpsError("failed-precondition", "Invalid simulated payment");
      }

      if (!sandbox) {
        const credentials = getRazorpayCredentials();
        if (!credentials.keyId || !credentials.keySecret) {
          throw new HttpsError("failed-precondition", "Razorpay credentials not configured");
        }
        const expected = createHmac("sha256", credentials.keySecret)
          .update(`${orderId}|${paymentId}`).digest();
        const matches = /^[a-fA-F0-9]{64}$/.test(signature) &&
          timingSafeEqual(expected, Buffer.from(signature, "hex"));
        if (!matches) {
          await admin.firestore().collection("payment_security_logs").add({
            paymentId, orderId, receivedSignatureLength: signature.length,
            signatureMatched: false,
            flaggedAt: admin.firestore.FieldValue.serverTimestamp(),
            type: "signature_mismatch",
          });
          return { success: false, verified: false, error: "Payment signature verification failed" };
        }
      }

      const db = admin.firestore();
      const orderRef = db.collection("razorpay_orders").doc(orderId);
      // Reject an unowned order before any provider call. Recheck inside the
      // final transaction so an intervening server mutation cannot change it.
      const order = requireOwnedOrder((await orderRef.get()).data(), orderId, uid, sandbox);
      let payment: RazorpayPayment;
      if (sandbox) {
        payment = { id: paymentId, order_id: orderId, amount: order.amountPaise,
          currency: order.currency, status: "captured", method: "test_sandbox",
          bank: "SANDBOX_TEST_BANK" };
      } else {
        const credentials = getRazorpayCredentials();
        const authHeader = Buffer.from(`${credentials.keyId}:${credentials.keySecret}`).toString("base64");
        const response = await axios.get(`https://api.razorpay.com/v1/payments/${paymentId}`, {
          headers: { Authorization: `Basic ${authHeader}` }, timeout: 15000,
        });
        payment = response.data as RazorpayPayment;
      }
      const requireProviderMatch = (stored: admin.firestore.DocumentData) => {
        if (!payment || payment.id !== paymentId || payment.order_id !== orderId ||
            !Number.isSafeInteger(payment.amount) || payment.amount !== stored.amountPaise ||
            payment.currency !== stored.currency) {
          throw new HttpsError("failed-precondition", "Payment did not match its stored order");
        }
      };
      requireProviderMatch(order);
      if (payment.status !== "captured") {
        return { success: true, verified: false,
          payment: { id: payment.id, status: payment.status, method: payment.method } };
      }

      const paymentRef = db.collection("verified_payments").doc(paymentId);
      await db.runTransaction(async (tx) => {
        const [orderSnap, existingSnap] = await Promise.all([tx.get(orderRef), tx.get(paymentRef)]);
        const stored = requireOwnedOrder(orderSnap.data(), orderId, uid, sandbox);
        requireProviderMatch(stored);
        if (existingSnap.exists) {
          const existing = existingSnap.data()!;
          if (existing.userId !== uid || existing.orderId !== orderId ||
              existing.paymentId !== paymentId || existing.amount !== payment.amount / 100 ||
              (existing.currency != null && existing.currency !== payment.currency)) {
            throw new HttpsError("failed-precondition", "Payment could not be verified for your account");
          }
        }
        // All consumption namespaces (including concurrent consumer writes)
        // survive retries. No verification result ever clears a spending marker.
        tx.set(paymentRef, {
          orderId, paymentId, userId: uid, signatureVerified: true,
          upiId: upiId || null, verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
          method: payment.method || null, bank: payment.bank || null,
          email: payment.email || null, contact: payment.contact || null,
          amount: payment.amount / 100, amountPaise: payment.amount,
          currency: payment.currency, status: payment.status, isTest: sandbox,
          ...(typeof stored.purpose === "string" ? { purpose: stored.purpose } : {}),
        }, { merge: true });
      });
      return { success: true, verified: true,
        payment: { id: payment.id, status: payment.status, method: payment.method } };
    } catch (error: any) {
      // Provider responses can contain payment PII; log only a stable category.
      log.error("Razorpay verification failed");
      if (error instanceof HttpsError) throw error;
      throw new HttpsError("internal", "Could not verify this payment. Please contact support.");
    }
  }
);
