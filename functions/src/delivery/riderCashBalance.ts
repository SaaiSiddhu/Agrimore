// Shared cash authority for dispatch and money mutations; no callable dependencies.
function safeCashPaise(value: unknown): number | null {
  return typeof value === "number" && Number.isSafeInteger(value) && value >= 0 &&
    Math.round((value / 100) * 100) === value ? value : null;
}

/** A nonnegative rupee amount with exact, safely representable minor units. */
export function readCodAmountPaise(value: unknown): number | null {
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0) return null;
  const p = Math.round(value * 100);
  return Math.abs(value * 100 - p) < 1e-7 ? safeCashPaise(p) : null;
}

/** Explicit paise is authoritative; only absent legacy cash means zero. */
export function readRiderCashPaise(data: Record<string, unknown> | undefined): number | null {
  if (data && Object.prototype.hasOwnProperty.call(data, "cashHeldPaise")) {
    return safeCashPaise(data.cashHeldPaise);
  }
  if (data && Object.prototype.hasOwnProperty.call(data, "cashHeld")) {
    return readCodAmountPaise(data.cashHeld);
  }
  return 0;
}
