// ============================================================
//  changeEmailAddress — apply an ALREADY-VERIFIED email to an EXISTING,
//  already-signed-in user's own profile.
// ============================================================
//
// Deliberately two calls, not one: the client must call verifyEmailForProfile
// first (existing, Phase 16 Workstream 4 — verifies the OTP against
// otp_codes/{email} and marks verifiedByUid), and only then this callable,
// which trusts that marker via the shared isEmailVerifiedForUid() helper —
// no OTP/hash logic duplicated here.
//
// Why a separate callable from completeUserProfile.ts rather than reusing
// it: that callable's own comment states a post-completion change is out of
// its scope by design ("a genuine profile CHANGE after completion goes
// through the normal profile-edit path... not back through this callable"),
// and it also short-circuits to a same-value no-op on an already-complete
// profile — the wrong behaviour for "I am deliberately changing to a
// DIFFERENT email". This callable is the missing normal profile-edit path
// completeUserProfile.ts's comment refers to, for email specifically.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { isEmailVerifiedForUid } from "./verifyEmailForProfile";

export const changeEmailAddress = onCall(
  { minInstances: 0, memory: "256MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required");
    }
    const uid = request.auth.uid;

    const email = String(request.data?.email || "").trim().toLowerCase();
    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      throw new HttpsError("invalid-argument", "A valid email is required");
    }

    const db = admin.firestore();

    const verified = await isEmailVerifiedForUid(db, email, uid);
    if (!verified) {
      throw new HttpsError(
        "failed-precondition",
        "Please verify this email address before saving it."
      );
    }

    // Same uniqueness check completeUserProfile.ts runs, same disclosed
    // race-window caveat (Firestore has no unique-index primitive) — see
    // that file's comment for why this is acceptable here too.
    const dupSnap = await db.collection("users").where("email", "==", email).limit(1).get();
    const dupOwnerUid = dupSnap.empty ? null : dupSnap.docs[0].id;
    if (dupOwnerUid && dupOwnerUid !== uid) {
      throw new HttpsError("already-exists", "This email is already associated with another account");
    }

    await db.collection("users").doc(uid).update({
      email,
      emailVerified: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, email };
  }
);
