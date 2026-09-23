// ============================================================
//  SELLER-OPS-1 — "Accepting orders" (ADR M-06), enforced at checkout
// ============================================================
//
// sellers/{uid}.acceptingOrders === false pauses the store. An optional
// pausedUntil (Timestamp) resumes it automatically once that moment has
// passed. A missing field means the store is open — every seller written
// before this phase keeps taking orders.

import * as admin from "firebase-admin";
import { HttpsError } from "firebase-functions/v2/https";

/** Pure — exported for tests. */
export function isSellerPaused(seller: Record<string, unknown> | undefined, nowMs: number): boolean {
  if (!seller || seller.acceptingOrders !== false) return false;
  const until = seller.pausedUntil;
  if (until instanceof admin.firestore.Timestamp) return until.toMillis() > nowMs;
  return true;
}

/** Throws failed-precondition when the seller is paused. */
export function assertSellerAcceptingOrders(seller: Record<string, unknown> | undefined, nowMs: number): void {
  if (!isSellerPaused(seller, nowMs)) return;
  const name = typeof seller?.shopName === "string" && seller.shopName ? seller.shopName : "This seller";
  const until = seller?.pausedUntil;
  const when =
    until instanceof admin.firestore.Timestamp
      ? ` until ${until.toDate().toLocaleDateString("en-IN", { day: "numeric", month: "short", timeZone: "Asia/Kolkata" })}`
      : "";
  throw new HttpsError("failed-precondition", `${name} isn't taking orders${when}. Remove their items or try again later.`);
}
