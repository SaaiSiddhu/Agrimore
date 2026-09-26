// ============================================================
//  Rider support tickets (Phase DLVSUP1)
// ============================================================
//
// A rider's only self-serve support surface was Profile's raw Call/Email
// buttons (support_card.dart) -- no way to actually file anything and get a
// tracked answer. Modelled on rider_incidents (riderIncidents.ts) rather
// than the identity/bank/vehicle change-request family: a support ticket is
// not "one value to review and either approve or reject" -- like an
// incident, several may be open on a rider at once (two different problems
// don't conflict the way two proposed values for the same field would), so
// there is no singleton pending-gate here. Status is submitted -> seen ->
// closed (mirrors incidents' reported -> acknowledged -> resolved exactly,
// including "closing implies it was seen" and a required note on close),
// idempotent by client-supplied requestId (a retried call after a lost
// response returns the same ticket, never a duplicate).
//
// 31.4's own mockup explicitly warns: "Only confirmed backend states are
// shown: Submitted, Seen, Closed" -- no 4th state is invented here either.
// "Related to" (a specific order/statement) is accepted and stored so a
// picker can be added later without another reshape, but no picker UI
// ships this phase -- see this phase's ledger row for why.
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { Timestamp } from "firebase-admin/firestore";
import { resolveIsAdmin } from "../admin/complianceGate";
import { supportRequestNotice, tellRider } from "./riderNotices";

type Db = FirebaseFirestore.Firestore;

export const RIDER_SUPPORT_CATEGORIES = ["delivery_issue", "earnings_payouts", "account_documents"] as const;
export type RiderSupportCategory = (typeof RIDER_SUPPORT_CATEGORIES)[number];

export const MAX_MESSAGE = 500;
const REQUEST_ID = /^[A-Za-z0-9_-]{8,64}$/;

export type RelatedTo = { type: "order" | "statement"; id: string };

/** null = none given (valid); undefined = given but malformed (invalid). */
function parseRelatedTo(v: unknown): RelatedTo | null | undefined {
  if (v === undefined || v === null) return null;
  if (typeof v !== "object") return undefined;
  const r = v as Record<string, unknown>;
  if ((r.type !== "order" && r.type !== "statement") || typeof r.id !== "string" || !r.id.trim()) return undefined;
  return { type: r.type, id: r.id.trim() };
}

export type SupportRequestVerdict =
  | { kind: "submitted"; ticketId: string }
  | { kind: "already"; ticketId: string }
  | { kind: "refused"; reason: "not_a_rider" | "bad_request" };

export async function submitSupportRequestCore(
  db: Db, riderId: string, data: unknown, nowMs: number
): Promise<SupportRequestVerdict> {
  const d = (data ?? {}) as Record<string, unknown>;
  const requestId = typeof d.requestId === "string" ? d.requestId : "";
  const category = typeof d.category === "string" ? d.category : "";
  const message = typeof d.message === "string" ? d.message.trim() : "";
  const attachmentPath = d.attachmentPath === undefined || d.attachmentPath === null ? null
    : typeof d.attachmentPath === "string" && d.attachmentPath.trim() ? d.attachmentPath.trim() : undefined;
  const relatedTo = parseRelatedTo(d.relatedTo);
  if (!REQUEST_ID.test(requestId) || !(RIDER_SUPPORT_CATEGORIES as readonly string[]).includes(category) ||
      message.length < 3 || message.length > MAX_MESSAGE || attachmentPath === undefined || relatedTo === undefined) {
    return { kind: "refused", reason: "bad_request" };
  }
  const ticketId = `${riderId}_${requestId}`;
  const ticketRef = db.collection("rider_support_tickets").doc(ticketId);
  const partnerRef = db.collection("delivery_partners").doc(riderId);
  return db.runTransaction(async (tx): Promise<SupportRequestVerdict> => {
    const [existing, partner] = await Promise.all([tx.get(ticketRef), tx.get(partnerRef)]);
    if (existing.exists) return { kind: "already", ticketId };
    // Any registered rider may file a support request, including a
    // suspended one -- exactly like an incident report, help-seeking must
    // never be blocked by account status.
    if (!partner.exists) return { kind: "refused", reason: "not_a_rider" };
    const at = Timestamp.fromMillis(nowMs);
    tx.create(ticketRef, {
      ticketId,
      riderId,
      category: category as RiderSupportCategory,
      relatedTo,
      message,
      attachmentPath,
      status: "submitted",
      createdAt: at,
      updatedAt: at,
      seenAt: null,
      seenBy: null,
      closedAt: null,
      closedBy: null,
      resolutionNote: null,
    });
    return { kind: "submitted", ticketId };
  });
}

export type SupportUpdateVerdict =
  | { kind: "updated" | "unchanged"; status: string }
  | { kind: "refused"; reason: "not_found" | "bad_request" | "already_closed" | "note_required" };

export async function updateSupportRequestCore(
  db: Db, adminUid: string, ticketId: string, action: unknown, note: unknown, nowMs: number
): Promise<SupportUpdateVerdict> {
  if (action !== "mark_seen" && action !== "close") return { kind: "refused", reason: "bad_request" };
  const text = typeof note === "string" ? note.trim() : "";
  if (action === "close" && (text.length < 3 || text.length > MAX_MESSAGE)) return { kind: "refused", reason: "note_required" };
  const ref = db.collection("rider_support_tickets").doc(ticketId);
  return db.runTransaction(async (tx): Promise<SupportUpdateVerdict> => {
    const snap = await tx.get(ref);
    if (!snap.exists) return { kind: "refused", reason: "not_found" };
    const status = snap.data()!.status;
    const at = Timestamp.fromMillis(nowMs);
    if (action === "mark_seen") {
      if (status !== "submitted") return { kind: "unchanged", status };
      tx.update(ref, { status: "seen", seenAt: at, seenBy: adminUid, updatedAt: at });
      return { kind: "updated", status: "seen" };
    }
    if (status === "closed") return { kind: "refused", reason: "already_closed" };
    tx.update(ref, {
      status: "closed",
      closedAt: at,
      closedBy: adminUid,
      resolutionNote: text,
      // Closing implies a person saw it; keep the first "seen" if there was one.
      ...(status === "submitted" ? { seenAt: at, seenBy: adminUid } : {}),
      updatedAt: at,
    });
    return { kind: "updated", status: "closed" };
  });
}

// ── callables ──

const REFUSALS: Record<string, [HttpsError["code"], string]> = {
  not_a_rider: ["permission-denied", "Only delivery partners can submit a support request"],
  bad_request: ["invalid-argument", "The request could not be read"],
  not_found: ["not-found", "Request not found"],
  already_closed: ["failed-precondition", "This request is already closed"],
  note_required: ["invalid-argument", "Write what was done (3–500 characters)"],
};
function refuse(reason: string): never {
  const [code, message] = REFUSALS[reason];
  throw new HttpsError(code, message, { reason });
}

export const submitSupportRequest = onCall({ minInstances: 0, memory: "256MiB" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required");
  const v = await submitSupportRequestCore(admin.firestore(), request.auth.uid, request.data, Date.now());
  if (v.kind === "refused") refuse(v.reason);
  return { success: true, ticketId: v.ticketId, alreadySubmitted: v.kind === "already" };
});

export const updateSupportRequest = onCall({ minInstances: 0, memory: "256MiB" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required");
  const isAdmin = await resolveIsAdmin(admin.firestore(), request.auth.uid, request.auth.token.admin === true);
  if (!isAdmin) throw new HttpsError("permission-denied", "Admins only");
  const d = (request.data ?? {}) as Record<string, unknown>;
  const ticketId = typeof d.ticketId === "string" ? d.ticketId.trim() : "";
  if (!ticketId) throw new HttpsError("invalid-argument", "ticketId is required");
  const v = await updateSupportRequestCore(admin.firestore(), request.auth.uid, ticketId, d.action, d.note, Date.now());
  if (v.kind === "refused") refuse(v.reason);
  if (v.kind === "updated") {
    const db = admin.firestore();
    const t = (await db.collection("rider_support_tickets").doc(ticketId).get()).data() ?? {};
    await tellRider(
      db, typeof t.riderId === "string" ? t.riderId : null,
      supportRequestNotice(ticketId, v.status === "closed" ? "closed" : "seen", typeof t.resolutionNote === "string" ? t.resolutionNote : null),
      Date.now()
    );
  }
  return { success: true, status: v.status, changed: v.kind === "updated" };
});
