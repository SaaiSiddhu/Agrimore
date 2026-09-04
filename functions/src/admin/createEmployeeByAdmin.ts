// ============================================================
//  Callable: createEmployeeByAdmin — Firebase Auth + Firestore
// ============================================================

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
// Phase 18, Workstream 1: the SAME normaliser sendPhoneOTP/verifyPhoneOTP
// use, imported rather than re-implemented. This is load-bearing, not a
// tidiness preference: verifyPhoneOTP resolves an existing account with
// auth.getUserByPhoneNumber(normalizePhone(raw)), so if the number written
// onto the Auth record here were normalised even slightly differently, that
// lookup would MISS this associate, mint them a SECOND uid, and orphan their
// employees/{uid} doc, associate code, wallet and commission history.
// changePhoneNumber.ts already imports it from exactly here, so this follows
// an established precedent rather than inventing one. Note it is imported
// from sendPhoneOTP (which exports it) — verifyPhoneOTP keeps a private,
// byte-identical copy; neither of those two files is edited by this phase.
import { normalizePhone } from "../common/sendPhoneOTP";

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
// Phase 15, Workstream 3c decision: KEPT unchanged — see the identical,
// fuller note in createSellerByAdmin.ts's callerIsAdmin(). Summary: now
// that role is unwritable by a non-admin client (Phase 14), every path to
// role:'admin' is already a trusted, server-side action, so narrowing this
// further adds no real security margin while risking locking an admin out
// of their own tooling.
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
 * Generate unique employee code: First 4 letters of name + 2 digit sequence.
 * Mirrors WalletModel's referral code generation (packages/agrimore_core).
 */
function generateEmployeeCode(uid: string, name: string): string {
    const cleanName = name.replace(/\s+/g, "").toUpperCase();
    const namePrefix = cleanName.length >= 4
        ? cleanName.slice(0, 4)
        : cleanName.padEnd(4, "X") || "EMPL";

    let hash = 0;
    for (let i = 0; i < uid.length; i++) {
        hash = (hash * 31 + uid.charCodeAt(i)) | 0;
    }
    const sequence = String(Math.abs(hash) % 100).padStart(2, "0");
    return `${namePrefix}${sequence}`;
}

/**
 * Creates (or updates) an employee account with email/password login.
 * Caller must be an admin (Firestore `role: admin` + optional `settings/access.adminEmails`).
 */
export const createEmployeeByAdmin = functions.https.onCall(async (data, context) => {
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
    const commissionRate = Number(data.commissionRate) || 0;

    if (!email || password.length < 6 || !name) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "email, password (min 6 chars), and name are required",
        );
    }

    // Phase 18, Workstream 1: phone stays OPTIONAL — omitting it behaves
    // exactly as it did before this phase. But a phone that IS supplied and
    // cannot be normalised is now rejected up front, BEFORE any Auth user or
    // Firestore document is created, rather than being quietly stored in a
    // shape nothing can look up. Failing here costs nothing; failing after
    // auth.createUser would leave a half-built associate behind.
    let normalizedPhone: string | null = null;
    if (phone) {
        normalizedPhone = normalizePhone(phone);
        if (!normalizedPhone) {
            throw new functions.https.HttpsError(
                "invalid-argument",
                "Enter a valid 10-digit Indian mobile number for this associate, or leave the phone field empty.",
            );
        }
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
    // "create an employee" endpoint.
    let existingAccountEmail: string | null = null;

    try {
        const existing = await auth.getUserByEmail(email);
        uid = existing.uid;
        existingAccountEmail = email;
    } catch (e: unknown) {
        const err = e as { code?: string };
        if (err.code === "auth/user-not-found") {
            // Phase 18, Workstream 1: attach the phone number to the Auth
            // record itself, not just to Firestore. Before this, an
            // admin-created associate had NO phoneNumber on their Auth
            // record, so they could never sign in with the phone-OTP path
            // that apps/employee now offers — getUserByPhoneNumber would
            // miss them and create a second, orphaned account.
            try {
                const rec = await auth.createUser({
                    email,
                    password,
                    emailVerified: true,
                    displayName: name,
                    ...(normalizedPhone ? { phoneNumber: normalizedPhone } : {}),
                });
                uid = rec.uid;
                createdAuth = true;
            } catch (createErr: unknown) {
                const cErr = createErr as { code?: string };
                // The number belongs to a DIFFERENT Auth user (very often the
                // associate's own existing CUSTOMER account, created when they
                // logged into the marketplace by phone OTP). Say so plainly and
                // stop. Silently dropping the phone would recreate the exact
                // orphaning bug this workstream exists to prevent, and stealing
                // the number from the other account would break their login.
                if (cErr.code === "auth/phone-number-already-exists") {
                    throw new functions.https.HttpsError(
                        "already-exists",
                        "This mobile number is already attached to another Agrimore account. If the associate already uses this number to sign in as a customer, approve their self-applied associate request instead of creating a new account here — that keeps their existing account, code and wallet.",
                    );
                }
                if (cErr.code === "auth/email-already-exists") {
                    throw new functions.https.HttpsError(
                        "already-exists",
                        "An account with this email already exists. Manage its role through the role-assignment flow instead of creating a new employee.",
                    );
                }
                console.error("createEmployeeByAdmin createUser error", createErr);
                throw new functions.https.HttpsError("internal", "Auth error");
            }
        } else {
            console.error("createEmployeeByAdmin auth error", e);
            throw new functions.https.HttpsError("internal", "Auth error");
        }
    }

    if (existingAccountEmail) {
        throw new functions.https.HttpsError(
            "already-exists",
            "An account with this email already exists. Manage its role through the role-assignment flow instead of creating a new employee — this endpoint no longer resets an existing account's password."
        );
    }

    const employeeCode = generateEmployeeCode(uid, name);

    // Phase 18, Workstream 1: store the NORMALISED (+91XXXXXXXXXX) form, not
    // the raw admin keystrokes. This is not cosmetic — changePhoneNumber.ts
    // enforces phone uniqueness with
    //   db.collection("employees").where("phone", "==", normalizePhone(raw))
    // (lines 86-88), so a raw "9876543210" stored here would never match that
    // query and an admin-created associate's number would look free to steal.
    // It also keeps users/{uid}.phone, employees/{uid}.phone and the Auth
    // record's phoneNumber in one single format.
    const userPayload: Record<string, unknown> = {
        uid,
        email,
        name,
        phone: normalizedPhone,
        role: "employee",
        employeeStatus: "approved",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (createdAuth) {
        userPayload.createdAt = admin.firestore.FieldValue.serverTimestamp();
    }

    const employeePayload = {
        userId: uid,
        name,
        email,
        phone: normalizedPhone,
        employeeCode,
        status: "approved",
        commissionRate,
        createdBy: "admin",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const batch = db.batch();
    batch.set(db.collection("users").doc(uid), userPayload, { merge: true });
    batch.set(db.collection("employees").doc(uid), employeePayload, { merge: true });
    await batch.commit();

    await auth.setCustomUserClaims(uid, {
        role: "employee",
        admin: false,
        seller: false,
        sellerApproved: false,
        delivery_partner: false,
        deliveryApproved: false,
        employee: true,
        employeeApproved: true,
    });

    return { uid, email, employeeCode, createdAuth };
});
