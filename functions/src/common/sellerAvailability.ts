// ============================================================
//  SELLER-OPS-1 — "Accepting orders" (ADR M-06), enforced at checkout
// ============================================================
//
// sellers/{uid}.acceptingOrders === false pauses the store. An optional
// pausedUntil (Timestamp) resumes it automatically once that moment has
// passed. A missing field means the store is open — every seller written
// before this phase keeps taking orders.
//
// SELLER-OPS-2: weeklyOff (ISO weekdays, 1 = Monday … 7 = Sunday) and
// holidays ("YYYY-MM-DD") close the store for that whole Indian calendar
// day. Malformed entries are ignored.

import * as admin from "firebase-admin";
import { HttpsError } from "firebase-functions/v2/https";

/** Pure — exported for tests. */
export function isSellerPaused(seller: Record<string, unknown> | undefined, nowMs: number): boolean {
  if (!seller || seller.acceptingOrders !== false) return false;
  const until = seller.pausedUntil;
  if (until instanceof admin.firestore.Timestamp) return until.toMillis() > nowMs;
  return true;
}

const IST_OFFSET_MS = 330 * 60 * 1000;

/** The Indian calendar day of [nowMs]: ISO weekday and "YYYY-MM-DD". Pure. */
export function istDay(nowMs: number): { weekday: number; key: string } {
  const d = new Date(nowMs + IST_OFFSET_MS);
  const weekday = d.getUTCDay() === 0 ? 7 : d.getUTCDay();
  const key = d.toISOString().slice(0, 10);
  return { weekday, key };
}

export type ClosedReason = "paused" | "weeklyOff" | "holiday";

/** Why the store takes no orders right now, or null when it is open. Pure. */
export function sellerClosedReason(seller: Record<string, unknown> | undefined, nowMs: number): ClosedReason | null {
  if (!seller) return null;
  if (isSellerPaused(seller, nowMs)) return "paused";
  const { weekday, key } = istDay(nowMs);
  const off = Array.isArray(seller.weeklyOff) ? seller.weeklyOff : [];
  if (off.some((d) => d === weekday)) return "weeklyOff";
  const holidays = Array.isArray(seller.holidays) ? seller.holidays : [];
  if (holidays.some((h) => h === key)) return "holiday";
  return null;
}

/** Throws failed-precondition when the seller is paused or closed today. */
export function assertSellerAcceptingOrders(seller: Record<string, unknown> | undefined, nowMs: number): void {
  const reason = sellerClosedReason(seller, nowMs);
  if (reason === null) return;
  const name = typeof seller?.shopName === "string" && seller.shopName ? seller.shopName : "This seller";
  if (reason !== "paused") {
    throw new HttpsError("failed-precondition", `${name} is closed today. Remove their items or try again tomorrow.`);
  }
  const until = seller?.pausedUntil;
  const when =
    until instanceof admin.firestore.Timestamp
      ? ` until ${until.toDate().toLocaleDateString("en-IN", { day: "numeric", month: "short", timeZone: "Asia/Kolkata" })}`
      : "";
  throw new HttpsError("failed-precondition", `${name} isn't taking orders${when}. Remove their items or try again later.`);
}
