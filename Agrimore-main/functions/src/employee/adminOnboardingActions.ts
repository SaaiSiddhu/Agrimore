// ============================================================
//  Admin onboarding actions — Phase 16A, Workstream 9
// ============================================================
//
// Three exports:
//   - waiveAssociateOnboardingFee     — admin lets an associate skip the fee
//   - recordAssociateOnboardingRefund — admin RECORDS that a refund
//                                       happened (see D6: never moves money)
//   - requestAssociateOnboardingRefundOnSuspend — Firestore trigger that
//                                       automatically opens a pending
//                                       refund request when a paid
//                                       associate is suspended
//
// Admin auth uses the CURRENT codebase pattern exactly, copied from
// admin/setUserRole.ts (Phase 15's newest admin-callable): claim-first
// (request.auth.token.admin === true), Firestore-role fallback otherwise.
// No email allowlist anywhere (S5) — this programme has been burned by
// hardcoded admin-email shortcuts twice already (findings #2 and C-5).

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as functionsV1 from "firebase-functions/v1";
import { log } from "../common/helpers";
import { ASSOCIATE_DISPLAY_TERM } from "./associateTerm";

interface CallableAuth {
  uid: string;
  token: { admin?: boolean };
}

async function assertCallerIsAdmin(auth: CallableAuth | undefined): Promise<CallableAuth> {
  if (!auth) {
    throw new HttpsError("unauthenticated", "Sign in required");
  }
  const isAdminClaim = auth.token.admin === true;
  if (!isAdminClaim) {
    const callerSnap = await admin.firestore().collection("users").doc(auth.uid).get();
    if (callerSnap.data()?.role !== "admin") {
      throw new HttpsError("permission-denied", "Admin only");
    }
  }
  return auth;
}

// ============================================================
// 9a — waiveAssociateOnboardingFee
// ============================================================
export const waiveAssociateOnboardingFee = onCall(
  { minInstances: 0, memory: "256MiB" },
  async (request) => {
    const auth = await assertCallerIsAdmin(request.auth as CallableAuth | undefined);

    const employeeId = String(request.data?.employeeId || "").trim();
    const reason = String(request.data?.reason || "").trim();
    if (!employeeId) throw new HttpsError("invalid-argument", "employeeId is required");
    if (!reason) throw new HttpsError("invalid-argument", "A reason is required to waive the onboarding fee");

    const db = admin.firestore();
    const employeeRef = db.collection("employees").doc(employeeId);

    await db.runTransaction(async (tx) => {
      const snap = await tx.get(employeeRef);
      if (!snap.exists) throw new HttpsError("not-found", `${ASSOCIATE_DISPLAY_TERM} not found`);
      const employee = snap.data()!;

      // Decision (9a — already-paid case): REFUSED. Waiving is meant to
      // let an associate skip an unpaid fee; if they already paid, the
      // correct reversing action is recordAssociateOnboardingRefund
      // (9b) — allowing both onboardingPaid AND onboardingWaived to be
      // true simultaneously would leave two conflicting "why is this
      // associate active" truths on the same document for no benefit.
      if (employee.onboardingPaid === true) {
        throw new HttpsError(
          "failed-precondition",
          "This associate has already paid the onboarding fee. Use the refund action instead if you want to reverse it."
        );
      }
      if (employee.onboardingWaived === true) {
        // Idempotent no-op — calling this twice must not error.
        return;
      }

      // SECURITY INVARIANT (S4): WAIVING THE FEE IS NOT APPROVAL. This
      // must NEVER set `status`. Admin approval remains a fully separate,
      // unchanged, admin-only action performed elsewhere.
      tx.update(employeeRef, {
        onboardingWaived: true,
        onboardingWaivedAt: admin.firestore.FieldValue.serverTimestamp(),
        onboardingWaivedBy: auth.uid,
        onboardingWaivedReason: reason,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const eventRef = db.collection("onboarding_events").doc();
      tx.set(eventRef, {
        type: "waiver",
        uid: employeeId,
        actorUid: auth.uid,
        reason,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    log.success(`✅ Onboarding fee waived for ${employeeId} by admin ${auth.uid}`);
    return { success: true, employeeId };
  }
);

// ============================================================
// 9b — recordAssociateOnboardingRefund
// ============================================================
export const recordAssociateOnboardingRefund = onCall(
  { minInstances: 0, memory: "256MiB" },
  async (request) => {
    const auth = await assertCallerIsAdmin(request.auth as CallableAuth | undefined);

    const employeeId = String(request.data?.employeeId || "").trim();
    const reason = String(request.data?.reason || "").trim();
    if (!employeeId) throw new HttpsError("invalid-argument", "employeeId is required");
    if (!reason) throw new HttpsError("invalid-argument", "A reason is required to record a refund");

    const db = admin.firestore();
    const employeeRef = db.collection("employees").doc(employeeId);

    await db.runTransaction(async (tx) => {
      const snap = await tx.get(employeeRef);
      if (!snap.exists) throw new HttpsError("not-found", `${ASSOCIATE_DISPLAY_TERM} not found`);
      const employee = snap.data()!;

      if (employee.onboardingRefundedAt) {
        // Idempotent no-op.
        return;
      }
      if (employee.onboardingPaid !== true) {
        // Covers both "never paid" and "waived, not paid" — nothing was
        // ever collected, so there is nothing to refund.
        throw new HttpsError(
          "failed-precondition",
          "This associate never paid the onboarding fee — there is nothing to refund."
        );
      }

      // ================================================================
      // THIS RECORDS A REFUND. IT DOES NOT MOVE MONEY (Decision D6). The
      // actual Razorpay refund must be issued BY HAND, by the owner, in
      // the Razorpay dashboard. This write only records that it happened
      // (or should happen) and why, and flips the onboarding gate closed:
      // EmployeeModel's gate-cleared getter reads false once
      // onboardingRefundedAt is set, regardless of onboardingPaid.
      // ================================================================
      tx.update(employeeRef, {
        onboardingRefundedAt: admin.firestore.FieldValue.serverTimestamp(),
        onboardingRefundedBy: auth.uid,
        onboardingRefundedReason: reason,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const eventRef = db.collection("onboarding_events").doc();
      tx.set(eventRef, {
        type: "refund_recorded",
        uid: employeeId,
        actorUid: auth.uid,
        reason,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    log.success(`✅ Onboarding refund recorded (NOT executed — record only) for ${employeeId} by admin ${auth.uid}`);
    return { success: true, employeeId };
  }
);

// ============================================================
// 9c — requestAssociateOnboardingRefundOnSuspend (Firestore trigger)
// ============================================================
// Decision (9c — trigger vs. callable): TRIGGER. A callable requires an
// admin to remember to invoke it separately from the suspension action
// itself — exactly the "so it cannot be forgotten" failure mode this
// workstream exists to close. Mirrors employeeCommission.ts's
// before/after transition-detection pattern exactly (fires only on the
// transition INTO 'suspended', never on every write while already
// suspended).
export const requestAssociateOnboardingRefundOnSuspend = functionsV1.firestore
  .document("employees/{employeeId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const employeeId = context.params.employeeId as string;

    if (before.status === "suspended" || after.status !== "suspended") {
      return null;
    }

    // Only an associate who cleared the gate BY PAYMENT gets an automatic
    // refund request — a waived-only associate had nothing collected from
    // them, so there is nothing to refund (Workstream 9c's explicit
    // wording: "cleared the gate BY PAYMENT").
    if (before.onboardingPaid !== true || before.onboardingRefundedAt) {
      return null;
    }

    const paymentId = before.onboardingPaymentId as string | undefined;
    const amount = before.onboardingFeeAmount as number | undefined;
    if (!paymentId) {
      log.warn(
        `⚠️ Employee ${employeeId} suspended after onboardingPaid=true but has no onboardingPaymentId on record — skipping automatic refund request`
      );
      return null;
    }

    const db = admin.firestore();
    // Deterministic id keyed on (employeeId, paymentId): idempotent
    // against duplicate/retried trigger invocations for the SAME payment,
    // while still allowing a NEW request if this associate is
    // re-onboarded (a new paymentId) and suspended again later.
    const requestRef = db.collection("associate_refund_requests").doc(`${employeeId}_${paymentId}`);
    const existing = await requestRef.get();
    if (existing.exists) {
      return null;
    }

    // Creates a REQUEST. Never moves money (D6) — an admin actions it by
    // hand in the Razorpay dashboard, then (separately)
    // recordAssociateOnboardingRefund marks it recorded.
    await requestRef.set({
      employeeId,
      paymentId,
      amount: amount ?? null,
      status: "pending",
      reason: "Associate suspended after clearing onboarding by payment — automatic refund request",
      requestedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    log.info(
      `📌 Automatic onboarding refund request created for suspended associate ${employeeId} (payment ${paymentId})`
    );
    return null;
  });
