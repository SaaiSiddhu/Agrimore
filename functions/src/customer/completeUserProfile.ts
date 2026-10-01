// ============================================================
//  Phase 16, Workstream 4 — completeUserProfile
// ============================================================
//
// complete_profile_screen.dart (Phase 16, Workstream 6) used to collect
// Name + Phone and write `profileCompleted: true` directly to Firestore
// from the client — no server validation at all, and nothing forced a user
// through the screen in the first place. This callable is the
// server-authoritative replacement: name/email/dateOfBirth/gender are
// validated here, `profileCompleted`/`profileCompletedAt` are set only by
// this Admin SDK write (firestore.rules blocks a client from ever setting
// them directly — see Workstream 5), and a NEW user cannot complete
// without first proving ownership of the submitted email via
// verifyEmailForProfile.ts.
//
// New-vs-existing-user distinction (the single most important design
// decision in this file — read before changing it): the caller's CURRENT
// `users/{uid}.email` value, as it stood BEFORE this call, is the signal.
//   - If it is already non-empty AND already equals the submitted email
//     (case-insensitively) -> nothing new is being claimed; no OTP
//     verification is required.
//   - Otherwise (empty on file, or the submitted email differs from what's
//     on file) -> this is a new claim of email ownership and must be
//     verified via verifyEmailForProfile.ts first.
// This matches the Workstream 1 backfill's own grandfathering criterion
// (name + email + phone all present) exactly: a user with no email on file
// was never "usable-profile" complete by that definition either, so
// requiring verification the first time they add one is consistent with,
// not contrary to, "existing users are exempt" — it only ever exempts a
// resubmission of an email the account already had.
//
// Operational note or the owner, restated in the completion report: this
// per-call check is a SECOND line of defense. The FIRST and better one is
// the Workstream 1 backfill itself — running it with --apply BEFORE the
// new client ships sets profileCompleted: true directly (bypassing this
// callable, and the client-side gate, entirely) for every existing user
// who already has name+email+phone, so they never see the profile
// completion screen at all. Until that backfill actually runs, EVERY
// existing phone-only user (no email on file) will be asked to add and
// verify one on next login — this is expected under the rule above, not a
// bug, but it means the backfill run is a real prerequisite, not optional
// cleanup.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { isEmailVerifiedForUid } from "./verifyEmailForProfile";

// Mirrors packages/agrimore_core/lib/models/user_model.dart's
// kAllowedGenders exactly — kept in sync manually since the Dart shared
// package isn't consumable from functions/.
const ALLOWED_GENDERS = ["male", "female", "non_binary", "prefer_not_to_say"];

// Mirrors user_model.dart's kMinimumProfileAgeYears exactly — see that
// file's comment for the "why 18" reasoning. A single, easily-changed
// constant, not scattered inline logic.
const MINIMUM_AGE_YEARS = 18;
const MAXIMUM_AGE_YEARS = 120;

const NAME_MIN_LENGTH = 2;
const NAME_MAX_LENGTH = 60;
// Unicode letters/marks (covers Indian-language names), spaces, apostrophe,
// hyphen, period.
const NAME_PATTERN = /^[\p{L}\p{M}\s.'-]+$/u;

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

export const completeUserProfile = onCall(
  { minInstances: 0, memory: "256MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required");
    }
    // Deliberately never accepts a target uid — operates ONLY on the
    // caller's own document. Accepting one is exactly the shape
    // privilege-escalation bugs are made of.
    const uid = request.auth.uid;
    if (request.data?.expectedOwnerId !== undefined && request.data.expectedOwnerId !== uid) {
      throw new HttpsError("permission-denied", "Profile change does not belong to this account");
    }

    const db = admin.firestore();
    const userRef = db.collection("users").doc(uid);

    // --- Validate inputs ---------------------------------------------
    const name = String(request.data?.name || "").trim();
    if (name.length < NAME_MIN_LENGTH || name.length > NAME_MAX_LENGTH) {
      throw new HttpsError(
        "invalid-argument",
        `Name must be between ${NAME_MIN_LENGTH} and ${NAME_MAX_LENGTH} characters`
      );
    }
    if (!NAME_PATTERN.test(name)) {
      throw new HttpsError("invalid-argument", "Name contains invalid characters");
    }

    const email = String(request.data?.email || "").trim().toLowerCase();
    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      throw new HttpsError("invalid-argument", "A valid email is required");
    }

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

    const gender = String(request.data?.gender || "").trim().toLowerCase();
    if (!ALLOWED_GENDERS.includes(gender)) {
      throw new HttpsError("invalid-argument", `Gender must be one of: ${ALLOWED_GENDERS.join(", ")}`);
    }

    // --- Transaction: all reads first, then all writes ----------------
    const result = await db.runTransaction(async (tx) => {
      const callerSnap = await tx.get(userRef);
      if (!callerSnap.exists) {
        throw new HttpsError("not-found", "User account not found");
      }
      const callerData = callerSnap.data()!;

      // Idempotent no-op: re-calling on an already-complete profile
      // succeeds without re-validating email uniqueness/verification
      // against values that may have since changed underneath it (e.g. a
      // stale, expired otp_codes doc) — a genuine profile CHANGE after
      // completion goes through the normal profile-edit path
      // (firestore.rules' owner-writable name/gender/dateOfBirth fields),
      // not back through this callable.
      if (callerData.profileCompleted === true) {
        return { success: true, alreadyComplete: true };
      }

      const existingEmail = typeof callerData.email === "string" ? callerData.email.trim().toLowerCase() : "";
      const isResubmissionOfKnownEmail = existingEmail !== "" && existingEmail === email;

      // Email uniqueness — must not already belong to a DIFFERENT uid.
      // Race note, disclosed honestly: Firestore has no unique-index
      // primitive. This query is read inside the transaction (so it's
      // consistent with everything else this transaction reads), but two
      // truly simultaneous completeUserProfile calls claiming the SAME
      // never-before-seen email could both observe "no existing owner" and
      // both proceed — the same class of limitation
      // redeemReferralCode's referral-code lookup already has in this
      // codebase. Acceptable here: the consequence is two accounts
      // sharing a display email, not a security bypass (each uid's Auth
      // identity is unaffected), and is astronomically unlikely for two
      // people typing the same never-used address in the same instant.
      const dupSnap = await tx.get(db.collection("users").where("email", "==", email).limit(1));
      const dupOwnerUid = dupSnap.empty ? null : dupSnap.docs[0].id;
      if (dupOwnerUid && dupOwnerUid !== uid) {
        throw new HttpsError("already-exists", "This email is already associated with another account");
      }

      if (!isResubmissionOfKnownEmail) {
        const verified = await isEmailVerifiedForUid(db, email, uid);
        if (!verified) {
          throw new HttpsError(
            "failed-precondition",
            "Please verify this email address before completing your profile"
          );
        }
      }

      tx.update(userRef, {
        name,
        email,
        dateOfBirth: admin.firestore.Timestamp.fromDate(dob),
        gender,
        profileCompleted: true,
        profileCompletedAt: admin.firestore.FieldValue.serverTimestamp(),
        emailVerified: isResubmissionOfKnownEmail ? callerData.emailVerified === true : true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { success: true, alreadyComplete: false };
    });

    return result;
  }
);
