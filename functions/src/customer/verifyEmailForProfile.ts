// ============================================================
//  Phase 16, Workstream 4 — verifyEmailForProfile
// ============================================================
//
// Architecture decision (disclosed): the existing verifyEmailOTP.ts
// (Phase 15) is a full LOGIN endpoint — on a correct OTP it creates or
// signs into a Firebase Auth account KEYED BY EMAIL and mints a custom
// token for it. That is the wrong shape for this phase's use case: a user
// who is already signed in via phone OTP, typing an email into the
// profile-completion form, needs to PROVE they own that email address —
// not sign into a second, disconncted Firebase Auth identity keyed by it.
// Reusing verifyEmailOTP.ts as-is here would mint a competing account with
// a different uid than the caller's real (phone-authenticated) one.
//
// This callable does the narrow thing instead: it is authenticated
// (request.auth is required), it checks the submitted OTP against the same
// otp_codes/{email} document sendEmailOTP.ts already writes (same hash
// comparison, same attempts cap, same expiry — no logic duplicated or
// reinvented), and on success marks that document verified — WITHOUT ever
// touching Firebase Auth. completeUserProfile.ts then trusts that marker,
// scoped to this exact caller's uid (see verifiedByUid below), to decide
// whether the submitted email has been proven.
//
// verifyEmailOTP.ts itself is left completely untouched by this phase — it
// remains deployed exactly as Phase 15 hardened it, in case anything else
// depends on its full-login shape.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as crypto from "crypto";

const MAX_ATTEMPTS = 5;
// A verification is only trusted by completeUserProfile.ts for a bounded
// window after it succeeds — an old, long-forgotten "verified" marker
// shouldn't silently authorize an unrelated later profile-completion
// attempt for the same email.
const VERIFICATION_TRUST_WINDOW_MS = 30 * 60 * 1000; // 30 minutes

function hashOtp(otp: string): string {
  return crypto.createHash("sha256").update(otp).digest("hex");
}

export const verifyEmailForProfile = onCall(
  { minInstances: 0, memory: "256MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required");
    }
    const uid = request.auth.uid;

    const email = String(request.data?.email || "").trim().toLowerCase();
    const otp = String(request.data?.otp || "").trim();

    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      throw new HttpsError("invalid-argument", "A valid email is required");
    }
    if (!otp) {
      throw new HttpsError("invalid-argument", "OTP is required");
    }

    const db = admin.firestore();
    const otpRef = db.collection("otp_codes").doc(email);
    const otpDoc = await otpRef.get();

    if (!otpDoc.exists) {
      throw new HttpsError("failed-precondition", "No OTP found. Please request a new code.");
    }

    const data = otpDoc.data()!;

    if (data.verified) {
      // Idempotent: if THIS caller already verified this exact email, treat
      // a repeat call as success rather than an error (e.g. a client retry
      // after a network blip).
      if (data.verifiedByUid === uid) {
        return { success: true, alreadyVerified: true };
      }
      throw new HttpsError("failed-precondition", "OTP already used. Please request a new code.");
    }

    if (typeof data.attempts === "number" && data.attempts >= MAX_ATTEMPTS) {
      await otpRef.delete();
      throw new HttpsError("failed-precondition", "Too many attempts. Please request a new code.");
    }

    await otpRef.update({ attempts: admin.firestore.FieldValue.increment(1) });

    if (Date.now() > data.expiresAt) {
      await otpRef.delete();
      throw new HttpsError("failed-precondition", "OTP expired. Please request a new code.");
    }

    if (data.otpHash !== hashOtp(otp)) {
      throw new HttpsError("invalid-argument", "Invalid OTP. Please try again.");
    }

    await otpRef.update({
      verified: true,
      verifiedAt: Date.now(),
      verifiedByUid: uid,
    });

    return { success: true, alreadyVerified: false };
  }
);

/**
 * Checked by completeUserProfile.ts: was `email` verified by `uid`, via the
 * flow above, within the trust window? Exported so the two files share one
 * definition instead of duplicating the freshness/ownership logic.
 */
export async function isEmailVerifiedForUid(
  db: admin.firestore.Firestore,
  email: string,
  uid: string
): Promise<boolean> {
  const snap = await db.collection("otp_codes").doc(email).get();
  if (!snap.exists) return false;
  const data = snap.data()!;
  return (
    data.verified === true &&
    data.verifiedByUid === uid &&
    typeof data.verifiedAt === "number" &&
    Date.now() - data.verifiedAt < VERIFICATION_TRUST_WINDOW_MS
  );
}
