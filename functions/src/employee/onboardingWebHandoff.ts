// ============================================================
//  Callables: createOnboardingWebHandoff / redeemOnboardingWebHandoff
// ============================================================
//
// Phase ONBOARD-1. Lets an already-signed-in visitor on the marketplace
// MOBILE app open the associate onboarding page in the phone's own
// external browser -- where the actual Razorpay payment step lives
// (kIsWeb-gated, Phase 16B-2 D2) -- without signing in a second time.
//
// createOnboardingWebHandoff mints a short-lived, single-use, unguessable
// CODE (never a raw Firebase custom token or ID token, which would end up
// in browser history / server logs if placed in a URL); the web page
// exchanges that code, exactly once, via redeemOnboardingWebHandoff, for a
// genuine Firebase custom token to sign in with. The code carries no
// privilege beyond "sign in as the uid that created it" -- identical to
// what that same user could already do with their own phone-OTP
// credentials; this is a convenience bridge, not a privilege escalation.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as crypto from "crypto";
import { log } from "../common/helpers";

const HANDOFF_TTL_MS = 5 * 60 * 1000; // 5 minutes
const HANDOFF_PURPOSE = "associate_onboarding" as const;

export const createOnboardingWebHandoff = onCall(
  { minInstances: 0, memory: "256MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required");
    }
    const uid = request.auth.uid;
    const db = admin.firestore();

    const code = crypto.randomBytes(32).toString("hex");
    const now = Date.now();

    await db.collection("onboarding_handoffs").doc(code).set({
      uid,
      purpose: HANDOFF_PURPOSE,
      used: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromMillis(now + HANDOFF_TTL_MS),
    });

    log.info(`🔗 Created onboarding web handoff for uid=${uid}`);

    return { success: true, code };
  }
);

export const redeemOnboardingWebHandoff = onCall(
  { minInstances: 0, memory: "256MiB" },
  async (request) => {
    const code = request.data?.code;
    if (typeof code !== "string" || code.length === 0) {
      throw new HttpsError("invalid-argument", "code is required");
    }
    const db = admin.firestore();
    const ref = db.collection("onboarding_handoffs").doc(code);

    // Look-up + mark-used inside ONE transaction, so two near-simultaneous
    // redemption attempts (e.g. a page reload firing this twice) cannot
    // both succeed from the same still-valid code.
    const uid = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) {
        throw new HttpsError(
          "not-found",
          "This sign-in link is invalid. Please sign in manually."
        );
      }
      const data = snap.data()!;
      if (data.used === true) {
        throw new HttpsError(
          "failed-precondition",
          "This sign-in link has already been used. Please sign in manually."
        );
      }
      const expiresAt = data.expiresAt as admin.firestore.Timestamp | undefined;
      if (!expiresAt || expiresAt.toMillis() < Date.now()) {
        throw new HttpsError(
          "deadline-exceeded",
          "This sign-in link has expired. Please sign in manually."
        );
      }
      tx.update(ref, {
        used: true,
        usedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return data.uid as string;
    });

    const customToken = await admin.auth().createCustomToken(uid);

    log.info(`🔗 Redeemed onboarding web handoff for uid=${uid}`);

    return { success: true, customToken };
  }
);
