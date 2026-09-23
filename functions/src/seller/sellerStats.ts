// ============================================================
//  SELLER-HOME-1a — seller_stats_daily rollup (ADR §12.2, gap 11)
// ============================================================
//
// One document per seller per Indian calendar day:
//   seller_stats_daily/{sellerId}_{yyyyMMdd}
//   { sellerId, day, orders, cancelled, delivered, gross, units, b2bGross, updatedAt }
// An order counts on the IST day it was CREATED. Cancelled/rejected orders
// count in `orders` and `cancelled` but add nothing to gross or units.
//
// Idempotency: Firestore triggers are at-least-once. Every applied order
// leaves a private marker seller_stats_contrib/{orderId} holding exactly what
// it last added. Each write applies (new − marker) inside one transaction and
// replaces the marker, so a retried or duplicate event applies zero.
//
// Existing orders predate the trigger: rebuildMySellerStats recomputes a
// seller's days from their orders (absolute writes, not increments).

import * as functions from "firebase-functions/v1";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

const IST_OFFSET_MS = 330 * 60 * 1000;
const CANCELLED = new Set(["cancelled", "canceled", "rejected", "refunded"]);
const DELIVERED = new Set(["delivered", "completed"]);
export const REBUILD_COOLDOWN_MS = 10 * 60 * 1000;
const BATCH_LIMIT = 400;

export interface Contribution {
  sellerId: string;
  day: string;
  orders: number;
  cancelled: number;
  delivered: number;
  gross: number;
  units: number;
  b2bGross: number;
}

const METRICS = ["orders", "cancelled", "delivered", "gross", "units", "b2bGross"] as const;

/** yyyyMMdd of the Indian calendar day containing [ms]. */
export function istDay(ms: number): string {
  const d = new Date(ms + IST_OFFSET_MS);
  const mm = String(d.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(d.getUTCDate()).padStart(2, "0");
  return `${d.getUTCFullYear()}${mm}${dd}`;
}

function toMillis(v: unknown): number | null {
  if (v instanceof admin.firestore.Timestamp) return v.toMillis();
  if (v instanceof Date) return v.getTime();
  return null;
}

const money = (v: unknown) => (typeof v === "number" && Number.isFinite(v) && v > 0 ? v : 0);

/** What one order adds to its seller's day, or null if it adds nothing. */
export function contributionOf(order: Record<string, unknown> | undefined): Contribution | null {
  if (!order) return null;
  const sellerId = typeof order.sellerId === "string" ? order.sellerId : "";
  const created = toMillis(order.createdAt);
  if (!sellerId || created === null) return null;
  const status = String(order.orderStatus ?? order.status ?? "").toLowerCase();
  const day = istDay(created);
  if (CANCELLED.has(status)) {
    return { sellerId, day, orders: 1, cancelled: 1, delivered: 0, gross: 0, units: 0, b2bGross: 0 };
  }
  const gross = money(order.total ?? order.totalAmount);
  const items = Array.isArray(order.items) ? order.items : [];
  const units = items.reduce((n: number, it: unknown) => {
    const q = (it as { quantity?: unknown })?.quantity;
    return n + (typeof q === "number" && Number.isFinite(q) && q > 0 ? q : 0);
  }, 0);
  return {
    sellerId,
    day,
    orders: 1,
    cancelled: 0,
    delivered: DELIVERED.has(status) ? 1 : 0,
    gross,
    units,
    b2bGross: typeof order.rfqId === "string" && order.rfqId ? gross : 0,
  };
}

const statsRef = (db: admin.firestore.Firestore, sellerId: string, day: string) =>
  db.collection("seller_stats_daily").doc(`${sellerId}_${day}`);

function sameContribution(a: Contribution | null, b: Contribution | null): boolean {
  if (a === null || b === null) return a === b;
  return a.sellerId === b.sellerId && a.day === b.day && METRICS.every((m) => a[m] === b[m]);
}

/** Applies (new − previously applied) for one order. Exported for tests. */
export async function applyOrderContribution(
  db: admin.firestore.Firestore,
  orderId: string,
  after: Record<string, unknown> | undefined
): Promise<void> {
  const next = contributionOf(after);
  const markerRef = db.collection("seller_stats_contrib").doc(orderId);
  await db.runTransaction(async (tx) => {
    const marker = await tx.get(markerRef);
    const prev = marker.exists ? ((marker.data() as { c?: Contribution }).c ?? null) : null;
    if (sameContribution(prev, next)) return;
    const inc = admin.firestore.FieldValue.increment;
    const now = admin.firestore.FieldValue.serverTimestamp();
    const write = (c: Contribution, sign: 1 | -1) => {
      const data: Record<string, unknown> = { sellerId: c.sellerId, day: c.day, updatedAt: now };
      for (const m of METRICS) data[m] = inc(sign * c[m]);
      tx.set(statsRef(db, c.sellerId, c.day), data, { merge: true });
    };
    if (prev && next && prev.sellerId === next.sellerId && prev.day === next.day) {
      // Same day: one write with the difference.
      const data: Record<string, unknown> = { sellerId: next.sellerId, day: next.day, updatedAt: now };
      for (const m of METRICS) data[m] = inc(next[m] - prev[m]);
      tx.set(statsRef(db, next.sellerId, next.day), data, { merge: true });
    } else {
      if (prev) write(prev, -1);
      if (next) write(next, 1);
    }
    if (next) tx.set(markerRef, { c: next, updatedAt: now });
    else tx.delete(markerRef);
  });
}

export const rollupSellerStats = functions.firestore
  .document("orders/{orderId}")
  .onWrite(async (change, context) => {
    const after = change.after.exists ? change.after.data() : undefined;
    await applyOrderContribution(admin.firestore(), context.params.orderId, after);
  });

/**
 * Recompute the caller's own seller_stats_daily from their orders. Absolute
 * values, so it is safe to run again; limited to once per REBUILD_COOLDOWN_MS.
 */
export const rebuildMySellerStats = onCall({ minInstances: 0, memory: "512MiB", timeoutSeconds: 300 }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required");
  const uid = request.auth.uid;
  const db = admin.firestore();

  const seller = await db.collection("sellers").doc(uid).get();
  if (!seller.exists || seller.data()?.status !== "approved") {
    throw new HttpsError("permission-denied", "Only an approved seller can rebuild their stats");
  }
  const last = seller.data()?.statsRebuiltAt;
  if (last instanceof admin.firestore.Timestamp && Date.now() - last.toMillis() < REBUILD_COOLDOWN_MS) {
    throw new HttpsError("resource-exhausted", "Stats were rebuilt a few minutes ago");
  }

  const orders = await db.collection("orders").where("sellerId", "==", uid).get();
  const days = new Map<string, Contribution>();
  const markers: [string, Contribution][] = [];
  for (const doc of orders.docs) {
    const c = contributionOf(doc.data());
    if (!c || c.sellerId !== uid) continue;
    markers.push([doc.id, c]);
    const acc = days.get(c.day) ?? { ...c, orders: 0, cancelled: 0, delivered: 0, gross: 0, units: 0, b2bGross: 0 };
    for (const m of METRICS) acc[m] += c[m];
    days.set(c.day, acc);
  }

  // Days that exist but no longer have any order are zeroed, not left stale.
  const existing = await db.collection("seller_stats_daily").where("sellerId", "==", uid).get();
  const now = admin.firestore.FieldValue.serverTimestamp();
  const writes: ((b: admin.firestore.WriteBatch) => void)[] = [];
  for (const doc of existing.docs) {
    const day = String(doc.data().day ?? "");
    if (!days.has(day)) {
      writes.push((b) => b.set(doc.ref, { sellerId: uid, day, orders: 0, cancelled: 0, delivered: 0, gross: 0, units: 0, b2bGross: 0, updatedAt: now }));
    }
  }
  for (const [day, c] of days) {
    const data: Record<string, unknown> = { sellerId: uid, day, updatedAt: now };
    for (const m of METRICS) data[m] = c[m];
    writes.push((b) => b.set(statsRef(db, uid, day), data));
  }
  for (const [orderId, c] of markers) {
    writes.push((b) => b.set(db.collection("seller_stats_contrib").doc(orderId), { c, updatedAt: now }));
  }
  for (let i = 0; i < writes.length; i += BATCH_LIMIT) {
    const batch = db.batch();
    for (const w of writes.slice(i, i + BATCH_LIMIT)) w(batch);
    await batch.commit();
  }
  await seller.ref.update({ statsRebuiltAt: now });
  return { success: true, orders: markers.length, days: days.size };
});
