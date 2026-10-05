// Preparatory request handler. NOT index-exported or a public Cloud Function.
import * as admin from "firebase-admin";
import type { Bucket, FileMetadata } from "@google-cloud/storage";
import { createHash } from "crypto";
import { HttpsError } from "firebase-functions/v2/https";
import { photoInput, normalizePhoto, MAX_PHOTO_BYTES } from "./reviewPhotoImage";
import { chargePhotoUpload, bindPhotoUpload, confirmPhotoUpload } from "./reviewPhotoDraftCore";
function unavailable(): never { throw new HttpsError("failed-precondition", "Photo upload could not be confirmed. Retry this upload."); }
function digest(bytes: Buffer) { return createHash("sha256").update(bytes).digest("hex"); }
function verified(meta: FileMetadata, bucket: string, path: string, source: string, normalized: string, size: number): string {
 if (!meta || meta.name !== path || meta.bucket !== bucket || meta.contentType !== "image/jpeg" || Number(meta.size) !== size || size > MAX_PHOTO_BYTES ||
   typeof meta.generation !== "string" || !/^[1-9]\d*$/.test(meta.generation) || meta.metadata?.reviewPhotoInputDigest !== source || meta.metadata?.reviewPhotoNormalizedDigest !== normalized ||
   Object.prototype.hasOwnProperty.call(meta.metadata || {}, "firebaseStorageDownloadTokens")) unavailable();
 return meta.generation;
}
export async function uploadPhotoRequest(db: admin.firestore.Firestore, bucket: Bucket, expectedBucket: string,
 request: { auth?: { uid: string }; data: unknown }, now: () => number = Date.now) {
 if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Sign in required.");
 const data = request.data;
 if (!data || typeof data !== "object" || Array.isArray(data) || Object.keys(data).sort().join(",") !== "assetId,draftId,imageBase64") throw new HttpsError("invalid-argument", "Invalid photo upload request.");
 if (!expectedBucket || expectedBucket.trim() !== expectedBucket || bucket.name !== expectedBucket) unavailable();
 const { assetId, draftId, imageBase64 } = data as Record<string, unknown>;
 if (typeof assetId !== "string" || typeof draftId !== "string") throw new HttpsError("invalid-argument", "Invalid photo upload request.");
 const input = photoInput(imageBase64), actor = request.auth.uid;
 const path = await chargePhotoUpload(db, actor, draftId, assetId, now);
 const output = normalizePhoto(input), source = digest(input), normalized = digest(output);
 await bindPhotoUpload(db, actor, draftId, path, source, normalized, now);
 const file = bucket.file(path);
 let metadata: FileMetadata | undefined;
 try { [metadata] = await file.getMetadata(); }
 catch (e: unknown) { if (!e || typeof e !== "object" || !("code" in e) || e.code !== 404) unavailable(); }
 if (!metadata) {
   try {
     await bucket.file(path, { preconditionOpts: { ifGenerationMatch: 0 } }).save(output, {
       resumable: false, metadata: { contentType: "image/jpeg", cacheControl: "private, no-store",
         metadata: { reviewPhotoInputDigest: source, reviewPhotoNormalizedDigest: normalized } },
     });
   } catch { /* Could have committed before response failed. Resolve by metadata. */ }
   try { [metadata] = await file.getMetadata(); } catch { unavailable(); }
 }
 const generation = verified(metadata!, expectedBucket, path, source, normalized, output.length);
 try {
   const [pinned] = await bucket.file(path, { generation }).getMetadata();
   if (verified(pinned, expectedBucket, path, source, normalized, output.length) !== generation) unavailable();
   const [bytes] = await bucket.file(path, { generation }).download({ start: 0, end: output.length - 1, validation: false });
   if (bytes.length !== output.length || digest(bytes) !== normalized) unavailable();
 } catch { unavailable(); }
 await confirmPhotoUpload(db, actor, draftId, path, normalized, generation, now);
 // No download URL/token or arbitrary object metadata crosses the boundary.
 return { path, generation, state: "uploaded" as const };
}
