// ============================================================
//  Scheduled: reconcileStaleOnboardingPayments — Phase 16A, Workstream 8
// ============================================================
//
// Safety net for the case even the webhook can miss: a webhook delivery
// that never arrives (Razorpay retries with backoff and eventually gives
// up) or arrives while this endpoint's environment is unhealthy. Detects
// "money taken but onboarding never activated" so an admin finds out from
// onboarding_exceptions, not from an angry associate.

import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import Razorpay from "razorpay";
import { log } from "../common/helpers";
import { getRazorpayCredentials } from "../customer/payment";
import { performOnboardingActivation } from "./activationCore";
import { ONBOARDING_PURPOSE } from "./onboardingConfig";

// Decision (8a/8d — see completion report Decisions section): a stale
// order is one created more than STALENESS_MINUTES ago (long enough that
// both the client callback AND a normal webhook delivery should already
// have fired). LOOKBACK_HOURS bounds the query window so this job never
// scans unbounded history — this programme's cost initiative (Phases
// 10-13) exists specifically because of unbounded reads, and this job
// must not regress it. An order that never gets a captured payment within
// LOOKBACK_HOURS simply falls out of this job's scope permanently (stated
// limitation — see the completion report).
const STALENESS_MINUTES = 30;
const LOOKBACK_HOURS = 24;
const MAX_ORDERS_PER_RUN = 50;

export const reconcileStaleOnboardingPayments = onSchedule(
  { schedule: "every 15 minutes", timeZone: "Asia/Kolkata", memory: "256MiB" },
  async () => {
    const db = admin.firestore();
    const now = Date.now();
    const staleCutoff = admin.firestore.Timestamp.fromMillis(now - STALENESS_MINUTES * 60 * 1000);
    const lookbackFloor = admin.firestore.Timestamp.fromMillis(now - LOOKBACK_HOURS * 60 * 60 * 1000);

    // Bounded query: fixed [lookbackFloor, staleCutoff] window, capped at
    // MAX_ORDERS_PER_RUN. Requires a composite index on razorpay_orders
    // (purpose ASC, createdAt ASC) — added to firestore.indexes.json by
    // this phase; the owner must deploy it (see completion report Section
    // V-equivalent) before this function can run without a
    // failed-precondition "requires an index" error.
    const snap = await db
      .collection("razorpay_orders")
      .where("purpose", "==", ONBOARDING_PURPOSE)
      .where("createdAt", ">=", lookbackFloor)
      .where("createdAt", "<=", staleCutoff)
      .orderBy("createdAt", "asc")
      .limit(MAX_ORDERS_PER_RUN)
      .get();

    if (snap.size >= MAX_ORDERS_PER_RUN) {
      log.warn(
        `⚠️ reconcileStaleOnboardingPayments hit its per-run cap of ${MAX_ORDERS_PER_RUN} orders — some stale orders were NOT processed this run and will be picked up on the next run.`
      );
    }
    log.info(`📌 reconcileStaleOnboardingPayments: found ${snap.size} candidate order(s)`);

    if (snap.empty) {
      return;
    }

    const { keyId, keySecret } = getRazorpayCredentials();
    if (!keyId || !keySecret) {
      log.error("🚨 reconcileStaleOnboardingPayments: Razorpay credentials not configured — skipping run");
      return;
    }
    const razorpay = new Razorpay({ key_id: keyId, key_secret: keySecret });

    let activated = 0;
    let exceptions = 0;

    for (const orderDoc of snap.docs) {
      const order = orderDoc.data();
      const employeeId = (order.employeeId || order.userId) as string | undefined;
      if (!employeeId) {
        continue;
      }

      const employeeSnap = await db.collection("employees").doc(employeeId).get();
      const employee = employeeSnap.data();
      const alreadyGateCleared =
        !!employee &&
        (employee.onboardingPaid === true || employee.onboardingWaived === true) &&
        !employee.onboardingRefundedAt;
      if (alreadyGateCleared) {
        continue;
      }

      try {
        // Never move money — read-only Razorpay call. Finds a captured
        // payment for this order, if one exists.
        const paymentsResp = await razorpay.orders.fetchPayments(orderDoc.id);
        const capturedPayment = (paymentsResp.items || []).find((p) => p.status === "captured");
        if (!capturedPayment) {
          // No captured payment for this order at all — a normal
          // abandoned checkout, not a system failure. Nothing to
          // reconcile.
          continue;
        }

        const result = await performOnboardingActivation({
          db,
          uid: employeeId,
          paymentId: capturedPayment.id,
          source: "reconciler",
        });

        if (result.ok) {
          activated++;
          log.success(
            `✅ reconcileStaleOnboardingPayments activated uid=${employeeId} payment=${capturedPayment.id}`
          );
        } else if (!result.alreadyActive) {
          // A captured payment exists but activation still failed (e.g.
          // amount mismatch, cross-consumed payment) — the exact
          // "paid but not active" case an admin needs visibility into
          // without reading logs. This is this job's operational
          // deliverable.
          exceptions++;
          await db.collection("onboarding_exceptions").add({
            employeeId,
            orderId: orderDoc.id,
            paymentId: capturedPayment.id,
            reason: result.failureCode || "unknown",
            source: "reconciler",
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          log.error(
            `❌ reconcileStaleOnboardingPayments: paid but could not activate uid=${employeeId} payment=${capturedPayment.id} code=${result.failureCode}`
          );
        }
      } catch (error: unknown) {
        const message = error instanceof Error ? error.message : String(error);
        log.error(`❌ reconcileStaleOnboardingPayments error for order=${orderDoc.id}: ${message}`);
      }
    }

    log.info(
      `📌 reconcileStaleOnboardingPayments run complete: activated=${activated} exceptions=${exceptions}`
    );
  }
);
