// ============================================================
//  Per-seller delivery fee schedule (Phase FIX-8, Workstream 1)
// ============================================================
//
// D-DELIVERY-FEE (owner decision, 2026-09-07): per-seller, and each seller
// picks their own fee shape. This file ships flat and slab only — see the
// ledger row for why distance-based is a deferred follow-up.
//
// A seller can write ANY value to sellers/{sellerId}.deliveryFeeSchedule
// directly (firestore.rules' own ownerCannotApproveSellerStatus() only
// denylists the 'status' field — confirmed by reading the sellers match
// block fresh). This file is therefore the ONLY validation a schedule ever
// gets: parseDeliveryFeeSchedule() must reject anything malformed rather
// than trust it, and computeFeeFromSchedule() enforces the SAME sanity
// ceiling orderPricing.ts's legacy client-supplied path already has
// (MAX_REASONABLE_DELIVERY_CHARGE) — a seller's schedule must never be able
// to charge a customer more than an unconfigured seller already could.

import { HttpsError } from "firebase-functions/v2/https";

// Mirrors orderPricing.ts's own MAX_REASONABLE_DELIVERY_CHARGE exactly — a
// schedule-computed fee must never exceed what the legacy, client-supplied
// path already caps at. Duplicated (not imported) because orderPricing.ts
// does not export it and importing across these two files in either
// direction risks the exact circular-dependency mess Cloud Functions'
// single build output makes easy to introduce by accident; both values
// must be changed together if either ever does.
const MAX_REASONABLE_DELIVERY_FEE = 1000;

export interface FlatFeeSchedule {
  type: "flat";
  amount: number;
}

export interface SlabFeeSchedule {
  type: "slab";
  /** Sorted ascending by minOrderValue at write time is NOT assumed —
   *  computeFeeFromSchedule sorts defensively. Must include a slab with
   *  minOrderValue 0 (enforced by parseDeliveryFeeSchedule) so every
   *  non-negative subtotal always matches at least one slab — a schedule
   *  is either fully usable or treated as absent, never partially. */
  slabs: Array<{ minOrderValue: number; fee: number }>;
}

export type DeliveryFeeSchedule = FlatFeeSchedule | SlabFeeSchedule;

const MAX_SLABS = 10;

/**
 * Validates a raw Firestore field value into a typed schedule. Returns
 * null for anything absent or malformed — a malformed schedule falls back
 * to the legacy client-supplied-with-ceiling behaviour rather than
 * crashing an order, since it can only arise from a seller bypassing the
 * (not-yet-built) config screen's own validation directly, not a normal
 * path any real seller reaches through the app.
 */
export function parseDeliveryFeeSchedule(raw: unknown): DeliveryFeeSchedule | null {
  if (typeof raw !== "object" || raw === null) return null;
  const data = raw as Record<string, unknown>;

  if (data.type === "flat") {
    const amount = data.amount;
    if (typeof amount !== "number" || !Number.isFinite(amount) || amount < 0) return null;
    if (amount > MAX_REASONABLE_DELIVERY_FEE) return null;
    return { type: "flat", amount };
  }

  if (data.type === "slab") {
    const rawSlabs = data.slabs;
    if (!Array.isArray(rawSlabs) || rawSlabs.length === 0 || rawSlabs.length > MAX_SLABS) return null;

    const slabs: Array<{ minOrderValue: number; fee: number }> = [];
    let hasZeroSlab = false;
    for (const rawSlab of rawSlabs) {
      if (typeof rawSlab !== "object" || rawSlab === null) return null;
      const minOrderValue = (rawSlab as Record<string, unknown>).minOrderValue;
      const fee = (rawSlab as Record<string, unknown>).fee;
      if (typeof minOrderValue !== "number" || !Number.isFinite(minOrderValue) || minOrderValue < 0) return null;
      if (typeof fee !== "number" || !Number.isFinite(fee) || fee < 0) return null;
      if (fee > MAX_REASONABLE_DELIVERY_FEE) return null;
      if (minOrderValue === 0) hasZeroSlab = true;
      slabs.push({ minOrderValue, fee });
    }
    if (!hasZeroSlab) return null;

    return { type: "slab", slabs };
  }

  return null;
}

/**
 * Computes a seller's own delivery fee for their own subtotal from an
 * already-validated schedule. Throws (never silently charges 0 or an
 * unbounded amount) if the schedule is somehow unusable at this point —
 * parseDeliveryFeeSchedule should have already rejected anything that
 * would reach here in that state, so this is defence-in-depth, not the
 * primary validation.
 */
export function computeFeeFromSchedule(schedule: DeliveryFeeSchedule, sellerSubtotal: number): number {
  if (schedule.type === "flat") {
    return schedule.amount;
  }

  // slab: the highest minOrderValue that does not exceed the subtotal.
  const sorted = [...schedule.slabs].sort((a, b) => a.minOrderValue - b.minOrderValue);
  let matched: { minOrderValue: number; fee: number } | null = null;
  for (const slab of sorted) {
    if (slab.minOrderValue <= sellerSubtotal) {
      matched = slab;
    } else {
      break;
    }
  }
  if (!matched) {
    // Unreachable when parseDeliveryFeeSchedule's hasZeroSlab check passed
    // and sellerSubtotal >= 0 — kept as a hard failure, not a silent 0,
    // in case that invariant is ever violated by a future change.
    throw new HttpsError(
      "internal",
      "Delivery fee schedule has no matching slab for this order — contact support"
    );
  }
  return matched.fee;
}
