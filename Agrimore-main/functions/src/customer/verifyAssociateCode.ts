import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

// Lets the optional B2C "Associate Code" field (AssociateCodeField.dart)
// show a real "this code is valid" state before checkout — previously
// there was no Apply/verify step at all, only a plain text box the
// customer typed into and hoped for the best.
//
// This mirrors createOrder.ts's exact B2C resolution rules (same
// employees.where('employeeCode','==',code).where('status','==','approved')
// query, same self-attribution block, same onboarding-gate check) so the
// checkmark the customer sees here is truthful about what createOrder will
// actually do at order time — createOrder.ts remains the sole place
// attribution is decided; this is advisory-only feedback, never a gate.
//
// Deliberately returns nothing beyond a boolean: the field's locked
// invariant (see AssociateCodeField's header comment) is that a customer
// only ever sees what they themselves typed, never another person's name
// or any associate list. employees/{id} read access is owner-or-admin-only
// in firestore.rules, so a client-side query cannot do this lookup at all —
// this callable exists specifically to do it server-side without leaking
// the matched document's fields back to the caller.
export const verifyAssociateCode = onCall(
  { minInstances: 0, memory: "256MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required");
    }
    const uid = request.auth.uid;
    const code = String(request.data?.code || "").trim();
    if (!code) {
      return { valid: false };
    }

    const db = admin.firestore();
    const snap = await db
      .collection("employees")
      .where("employeeCode", "==", code)
      .where("status", "==", "approved")
      .limit(1)
      .get();

    if (snap.empty) {
      return { valid: false };
    }

    const candidate = snap.docs[0];
    if (candidate.id === uid) {
      // Self-attribution never counts (mirrors createOrder.ts) — reported
      // as invalid rather than valid so the customer isn't told their own
      // code "works" when it will never actually attribute an order.
      return { valid: false };
    }

    const data = candidate.data();
    const gateCleared =
      (data.onboardingPaid === true || data.onboardingWaived === true) &&
      !data.onboardingRefundedAt;

    return { valid: gateCleared };
  }
);
