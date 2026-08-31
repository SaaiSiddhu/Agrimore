// ============================================================
//  changePhoneNumber — verify a NEW number and update an EXISTING,
//  already-signed-in user's own phone, in one call.
// ============================================================
//
// Why this exists: there is no path anywhere in this codebase for a user
// who has already completed their profile to change their phone number.
// completeUserProfile.ts's own comment is explicit that a post-completion
// change is someone else's problem ("a genuine profile CHANGE after
// completion goes through the normal profile-edit path... not back through
// this callable") — and no such path was ever built for phone.
//
// Why this is NOT built on top of verifyPhoneOTP.ts (the login endpoint):
// that callable's whole job, on a correct code, is to find-or-CREATE a
// Firebase Auth user for the submitted number and mint a session for IT —
// see its own header comment and verifyEmailForProfile.ts's identical
// reasoning for email. Calling it here would (a) create an orphan Auth
// account under the new number, disconnected from the caller's real,
// already-signed-in uid, and (b) hand back a session the caller doesn't
// want, for an account they didn't mean to create. This callable instead
// does the narrow thing: verify the caller (already authenticated) proved
// ownership of phone_otp_codes/{newPhone} (the same document sendPhoneOTP.ts
// already writes — no OTP logic duplicated, hashOtp/normalizePhone imported
// from there), and if so, write the number onto the CALLER's own
// users/{uid} doc. Firebase Auth is never touched.
//
// Cross-account collision check ported from the reference build's
// change-phone screen, moved server-side (it was client-only there, which
// meant it was advisory, not enforced) — a phone number already in use by a
// DIFFERENT uid, in ANY of users/sellers/employees, is rejected rather than
// silently creating a second account that shares it.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { hashOtp, normalizePhone } from "../common/sendPhoneOTP";

const MAX_ATTEMPTS = 5;

export const changePhoneNumber = onCall(
  { minInstances: 0, memory: "256MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required");
    }
    const uid = request.auth.uid;

    const rawPhone = String(request.data?.phone || "").trim();
    const otp = String(request.data?.otp || "").trim();

    const normalizedPhone = normalizePhone(rawPhone);
    if (!normalizedPhone) {
      throw new HttpsError("invalid-argument", "Please enter a valid 10-digit mobile number");
    }
    if (!otp) {
      throw new HttpsError("invalid-argument", "OTP is required");
    }

    const db = admin.firestore();
    const otpRef = db.collection("phone_otp_codes").doc(normalizedPhone);
    const otpDoc = await otpRef.get();

    if (!otpDoc.exists) {
      throw new HttpsError("failed-precondition", "No OTP found. Please request a new code.");
    }
    const otpData = otpDoc.data()!;

    if (typeof otpData.attempts === "number" && otpData.attempts >= MAX_ATTEMPTS) {
      await otpRef.delete();
      throw new HttpsError("failed-precondition", "Too many attempts. Please request a new code.");
    }

    await otpRef.update({ attempts: admin.firestore.FieldValue.increment(1) });

    if (Date.now() > otpData.expiresAt) {
      await otpRef.delete();
      throw new HttpsError("failed-precondition", "OTP expired. Please request a new code.");
    }

    if (otpData.otpHash !== hashOtp(otp)) {
      throw new HttpsError("invalid-argument", "Invalid OTP. Please try again.");
    }

    // OTP proven correct. Reject if this number already belongs to a
    // different account before writing it onto this one.
    const [usersCollision, sellersCollision, employeesCollision] = await Promise.all([
      db.collection("users").where("phone", "==", normalizedPhone).limit(1).get(),
      db.collection("sellers").where("phone", "==", normalizedPhone).limit(1).get(),
      db.collection("employees").where("phone", "==", normalizedPhone).limit(1).get(),
    ]);
    for (const snap of [usersCollision, sellersCollision, employeesCollision]) {
      if (!snap.empty && snap.docs[0].id !== uid) {
        throw new HttpsError(
          "already-exists",
          "This mobile number is already registered to another Agrimore account."
        );
      }
    }

    await db.collection("users").doc(uid).update({
      phone: normalizedPhone,
      phoneVerified: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // One-time use, same convention verifyPhoneOTP.ts's login path follows.
    await otpRef.delete();

    return { success: true, phone: normalizedPhone };
  }
);
