// Phase DLV-N1 — what the rider app's inbox shows (users/{riderId}/notifications,
// the collection firestore.rules already lets its owner read and mark read).
//
// Every notice has a deterministic id, so a retried trigger or callable
// rewrites the same row instead of adding a second one. Pushes that already
// existed (offline, assigned, moved away) are also recorded here, because a
// push that arrives while the phone is off is otherwise gone. Money and review
// outcomes are recorded without a push: the only rider push channel is the
// max-priority order channel, and none of these needs the rider to act now.
import * as admin from "firebase-admin";
import { FieldValue, Timestamp } from "firebase-admin/firestore";

type Db = admin.firestore.Firestore;

export type RiderNoticeType =
  | "rider_offline" | "delivery_assigned" | "delivery_unassigned"
  | "statement_ready" | "payout_sent" | "bank_change_approved" | "bank_change_rejected"
  | "identity_change_approved" | "identity_change_rejected"
  | "delivery_problem_resolved" | "incident_acknowledged" | "incident_resolved"
  | "support_request_seen" | "support_request_closed";

export interface RiderNotice {
  id: string;
  type: RiderNoticeType;
  title: string;
  body: string;
  data: Record<string, string>;
}

const INR = new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", minimumFractionDigits: 2 });
export const rupeesText = (paise: number) => INR.format(paise / 100);

export async function recordRiderNotice(db: Db, riderId: string, n: RiderNotice, nowMs: number): Promise<void> {
  await db.collection("users").doc(riderId).collection("notifications").doc(n.id).set({
    type: n.type,
    title: n.title,
    body: n.body,
    data: n.data,
    audience: "rider",
    unread: true,
    createdAt: Timestamp.fromMillis(nowMs),
    recordedAt: FieldValue.serverTimestamp(),
  });
}

/** Best effort: a notice that cannot be written must never fail the action it reports. */
export async function tellRider(db: Db, riderId: string | null | undefined, n: RiderNotice | null, nowMs: number): Promise<void> {
  if (!riderId || !n) return;
  try {
    await recordRiderNotice(db, riderId, n, nowMs);
  } catch (e) {
    console.warn(`[riderNotices] ${n.id} for ${riderId} not recorded: ${(e as Error)?.message ?? e}`);
  }
}

// ── the notices ──

export const offlineNotice = (offlineAtMs: number): RiderNotice => ({
  id: `offline_${offlineAtMs}`, type: "rider_offline", title: "You're offline",
  body: "We haven't received your location for 15 minutes. Open the app to go online again.",
  data: { type: "rider_offline" },
});

export const assignedNotice = (orderId: string, orderNumber: string): RiderNotice => ({
  id: `assigned_${orderId}`, type: "delivery_assigned", title: "New order assigned to you",
  body: `Order #${orderNumber} — open the app to see the pickup.`,
  data: { type: "delivery_assigned", orderId, orderNumber },
});

export const unassignedNotice = (orderId: string, orderNumber: string): RiderNotice => ({
  id: `unassigned_${orderId}`, type: "delivery_unassigned", title: "Order moved to another rider",
  body: `Order #${orderNumber} is no longer yours. You don't need to pick it up.`,
  data: { type: "delivery_unassigned", orderId, orderNumber },
});

/** A statement was made — not money sent (that is payoutSentNotice). */
export function statementNotice(p: {
  id: string; amountPaise: number; status: string; holdReason?: string | null;
}): RiderNotice {
  const body = p.status === "on_hold"
    ? p.holdReason === "bank_change_pending"
      ? `${rupeesText(p.amountPaise)} is on hold until your new payout details are checked.`
      : `${rupeesText(p.amountPaise)} is on hold — add your bank or UPI details.`
    : p.status === "nothing_to_pay"
      ? "Nothing to pay this week — cash you held covered it."
      : `${rupeesText(p.amountPaise)} will be sent to you by the Agrimore team.`;
  return { id: `statement_${p.id}`, type: "statement_ready", title: "Your weekly statement is ready", body,
    data: { type: "statement_ready", payoutId: p.id } };
}

export function payoutSentNotice(p: {
  id: string; amountPaise: number; reference: string; method: string; accountLast4?: string | null; upiId?: string | null;
}): RiderNotice {
  const to = p.method === "upi" && p.upiId ? `UPI ${p.upiId}` : p.accountLast4 ? `bank account ending ${p.accountLast4}` : "your account";
  return { id: `payout_sent_${p.id}`, type: "payout_sent", title: "Money sent",
    body: `${rupeesText(p.amountPaise)} sent to ${to}. Reference ${p.reference}.`,
    data: { type: "payout_sent", payoutId: p.id } };
}

export function bankReviewNotice(requestId: string, approved: boolean, reason: string | null): RiderNotice {
  return approved
    ? { id: `bank_change_${requestId}`, type: "bank_change_approved", title: "Payout details updated",
      body: "Your new payout details were approved. Pay on hold is released.", data: { type: "bank_change_approved" } }
    : { id: `bank_change_${requestId}`, type: "bank_change_rejected", title: "Payout details not changed",
      body: reason ? `Your change was not approved: ${reason}` : "Your change was not approved.",
      data: { type: "bank_change_rejected" } };
}

export function identityChangeNotice(requestId: string, approved: boolean, reason: string | null): RiderNotice {
  return approved
    ? { id: `identity_change_${requestId}`, type: "identity_change_approved", title: "Your name was updated",
      body: "Your identity change request was approved.", data: { type: "identity_change_approved", requestId } }
    : { id: `identity_change_${requestId}`, type: "identity_change_rejected", title: "Identity change not approved",
      body: reason ? `Your request was not approved: ${reason}` : "Your request was not approved.",
      data: { type: "identity_change_rejected", requestId } };
}

const DISPOSITION_TEXT: Record<string, string> = {
  reattempt: "Try the delivery again.",
  returned_to_seller: "Take the order back to the store.",
};

export function problemResolvedNotice(exceptionId: string, orderId: string, orderNumber: string, disposition: string): RiderNotice {
  return { id: `problem_${exceptionId}`, type: "delivery_problem_resolved", title: `Order #${orderNumber}: problem handled`,
    body: DISPOSITION_TEXT[disposition] ?? "The Agrimore team has handled the problem you reported.",
    data: { type: "delivery_problem_resolved", orderId, orderNumber } };
}

export function supportRequestNotice(ticketId: string, status: "seen" | "closed", resolutionNote: string | null): RiderNotice {
  return status === "closed"
    ? { id: `support_${ticketId}_closed`, type: "support_request_closed", title: "Your support request is closed",
      body: resolutionNote ? `Outcome: ${resolutionNote}` : "Your request has been closed.",
      data: { type: "support_request_closed", ticketId } }
    : { id: `support_${ticketId}_seen`, type: "support_request_seen", title: "Your support request was seen",
      body: "The Agrimore team has seen your request and is looking into it.",
      data: { type: "support_request_seen", ticketId } };
}

export function incidentNotice(incidentId: string, status: "acknowledged" | "resolved"): RiderNotice {
  return status === "acknowledged"
    ? { id: `incident_${incidentId}_ack`, type: "incident_acknowledged", title: "Your safety report was seen",
      body: "The Agrimore team has seen your report and is looking into it.", data: { type: "incident_acknowledged" } }
    : { id: `incident_${incidentId}_done`, type: "incident_resolved", title: "Your safety report was closed",
      body: "The Agrimore team has closed your report. Contact support if you still need help.", data: { type: "incident_resolved" } };
}
