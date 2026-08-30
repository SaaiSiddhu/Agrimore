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
// RESOLVED (Phase C, Workstream 2): Phase B's `tier`/`category` rule types
// always resolved to 0 because CustomerEnrollmentModel had no per-enrollment
// tier/category assignment field. `benefitTierId`/`benefitCategoryId` now
// exist on the enrollment (Phase C) — both rule types look up that id in
// the program's `tierRates`/`categoryRates` map. An enrollment with no
// assignment, or an assignment that doesn't match any configured key, still
// resolves to 0 (fail-closed — D6: never a default positive rate).
//
// RESOLVED (Phase C, Workstream 2): `promotional` no longer reuses
// enrollmentOpensAt/enrollmentClosesAt — Phase B's stopgap conflated "when
// a customer may JOIN" with "when a promotional RATE applies", which are
// different questions and would have silently mis-priced a program that
// legitimately wanted both configured differently. BenefitProgramModel now
// has dedicated `promotionalFrom`/`promotionalTo` fields for this.

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
  promotionalFrom?: Date | null;
  promotionalTo?: Date | null;
}

export interface BenefitCalculationEnrollment {
  programAmount: number;
  rulesVersionAtEnrollment: number;
  benefitTierId?: string | null;
  benefitCategoryId?: string | null;
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
      const tierId = enrollment.benefitTierId ?? null;
      const rate = tierId ? program.tierRates?.[tierId] : undefined;
      if (tierId && typeof rate === "number") {
        amount = rate;
        explanation = `tier: enrollment assigned to tier "${tierId}" -> Rs.${rate} for period ${period}${note}`;
      } else {
        amount = 0;
        explanation = tierId
          ? `tier: enrollment's benefitTierId "${tierId}" has no matching rate in tierRates -> 0 ` +
            `(configured tierRates: ${JSON.stringify(program.tierRates ?? {})})${note}`
          : `tier: enrollment has no benefitTierId assigned -> 0${note}`;
      }
      break;
    }

    case "category": {
      const categoryId = enrollment.benefitCategoryId ?? null;
      const rate = categoryId ? program.categoryRates?.[categoryId] : undefined;
      if (categoryId && typeof rate === "number") {
        amount = rate;
        explanation = `category: enrollment assigned to category "${categoryId}" -> Rs.${rate} for period ${period}${note}`;
      } else {
        amount = 0;
        explanation = categoryId
          ? `category: enrollment's benefitCategoryId "${categoryId}" has no matching rate in categoryRates -> 0 ` +
            `(configured categoryRates: ${JSON.stringify(program.categoryRates ?? {})})${note}`
          : `category: enrollment has no benefitCategoryId assigned -> 0${note}`;
      }
      break;
    }

    case "promotional": {
      const from = program.promotionalFrom ?? null;
      const to = program.promotionalTo ?? null;
      const withinWindow = (!from || input.periodDate >= from) && (!to || input.periodDate <= to);
      amount = withinWindow ? program.benefitRateValue : 0;
      explanation = withinWindow
        ? `promotional: Rs.${program.benefitRateValue} for period ${period} (within promotionalFrom/promotionalTo window)${note}`
        : `promotional: period ${period} is outside the configured promotionalFrom/promotionalTo window -> 0${note}`;
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
