// ============================================================
//  Product Credit redemption restrictions — pure function
//  (Phase C: Product Credit redemption machinery)
// ============================================================
//
// computeRedeemableAmount() takes only already-fetched data and performs no
// Firestore access — same style as calculateBenefitForPeriod
// (benefitCalculation.ts). It never trusts a client-supplied
// `requestedAmount` as authoritative; it only ever narrows it down via caps
// derived from server-known values (available balance, program config,
// eligible cart value).
//
// Rounding discipline: the FINAL amount is always rounded DOWN
// (Math.floor), never to-nearest and never up — rounding up would apply
// more credit than the caps actually allow, i.e. over-crediting. Values fed
// INTO the cap computation (e.g. the percent-of-order cap itself) use the
// ordinary round-to-nearest `roundMoney` convention already established in
// createOrder.ts, since those are intermediate figures, not the final
// amount actually granted.

export interface RedemptionRulesProgram {
  redemptionEnabled: boolean;
  minOrderValueForRedemption: number;
  /** Absolute rupee cap. Null/undefined = no cap (treated as Infinity). */
  maxCreditPerOrder?: number | null;
  /** 0-100. Null/undefined = no percent cap. A configured 0 means "no
   *  credit at all", never "unlimited" — see the amount<=0 branch below. */
  maxCreditPercentOfOrder?: number | null;
}

export interface ComputeRedeemableAmountInput {
  program: RedemptionRulesProgram;
  /** Full cart subtotal — used only for the minimum-order-value check. */
  orderSubtotal: number;
  /** Sum of line items whose category is redemption-eligible (the whole
   *  subtotal when the program has no category restriction). Credit can
   *  never exceed the value of eligible goods in the cart. */
  eligibleSubtotal: number;
  availableCredit: number;
  /** An upper-bound REQUEST from the client — never trusted as the final
   *  amount; only ever narrows the caps below. */
  requestedAmount: number;
}

export interface ComputeRedeemableAmountResult {
  allowed: boolean;
  amount: number;
  reasons: string[];
}

function roundMoney(value: number): number {
  return Math.round(value * 100) / 100;
}

// A small epsilon guards against floating-point representation artifacts
// (e.g. 33.335 * 100 evaluating to 3333.4999999999995) turning a correct
// floor into an off-by-one-cent undercount.
function roundDownMoney(value: number): number {
  return Math.floor(value * 100 + 1e-9) / 100;
}

export function computeRedeemableAmount(input: ComputeRedeemableAmountInput): ComputeRedeemableAmountResult {
  const { program, orderSubtotal, eligibleSubtotal, availableCredit, requestedAmount } = input;

  // Rule 1: redemptionEnabled false.
  if (!program.redemptionEnabled) {
    return {
      allowed: false,
      amount: 0,
      reasons: ["Product Credit redemption is not enabled for this program"],
    };
  }

  // Rule 2: orderSubtotal below the configured minimum, with the shortfall.
  if (orderSubtotal < program.minOrderValueForRedemption) {
    const shortfall = roundMoney(program.minOrderValueForRedemption - orderSubtotal);
    return {
      allowed: false,
      amount: 0,
      reasons: [
        `Order subtotal is Rs.${shortfall} below the Rs.${program.minOrderValueForRedemption} minimum required for redemption`,
      ],
    };
  }

  // Rule 3: cap = min(requestedAmount, availableCredit, maxCreditPerOrder,
  // eligibleSubtotal * maxCreditPercentOfOrder/100, eligibleSubtotal).
  // Every term is clamped to >= 0 first — a negative requestedAmount, for
  // instance, must never make the min() spuriously permissive.
  const caps: number[] = [
    Math.max(0, requestedAmount),
    Math.max(0, availableCredit),
    Math.max(0, eligibleSubtotal),
  ];
  const hasMaxPerOrder = typeof program.maxCreditPerOrder === "number";
  if (hasMaxPerOrder) {
    caps.push(Math.max(0, program.maxCreditPerOrder as number));
  }
  const hasPercentCap = typeof program.maxCreditPercentOfOrder === "number";
  if (hasPercentCap) {
    caps.push(roundMoney(Math.max(0, (eligibleSubtotal * (program.maxCreditPercentOfOrder as number)) / 100)));
  }

  // Rule 4: round DOWN to 2 decimals — never round a cap up, that would
  // over-credit relative to what the rules actually allow.
  const amount = roundDownMoney(Math.min(...caps));

  // Rule 5: amount <= 0 -> allowed=false, with the most specific reason
  // available.
  if (amount <= 0) {
    const reasons: string[] = [];
    if (eligibleSubtotal <= 0) {
      reasons.push("No items in this order are eligible for Product Credit redemption");
    }
    if (availableCredit <= 0) {
      reasons.push("No Product Credit is available to redeem");
    }
    if (requestedAmount <= 0) {
      reasons.push("No credit amount was requested");
    }
    if (hasPercentCap && program.maxCreditPercentOfOrder === 0) {
      reasons.push("This program's maxCreditPercentOfOrder is 0 — no credit may be applied to any order");
    }
    if (hasMaxPerOrder && program.maxCreditPerOrder === 0) {
      reasons.push("This program's maxCreditPerOrder is 0 — no credit may be applied to any order");
    }
    if (reasons.length === 0) {
      reasons.push("Computed redeemable amount is zero");
    }
    return { allowed: false, amount: 0, reasons };
  }

  return { allowed: true, amount, reasons: [] };
}
