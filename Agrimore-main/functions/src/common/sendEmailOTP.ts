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
// PLAIN-TEXT EMAIL BODY
// ============================================
// Owner decision, 2026-08-30: the verification email is PLAIN TEXT ONLY — no
// colours, no theme, no HTML. This replaced a themed HTML template.
//
// Beyond the owner's preference, plain text is the better default for a
// one-time code: there is nothing for a mail client to block, strip, or
// render badly, and no image or CSS can hide the code from a screen reader.
// sendEmailViaResend is passed `text` (not `html`) below, so this really is
// sent as text/plain rather than HTML that merely looks plain.
//
// Keep it short. Every extra line is another thing that can wrap badly in a
// narrow mobile mail client and push the code out of the preview pane.
function generateOTPEmailBody(otp: string): string {
  return [
    `Your Agrimore verification code is ${otp}`,
    "",
    "This code expires in 5 minutes.",
    "",
    "Do not share it with anyone. Agrimore will never ask you for it.",
    "",
    "If you did not request this code, you can ignore this email.",
  ].join("\n");
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
// Phase 18, Workstream 2: needs RESEND_API_KEY (delivery, via
// emailProvider.ts's sendEmailViaResend, called below). RESEND_FROM_EMAIL
// is deliberately NOT bound here — see emailProvider.ts's Workstream 3
// comment for why it's ordinary config, not a secret.
export const sendEmailOTP = functions
  .runWith({ secrets: ["RESEND_API_KEY"] })
  .https.onRequest(async (req, res) => {
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
    const emailText = generateOTPEmailBody(otp);

    try {
      await sendEmailViaResend({
        to: email,
        subject: `${otp} is your Agrimore verification code`,
        // `text`, not `html` — see generateOTPEmailBody above.
        text: emailText,
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
