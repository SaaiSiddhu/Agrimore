// ============================================================
//  AGRIMORE - SEND EMAIL OTP CLOUD FUNCTION
// ============================================================
//
// Phase 15, Workstream 1 fix: mirrors the Phase 14 phone-OTP hardening
// exactly — CSPRNG generation, SHA-256 hashed storage, a resend cooldown,
// and no account-existence signal in the response. Unlike phone OTP, this
// flow genuinely delivers (originally via SMTP, now via Resend — see
// below) and is a working login path, so it is NOT gated behind an
// enabled/disabled env flag the way phone OTP was — gating it off would
// break real logins rather than close a hole with no real delivery
// mechanism.
//
// Phase 16, Workstream 3 fix: transport swapped from nodemailer/Gmail SMTP
// to Resend (see emailProvider.ts) — a pure delivery-channel change. Every
// property from Phase 15 above (generation, hashing, cooldown, cap,
// no-enumeration) is unchanged. As of this phase, this endpoint is wired
// into the marketplace app's profile-completion flow for new users (see
// complete_profile_screen.dart) — no longer unwired as the Phase 15 note
// above described.

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import * as crypto from "crypto";
import { sendEmailViaResend } from "./emailProvider";

// Initialize only if not already initialized
if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();

const RESEND_COOLDOWN_MS = 30 * 1000; // 30 seconds — mirrors sendPhoneOTP.ts

// Per-address daily send cap. Chosen to comfortably cover a real user who
// mistypes their address a few times and needs to resend after each of a
// handful of failed verification attempts, while bounding how many emails a
// single address can be bombarded with per day. This is a per-address limit
// only — it does not stop a distributed attacker enumerating many different
// addresses (that needs App Check, deferred to a future phase).
const MAX_SENDS_PER_DAY = 10;
const DAY_MS = 24 * 60 * 60 * 1000;

// Mirrors sendPhoneOTP.ts's hashOtp() helper exactly — Firestore is
// defence-in-depth here (otp_codes is already `allow read, write: if
// false`), but storing only a hash means a Firestore export/backup leak
// can't reveal a live, usable code.
function hashOtp(otp: string): string {
  return crypto.createHash("sha256").update(otp).digest("hex");
}

// ============================================
// BEAUTIFUL HTML EMAIL TEMPLATE
// ============================================
function generateOTPEmailTemplate(otp: string, email: string): string {
  // Agrimore Theme Colors
  const colors = {
    primary: "#00E676",
    secondary: "#4CAF50",
    background: "#0A120A",
    cardBg: "#0F2818",
    textLight: "#FFFFFF",
    textDim: "#A5D6A7",
    accent: "#81C784"
  };

  return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Your Verification Code - Agrimore</title>
  <style>
    @media only screen and (max-width: 600px) {
      .container { width: 100% !important; padding: 20px !important; }
      .otp-code { font-size: 32px !important; letter-spacing: 8px !important; }
    }
  </style>
</head>
<body style="margin: 0; padding: 0; font-family: 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: ${colors.background}; color: ${colors.textLight};">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
    <tr>
      <td align="center" style="padding: 40px 0;">
        <!-- Main Container -->
        <table class="container" role="presentation" width="480" cellspacing="0" cellpadding="0" border="0" style="background: linear-gradient(145deg, #1A2E1A 0%, #0A120A 100%); border-radius: 24px; border: 1px solid rgba(0, 230, 118, 0.1); box-shadow: 0 20px 40px rgba(0, 0, 0, 0.4); overflow: hidden;">
          
          <!-- Header (Logo) -->
          <tr>
            <td align="center" style="padding: 40px 40px 20px 40px;">
              <div style="display: inline-block; width: 64px; height: 64px; border-radius: 16px; background: linear-gradient(135deg, ${colors.primary} 0%, ${colors.secondary} 100%); line-height: 64px; text-align: center; box-shadow: 0 8px 16px rgba(0, 230, 118, 0.2);">
                <span style="font-size: 32px; font-weight: 800; color: #003300;">A</span>
              </div>
              <h1 style="margin: 16px 0 0 0; font-size: 24px; font-weight: 700; background: linear-gradient(90deg, #FFFFFF 0%, #A5D6A7 100%); -webkit-background-clip: text; -webkit-text-fill-color: transparent; letter-spacing: 1px;">AGRIMORE</h1>
            </td>
          </tr>

          <!-- Content -->
          <tr>
            <td style="padding: 0 40px;">
              <p style="margin: 0 0 24px 0; font-size: 16px; line-height: 1.6; color: rgba(255, 255, 255, 0.9); text-align: center;">
                Hello, use the verification code below to securely access your Agrimore account.
              </p>

              <!-- OTP Box -->
              <div style="background: rgba(0, 230, 118, 0.08); border: 1px dashed rgba(0, 230, 118, 0.3); border-radius: 16px; padding: 32px 20px; text-align: center; margin-bottom: 24px;">
                <span style="display: block; font-size: 12px; font-weight: 600; text-transform: uppercase; color: ${colors.primary}; letter-spacing: 1.5px; margin-bottom: 8px;">Verification Code</span>
                <span class="otp-code" style="display: block; font-size: 40px; font-weight: 800; color: #FFFFFF; font-family: monospace; letter-spacing: 12px;">${otp}</span>
              </div>

              <p style="margin: 0; font-size: 14px; text-align: center; color: ${colors.textDim};">
                ⏱️ This code will expire in 5 minutes.
              </p>
            </td>
          </tr>

          <!-- Security Tip -->
          <tr>
            <td style="padding: 30px 40px;">
              <div style="background: rgba(255, 255, 255, 0.03); border-left: 3px solid ${colors.secondary}; padding: 12px 16px; border-radius: 0 8px 8px 0;">
                <p style="margin: 0; font-size: 13px; color: rgba(255, 255, 255, 0.7); line-height: 1.5;">
                  <strong>Security Notice:</strong> Agrimore will never ask for this code via call or SMS. Do not share it with anyone.
                </p>
              </div>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="padding: 30px 40px; background-color: rgba(0, 0, 0, 0.2); border-top: 1px solid rgba(255, 255, 255, 0.05); text-align: center;">
              <p style="margin: 0 0 8px 0; font-size: 12px; color: ${colors.textDim};">
                Sent to <span style="color: ${colors.primary};">${email}</span>
              </p>
              <p style="margin: 0; font-size: 11px; color: rgba(255, 255, 255, 0.4);">
                &copy; ${new Date().getFullYear()} Agrimore Marketplace. All rights reserved.
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
  `;
}

// ============================================
// GENERATE 6-DIGIT OTP
// ============================================
// CSPRNG — Math.random() is not appropriate for an authentication
// credential (V8's PRNG is seeded per-isolate and its output stream is, in
// principle, inferable from observed values). Mirrors
// sendPhoneOTP.ts/createOrder.ts's generateVerificationCode() exactly.
function generateOTP(): string {
  return crypto.randomInt(100000, 1000000).toString();
}

// ============================================
// SEND EMAIL OTP FUNCTION
// ============================================
export const sendEmailOTP = functions.https.onRequest(async (req, res) => {
  // CORS headers
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  if (req.method !== "POST") {
    res.status(405).json({ success: false, error: "Method not allowed" });
    return;
  }

  try {
    const { email } = req.body;

    // Validate email
    if (!email || typeof email !== "string") {
      res.status(400).json({ success: false, error: "Email is required" });
      return;
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      res.status(400).json({ success: false, error: "Invalid email format" });
      return;
    }

    // Resend cooldown + daily send cap, both read off the existing
    // otp_codes/{email} document — mirrors sendPhoneOTP.ts's cooldown
    // check, extended with a rolling daily counter.
    const existingRef = db.collection("otp_codes").doc(email);
    const existing = await existingRef.get();
    const now = Date.now();
    let sendCount = 0;
    let windowStart = now;
    if (existing.exists) {
      const data = existing.data()!;
      const elapsed = now - (data.createdAt as number);
      if (!data.verified && elapsed < RESEND_COOLDOWN_MS) {
        res.status(429).json({
          success: false,
          error: "Please wait before requesting another code",
          retryAfterMs: RESEND_COOLDOWN_MS - elapsed,
        });
        return;
      }
      const existingWindowStart = typeof data.sendWindowStart === "number" ? data.sendWindowStart : now;
      if (now - existingWindowStart < DAY_MS) {
        windowStart = existingWindowStart;
        sendCount = typeof data.sendCount === "number" ? data.sendCount : 0;
      }
      if (sendCount >= MAX_SENDS_PER_DAY) {
        res.status(429).json({
          success: false,
          error: "Too many code requests for this address today. Please try again later.",
          retryAfterMs: windowStart + DAY_MS - now,
        });
        return;
      }
    }

    // Generate OTP
    const otp = generateOTP();
    const expiresAt = now + 5 * 60 * 1000; // 5 minutes

    // Store OTP in Firestore — only the hash, never the plaintext code.
    await existingRef.set({
      otpHash: hashOtp(otp),
      email: email,
      expiresAt: expiresAt,
      createdAt: now,
      verified: false,
      attempts: 0,
      sendWindowStart: windowStart,
      sendCount: sendCount + 1,
    });

    // Send email via Resend (Phase 16, Workstream 3 — see emailProvider.ts).
    const emailHtml = generateOTPEmailTemplate(otp, email);

    try {
      await sendEmailViaResend({
        to: email,
        subject: `${otp} is your Agrimore verification code`,
        html: emailHtml,
      });
    } catch (deliveryError: any) {
      console.error("❌ Resend delivery failed:", deliveryError?.message || deliveryError);
      // Delivery failed — don't leave a usable, brute-forceable OTP behind.
      await existingRef.delete();
      res.status(502).json({
        success: false,
        error: "Could not deliver the verification code. Please try again shortly.",
      });
      return;
    }

    console.log(`✅ OTP sent to ${email}`);

    // Phase 15, Workstream 1 fix: no account-existence signal in the
    // response. The prior `userExists` field let an unauthenticated caller
    // enumerate whether any given email has an Agrimore account — grepped
    // apps/ and packages/ for any Dart consumer of this field on the email
    // path and found none (see this file's header comment), so removing it
    // outright requires no client-side change.
    res.status(200).json({
      success: true,
      message: "OTP sent successfully",
    });

  } catch (error: any) {
    console.error("❌ Error sending OTP:", error);
    res.status(500).json({
      success: false,
      error: error.message || "Failed to send OTP",
    });
  }
});
