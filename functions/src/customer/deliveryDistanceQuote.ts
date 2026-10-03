// Owner-approved F3.3 distance-priced checkout quotes.
//
// This is a separate use of Google's Routes API for pricing; it does not
// change the traffic-aware rider-tracking route in deliveryRoute.ts. The
// callable reads a caller-owned saved address and seller-owned coordinates,
// performs routing before any checkout transaction, then stores only a
// short-lived quote snapshot (no raw coordinates or route geometry).

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { Timestamp } from "firebase-admin/firestore";
import { normalizeOrderItems, OrderPricingItemInput, MAX_CART_LINES } from "./orderPricing";
import { computeFeeFromSchedule, DeliveryFeeSchedule, parseDeliveryFeeSchedule } from "./deliveryFeeSchedule";
import { distanceScheduleFingerprint, fingerprintDeliveryItems, hashDeliveryQuoteValue as hash } from "./deliveryQuoteFingerprint";
import { computeOrderPricing } from "./orderPricing";
import { GOOGLE_ROUTES_API_KEY } from "../delivery/deliveryRoute";

const ROUTES_URL = "https://routes.googleapis.com/directions/v2:computeRoutes";
const ROUTE_FIELD_MASK = "routes.distanceMeters";
const MAX_SELLERS_PER_QUOTE = 10;
const MAX_RADIUS_KM = 100;
const QUOTE_TTL_MS = 10 * 60 * 1000;
const RATE_WINDOW_MS = 60 * 1000;
const MAX_QUOTES_PER_WINDOW = 3;
const ROUTE_TIMEOUT_MS = 7000;

export type RoutePoint = { latitude: number; longitude: number };
export type DistanceRouteFetcher = (body: unknown, apiKey: string) => Promise<unknown>;

function validCoordinatePair(lat: unknown, lng: unknown): RoutePoint | null {
  if (typeof lat !== "number" || !Number.isFinite(lat) || lat < -90 || lat > 90) return null;
  if (typeof lng !== "number" || !Number.isFinite(lng) || lng < -180 || lng > 180) return null;
  return { latitude: lat, longitude: lng };
}

export { distanceScheduleFingerprint, fingerprintDeliveryItems } from "./deliveryQuoteFingerprint";

function routeBody(origin: RoutePoint, destination: RoutePoint): Record<string, unknown> {
  return {
    origin: { location: { latLng: origin } },
    destination: { location: { latLng: destination } },
    travelMode: "DRIVE",
    routingPreference: "TRAFFIC_UNAWARE",
    computeAlternativeRoutes: false,
    languageCode: "en-IN",
    regionCode: "IN",
    units: "METRIC",
  };
}

/** Calls Routes API with a minimal response field mask; exported for injected local tests. */
export const googleDistanceFetcher: DistanceRouteFetcher = async (body, apiKey) => {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), ROUTE_TIMEOUT_MS);
  try {
    const response = await fetch(ROUTES_URL, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "X-Goog-Api-Key": apiKey,
        "X-Goog-FieldMask": ROUTE_FIELD_MASK,
      },
      body: JSON.stringify(body),
      signal: controller.signal,
    });
    if (!response.ok) {
      // Do not forward provider body text, which can contain address details.
      throw new Error(`Routes API returned HTTP ${response.status}`);
    }
    return response.json();
  } finally {
    clearTimeout(timeout);
  }
};

export async function getRoadDistanceMeters(
  origin: RoutePoint,
  destination: RoutePoint,
  apiKey: string,
  fetcher: DistanceRouteFetcher = googleDistanceFetcher
): Promise<number> {
  if (!apiKey) throw new HttpsError("unavailable", "Distance pricing is temporarily unavailable");
  let result: unknown;
  try {
    result = await fetcher(routeBody(origin, destination), apiKey);
  } catch {
    throw new HttpsError("unavailable", "A delivery route could not be calculated. Please try again.");
  }
  const routes = (result as { routes?: unknown } | null)?.routes;
  const distanceMeters = Array.isArray(routes) ? (routes[0] as { distanceMeters?: unknown } | undefined)?.distanceMeters : undefined;
  if (typeof distanceMeters !== "number" || !Number.isSafeInteger(distanceMeters) || distanceMeters < 0) {
    throw new HttpsError("unavailable", "A delivery route could not be calculated. Please try again.");
  }
  return distanceMeters;
}

async function claimQuoteRateSlot(db: FirebaseFirestore.Firestore, uid: string, nowMs: number): Promise<void> {
  const ref = db.collection("delivery_fee_quote_rate_limits").doc(uid);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const current = snap.data() ?? {};
    const windowStart = typeof current.windowStartMs === "number" ? current.windowStartMs : 0;
    const count = typeof current.count === "number" ? current.count : 0;
    const active = nowMs >= windowStart && nowMs - windowStart < RATE_WINDOW_MS;
    if (active && count >= MAX_QUOTES_PER_WINDOW) {
      throw new HttpsError("resource-exhausted", "Too many delivery quote attempts. Please wait a moment and try again.");
    }
    tx.set(ref, {
      windowStartMs: active ? windowStart : nowMs,
      count: active ? count + 1 : 1,
      updatedAt: Timestamp.fromMillis(nowMs),
    });
  });
}

export interface CreateDeliveryQuoteInput {
  uid: string;
  addressId: string;
  rawItems: unknown;
  orderMode?: "B2C" | "B2B";
  legacyDeliveryCharge?: number;
  rfqId?: string;
  nowMs: number;
  apiKey: string | (() => string);
  fetcher?: DistanceRouteFetcher;
}

/** Purely injectable core: all Firestore reads are owner/product/seller scoped by explicit IDs. */
export async function createDeliveryQuoteCore(
  db: FirebaseFirestore.Firestore,
  input: CreateDeliveryQuoteInput
): Promise<{ deliveryQuoteId: string | null; deliveryQuoteExpiresAtMs?: number; deliveryCharge: number | null; sellerFees: Array<Record<string, unknown>> }> {
  const { uid, addressId, nowMs } = input;
  if (typeof addressId !== "string" || !/^[A-Za-z0-9_-]{1,150}$/.test(addressId)) {
    throw new HttpsError("invalid-argument", "A saved delivery address is required");
  }
  let items: OrderPricingItemInput[];
  try {
    items = normalizeOrderItems(input.rawItems as OrderPricingItemInput[]);
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("invalid-argument", "The delivery quote cart is invalid");
  }
  if (items.length === 0 || items.length > MAX_CART_LINES) {
    throw new HttpsError("invalid-argument", "The delivery quote cart is invalid");
  }

  const productIds = [...new Set(items.map((item) => item.productId))];
  const productSnaps = await db.getAll(...productIds.map((id) => db.collection("products").doc(id)));
  const products = new Map(productSnaps.map((snap) => [snap.id, snap]));
  const sellerIds = [...new Set(items.map((item) => {
    const sellerId = products.get(item.productId)?.data()?.sellerId;
    return typeof sellerId === "string" && sellerId ? sellerId : "_unassigned";
  }))].sort();
  const realSellerIds = sellerIds.filter((id) => id !== "_unassigned");
  if (realSellerIds.length === 0) return { deliveryQuoteId: null, deliveryCharge: null, sellerFees: [] };

  let rfqContext: { rfqId: string; productId: string; quantity: number; finalPrice: number; sellerId: string; fingerprint: string } | null = null;
  if (input.rfqId !== undefined) {
    if (typeof input.rfqId !== "string" || !/^[A-Za-z0-9_-]{1,150}$/.test(input.rfqId) || items.length !== 1) {
      throw new HttpsError("invalid-argument", "The accepted quote order is invalid");
    }
    const rfqSnap = await db.collection("rfqs").doc(input.rfqId).get();
    const rfq = rfqSnap.data();
    const item = items[0];
    if (!rfqSnap.exists || rfq?.buyerId !== uid || rfq?.status !== "accepted" || rfq?.consumedByOrderId ||
        rfq?.productId !== item.productId || rfq?.finalQuantity !== item.quantity ||
        typeof rfq?.finalPrice !== "number" || !Number.isFinite(rfq.finalPrice) || rfq.finalPrice <= 0 ||
        typeof rfq?.sellerId !== "string" || sellerIds[0] !== rfq.sellerId) {
      throw new HttpsError("failed-precondition", "This accepted quote is no longer available");
    }
    const fingerprint = hash({ rfqId: input.rfqId, productId: item.productId, quantity: item.quantity, finalPrice: rfq.finalPrice, sellerId: rfq.sellerId });
    rfqContext = { rfqId: input.rfqId, productId: item.productId, quantity: item.quantity, finalPrice: rfq.finalPrice, sellerId: rfq.sellerId, fingerprint };
  }

  const sellerSnaps = await db.getAll(...realSellerIds.map((id) => db.collection("sellers").doc(id)));
  const sellers = new Map(sellerSnaps.map((snap) => [snap.id, snap.data() ?? {}]));
  const sellerFeeSchedules = new Map<string, DeliveryFeeSchedule>();
  const scheduleFingerprints: Record<string, string> = {};
  const distanceSellerIds: string[] = [];
  for (const sellerId of realSellerIds) {
    const schedule = parseDeliveryFeeSchedule(sellers.get(sellerId)!.deliveryFeeSchedule);
    if (schedule) {
      sellerFeeSchedules.set(sellerId, schedule);
      scheduleFingerprints[sellerId] = distanceScheduleFingerprint(schedule);
      if (schedule.type === "distance") distanceSellerIds.push(sellerId);
    }
  }
  if (sellerFeeSchedules.size === 0) return { deliveryQuoteId: null, deliveryCharge: null, sellerFees: [] };
  if (distanceSellerIds.length > MAX_SELLERS_PER_QUOTE) {
    throw new HttpsError("resource-exhausted", "Too many distance-priced sellers in one checkout");
  }

  const addressSnap = await db.collection("addresses").doc(addressId).get();
  if (!addressSnap.exists || addressSnap.data()?.userId !== uid) {
    throw new HttpsError("permission-denied", "The delivery address does not belong to this account");
  }
  const address = addressSnap.data()!;
  const destination = validCoordinatePair(address.latitude, address.longitude);
  if (distanceSellerIds.length > 0 && !destination) {
    throw new HttpsError("failed-precondition", "Add a map location to this saved address before using distance delivery");
  }

  // Bound scheduled-quote reads as well as billable Routes API requests.
  // This must happen before the Maps key is resolved or any route is fetched.
  await claimQuoteRateSlot(db, uid, nowMs);
  const apiKey = distanceSellerIds.length > 0
    ? (typeof input.apiKey === "function" ? input.apiKey() : input.apiKey)
    : "";
  const distanceEntries: Array<{
    sellerId: string;
    schedule: DeliveryFeeSchedule;
    distanceMeters: number;
    feePaise: number;
    originFingerprint: string;
    radiusKm: number;
    policyFingerprint: string;
  }> = [];

  const distancePolicies = distanceSellerIds.map((sellerId) => {
    const seller = sellers.get(sellerId)!;
    const schedule = parseDeliveryFeeSchedule(seller.deliveryFeeSchedule);
    if (!schedule || schedule.type !== "distance") {
      throw new HttpsError("failed-precondition", "A seller delivery schedule changed; request a new quote");
    }
    const origin = validCoordinatePair(seller.latitude, seller.longitude);
    if (!origin) {
      throw new HttpsError("failed-precondition", "A seller using distance delivery must configure a valid shop location");
    }
    const radiusKm = seller.deliveryRadiusKm;
    if (typeof radiusKm !== "number" || !Number.isFinite(radiusKm) || radiusKm <= 0 || radiusKm > MAX_RADIUS_KM) {
      throw new HttpsError("failed-precondition", "A seller using distance delivery must configure a valid delivery radius");
    }
    return { sellerId, schedule, origin, radiusKm };
  });

  // Fetch the bounded set together so a cart with several distance-priced sellers
  // cannot consume one per-route timeout for each seller in sequence.
  const measuredDistances = await Promise.all(distancePolicies.map(async (policy) => ({
    ...policy,
    distanceMeters: await getRoadDistanceMeters(policy.origin, destination!, apiKey, input.fetcher),
  })));
  for (const { sellerId, schedule, origin, radiusKm, distanceMeters } of measuredDistances) {
    if (distanceMeters > Math.round(radiusKm * 1000)) {
      throw new HttpsError("failed-precondition", "This delivery address is outside the seller's delivery area");
    }
    const fee = (schedule.baseFeePaise + Math.round(distanceMeters * schedule.ratePerKmPaise / 1000)) / 100;
    distanceEntries.push({
      sellerId,
      schedule,
      distanceMeters,
      feePaise: Math.round(fee * 100),
      originFingerprint: hash(origin),
      radiusKm,
      policyFingerprint: distanceScheduleFingerprint(schedule),
    });
  }

  const quoteRef = db.collection("delivery_fee_quotes").doc();
  const addressFingerprint = hash({ addressId, destination: destination ?? null });
  const cartFingerprint = fingerprintDeliveryItems(items);
  const sellerFees = distanceEntries.map(({ sellerId, distanceMeters, feePaise }) => ({
    sellerId,
    distanceMeters,
    deliveryCharge: feePaise / 100,
  }));
  const sellerDistanceMeters = new Map(distanceEntries.map((entry) => [entry.sellerId, entry.distanceMeters]));
  const orderMode = input.orderMode ?? "B2C";
  const legacyDeliveryCharge = typeof input.legacyDeliveryCharge === "number" && Number.isFinite(input.legacyDeliveryCharge)
    ? Math.max(0, input.legacyDeliveryCharge) : 0;
  let deliveryCharge: number;
  if (rfqContext) {
    const schedule = sellerFeeSchedules.get(rfqContext.sellerId);
    deliveryCharge = schedule
      ? computeFeeFromSchedule(schedule, rfqContext.finalPrice * rfqContext.quantity, sellerDistanceMeters.get(rfqContext.sellerId))
      : legacyDeliveryCharge;
  } else {
    deliveryCharge = computeOrderPricing({
      items, productSnaps, orderMode, uid, couponSnap: null,
      deliveryCharge: legacyDeliveryCharge,
      sellerFeeSchedules,
      sellerDistanceMeters,
    }).deliveryCharge;
  }
  const totalPaise = Math.round(deliveryCharge * 100);
  if (!Number.isSafeInteger(totalPaise) || totalPaise > 100000) {
    throw new HttpsError("failed-precondition", "Distance delivery fees exceed the allowed maximum");
  }
  await quoteRef.create({
    uid,
    addressId,
    addressFingerprint,
    cartFingerprint,
    sellerIds,
    orderMode,
    ...(rfqContext ? { rfqContext } : {}),
    legacyDeliveryChargePaise: Math.round(legacyDeliveryCharge * 100),
    scheduleFingerprints,
    distanceEntries: distanceEntries.map((entry) => ({
      sellerId: entry.sellerId,
      distanceMeters: entry.distanceMeters,
      feePaise: entry.feePaise,
      originFingerprint: entry.originFingerprint,
      radiusKm: entry.radiusKm,
      policyFingerprint: entry.policyFingerprint,
    })),
    deliveryChargePaise: totalPaise,
    createdAt: Timestamp.fromMillis(nowMs),
    expiresAt: Timestamp.fromMillis(nowMs + QUOTE_TTL_MS),
    consumedAt: null,
    consumedByOrderIds: null,
  });
  return { deliveryQuoteId: quoteRef.id, deliveryQuoteExpiresAtMs: nowMs + QUOTE_TTL_MS, deliveryCharge: totalPaise / 100, sellerFees };
}

export const quoteDeliveryFees = onCall(
  { minInstances: 0, maxInstances: 10, memory: "256MiB", secrets: [GOOGLE_ROUTES_API_KEY] },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required");
    const uid = request.auth.uid;
    const db = admin.firestore();
    const nowMs = Date.now();

    // The core resolves seller schedules first and touches the Routes secret
    // only when at least one distance schedule is present.
    return createDeliveryQuoteCore(db, {
      uid,
      addressId: request.data?.addressId,
      rawItems: request.data?.items,
      orderMode: request.data?.orderMode === "B2B" ? "B2B" : "B2C",
      legacyDeliveryCharge: request.data?.legacyDeliveryCharge,
      rfqId: request.data?.rfqId,
      nowMs,
      apiKey: () => GOOGLE_ROUTES_API_KEY.value(),
    });
  }
);
