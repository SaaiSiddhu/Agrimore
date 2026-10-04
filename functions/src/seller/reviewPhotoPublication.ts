// Internal trusted request boundary. NOT index-exported or an enabled Cloud Function.
import * as admin from "firebase-admin";
import type { Bucket, FileMetadata } from "@google-cloud/storage";
import { createHash } from "crypto";
import { HttpsError } from "firebase-functions/v2/https";
import { MAX_PHOTO_BYTES } from "./reviewPhotoImage";
import { freezePhotoContent, inspectPhotoPublication, preparePhotoAccessPlan, publishPhotoDraft,
 inspectPhotoActivation, finishPhotoActivation, PhotoUploadBinding, PhotoAccessAsset } from "./reviewPhotoDraftCore";
function retry(): never { throw new HttpsError("unavailable", "Photo publication could not be confirmed. Retry this submission."); }
function refuse(): never { throw new HttpsError("failed-precondition", "Photo publication requires recovery."); }
function metadata(meta: FileMetadata, bucket: string, asset: PhotoUploadBinding): { size: number; metageneration: string } {
 const size = Number(meta?.size);
 if (!meta || meta.name !== asset.path || meta.bucket !== bucket || meta.contentType !== "image/jpeg" || meta.generation !== asset.generation ||
   typeof meta.metageneration !== "string" || !/^[1-9]\d*$/.test(meta.metageneration) || !Number.isSafeInteger(size) || size <= 0 || size > MAX_PHOTO_BYTES ||
   meta.metadata?.reviewPhotoInputDigest !== asset.inputDigest || meta.metadata?.reviewPhotoNormalizedDigest !== asset.normalizedDigest) refuse();
 return { size, metageneration: meta.metageneration };
}
function capability(meta: FileMetadata, asset: PhotoAccessAsset): "private" | "active" {
 if (!Object.prototype.hasOwnProperty.call(meta.metadata || {}, "firebaseStorageDownloadTokens")) return "private";
 if (meta.metadata?.firebaseStorageDownloadTokens !== asset.capability) refuse();
 return "active";
}
async function privateBytes(bucket: Bucket, expected: string, asset: PhotoUploadBinding) {
 const [m] = await bucket.file(asset.path).getMetadata(), { size } = metadata(m, expected, asset);
 if (Object.prototype.hasOwnProperty.call(m.metadata || {}, "firebaseStorageDownloadTokens")) refuse();
 const [bytes] = await bucket.file(asset.path, { generation: asset.generation }).download({ start: 0, end: size - 1, validation: false });
 if (bytes.length !== size || createHash("sha256").update(bytes).digest("hex") !== asset.normalizedDigest) refuse();
 const [again] = await bucket.file(asset.path).getMetadata();
 metadata(again, expected, asset);
 if (again.metageneration !== m.metageneration || Object.prototype.hasOwnProperty.call(again.metadata || {}, "firebaseStorageDownloadTokens")) refuse();
}
async function activeObject(bucket: Bucket, expected: string, asset: PhotoAccessAsset) {
 const [m] = await bucket.file(asset.path).getMetadata();
 metadata(m, expected, asset);
 if (capability(m, asset) !== "active") retry();
}
export async function publishPhotoRequest(db: admin.firestore.Firestore, bucket: Bucket, expectedBucket: string,
 request: { auth?: { uid: string }; data: unknown }, now: () => number = Date.now) {
 if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Sign in required.");
 const data = request.data;
 if (!data || typeof data !== "object" || Array.isArray(data) || Object.keys(data).sort().join(",") !== "comment,draftId,rating,title") throw new HttpsError("invalid-argument", "Invalid photo publication request.");
 if (!expectedBucket || expectedBucket.trim() !== expectedBucket || bucket.name !== expectedBucket) refuse();
 const { draftId, rating, title, comment } = data as Record<string, unknown>;
 if (typeof draftId !== "string" || typeof rating !== "number" || typeof title !== "string" || typeof comment !== "string") throw new HttpsError("invalid-argument", "Invalid photo publication request.");
 try {
   const actor = request.auth.uid, initial = await inspectPhotoPublication(db, actor, draftId, now);
   let profile = initial.content;
   if (!profile) {
     const user = (await db.collection("users").doc(actor).get()).data();
     if (!user || typeof user.name !== "string" || (user.photoUrl != null && typeof user.photoUrl !== "string")) refuse();
     profile = { rating, title, comment, userName: user.name, userAvatar: user.photoUrl ?? "" };
   }
   const content = await freezePhotoContent(db, actor, draftId, { ...profile, rating, title, comment }, now);
   let plan = initial.plan;
   if (initial.state !== "linked") for (const asset of initial.uploads) await privateBytes(bucket, expectedBucket, asset);
   if (!plan) {
     plan = await preparePhotoAccessPlan(db, actor, draftId, expectedBucket, initial.uploads, now);
   }
   if (plan.bucket !== expectedBucket) refuse();
   const linked = await publishPhotoDraft(db, actor, draftId, content, now);
   if (!linked.stillCurrent) return { ...linked, photoActivationState: "superseded" as const };
   // A durable completed receipt needs no Storage mutation, even after subsequent author edits.
   const current = await inspectPhotoPublication(db, actor, draftId, now);
   if (current.activation === "complete") {
     await inspectPhotoActivation(db, actor, draftId, expectedBucket);
     return { ...linked, photoActivationState: "complete" as const };
   }
   for (const asset of plan.assets) {
     const checked = await inspectPhotoActivation(db, actor, draftId, expectedBucket);
     if (JSON.stringify(checked.plan) !== JSON.stringify(plan)) refuse();
     const [m] = await bucket.file(asset.path).getMetadata(), { metageneration } = metadata(m, expectedBucket, asset);
     if (capability(m, asset) === "active") continue;
     // Another request may have completed and released the client lock. Never reissue then.
     if (checked.state !== "pending") retry();
     await inspectPhotoActivation(db, actor, draftId, expectedBucket);
     try {
       // Patch the CURRENT object, not an archived generation; conditions guard the current version atomically in GCS.
       await bucket.file(asset.path, { preconditionOpts: { ifGenerationMatch: asset.generation, ifMetagenerationMatch: metageneration } }).setMetadata({
         metadata: { ...m.metadata, firebaseStorageDownloadTokens: asset.capability },
       }, { ifGenerationMatch: asset.generation, ifMetagenerationMatch: metageneration });
     } catch { /* Unknown response: the same immutable capability may already be active. */ }
     await activeObject(bucket, expectedBucket, asset);
   }
   // Recheck ALL objects before releasing both locks, including earlier partial activations.
   for (const asset of plan.assets) await activeObject(bucket, expectedBucket, asset);
   await finishPhotoActivation(db, actor, draftId, expectedBucket, plan.assets.map(({ path, generation, url }) => ({ path, generation, url })), now);
   return { ...linked, photoActivationState: "complete" as const };
 } catch (error) {
   if (error instanceof HttpsError) throw error;
   retry();
 }
}
