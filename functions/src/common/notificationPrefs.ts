// ============================================================
//  SELLER-ACCOUNT-1b — notification preferences, honoured by the sender
// ============================================================
//
// users/{uid}/settings/notifications (owner-written, schema-checked in
// firestore.rules):
//   { orders, quotes, payments, stock, reviews, announcements: bool,
//     quietHours: bool, quietStartMin, quietEndMin: 0–1439 (IST) }
// A category switched off, or quiet hours, suppress the PUSH only — the
// inbox entry is always written, so nothing is lost.

import * as admin from "firebase-admin";

export type NotificationCategory = "orders" | "quotes" | "payments" | "stock" | "reviews" | "announcements";

const IST_OFFSET_MIN = 330;
const DAY_MIN = 24 * 60;

/** Category of a notification `type` (orderNotifications, rfq, payouts, …). */
export function categoryOfType(type: string): NotificationCategory {
  const t = type.toLowerCase();
  if (t.startsWith("rfq")) return "quotes";
  if (t.startsWith("payout")) return "payments";
  if (t.includes("stock")) return "stock";
  if (t.includes("review")) return "reviews";
  if (t.includes("order")) return "orders";
  return "announcements";
}

/** Minutes since midnight IST for [ms]. */
export function istMinuteOfDay(ms: number): number {
  const m = Math.floor(ms / 60000) + IST_OFFSET_MIN;
  return ((m % DAY_MIN) + DAY_MIN) % DAY_MIN;
}

function inQuietWindow(minute: number, start: number, end: number): boolean {
  if (start === end) return false;
  return start < end ? minute >= start && minute < end : minute >= start || minute < end; // wraps midnight
}

/** Pure decision — exported for tests. Missing prefs = everything allowed. */
export function pushAllowed(prefs: Record<string, unknown> | undefined, type: string, nowMs: number): boolean {
  if (!prefs) return true;
  if (prefs[categoryOfType(type)] === false) return false;
  const start = prefs.quietStartMin;
  const end = prefs.quietEndMin;
  if (prefs.quietHours === true && typeof start === "number" && typeof end === "number") {
    if (inQuietWindow(istMinuteOfDay(nowMs), start, end)) return false;
  }
  return true;
}

/** Reads the user's preferences (best-effort: a read failure allows push). */
export async function shouldPush(userId: string, type: string, nowMs = Date.now()): Promise<boolean> {
  try {
    const snap = await admin.firestore().collection("users").doc(userId).collection("settings").doc("notifications").get();
    return pushAllowed(snap.exists ? snap.data() : undefined, type, nowMs);
  } catch (e) {
    console.error(`Notification preferences read failed for ${userId}`, e);
    return true;
  }
}
