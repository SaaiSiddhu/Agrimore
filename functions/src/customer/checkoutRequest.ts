import { createHash } from "crypto";
import { isSafeProviderId } from "../common/paymentIntegrity";
import { MAX_CART_LINES } from "./orderPricing";

export interface CheckoutOrderReceipt {
  orderId: string;
  orderNumber: string;
  sellerId: string;
  total: number;
}

// Encoding the tuple avoids ambiguous UID/request concatenation. The anchor
// is server-only; clients recover it through the authenticated order command.
export function checkoutRequestDocId(uid: string, requestId: string): string {
  return createHash("sha256").update(JSON.stringify([uid, requestId])).digest("hex");
}

function canonicalJson(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(",")}]`;
  if (value !== null && typeof value === "object") {
    const object = value as Record<string, unknown>;
    return `{${Object.keys(object).sort().map(key => `${JSON.stringify(key)}:${canonicalJson(object[key])}`).join(",")}}`;
  }
  return JSON.stringify(value) ?? "null";
}

export function checkoutRequestFingerprint(intent: Record<string, unknown>): string {
  // Preserve array order: cart ordering can affect existing BOGO selection.
  // Object key order, in contrast, is a serialization detail.
  return createHash("sha256").update(canonicalJson(intent)).digest("hex");
}

export function isCheckoutOrderReceipt(value: unknown): value is CheckoutOrderReceipt[] {
  return Array.isArray(value) && value.length > 0 && value.length <= MAX_CART_LINES &&
    value.every(order => order && typeof order === "object" &&
      isSafeProviderId(order.orderId) && typeof order.orderNumber === "string" &&
      typeof order.sellerId === "string" && typeof order.total === "number" &&
      Number.isFinite(order.total) && order.total >= 0) &&
    new Set(value.map(order => order.orderId)).size === value.length;
}
