// ============================================================
//  Callable: activateAssociateOnboarding — Phase 16A, Workstream 6
// ============================================================
//
// Client-facing wrapper around activationCore.performOnboardingActivation.
// Best-effort UX only — the REAL source of truth is
// razorpayOnboardingWebhook (Workstream 7), which activates independently
// of whether this callable ever runs (browser closed, network dropped,
// etc.). This file contains NO validation logic of its own: it derives
// `uid` from the authenticated caller, forwards it and the client-supplied
// `paymentId` to the shared core, and translates the core's result into an
// HttpsError. Nothing about money, amounts, or payment status is decided
// here.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { log } from "../common/helpers";
import { performOnboardingActivation, ActivationFailureCode } from "./activationCore";
import { ASSOCIATE_DISPLAY_TERM } from "./associateTerm";

function messageForFailure(code: ActivationFailureCode | undefined): string {
  switch (code) {
  case "config_invalid":
  case "config_disabled":
    return `${ASSOCIATE_DISPLAY_TERM} onboarding payment is not available right now. Please try again later or contact support.`;
  case "employee_not_found":
    return `Please complete your ${ASSOCIATE_DISPLAY_TERM} registration details before paying the onboarding fee.`;
  case "payment_not_found":
  case "payment_wrong_user":
  case "payment_not_captured":
  case "payment_amount_mismatch":
  case "payment_already_consumed_by_order":
  case "payment_already_consumed_by_onboarding":
    // Deliberately generic to the caller for every payment-trust-boundary
    // failure — never reveal WHICH specific check failed (e.g. "this
    // payment belongs to a different user") to avoid leaking internal
    // state about other users' payments. The specific failureCode is
    // still logged server-side below for support/debugging.
    return "We could not verify this payment for your onboarding fee. If you were charged, please contact support.";
  default:
    return "We could not activate your onboarding. Please contact support.";
  }
}

export const activateAssociateOnboarding = onCall(
  { minInstances: 0, memory: "256MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required");
    }

    const uid = request.auth.uid;
    // Accepts NOTHING that affects money — no amount, no uid, no
    // employeeId. razorpayOrderId is accepted but not currently required
    // by the core (kept for forward-compatible client logging/debugging
    // only; the core keys everything off paymentId).
    const paymentId = String(request.data?.paymentId || "").trim();
    if (!paymentId) {
      throw new HttpsError("invalid-argument", "paymentId is required");
    }

    const db = admin.firestore();
    const result = await performOnboardingActivation({ db, uid, paymentId, source: "client" });

    if (!result.ok) {
      log.error(
        `❌ Associate onboarding activation failed: uid=${uid} payment=${paymentId} code=${result.failureCode}`
      );
      throw new HttpsError("failed-precondition", messageForFailure(result.failureCode));
    }

    if (result.alreadyActive) {
      // A double-tap or retry must read as SUCCESS to the user, not a
      // scary failure — they already paid and are already active.
      log.info(`ℹ️ Associate onboarding already active (idempotent retry): uid=${uid}`);
      return { success: true, alreadyActive: true };
    }

    log.success(`✅ Associate onboarding activated via client callback: uid=${uid}`);
    return { success: true, alreadyActive: false };
  }
);
