// Preparatory server-only verifier. No public handler, URL issuance or decoding.
import * as admin from "firebase-admin";
import type { Bucket, FileMetadata } from "@google-cloud/storage";
import { HttpsError } from "firebase-functions/v2/https";
import { inspectPhotoDraft } from "./reviewPhotoDraftCore";

export type VerifiedPhotoObject = {
 path: string; generation: string; metageneration: string; size: number; contentType: "image/jpeg";
};
function reject(): never { throw new HttpsError("failed-precondition", "Photo object verification failed."); }
function decimal(v: unknown): string {
 if (typeof v !== "string" || !/^[1-9]\d*$/.test(v)) reject();
 return v;
}
function validate(meta: FileMetadata, path: string, expectedBucket: string): VerifiedPhotoObject {
 if (meta == null || meta.name !== path || meta.bucket !== expectedBucket || meta.contentType !== "image/jpeg") reject();
 const generation = decimal(meta.generation), metageneration = decimal(meta.metageneration);
 const raw = meta.size;
 if (!((typeof raw === "string" && /^[1-9]\d*$/.test(raw)) || (typeof raw === "number" && Number.isSafeInteger(raw)))) reject();
 const size = Number(raw);
 if (!Number.isSafeInteger(size) || size <= 0 || size >= 10 * 1024 * 1024) reject();
 // Drafts must not already contain a download capability. Publication is separate.
 if (meta.metadata && Object.prototype.hasOwnProperty.call(meta.metadata, "firebaseStorageDownloadTokens")) reject();
 return { path, generation, metageneration, size, contentType: "image/jpeg" };
}
/** bucket/expectedBucket/clock come from server configuration, never client input.
 * Metadata validates claimed MIME, not JPEG decoding or create-only Storage rules.
 * readyPhotoDraft must still run after this and enforce state/expiry atomically.
 */
export async function verifyPhotoDraftObjects(
 db: admin.firestore.Firestore, bucket: Bucket, expectedBucket: string,
 actor: string, draft: string, now: () => number = Date.now,
): Promise<VerifiedPhotoObject[]> {
 if (typeof expectedBucket !== "string" || !expectedBucket || expectedBucket.trim() !== expectedBucket || bucket.name !== expectedBucket) reject();
 const lease = await inspectPhotoDraft(db, actor, draft, now);
 const result: VerifiedPhotoObject[] = [];
 for (const path of lease.paths) {
   const [metadata] = await bucket.file(path).getMetadata();
   const verified = validate(metadata, path, expectedBucket);
   // Pin the second read to the exact version; never silently accept replacement.
   const [pinned] = await bucket.file(path, { generation: verified.generation }).getMetadata();
   if (JSON.stringify(validate(pinned, path, expectedBucket)) !== JSON.stringify(verified)) reject();
   result.push(verified);
 }
 const finalLease = await inspectPhotoDraft(db, actor, draft, now);
 if (finalLease.expiresAt !== lease.expiresAt || finalLease.state !== lease.state || JSON.stringify(finalLease.paths) !== JSON.stringify(lease.paths)) reject();
 return result;
}
