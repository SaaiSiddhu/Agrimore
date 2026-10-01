// Provider IDs are also document IDs and URL path components.
export function isSafeProviderId(value: unknown): value is string {
  return typeof value === "string" && /^[A-Za-z0-9_-]{1,200}$/.test(value);
}

// Server environment authority shared by payment verification and every
// economic consumer. Neither request flags nor provider key prefixes enable
// simulated money. Require loopback storage to isolate local financial tests.
export function isLocalPaymentEmulator(): boolean {
  return process.env.FUNCTIONS_EMULATOR === "true" && isLocalPaymentStorage();
}

// Provider-backed sandbox fixtures still require isolated financial storage,
// even when handlers are invoked directly without the Functions emulator.
export function isLocalPaymentStorage(): boolean {
  return /^(127\.0\.0\.1|localhost|\[::1\]):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST || "");
}

export function razorpayModeFromKey(keyId: string): "live" | "test" | undefined {
  if (keyId.startsWith("rzp_live_")) return "live";
  if (keyId.startsWith("rzp_test_")) return "test";
  return undefined;
}

// This is an additional guard, not an ownership or amount-due validator:
// callers still perform those checks and consume once in their transaction.
// Old wallet records lack currency/minor-unit/signature fields; retain their
// established INR contract while rejecting explicitly inconsistent metadata.
export function isSpendableCapturedPayment(
  payment: Record<string, unknown>,
  paymentId: unknown
): boolean {
  const amount = payment.amount;
  if (payment.status !== "captured" || typeof amount !== "number" ||
      !Number.isFinite(amount) || amount <= 0 ||
      !Number.isSafeInteger(Math.round(amount * 100)) || Math.round(amount * 100) < 1 ||
      (payment.currency !== undefined && payment.currency !== "INR") ||
      payment.signatureVerified === false) return false;
  if (payment.amountPaise !== undefined &&
      (!Number.isSafeInteger(payment.amountPaise) || payment.amountPaise !== Math.round(amount * 100))) return false;
  if (payment.paymentId !== undefined && payment.paymentId !== paymentId) return false;
  if (payment.providerMode !== undefined &&
      (payment.providerMode !== "live" && payment.providerMode !== "test")) return false;
  if (payment.providerMode === "test" && !isLocalPaymentStorage()) return false;

  const simulated = payment.isTest === true || payment.isTestOrder === true ||
    (typeof paymentId === "string" && paymentId.startsWith("pay_test_")) ||
    (typeof payment.orderId === "string" && payment.orderId.startsWith("order_test_"));
  return !simulated || isLocalPaymentEmulator();
}
