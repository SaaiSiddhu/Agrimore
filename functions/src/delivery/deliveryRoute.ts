// ============================================================
//  Road route for customer live tracking (Phase DLV-3B)
// ============================================================
//
// OWNER_DECISION D-DLV-ROUTES (2026-09-23, references/decisions.md): the
// customer's map follows real roads, from Google's Routes API (two-wheeler,
// traffic-aware), called ONLY from here — the key is the
// GOOGLE_ROUTES_API_KEY secret and never reaches an app.
//
// Like Swiggy/Zomato, not on every GPS ping: a route is (re)computed when a
// leg starts, when the stage changes (pickup), when the rider strays more
// than OFF_ROUTE_METERS from it, or when it is older than MAX_ROUTE_AGE_MS —
// never more often than MIN_REROUTE_GAP_MS, and at most MAX_ROUTES_PER_ORDER
// times. The result goes on delivery_tasks/{orderId}.route (server-written;
// readable by the order's customer, seller, rider and admin — firestore.rules
// unchanged). The app draws it and counts its traffic-aware duration down for
// the ETA, falling back to the free estimate (D-DLV-ETA) when there is none.

import * as admin from "firebase-admin";
import { Timestamp } from "firebase-admin/firestore";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { defineSecret } from "firebase-functions/params";

export const GOOGLE_ROUTES_API_KEY = defineSecret("GOOGLE_ROUTES_API_KEY");

export const OFF_ROUTE_METERS = 150;
export const MIN_REROUTE_GAP_MS = 20 * 1000;
export const MAX_ROUTE_AGE_MS = 5 * 60 * 1000;
export const MAX_ROUTES_PER_ORDER = 30;
export const STALE_LIVE_MS = 2 * 60 * 1000;
const ROUTES_URL = "https://routes.googleapis.com/directions/v2:computeRoutes";
const FIELD_MASK = "routes.duration,routes.distanceMeters,routes.legs.duration,routes.legs.distanceMeters,routes.legs.polyline.encodedPolyline";

type Db = FirebaseFirestore.Firestore;
export type Point = { lat: number; lng: number };

/**
 * Which route a leg status needs: via the store while the rider is still
 * heading there, straight to the customer from the store onwards; none
 * before a rider has the order or after it ends.
 */
export function routePlanFor(status: unknown): "via_pickup" | "to_drop" | null {
  switch (status) {
    case "assigned":
      return "via_pickup";
    case "at_pickup":
    case "picked_up":
    case "en_route":
    case "at_drop":
      return "to_drop";
    default:
      return null;
  }
}

/** Google's encoded polyline format. */
export function decodePolyline(encoded: string): Point[] {
  const out: Point[] = [];
  let i = 0, lat = 0, lng = 0;
  const next = (): number | null => {
    let shift = 0, result = 0, b: number;
    do {
      if (i >= encoded.length) return null;
      b = encoded.charCodeAt(i++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    return result & 1 ? ~(result >> 1) : result >> 1;
  };
  while (i < encoded.length) {
    const dLat = next();
    const dLng = next();
    if (dLat === null || dLng === null) break;
    lat += dLat;
    lng += dLng;
    out.push({ lat: lat / 1e5, lng: lng / 1e5 });
  }
  return out;
}

/** Metres from p to the nearest point of the polyline (flat-earth, fine at city scale). */
export function distanceToPolylineMeters(p: Point, line: Point[]): number {
  if (line.length === 0) return Infinity;
  const k = 111320;
  const cos = Math.cos((p.lat * Math.PI) / 180);
  const xy = (q: Point) => ({ x: q.lng * k * cos, y: q.lat * k });
  const P = xy(p);
  if (line.length === 1) {
    const A = xy(line[0]);
    return Math.hypot(P.x - A.x, P.y - A.y);
  }
  let best = Infinity;
  for (let j = 0; j < line.length - 1; j++) {
    const A = xy(line[j]), B = xy(line[j + 1]);
    const dx = B.x - A.x, dy = B.y - A.y;
    const len2 = dx * dx + dy * dy;
    const t = len2 === 0 ? 0 : Math.max(0, Math.min(1, ((P.x - A.x) * dx + (P.y - A.y) * dy) / len2));
    best = Math.min(best, Math.hypot(P.x - (A.x + t * dx), P.y - (A.y + t * dy)));
  }
  return best;
}

function millis(v: unknown): number | null {
  if (v instanceof Timestamp) return v.toMillis();
  if (typeof v === "number") return v;
  return null;
}

/** Why a new route is needed now, or null. Pure — the suite pins it. */
export function rerouteReason(
  task: FirebaseFirestore.DocumentData | undefined,
  live: FirebaseFirestore.DocumentData | undefined,
  nowMs: number
): string | null {
  if (!task || !live) return null;
  const plan = routePlanFor(task.status);
  if (!plan) return null;
  if (typeof live.lat !== "number" || typeof live.lng !== "number") return null;
  const at = millis(live.at);
  if (at === null || nowMs - at > STALE_LIVE_MS) return null;
  if (!task.drop || (plan === "via_pickup" && !task.pickup)) return null;
  const route = task.route;
  const count = typeof route?.count === "number" ? route.count : 0;
  if (count >= MAX_ROUTES_PER_ORDER) return null;
  const computedAt = millis(route?.computedAt);
  const requestedAt = millis(route?.requestedAt);
  // Throttle on the latest attempt, successful or not: a failing API must
  // not be retried on every GPS ping.
  const lastTry = Math.max(computedAt ?? 0, requestedAt ?? 0);
  if (lastTry && nowMs - lastTry < MIN_REROUTE_GAP_MS) return null;
  if (!route || computedAt === null) return "first";
  if (route.plan !== plan) return "stage";
  if (nowMs - computedAt > MAX_ROUTE_AGE_MS) return "age";
  const firstLeg = Array.isArray(route.legs) && route.legs[0]?.polyline;
  const geometry = typeof firstLeg === "string" ? decodePolyline(firstLeg) : [];
  // No geometry to measure against is not "off route" (it cost a call per
  // ping in the suite before this check).
  if (geometry.length > 0 &&
      distanceToPolylineMeters({ lat: live.lat, lng: live.lng }, geometry) > OFF_ROUTE_METERS) {
    return "off_route";
  }
  return null;
}

export type RouteFetcher = (body: unknown, apiKey: string) => Promise<unknown>;

/** The real Routes API call (exported for scripts/routes_smoke.js). */
export const googleFetcher: RouteFetcher = async (body, apiKey) => {
  const res = await fetch(ROUTES_URL, {
    method: "POST",
    headers: { "content-type": "application/json", "X-Goog-Api-Key": apiKey, "X-Goog-FieldMask": FIELD_MASK },
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`Routes API ${res.status}: ${(await res.text()).slice(0, 200)}`);
  return res.json();
};

const ll = (p: Point) => ({ location: { latLng: { latitude: p.lat, longitude: p.lng } } });
const seconds = (d: unknown) => (typeof d === "string" && /^\d+(\.\d+)?s$/.test(d) ? Math.round(parseFloat(d)) : null);

export function routeRequest(plan: "via_pickup" | "to_drop", rider: Point, pickup: Point | null, drop: Point) {
  return {
    origin: ll(rider),
    destination: ll(drop),
    ...(plan === "via_pickup" && pickup ? { intermediates: [ll(pickup)] } : {}),
    travelMode: "TWO_WHEELER",
    routingPreference: "TRAFFIC_AWARE",
    // HIGH_QUALITY: OVERVIEW is "composed using a small number of points"
    // and cuts corners between junctions instead of following the road.
    polylineQuality: "HIGH_QUALITY",
    polylineEncoding: "ENCODED_POLYLINE",
    languageCode: "en-IN",
    regionCode: "IN",
    units: "METRIC",
  };
}

/**
 * Recomputes the route for one order if it needs one. Claims the slot in a
 * transaction first (requestedAt) so two quick live writes cost one call.
 * Returns the reason it routed, or null.
 */
export async function refreshRouteCore(
  db: Db, orderId: string, nowMs: number, apiKey: string, fetcher: RouteFetcher = googleFetcher
): Promise<string | null> {
  const taskRef = db.collection("delivery_tasks").doc(orderId);
  const liveRef = taskRef.collection("live").doc("rider");
  const claim = await db.runTransaction(async (tx) => {
    const [taskSnap, liveSnap] = await Promise.all([tx.get(taskRef), tx.get(liveRef)]);
    const task = taskSnap.data();
    const live = liveSnap.data();
    const reason = rerouteReason(task, live, nowMs);
    if (!reason) return null;
    tx.update(taskRef, { "route.requestedAt": Timestamp.fromMillis(nowMs) });
    return { reason, task: task!, live: live! };
  });
  if (!claim) return null;
  if (!apiKey) {
    console.warn("[deliveryRoute] GOOGLE_ROUTES_API_KEY not set; no road route");
    return null;
  }
  const { task, live } = claim;
  const plan = routePlanFor(task.status)!;
  const rider = { lat: live.lat as number, lng: live.lng as number };
  let json: any;
  try {
    json = await fetcher(routeRequest(plan, rider, task.pickup ?? null, task.drop), apiKey);
  } catch (e) {
    console.warn(`[deliveryRoute] ${orderId}: ${(e as Error)?.message ?? e}`);
    return null;
  }
  const r = json?.routes?.[0];
  const legs = Array.isArray(r?.legs) ? r.legs : [];
  if (!r || legs.length === 0 || legs.some((l: any) => typeof l?.polyline?.encodedPolyline !== "string")) {
    console.warn(`[deliveryRoute] ${orderId}: no usable route`);
    return null;
  }
  await taskRef.update({
    route: {
      plan,
      legs: legs.map((l: any) => ({
        polyline: l.polyline.encodedPolyline,
        durationSeconds: seconds(l.duration),
        distanceMeters: typeof l.distanceMeters === "number" ? l.distanceMeters : null,
      })),
      durationSeconds: seconds(r.duration),
      distanceMeters: typeof r.distanceMeters === "number" ? r.distanceMeters : null,
      origin: rider,
      computedAt: Timestamp.fromMillis(nowMs),
      requestedAt: Timestamp.fromMillis(nowMs),
      count: (typeof task.route?.count === "number" ? task.route.count : 0) + 1,
      reason: claim.reason,
    },
  });
  return claim.reason;
}

export const refreshDeliveryRoute = onDocumentWritten(
  {
    document: "delivery_tasks/{orderId}/live/rider",
    secrets: [GOOGLE_ROUTES_API_KEY],
    memory: "256MiB",
    maxInstances: 20,
  },
  async (event) => {
    if (!event.data?.after?.exists) return;
    try {
      await refreshRouteCore(admin.firestore(), event.params.orderId, Date.now(), GOOGLE_ROUTES_API_KEY.value());
    } catch (e) {
      console.error(`[deliveryRoute] ${event.params.orderId} failed:`, e);
    }
  }
);
