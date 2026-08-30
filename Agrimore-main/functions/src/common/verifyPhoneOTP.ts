// ============================================================
//  AGRIMORE - VERIFY PHONE OTP CLOUD FUNCTION
//  Mirrors verifyEmailOTP.ts, but for mobile-number login/signup.
// ============================================================
//
// Phase 14, Workstream 1 fix: this endpoint used to compare the submitted
// code against a hardcoded FIXED_OTP ("123456", written by sendPhoneOTP.ts)
// and, on match, mint a real Firebase custom token via
// auth.createCustomToken — creating the Auth user if one didn't already
// exist — with no authentication and no App Check on the request itself.
// Two unauthenticated POSTs from a browser were enough to obtain a valid
// session for ANY phone-registered account, including administrators. This
// is gated behind PHONE_OTP_ENABLED, checked FIRST — before the Firestore
// lookup, the code comparison, any Auth user creation, and the token mint —
// so disabling it costs zero side effects, not just a rejected response
// after the fact.
//
// Phase 16, Workstream 2 fix: PHONE_OTP_ENABLED's MEANING changes — see
// sendPhoneOTP.ts's identical truth table. It now tracks whether a real SMS
// provider (2Factor.in) is actually configured, not a standalone flag that
// could drift out of sync with whether delivery is genuinely possible.

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import * as crypto from "crypto";
import { isSmsProviderConfigured } from "./smsProvider";

// Initialize only if not already initialized
if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();
const auth = admin.auth();

const PHONE_OTP_ENABLED = isSmsProviderConfigured();

function hashOtp(otp: string): string {
  return crypto.createHash("sha256").update(otp).digest("hex");
}

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
// VERIFY PHONE OTP FUNCTION
// ============================================
export const verifyPhoneOTP = functions.https.onRequest(async (req, res) => {
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

  // Fail closed, before ANY Firestore lookup, code comparison, Auth user
  // creation, or token mint — the whole point of this gate is that a
  // disabled flow costs zero side effects, not just a rejected response.
  if (!PHONE_OTP_ENABLED) {
    res.status(503).json({
      success: false,
      error: "Phone login is currently unavailable",
    });
    return;
  }

  try {
    const { phone, otp, name } = req.body;

    if (!phone || typeof phone !== "string") {
      res.status(400).json({ success: false, error: "Phone number is required" });
      return;
    }
    if (!otp || typeof otp !== "string") {
      res.status(400).json({ success: false, error: "OTP is required" });
      return;
    }

    const normalizedPhone = normalizePhone(phone);
    if (!normalizedPhone) {
      res.status(400).json({ success: false, error: "Invalid phone number" });
      return;
    }

    const otpRef = db.collection("phone_otp_codes").doc(normalizedPhone);
    const otpDoc = await otpRef.get();

    if (!otpDoc.exists) {
      res.status(400).json({ success: false, error: "No OTP found. Please request a new code." });
      return;
    }

    const otpData = otpDoc.data()!;

    if (otpData.verified) {
      res.status(400).json({ success: false, error: "OTP already used. Please request a new code." });
      return;
    }

    if (otpData.attempts >= 5) {
      await otpRef.delete();
      res.status(400).json({ success: false, error: "Too many attempts. Please request a new code." });
      return;
    }

    await otpRef.update({ attempts: admin.firestore.FieldValue.increment(1) });

    if (Date.now() > otpData.expiresAt) {
      await otpRef.delete();
      res.status(400).json({ success: false, error: "OTP expired. Please request a new code." });
      return;
    }

    if (otpData.otpHash !== hashOtp(otp)) {
      res.status(400).json({ success: false, error: "Invalid OTP. Please try again." });
      return;
    }

    // OTP is valid
    await otpRef.update({ verified: true, verifiedAt: Date.now() });

    // Find or create the Firebase Auth user for this phone number
    let userId: string;
    let isNewUser = false;

    try {
      const userRecord = await auth.getUserByPhoneNumber(normalizedPhone);
      userId = userRecord.uid;
      console.log(`✅ Existing user found: ${userId}`);
    } catch (error: any) {
      if (error.code === "auth/user-not-found") {
        const newUser = await auth.createUser({
          phoneNumber: normalizedPhone,
          displayName: name || undefined,
        });
        userId = newUser.uid;
        isNewUser = true;
        console.log(`✅ New user created: ${userId}`);

        await db.collection("users").doc(userId).set({
          email: "",
          name: name || "User",
          phone: normalizedPhone,
          role: "user",
          isActive: true,
          phoneVerified: true,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          lastLogin: admin.firestore.FieldValue.serverTimestamp(),
          loginCount: 1,
        });
      } else {
        throw error;
      }
    }

    if (!isNewUser) {
      const updateData: Record<string, unknown> = {
        lastLogin: admin.firestore.FieldValue.serverTimestamp(),
        loginCount: admin.firestore.FieldValue.increment(1),
        phoneVerified: true,
      };
      if (name) updateData.name = name;
      await db.collection("users").doc(userId).update(updateData);
    }

    // Generate custom token for Firebase Auth sign-in on the client
    const customToken = await auth.createCustomToken(userId);

    await otpRef.delete();

    console.log(`✅ Phone ${normalizedPhone} authenticated successfully`);

    res.status(200).json({
      success: true,
      message: "OTP verified successfully",
      token: customToken,
      userId,
      isNewUser,
    });
  } catch (error: any) {
    console.error("❌ Error verifying phone OTP:", error);
    res.status(500).json({
      success: false,
      error: error.message || "Failed to verify OTP",
    });
  }
});
