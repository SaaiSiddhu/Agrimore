/** Wallet debt can legitimately be negative after commission reversal. */
export function payoutBalancePaise(value: unknown): number | null {
  if (typeof value !== "number" || !Number.isFinite(value)) return null;
  const paise = Math.round(value * 100);
  return Number.isSafeInteger(paise) && Math.abs(value * 100 - paise) < 1e-7
    ? paise : null;
}

/** A safe integer may still lose a paise when encoded as the stored rupee double. */
export function payoutAmountFromPaise(paise: number): number | null {
  if (!Number.isSafeInteger(paise)) return null;
  const amount = paise / 100;
  return payoutBalancePaise(amount) === paise ? amount : null;
}
