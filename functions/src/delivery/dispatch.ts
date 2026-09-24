// ============================================================
//  Delivery dispatch — offer waves (Phase DLV-2A)
// ============================================================
//
// OWNER_DECISIONS 2026-09-23 (references/decisions.md):
//  D-DLV-DISPATCH  offer a packed order to the 3 nearest eligible riders at a
//                  time, 30 s per offer, widening 5 → 8 → 12 km; the first
//                  rider to accept (acceptDeliveryOffer) gets it.
//  D-DLV-NO-TAKER  after the third wave: flag the order for admin AND keep
//                  re-offering every 2 min at 12 km until a rider accepts or
//                  an admin assigns one.
//
// Replaces notifications.ts's notifyDeliveryPartnersForPickup, which offered
// to up to 12 riders at once, never expired, retried or escalated, and fell
// back to the CUSTOMER's address as the pickup point when the seller had no
// location (so "nearest" could mean nearest to the drop).
//
// Server-only documents:
//  delivery_dispatch/{orderId}           wave state (admin-readable)
//  delivery_requests/{orderId}_{riderId} one offer (readable by its rider).
//    Carries NO customer name/phone/address text: pickup distance/area, drop
//    pincode and pickup→drop distance, item count, COD amount only.
//
// Compatibility: the released May-6 rider app ignores offers and still claims
// orders directly (firestore.rules deliveryPartnerCanClaimOrder). The
// scheduler notices any assignment — callable, legacy claim or admin
// assignment — and closes the dispatch.
//
// Every entry point takes `nowMs` so the suite can drive time.

import * as admin from "firebase-admin";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { dropPoint, orderPickupPoint, sellerPickupPoint } from "./syncDeliveryTask";
import { isTerminal, taskStatusFromOrder } from "./states";
import { riderPay, tripKm } from "./riderPay";
import { loadRiderPayRates, ridersAtCashLimit } from "./riderRates";

export const WAVE_RADII_KM = [5, 8, 12] as const;
export const WAVE_SIZE = 3;
export const OFFER_TTL_MS = 30 * 1000;
export const RETRY_INTERVAL_MS = 2 * 60 * 1000;
// DLV-3A: 30 → 5 min. With D-DLV-BG an online rider reports at least every
// minute; a location older than 5 min means the app has stopped sending.
export const LOCATION_FRESHNESS_MS = 5 * 60 * 1000;
/** A wave in progress holds this lease so concurrent callers do not double it. */
export const WAVE_LEASE_MS = 60 * 1000;
export const OFFERS_CHANNEL_ID = "delivery_offers";

/**
 * DLV-INT: whether [order] still holds its rider, by BOTH status fields
 * (taskStatusFromOrder). A query on RIDER_ACTIVE_ORDER_STATUSES matches
 * `orderStatus` only; an order a seller or admin panel finished through
 * `status` alone keeps `orderStatus` behind and would leave the rider busy
 * for good (never offered, refused at accept, never swept, cannot delete).
 * Every such query's results pass through this.
 */
export function holdsRider(order: FirebaseFirestore.DocumentData): boolean {
  const t = taskStatusFromOrder(order);
  return t !== null && t !== "searching" && !isTerminal(t);
}

/** Order statuses in which a rider is carrying (or collecting) an order. */
export const RIDER_ACTIVE_ORDER_STATUSES = [
  "delivery_accepted",
  "arrived_at_store",
  "reached_pickup",
  "picked_up",
  "parcel_picked",
  "out_for_delivery",
  "outfordelivery",
  "outForDelivery",
];

type Point = { lat: number; lng: number };
type Db = FirebaseFirestore.Firestore;

export const dispatchRef = (db: Db, orderId: string) =>
  db.collection("delivery_dispatch").doc(orderId);
export const offerRef = (db: Db, orderId: string, riderId: string) =>
  db.collection("delivery_requests").doc(`${orderId}_${riderId}`);

export function hasPartner(order: FirebaseFirestore.DocumentData): boolean {
  return typeof order.deliveryPartnerId === "string" && order.deliveryPartnerId.length > 0;
}

/**
 * Waiting for a rider: DLV-1A's reading of the two status fields says
 * `searching` — ready_for_pickup in either field, no rider, and NOT
 * overridden by a terminal value in the other field. A seller or admin
 * cancellation writes only `status`, leaving orderStatus at
 * ready_for_pickup; a one-field check kept offering that cancelled order
 * (phaseDLV2A_dispatch_test d21).
 */
export function isReadyForPickup(order: FirebaseFirestore.DocumentData): boolean {
  return taskStatusFromOrder({ ...order, deliveryPartnerId: null }) === "searching";
}

export function distanceKm(a: Point, b: Point): number {
  const r = (d: number) => (d * Math.PI) / 180;
  const dLat = r(b.lat - a.lat);
  const dLng = r(b.lng - a.lng);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(r(a.lat)) * Math.cos(r(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
}

function num(v: unknown): number | null {
  if (typeof v === "number" && Number.isFinite(v)) return v;
  if (typeof v === "string" && v.trim()) {
    const n = Number(v);
    return Number.isFinite(n) ? n : null;
  }
  return null;
}

function millis(v: unknown): number | null {
  if (v instanceof Timestamp) return v.toMillis();
  if (v && typeof (v as { toMillis?: unknown }).toMillis === "function") {
    return (v as { toMillis: () => number }).toMillis();
  }
  return null;
}

export interface Candidate {
  id: string;
  distanceKm: number | null;
}

/**
 * Pure ranking. Eligible = status EXACTLY 'approved' (roleClaims.ts must not
 * be the arbiter of case — SEC-STATUSCASE), isOnline === true, not excluded,
 * not busy. With a pickup point: fresh location within `radiusKm`, nearest
 * first. Without one: the pincode/city match notifications.ts used, in
 * document order.
 */
export function rankCandidates(
  partners: { id: string; data: FirebaseFirestore.DocumentData }[],
  opts: {
    pickup: Point | null;
    orderAddress: FirebaseFirestore.DocumentData;
    exclude: Set<string>;
    busy: Set<string>;
    radiusKm: number;
    limit: number;
    nowMs: number;
  }
): Candidate[] {
  const eligible = partners.filter(
    (p) => p.data.status === "approved" && p.data.isOnline === true &&
      !opts.exclude.has(p.id) && !opts.busy.has(p.id)
  );
  if (opts.pickup) {
    const pickup = opts.pickup;
    return eligible
      .map((p) => {
        const lat = num(p.data.currentLat);
        const lng = num(p.data.currentLng);
        const seen = millis(p.data.lastLocationUpdate);
        if (lat === null || lng === null || seen === null) return null;
        if (opts.nowMs - seen > LOCATION_FRESHNESS_MS) return null;
        return { id: p.id, distanceKm: distanceKm(pickup, { lat, lng }) };
      })
      .filter((c): c is { id: string; distanceKm: number } => c !== null && c.distanceKm <= opts.radiusKm)
      .sort((a, b) => a.distanceKm - b.distanceKm)
      .slice(0, opts.limit);
  }
  const pin = String(opts.orderAddress.pincode || opts.orderAddress.zipcode || "").trim();
  const city = String(opts.orderAddress.city || "").trim().toLowerCase();
  return eligible
    .filter((p) => {
      const pp = String(p.data.pincode || "").trim();
      const pc = String(p.data.city || "").trim().toLowerCase();
      return (!!pin && pp === pin) || (!!city && pc === city);
    })
    .slice(0, opts.limit)
    .map((p) => ({ id: p.id, distanceKm: null }));
}

async function resolvePickup(db: Db, order: FirebaseFirestore.DocumentData): Promise<Point | null> {
  const direct = orderPickupPoint(order);
  if (direct) return direct;
  const sellerId = typeof order.sellerId === "string" ? order.sellerId : "";
  if (!sellerId) return null;
  const seller = await db.collection("sellers").doc(sellerId).get();
  return sellerPickupPoint(seller.data());
}

async function busyRiders(db: Db): Promise<Set<string>> {
  const snap = await db.collection("orders")
    .where("orderStatus", "in", RIDER_ACTIVE_ORDER_STATUSES).get();
  const busy = new Set<string>();
  snap.docs.forEach((d) => {
    const id = d.data().deliveryPartnerId;
    if (typeof id === "string" && id && holdsRider(d.data())) busy.add(id);
  });
  return busy;
}

/** Riders with an offer for this order that is still open (not yet expired). */
async function openOfferRiders(db: Db, orderId: string, nowMs: number): Promise<Set<string>> {
  const snap = await db.collection("delivery_requests")
    .where("orderId", "==", orderId).where("status", "==", "offered").get();
  const open = new Set<string>();
  snap.docs.forEach((d) => {
    const exp = millis(d.data().expiresAt);
    const rider = d.data().riderId ?? d.data().partnerId;
    if (typeof rider === "string" && (exp === null || exp > nowMs)) open.add(rider);
  });
  return open;
}

/**
 * Begins (or restarts) dispatch for an order that just became ready for
 * pickup without a rider. Keeps `declinedBy` across a restart, so a rider who
 * declined (or released) the order is not offered it again.
 */
export async function startDispatch(db: Db, orderId: string, order: FirebaseFirestore.DocumentData, nowMs: number) {
  if (hasPartner(order) || !isReadyForPickup(order)) return { started: false };
  const ref = dispatchRef(db, orderId);
  const started = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const cur = snap.exists ? snap.data()! : null;
    if (cur && cur.status === "dispatching") return false;
    tx.set(ref, {
      orderId,
      status: "dispatching",
      wave: 0,
      radiusKm: null,
      offeredTo: [],
      declinedBy: Array.isArray(cur?.declinedBy) ? cur!.declinedBy : [],
      needsAdmin: false,
      needsAdminSince: null,
      assignedTo: null,
      stopReason: null,
      leaseUntil: Timestamp.fromMillis(0),
      nextActionAt: Timestamp.fromMillis(nowMs),
      startedAt: Timestamp.fromMillis(nowMs),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return true;
  });
  if (!started) return { started: false };
  const wave = await runNextWave(db, orderId, nowMs, { force: true, expectWave: 0 });
  return { started: true, ...wave };
}

/**
 * Offers the order to the next wave of riders.
 *
 * Waves 1–3 go to riders never offered this order before, at 5/8/12 km; a
 * wave with nobody in range falls straight through to the next. From wave 4
 * on (the D-DLV-NO-TAKER retry) every eligible rider within 12 km who has not
 * declined and holds no open offer is offered again, every 2 min, with the
 * order flagged needsAdmin — set as soon as wave 3 is reached with no offer
 * made or the first retry begins.
 *
 * Single-flight: a transaction takes a short lease before any offer is made,
 * and a forced advance (start, or "everyone in the wave declined") must name
 * the wave it saw — compare-and-swap — so two riders declining at once, or a
 * decline racing the scheduler, advance one wave, not two
 * (phaseDLV2A_dispatch_test d24).
 */
export async function runNextWave(
  db: Db, orderId: string, nowMs: number, opts: { force?: boolean; expectWave?: number } = {}
) {
  const ref = dispatchRef(db, orderId);
  const orderRef = db.collection("orders").doc(orderId);

  const claim = await db.runTransaction(async (tx) => {
    const [snap, orderSnap] = await Promise.all([tx.get(ref), tx.get(orderRef)]);
    if (!snap.exists || !orderSnap.exists) return null;
    const d = snap.data()!;
    const order = orderSnap.data()!;
    if (d.status !== "dispatching") return null;
    if ((millis(d.leaseUntil) ?? 0) > nowMs) return null;
    if (opts.expectWave !== undefined && (d.wave ?? 0) !== opts.expectWave) return null;
    if (!opts.force && (millis(d.nextActionAt) ?? 0) > nowMs) return null;
    if (hasPartner(order) || !isReadyForPickup(order)) return { stop: true as const, order };
    tx.update(ref, { leaseUntil: Timestamp.fromMillis(nowMs + WAVE_LEASE_MS) });
    return { stop: false as const, d, order };
  });
  if (!claim) return { wave: null, offered: [] as string[] };
  if (claim.stop) {
    await closeDispatch(db, orderId, hasPartner(claim.order) ? claim.order.deliveryPartnerId : null, nowMs,
      hasPartner(claim.order) ? "assigned_elsewhere" : "order_not_ready");
    return { wave: null, offered: [] as string[] };
  }

  const { d, order } = claim;
  const pickup = await resolvePickup(db, order);
  const partners = await db.collection("delivery_partners")
    .where("status", "==", "approved").where("isOnline", "==", true).get();
  const partnerList = partners.docs.map((p) => ({ id: p.id, data: p.data() }));
  const busy = await busyRiders(db);
  const declined = new Set<string>(Array.isArray(d.declinedBy) ? d.declinedBy : []);
  const offeredBefore = new Set<string>(Array.isArray(d.offeredTo) ? d.offeredTo : []);
  const open = await openOfferRiders(db, orderId, nowMs);

  // DLV-4A (D-DLV-COD): a rider holding cash at or over the limit gets no
  // COD offers until admin confirms a deposit; prepaid offers still come.
  const rates = await loadRiderPayRates(db);
  const codOrder = isCod(order.paymentMethod) && (num(order.total) ?? 0) > 0;
  const overCashLimit = codOrder ? await ridersAtCashLimit(db, rates.codCashLimit) : new Set<string>();

  let wave = typeof d.wave === "number" ? d.wave : 0;
  let chosen: Candidate[] = [];
  let radiusKm: number = WAVE_RADII_KM[WAVE_RADII_KM.length - 1];
  while (chosen.length === 0) {
    wave += 1;
    const retry = wave > WAVE_RADII_KM.length;
    radiusKm = WAVE_RADII_KM[Math.min(wave, WAVE_RADII_KM.length) - 1];
    const exclude = new Set<string>([...declined, ...open, ...overCashLimit, ...(retry ? [] : offeredBefore)]);
    chosen = rankCandidates(partnerList, {
      pickup, orderAddress: order.deliveryAddress || {}, exclude, busy,
      radiusKm, limit: WAVE_SIZE, nowMs,
    });
    // Fall through empty waves 1–2; stop at wave 3 or any retry wave.
    if (wave >= WAVE_RADII_KM.length) break;
  }

  const needsAdmin = wave > WAVE_RADII_KM.length || (wave === WAVE_RADII_KM.length && chosen.length === 0);
  const inRetry = wave >= WAVE_RADII_KM.length && (chosen.length === 0 || wave > WAVE_RADII_KM.length);
  const expiresAt = Timestamp.fromMillis(nowMs + OFFER_TTL_MS);
  const drop = dropPoint(order);
  const items = Array.isArray(order.items) ? order.items : [];
  const itemCount = items.reduce((n: number, i: { quantity?: unknown }) =>
    n + (typeof i?.quantity === "number" ? i.quantity : 1), 0);
  const cod = isCod(order.paymentMethod) ? (num(order.total) ?? 0) : 0;
  const sellerSnap = typeof order.sellerId === "string" && order.sellerId
    ? await db.collection("sellers").doc(order.sellerId).get() : null;
  const seller = sellerSnap?.data() ?? {};
  const pickupArea = [seller.city, seller.pincode].filter((v) => typeof v === "string" && v).join(" · ") || null;
  // DLV-4A (D-DLV-PAY): what the rider is offered — base + distance on the
  // straight line × 1.35 (no road route exists before acceptance). The
  // amount actually paid is computed at delivery, road distance and waiting
  // included (riderMoney.ts).
  const estimate = riderPay(rates, tripKm({ pickup, drop }).km, 0);

  const batch = db.batch();
  for (const c of chosen) {
    batch.set(offerRef(db, orderId, c.id), {
      requestId: `${orderId}_${c.id}`,
      orderId,
      orderNumber: order.orderNumber ?? null,
      riderId: c.id,
      partnerId: c.id, // pre-DLV-2A field name, kept for older readers
      sellerId: order.sellerId ?? null,
      status: "offered",
      wave,
      expiresAt,
      pickupDistanceKm: c.distanceKm === null ? null : Number(c.distanceKm.toFixed(2)),
      pickupArea,
      dropPincode: drop?.pincode ?? null,
      dropDistanceKm: pickup && drop ? Number(distanceKm(pickup, drop).toFixed(2)) : null,
      itemCount,
      codAmount: cod,
      paymentMethod: order.paymentMethod ?? null,
      estimatedPay: estimate.total,
      radiusKm,
      createdAt: Timestamp.fromMillis(nowMs),
      updatedAt: FieldValue.serverTimestamp(),
    });
  }
  const next = chosen.length > 0 && !inRetry ? nowMs + OFFER_TTL_MS : nowMs + RETRY_INTERVAL_MS;
  batch.update(dispatchRef(db, orderId), {
    wave,
    radiusKm,
    ...(chosen.length ? { offeredTo: FieldValue.arrayUnion(...chosen.map((c) => c.id)) } : {}),
    lastWaveAt: Timestamp.fromMillis(nowMs),
    nextActionAt: Timestamp.fromMillis(next),
    leaseUntil: Timestamp.fromMillis(0),
    ...(needsAdmin && !d.needsAdmin ? { needsAdmin: true, needsAdminSince: Timestamp.fromMillis(nowMs) } : {}),
    updatedAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();

  await Promise.all(chosen.map((c) => sendOfferPush(db, c.id, {
    orderId, orderNumber: String(order.orderNumber ?? orderId), expiresAtMs: nowMs + OFFER_TTL_MS,
    pickupDistanceKm: c.distanceKm, itemCount, codAmount: cod,
  }).catch((e) => console.warn(`[dispatch] push to ${c.id} failed: ${e?.message ?? e}`))));

  return { wave, offered: chosen.map((c) => c.id), needsAdmin };
}

/**
 * Ends dispatch: the winner's offer (if any) becomes accepted, every other
 * open offer withdrawn. Idempotent.
 */
export async function closeDispatch(db: Db, orderId: string, winnerId: string | null, nowMs: number, reason: string) {
  const open = await db.collection("delivery_requests")
    .where("orderId", "==", orderId).where("status", "==", "offered").get();
  const batch = db.batch();
  open.docs.forEach((doc) => {
    const rider = doc.data().riderId ?? doc.data().partnerId;
    batch.update(doc.ref, {
      status: rider === winnerId ? "accepted" : "withdrawn",
      closedAt: Timestamp.fromMillis(nowMs),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
  const ref = dispatchRef(db, orderId);
  const snap = await ref.get();
  if (snap.exists) {
    batch.update(ref, {
      status: winnerId ? "assigned" : "stopped",
      assignedTo: winnerId,
      stopReason: reason,
      needsAdmin: false,
      leaseUntil: Timestamp.fromMillis(0),
      updatedAt: FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
}

/** Marks offers past their expiry as expired. Returns how many. */
export async function expireOffers(db: Db, nowMs: number, limit = 200): Promise<number> {
  const snap = await db.collection("delivery_requests")
    .where("status", "==", "offered")
    .where("expiresAt", "<=", Timestamp.fromMillis(nowMs))
    .limit(limit).get();
  if (snap.empty) return 0;
  const batch = db.batch();
  snap.docs.forEach((d) => batch.update(d.ref, { status: "expired", updatedAt: FieldValue.serverTimestamp() }));
  await batch.commit();
  return snap.size;
}

/** One scheduler tick: expire offers, then advance every due dispatch. */
export async function runDispatchTick(db: Db, nowMs: number, limit = 50) {
  const expired = await expireOffers(db, nowMs);
  const due = await db.collection("delivery_dispatch")
    .where("status", "==", "dispatching")
    .where("nextActionAt", "<=", Timestamp.fromMillis(nowMs))
    .limit(limit).get();
  let advanced = 0;
  for (const doc of due.docs) {
    try {
      const r = await runNextWave(db, doc.id, nowMs);
      if (r.wave !== null) advanced += 1;
    } catch (e) {
      console.error(`[dispatch] tick failed for ${doc.id}:`, e);
    }
  }
  return { expired, due: due.size, advanced };
}

export function isCod(paymentMethod: unknown): boolean {
  const m = typeof paymentMethod === "string" ? paymentMethod.toLowerCase() : "";
  return m === "cod" || m === "cash_on_delivery" || m.includes("cash");
}

function uniqueTokens(data: FirebaseFirestore.DocumentData | undefined): string[] {
  if (!data) return [];
  const out = new Set<string>();
  if (Array.isArray(data.fcmTokens)) {
    data.fcmTokens.forEach((t: unknown) => { if (typeof t === "string" && t.trim()) out.add(t.trim()); });
  }
  if (typeof data.fcmToken === "string" && data.fcmToken.trim()) out.add(data.fcmToken.trim());
  return [...out];
}

/**
 * The offer push. Type 'delivery_offer' on the 'delivery_offers' channel,
 * high priority, TTL = the offer's life. It carries a notification block as
 * well as data: the server cannot tell which build a rider runs, and the
 * released build must still show something; DLV-2B's handler raises the
 * full-screen alert from the data and suppresses the duplicate.
 */
async function sendOfferPush(db: Db, riderId: string, o: {
  orderId: string; orderNumber: string; expiresAtMs: number;
  pickupDistanceKm: number | null; itemCount: number; codAmount: number;
}) {
  const userRef = db.collection("users").doc(riderId);
  const user = await userRef.get();
  const tokens = uniqueTokens(user.data());
  if (!tokens.length) return;
  const title = "New delivery request";
  const parts = [
    o.pickupDistanceKm === null ? "Pickup nearby" : `Pickup ${o.pickupDistanceKm.toFixed(1)} km away`,
    `${o.itemCount} item${o.itemCount === 1 ? "" : "s"}`,
    ...(o.codAmount > 0 ? [`Collect ₹${Math.round(o.codAmount)}`] : []),
  ];
  const body = parts.join(" · ");
  const invalid: string[] = [];
  for (const token of tokens) {
    try {
      await admin.messaging().send({
        token,
        notification: { title, body },
        data: {
          type: "delivery_offer",
          orderId: o.orderId,
          orderNumber: o.orderNumber,
          expiresAt: String(o.expiresAtMs),
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          priority: "high",
          ttl: OFFER_TTL_MS,
          notification: {
            // DLV-2B: the rider app replaces this system copy with its own
            // ringing full-screen alert and clears it by this tag.
            tag: `delivery_offer_${o.orderId}`,
            channelId: OFFERS_CHANNEL_ID,
            priority: "max",
            visibility: "public",
            defaultSound: true,
            defaultVibrateTimings: true,
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
          },
        },
        apns: { headers: { "apns-priority": "10" }, payload: { aps: { sound: "default" } } },
      });
    } catch (e: unknown) {
      const code = (e as { code?: string })?.code;
      if (code === "messaging/invalid-registration-token" || code === "messaging/registration-token-not-registered") {
        invalid.push(token);
      }
    }
  }
  if (invalid.length) await userRef.update({ fcmTokens: FieldValue.arrayRemove(...invalid) });
}
