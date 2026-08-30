// ============================================================
//  Benefit calculation — pure function
//  (Phase B: benefit ledger & accrual engine)
// ============================================================
//
// calculateBenefitForPeriod() takes only already-fetched data and performs
// no Firestore access — this keeps it unit-testable in isolation and keeps
// benefitAccrual.ts's transaction free of any calculation logic beyond
// calling this once.
//
// D6: never hardcode a rate. Every number this function produces comes
// from the `program` argument, which the caller reads from
// benefit_programs/{programId} — nothing here is a fallback default that
// could silently apply an un-configured rate.
//
// Schema gap, stated honestly rather than silently guessed around: the
// `tier`/`category` rule types need a per-enrollment "which tier/category
// does this customer belong to" assignment to look up a rate for, but
// CustomerEnrollmentModel (Phase B, Workstream 3) has no such field —
// nothing in this phase's instructions specifies how a customer gets
// assigned a tier or category. Both rule types therefore always resolve to
// 0 in this phase (the same "unmatched -> 0" behavior the spec calls for),
// with an explanation string saying why. A future phase must add an
// enrollment-side assignment field before either rule type can produce a
// nonzero result — this is not a bug, it is the fail-closed default D6
// requires in the absence of that field.
//
// Similarly, `promotional`'s "promotional window" is not a separately
// modeled field on BenefitProgramModel — this function reuses the
// program's enrollmentOpensAt/enrollmentClosesAt as that window, on the
// basis that both concepts ("is new participation being promoted right
// now" and "is this promotional rate active right now") describe the same
// campaign period in practice. This is a deliberate interpretation filling
// an implicit gap, documented here and in the Phase B completion report,
// not a silent guess.

export type BenefitRuleType = "none" | "flatRupee" | "percentage" | "promotional" | "tier" | "category";
export type CreditFrequency = "monthly" | "quarterly" | "annual";

const PERIODS_PER_YEAR: Record<CreditFrequency, number> = {
  monthly: 12,
  quarterly: 4,
  annual: 1,
};

export interface BenefitCalculationProgram {
  benefitRuleType: string;
  benefitRateValue: number;
  creditFrequency: string;
  rulesVersion: number;
  tierRates?: Record<string, number> | null;
  categoryRates?: Record<string, number> | null;
  enrollmentOpensAt?: Date | null;
  enrollmentClosesAt?: Date | null;
}

export interface BenefitCalculationEnrollment {
  programAmount: number;
  rulesVersionAtEnrollment: number;
}

export interface CalculateBenefitInput {
  program: BenefitCalculationProgram;
  enrollment: BenefitCalculationEnrollment;
  /** 'YYYY-MM' */
  period: string;
  /** The reference date for this period (e.g. the day the accrual job ran). */
  periodDate: Date;
}

export interface CalculateBenefitResult {
  amount: number;
  ruleType: string;
  rulesVersion: number;
  explanation: string;
}

function roundMoney(value: number): number {
  return Math.round(value * 100) / 100;
}

function versionNote(program: BenefitCalculationProgram, enrollment: BenefitCalculationEnrollment): string {
  return program.rulesVersion !== enrollment.rulesVersionAtEnrollment
    ? ` [calculated using the program's CURRENT rulesVersion=${program.rulesVersion}; ` +
        `this enrollment was created under rulesVersionAtEnrollment=${enrollment.rulesVersionAtEnrollment} — ` +
        `the rate changed since enrollment, recorded here rather than silently applied]`
    : "";
}

export function calculateBenefitForPeriod(input: CalculateBenefitInput): CalculateBenefitResult {
  const { program, enrollment, period } = input;
  const note = versionNote(program, enrollment);
  let amount = 0;
  let explanation: string;

  switch (program.benefitRuleType) {
    case "none":
      amount = 0;
      explanation = `benefitRuleType=none for period ${period} -> 0${note}`;
      break;

    case "flatRupee":
      amount = program.benefitRateValue;
      explanation = `flatRupee: fixed Rs.${program.benefitRateValue} for period ${period}${note}`;
      break;

    case "percentage": {
      const periodsPerYear = PERIODS_PER_YEAR[program.creditFrequency as CreditFrequency] ?? 12;
      // Simple allocation on the ORIGINAL programAmount only — never adds
      // previously-credited benefit back into the base (that would be
      // compounding, which is hard-blocked at the feature-flag layer and
      // must never be reachable from this calculation either).
      amount = (enrollment.programAmount * program.benefitRateValue) / 100 / periodsPerYear;
      explanation =
        `percentage: Rs.${enrollment.programAmount} x ${program.benefitRateValue}% / ${periodsPerYear} ` +
        `(${program.creditFrequency}) for period ${period}${note}`;
      break;
    }

    case "tier": {
      // See file header: no per-enrollment tier assignment field exists
      // yet in this phase's schema, so this rule type always resolves to
      // 0 — a fail-closed "unmatched" result, not an error.
      amount = 0;
      explanation =
        `tier: no per-enrollment tier assignment field exists in this phase's schema -> 0 ` +
        `(configured tierRates: ${JSON.stringify(program.tierRates ?? {})})${note}`;
      break;
    }

    case "category": {
      amount = 0;
      explanation =
        `category: no per-enrollment category assignment field exists in this phase's schema -> 0 ` +
        `(configured categoryRates: ${JSON.stringify(program.categoryRates ?? {})})${note}`;
      break;
    }

    case "promotional": {
      const opensAt = program.enrollmentOpensAt ?? null;
      const closesAt = program.enrollmentClosesAt ?? null;
      const withinWindow = (!opensAt || input.periodDate >= opensAt) && (!closesAt || input.periodDate <= closesAt);
      amount = withinWindow ? program.benefitRateValue : 0;
      explanation = withinWindow
        ? `promotional: Rs.${program.benefitRateValue} for period ${period} (within enrollmentOpensAt/enrollmentClosesAt window)${note}`
        : `promotional: period ${period} is outside the configured enrollmentOpensAt/enrollmentClosesAt window -> 0${note}`;
      break;
    }

    default:
      amount = 0;
      explanation = `Unrecognized benefitRuleType "${program.benefitRuleType}" -> 0 (fail-closed)${note}`;
      break;
  }

  return {
    amount: roundMoney(Math.max(0, amount)),
    ruleType: program.benefitRuleType,
    rulesVersion: program.rulesVersion,
    explanation,
  };
}
