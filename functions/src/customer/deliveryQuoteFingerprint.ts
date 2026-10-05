import * as crypto from "crypto";
import { DeliveryFeeSchedule } from "./deliveryFeeSchedule";
import { OrderPricingItemInput } from "./orderPricing";

export function hashDeliveryQuoteValue(value: unknown): string {
  return crypto.createHash("sha256").update(JSON.stringify(value)).digest("hex");
}

export function fingerprintDeliveryItems(items: OrderPricingItemInput[]): string {
  return hashDeliveryQuoteValue([...items]
    .map((item) => ({ productId: item.productId, quantity: item.quantity, variantId: item.variantId ?? null }))
    .sort((a, b) => a.productId.localeCompare(b.productId) || String(a.variantId).localeCompare(String(b.variantId))));
}

export function distanceScheduleFingerprint(schedule: DeliveryFeeSchedule): string {
  return hashDeliveryQuoteValue(schedule);
}
