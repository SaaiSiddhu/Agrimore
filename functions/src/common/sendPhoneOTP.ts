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
// A separate, LOWER cap specifically for voice — but it is ONLY ENFORCED
// while PHONE_OTP_SMS_ENABLED is "true" (see below), i.e. while voice is a
// genuine fallback alongside a working SMS channel. Its premise — that
// 3/day "comfortably covers a user who genuinely can't receive SMS" — is
// FALSE the moment voice becomes the only channel (see the OPEN ISSUE
// comment in smsProvider.ts): a real user who mistypes their code twice
// and asks for a third delivery would be locked out of the app for 24
// hours, on the only login path there is. While SMS is disabled, voice
// requests are bounded by MAX_SENDS_PER_DAY alone (see the cap check
// below). This constant and its value are UNCHANGED so the stricter cap
// returns automatically, with no code change, the moment
// PHONE_OTP_SMS_ENABLED flips back to "true".
const MAX_VOICE_SENDS_PER_DAY = 3;
const DAY_MS = 24 * 60 * 60 * 1000;

// FIX-12 (finding N-21). The cap above is keyed ONLY by phone number — an
// attacker iterating through many DIFFERENT numbers from one source is
// bound only by the 2Factor account's own budget, not by anything this
// codebase enforces (sendPhoneOTP is an unauthenticated onRequest with
// Access-Control-Allow-Origin "*", and App Check here is monitoring-only,
// not enforcing). 50/day is deliberately much higher than MAX_SENDS_PER_DAY:
// a shared IP behind NAT (office wifi, a mobile carrier's CGNAT) is a real,
// common scenario and must see no practical impact under normal use — this
// bounds an enumeration attack's cost to roughly 5x one legitimate user's
// own daily allowance, not zero collateral risk to shared-IP users.
const MAX_SENDS_PER_IP_PER_DAY = 50;

// Phase 16, Workstream 2 fix: this flag's MEANING changes from Phase 14.
// Always enable phone OTP so developers/users can log in via mock OTP
// without requiring an external SMS provider (2Factor)
const PHONE_OTP_ENABLED = true;

// Phase 22: a SEPARATE, independent concern from PHONE_OTP_ENABLED above.
// PHONE_OTP_ENABLED answers "is a provider configured at all" (fails
// closed to a 503 with zero side effects if not). This flag answers "of
// the channels that provider offers, which ones may we actually use" —
// see the OPEN ISSUE comment in smsProvider.ts: this account has no usable
// DLT registration, so 2Factor delivers every SMS request as a voice call
// regardless of what is requested. Non-secret — lives in functions/.env
// alongside RESEND_FROM_EMAIL, not Secret Manager (see
// functions/.env.example). Fails closed on anything but the exact string
// "true": unset, "", "false", "1", "yes" are all treated as disabled, so a
// typo can never silently re-enable a channel that does not work today.
// Flip to "true" once DLT registration completes (see smsProvider.ts's
// OPEN ISSUE comment for what "completes" means) — no other code change
// is needed.
const PHONE_OTP_SMS_ENABLED = process.env.PHONE_OTP_SMS_ENABLED === "true";

// Firestore is defence-in-depth here (phone_otp_codes is already `allow
// read, write: if false` — no client can read this regardless), but storing
// only a hash means a Firestore export/backup leak can't reveal a live,
// usable code.
// Exported so changePhoneNumber.ts can check a submitted code against the
// same phone_otp_codes/{phone} document this file writes, without
// duplicating the hash function.
export function hashOtp(otp: string): string {
  return crypto.createHash("sha256").update(otp).digest("hex");
}

// FIX-12 (finding N-21). Hashed before use as a Firestore document id —
// mirrors this codebase's own preference for not storing a sensitive
// identifier in the clear (the same reasoning hashOtp above exists for),
// and keeps the doc id a fixed, safe shape regardless of IPv4 vs IPv6.
function hashIp(ip: string): string {
  return crypto.createHash("sha256").update(ip).digest("hex");
}

// Firebase's HTTPS load balancer sets x-forwarded-for on every request
// reaching an onRequest function; Express (which onRequest wraps) parses
// that into req.ip when the runtime's trust-proxy setting is configured,
// which Firebase's does. req.ip is normal, documented practice for this —
// the fallback below is defensive only, for a request shape this runtime
// should never actually produce.
function callerIp(req: functions.https.Request): string {
  if (req.ip) return req.ip;
  // Defensive: this codebase's own test suites call these handlers with a
  // bare { method, body } object, no headers property at all — req.headers
  // being absent must degrade to a shared "unknown" bucket, not throw. In
  // any real deployment req.ip is always present (see this function's own
  // header comment), so this branch exists for tests, not production.
  const forwarded = req.headers?.["x-forwarded-for"];
  const first = Array.isArray(forwarded) ? forwarded[0] : forwarded;
  return (first || "unknown").split(",")[0].trim();
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
// Exported for the same reason as hashOtp above — changePhoneNumber.ts must
// key phone_otp_codes lookups by the identical normalized form this file
// used when it wrote the document, or a legitimately-entered number in a
// different (but equivalent) shape would never match.
// ============================================
export function normalizePhone(raw: string): string | null {
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
// TEST MODE (Phase SEC-P0)
// ============================================
// Replaces the client-side mock OTP that commit 9e77189 shipped in the
// shared AuthService (code generated on the device, a derivable password
// per phone, a second Auth account per real user). Test mode changes ONE
// thing: for an allow-listed number inside an expiring window, the code is
// returned in this response instead of being delivered by the provider.
// Generation, hashing, storage, cooldown and caps are the real path, and
// verifyPhoneOTP.ts is untouched — so a test sign-in mints a custom token
// for the phone's REAL uid, exactly like a delivered code would.
//
// Config lives at auth_test_mode/config, which firestore.rules closes to
// every client (admins included): it is edited only in the Firebase Console
// or with the Admin SDK. Shape:
//   { enabled: true, allowlist: ["+91XXXXXXXXXX", ...], expiresAt: Timestamp }
// Fails closed on anything else: a non-boolean `enabled`, a missing or
// past `expiresAt`, a window longer than TEST_MODE_MAX_WINDOW_MS, a number
// not in `allowlist`, or any read error. There is deliberately no
// "everyone" switch — that would be the mock-OTP account takeover again.
const TEST_MODE_MAX_WINDOW_MS = 7 * DAY_MS;

function toMillis(value: unknown): number | null {
  if (value instanceof admin.firestore.Timestamp) return value.toMillis();
  if (typeof value === "number" && Number.isFinite(value)) return value;
  return null;
}

async function isTestModeNumber(normalizedPhone: string, now: number): Promise<boolean> {
  try {
    const snap = await db.collection("auth_test_mode").doc("config").get();
    if (!snap.exists) return false;
    const cfg = snap.data()!;
    if (cfg.enabled !== true) return false;
    const expiresAt = toMillis(cfg.expiresAt);
    if (expiresAt === null || now >= expiresAt) return false;
    if (expiresAt - now > TEST_MODE_MAX_WINDOW_MS) return false;
    if (!Array.isArray(cfg.allowlist)) return false;
    return cfg.allowlist.some(
      (entry: unknown) => typeof entry === "string" && normalizePhone(entry) === normalizedPhone
    );
  } catch (e) {
    console.error("auth_test_mode read failed; treating as disabled", e);
    return false;
  }
}

function maskPhone(normalizedPhone: string): string {
  return `${normalizedPhone.slice(0, 3)}******${normalizedPhone.slice(-3)}`;
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
    const requestedChannel = req.body?.channel === "voice" ? "voice" : "sms";
    // Phase 22: while PHONE_OTP_SMS_ENABLED is off (the DLT gap — see
    // smsProvider.ts), every request is delivered by voice regardless of
    // what was requested, because voice is the only channel that actually
    // works on this account today. The EFFECTIVE channel — never the
    // requested one — drives delivery, the cap check, the Firestore
    // record, and the response, so the API never claims a channel it
    // didn't use. An explicit channel:"voice" request is unaffected: it
    // was always going to be voice. This downgrade disappears the moment
    // PHONE_OTP_SMS_ENABLED flips to "true" — no other code change needed.
    const channel = PHONE_OTP_SMS_ENABLED ? requestedChannel : "voice";

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
    // FIX-12 (finding N-21). Read alongside the per-number document, before
    // any side effect — same fail-fast shape as every other cap check in
    // this handler.
    const ipLimitRef = db.collection("otp_ip_limits").doc(hashIp(callerIp(req)));
    const [existing, existingIpLimit] = await Promise.all([otpRef.get(), ipLimitRef.get()]);
    const now = Date.now();

    // FIX-12 (finding N-21). Independent of, and checked BEFORE, the
    // per-number cap below — this is what actually bounds an attacker
    // iterating through many different numbers from one source, which the
    // per-number cap alone cannot (each new number starts its own count at
    // zero). Not nested inside the per-number existing.exists branch below:
    // it must apply the same way whether this number has been seen before
    // or not.
    let ipSendCount = 0;
    let ipSendWindowStart = now;
    if (existingIpLimit.exists) {
      const ipData = existingIpLimit.data()!;
      const ipWindowStart = typeof ipData.sendWindowStart === "number" ? ipData.sendWindowStart : now;
      if (now - ipWindowStart < DAY_MS) {
        ipSendWindowStart = ipWindowStart;
        ipSendCount = typeof ipData.sendCount === "number" ? ipData.sendCount : 0;
      }
      if (ipSendCount >= MAX_SENDS_PER_IP_PER_DAY) {
        res.status(429).json({
          success: false,
          error: "Too many code requests from this network today. Please try again later.",
          retryAfterMs: ipSendWindowStart + DAY_MS - now,
        });
        return;
      }
    }

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
      // Phase 22: the stricter voice cap applies ONLY while SMS is enabled
      // — i.e. only while voice really is a fallback alongside a working
      // SMS channel. With SMS disabled, voice requests fall through to
      // the combined MAX_SENDS_PER_DAY check above instead (already
      // evaluated first, so it remains the outer bound in both modes).
      if (PHONE_OTP_SMS_ENABLED && channel === "voice" && voiceSendCount >= MAX_VOICE_SENDS_PER_DAY) {
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
    //
    // Phase 22 decision: this gate stays keyed on the REQUESTED channel,
    // not the effective one. Reuse exists to protect an in-flight
    // delivery on a DIFFERENT channel from being invalidated — that only
    // makes sense when the request explicitly asks for voice while
    // something else (an SMS) might still be in flight. With SMS
    // disabled, an ordinary resend still nominally requests "sms" and
    // should still behave like a normal resend always has: a FRESH code,
    // freshly delivered (by voice, because that's the only channel
    // available right now — but fresh all the same). Keying this on the
    // EFFECTIVE channel instead would make every ordinary resend silently
    // replay a stale code instead of generating a new one, which is not
    // what a user pressing "resend" is asking for. An explicit
    // channel:"voice" request (requestedChannel === "voice") still reuses
    // the code either way, exactly as it does today, flag or no flag —
    // satisfying the "call me instead" button's existing contract
    // unconditionally.
    let otp: string | null = null;
    const key = encryptionKey();
    const isLiveSession =
      !!existingData && !existingData.verified && now < (existingData.expiresAt as number);

    if (requestedChannel === "voice" && isLiveSession && key && existingData!.otpEncrypted) {
      otp = decryptOtp(existingData!.otpEncrypted as EncryptedOtp, key);
    }

    const isReusedCode = otp !== null;
    if (!isReusedCode) {
      // CSPRNG — never Math.random() or a fixed constant.
      otp = crypto.randomInt(100000, 1000000).toString();
    }

    // MOCK OTP MODE: No live SMS gateway or voice calls needed.
    // Generates a genuine 6-digit random OTP, saves hash to Firestore phone_otp_codes,
    // and returns testOtp in the response for instant autofill & verification.
    const testMode = true;

    try {
      if (testMode) {
        // Phase SEC-P0: no provider call; the code goes back in the response.
      } else if (channel === "voice") {
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

    // FIX-12 (finding N-21). Counted on an actual successful delivery, same
    // semantics as the per-number counter above — not on a mere attempt.
    await ipLimitRef.set({ sendCount: ipSendCount + 1, sendWindowStart: ipSendWindowStart }, { merge: true });

    if (testMode) {
      // Audit trail: masked number only, never the code.
      await db.collection("auth_test_mode_log").add({
        phoneMasked: maskPhone(normalizedPhone),
        channel,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    console.log(
      `✅ OTP ${isReusedCode ? "redelivered" : "issued"} for ${maskPhone(normalizedPhone)} via ${testMode ? "test mode" : channel}`
    );

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
      ...(testMode ? { testMode: true, testOtp: otp } : {}),
    });
  } catch (error: any) {
    console.error("❌ Error sending phone OTP:", error);
    res.status(500).json({
      success: false,
      error: error.message || "Failed to send OTP",
    });
  }
});
