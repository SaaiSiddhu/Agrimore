// ============================================================
//  Callable: setUserRole — Admin SDK role promotion/demotion
// ============================================================
//
// Phase 15, Workstream 3b: Phase 14 correctly removed the client's ability
// to write users/{uid}.role directly (see firestore.rules'
// ownerCannotChangePrivilegedFields()) — but that means AdminAccessConfig
// and the settings/access.adminEmails allowlist can now only DETECT that a
// user should be admin, never GRANT it; there is currently no supported way
// to promote a user except editing Firestore by hand. This callable is that
// server-side replacement, using the Admin SDK (bypasses firestore.rules
// entirely, the same way createSellerByAdmin.ts/createEmployeeByAdmin.ts
// already do).

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { setClaims } from "./roleClaims";

// Mirrors roleClaims.ts's `Role` union exactly, per this phase's own
// instruction — but see the storage-mapping note below on "customer".
const VALID_ROLES = ["customer", "seller", "admin", "delivery_partner", "employee"] as const;
type ApiRole = (typeof VALID_ROLES)[number];

// roleClaims.ts's Role union uses "customer" for the non-privileged case,
// but the REAL, live value every other code path in this app writes and
// reads for an ordinary user is "user" — not "customer". Grepped: `role ==
// 'user'` is checked directly by apps/admin's user_management_screen.dart
// (its user-list filter) and by UserModel.isBuyer
// (packages/agrimore_core/lib/models/user_model.dart). Writing "customer"
// verbatim would silently break both — the affected user would vanish from
// the admin user list and isBuyer would go false. roleClaims.ts's own
// normalizeRole() already treats "user" and "customer" identically for
// claim-minting purposes (anything not seller/admin/delivery_partner/
// employee falls through to the "customer" claim), so this mapping changes
// nothing about the resulting custom claims — only which literal string
// lands in the Firestore field, chosen to match what the rest of the app
// actually checks for.
function toStoredRole(apiRole: ApiRole): string {
  return apiRole === "customer" ? "user" : apiRole;
}

export const setUserRole = onCall({ minInstances: 0, memory: "256MiB" }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required");
  }

  // Claim-first, mirroring createSellerByAdmin.ts/createEmployeeByAdmin.ts's
  // callerIsAdmin(uid, isAdminClaim) shape (Phase 14, Workstream 6).
  const isAdminClaim = request.auth.token.admin === true;
  if (!isAdminClaim) {
    const callerSnap = await admin.firestore().collection("users").doc(request.auth.uid).get();
    if (callerSnap.data()?.role !== "admin") {
      throw new HttpsError("permission-denied", "Admin only");
    }
  }

  const targetUserId = String(request.data?.userId || "").trim();
  const requestedRole = String(request.data?.role || "").trim().toLowerCase();

  if (!targetUserId) {
    throw new HttpsError("invalid-argument", "userId is required");
  }
  if (!(VALID_ROLES as readonly string[]).includes(requestedRole)) {
    throw new HttpsError("invalid-argument", `role must be one of: ${VALID_ROLES.join(", ")}`);
  }
  const apiRole = requestedRole as ApiRole;

  // Refuses to let a caller change their OWN role — prevents an admin
  // accidentally or maliciously self-demoting/locking everyone out, and
  // removes the self-escalation shape entirely.
  if (targetUserId === request.auth.uid) {
    throw new HttpsError(
      "failed-precondition",
      "You cannot change your own role. Ask another admin to do it."
    );
  }

  const db = admin.firestore();
  const targetRef = db.collection("users").doc(targetUserId);
  const storedRole = toStoredRole(apiRole);

  await db.runTransaction(async (tx) => {
    const targetSnap = await tx.get(targetRef);
    if (!targetSnap.exists) {
      throw new HttpsError("not-found", "Target user not found");
    }
    const currentRole = String(targetSnap.data()?.role || "").trim().toLowerCase();

    // Refuses to demote the last remaining admin. The admin count is read
    // as an aggregate COUNT query inside this same transaction — Firestore
    // applies the same transactional isolation to an aggregate read as to
    // a document read, so a concurrent write that would change the count
    // forces this transaction to retry rather than act on a stale count.
    //
    // Race characteristic that remains, stated honestly: two SIMULTANEOUS
    // calls each demoting a DIFFERENT admin, when exactly two admins exist,
    // could each observe count=2 in their own transaction attempt before
    // either commits — Firestore's optimistic-concurrency retry does not
    // protect against this specific interleaving, because neither
    // transaction's read set includes the OTHER transaction's target
    // document (they touch different user docs, so they don't conflict
    // with each other from Firestore's point of view). This is a
    // best-effort safety net for the realistic single-operator case (one
    // admin fat-fingering a demotion), not a distributed-lock guarantee
    // against adversarial concurrent admins.
    if (currentRole === "admin" && storedRole !== "admin") {
      const adminCountSnap = await tx.get(db.collection("users").where("role", "==", "admin").count());
      if ((adminCountSnap.data().count || 0) <= 1) {
        throw new HttpsError("failed-precondition", "Cannot demote the last remaining admin");
      }
    }

    tx.update(targetRef, {
      role: storedRole,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  // Mint claims immediately rather than waiting for syncUserRoleClaims's
  // onWrite trigger to fire asynchronously — mirrors
  // createSellerByAdmin.ts/createEmployeeByAdmin.ts's own immediate
  // auth.setCustomUserClaims() call right after their Firestore write. The
  // trigger will also fire and recompute the same claims redundantly; this
  // is harmless idempotent duplication, matching that existing convention.
  const claims = await setClaims(targetUserId);

  return { success: true, userId: targetUserId, role: storedRole, claims };
});
