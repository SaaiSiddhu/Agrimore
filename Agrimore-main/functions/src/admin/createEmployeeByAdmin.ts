// ============================================================
//  Callable: createEmployeeByAdmin — Firebase Auth + Firestore
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

async function callerIsAdmin(uid: string): Promise<boolean> {
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

    if (!(await callerIsAdmin(context.auth.uid))) {
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

    let uid: string;
    let createdAuth = false;

    try {
        const existing = await auth.getUserByEmail(email);
        uid = existing.uid;
        await auth.updateUser(uid, { password, displayName: name });
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
            console.error("createEmployeeByAdmin auth error", e);
            throw new functions.https.HttpsError("internal", "Auth error");
        }
    }

    const employeeCode = generateEmployeeCode(uid, name);

    const userPayload: Record<string, unknown> = {
        uid,
        email,
        name,
        phone: phone || null,
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
        phone: phone || null,
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
