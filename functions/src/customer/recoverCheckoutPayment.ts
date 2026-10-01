import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import axios from "axios";
import { getRazorpayCredentials, RAZORPAY_KEY_SECRET } from "./payment";
import { isExactMoneyAmount, isSafeProviderId, razorpayModeFromKey } from "../common/paymentIntegrity";

// Callback-independent recovery uses authenticated provider GET, never a
// manufactured Checkout signature. Existing economic consumers still own
// fulfilment and once-only consumption. No provider write occurs here.
function requireGoodsOrder(
  order: admin.firestore.DocumentData | undefined,
  orderId: string,
  uid: string,
  mode: "live" | "test"
): admin.firestore.DocumentData {
  if (!order || !order.userId) {
    throw new HttpsError("failed-precondition", "Saved payment needs review");
  }
  if (order.userId !== uid) {
    throw new HttpsError("permission-denied", "This payment does not belong to you");
  }
  // Older untyped payment orders remain on their original verification path;
  // recovery must never infer a goods purpose for a fee or wallet payment.
  if (order.orderId !== orderId || order.purpose !== "goods_checkout" ||
      order.currency !== "INR" || !isExactMoneyAmount(order.amount) ||
      !Number.isSafeInteger(order.amountPaise) || order.amountPaise <= 0 ||
      Math.round(order.amount * 100) !== order.amountPaise ||
      order.providerMode !== mode || order.isTestOrder === true ||
      orderId.startsWith("order_test_")) {
    throw new HttpsError("failed-precondition", "Saved payment needs review");
  }
  return order;
}

interface ProviderPayment {
  id: string;
  entity: string;
  order_id: string;
  amount: number;
  currency: string;
  status: string;
  captured: boolean;
  amount_refunded: number;
  refund_status: string | null;
}

function readPayments(value: unknown, orderId: string, amountPaise: number): ProviderPayment[] {
  const collection = value as { entity?: unknown; count?: unknown; items?: unknown } | null;
  if (!collection || collection.entity !== "collection" ||
      !Array.isArray(collection.items) || !Number.isSafeInteger(collection.count) ||
      collection.count !== collection.items.length || collection.items.length > 100) {
    throw new HttpsError("failed-precondition", "Payment outcome needs review");
  }
  const ids = new Set<string>();
  return collection.items.map((row: ProviderPayment) => {
    if (!row || row.entity !== "payment" || !isSafeProviderId(row.id) ||
        row.id.startsWith("pay_test_") || ids.has(row.id) || row.order_id !== orderId ||
        row.currency !== "INR" || !Number.isSafeInteger(row.amount) || row.amount !== amountPaise ||
        !["created", "authorized", "captured", "refunded", "failed"].includes(row.status) ||
        typeof row.captured !== "boolean" ||
        (["captured", "refunded"].includes(row.status) ? !row.captured : row.captured) ||
        !Number.isSafeInteger(row.amount_refunded) || row.amount_refunded < 0 ||
        row.amount_refunded > row.amount || ![null, "partial", "full"].includes(row.refund_status)) {
      throw new HttpsError("failed-precondition", "Payment outcome needs review");
    }
    ids.add(row.id);
    return row;
  });
}

export const recoverCheckoutPayment = onCall(
  { minInstances: 0, memory: "256MiB", secrets: [RAZORPAY_KEY_SECRET] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to recover checkout");
    }
    const uid = request.auth.uid;
    const { orderId, checkoutOwnerId, includeCheckoutOrder } = request.data || {};
    if (!isSafeProviderId(orderId) || typeof checkoutOwnerId !== "string" ||
        !checkoutOwnerId || checkoutOwnerId.length > 128 ||
        (includeCheckoutOrder !== undefined && typeof includeCheckoutOrder !== "boolean")) {
      throw new HttpsError("invalid-argument", "Missing checkout recovery details");
    }
    // Firebase transport can choose its auth token after the app session check.
    if (checkoutOwnerId !== uid) {
      throw new HttpsError("permission-denied", "Checkout does not belong to this account");
    }
    const credentials = getRazorpayCredentials();
    const mode = razorpayModeFromKey(credentials.keyId);
    if (!mode || !credentials.keySecret) {
      throw new HttpsError("failed-precondition", "Payments are not configured");
    }
    const db = admin.firestore();
    const orderRef = db.collection("razorpay_orders").doc(orderId);
    const order = requireGoodsOrder((await orderRef.get()).data(), orderId, uid, mode);
    let body: unknown;
    try {
      const response = await axios.get(`https://api.razorpay.com/v1/orders/${orderId}/payments`, {
        auth: { username: credentials.keyId, password: credentials.keySecret },
        timeout: 15000, maxContentLength: 256 * 1024, maxRedirects: 0,
      });
      body = response.data;
    } catch {
      // Provider exceptions contain auth headers and customer data. Do not log
      // or return them, and never report an uncertain lookup as a failed charge.
      throw new HttpsError("unavailable", "Payment outcome could not be checked. Try again later.");
    }
    const payments = readPayments(body, orderId, order.amountPaise);
    const captures = payments.filter(p => p.status === "captured");
    if (payments.some(p => p.status === "refunded" || p.amount_refunded !== 0 || p.refund_status !== null) ||
        captures.length > 1) {
      throw new HttpsError("failed-precondition", "Payment outcome needs review");
    }
    if (captures.length === 0) {
      // No new-charge permission: a created/authorized/failed/empty list is an
      // observation, not evidence that no future capture can occur.
      if (includeCheckoutOrder === true) {
        const stored = requireGoodsOrder((await orderRef.get()).data(), orderId, uid, mode);
        if (stored.amountPaise !== order.amountPaise || stored.amount !== order.amount) {
          throw new HttpsError("failed-precondition", "Saved payment needs review");
        }
        // Public metadata for the SAME owned order only. Never permit a new
        // order on an uncertain result. The provider enforces its paid state.
        return { success: true, verified: false, outcome: "unconfirmed", orderId,
          keyId: credentials.keyId, amountPaise: stored.amountPaise, currency: "INR" };
      }
      return { success: true, verified: false, outcome: "unconfirmed", orderId };
    }
    const payment = captures[0];
    const paymentRef = db.collection("verified_payments").doc(payment.id);
    await db.runTransaction(async tx => {
      const [orderSnap, paymentSnap] = await Promise.all([tx.get(orderRef), tx.get(paymentRef)]);
      const stored = requireGoodsOrder(orderSnap.data(), orderId, uid, mode);
      if (stored.amountPaise !== order.amountPaise || stored.amount !== order.amount) {
        throw new HttpsError("failed-precondition", "Saved payment needs review");
      }
      if (paymentSnap.exists) {
        const existing = paymentSnap.data()!;
        if (existing.userId !== uid || existing.orderId !== orderId || existing.paymentId !== payment.id ||
            existing.amount !== payment.amount / 100 ||
            (existing.amountPaise !== undefined && existing.amountPaise !== payment.amount) ||
            (existing.currency !== undefined && existing.currency !== "INR") ||
            (existing.purpose !== undefined && existing.purpose !== "goods_checkout") ||
            (existing.providerMode !== undefined && existing.providerMode !== mode) ||
            existing.isTest === true || existing.signatureVerified === false ||
            (existing.status !== undefined && existing.status !== "captured")) {
          throw new HttpsError("failed-precondition", "Saved payment needs review");
        }
      }
      // Merge preserves ALL consumption namespaces, including writes racing
      // this lookup. Do not claim signatureVerified: no SDK HMAC was supplied.
      tx.set(paymentRef, {
        userId: uid, orderId, paymentId: payment.id, amount: payment.amount / 100,
        amountPaise: payment.amount, currency: "INR", status: "captured",
        purpose: "goods_checkout", providerMode: mode, isTest: false,
        providerCaptureVerified: true, verificationMethod: "provider_api_recovery",
        recoveredAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    });
    return { success: true, verified: true, outcome: "captured", orderId,
      paymentId: payment.id, amountPaise: payment.amount, currency: "INR" };
  }
);
