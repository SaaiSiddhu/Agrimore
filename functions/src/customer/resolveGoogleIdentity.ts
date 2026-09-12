// ============================================================
//  AGRIMORE - RESOLVE GOOGLE IDENTITY CLOUD FUNCTION
// ============================================================
//
// AUTH-3 (corrected architecture, owner directive 2026-09-12): the client
// must know whether a Google identity is ALREADY linked to an AgriMore
// account BEFORE deciding whether to sign in with it — a first-time
// identity must never reach a temporary Firebase session that later gets
// signed out on a miss (the exact shape the original AUTH-3 plan used and
// the owner corrected). Both the "linked" and "unlinked" cases are
// therefore resolved here with NO Firebase Auth context at call time,
// which is why this is an unauthenticated onRequest endpoint (mirroring
// verifyPhoneOTP.ts's own shape) rather than an onCall callable — there is
// no request.auth to require yet.
//
// This function is a pure identity LOOKUP boundary: it verifies the
// caller's Google ID token itself, then answers one question (is this
// Google identity already linked to an existing Firebase user?). It never
// creates a user, never writes Firestore, never signs anyone in, and
// never returns more than the yes/no plus the uid needed to sanity-check
// the client's own subsequent signInWithCredential result.
//
// sendPhoneOTP.ts / verifyPhoneOTP.ts are untouched by this phase and are
// not referenced here — phone verification for a first-time Google
// identity goes through those exact functions, unchanged, from the client.

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import { OAuth2Client } from "google-auth-library";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const auth = admin.auth();

// Must match the serverClientId passed to GoogleSignIn(...) in
// packages/agrimore_services/lib/auth/auth_service.dart — that value is
// what makes the client's Google ID token audienced to THIS id, which is
// exactly what verifyIdToken checks below. Not a secret: a Google OAuth
// "client ID" is a public identifier by design, already shipped inside
// every app binary (the same category as the Google client keys in
// firebase_options.dart — see security.md's own note on that file).
const GOOGLE_WEB_CLIENT_ID =
  "1082819024270-0rmfnpcfjbmd12mq3h4qbffp67jri89a.apps.googleusercontent.com";

const oauthClient = new OAuth2Client(GOOGLE_WEB_CLIENT_ID);

export const resolveGoogleIdentity = functions.https.onRequest(async (req, res) => {
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

  try {
    const { idToken } = req.body;
    if (!idToken || typeof idToken !== "string") {
      res.status(400).json({ success: false, error: "Google ID token is required" });
      return;
    }

    // The ONLY trust boundary in this function: verifies signature, issuer
    // and audience together and throws on any mismatch or expiry.
    // Everything below trusts the extracted subject only because this
    // call already succeeded — never trust a client-supplied subject,
    // email, or uid directly (see this phase's own security invariant).
    let subject: string;
    try {
      const ticket = await oauthClient.verifyIdToken({
        idToken,
        audience: GOOGLE_WEB_CLIENT_ID,
      });
      const payload = ticket.getPayload();
      if (!payload || !payload.sub) {
        throw new Error("Google ID token carried no subject claim");
      }
      subject = payload.sub;
    } catch (verifyError) {
      console.error("Google ID token verification failed:", verifyError);
      res.status(401).json({ success: false, error: "Invalid Google credential" });
      return;
    }

    // Looks up an existing Firebase Auth user already linked with
    // providerId=google.com and this subject — a native Auth API lookup,
    // the same shape verifyPhoneOTP.ts already uses for
    // auth.getUserByPhoneNumber(). Never a Firestore query, never an
    // email-based lookup (email enumeration is not this function's job).
    try {
      const user = await auth.getUserByProviderUid("google.com", subject);
      res.status(200).json({ success: true, linked: true, expectedUid: user.uid });
      return;
    } catch (lookupError: any) {
      if (lookupError.code === "auth/user-not-found") {
        res.status(200).json({ success: true, linked: false });
        return;
      }
      throw lookupError;
    }
  } catch (error: any) {
    console.error("Error resolving Google identity:", error);
    res.status(500).json({ success: false, error: "Failed to resolve Google identity" });
  }
});
