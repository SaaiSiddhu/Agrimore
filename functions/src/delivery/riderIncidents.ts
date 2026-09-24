// ============================================================
//  Rider incidents (Phase DLV-S2): a rider tells the Agrimore team about a
//  safety incident; the team acknowledges and resolves it.
// ============================================================
//
// Until DLV-S1 the SOS button claimed "SOS Alert Sent! Live location shared
// with authorities and admin." and sent nothing. S1 made the emergency sheet
// a dialer handoff (112, support). This adds the part the Agrimore team can
// act on: a server-written record in rider_incidents, visible to the rider
// who reported it and to admins, never writable by a client.
//
// What each state means — and what it does NOT mean:
//   reported      the record exists. Nobody has necessarily seen it; there
//                 is no admin push channel today, so the team sees it when
//                 they open Rider Incidents in the admin app.
//   acknowledged  an admin opened it and pressed Acknowledge (a person saw it).
//   resolved      an admin closed it with a written resolution.
// Nothing here contacts emergency services or promises a response time.
//
// Idempotency: the client sends a request id; the incident id is
// `${riderId}_${requestId}`, so a retried call after a lost response returns
// the same incident instead of creating another.
//
// Modular FieldValue/Timestamp (functions-emulator safe; see confirmDelivery.ts).

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { Timestamp } from "firebase-admin/firestore";
import { holdsRider, RIDER_ACTIVE_ORDER_STATUSES } from "./dispatch";
import { parseFix } from "./riderSteps";
import { resolveIsAdmin } from "../admin/complianceGate";
import { incidentNotice, tellRider } from "./riderNotices";

type Db = FirebaseFirestore.Firestore;

export const INCIDENT_KINDS = ["sos"] as const;
export type IncidentKind = typeof INCIDENT_KINDS[number];

/** At most this many reports per rider inside the window (a stuck button must not flood the queue). */
export const MAX_REPORTS = 5;
export const REPORT_WINDOW_MS = 10 * 60 * 1000;
/** A last-known server position younger than this counts as fresh. */
export const FRESH_LOCATION_MS = 2 * 60 * 1000;
export const MAX_NOTE = 500;

const REQUEST_ID = /^[A-Za-z0-9_-]{8,64}$/;

function millis(v: unknown): number | null {
  if (v instanceof Timestamp) return v.toMillis();
  if (v && typeof (v as { toMillis?: unknown }).toMillis === "function") return (v as { toMillis: () => number }).toMillis();
  return null;
}
const num = (v: unknown) => (typeof v === "number" && Number.isFinite(v) ? v : null);

export type IncidentLocation =
  | { freshness: "fresh"; source: "device" | "server"; lat: number; lng: number; accuracy: number | null; isMocked: boolean | null; at: Timestamp }
  | { freshness: "stale"; source: "server"; lat: number; lng: number; accuracy: null; isMocked: null; at: Timestamp }
  | { freshness: "unavailable" };

/**
 * The position to record. The device's fix at the tap wins; otherwise the
 * rider's last server-known position, marked stale beyond 2 minutes and
 * carrying its own time; otherwise "unavailable" — never an invented point.
 */
export function incidentLocation(fixData: unknown, partner: FirebaseFirestore.DocumentData | undefined, nowMs: number): IncidentLocation {
  const fix = parseFix(fixData);
  if (fix) {
    return { freshness: "fresh", source: "device", lat: fix.lat, lng: fix.lng, accuracy: fix.accuracy, isMocked: fix.isMocked, at: Timestamp.fromMillis(nowMs) };
  }
  const lat = num(partner?.currentLat), lng = num(partner?.currentLng), seen = millis(partner?.lastLocationUpdate);
  if (lat === null || lng === null || seen === null) return { freshness: "unavailable" };
  if (nowMs - seen <= FRESH_LOCATION_MS) {
    return { freshness: "fresh", source: "server", lat, lng, accuracy: null, isMocked: null, at: Timestamp.fromMillis(seen) };
  }
  return { freshness: "stale", source: "server", lat, lng, accuracy: null, isMocked: null, at: Timestamp.fromMillis(seen) };
}

export type ReportVerdict =
  | { kind: "reported"; incidentId: string; activeOrderIds: string[] }
  | { kind: "already"; incidentId: string }
  | { kind: "refused"; reason: "not_a_rider" | "bad_request" | "too_many" };

export async function reportIncidentCore(db: Db, riderId: string, data: unknown, nowMs: number): Promise<ReportVerdict> {
  const d = (data ?? {}) as Record<string, unknown>;
  const requestId = typeof d.requestId === "string" ? d.requestId : "";
  const kind = d.kind === undefined ? "sos" : d.kind;
  const note = d.note === undefined || d.note === null ? null : typeof d.note === "string" ? d.note.trim() : undefined;
  if (!REQUEST_ID.test(requestId) || !INCIDENT_KINDS.includes(kind as IncidentKind) || note === undefined || (note && note.length > MAX_NOTE)) {
    return { kind: "refused", reason: "bad_request" };
  }
  const incidentId = `${riderId}_${requestId}`;
  const incidentRef = db.collection("rider_incidents").doc(incidentId);
  const partnerRef = db.collection("delivery_partners").doc(riderId);
  const limitRef = db.collection("rider_incident_limits").doc(riderId);
  const activeQuery = db.collection("orders")
    .where("deliveryPartnerId", "==", riderId)
    .where("orderStatus", "in", RIDER_ACTIVE_ORDER_STATUSES)
    .limit(10);

  return db.runTransaction(async (tx): Promise<ReportVerdict> => {
    const [existing, partner, limits, active] = await Promise.all([
      tx.get(incidentRef), tx.get(partnerRef), tx.get(limitRef), tx.get(activeQuery),
    ]);
    if (existing.exists) return { kind: "already", incidentId };
    // Any registered rider may report — including suspended or pending ones:
    // a safety report must never be blocked by account status.
    if (!partner.exists) return { kind: "refused", reason: "not_a_rider" };
    const recent = (Array.isArray(limits.data()?.recent) ? limits.data()!.recent as unknown[] : [])
      .filter((t): t is number => typeof t === "number" && nowMs - t < REPORT_WINDOW_MS);
    if (recent.length >= MAX_REPORTS) return { kind: "refused", reason: "too_many" };

    const p = partner.data()!;
    // Every active assignment, not an arbitrary first one: more than one is
    // itself something the team needs to see.
    const activeOrderIds = active.docs.filter((o) => holdsRider(o.data())).map((o) => o.id).sort();
    const at = Timestamp.fromMillis(nowMs);
    tx.create(incidentRef, {
      incidentId,
      riderId,
      kind,
      note: note || null,
      riderName: typeof p.name === "string" ? p.name : null,
      riderStatus: typeof p.status === "string" ? p.status : null,
      activeOrderIds,
      orderId: activeOrderIds.length === 1 ? activeOrderIds[0] : null,
      location: incidentLocation(d, p, nowMs),
      status: "reported",
      createdAt: at,
      updatedAt: at,
      acknowledgedAt: null,
      acknowledgedBy: null,
      resolvedAt: null,
      resolvedBy: null,
      resolution: null,
    });
    tx.set(limitRef, { recent: [...recent, nowMs] });
    return { kind: "reported", incidentId, activeOrderIds };
  });
}

export type UpdateVerdict =
  | { kind: "updated" | "unchanged"; status: string }
  | { kind: "refused"; reason: "not_found" | "bad_request" | "already_resolved" | "resolution_required" };

export async function updateIncidentCore(
  db: Db, adminUid: string, incidentId: string, action: unknown, resolution: unknown, nowMs: number
): Promise<UpdateVerdict> {
  if (action !== "acknowledge" && action !== "resolve") return { kind: "refused", reason: "bad_request" };
  const text = typeof resolution === "string" ? resolution.trim() : "";
  if (action === "resolve" && (text.length < 3 || text.length > MAX_NOTE)) return { kind: "refused", reason: "resolution_required" };
  const ref = db.collection("rider_incidents").doc(incidentId);
  return db.runTransaction(async (tx): Promise<UpdateVerdict> => {
    const snap = await tx.get(ref);
    if (!snap.exists) return { kind: "refused", reason: "not_found" };
    const status = snap.data()!.status;
    const at = Timestamp.fromMillis(nowMs);
    if (action === "acknowledge") {
      if (status !== "reported") return { kind: "unchanged", status };
      tx.update(ref, { status: "acknowledged", acknowledgedAt: at, acknowledgedBy: adminUid, updatedAt: at });
      return { kind: "updated", status: "acknowledged" };
    }
    if (status === "resolved") return { kind: "refused", reason: "already_resolved" };
    tx.update(ref, {
      status: "resolved",
      resolvedAt: at,
      resolvedBy: adminUid,
      resolution: text,
      // Resolving implies a person saw it; keep the first acknowledgement if there was one.
      ...(status === "reported" ? { acknowledgedAt: at, acknowledgedBy: adminUid } : {}),
      updatedAt: at,
    });
    return { kind: "updated", status: "resolved" };
  });
}

const REFUSALS: Record<string, [HttpsError["code"], string]> = {
  not_a_rider: ["permission-denied", "Only delivery partners can report an incident here"],
  bad_request: ["invalid-argument", "The report could not be read"],
  too_many: ["resource-exhausted", "Too many reports in a few minutes. Call 112 or Agrimore support"],
  not_found: ["not-found", "Incident not found"],
  already_resolved: ["failed-precondition", "This incident is already resolved"],
  resolution_required: ["invalid-argument", "Write what was done (3–500 characters)"],
};
function refuse(reason: string): never {
  const [code, message] = REFUSALS[reason];
  throw new HttpsError(code, message, { reason });
}

export const reportRiderIncident = onCall({ minInstances: 0, memory: "256MiB" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required");
  const v = await reportIncidentCore(admin.firestore(), request.auth.uid, request.data, Date.now());
  if (v.kind === "refused") refuse(v.reason);
  // Never log the position; the id is enough to find it.
  console.log(`[reportRiderIncident] ${v.incidentId} ${v.kind}`);
  return { success: true, incidentId: v.incidentId, alreadyReported: v.kind === "already" };
});

export const updateRiderIncident = onCall({ minInstances: 0, memory: "256MiB" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required");
  const isAdmin = await resolveIsAdmin(admin.firestore(), request.auth.uid, request.auth.token.admin === true);
  if (!isAdmin) throw new HttpsError("permission-denied", "Admins only");
  const d = (request.data ?? {}) as Record<string, unknown>;
  const incidentId = typeof d.incidentId === "string" ? d.incidentId.trim() : "";
  if (!incidentId) throw new HttpsError("invalid-argument", "incidentId is required");
  const v = await updateIncidentCore(admin.firestore(), request.auth.uid, incidentId, d.action, d.resolution, Date.now());
  if (v.kind === "refused") refuse(v.reason);
  if (v.kind === "updated") {
    const db = admin.firestore();
    const i = (await db.collection("rider_incidents").doc(incidentId).get()).data() ?? {};
    await tellRider(db, typeof i.riderId === "string" ? i.riderId : null,
      incidentNotice(incidentId, v.status === "resolved" ? "resolved" : "acknowledged"), Date.now());
  }
  return { success: true, status: v.status, changed: v.kind === "updated" };
});
