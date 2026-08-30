// ============================================================
//  Callable: createAssociateOnboardingPayment — Phase 16A, Workstream 4
// ============================================================
//
// Creates a Razorpay order for EXACTLY the server-configured onboarding
// fee and tags it `purpose: "associate_onboarding"` so
// razorpayOnboardingWebhook and reconcileStaleOnboardingPayments can find
// it later. Reuses getRazorpayCredentials() from customer/payment.ts
// rather than duplicating credential loading.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import Razorpay from "razorpay";
import { log } from "../common/helpers";
import { getRazorpayCredentials, RAZORPAY_KEY_SECRET } from "../customer/payment";
import { loadOnboardingConfig, ONBOARDING_PURPOSE } from "./onboardingConfig";
import { ASSOCIATE_DISPLAY_TERM } from "./associateTerm";

// Mirrors sendPhoneOTP.ts's RESEND_COOLDOWN_MS (30s) — the same
// "long enough to stop scripted spam, short enough not to punish a genuine
// retry" reasoning applies here: every call creates a REAL order via
// Razorpay's live API, which has its own cost and rate implications.
const RATE_LIMIT_WINDOW_MS = 30 * 1000;

export const createAssociateOnboardingPayment = onCall(
  // Phase 18, Workstream 1 / Trap 2: reached indirectly via
  // getRazorpayCredentials() imported above, not a direct process.env read
  // — easy to miss with a grep for "process.env" alone.
  { minInstances: 0, memory: "256MiB", secrets: [RAZORPAY_KEY_SECRET] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required");
    }
    const uid = request.auth.uid;
    const db = admin.firestore();

    // Amount comes ONLY from server config — never from the client (S8).
    const config = await loadOnboardingConfig(db);
    if (!config.valid || !config.isEnabled || typeof config.feeAmount !== "number") {
      throw new HttpsError(
        "failed-precondition",
        `${ASSOCIATE_DISPLAY_TERM} onboarding payment is not available right now. Please try again later.`
      );
    }

    // Requires employees/{uid} to already exist — the applicant submits
    // their details (via the existing, unmodified employee_apply_screen.dart
    // flow) before ever reaching payment.
    const employeeRef = db.collection("employees").doc(uid);
    const employeeSnap = await employeeRef.get();
    if (!employeeSnap.exists) {
      throw new HttpsError(
        "failed-precondition",
        `Please complete your ${ASSOCIATE_DISPLAY_TERM} registration details before paying the onboarding fee.`
      );
    }
    const employee = employeeSnap.data()!;

    // Decision (4h/4i — re-payment after refund): refused. A refund is
    // recorded (recordAssociateOnboardingRefund, Workstream 9b) as a
    // deliberate admin action, typically tied to rejection/suspension —
    // letting the same associate silently re-pay and re-activate would
    // bypass whatever review led to that refund. Re-enabling a refunded
    // associate is left as an explicit future admin action (not built in
    // this phase — see the completion report's Remaining Work section),
    // not something this callable does automatically.
    if (employee.onboardingRefundedAt) {
      throw new HttpsError(
        "failed-precondition",
        "Your onboarding fee was refunded. Please contact support if you would like to re-activate your account."
      );
    }

    const alreadyGateCleared =
      (employee.onboardingPaid === true || employee.onboardingWaived === true) &&
      !employee.onboardingRefundedAt;
    if (alreadyGateCleared) {
      throw new HttpsError("already-exists", "Your onboarding is already complete.");
    }

    // Rate limit — a dedicated, Cloud-Functions-only doc keyed by uid (a
    // direct get-by-id, not a query, so it needs no composite Firestore
    // index). Deliberately NOT stored as a field on employees/{uid}: that
    // document's owner-update rule only denylists the seven onboarding
    // fields (Workstream 10), so a rate-limit marker living there would be
    // freely client-resettable, defeating the whole point of throttling.
    const rateLimitRef = db.collection("onboarding_rate_limits").doc(uid);
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

    log.info(`💳 Creating associate onboarding Razorpay order for uid=${uid} amount=₹${config.feeAmount}`);

    const order = await razorpay.orders.create({
      amount: Math.round(config.feeAmount * 100),
      currency: config.currency as string,
      receipt: `assoc_onboard_${uid}_${Date.now()}`,
      notes: {
        purpose: ONBOARDING_PURPOSE,
        userId: uid,
        configVersion: String(config.configVersion),
      },
    });

    await rateLimitRef.set(
      { lastRequestAt: admin.firestore.FieldValue.serverTimestamp() },
      { merge: true }
    );

    // Mirrors createRazorpayOrder's razorpay_orders bookkeeping write
    // (customer/payment.ts), plus `purpose`/`employeeId` so the webhook
    // and reconciler can find this order later.
    await db.collection("razorpay_orders").doc(order.id).set({
      orderId: order.id,
      userId: uid,
      employeeId: uid,
      purpose: ONBOARDING_PURPOSE,
      amount: config.feeAmount,
      amountPaise: order.amount,
      currency: order.currency,
      status: order.status,
      receipt: order.receipt,
      configVersion: config.configVersion,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    log.success(`✅ Associate onboarding Razorpay order created: uid=${uid} order=${order.id}`);

    return {
      success: true,
      orderId: order.id,
      // The PUBLIC Razorpay key only — never the secret. Matches
      // createRazorpayOrder's own return shape exactly.
      amount: order.amount,
      currency: order.currency,
      keyId: RAZORPAY_KEY_ID,
    };
  }
);
