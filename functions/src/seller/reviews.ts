// ============================================================
//  SELLER-ACCOUNT-1a — review trust: server ratings, verified purchase, seller replies
// ============================================================
//
// products/{productId}/reviews/{reviewId} is written by buyers (several
// client paths). Before this phase:
//   * reviewStats, products.rating/reviewCount were computed CLIENT-side —
//     and the rules (admin-only) rejected those writes, so ratings never moved;
//   * isVerifiedPurchase was whatever the client sent;
//   * sellers had no way to reply.
// Now one trigger recomputes every aggregate and stamps the server truth on
// the review; replies go through a callable that checks product ownership.

import * as functions from "firebase-functions/v1";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

const DELIVERED = new Set(["delivered", "completed"]);
export const REPLY_MAX = 500;
export const REPLY_EDIT_WINDOW_MS = 24 * 60 * 60 * 1000;
const ORDER_SCAN_LIMIT = 200;

type Dist = Record<"1" | "2" | "3" | "4" | "5", number>;

/** Aggregate of a product's reviews; ratings outside 1–5 are ignored. */
export function summarise(ratings: unknown[]): { average: number; total: number; distribution: Dist } {
  const distribution: Dist = { "1": 0, "2": 0, "3": 0, "4": 0, "5": 0 };
  let sum = 0;
  let total = 0;
  for (const r of ratings) {
    if (typeof r !== "number" || !Number.isFinite(r)) continue;
    const star = Math.round(r);
    if (star < 1 || star > 5) continue;
    distribution[String(star) as keyof Dist]++;
    sum += star;
    total++;
  }
  const average = total === 0 ? 0 : Math.round((sum / total) * 10) / 10;
  return { average, total, distribution };
}

/** Did [userId] receive [productId] in a delivered order? */
export async function hasDeliveredPurchase(db: admin.firestore.Firestore, userId: string, productId: string): Promise<boolean> {
  if (!userId) return false;
  const orders = await db.collection("orders").where("userId", "==", userId).limit(ORDER_SCAN_LIMIT).get();
  return orders.docs.some((d) => {
    const o = d.data();
    const status = String(o.orderStatus ?? o.status ?? "").toLowerCase();
    if (!DELIVERED.has(status)) return false;
    const items = Array.isArray(o.items) ? o.items : [];
    return items.some((it: { productId?: unknown }) => it?.productId === productId);
  });
}

/** Recompute everything derived from one product's reviews. Exported for tests. */
export async function refreshProductReviews(
  db: admin.firestore.Firestore,
  productId: string,
  changedReviewId: string | null
): Promise<void> {
  const productRef = db.collection("products").doc(productId);
  const [productSnap, reviewsSnap] = await Promise.all([productRef.get(), productRef.collection("reviews").get()]);
  const product = productSnap.data() ?? {};
  const sellerId = typeof product.sellerId === "string" ? product.sellerId : "";
  const productName = typeof product.name === "string" ? product.name : "";
  const s = summarise(reviewsSnap.docs.map((d) => d.data().rating));
  const now = admin.firestore.FieldValue.serverTimestamp();

  const batch = db.batch();
  batch.set(productRef.collection("reviewStats").doc("stats"), {
    averageRating: s.average,
    totalReviews: s.total,
    fiveStarCount: s.distribution["5"],
    fourStarCount: s.distribution["4"],
    threeStarCount: s.distribution["3"],
    twoStarCount: s.distribution["2"],
    oneStarCount: s.distribution["1"],
    ratingDistribution: s.distribution,
    updatedAt: now,
  });
  if (productSnap.exists) batch.update(productRef, { rating: s.average, reviewCount: s.total });

  // Server truth on the changed review: who sells it, and whether the
  // reviewer really bought it. Written only when different, so this
  // trigger's own write does not loop.
  if (changedReviewId) {
    const review = reviewsSnap.docs.find((d) => d.id === changedReviewId);
    if (review) {
      const r = review.data();
      const verified = await hasDeliveredPurchase(db, String(r.userId ?? ""), productId);
      const patch: Record<string, unknown> = {};
      if (r.isVerifiedPurchase !== verified) patch.isVerifiedPurchase = verified;
      if (sellerId && r.sellerId !== sellerId) patch.sellerId = sellerId;
      if (productName && r.productName !== productName) patch.productName = productName;
      if (Object.keys(patch).length > 0) batch.update(review.ref, patch);
    }
  }
  await batch.commit();

  if (sellerId) await refreshSellerRating(db, sellerId);
}

/** Seller rating = review-weighted average over the seller's products. */
export async function refreshSellerRating(db: admin.firestore.Firestore, sellerId: string): Promise<void> {
  const products = await db.collection("products").where("sellerId", "==", sellerId).get();
  let weighted = 0;
  let count = 0;
  for (const d of products.docs) {
    const p = d.data();
    const n = typeof p.reviewCount === "number" ? p.reviewCount : 0;
    const r = typeof p.rating === "number" ? p.rating : 0;
    if (n > 0) {
      weighted += r * n;
      count += n;
    }
  }
  const sellerRef = db.collection("sellers").doc(sellerId);
  const seller = await sellerRef.get();
  if (!seller.exists) return;
  await sellerRef.update({
    rating: count === 0 ? 0 : Math.round((weighted / count) * 10) / 10,
    reviewCount: count,
  });
}

/** Fields the trigger itself writes on a review — a change touching only
 * these is our own write and needs no recompute. */
const SERVER_REVIEW_FIELDS = new Set(["isVerifiedPurchase", "sellerId", "productName", "sellerReply"]);

function onlyServerFieldsChanged(before: Record<string, unknown> | undefined, after: Record<string, unknown> | undefined): boolean {
  if (!before || !after) return false;
  const keys = new Set([...Object.keys(before), ...Object.keys(after)]);
  for (const k of keys) {
    if (SERVER_REVIEW_FIELDS.has(k)) continue;
    if (JSON.stringify(before[k]) !== JSON.stringify(after[k])) return false;
  }
  return true;
}

export const onProductReviewWrite = functions.firestore
  .document("products/{productId}/reviews/{reviewId}")
  .onWrite(async (change, context) => {
    const before = change.before.exists ? change.before.data() : undefined;
    const after = change.after.exists ? change.after.data() : undefined;
    if (onlyServerFieldsChanged(before, after)) return null;
    await refreshProductReviews(admin.firestore(), context.params.productId, after ? context.params.reviewId : null);
    return null;
  });

interface ReplyData {
  productId?: string;
  reviewId?: string;
  text?: string;
}

/** One public reply per review by the product's seller, editable for 24 h. */
export const replyToReview = onCall({ minInstances: 0, memory: "256MiB" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required");
  const uid = request.auth.uid;
  const data = request.data as ReplyData;
  if (typeof data?.productId !== "string" || !data.productId || typeof data?.reviewId !== "string" || !data.reviewId) {
    throw new HttpsError("invalid-argument", "productId and reviewId are required");
  }
  const text = typeof data.text === "string" ? data.text.trim() : "";
  if (!text || text.length > REPLY_MAX) {
    throw new HttpsError("invalid-argument", `Reply must be 1–${REPLY_MAX} characters`);
  }
  const db = admin.firestore();
  const productRef = db.collection("products").doc(data.productId);
  const reviewRef = productRef.collection("reviews").doc(data.reviewId);

  await db.runTransaction(async (tx) => {
    const [product, review] = await Promise.all([tx.get(productRef), tx.get(reviewRef)]);
    if (!product.exists || !review.exists) throw new HttpsError("not-found", "Review not found");
    if (product.data()?.sellerId !== uid) {
      throw new HttpsError("permission-denied", "Only the seller of this product can reply");
    }
    const existing = review.data()?.sellerReply as { at?: admin.firestore.Timestamp } | undefined;
    const now = admin.firestore.Timestamp.now();
    if (existing?.at && now.toMillis() - existing.at.toMillis() > REPLY_EDIT_WINDOW_MS) {
      throw new HttpsError("failed-precondition", "Replies can be edited for 24 hours only");
    }
    tx.update(reviewRef, {
      sellerReply: existing?.at ? { text, at: existing.at, editedAt: now } : { text, at: now, editedAt: null },
    });
  });
  return { success: true };
});
