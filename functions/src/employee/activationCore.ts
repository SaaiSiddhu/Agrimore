// ============================================================
//  Associate Onboarding — shared activation core (Phase 16A, Workstream 5)
// ============================================================
//
// This file is the ONLY place that decides whether an onboarding payment
// activates an associate. Three callers use it — the client-facing
// activateAssociateOnboarding callable, razorpayOnboardingWebhook, and
// reconcileStaleOnboardingPayments — and every one of them is a thin
// wrapper that authenticates/authorises its own caller and then delegates
// here. None of them re-implements any part of this gate; if you're
// tempted to add a validation check in one of those three files instead of
// here, that's the wrong file.
//
// Mirrors functions/src/customer/createOrder.ts's transaction shape
// exactly: every Firestore read happens before any write (a hard
// Firestore transaction requirement), and the payment-consumption write
// uses the same idempotency-anchor pattern as createOrder.ts's
// `consumedByOrderId` write.

import * as admin from "firebase-admin";
import { log } from "../common/helpers";
import { isSpendableCapturedPayment } from "../common/paymentIntegrity";
import { loadOnboardingConfig } from "./onboardingConfig";

export type ActivationSource = "client" | "webhook" | "reconciler";

export type ActivationFailureCode =
  | "config_invalid"
  | "config_disabled"
  | "payment_not_found"
  | "payment_wrong_user"
  | "payment_not_captured"
  | "payment_amount_mismatch"
  | "payment_already_consumed_by_order"
  | "payment_already_consumed_by_onboarding"
  // Phase FIX-1 (finding N-1, P0): the third consumption direction. A payment
  // already credited to a wallet must not also activate onboarding.
  | "payment_already_consumed_by_wallet_topup"
  // Phase AI-4 (D-SELLER-AI-FUNDING): the fourth consumption direction. A
  // payment already spent on a seller's AI Assistant activation must not
  // also activate onboarding.
  | "payment_already_consumed_by_seller_ai_activation"
  | "employee_not_found";

export interface ActivationResult {
  ok: boolean;
  alreadyActive?: boolean;
  failureCode?: ActivationFailureCode;
  employeeId?: string;
  paymentId?: string;
  amount?: number;
}

export interface ActivationParams {
  db: admin.firestore.Firestore;
  uid: string;
  paymentId: string;
  source: ActivationSource;
}

// Amount-match tolerance (Workstream 5c.5 decision — see the completion
// report's Decisions section for the full justification). Unlike
// createOrder.ts's ±₹1 tolerance on a MULTI-COMPONENT computed total
// (subtotal - discount + delivery + tax, which can accumulate real
// per-seller rounding error — see roundMoney() calls throughout
// createOrder.ts), the onboarding fee is a single, fixed,
// server-configured number with no arithmetic performed on it anywhere.
// This tolerance exists ONLY to absorb floating-point representation noise
// from Razorpay's paise-to-rupee division (payment.amount / 100 in
// payment.ts), never to permit a genuine underpayment or overpayment.
const ONBOARDING_AMOUNT_TOLERANCE = 0.01;

export async function performOnboardingActivation(
  params: ActivationParams
): Promise<ActivationResult> {
  const { db, uid, paymentId, source } = params;

  return db.runTransaction(async (tx) => {
    // ============================================
    // ALL READS FIRST
    // ============================================
    const config = await loadOnboardingConfig(db, tx);
    const paymentRef = db.collection("verified_payments").doc(paymentId);
    const paymentSnap = await tx.get(paymentRef);
    const employeeRef = db.collection("employees").doc(uid);
    const employeeSnap = await tx.get(employeeRef);

    // ============================================
    // VALIDATION — fail closed at every step (S9)
    // ============================================
    if (!config.valid) {
      return { ok: false, failureCode: "config_invalid" as const };
    }
    if (!config.isEnabled) {
      return { ok: false, failureCode: "config_disabled" as const };
    }

    if (!paymentSnap.exists) {
      return { ok: false, failureCode: "payment_not_found" as const };
    }
    const payment = paymentSnap.data()!;

    // Fail-closed on legacy verified_payments documents written before
    // Phase 14 added `userId` (see payment.ts's header comment on that
    // change) — mirrors createOrder.ts's identical check (its comment
    // directly above `if (!payment.userId || payment.userId !== uid)`)
    // exactly: a missing userId is "not verifiably this caller's
    // payment," never "unknown, so allow it."
    if (!payment.userId || payment.userId !== uid) {
      return { ok: false, failureCode: "payment_wrong_user" as const };
    }
    if (!isSpendableCapturedPayment(payment, paymentId)) {
      return { ok: false, failureCode: "payment_not_captured" as const };
    }

    const paidAmount = typeof payment.amount === "number" ? payment.amount : -1;
    if (Math.abs(paidAmount - (config.feeAmount as number)) > ONBOARDING_AMOUNT_TOLERANCE) {
      return { ok: false, failureCode: "payment_amount_mismatch" as const };
    }

    if (!employeeSnap.exists) {
      return { ok: false, failureCode: "employee_not_found" as const };
    }
    const employee = employeeSnap.data()!;

    // IDEMPOTENCY (S3, Workstream 5c.9) — checked BEFORE the
    // consumption-marker checks below, deliberately. An associate who
    // already cleared the gate must see success on a retried/duplicated
    // activation call — e.g. the client callback retrying after a dropped
    // response, or the webhook and the client callback racing each other
    // within milliseconds. By the time such a retry arrives, THIS SAME
    // payment already carries `consumedByOnboardingFor: uid` from the
    // first successful call — checking that marker first (as an earlier,
    // now-corrected version of this function did) would misclassify a
    // legitimate replay as a hard failure, making this idempotency
    // guarantee unreachable in practice. This check is scoped to the
    // CALLING uid's own employee document, so it does not weaken the
    // cross-user protection below: an attacker whose OWN gate is not
    // cleared still falls through to the consumption checks regardless of
    // what this payment's marker says.
    const alreadyGateCleared =
      (employee.onboardingPaid === true || employee.onboardingWaived === true) &&
      !employee.onboardingRefundedAt;
    if (alreadyGateCleared) {
      return { ok: true, alreadyActive: true, employeeId: uid };
    }

    // Cross-consumption guard, one direction only (S3): a payment already
    // spent on a real order can never also activate onboarding. NOTE: the
    // reverse direction — createOrder.ts rejecting a payment already
    // consumed BY onboarding — is NOT enforced, because createOrder.ts is
    // out of this phase's scope to edit. This is a real, confirmed
    // residual finding; see the completion report's Security Caveats
    // section (item X) for the exact line numbers and recommended Phase
    // 16B fix.
    if (payment.consumedByOrderId) {
      return { ok: false, failureCode: "payment_already_consumed_by_order" as const };
    }
    if (payment.consumedByOnboardingFor) {
      return { ok: false, failureCode: "payment_already_consumed_by_onboarding" as const };
    }
    // Phase FIX-1 (finding N-1, P0): third direction. verifyWalletTopup
    // (functions/src/customer/wallet.ts) now claims a payment it credits with
    // consumedByWalletTopup, in the same transaction as the credit — so a
    // payment already turned into wallet balance must not also activate an
    // associate's ₹500 onboarding. Symmetric with the two checks above and with
    // createOrder.ts's own trust block.
    if (payment.consumedByWalletTopup) {
      return { ok: false, failureCode: "payment_already_consumed_by_wallet_topup" as const };
    }
    // Phase AI-4 (D-SELLER-AI-FUNDING): fourth direction. connectSellerAiProvider
    // (functions/src/seller/aiConnection.ts) now claims a payment it spends on a
    // seller's AI Assistant activation with consumedBySellerAiActivationFor, in the
    // same transaction as the connection write — so a payment already spent there
    // must not also activate an associate's ₹500 onboarding.
    if (payment.consumedBySellerAiActivationFor) {
      return { ok: false, failureCode: "payment_already_consumed_by_seller_ai_activation" as const };
    }

    // ============================================
    // ALL WRITES — same transaction, after every read above
    // ============================================
    //
    // SECURITY INVARIANT (S4): PAYING THE FEE IS NOT APPROVAL. This
    // function must NEVER set employees/{uid}.status. Admin approval stays
    // a fully separate, unchanged, admin-only action performed elsewhere.
    // Getting this wrong turns a ₹500 payment into a self-service role
    // grant.
    tx.update(employeeRef, {
      onboardingPaid: true,
      onboardingFeeAmount: config.feeAmount,
      onboardingPaymentId: paymentId,
      onboardingPaidAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Idempotency-anchor write, mirroring createOrder.ts's
    // consumedByOrderId write exactly: marking the payment consumed inside
    // the SAME transaction that grants what it pays for, so a
    // retried/racing call either sees the marker already set (checked
    // above, before any write) or loses the transaction race and retries
    // — never both succeed.
    tx.set(
      paymentRef,
      {
        consumedByOnboardingFor: uid,
        consumedByOnboardingAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    const eventRef = db.collection("onboarding_events").doc();
    tx.set(eventRef, {
      type: "activation",
      uid,
      paymentId,
      amount: config.feeAmount,
      source,
      configVersion: config.configVersion,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    log.success(
      `✅ Associate onboarding activated: uid=${uid} payment=${paymentId} source=${source}`
    );
    return {
      ok: true,
      alreadyActive: false,
      employeeId: uid,
      paymentId,
      amount: config.feeAmount as number,
    };
  });
}
