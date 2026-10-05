// Default-disabled photo transport. No existing callable's App Check policy changes.
import * as admin from "firebase-admin";
import type { Bucket } from "@google-cloud/storage";
import { createHash } from "crypto";
import { defineBoolean } from "firebase-functions/params";
import type { Expression } from "firebase-functions/params";
import { CallableRequest, HttpsError, onCall } from "firebase-functions/v2/https";
import { createPhotoDraft, readPhotoDraftStatus } from "./reviewPhotoDraftCore";
import { uploadPhotoRequest } from "./reviewPhotoUpload";
import { publishPhotoRequest } from "./reviewPhotoPublication";
import { cleanupPhotoDraftObjects } from "./reviewPhotoCleanup";
import { MAX_PHOTO_BYTES } from "./reviewPhotoImage";
const FLOW_ENABLED = defineBoolean("REVIEW_PHOTO_FLOW_ENABLED", { default: false });
const APPCHECK_APPROVED = defineBoolean("REVIEW_PHOTO_APPCHECK_REQUIRED", { default: false });
export const PHOTO_RPC_OPTIONS = { minInstances: 0, maxInstances: 1, concurrency: 1, cpu: 1, memory: "256MiB" as const, timeoutSeconds: 60 };
export type PhotoRpcDependencies = {
 db: () => admin.firestore.Firestore; bucket: () => Bucket; expectedBucket: () => string;
 enabled: () => boolean; appCheckApproved: () => boolean; now: () => number;
 user: (uid: string) => Promise<{ uid: string; disabled: boolean; tokensValidAfterTime?: string }>;
};
type Operation = "create" | "upload" | "publish" | "status" | "cleanup";
function bad(): never { throw new HttpsError("invalid-argument", "Invalid review photo request."); }
function identity(v: unknown): string {
 if (typeof v !== "string" || !v || v.trim() !== v || v.includes("/") || v.length > 128 || Buffer.byteLength(v) > 512) bad();
 return v;
}
function payload(op: Operation, value: unknown): Record<string, any> {
 const keys = { create: "assetIds,draftId,productId,reviewId", upload: "assetId,draftId,imageBase64", publish: "comment,draftId,rating,title", status: "draftId", cleanup: "abandon,draftId" };
 if (!value || typeof value !== "object" || Array.isArray(value) || Object.keys(value).sort().join(",") !== keys[op]) bad();
 const d = value as Record<string, any>;
 identity(d.draftId);
 if (!/^[A-Za-z0-9_-]{1,128}$/.test(d.draftId)) bad();
 if (op === "create") {
   identity(d.productId); identity(d.reviewId);
   if (!Array.isArray(d.assetIds) || !d.assetIds.length || d.assetIds.length > 10 || new Set(d.assetIds).size !== d.assetIds.length ||
     d.assetIds.some((a: unknown) => typeof a !== "string" || !/^[A-Za-z0-9_-]{1,128}$/.test(a) || ["__proto__", "prototype", "constructor"].includes(a))) bad();
 }
 if (op === "upload" && (typeof d.assetId !== "string" || !/^[A-Za-z0-9_-]{1,128}$/.test(d.assetId) || ["__proto__", "prototype", "constructor"].includes(d.assetId) || typeof d.imageBase64 !== "string" ||
   d.imageBase64.length > Math.ceil(MAX_PHOTO_BYTES / 3) * 4)) bad();
 if (op === "publish" && (!Number.isInteger(d.rating) || d.rating < 1 || d.rating > 5 || typeof d.title !== "string" || d.title.length > 200 || typeof d.comment !== "string" || d.comment.length > 10000)) bad();
 if (op === "cleanup" && typeof d.abandon !== "boolean") bad();
 return d;
}
async function activeSession(deps: PhotoRpcDependencies, request: CallableRequest<unknown>, actor: string) {
 const at = request.auth?.token.auth_time;
 if (!Number.isSafeInteger(at) || (at as number) < 0) throw new HttpsError("unauthenticated", "Sign in again to manage review photos.");
 let user;
 try { user = await deps.user(actor); } catch { throw new HttpsError("unauthenticated", "Sign in again to manage review photos."); }
 const after = user.tokensValidAfterTime === undefined ? 0 : Date.parse(user.tokensValidAfterTime);
 if (user.uid !== actor || user.disabled || !Number.isFinite(after) || (at as number) < Math.floor(after / 1000)) throw new HttpsError("unauthenticated", "Sign in again to manage review photos.");
}
/** Private work counters; rejected business requests still consume their admitted work budget. */
async function charge(deps: PhotoRpcDependencies, actor: string, op: Operation) {
 const status = op === "status", lane = status ? "status" : "work", globalMax = status ? 240 : 60, ownerMax = status ? 60 : 20;
 const db = deps.db(), owner = createHash("sha256").update(actor).digest("hex");
 await db.runTransaction(async tx => {
   const now = deps.now();
   if (!Number.isSafeInteger(now) || now < 0) bad();
   const start = Math.floor(now / 60000) * 60000;
   const g = db.collection("review_photo_rpc_limits").doc("global_" + lane), o = db.collection("review_photo_rpc_limits").doc(owner + "_" + lane);
   const rows = await Promise.all([tx.get(g), tx.get(o)]), limits = [globalMax, ownerMax];
   const counts = rows.map((s, i) => {
     const d = s.data();
     if (d && (!Number.isSafeInteger(d.windowStart) || d.windowStart < 0 || d.windowStart % 60000 !== 0 || d.windowStart > start || !Number.isInteger(d.count) || d.count < 0 || d.count > limits[i])) throw new HttpsError("failed-precondition", "Review photo limits require recovery.");
     return d?.windowStart === start ? d.count : 0;
   });
   if (counts.some((n, i) => n >= limits[i])) throw new HttpsError("resource-exhausted", "Wait before managing more review photos.");
   tx.set(g, { windowStart: start, count: counts[0] + 1 }); tx.set(o, { windowStart: start, count: counts[1] + 1 });
 });
}
export function buildReviewPhotoCallables(deps: PhotoRpcDependencies, appCheckPolicy: boolean | Expression<boolean>) {
 const handler = (op: Operation) => async (request: CallableRequest<unknown>) => {
   if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Sign in required.");
   const actor = identity(request.auth.uid);
   const enabled = deps.enabled() === true;
   if (deps.appCheckApproved() !== true || (!enabled && (op === "create" || op === "upload"))) throw new HttpsError("failed-precondition", "Review photo uploads are not available yet.");
   if (!request.app?.appId || request.app.alreadyConsumed !== false) throw new HttpsError("unauthenticated", "Review photo verification is required. Retry from the app.");
   const d = payload(op, request.data);
   await activeSession(deps, request, actor);
   try {
     await charge(deps, actor, op);
     const db = deps.db();
     if (!enabled && op === "publish") {
       const status = await readPhotoDraftStatus(db, actor, d.draftId, deps.now);
       if (status.state !== "linked" || !["pending", "complete"].includes(status.photoActivationState)) throw new HttpsError("failed-precondition", "New review photo publication is paused.");
     }
     if (op === "status") return await readPhotoDraftStatus(db, actor, d.draftId, deps.now);
     const bucket = deps.bucket(), expected = deps.expectedBucket();
     if (!expected || expected.trim() !== expected || bucket.name !== expected) throw new HttpsError("failed-precondition", "Review photo storage is unavailable.");
     if (op === "create") {
       await createPhotoDraft(db, actor, d.draftId, d.productId, d.reviewId, d.assetIds, deps.now);
       return await readPhotoDraftStatus(db, actor, d.draftId, deps.now);
     }
     if (op === "upload") {
       await uploadPhotoRequest(db, bucket, expected, { auth: { uid: actor }, data: d }, deps.now);
       return { draftId: d.draftId as string, assetId: d.assetId as string, state: "uploaded" };
     }
     if (op === "publish") return await publishPhotoRequest(db, bucket, expected, { auth: { uid: actor }, data: d }, deps.now);
     const pass = await cleanupPhotoDraftObjects(db, bucket, expected, actor, d.draftId, d.abandon, deps.now);
     const status = await readPhotoDraftStatus(db, actor, d.draftId, deps.now);
     return { ...status, cleanupClaimed: pass.claimed, deletedCount: pass.deletedPaths.length, observedAbsentCount: pass.observedAbsentPaths.length,
       retryCount: pass.retryPaths.length, recoveryRequired: pass.recoveryRequired || status.recoveryRequired };
   } catch (error) {
     if (error instanceof HttpsError) throw error;
     throw new HttpsError("unavailable", "Review photos could not be confirmed. Retry from the app.");
   }
 };
 const options = { ...PHOTO_RPC_OPTIONS, enforceAppCheck: appCheckPolicy, consumeAppCheckToken: appCheckPolicy };
 return {
   createReviewPhotoDraft: onCall(options, handler("create")), uploadReviewPhotoAsset: onCall(options, handler("upload")),
   publishReviewPhotoDraft: onCall(options, handler("publish")), getReviewPhotoDraftStatus: onCall(options, handler("status")),
   cleanupReviewPhotoDraft: onCall(options, handler("cleanup")),
 };
}
export const { createReviewPhotoDraft, uploadReviewPhotoAsset, publishReviewPhotoDraft, getReviewPhotoDraftStatus, cleanupReviewPhotoDraft } = buildReviewPhotoCallables({
 db: () => admin.firestore(), bucket: () => admin.storage().bucket(), expectedBucket: () => admin.storage().bucket().name,
 enabled: () => FLOW_ENABLED.value(), appCheckApproved: () => APPCHECK_APPROVED.value(), now: Date.now,
 user: uid => admin.auth().getUser(uid),
}, APPCHECK_APPROVED);
