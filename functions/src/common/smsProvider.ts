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

// ...but the VOICE endpoint does NOT accept that form. Proven against the live
// API on 2026-08-30, same key, same instant:
//   POST /API/V1/{key}/SMS/918610787151/123456    -> {"Status":"Success"}
//   POST /API/V1/{key}/VOICE/918610787151/123456  -> HTTP 400
//        {"Status":"Error","Details":"Invalid Phone Number - Length Mismatch(Expected: 10)"}
// Voice wants the BARE 10-DIGIT national number, no country code. Because
// normalizePhone() in sendPhoneOTP.ts guarantees +91XXXXXXXXXX, stripping the
// leading "+91" is exact here rather than a guess.
//
// This defect was latent from Phase 16 (when voice was added) and invisible
// because every test mocks axios at this boundary, so no suite ever exercised
// the real endpoint — and because the voice calls that DID arrive were
// 2Factor internally converting SMS-endpoint requests, not this path working.
// Phase 22 made voice the default channel, which turned it into a total login
// outage: every sendPhoneOTP 502'd.
function toTwoFactorVoicePhone(normalizedPhone: string): string {
  return normalizedPhone.replace(/^\+91/, "");
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
//  - ROOT CAUSE FOUND, 2026-08-30: the account has NO usable DLT
//    registration at all. The owner's own dlt-registration.2factor.in
//    screenshots show "My DLT Templates" -> Approved Templates (0),
//    Blacklisted (0), "No results found"; and "My DLT Registrations" -> no
//    mapped entity at all (an empty "MAP NEW ENTITY" row, placeholder text
//    only). Whatever "Agrimore2026" / sender AGRIMO approval exists, it
//    exists on the OPERATOR's DLT platform and was never mapped into THIS
//    2Factor account. 2Factor cannot attach a DLT entity/template it does
//    not have, so it cannot send DLT-compliant transactional SMS on an
//    Indian route — and falling back to voice is exactly what that
//    produces. (An earlier version of this bullet asserted the account
//    "HAS an approved DLT template" and concluded "no template" was
//    therefore not the cause — that premise was checked against 2Factor's
//    internal OTP-template panel, not the actual TRAI DLT platform, and
//    was false. It is corrected here, not left standing.)
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
// overrides, or provider-shape experiments here — every other hypothesis
// above has been eliminated, and the bullet above this one confirms the
// actual root cause. There is no longer an open question about WHAT
// category "Agrimore2026" is registered under (asked by an earlier version
// of this paragraph) — that question is moot: there is no mapped template
// in the 2Factor account to HAVE a category. THE FIX IS AN OWNER ACTION IN
// THE 2FACTOR DLT PORTAL (dlt-registration.2factor.in), NOT a code change:
// (1) Map New Entity — business name + PAN exactly as registered with the
// operator, PE ID as issued by the operator; (2) register the template
// content so it appears under Approved Templates. Until both rows are
// non-empty there, no amount of code work here will make SMS arrive — and
// sendSmsOtp below already does the right thing and needs no change once
// DLT registration clears.
// One diagnostic still worth running, independent of the above: vary the
// DESTINATION — send to a second, known non-DND number. SMS there would
// mean the fault also has a destination-specific (DND/category) component
// even after DLT is fixed; voice there too would simply confirm what is
// already established: a purely account-level cause (the missing DLT
// mapping), consistent with every other finding above.

/** Sends `otp` to `normalizedPhone` via SMS. Throws on any delivery failure. */
export async function sendSmsOtp(normalizedPhone: string, otp: string): Promise<void> {
  const phone = toTwoFactorPhone(normalizedPhone);
  await call2Factor(`SMS/${phone}/${otp}`);
}

/** Calls `normalizedPhone` and reads `otp` aloud via 2Factor's voice API. Throws on failure. */
export async function sendVoiceOtp(normalizedPhone: string, otp: string): Promise<void> {
  // toTwoFactorVoicePhone, NOT toTwoFactorPhone — the two endpoints disagree
  // about the country code. See that function's comment for the live proof.
  const phone = toTwoFactorVoicePhone(normalizedPhone);
  await call2Factor(`VOICE/${phone}/${otp}`);
}
