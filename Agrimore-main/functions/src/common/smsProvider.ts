// ============================================================
//  Phase 16, Workstream 2 — 2Factor.in SMS / voice OTP delivery
// ============================================================
//
// This module is a pure DELIVERY channel. Agrimore generates the OTP itself
// (crypto.randomInt, in sendPhoneOTP.ts) and stores only its SHA-256 hash —
// 2Factor never learns anything Agrimore doesn't already control, and never
// participates in verification. This is 2Factor's "custom OTP" mode
// (`https://2factor.in/API/V1/{api_key}/SMS|VOICE/{phone}/{otp}`), NOT their
// AUTOGEN/session-id mode — deliberately, so a provider outage or a
// compromised 2Factor account can never mint a valid session on its own.
//
// Verified against https://2factor.in/API/DOCS/SMS_OTP.html (2026-08-30):
// custom-OTP SMS is a POST to that exact URL shape. The voice endpoint
// mirrors it (`.../VOICE/{phone}/{otp}`) per 2Factor's voice API docs. Both
// endpoints share 2Factor's standard `{ Status, Details }` response
// envelope — `Status !== "Success"` is treated as a delivery failure.
//
// NEVER log the OTP value or the API key, at any log level, in any branch.

import axios from "axios";

const TWOFACTOR_BASE_URL = "https://2factor.in/API/V1";
// 2Factor's HTTP API has no documented SLA; without a timeout, a stalled
// provider call would leave the caller (and its Firestore write below it)
// hanging indefinitely.
const REQUEST_TIMEOUT_MS = 10_000;

function apiKey(): string | null {
  const key = process.env.TWOFACTOR_API_KEY;
  return key && key.trim() ? key.trim() : null;
}

// The sendPhoneOTP.ts / verifyPhoneOTP.ts gate reads this to decide whether
// phone OTP is enabled at all — see those files' PHONE_OTP_ENABLED logic.
export function isSmsProviderConfigured(): boolean {
  return apiKey() !== null;
}

interface TwoFactorResponse {
  Status?: string;
  Details?: string;
}

// normalizedPhone arrives already validated/normalized to +91XXXXXXXXXX by
// the caller (sendPhoneOTP.ts's normalizePhone()) — 2Factor's URL scheme
// expects the country code without the leading '+'.
function toTwoFactorPhone(normalizedPhone: string): string {
  return normalizedPhone.replace(/^\+/, "");
}

async function call2Factor(pathSuffix: string): Promise<void> {
  const key = apiKey();
  if (!key) {
    // Callers must check isSmsProviderConfigured() before reaching here —
    // this is a defensive fallback, not the primary gate.
    throw new Error("SMS provider not configured");
  }

  const url = `${TWOFACTOR_BASE_URL}/${key}/${pathSuffix}`;

  let response;
  try {
    response = await axios.post<TwoFactorResponse>(url, undefined, {
      timeout: REQUEST_TIMEOUT_MS,
    });
  } catch (error: any) {
    // Never include the request URL (it contains the API key) in a thrown
    // error message that might reach a log or an HTTP response.
    const status = error?.response?.status;
    throw new Error(`2Factor request failed${status ? ` (HTTP ${status})` : ""}`);
  }

  if (response.data?.Status !== "Success") {
    throw new Error(`2Factor delivery failed: ${response.data?.Details || "unknown error"}`);
  }
}

/** Sends `otp` to `normalizedPhone` via SMS. Throws on any delivery failure. */
export async function sendSmsOtp(normalizedPhone: string, otp: string): Promise<void> {
  const phone = toTwoFactorPhone(normalizedPhone);
  await call2Factor(`SMS/${phone}/${otp}`);
}

/** Calls `normalizedPhone` and reads `otp` aloud via 2Factor's voice API. Throws on failure. */
export async function sendVoiceOtp(normalizedPhone: string, otp: string): Promise<void> {
  const phone = toTwoFactorPhone(normalizedPhone);
  await call2Factor(`VOICE/${phone}/${otp}`);
}
