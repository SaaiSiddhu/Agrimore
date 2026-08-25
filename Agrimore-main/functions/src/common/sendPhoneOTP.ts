// ============================================================
//  AGRIMORE - SEND PHONE OTP CLOUD FUNCTION
//  Mirrors sendEmailOTP.ts, but for mobile-number login/signup.
// ============================================================

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

// Initialize only if not already initialized
if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();
const auth = admin.auth();

const OTP_TTL_MS = 5 * 60 * 1000; // 5 minutes
const RESEND_COOLDOWN_MS = 30 * 1000; // 30 seconds

// No SMS provider is wired up (cost) — every request issues this same fixed
// code as the PRIMARY mechanism. Swap for a real generated + delivered code
// once an SMS provider is budgeted for (see the TODO below).
const FIXED_OTP = "123456";

// ============================================
// NORMALIZE + VALIDATE INDIAN MOBILE NUMBER → +91XXXXXXXXXX
// ============================================
function normalizePhone(raw: string): string | null {
  const digits = raw.replace(/[^\d]/g, "");
  let national: string | null = null;

  if (digits.length === 10 && /^[6-9]/.test(digits)) {
    national = digits;
  } else if (digits.length === 12 && digits.startsWith("91")) {
    national = digits.slice(2);
  } else if (digits.length === 13 && digits.startsWith("091")) {
    national = digits.slice(3);
  }

  if (!national || !/^[6-9]\d{9}$/.test(national)) return null;
  return `+91${national}`;
}

// ============================================
// SEND PHONE OTP FUNCTION
// ============================================
export const sendPhoneOTP = functions.https.onRequest(async (req, res) => {
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
    const { phone } = req.body;

    if (!phone || typeof phone !== "string") {
      res.status(400).json({ success: false, error: "Phone number is required" });
      return;
    }

    const normalizedPhone = normalizePhone(phone);
    if (!normalizedPhone) {
      res.status(400).json({ success: false, error: "Enter a valid 10-digit Indian mobile number" });
      return;
    }

    // Resend cooldown
    const existing = await db.collection("phone_otp_codes").doc(normalizedPhone).get();
    if (existing.exists) {
      const data = existing.data()!;
      const elapsed = Date.now() - (data.createdAt as number);
      if (!data.verified && elapsed < RESEND_COOLDOWN_MS) {
        res.status(429).json({
          success: false,
          error: "Please wait before requesting another code",
          retryAfterMs: RESEND_COOLDOWN_MS - elapsed,
        });
        return;
      }
    }

    // No SMS provider is wired up (cost) — the fixed code is the primary
    // mechanism for now.
    const otp = FIXED_OTP;

    // TODO: once an SMS provider (e.g. MSG91 / Twilio) is budgeted for:
    //   const otp = Math.floor(100000 + Math.random() * 900000).toString();
    //   await smsProvider.send(normalizedPhone, `${otp} is your Agrimore verification code`);

    await db.collection("phone_otp_codes").doc(normalizedPhone).set({
      otp,
      phone: normalizedPhone,
      expiresAt: Date.now() + OTP_TTL_MS,
      createdAt: Date.now(),
      verified: false,
      attempts: 0,
    });

    console.log(`✅ OTP issued for ${normalizedPhone}`);

    // Check if user already exists (so client can tailor copy if needed)
    let userExists = false;
    try {
      await auth.getUserByPhoneNumber(normalizedPhone);
      userExists = true;
    } catch (e: any) {
      if (e.code !== "auth/user-not-found") throw e;
    }

    res.status(200).json({
      success: true,
      message: "OTP sent successfully",
      userExists,
    });
  } catch (error: any) {
    console.error("❌ Error sending phone OTP:", error);
    res.status(500).json({
      success: false,
      error: error.message || "Failed to send OTP",
    });
  }
});
