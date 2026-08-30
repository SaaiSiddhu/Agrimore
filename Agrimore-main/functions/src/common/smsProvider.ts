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

// OPEN ISSUE, 2026-08-30: an explicit channel:"sms" request delivers a VOICE
// CALL. Established so far, so nobody re-treads it:
//
//  - Not a defect on this side. sendPhoneOTP resolves channel to "sms", calls
//    sendSmsOtp, which POSTs the URL below; 2Factor returns Status:"Success".
//    A failed SMS never silently becomes a voice call — it throws, 502s, and
//    writes to otp_delivery_failures. (Precision, because an earlier draft of
//    this comment said "no voice fallback anywhere", which misreads as "no
//    voice code exists": there IS a deliberate voice channel — sendPhoneOTP.ts
//    dispatches sms/voice in a clean if/else, voice has its own daily cap and
//    encrypted-code-reuse path, and otp_verification_screen.dart has a real
//    "call me instead" button. Legitimate voice traffic is therefore expected
//    and is NOT evidence of this bug.)
//  - The account HAS an approved DLT template: "Agrimore2026", sender AGRIMO,
//    body "XXXX is your OTP for AGRIMORE. Please do not share OTP with
//    anyone.", approved 2026-06-12. So plain "no template" is NOT the cause.
//  - Naming that template does NOT help, and must not be re-attempted here:
//    2Factor's docs for the custom-OTP form (the one we use, where WE supply
//    the code) define exactly one shape —
//    POST https://2factor.in/API/V1/{key}/SMS/{phone}/{otp} — with NO template
//    parameter. template_name is documented only for the AUTOGEN form
//    (/AUTOGEN/{template_name}) and for the newer JSON endpoint
//    POST /API/V1/OTP/SEND with an X-API-Key header and a
//    {to, template_name, var1} body. Appending it to the custom-OTP path was
//    tried on 2026-08-30, changed nothing, and was reverted.
//
//  - OTP LENGTH IS NOT THE CAUSE. The approved template's variable renders as
//    four characters ("XXXX") while this code sends six digits, which looked
//    like a DLT content-match failure. DISPROVEN 2026-08-30: direct curls to
//    the URL below with BOTH a 4-digit and a 6-digit code, bypassing this
//    codebase entirely, each arrived as a voice call.
//    ⛔ DO NOT shorten the OTP to 4 digits. It would not fix this, and it
//    would cut brute-force space 10^6 -> 10^4 on the only login path.
//  - SMS CREDITS ARE NOT EXHAUSTED. GET /API/V1/{key}/BAL/SMS returns 166
//    (voice 50, transactional SMS 200, promotional 0). SMS credit sits unused
//    while voice credit is consumed — 2Factor is choosing voice while it has
//    SMS credit available. (BAL/ALL is not a valid service name.)
//  - The newer JSON endpoint POST /API/V1/OTP/SEND (X-API-Key header,
//    {to, template_name, var1} body) 404s — it does not exist on this
//    account, despite what search results about 2Factor's docs claim. Treat
//    any endpoint shape not present on 2factor.in/API/DOCS/SMS_OTP.html as
//    unverified.
//  - AUTOGEN + template also delivers voice. This is the decisive one: with
//    /SMS/{phone}/AUTOGEN/{template} it is 2FACTOR that generates the code and
//    2FACTOR that selects the template, and it still came through as a call.
//    No way of asking for SMS produces SMS, so the SMS route itself is
//    unavailable for this account or this destination number.
//
// NOTHING IN THIS REPOSITORY CAN FIX THIS. Do not add retries, channel
// overrides, or provider-shape experiments here — seven have been eliminated.
// The open questions are provider-side and need 2Factor support plus the DLT
// portal: is a default template mapped to the SMS-OTP service, and is
// "Agrimore2026" registered under a transactional/service-implicit category
// rather than promotional (promotional is blocked on DND-registered numbers,
// which would block the SMS route and trigger their voice fallback)?
// The one experiment still worth running is varying the DESTINATION: send to
// a second, known non-DND number. SMS there means the fault is destination
// specific (DND/category); voice there too means it is account-level.

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
