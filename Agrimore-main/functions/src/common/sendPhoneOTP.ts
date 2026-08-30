// ============================================================
//  AGRIMORE - SEND PHONE OTP CLOUD FUNCTION
//  Mirrors sendEmailOTP.ts, but for mobile-number login/signup.
// ============================================================
//
// Phase 14, Workstream 1 fix: this endpoint used to write a hardcoded
// FIXED_OTP = "123456" as the genuine code for every phone number, with no
// authentication and no App Check — anyone could obtain a valid session for
// ANY phone-registered account (including admins) with two unauthenticated
// POSTs. No SMS provider was budgeted to actually deliver a real code, so
// this endpoint (and verifyPhoneOTP.ts) was fail-closed behind an explicit
// PHONE_OTP_ENABLED env flag until one was wired up.
//
// Phase 16, Workstream 2 fix: a real provider (2Factor.in, see
// smsProvider.ts) is now wired up as the delivery channel. The fail-closed
// gate's MEANING changes here — see PHONE_OTP_ENABLED below — but every
// other Phase 14 security property is unchanged: CSPRNG generation,
// SHA-256-hashed storage, the resend cooldown, normalizePhone() validation.

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import * as crypto from "crypto";
import { isSmsProviderConfigured, sendSmsOtp, sendVoiceOtp } from "./smsProvider";

// Initialize only if not already initialized
if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();
const auth = admin.auth();

const OTP_TTL_MS = 5 * 60 * 1000; // 5 minutes
const RESEND_COOLDOWN_MS = 30 * 1000; // 30 seconds

// Per-number daily send cap, covering both channels combined — mirrors
// sendEmailOTP.ts's MAX_SENDS_PER_DAY (10) exactly, same reasoning: covers a
// real user who mistypes/needs several resends, bounds how many messages one
// number can be bombarded with per day. Per-number only, not per-IP — a
// distributed enumerator needs App Check, deferred.
const MAX_SENDS_PER_DAY = 10;
// A separate, LOWER cap specifically for voice — voice minutes cost 2Factor
// meaningfully more than an SMS segment, and a voice call is more disruptive
// to bombard a real phone with (it rings) — 3/day comfortably covers a user
// who genuinely can't receive SMS (e.g. temporarily out of signal-but-not-
// call-range) without opening a cheap abuse vector on the pricier channel.
const MAX_VOICE_SENDS_PER_DAY = 3;
const DAY_MS = 24 * 60 * 60 * 1000;

// Phase 16, Workstream 2 fix: this flag's MEANING changes from Phase 14.
// Truth table:
//   TWOFACTOR_API_KEY present     -> phone OTP ENABLED (real delivery)
//   TWOFACTOR_API_KEY absent      -> phone OTP DISABLED, 503, zero side effects
// The system must never again be in a state where it accepts OTP requests
// it cannot actually deliver — so "enabled" is now derived from whether a
// real provider is configured, not a separate boolean flag that could drift
// out of sync with reality.
const PHONE_OTP_ENABLED = isSmsProviderConfigured();

// Firestore is defence-in-depth here (phone_otp_codes is already `allow
// read, write: if false` — no client can read this regardless), but storing
// only a hash means a Firestore export/backup leak can't reveal a live,
// usable code.
function hashOtp(otp: string): string {
  return crypto.createHash("sha256").update(otp).digest("hex");
}

// ============================================
// OPTIONAL REVERSIBLE ENCRYPTION — for same-code voice redelivery ONLY.
// ============================================
// The correctness trap this exists for: a voice request for a number with a
// live, unexpired SMS OTP must redeliver the SAME code — otherwise the SMS
// already in flight to the user silently stops working. Hash-only storage
// (the verification mechanism) can't support that, since a hash can't be
// reversed. AES-256-GCM storage of the plaintext, alongside the hash, lets
// this endpoint recover the exact code for a live session without ever
// returning it to any client or logging it. The key lives only in Cloud
// Functions environment config, never in client source.
//
// This is an OPTIONAL enhancement, independent of PHONE_OTP_ENABLED: if
// OTP_ENCRYPTION_KEY isn't set, voice-reuse degrades to generating a fresh
// code (see the channel handling below) — a real UX degradation (the
// earlier SMS code stops working) but not a security regression, so it does
// not gate the phone-OTP-enabled flag itself.
function encryptionKey(): Buffer | null {
  const raw = process.env.OTP_ENCRYPTION_KEY;
  if (!raw || !raw.trim()) return null;
  return crypto.createHash("sha256").update(raw).digest();
}

interface EncryptedOtp {
  iv: string;
  ciphertext: string;
  authTag: string;
}

function encryptOtp(otp: string, key: Buffer): EncryptedOtp {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv("aes-256-gcm", key, iv);
  const ciphertext = Buffer.concat([cipher.update(otp, "utf8"), cipher.final()]);
  return {
    iv: iv.toString("hex"),
    ciphertext: ciphertext.toString("hex"),
    authTag: cipher.getAuthTag().toString("hex"),
  };
}

function decryptOtp(enc: EncryptedOtp, key: Buffer): string | null {
  try {
    const decipher = crypto.createDecipheriv("aes-256-gcm", key, Buffer.from(enc.iv, "hex"));
    decipher.setAuthTag(Buffer.from(enc.authTag, "hex"));
    const plain = Buffer.concat([
      decipher.update(Buffer.from(enc.ciphertext, "hex")),
      decipher.final(),
    ]);
    return plain.toString("utf8");
  } catch {
    // Tampered/undecryptable ciphertext (e.g. key rotated) — fall back to
    // generating a fresh code rather than throwing.
    return null;
  }
}

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
// Phase 18, Workstream 2: v1 secret binding uses secret NAMES (strings),
// not defineSecret() objects — do not mix the two API styles. Needs both
// TWOFACTOR_API_KEY (delivery, via smsProvider.ts) and OTP_ENCRYPTION_KEY
// (voice-reuse redelivery, read directly in this file). Read sites
// unchanged — both still resolve via plain process.env.X.
export const sendPhoneOTP = functions
  .runWith({ secrets: ["TWOFACTOR_API_KEY", "OTP_ENCRYPTION_KEY"] })
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

  // Fail closed, before any lookup or side effect: no SMS provider is
  // configured, so this flow must not issue anything a client could treat
  // as usable.
  if (!PHONE_OTP_ENABLED) {
    res.status(503).json({
      success: false,
      error: "Phone login is currently unavailable",
    });
    return;
  }

  try {
    const { phone } = req.body;
    const channel = req.body?.channel === "voice" ? "voice" : "sms";

    if (!phone || typeof phone !== "string") {
      res.status(400).json({ success: false, error: "Phone number is required" });
      return;
    }

    const normalizedPhone = normalizePhone(phone);
    if (!normalizedPhone) {
      res.status(400).json({ success: false, error: "Enter a valid 10-digit Indian mobile number" });
      return;
    }

    const otpRef = db.collection("phone_otp_codes").doc(normalizedPhone);
    const existing = await otpRef.get();
    const now = Date.now();

    let sendCount = 0;
    let sendWindowStart = now;
    let voiceSendCount = 0;
    let voiceSendWindowStart = now;
    let existingData: FirebaseFirestore.DocumentData | undefined;

    if (existing.exists) {
      existingData = existing.data();
      const elapsed = now - (existingData!.createdAt as number);
      if (!existingData!.verified && elapsed < RESEND_COOLDOWN_MS) {
        res.status(429).json({
          success: false,
          error: "Please wait before requesting another code",
          retryAfterMs: RESEND_COOLDOWN_MS - elapsed,
        });
        return;
      }

      const windowStart = typeof existingData!.sendWindowStart === "number" ? existingData!.sendWindowStart : now;
      if (now - windowStart < DAY_MS) {
        sendWindowStart = windowStart;
        sendCount = typeof existingData!.sendCount === "number" ? existingData!.sendCount : 0;
      }
      if (sendCount >= MAX_SENDS_PER_DAY) {
        res.status(429).json({
          success: false,
          error: "Too many code requests for this number today. Please try again later.",
          retryAfterMs: sendWindowStart + DAY_MS - now,
        });
        return;
      }

      const voiceWindowStart =
        typeof existingData!.voiceSendWindowStart === "number" ? existingData!.voiceSendWindowStart : now;
      if (now - voiceWindowStart < DAY_MS) {
        voiceSendWindowStart = voiceWindowStart;
        voiceSendCount = typeof existingData!.voiceSendCount === "number" ? existingData!.voiceSendCount : 0;
      }
      if (channel === "voice" && voiceSendCount >= MAX_VOICE_SENDS_PER_DAY) {
        res.status(429).json({
          success: false,
          error: "Too many voice call requests for this number today. Please try again later.",
          retryAfterMs: voiceSendWindowStart + DAY_MS - now,
        });
        return;
      }
    }

    // Voice-reuse: a live (exists, unexpired, unverified) session must be
    // redelivered with the SAME code on a voice request — generating a new
    // one here would silently invalidate the SMS already in flight to the
    // user. Only possible when OTP_ENCRYPTION_KEY is configured and the
    // stored ciphertext still decrypts; otherwise falls through to
    // generating fresh (a UX degradation, not a security issue — see the
    // encryptionKey() comment above).
    let otp: string | null = null;
    const key = encryptionKey();
    const isLiveSession =
      !!existingData && !existingData.verified && now < (existingData.expiresAt as number);

    if (channel === "voice" && isLiveSession && key && existingData!.otpEncrypted) {
      otp = decryptOtp(existingData!.otpEncrypted as EncryptedOtp, key);
    }

    const isReusedCode = otp !== null;
    if (!isReusedCode) {
      // CSPRNG — never Math.random() or a fixed constant.
      otp = crypto.randomInt(100000, 1000000).toString();
    }

    try {
      if (channel === "voice") {
        await sendVoiceOtp(normalizedPhone, otp!);
      } else {
        await sendSmsOtp(normalizedPhone, otp!);
      }
    } catch (deliveryError: any) {
      // Provider failure: must not leave a usable/brute-forceable OTP
      // document behind. If we were about to generate a fresh code, don't
      // write it at all. If we were reusing an existing live session's
      // code, leave that existing document exactly as it was (it was
      // already valid and delivered via the other channel) — do not delete
      // a still-good session just because this delivery attempt failed.
      await db.collection("otp_delivery_failures").add({
        phone: normalizedPhone,
        channel,
        error: deliveryError?.message || "unknown error",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      res.status(502).json({
        success: false,
        error: "Could not deliver the verification code. Please try again shortly.",
      });
      return;
    }

    if (!isReusedCode) {
      await otpRef.set({
        otpHash: hashOtp(otp!),
        otpEncrypted: key ? encryptOtp(otp!, key) : null,
        phone: normalizedPhone,
        expiresAt: now + OTP_TTL_MS,
        createdAt: now,
        verified: false,
        attempts: 0,
        channel,
        sendCount: sendCount + 1,
        sendWindowStart,
        voiceSendCount: channel === "voice" ? voiceSendCount + 1 : voiceSendCount,
        voiceSendWindowStart,
      });
    } else {
      // Reused an existing live code — only advance the counters/cooldown
      // clock, never touch otpHash/otpEncrypted/expiresAt (the code and its
      // expiry are unchanged; redelivering it must not extend its life).
      await otpRef.update({
        createdAt: now, // resets the resend cooldown, not the OTP's own expiresAt
        channel,
        sendCount: sendCount + 1,
        sendWindowStart,
        voiceSendCount: voiceSendCount + 1,
        voiceSendWindowStart,
      });
    }

    console.log(`✅ OTP ${isReusedCode ? "redelivered" : "issued"} for ${normalizedPhone} via ${channel}`);

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
      channel,
    });
  } catch (error: any) {
    console.error("❌ Error sending phone OTP:", error);
    res.status(500).json({
      success: false,
      error: error.message || "Failed to send OTP",
    });
  }
});
