// ============================================================
//  Callable: createSellerByAdmin — Firebase Auth + Firestore
// ============================================================

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

const db = admin.firestore();
const auth = admin.auth();

async function loadAdminEmailsLower(): Promise<string[]> {
    const snap = await db.collection("settings").doc("access").get();
    const raw = snap.data()?.adminEmails;
    if (!Array.isArray(raw)) return [];
    return raw
        .map((x: unknown) => String(x).trim().toLowerCase())
        .filter((e) => e.length > 0);
}

// Phase 14, Workstream 6: prefer the caller's own custom claim (set only by
// syncUserRoleClaims from a real Firestore role, itself now locked to
// admin/Cloud-Functions-only by firestore.rules — see
// ownerCannotChangePrivilegedFields()) and fall back to the Firestore role
// only if the claim is absent (e.g. immediately after promotion, before the
// onWrite trigger has minted claims yet). This is defence in depth — the
// real fix is Workstream 2 making the underlying `role` field itself
// unwritable by a non-admin.
// Phase 15, Workstream 3c decision: KEPT unchanged — when
// settings/access.adminEmails is empty, any caller with Firestore
// role:'admin' still passes, with no allowlist narrowing. Before Phase 14
// this was a real risk (role was self-writable, so "any Firestore-role
// admin" meant "any user who wrote role:'admin' onto their own doc"). Now
// that firestore.rules' ownerCannotChangePrivilegedFields() makes role
// unwritable by a non-admin client, the ONLY ways role:'admin' can be set
// at all are: a direct Firestore console edit (followed by the deployed
// refreshUserRoleClaims callable, which mints the matching custom claim),
// or setUserRole.ts (itself gated behind an existing admin's claim/role,
// and source-only/UNDEPLOYED as of 2026-09-04 — so the console edit is
// today the only live path).
// Phase SEC-1 (2026-09-04) removed a third path that used to be listed
// here: functions/scripts/create_admin.js, a one-off owner-run Admin SDK
// script that hardcoded an admin email + password and shipped inside every
// functions deploy bundle (finding A-1). It is deleted; do not re-add it.
// Every remaining path is already a trusted, server-side action — narrowing this
// further would add no real security margin, and the failure mode of
// getting it wrong (an admin locked out of their own tooling because
// settings/access.adminEmails is empty or stale) is worse than the finding.
// Left exactly as-is; flagged here as a considered decision, not an
// oversight.
async function callerIsAdmin(uid: string, isAdminClaim: boolean): Promise<boolean> {
    if (isAdminClaim) return true;

    const u = await db.collection("users").doc(uid).get();
    if (!u.exists) return false;
    const d = u.data()!;
    if (d.role !== "admin") return false;
    const email = String(d.email || "").trim().toLowerCase();
    const allow = await loadAdminEmailsLower();
    if (allow.length === 0) return true;
    return allow.includes(email);
}

/**
 * Creates (or updates) a seller account with email/password login.
 * Caller must be an admin (Firestore `role: admin` + optional `settings/access.adminEmails`).
 */
export const createSellerByAdmin = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Sign in required");
    }

    if (!(await callerIsAdmin(context.auth.uid, context.auth.token.admin === true))) {
        throw new functions.https.HttpsError("permission-denied", "Admin only");
    }

    const email = String(data.email || "").trim().toLowerCase();
    const password = String(data.password || "");
    const name = String(data.name || "").trim();
    const phone = String(data.phone || "").trim();
    const shopName = String(data.shopName || "").trim();
    const shopAddress = String(data.shopAddress || "").trim();

    if (!email || password.length < 6 || !name || !shopName) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "email, password (min 6 chars), name, and shopName are required",
        );
    }

    let uid: string;
    let createdAuth = false;
    // Phase 14, Workstream 6 fix: an existing account used to have its
    // password silently reset to whatever the admin submitted
    // (auth.updateUser(uid, { password, ... })) — if the email happened to
    // belong to a customer, another admin, or the real owner, their
    // password was overwritten and emailVerified forced to true with no
    // signal to them. This now throws instead of touching the password at
    // all; an admin who genuinely needs to change an existing user's role
    // must do so through the real role-assignment flow, not this
    // "create a seller" endpoint.
    let existingAccountEmail: string | null = null;

    try {
        const existing = await auth.getUserByEmail(email);
        uid = existing.uid;
        existingAccountEmail = email;
    } catch (e: unknown) {
        const err = e as { code?: string };
        if (err.code === "auth/user-not-found") {
            const rec = await auth.createUser({
                email,
                password,
                emailVerified: true,
                displayName: name,
            });
            uid = rec.uid;
            createdAuth = true;
        } else {
            console.error("createSellerByAdmin auth error", e);
            throw new functions.https.HttpsError("internal", "Auth error");
        }
    }

    if (existingAccountEmail) {
        throw new functions.https.HttpsError(
            "already-exists",
            "An account with this email already exists. Manage its role through the role-assignment flow instead of creating a new seller — this endpoint no longer resets an existing account's password."
        );
    }

    const userPayload: Record<string, unknown> = {
        uid,
        email,
        name,
        phone: phone || null,
        role: "seller",
        sellerStatus: "approved",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (createdAuth) {
        userPayload.createdAt = admin.firestore.FieldValue.serverTimestamp();
    }

    const sellerPayload = {
        userId: uid,
        status: "approved",
        name,
        mobile: phone,
        email,
        shopName,
        shopAddress,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const reqPayload = {
        name,
        email,
        mobile: phone,
        shopName,
        shopAddress,
        status: "approved",
        appliedAt: admin.firestore.FieldValue.serverTimestamp(),
        reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
        createdByAdmin: true,
    };

    const batch = db.batch();
    batch.set(db.collection("users").doc(uid), userPayload, { merge: true });
    batch.set(db.collection("sellers").doc(uid), sellerPayload, { merge: true });
    batch.set(db.collection("sellerRequests").doc(uid), reqPayload, { merge: true });
    await batch.commit();

    await auth.setCustomUserClaims(uid, {
        role: "seller",
        admin: false,
        seller: true,
        sellerApproved: true,
        delivery_partner: false,
        deliveryApproved: false,
    });

    return { uid, email, createdAuth };
});
