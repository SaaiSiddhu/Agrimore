// Preparatory trusted-server core, NOT a public callable. Object metadata and
// generation verification, quotas, rules and client adoption are still required.
import * as admin from "firebase-admin";
import { HttpsError } from "firebase-functions/v2/https";
import { createHash } from "crypto";
type Db = admin.firestore.Firestore;
type Data = Record<string, any>;
export type PhotoReceipt = { path: string; url: string; generation: string };
export type ReviewPhotoContent = { rating: number; title: string; comment: string; userName: string; userAvatar: string };
const COLL = "review_photo_drafts", TTL = 30 * 60 * 1000, MAX = 10;
function fail(code: "invalid-argument" | "failed-precondition" | "permission-denied" | "already-exists" | "not-found" | "deadline-exceeded", message: string): never { throw new HttpsError(code, message); }
function id(v: string) { if (typeof v !== "string" || !v || v.trim() !== v || v.includes("/")) fail("invalid-argument", "Invalid draft identity."); return v; }
function clock(now: number) { if (!Number.isSafeInteger(now) || now < 0 || !Number.isSafeInteger(now + TTL)) fail("invalid-argument", "Invalid draft clock."); }
function instant(source: number | (() => number)): number { const now = typeof source === "function" ? source() : source; clock(now); return now; }
function owned(s: admin.firestore.DocumentSnapshot, actor: string): Data {
 const d = s.data(); if (!d || d.owner !== actor) fail("permission-denied", "Photo draft unavailable.");
 id(d.productId); id(d.reviewId);
 const prefix = `review_drafts/${actor}/${s.id}/`;
 if (!Number.isSafeInteger(d.createdAt) || d.createdAt < 0 || !Number.isSafeInteger(d.expiresAt) || d.expiresAt !== d.createdAt + TTL ||
   !["open", "ready", "linked", "cleanup"].includes(d.state) || !Array.isArray(d.paths) || !d.paths.length || d.paths.length > MAX ||
   d.paths.some((p: unknown) => typeof p !== "string" || !p.startsWith(prefix) || p.slice(prefix.length).includes("/") || !p.endsWith(".jpg")) || new Set(d.paths).size !== d.paths.length) fail("failed-precondition", "Invalid draft record.");
 return d;
}
function editable(r: admin.firestore.DocumentSnapshot, actor: string, product: string, review: string) {
 const v = r.data(); if (r.exists ? (!v || v.userId !== actor || v.productId !== product || v.supersededBy != null) : review !== actor) fail("permission-denied", "Review unavailable for this owner.");
}
function validReceipts(d: Data, receipts: readonly PhotoReceipt[]) {
 return Array.isArray(receipts) && receipts.length === d.paths.length && receipts.every((r, i) => r != null && r.path === d.paths[i] && typeof r.url === "string" && r.url.startsWith("https://") && typeof r.generation === "string" && /^[1-9]\d*$/.test(r.generation));
}
export async function createPhotoDraft(db: Db, actor: string, draft: string, product: string, review: string, assets: readonly string[], now: number | (() => number) = Date.now) {
 id(actor); id(draft); id(product); id(review); instant(now);
 if (!Array.isArray(assets) || !assets.length || assets.length > MAX || new Set(assets).size !== assets.length) fail("invalid-argument", "Invalid photo batch.");
 const paths = assets.map(a => `review_drafts/${actor}/${draft}/${id(a)}.jpg`), ref = db.collection(COLL).doc(draft);
 await db.runTransaction(async tx => {
   let at = instant(now);
   const [s, p, r] = await Promise.all([tx.get(ref), tx.get(db.collection("products").doc(product)), tx.get(db.collection("products").doc(product).collection("reviews").doc(review))]);
   at = instant(now);
   if (!p.exists) fail("not-found", "Product unavailable.");
   if (s.exists) { const d = owned(s, actor); if (d.productId !== product || d.reviewId !== review || JSON.stringify(d.paths) !== JSON.stringify(paths)) fail("already-exists", "Draft identity already used."); return; }
   editable(r, actor, product, review);
   tx.create(ref, { owner: actor, productId: product, reviewId: review, paths, state: "open", createdAt: at, expiresAt: at + TTL });
 });
 return paths;
}
export async function readyPhotoDraft(db: Db, actor: string, draft: string, verified: readonly PhotoReceipt[], now: number | (() => number) = Date.now) {
 id(actor); id(draft); instant(now);
 if (!Array.isArray(verified)) fail("invalid-argument", "Invalid photo receipts.");
 const receipts = verified.map(r => ({ path: r?.path, url: r?.url, generation: r?.generation }));
 await db.runTransaction(async tx => {
   let at = instant(now);
   const ref = db.collection(COLL).doc(draft), s = await tx.get(ref), d = owned(s, actor);
   at = instant(now);
   if (d.state !== "open" && d.state !== "ready") fail("failed-precondition", "Photo draft closed.");
   if (at >= d.expiresAt) fail("deadline-exceeded", "Photo draft expired.");
   if (!validReceipts(d, receipts)) fail("invalid-argument", "Photo receipts do not match draft.");
   if (d.state === "ready") { if (JSON.stringify(d.receipts) !== JSON.stringify(receipts)) fail("already-exists", "Photo receipts immutable."); return; }
   tx.update(ref, { state: "ready", receipts });
 });
}
export async function publishPhotoDraft(db: Db, actor: string, draft: string, value: ReviewPhotoContent, now: number | (() => number) = Date.now) {
 id(actor); id(draft); instant(now);
 if (value == null || typeof value !== "object") fail("invalid-argument", "Invalid review content.");
 const content = { rating: value.rating, title: value.title, comment: value.comment, userName: value.userName, userAvatar: value.userAvatar };
 if (!Number.isInteger(content.rating) || content.rating < 1 || content.rating > 5 || [content.title, content.comment, content.userName, content.userAvatar].some(v => typeof v !== "string") || content.title.length > 200 || content.comment.length > 10000 || content.userName.length > 200 || content.userAvatar.length > 4096) fail("invalid-argument", "Invalid review content.");
 const hash = createHash("sha256").update(JSON.stringify(content)).digest("hex");
 return db.runTransaction(async tx => {
   let at = instant(now);
   const dr = db.collection(COLL).doc(draft), s = await tx.get(dr), d = owned(s, actor);
   const ref = db.collection("products").doc(d.productId).collection("reviews").doc(d.reviewId), r = await tx.get(ref);
   if (d.state === "linked") { if (d.contentHash !== hash) fail("already-exists", "Draft published with different content."); const current = r.data(); return { state: "linked", reviewId: d.reviewId, stillCurrent: current?.photoDraftId === draft && Array.isArray(current.imageUrls) && Array.isArray(d.receipts) && d.receipts.every((v: PhotoReceipt) => current.imageUrls.includes(v.url)) }; }
   at = instant(now);
   // Load-bearing cleanup tombstone: no late publication after deletion claim.
   if (d.state !== "ready") fail("failed-precondition", "Draft not ready for publication.");
   if (at >= d.expiresAt) fail("deadline-exceeded", "Photo draft expired.");
   editable(r, actor, d.productId, d.reviewId);
   if (!validReceipts(d, d.receipts)) fail("failed-precondition", "Invalid photo receipts.");
   const previous = r.data();
   const old = previous && Object.prototype.hasOwnProperty.call(previous, "imageUrls") ? previous.imageUrls : [];
   if (!Array.isArray(old) || old.some((v: unknown) => typeof v !== "string")) fail("failed-precondition", "Invalid existing photos.");
   const imageUrls = [...new Set([...d.receipts.map((v: PhotoReceipt) => v.url), ...old])];
   tx.set(ref, { ...content, userId: actor, productId: d.productId, imageUrls, photoDraftId: draft, updatedAt: admin.firestore.Timestamp.fromMillis(at), ...(!r.exists ? { createdAt: admin.firestore.Timestamp.fromMillis(at) } : {}) }, { merge: true });
   tx.update(dr, { state: "linked", contentHash: hash, linkedAt: at });
   return { state: "linked", reviewId: d.reviewId, stillCurrent: true };
 });
}
export async function claimPhotoCleanup(db: Db, actor: string, draft: string, abandon: boolean, now: number | (() => number) = Date.now) {
 id(actor); id(draft); instant(now);
 if (typeof abandon !== "boolean") fail("invalid-argument", "Invalid cleanup intent.");
 return db.runTransaction(async tx => {
   let at = instant(now);
   const ref = db.collection(COLL).doc(draft), s = await tx.get(ref), d = owned(s, actor);
   if (d.state === "linked") return { claimed: false, paths: [] as string[] };
   if (d.state === "cleanup") return { claimed: true, paths: [...d.paths] as string[] };
   if (d.state !== "open" && d.state !== "ready") fail("failed-precondition", "Invalid draft state.");
   at = instant(now);
   if (!abandon && at < d.expiresAt) fail("failed-precondition", "Photo draft still active.");
   tx.update(ref, { state: "cleanup", cleanupClaimedAt: at });
   return { claimed: true, paths: [...d.paths] as string[] };
 });
}

/** Trusted-only read boundary; does not grant client collection access. */
export async function inspectPhotoDraft(db: Db, actor: string, draft: string, now: () => number = Date.now) {
 id(actor); id(draft); instant(now);
 const d = owned(await db.collection(COLL).doc(draft).get(), actor);
 if (d.state !== "open" && d.state !== "ready") fail("failed-precondition", "Photo draft closed.");
 if (instant(now) >= d.expiresAt) fail("deadline-exceeded", "Photo draft expired.");
 return { paths: [...d.paths] as string[], expiresAt: d.expiresAt as number, state: d.state as string };
}

/** Trusted cleanup lookup; keep the tombstone indefinitely until recovery policy exists. */
export async function inspectPhotoCleanup(db: Db, actor: string, draft: string, now: () => number = Date.now) {
 id(actor); id(draft); instant(now);
 const d = owned(await db.collection(COLL).doc(draft).get(), actor);
 if (d.state !== "cleanup") fail("failed-precondition", "Photo cleanup not claimed.");
 return { paths: [...d.paths] as string[], expiresAt: d.expiresAt as number, leaseExpired: instant(now) >= d.expiresAt };
}

function openUpload(d: Data, at: number) {
 if (d.state !== "open") fail("failed-precondition", "Photo draft closed for upload.");
 if (at >= d.expiresAt) fail("deadline-exceeded", "Photo draft expired.");
}
function uploadMap(d: Data): Record<string, Data> {
 const all = d.uploads === undefined ? {} : d.uploads;
 if (!all || typeof all !== "object" || Array.isArray(all) || Object.keys(all).length > MAX || Object.entries(all).some(([key, raw]) => {
   const v = raw as Data;
   return !v || typeof v !== "object" || !d.paths.includes(v.path) || key !== createHash("sha256").update(v.path).digest("hex") ||
     !/^[a-f0-9]{64}$/.test(v.inputDigest) || !/^[a-f0-9]{64}$/.test(v.normalizedDigest) || !["bound", "uploaded"].includes(v.state) ||
     (v.state === "uploaded" && (typeof v.generation !== "string" || !/^[1-9]\d*$/.test(v.generation)));
 })) fail("failed-precondition", "Invalid upload bindings.");
 return all;
}
/** Owner quota is charged before expensive decoding, even on same-asset retries. */
export async function chargePhotoUpload(db: Db, actor: string, draft: string, asset: string, now: () => number = Date.now) {
 id(actor); id(draft); id(asset); instant(now);
 if (!/^[A-Za-z0-9_-]{1,128}$/.test(asset) || ["__proto__", "prototype", "constructor"].includes(asset)) fail("invalid-argument", "Invalid asset identity.");
 return db.runTransaction(async tx => {
   const ref = db.collection(COLL).doc(draft), limit = db.collection("review_photo_upload_limits").doc(actor);
   const [s, q] = await Promise.all([tx.get(ref), tx.get(limit)]), d = owned(s, actor), at = instant(now);
   openUpload(d, at);
   const path = `review_drafts/${actor}/${draft}/${asset}.jpg`;
   if (!d.paths.includes(path)) fail("permission-denied", "Asset not leased.");
   const windowStart = Math.floor(at / 60000) * 60000, old = q.data();
   if (old && (!Number.isSafeInteger(old.windowStart) || old.windowStart < 0 || old.windowStart % 60000 !== 0 || old.windowStart > windowStart || !Number.isInteger(old.count) || old.count < 0 || old.count > 20)) fail("failed-precondition", "Invalid upload limit.");
   const count = old?.windowStart === windowStart ? old.count : 0;
   if (count >= 20) throw new HttpsError("resource-exhausted", "Wait before uploading more photos.");
   tx.set(limit, { windowStart, count: count + 1 });
   return path;
 });
}
export async function bindPhotoUpload(db: Db, actor: string, draft: string, path: string, inputDigest: string, normalizedDigest: string, now: () => number = Date.now) {
 id(actor); id(draft); instant(now);
 if (!/^[a-f0-9]{64}$/.test(inputDigest) || !/^[a-f0-9]{64}$/.test(normalizedDigest)) fail("invalid-argument", "Invalid upload binding.");
 await db.runTransaction(async tx => {
   const ref = db.collection(COLL).doc(draft), d = owned(await tx.get(ref), actor); openUpload(d, instant(now));
   if (!d.paths.includes(path)) fail("permission-denied", "Asset not leased.");
   const all = uploadMap(d), key = createHash("sha256").update(path).digest("hex"), old = all[key];
   if (old) { if (old.inputDigest !== inputDigest || old.normalizedDigest !== normalizedDigest) fail("already-exists", "Asset content already bound."); return; }
   tx.update(ref, { uploads: { ...all, [key]: { path, inputDigest, normalizedDigest, state: "bound" } } });
 });
}
export async function confirmPhotoUpload(db: Db, actor: string, draft: string, path: string, normalizedDigest: string, generation: string, now: () => number = Date.now) {
 id(actor); id(draft); instant(now);
 if (typeof generation !== "string" || !/^[1-9]\d*$/.test(generation)) fail("invalid-argument", "Invalid upload generation.");
 await db.runTransaction(async tx => {
   const ref = db.collection(COLL).doc(draft), d = owned(await tx.get(ref), actor); openUpload(d, instant(now));
   const all = uploadMap(d), key = createHash("sha256").update(path).digest("hex"), old = all[key];
   if (!old || old.path !== path || old.normalizedDigest !== normalizedDigest) fail("failed-precondition", "Upload binding unavailable.");
   if (old.state === "uploaded") { if (old.generation !== generation) fail("failed-precondition", "Upload generation changed."); return; }
   tx.update(ref, { uploads: { ...all, [key]: { ...old, state: "uploaded", generation } } });
 });
}
