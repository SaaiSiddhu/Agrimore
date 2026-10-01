import * as admin from "firebase-admin";
import { isSafeProviderId, isSpendableCapturedPayment } from "../common/paymentIntegrity";
import { ONBOARDING_PURPOSE } from "./onboardingConfig";

type VerificationResult = { ok: true; uid: string } | { ok: false; reason: string };

// Both recovery channels establish the same immutable verification contract.
// Read again inside the transaction: a client verifier or economic consumer
// may have created/consumed this payment while the provider call was pending.
export async function verifyOnboardingCapture(params: {
  db: admin.firestore.Firestore;
  paymentId: string;
  orderId: string;
  notesUserId?: unknown;
  livePayment?: Record<string, unknown>;
  source: "webhook" | "reconciler";
}): Promise<VerificationResult> {
  const { db, paymentId, orderId, notesUserId, livePayment, source } = params;
  if (!isSafeProviderId(paymentId) || !isSafeProviderId(orderId)) {
    return { ok: false, reason: "invalid_payment_ids" };
  }
  return db.runTransaction(async (tx): Promise<VerificationResult> => {
    const paymentRef = db.collection("verified_payments").doc(paymentId);
    const [orderSnap, paymentSnap] = await Promise.all([
      tx.get(db.collection("razorpay_orders").doc(orderId)), tx.get(paymentRef),
    ]);
    const order = orderSnap.data(), existing = paymentSnap.data();
    const uid = order ? order.userId : existing?.userId;
    if (typeof uid !== "string" || !uid || uid.includes("/") ||
        (notesUserId !== undefined && notesUserId !== uid)) {
      return { ok: false, reason: "order_ownership_mismatch" };
    }
    let amountPaise: number | undefined;
    if (order) {
      if (order.orderId !== orderId || order.purpose !== ONBOARDING_PURPOSE ||
          order.currency !== "INR" ||
          (order.employeeId !== undefined && order.employeeId !== uid) ||
          typeof order.amount !== "number" || !Number.isFinite(order.amount) ||
          !Number.isSafeInteger(Math.round(order.amount * 100)) || Math.round(order.amount * 100) < 1) {
        return { ok: false, reason: "order_binding_mismatch" };
      }
      amountPaise = Math.round(order.amount * 100);
      if (!isSpendableCapturedPayment({ ...order, status: "captured", paymentId }, paymentId)) {
        return { ok: false, reason: "order_capture_not_spendable" };
      }
      // Older server order records can lack amountPaise; their finite INR
      // amount remains evidence. Explicit conflicting metadata never does.
      if (order.amountPaise !== undefined && order.amountPaise !== amountPaise) {
        return { ok: false, reason: "order_amount_mismatch" };
      }
    }
    if (livePayment && (livePayment.id !== paymentId || livePayment.order_id !== orderId ||
        livePayment.currency !== "INR" || !Number.isSafeInteger(livePayment.amount) ||
        !isSpendableCapturedPayment({ ...livePayment, paymentId, orderId,
          amount: (livePayment.amount as number) / 100 }, paymentId) ||
        (amountPaise !== undefined && livePayment.amount !== amountPaise))) {
      return { ok: false, reason: "provider_capture_mismatch" };
    }
    if (existing) {
      if (existing.paymentId !== paymentId || existing.orderId !== orderId || existing.userId !== uid ||
          (existing.purpose !== undefined && existing.purpose !== ONBOARDING_PURPOSE) ||
          !isSpendableCapturedPayment(existing, paymentId) ||
          (amountPaise !== undefined && Math.round(existing.amount * 100) !== amountPaise) ||
          (livePayment && Math.round(existing.amount * 100) !== livePayment.amount)) {
        return { ok: false, reason: "verified_binding_mismatch" };
      }
      // Do not refresh/replace it: all consumption and provenance fields
      // belong to the verifier/consumer that already won this transaction.
      return { ok: true, uid };
    }
    if (!order || !livePayment || amountPaise === undefined) {
      return { ok: false, reason: "capture_evidence_missing" };
    }
    tx.set(paymentRef, {
      paymentId, orderId, userId: uid, amount: amountPaise / 100,
      amountPaise, currency: "INR", purpose: ONBOARDING_PURPOSE,
      status: "captured", signatureVerified: true,
      isTest: order.isTest === true || order.isTestOrder === true ||
        livePayment.isTest === true || livePayment.isTestOrder === true,
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      verifiedBy: source === "webhook" ? "razorpayOnboardingWebhook" : "reconcileStaleOnboardingPayments",
      method: typeof livePayment.method === "string" ? livePayment.method : null,
    }, { merge: true });
    return { ok: true, uid };
  });
}
