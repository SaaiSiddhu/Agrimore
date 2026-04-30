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
 * Creates (or updates) a seller account with email/password login.
 * Caller must be an admin (Firestore `role: admin` + optional `settings/access.adminEmails`).
 */
export const createSellerByAdmin = functions.https.onCall(async (request) => {
    const data = request.data;
    const context = request;
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
            console.error("createSellerByAdmin auth error", e);
            throw new functions.https.HttpsError("internal", "Auth error");
        }
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

    return { uid, email, createdAuth };
});
