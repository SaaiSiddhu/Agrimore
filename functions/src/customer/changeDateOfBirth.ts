// ============================================================
//  changeDateOfBirth — apply a NEW date of birth to an EXISTING,
//  already-signed-in user's own profile.
// ============================================================
//
// dateOfBirth is blanket-blocked in firestore.rules'
// ownerCannotChangePrivilegedFields() (Phase 16, Workstream 5) — a client
// can never write it directly, at any value, after the document exists.
// That block is deliberate and stays exactly as-is; this callable is the
// one authorised path around it, same shape as changeEmailAddress.ts /
// changePhoneNumber.ts for their own fields. completeUserProfile.ts's own
// header comment claims a post-completion DOB change "goes through the
// normal profile-edit path... via a full-object update" — checked against
// the actual rule (not assumed): that claim is correct for name/gender,
// which really are plain owner-writable fields, but wrong for dateOfBirth
// specifically, which the same rule blocks outright regardless of value.
// This file is that missing path, restricted to DOB alone.
//
// No OTP/verification concept applies here the way it does for phone/email
// (there is no channel to prove a birthdate) — the safeguard PROFILE-8's
// owner asked for instead is server-side re-validation of the same age
// bounds completeUserProfile.ts already enforces at signup, so a change
// cannot silently place the account under the minimum age. `parseDateOfBirth`
// / `ageYears` / the age constants are duplicated from completeUserProfile.ts
// rather than imported — mirrors how ALLOWED_GENDERS/MINIMUM_AGE_YEARS are
// already duplicated there from user_model.dart's Dart constants, kept in
// sync manually since neither direction is consumable across the language
// boundary.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

const MINIMUM_AGE_YEARS = 18;
const MAXIMUM_AGE_YEARS = 120;

function parseDateOfBirth(raw: unknown): Date | null {
  if (typeof raw !== "string" && typeof raw !== "number") return null;
  const d = new Date(raw as string | number);
  if (Number.isNaN(d.getTime())) return null;
  return d;
}

function ageYears(dob: Date, now: Date): number {
  let age = now.getFullYear() - dob.getFullYear();
  const monthDiff = now.getMonth() - dob.getMonth();
  if (monthDiff < 0 || (monthDiff === 0 && now.getDate() < dob.getDate())) {
    age--;
  }
  return age;
}

export const changeDateOfBirth = onCall(
  { minInstances: 0, memory: "256MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required");
    }
    // Deliberately never accepts a target uid — operates ONLY on the
    // caller's own document, same reasoning completeUserProfile.ts states
    // for the identical choice.
    const uid = request.auth.uid;

    const dob = parseDateOfBirth(request.data?.dateOfBirth);
    if (!dob) {
      throw new HttpsError("invalid-argument", "A valid date of birth is required");
    }
    const now = new Date();
    if (dob.getTime() > now.getTime()) {
      throw new HttpsError("invalid-argument", "Date of birth cannot be in the future");
    }
    const age = ageYears(dob, now);
    if (age > MAXIMUM_AGE_YEARS) {
      throw new HttpsError("invalid-argument", "Date of birth is not valid");
    }
    if (age < MINIMUM_AGE_YEARS) {
      throw new HttpsError(
        "failed-precondition",
        `You must be at least ${MINIMUM_AGE_YEARS} years old to use Agrimore`
      );
    }

    const db = admin.firestore();
    const userRef = db.collection("users").doc(uid);

    const snap = await userRef.get();
    if (!snap.exists) {
      throw new HttpsError("not-found", "User account not found");
    }

    await userRef.update({
      dateOfBirth: admin.firestore.Timestamp.fromDate(dob),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true };
  }
);
