import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

const db = admin.firestore();
const auth = admin.auth();

const BOOTSTRAP_ADMIN_EMAILS = new Set([
  "admin@agrimore.com",
  "admin@admin.com",
  "agrimore@gmail.com",
]);

type Role = "customer" | "seller" | "admin" | "delivery_partner";

function normalizeRole(role: unknown): Role {
  const raw = String(role || "customer").trim().toLowerCase();
  if (raw === "delivery") return "delivery_partner";
  if (raw === "seller" || raw === "admin" || raw === "delivery_partner") {
    return raw;
  }
  return "customer";
}

function isApprovedStatus(value: unknown): boolean {
  return String(value || "").trim().toLowerCase() === "approved";
}

async function getUserData(uid: string): Promise<admin.firestore.DocumentData | null> {
  const snap = await db.collection("users").doc(uid).get();
  return snap.exists ? snap.data() || null : null;
}

async function isBootstrapAdmin(uid: string, userData: admin.firestore.DocumentData | null): Promise<boolean> {
  const email = String(userData?.email || "").trim().toLowerCase();
  if (BOOTSTRAP_ADMIN_EMAILS.has(email)) return true;

  try {
    const user = await auth.getUser(uid);
    return BOOTSTRAP_ADMIN_EMAILS.has(String(user.email || "").trim().toLowerCase());
  } catch (error: any) {
    if (error.code === "auth/user-not-found") return false;
    throw error;
  }
}

async function buildClaims(uid: string): Promise<Record<string, unknown> | null> {
  const userData = await getUserData(uid);
  if (!userData) return null;

  const role = normalizeRole(userData.role);
  const bootstrapAdmin = await isBootstrapAdmin(uid, userData);

  const [sellerDoc, deliveryDoc] = await Promise.all([
    db.collection("sellers").doc(uid).get(),
    db.collection("delivery_partners").doc(uid).get(),
  ]);

  const sellerApproved =
    role === "seller" &&
    (isApprovedStatus(userData.sellerStatus) ||
      isApprovedStatus(sellerDoc.data()?.status));

  const deliveryApproved =
    role === "delivery_partner" &&
    (isApprovedStatus(userData.deliveryStatus) ||
      isApprovedStatus(deliveryDoc.data()?.status));

  const isAdmin = role === "admin" || bootstrapAdmin;

  return {
    role: isAdmin ? "admin" : role,
    admin: isAdmin,
    seller: sellerApproved,
    sellerApproved,
    delivery_partner: deliveryApproved,
    deliveryApproved,
  };
}

async function setClaims(uid: string): Promise<Record<string, unknown> | null> {
  const claims = await buildClaims(uid);

  try {
    await auth.setCustomUserClaims(uid, claims);
  } catch (error: any) {
    if (error.code === "auth/user-not-found") {
      console.warn(`[RoleClaims] Auth user not found for ${uid}`);
      return claims;
    }
    throw error;
  }

  return claims;
}

async function callerIsAdmin(uid: string): Promise<boolean> {
  const userData = await getUserData(uid);
  if (await isBootstrapAdmin(uid, userData)) return true;
  return userData?.role === "admin";
}

export const syncUserRoleClaims = functions.firestore
  .document("users/{userId}")
  .onWrite(async (_change, context) => {
    return setClaims(context.params.userId);
  });

export const syncSellerRoleClaims = functions.firestore
  .document("sellers/{userId}")
  .onWrite(async (_change, context) => {
    return setClaims(context.params.userId);
  });

export const syncDeliveryRoleClaims = functions.firestore
  .document("delivery_partners/{userId}")
  .onWrite(async (_change, context) => {
    return setClaims(context.params.userId);
  });

export const refreshUserRoleClaims = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in required");
  }

  const targetUid = String(data?.userId || context.auth.uid);
  if (targetUid !== context.auth.uid && !(await callerIsAdmin(context.auth.uid))) {
    throw new functions.https.HttpsError("permission-denied", "Admin only");
  }

  const claims = await setClaims(targetUid);
  return { success: true, userId: targetUid, claims };
});
