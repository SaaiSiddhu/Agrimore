// ============================================================
//  Rider presence + rider pushes (Phase DLV-3A)
// ============================================================
//
// OWNER_DECISION D-DLV-BG (references/decisions.md): while a rider is online
// the rider app keeps sending location from a foreground service. A rider
// whose location has not arrived for SILENT_OFFLINE_MS — app killed, phone
// off, the released foreground-only build left in the background — is taken
// offline here, so dispatch and the admin queue stop counting them. A rider
// on an active order is never taken offline (weak GPS inside a building must
// not end their shift mid-delivery); dispatch already skips busy riders.
//
// Also the pushes a rider needs outside the offer flow: an order assigned by
// an admin (DLV-2C's screen writes deliveryAcceptedVia 'admin'), and an order
// moved away from them by a reassignment.
//
// Modular FieldValue/Timestamp only: onOrderStatusChanged is a v1 trigger, and
// namespace admin.firestore.FieldValue is undefined there
// (phaseDLV2A_trigger_test, P0-FIELDVALUE).

import * as admin from "firebase-admin";
import { FieldPath, FieldValue, Timestamp } from "firebase-admin/firestore";
import { holdsRider, RIDER_ACTIVE_ORDER_STATUSES } from "./dispatch";
import { assignedNotice, offlineNotice, tellRider, unassignedNotice } from "./riderNotices";

type Db = FirebaseFirestore.Firestore;

export const SILENT_OFFLINE_MS = 15 * 60 * 1000;
/** Android channel the rider app creates (packages/agrimore_services NotificationService). */
export const RIDER_ORDER_CHANNEL_ID = "high_priority_channel";

function millis(v: unknown): number | null {
  if (v instanceof Timestamp) return v.toMillis();
  if (v instanceof Date) return v.getTime();
  if (typeof v === "number") return v;
  return null;
}

/**
 * When the rider was last heard from: the newest of the last location and
 * the last online/offline toggle (a rider who just went online has not sent
 * a location yet).
 */
export function lastHeardMs(p: FirebaseFirestore.DocumentData): number | null {
  const a = millis(p.lastLocationUpdate);
  const b = millis(p.lastStatusUpdate);
  if (a === null) return b;
  if (b === null) return a;
  return Math.max(a, b);
}

/**
 * Takes silent online riders offline. Returns the riders taken offline.
 *
 * DLV-D1: pages through EVERY online rider (it read only the first 400, so
 * riders beyond that were never swept), and each offline write carries the
 * document's update time as a precondition — a location that arrives after
 * the sweep read the rider makes that write fail, and the rider stays online
 * (it used to be overwritten). `beforeWrite` exists for the race suite only.
 */
export async function sweepSilentRiders(
  db: Db, nowMs: number, pageSize = 400, opts: { beforeWrite?: () => Promise<unknown> } = {}
): Promise<string[]> {
  const silent: FirebaseFirestore.QueryDocumentSnapshot[] = [];
  let last: FirebaseFirestore.QueryDocumentSnapshot | null = null;
  for (;;) {
    let q = db.collection("delivery_partners").where("isOnline", "==", true)
      .orderBy(FieldPath.documentId()).limit(pageSize);
    if (last) q = q.startAfter(last);
    const page = await q.get();
    for (const d of page.docs) {
      const heard = lastHeardMs(d.data());
      if (heard === null || nowMs - heard > SILENT_OFFLINE_MS) silent.push(d);
    }
    if (page.size < pageSize) break;
    last = page.docs[page.docs.length - 1];
  }
  if (!silent.length) return [];

  const active = await db.collection("orders")
    .where("orderStatus", "in", RIDER_ACTIVE_ORDER_STATUSES).get();
  const busy = new Set<string>();
  active.docs.forEach((o) => {
    const id = o.data().deliveryPartnerId;
    if (typeof id === "string" && id && holdsRider(o.data())) busy.add(id);
  });

  const candidates = silent.filter((d) => !busy.has(d.id));
  if (!candidates.length) return [];
  if (opts.beforeWrite) await opts.beforeWrite();
  const off: string[] = [];
  await Promise.all(candidates.map(async (d) => {
    try {
      await d.ref.update({
        isOnline: false,
        offlineReason: "no_location",
        offlineAt: Timestamp.fromMillis(nowMs),
        lastStatusUpdate: Timestamp.fromMillis(nowMs),
      }, { lastUpdateTime: d.updateTime });
      off.push(d.id);
    } catch (e: unknown) {
      // FAILED_PRECONDITION: the rider changed since we read it (a new
      // location, or they went offline themselves) — leave them be.
      const code = (e as { code?: number | string })?.code;
      if (code !== 9 && code !== "failed-precondition") throw e;
    }
  }));
  // DLV-N1: kept in the inbox too — the push may reach a phone that is off.
  await Promise.all(off.map((id) => tellRider(db, id, offlineNotice(nowMs), nowMs)));
  await Promise.all(off.map((id) => sendRiderPush(db, id, {
    title: "You're offline",
    body: "We haven't received your location for 15 minutes. Open the app to go online again.",
    data: { type: "rider_offline" },
  }).catch((e) => console.warn(`[presence] offline push to ${id} failed: ${e?.message ?? e}`))));
  return off.sort();
}

function tokensOf(data: FirebaseFirestore.DocumentData | undefined): string[] {
  if (!data) return [];
  const out = new Set<string>();
  if (Array.isArray(data.fcmTokens)) {
    data.fcmTokens.forEach((t: unknown) => { if (typeof t === "string" && t.trim()) out.add(t.trim()); });
  }
  if (typeof data.fcmToken === "string" && data.fcmToken.trim()) out.add(data.fcmToken.trim());
  return [...out];
}

/** A high-priority push to one rider's devices; drops dead tokens. */
export async function sendRiderPush(db: Db, riderId: string, m: {
  title: string; body: string; data: Record<string, string>;
}): Promise<number> {
  const userRef = db.collection("users").doc(riderId);
  const tokens = tokensOf((await userRef.get()).data());
  if (!tokens.length) return 0;
  let sent = 0;
  const invalid: string[] = [];
  for (const token of tokens) {
    try {
      await admin.messaging().send({
        token,
        notification: { title: m.title, body: m.body },
        data: { ...m.data, click_action: "FLUTTER_NOTIFICATION_CLICK" },
        android: {
          priority: "high",
          notification: {
            channelId: RIDER_ORDER_CHANNEL_ID,
            priority: "max",
            defaultSound: true,
            defaultVibrateTimings: true,
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
          },
        },
        apns: { headers: { "apns-priority": "10" }, payload: { aps: { sound: "default" } } },
      });
      sent += 1;
    } catch (e: unknown) {
      const code = (e as { code?: string })?.code;
      if (code === "messaging/invalid-registration-token" || code === "messaging/registration-token-not-registered") {
        invalid.push(token);
      }
    }
  }
  if (invalid.length) await userRef.update({ fcmTokens: FieldValue.arrayRemove(...invalid) });
  return sent;
}

/**
 * The pushes owed when an admin gives an order to a rider (or moves it):
 * the new rider is told, and a rider it was taken from is told too.
 * Returns who was notified, for the trigger's log and the suite.
 */
export function riderAssignmentChange(
  before: FirebaseFirestore.DocumentData, after: FirebaseFirestore.DocumentData
): { assignedTo: string | null; removedFrom: string | null } {
  const was = typeof before.deliveryPartnerId === "string" && before.deliveryPartnerId ? before.deliveryPartnerId : null;
  const now = typeof after.deliveryPartnerId === "string" && after.deliveryPartnerId ? after.deliveryPartnerId : null;
  if (after.deliveryAcceptedVia !== "admin" || !now || now === was) return { assignedTo: null, removedFrom: null };
  return { assignedTo: now, removedFrom: was };
}

export async function notifyRiderAssignment(
  db: Db, orderId: string, before: FirebaseFirestore.DocumentData, after: FirebaseFirestore.DocumentData
) {
  const change = riderAssignmentChange(before, after);
  if (!change.assignedTo) return change;
  const number = String(after.orderNumber ?? orderId);
  const nowMs = Date.now();
  await tellRider(db, change.assignedTo, assignedNotice(orderId, number), nowMs);
  if (change.removedFrom) await tellRider(db, change.removedFrom, unassignedNotice(orderId, number), nowMs);
  await sendRiderPush(db, change.assignedTo, {
    title: "New order assigned to you",
    body: `Order #${number} — open the app to see the pickup.`,
    data: { type: "delivery_assigned", orderId, orderNumber: number },
  });
  if (change.removedFrom) {
    await sendRiderPush(db, change.removedFrom, {
      title: "Order moved to another rider",
      body: `Order #${number} is no longer yours. You don't need to pick it up.`,
      data: { type: "delivery_unassigned", orderId, orderNumber: number },
    });
  }
  return change;
}
