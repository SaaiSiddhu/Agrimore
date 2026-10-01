// ============================================================
//  HTTP: razorpayOnboardingWebhook — Phase 16A, Workstream 7
// ============================================================
//
// THE SOURCE OF TRUTH for associate onboarding activation. If the browser
// closes, crashes, or loses network between Razorpay capturing the ₹500
// and the client calling activateAssociateOnboarding, the associate has
// paid and has nothing — in a paid-signup product this is the single
// largest source of support burden and chargeback risk. This endpoint
// activates independently of whether the client callback ever runs; the
// client callback (activateAssociateOnboarding) is best-effort UX only.
//
// Contains NO independent validation/activation logic of its own beyond
// what THIS specific delivery channel requires (signature verification,
// idempotency, event/purpose filtering) — the actual money gate is
// activationCore.performOnboardingActivation, called once below.

import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import * as admin from "firebase-admin";
import * as crypto from "crypto";
import axios from "axios";
import { log } from "../common/helpers";
import { getRazorpayCredentials, RAZORPAY_KEY_SECRET } from "../customer/payment";
import { performOnboardingActivation } from "./activationCore";
import { ONBOARDING_PURPOSE } from "./onboardingConfig";
import { isSafeProviderId, razorpayModeFromKey } from "../common/paymentIntegrity";
import { verifyOnboardingCapture } from "./onboardingVerification";

// Phase 18, Workstream 1: distinct from RAZORPAY_KEY_SECRET (imported above,
// used for HMAC-signing checkout payments) — Razorpay issues a separate
// webhook secret when a webhook endpoint is configured in the dashboard.
// Read site unchanged (still process.env.RAZORPAY_WEBHOOK_SECRET) — see
// payment.ts's RAZORPAY_KEY_SECRET comment for why binding a secret never
// requires changing how it's read.
const RAZORPAY_WEBHOOK_SECRET_PARAM = defineSecret("RAZORPAY_WEBHOOK_SECRET");
const RAZORPAY_WEBHOOK_SECRET = process.env.RAZORPAY_WEBHOOK_SECRET || "";

// Minimal shape of a Razorpay `payment.captured` webhook delivery — only
// the fields this function actually reads.
interface RazorpayWebhookBody {
  event?: string;
  payload?: {
    payment?: {
      entity?: {
        id?: string;
        order_id?: string;
        status?: string;
        notes?: Record<string, string>;
      };
    };
  };
}

// Deliberately a DIFFERENT env var from RAZORPAY_KEY_SECRET (used for
// HMAC-signing checkout payments in customer/payment.ts) — Razorpay issues
// a separate webhook secret when a webhook endpoint is configured in the
// dashboard, and it must never be conflated with the API key secret.

function timingSafeEqualHex(expectedHex: string, receivedHex: string): boolean {
  const expected = Buffer.from(expectedHex, "utf8");
  const received = Buffer.from(receivedHex, "utf8");
  // A length mismatch is not itself a timing side-channel worth protecting
  // against — HMAC-SHA256 hex digests are always 64 characters, so an
  // attacker who can already observe response timing learns nothing new
  // from "the lengths differ" that they couldn't already infer. Falling
  // back to `false` here (instead of throwing, which crypto.timingSafeEqual
  // does on length mismatch) keeps this function total.
  if (expected.length !== received.length) return false;
  return crypto.timingSafeEqual(expected, received);
}

export const razorpayOnboardingWebhook = onRequest(
  // cors: false — explicit, not just "omitted". This endpoint is called
  // server-to-server by Razorpay's infrastructure only; it has no
  // legitimate browser caller and therefore needs no CORS support at all.
  // This programme already shipped a critical vulnerability (C-1) partly
  // enabled by a wide-open onRequest with `Access-Control-Allow-Origin:
  // "*"` (see common/sendPhoneOTP.ts, sendEmailOTP.ts, verifyPhoneOTP.ts,
  // verifyEmailOTP.ts — all still carry that pattern today because they
  // ARE called from a browser). Nothing in this function ever sets
  // Access-Control-Allow-Origin.
  {
    minInstances: 0,
    memory: "256MiB",
    cors: false,
    // Phase 18, Workstream 1: needs BOTH secrets — RAZORPAY_KEY_SECRET for
    // the live-API capture check (via getRazorpayCredentials(), used
    // further down in this file) and RAZORPAY_WEBHOOK_SECRET for the
    // webhook signature check above.
    secrets: [RAZORPAY_KEY_SECRET, RAZORPAY_WEBHOOK_SECRET_PARAM],
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    // Fail closed if the webhook secret isn't configured — never fall open
    // to "accept everything because we can't check."
    if (!RAZORPAY_WEBHOOK_SECRET) {
      log.error(
        "🚨 RAZORPAY_WEBHOOK_SECRET is not set — refusing all onboarding webhook deliveries (fail closed)."
      );
      res.status(500).send("Webhook not configured");
      return;
    }

    const signature = req.get("x-razorpay-signature");
    if (!signature) {
      log.warn("⚠️ Onboarding webhook delivery with no X-Razorpay-Signature header — rejected");
      res.status(400).send("Missing signature");
      return;
    }

    // MUST use the raw, exact bytes Razorpay signed — never a
    // re-serialised JSON.stringify(req.body). Re-serialisation can differ
    // from the original transmitted bytes in key order, whitespace, or
    // number formatting, which would produce a signature mismatch for a
    // completely genuine request. Firebase Functions (v1 and v2 onRequest
    // alike) preserves the original body as req.rawBody for exactly this
    // use case.
    const rawBody = (req as unknown as { rawBody?: Buffer }).rawBody;
    if (!rawBody) {
      log.error("🚨 req.rawBody unavailable for onboarding webhook — cannot verify signature, rejecting");
      res.status(500).send("Internal error");
      return;
    }

    const expectedSignature = crypto
      .createHmac("sha256", RAZORPAY_WEBHOOK_SECRET)
      .update(rawBody)
      .digest("hex");

    if (!timingSafeEqualHex(expectedSignature, signature)) {
      log.error("🚨 Onboarding webhook signature mismatch — possible spoofing attempt, rejected");
      res.status(400).send("Invalid signature");
      return;
    }

    let body: RazorpayWebhookBody;
    try {
      body = JSON.parse(rawBody.toString("utf8"));
    } catch {
      log.error("🚨 Onboarding webhook body failed to parse as JSON despite a valid signature");
      res.status(400).send("Malformed body");
      return;
    }

    const eventType = body?.event;
    if (eventType !== "payment.captured") {
      // Not an event this endpoint acts on. 200 so Razorpay doesn't retry
      // an event we will never do anything with.
      res.status(200).send("Ignored (event type)");
      return;
    }

    const paymentEntity = body?.payload?.payment?.entity || {};
    const paymentId = paymentEntity.id as string | undefined;
    const orderId = paymentEntity.order_id as string | undefined;
    const notes = paymentEntity.notes || {};

    if (!isSafeProviderId(paymentId) || !isSafeProviderId(orderId)) {
      log.warn("⚠️ Onboarding webhook payment.captured event missing payment id/order id — ignored");
      res.status(200).send("Ignored (malformed payload)");
      return;
    }

    if (notes.purpose !== ONBOARDING_PURPOSE) {
      // A payment.captured event for something else entirely (a regular
      // marketplace order, a wallet top-up). Not ours.
      res.status(200).send("Ignored (not associate onboarding)");
      return;
    }

    const db = admin.firestore();

    // IDEMPOTENCY: Razorpay retries webhook deliveries on any non-2xx
    // response and can occasionally redeliver even after a 2xx. Prefer
    // Razorpay's own X-Razorpay-Event-Id header when present; otherwise
    // fall back to a deterministic composite key (event type + payment
    // id) — a given payment fires `payment.captured` exactly once, so this
    // composite is stable across redeliveries of the SAME event without
    // depending on a header Razorpay may not send in every account
    // configuration.
    const eventIdHeader = req.get("x-razorpay-event-id");
    if (eventIdHeader && (eventIdHeader.length > 512 || eventIdHeader.includes("/"))) {
      res.status(400).send("Invalid event id");
      return;
    }
    const eventKey = eventIdHeader || `${eventType}_${paymentId}`;
    const eventRef = db.collection("webhook_events").doc(eventKey);

    const eventSnap = await eventRef.get();
    if (eventSnap.exists) {
      log.info(`ℹ️ Onboarding webhook event already processed: ${eventKey} — no-op`);
      res.status(200).send("Already processed");
      return;
    }

    try {
      const verifiedPaymentsRef = db.collection("verified_payments").doc(paymentId);
      const { keyId, keySecret } = getRazorpayCredentials();
      const verifiedSnap = await verifiedPaymentsRef.get();
      let livePayment: Record<string, unknown> | undefined;

      if (!verifiedSnap.exists) {
        // Decision (7e, option i — see completion report Decisions
        // section): perform the same live-Razorpay-API capture check
        // verifyRazorpayPayment does (customer/payment.ts) and write
        // verified_payments ourselves, rather than deferring entirely to
        // the reconciler — this lets a webhook that beats the client
        // callback activate immediately, which is this endpoint's whole
        // purpose. The userId written into verified_payments is NEVER
        // taken from the webhook body; it is cross-checked against
        // razorpay_orders/{orderId}.userId, written by
        // createAssociateOnboardingPayment.ts at order-creation time — a
        // value Razorpay's servers never see or control.
        if (!keyId || !keySecret) {
          log.error("🚨 Razorpay credentials not configured — cannot verify onboarding webhook payment");
          res.status(200).send("Ignored (credentials not configured)");
          return;
        }

        const authHeader = Buffer.from(`${keyId}:${keySecret}`).toString("base64");
        const liveResponse = await axios.get(`https://api.razorpay.com/v1/payments/${paymentId}`, {
          headers: { Authorization: `Basic ${authHeader}` },
        });
        livePayment = liveResponse.data;

        if (!livePayment || livePayment.status !== "captured") {
          log.warn(
            `⚠️ Onboarding webhook fired for ${paymentId} but live Razorpay status is not captured — not activating`
          );
          res.status(200).send("Ignored (not captured per live API)");
          return;
        }
      }

      const verification = await verifyOnboardingCapture({
        db, paymentId, orderId, notesUserId: notes.userId, livePayment, source: "webhook",
        providerMode: razorpayModeFromKey(keyId),
      });
      if (!verification.ok) {
        await db.collection("onboarding_exceptions").add({
          paymentId, orderId, reason: verification.reason, source: "webhook",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        res.status(200).send("Ignored (payment binding mismatch)");
        return;
      }
      const uid = verification.uid;

      const result = await performOnboardingActivation({ db, uid, paymentId, source: "webhook" });
      if (!result.ok && !result.alreadyActive) {
        log.warn(
          `⚠️ Onboarding webhook activation did not succeed for payment=${paymentId} uid=${uid} code=${result.failureCode}`
        );
      } else {
        log.success(
          `✅ Onboarding webhook activation processed for payment=${paymentId} uid=${uid} alreadyActive=${!!result.alreadyActive}`
        );
      }

      // Mark the event processed regardless of activation outcome — a
      // permanent failureCode (e.g. amount mismatch) will never succeed on
      // redelivery of this SAME event either, and
      // reconcileStaleOnboardingPayments (Workstream 8) is the real safety
      // net for anything left un-activated.
      await eventRef.set({
        eventType,
        paymentId,
        orderId,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        activationOk: result.ok,
        activationFailureCode: result.failureCode || null,
      });

      res.status(200).send("OK");
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : String(error);
      log.error(`❌ Onboarding webhook processing error for payment=${paymentId}: ${message}`);
      // A genuine internal error (Razorpay live-API network failure,
      // Firestore contention, etc.) — respond non-2xx so Razorpay retries.
      // webhook_events was never written on this path, so a retry
      // correctly re-attempts from scratch.
      res.status(500).send("Internal error");
    }
  }
);
