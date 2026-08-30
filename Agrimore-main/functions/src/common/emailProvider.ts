// ============================================================
//  Phase 16, Workstream 3 — Resend email delivery
// ============================================================
//
// Pure delivery-channel wrapper around Resend's REST API. Verified against
// https://resend.com/docs/api-reference/emails/send-email (2026-08-30):
// POST https://api.resend.com/emails, `Authorization: Bearer <key>`, JSON
// body { from, to, subject, html }. One REST call — axios (already a
// functions dependency) is used rather than adding the `resend` npm
// package, which would only wrap this same single request.
//
// This module does NOT generate, hash, or store OTPs — that logic already
// lives in sendEmailOTP.ts (Phase 15) and is unchanged by this phase. This
// is a transport swap only, replacing nodemailer/Gmail SMTP.

import axios from "axios";

const RESEND_API_URL = "https://api.resend.com/emails";
const REQUEST_TIMEOUT_MS = 10_000;

// Phase 18, Workstream 1/2: RESEND_API_KEY is bound as a Secret Manager
// secret on sendEmailOTP (the only function that ever calls
// sendEmailViaResend below) — see sendEmailOTP.ts's runWith({secrets}).
// This module itself declares no binding; it's a plain helper, not an
// exported Cloud Function, so it has nothing to bind a secret TO — it just
// reads process.env at call time, which resolves correctly as long as the
// CALLING function declared the secret.
function apiKey(): string | null {
  const key = process.env.RESEND_API_KEY;
  return key && key.trim() ? key.trim() : null;
}

// Phase 18, Workstream 3 decision: RESEND_FROM_EMAIL is deliberately NOT a
// Secret Manager secret — it's a from-address, and appears in the header of
// every email this sends; there is nothing to protect. Supplied via plain
// functions/.env (see .env.example), like RAZORPAY_KEY_ID in payment.ts.
function fromAddress(): string | null {
  const from = process.env.RESEND_FROM_EMAIL;
  return from && from.trim() ? from.trim() : null;
}

export function isEmailProviderConfigured(): boolean {
  return apiKey() !== null && fromAddress() !== null;
}

// Resend accepts `text`, `html`, or both. Both are OPTIONAL here and at least
// one must be supplied — enforced at runtime below, because TypeScript cannot
// express "at least one of these two" without an awkward union that every
// caller would then have to satisfy.
//
// The OTP mail deliberately sends `text` only (owner decision, 2026-08-30:
// plain text, no colours, no theme). Plain text is also the better default for
// a one-time code — nothing to render, nothing to strip, and no image or CSS
// for a mail client to block.
interface SendEmailArgs {
  to: string;
  subject: string;
  text?: string;
  html?: string;
}

/** Sends an email via Resend. Throws on any failure — never returns partial success. */
export async function sendEmailViaResend({ to, subject, text, html }: SendEmailArgs): Promise<void> {
  const key = apiKey();
  const from = fromAddress();
  if (!key || !from) {
    throw new Error("Email provider not configured");
  }
  if (!text && !html) {
    // Fail loudly rather than posting a body-less email that Resend would
    // accept and the recipient would receive blank.
    throw new Error("sendEmailViaResend requires at least one of `text` or `html`");
  }

  try {
    const response = await axios.post(
      RESEND_API_URL,
      // Omit the absent field entirely rather than sending `undefined` —
      // Resend treats a present-but-empty body part as a real empty body.
      { from, to, subject, ...(text ? { text } : {}), ...(html ? { html } : {}) },
      {
        headers: {
          Authorization: `Bearer ${key}`,
          "Content-Type": "application/json",
        },
        timeout: REQUEST_TIMEOUT_MS,
      }
    );
    if (!response.data?.id) {
      throw new Error("Resend response missing an email id");
    }
  } catch (error: any) {
    // Never let the API key leak into a thrown message (axios error
    // messages can include request headers in some failure modes).
    const status = error?.response?.status;
    const detail = error?.response?.data?.message;
    throw new Error(`Resend delivery failed${status ? ` (HTTP ${status})` : ""}${detail ? `: ${detail}` : ""}`);
  }
}
