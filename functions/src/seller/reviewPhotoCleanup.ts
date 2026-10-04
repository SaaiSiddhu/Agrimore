// Preparatory trusted-server cleanup pass. No public callable or automatic reaper.
import * as admin from "firebase-admin";
import type { Bucket } from "@google-cloud/storage";
import { HttpsError } from "firebase-functions/v2/https";
import { claimPhotoCleanup, inspectPhotoCleanup } from "./reviewPhotoDraftCore";

export type PhotoCleanupPass = {
 claimed: boolean; deletedPaths: string[]; observedAbsentPaths: string[];
 retryPaths: string[]; leaseExpired: boolean; recoveryRequired: boolean;
};
/** Only server-configured bucket/clock, no client paths or URL parsing.
 * Even after expiry, absent now does not prove a resumable upload cannot arrive.
 * This pass NEVER marks complete or removes a durable recovery journal/tombstone.
 * Future upload-quiescence proof, immutable Storage rules and client bypass closure
 * are required before enabling cleanup as an authoritative public protocol.
 */
export async function cleanupPhotoDraftObjects(
 db: admin.firestore.Firestore, bucket: Bucket, expectedBucket: string,
 actor: string, draft: string, abandon: boolean, now: () => number = Date.now,
): Promise<PhotoCleanupPass> {
 if (typeof expectedBucket !== "string" || !expectedBucket || expectedBucket.trim() !== expectedBucket || bucket.name !== expectedBucket)
   throw new HttpsError("failed-precondition", "Photo cleanup unavailable.");
 const claim = await claimPhotoCleanup(db, actor, draft, abandon, now);
 if (!claim.claimed) return { claimed: false, deletedPaths: [], observedAbsentPaths: [], retryPaths: [], leaseExpired: false, recoveryRequired: false };
 const lease = await inspectPhotoCleanup(db, actor, draft, now);
 const deletedPaths: string[] = [], observedAbsentPaths: string[] = [], retryPaths: string[] = [];
 for (const path of lease.paths) {
   let phase: "lookup" | "delete" = "lookup";
   try {
     const [meta] = await bucket.file(path).getMetadata();
     if (!meta || meta.name !== path || meta.bucket !== expectedBucket || typeof meta.generation !== "string" || !/^[1-9]\d*$/.test(meta.generation)) {
       retryPaths.push(path); continue;
     }
     phase = "delete";
     // Exact version + explicit precondition: replacement must not be deleted.
     const pinned = bucket.file(path, { generation: meta.generation, preconditionOpts: { ifGenerationMatch: meta.generation } });
     const [checked] = await pinned.getMetadata();
     if (!checked || checked.name !== path || checked.bucket !== expectedBucket || checked.generation !== meta.generation) {
       retryPaths.push(path); continue;
     }
     await pinned.delete();
     deletedPaths.push(path);
   } catch (error: unknown) {
     // A 404 during deletion may be a vanished version with a replacement present.
     // Only lookup absence is an observation; every deletion uncertainty retries.
     if (phase === "lookup" && typeof error === "object" && error !== null && "code" in error && error.code === 404) observedAbsentPaths.push(path);
     else retryPaths.push(path);
   }
 }
 const finalLease = await inspectPhotoCleanup(db, actor, draft, now);
 return { claimed: true, deletedPaths, observedAbsentPaths, retryPaths,
   leaseExpired: finalLease.leaseExpired, recoveryRequired: true };
}
