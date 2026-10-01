// ============================================================
//  Associate Onboarding Configuration — Phase 16A, Workstream 1
// ============================================================
//
// settings/associate_onboarding (Firestore) is the single source of truth
// for the one-time Registration & Onboarding Fee amount AND for every
// word of the onboarding page's copy — mirroring the settings/commission
// precedent that functions/src/customer/employeeCommission.ts already
// reads from. loadOnboardingConfig() below is the ONLY place in this
// codebase that reads this document; every other function that needs the
// fee amount, the enabled flag, or the copy deck goes through this loader.
// NEVER hardcode the fee amount anywhere else in this codebase.
//
// Two independent kinds of "invalid" are tracked here, deliberately kept
// separate:
//   - fee/config validity (`valid`/`isEnabled`) — gates whether money can
//     move at all (order creation, activation). Invalid here means every
//     caller must refuse outright (fail closed).
//   - copy validity (`copyFallbackReason`) — only affects which COPY is
//     served (admin-authored vs. this file's DEFAULT_ONBOARDING_COPY). A
//     copy problem never affects whether the fee itself is charged.
//
// Phase 16B-4: no string below may hardcode a currency amount. Every
// fee-bearing sentence — in DEFAULT_ONBOARDING_COPY AND in
// MANDATORY_ONBOARDING_DISCLOSURES — uses the FEE_TOKEN placeholder
// ("{{fee}}") instead. `loadOnboardingConfig()` itself returns `copy` and
// `mandatoryDisclosures` STILL CARRYING that placeholder, unrendered —
// interpolation happens ONLY at the client-facing boundary
// (getAssociateOnboardingConfig.ts), not here, because loadOnboardingConfig
// has TWO OTHER, money-path callers (createAssociateOnboardingPayment.ts,
// activationCore.ts) that never read `copy` at all, and because
// phase16a_activation_test.js asserts `loaded.mandatoryDisclosures`/
// `loaded.copy.summaryCard.feeLine` against the RAW MANDATORY_ONBOARDING_
// DISCLOSURES/DEFAULT_ONBOARDING_COPY module constants — interpolating
// here would compare rendered text against an unrendered template and
// break both assertions. An admin-supplied `copy` override is scanned, in
// its own RAW form (before any interpolation exists to do), for a
// currency literal that disagrees with `feeAmount` (`findFeeMismatches`)
// — a mismatch falls back to the default copy, exactly like
// `prohibited_claim` already does. See the "Fee-amount templating" and
// "Fee-mismatch guard" sections below for the interpolation/detection
// functions themselves — both exported so
// getAssociateOnboardingConfig.ts (the boundary) and
// scripts/phase16b4_fee_single_source_test.js can use them directly.

import * as admin from "firebase-admin";
import { isExactMoneyAmount } from "../common/paymentIntegrity";

export const ONBOARDING_PURPOSE = "associate_onboarding";
const SETTINGS_COLLECTION = "settings";
const ONBOARDING_CONFIG_DOC_ID = "associate_onboarding";

// "One named constant for the fallback" (Workstream 1b) — deliberately NOT
// a numeric fee value. The fallback for a missing/invalid fee config is
// INVALIDITY itself, never a hardcoded amount — see the module comment
// above. This constant exists so every caller can recognise "no usable
// config" through one shared shape instead of re-deriving it.
export const INVALID_FEE_CONFIG_FALLBACK = {
  valid: false,
  isEnabled: false,
  feeAmount: null as number | null,
  currency: null as string | null,
} as const;

// ------------------------------------------------------------
// Mandatory disclosures — Workstream 1c
// ------------------------------------------------------------
// These are a TypeScript constant, NOT stored in Firestore, specifically
// so no admin edit and no client build can ever ship the onboarding page
// without them. loadOnboardingConfig() always returns exactly this array
// (still carrying the FEE_TOKEN placeholder — Phase 16B-4; see the module
// comment above for why interpolation happens only at the
// getAssociateOnboardingConfig.ts boundary) as `mandatoryDisclosures`,
// regardless of anything present (or absent) in the Firestore document's
// own `copy.mandatoryDisclosures` — that field, if present in Firestore,
// is never read by this module at all. Plain, non-promissory language
// throughout; no fixed earnings figures anywhere.
export const MANDATORY_ONBOARDING_DISCLOSURES: readonly string[] = [
  "The Registration & Onboarding Fee of {{fee}} is a one-time payment, charged once when you complete registration.",
  "This is not a monthly or recurring subscription charge.",
  "Registering as an AgriMore Sales Associate does not guarantee employment or any income.",
  "AgriMore does not guarantee any specific monthly earnings.",
  "Earnings depend on your actual sales activity and the commission structure applicable at the time of each sale.",
  "Commission is paid only on eligible orders under AgriMore's current commission policy.",
  "Incentives and performance rewards are subject to eligibility criteria and are not guaranteed.",
  "Commission structures may vary between products and may change over time.",
];

// ------------------------------------------------------------
// Prohibited-claim guard — Workstream 1d
// ------------------------------------------------------------
// Case-insensitive substring backstop against the most common
// promissory-earnings phrasings. Documented explicitly, here and in the
// completion report: this is a backstop against obviously non-compliant
// copy, NOT a complete compliance/legal review — an admin can still write
// technically-compliant-sounding copy that implies guaranteed income
// without tripping any of these exact phrases. Human review of any
// settings/associate_onboarding edit is still required.
export const PROHIBITED_CLAIM_PHRASES: readonly string[] = [
  "guaranteed income",
  "guaranteed salary",
  "guaranteed return",
  "guaranteed earning",
  "assured income",
  "assured return",
  "earn ₹",
  "earn rs",
  "instant income",
  "join and earn",
  "fixed salary",
  "monthly salary",
];

function collectStringLeaves(value: unknown, out: string[]): void {
  if (typeof value === "string") {
    out.push(value);
  } else if (Array.isArray(value)) {
    for (const item of value) collectStringLeaves(item, out);
  } else if (value && typeof value === "object") {
    for (const key of Object.keys(value as Record<string, unknown>)) {
      collectStringLeaves((value as Record<string, unknown>)[key], out);
    }
  }
}

export function findProhibitedClaims(copy: unknown): string[] {
  const leaves: string[] = [];
  collectStringLeaves(copy, leaves);
  const haystack = leaves.join(" \n ").toLowerCase();
  return PROHIBITED_CLAIM_PHRASES.filter((phrase) => haystack.includes(phrase));
}

// ------------------------------------------------------------
// Fee-amount templating — Phase 16B-4
// ------------------------------------------------------------
// The ONE placeholder every fee-bearing string in this file's copy must
// use instead of a hardcoded amount. Never hardcode a currency amount
// anywhere below this point — interpolate this token instead.
export const FEE_TOKEN = "{{fee}}";

// Substituted for FEE_TOKEN whenever there is no authoritative amount to
// show (feeAmount is null/invalid — exactly when `valid === false`).
// Deliberately: never a number, never the raw token left visible, and
// deliberately lowercase/mid-sentence-safe — none of the seven templated
// strings in DEFAULT_ONBOARDING_COPY or MANDATORY_ONBOARDING_DISCLOSURES
// place FEE_TOKEN as the first word of a sentence, specifically so this
// phrase never needs to carry its own capitalisation.
export const NEUTRAL_FEE_PHRASE = "the applicable amount";

// Mirrors apps/marketplace/lib/screens/employee/onboarding/widgets/
// onboarding_fee_text.dart's authoritativeFeeText() exactly: INR renders
// with the ₹ symbol, whole rupees with no decimals, fractional rupees
// with two. A non-INR currency never renders ₹ — it renders
// "<CURRENCY CODE> <amount>" instead (e.g. "USD 100.00"); this product
// does not support multi-currency display beyond that, and this function
// does not invent any.
export function formatFeeAmountForDisplay(feeAmount: number, currency: string): string {
  const hasFraction = feeAmount !== Math.round(feeAmount);
  if (currency.toUpperCase() === "INR") {
    const formatter = new Intl.NumberFormat("en-IN", {
      minimumFractionDigits: hasFraction ? 2 : 0,
      maximumFractionDigits: hasFraction ? 2 : 0,
    });
    return `₹${formatter.format(feeAmount)}`;
  }
  const formatter = new Intl.NumberFormat("en-US", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
  return `${currency.toUpperCase()} ${formatter.format(feeAmount)}`;
}

// Walks the exact same shape collectStringLeaves() above already knows how
// to walk (string / array / plain object), replacing every FEE_TOKEN
// occurrence in every string leaf with `replacement`. Returns a NEW
// structure — never mutates `value`, since `value` may be the shared
// DEFAULT_ONBOARDING_COPY / MANDATORY_ONBOARDING_DISCLOSURES module
// constants, which every request shares.
function interpolateFeeToken<T>(value: T, replacement: string): T {
  if (typeof value === "string") {
    return value.split(FEE_TOKEN).join(replacement) as unknown as T;
  }
  if (Array.isArray(value)) {
    return value.map((item) => interpolateFeeToken(item, replacement)) as unknown as T;
  }
  if (value && typeof value === "object") {
    const out: Record<string, unknown> = {};
    for (const key of Object.keys(value as Record<string, unknown>)) {
      out[key] = interpolateFeeToken((value as Record<string, unknown>)[key], replacement);
    }
    return out as unknown as T;
  }
  return value;
}

// The single entry point getAssociateOnboardingConfig.ts (the client-facing
// boundary — see this file's header comment) uses to interpolate BOTH
// `copy` and `mandatoryDisclosures` from loadOnboardingConfig()'s
// still-templated return value, with the SAME replacement for both, so
// they can never disagree with each other about the fee. Exported (not
// just module-internal) so a script can unit-test interpolation directly,
// without needing a fake Firestore.
export function interpolateFeeAmount<T>(value: T, feeAmount: number | null, currency: string | null): T {
  const replacement =
    feeAmount !== null && currency !== null
      ? formatFeeAmountForDisplay(feeAmount, currency)
      : NEUTRAL_FEE_PHRASE;
  return interpolateFeeToken(value, replacement);
}

// ------------------------------------------------------------
// Fee-mismatch guard — Phase 16B-4, Workstream 2
// ------------------------------------------------------------
// Matches ₹<amount>, Rs/Rs.<amount>, and INR <amount> — case-insensitive,
// optional space, optional thousands separators, optional decimals — in the
// admin's RAW, uninterpolated copy (loadOnboardingConfig calls this against
// `raw.copy` directly — admins type real numbers; they don't know about
// FEE_TOKEN, so there is nothing to interpolate before scanning). Any
// amount found is a literal the admin typed, which either agrees with
// `feeAmount` (fine) or doesn't (exactly what this guard exists to catch).
// `\b` before "rs"/"inr" avoids matching inside ordinary words ("hours",
// "years", "Users") — there is no word-boundary transition before the
// "rs"/"inr" substring in any of those, so the pattern never fires on them.
const CURRENCY_MENTION_PATTERN = /(?:₹|\brs\.?|\binr)\s*([\d][\d,]*(?:\.\d+)?)/gi;

// Copy scanning retains its spelling tolerance. Financial activation uses
// exact provider minor units in matchesMoneyInPaise, independently of copy.
const FEE_MISMATCH_TOLERANCE = 0.01;

// Reuses collectStringLeaves — the exact traversal interpolateFeeToken()
// mirrors — so this scanner sees every string leaf the client could ever
// render, not a hand-picked subset. Returns the offending leaf strings
// (empty array = no mismatch).
export function findFeeMismatches(copy: unknown, feeAmount: number): string[] {
  const leaves: string[] = [];
  collectStringLeaves(copy, leaves);
  const offenders: string[] = [];
  for (const leaf of leaves) {
    CURRENCY_MENTION_PATTERN.lastIndex = 0;
    let match: RegExpExecArray | null;
    while ((match = CURRENCY_MENTION_PATTERN.exec(leaf)) !== null) {
      const parsed = parseFloat(match[1].replace(/,/g, ""));
      if (!Number.isFinite(parsed)) continue;
      if (Math.abs(parsed - feeAmount) > FEE_MISMATCH_TOLERANCE) {
        offenders.push(leaf);
        break;
      }
    }
  }
  return offenders;
}

// ------------------------------------------------------------
// Copy shape + default (server-authored) copy deck
// ------------------------------------------------------------
export interface OnboardingBenefitGroup {
  key: string;
  title: string;
  items: string[];
}

export interface OnboardingCopy {
  headline: string;
  feeLabel: string;
  supportingStatement: string;
  whyTheFeeExists: { title: string; body: string[] };
  benefitGroups: OnboardingBenefitGroup[];
  earningsExplainer: {
    title: string;
    body: string[];
    flowSteps: string[];
    variabilityFactors: string[];
  };
  journeySteps: { step: number; title: string; body: string }[];
  summaryCard: {
    title: string;
    feeLine: string;
    includes: string[];
    ctaLabel: string;
    ctaSubtext: string;
  };
  supportContact: { title: string; body: string; email: string; phone: string };
}

const REQUIRED_TOP_LEVEL_COPY_KEYS: (keyof OnboardingCopy)[] = [
  "headline",
  "feeLabel",
  "supportingStatement",
  "whyTheFeeExists",
  "benefitGroups",
  "earningsExplainer",
  "journeySteps",
  "summaryCard",
  "supportContact",
];

// Product spec source: Phase 16A prompt, Section 13. "Sales Associate"
// naming applied throughout per Decision D1. No fixed-figure earnings
// claims anywhere in this deck.
export const DEFAULT_ONBOARDING_COPY: OnboardingCopy = {
  headline: "AgriMore Sales Associate Registration & Onboarding",
  feeLabel: "One-Time Registration & Onboarding Fee: {{fee}}",
  supportingStatement:
    "Complete your AgriMore onboarding and gain access to the tools, training, product catalogue, sales platform, commission tracking, and support you need to start retail sales. This is a one-time payment of {{fee}} — it is not a monthly or recurring subscription charge.",
  whyTheFeeExists: {
    title: "Why this fee exists",
    body: [
      "A one-time Registration & Onboarding Fee of {{fee}} is collected to activate your associate account and provide access to AgriMore's sales tools, resources, training, platform access, and support services.",
      "This covers the complete sales ecosystem required to promote AgriMore products, manage customer orders, monitor your sales activity, and track applicable commissions.",
    ],
  },
  benefitGroups: [
    {
      key: "account_platform",
      title: "Account & Platform Access",
      items: [
        "AgriMore Associate ID",
        "App login access",
        "Personal dashboard",
        "Digital product catalogue",
        "Product prices & details",
        "Eligible product information",
      ],
    },
    {
      key: "retail_sales",
      title: "Retail Sales",
      items: [
        "Work-from-home retail sales access",
        "Customer order collection",
        "Order placement through the AgriMore app",
        "Order processing support",
        "Customer handling support",
      ],
    },
    {
      key: "commission_tracking",
      title: "Commission & Performance Tracking",
      items: [
        "Commission on successful eligible sales",
        "Daily sales tracking",
        "Monthly sales tracking",
        "Commission tracking",
        "Monthly commission statement",
        "Payment history",
        "Performance-based incentives",
        "Performance-based rewards",
      ],
    },
    {
      key: "training",
      title: "Training & Sales Enablement",
      items: [
        "Product training",
        "Sales training",
        "Customer handling guidance",
        "Sales support resources",
      ],
    },
    {
      key: "marketing",
      title: "Marketing Resources",
      items: [
        "Product images",
        "Marketing posters",
        "Promotional creatives",
        "WhatsApp marketing materials",
        "Social media marketing materials",
      ],
    },
    {
      key: "support",
      title: "Support",
      items: [
        "Dedicated associate support",
        "Order support",
        "Sales assistance",
        "Platform assistance",
      ],
    },
  ],
  earningsExplainer: {
    title: "Earn Through Successful Sales",
    body: [
      "As an AgriMore Sales Associate, you can promote AgriMore products to customers from home, assist with product selection, receive customer orders, and place those orders through the AgriMore platform.",
      "For eligible, successfully completed orders, you can earn commission according to the applicable product commission structure in effect at the time of sale.",
    ],
    flowSteps: ["Customer Order", "Successful Order", "Applicable Commission", "Associate Earnings"],
    variabilityFactors: [
      "Product",
      "Order value",
      "Applicable commission percentage",
      "Campaign or incentive structure",
      "Eligibility conditions",
    ],
  },
  journeySteps: [
    { step: 1, title: "Register", body: "Submit your registration details." },
    { step: 2, title: "Complete Onboarding ({{fee}})", body: "Pay the one-time Registration & Onboarding Fee." },
    { step: 3, title: "Account Activation", body: "Receive your AgriMore Associate ID and app access." },
    {
      step: 4,
      title: "Complete Training",
      body: "Learn about products, the sales process, customer handling, and order placement.",
    },
    { step: 5, title: "Start Selling", body: "Promote products and receive customer orders." },
    { step: 6, title: "Place Orders", body: "Submit customer orders through the AgriMore platform." },
    {
      step: 7,
      title: "Earn Commission",
      body: "Receive applicable commission on eligible, successful sales.",
    },
  ],
  summaryCard: {
    title: "AgriMore Associate Onboarding",
    feeLine: "One-Time Fee: {{fee}}",
    includes: [
      "Associate ID",
      "App Access",
      "Digital Product Catalogue",
      "Sales Dashboard",
      "Order Placement Access",
      "Commission Tracking",
      "Sales & Product Training",
      "Marketing Materials",
      "Dedicated Support",
      "Incentives & Rewards Eligibility",
    ],
    ctaLabel: "Complete Registration — {{fee}}",
    ctaSubtext: "One-Time Onboarding Fee • No Monthly Registration Charge",
  },
  supportContact: {
    title: "Need help?",
    body: "Contact AgriMore Sales Associate support for any questions about registration, onboarding, or your application.",
    email: "support@agrimore.in",
    phone: "",
  },
};

function isCopyStructurallyValid(copy: unknown): copy is OnboardingCopy {
  if (!copy || typeof copy !== "object") return false;
  const c = copy as Record<string, unknown>;
  for (const key of REQUIRED_TOP_LEVEL_COPY_KEYS) {
    if (!(key in c)) return false;
  }
  if (!Array.isArray(c.benefitGroups)) return false;
  if (!Array.isArray(c.journeySteps)) return false;
  if (typeof c.headline !== "string" || !c.headline.trim()) return false;
  if (typeof c.feeLabel !== "string" || !c.feeLabel.trim()) return false;
  if (!c.summaryCard || typeof c.summaryCard !== "object") return false;
  if (!c.earningsExplainer || typeof c.earningsExplainer !== "object") return false;
  return true;
}

// ------------------------------------------------------------
// Fee/config validation
// ------------------------------------------------------------
// Phase 16B-4: "fee_mismatch" added — an admin copy override whose
// interpolated fee text disagrees with the authoritative feeAmount falls
// back to the (interpolated, correct-by-construction) default copy,
// exactly like "prohibited_claim" already does.
export type CopyFallbackReason = "missing" | "malformed" | "prohibited_claim" | "fee_mismatch";
export type UnavailableReason = "config_missing" | "config_invalid" | "disabled";

export interface LoadedOnboardingConfig {
  valid: boolean;
  isEnabled: boolean;
  feeAmount: number | null;
  currency: string | null;
  configVersion: number;
  copy: OnboardingCopy;
  mandatoryDisclosures: readonly string[];
  copyFallbackReason?: CopyFallbackReason;
  violatedPhrases?: string[];
  unavailableReason?: UnavailableReason;
}

// Accepts either a plain Firestore instance OR an in-flight transaction —
// Workstream 5's activation core must read this document as one of ITS
// OWN reads, inside its own transaction, before any of that transaction's
// writes (Firestore requires all reads before all writes). Every other
// caller (getAssociateOnboardingConfig, createAssociateOnboardingPayment)
// calls this with no transaction, which just does a plain .get().
export async function loadOnboardingConfig(
  db: admin.firestore.Firestore,
  tx?: admin.firestore.Transaction
): Promise<LoadedOnboardingConfig> {
  const ref = db.collection(SETTINGS_COLLECTION).doc(ONBOARDING_CONFIG_DOC_ID);
  const snap = tx ? await tx.get(ref) : await ref.get();

  if (!snap.exists) {
    // Phase 16B-4 note: `copy`/`mandatoryDisclosures` are returned here
    // STILL CARRYING the FEE_TOKEN placeholder, unrendered — see this
    // function's own header comment for why interpolation happens only at
    // the client-facing boundary (getAssociateOnboardingConfig.ts), not
    // here.
    return {
      ...INVALID_FEE_CONFIG_FALLBACK,
      configVersion: 0,
      copy: DEFAULT_ONBOARDING_COPY,
      mandatoryDisclosures: MANDATORY_ONBOARDING_DISCLOSURES,
      copyFallbackReason: "missing",
      unavailableReason: "config_missing",
    };
  }

  const raw = snap.data() || {};

  const feeAmountRaw = raw.feeAmount;
  const feeAmountValid = isExactMoneyAmount(feeAmountRaw);

  const currencyRaw = raw.currency;
  const currencyValid = typeof currencyRaw === "string" && currencyRaw.trim().length === 3;

  const valid = feeAmountValid && currencyValid;
  const isEnabled = valid && raw.isEnabled === true;
  const configVersion = typeof raw.version === "number" ? raw.version : 0;

  let copy: OnboardingCopy = DEFAULT_ONBOARDING_COPY;
  let copyFallbackReason: CopyFallbackReason | undefined;
  let violatedPhrases: string[] | undefined;

  if (raw.copy === undefined || raw.copy === null) {
    copyFallbackReason = "missing";
  } else if (!isCopyStructurallyValid(raw.copy)) {
    copyFallbackReason = "malformed";
  } else {
    const claims = findProhibitedClaims(raw.copy);
    // Phase 16B-4, Workstream 2: admin-authored copy stating a rupee figure
    // that disagrees with the authoritative feeAmount falls back to the
    // default copy, exactly like prohibited_claim below. Scans raw.copy —
    // the admin's OWN literal text (admins type real numbers; they don't
    // know about FEE_TOKEN) — so this needs no interpolation step first.
    // Only runs when feeAmountValid: with no authoritative figure there is
    // nothing to disagree with.
    const feeMismatches = feeAmountValid ? findFeeMismatches(raw.copy, feeAmountRaw as number) : [];
    if (claims.length > 0) {
      copyFallbackReason = "prohibited_claim";
      violatedPhrases = claims;
    } else if (feeMismatches.length > 0) {
      copyFallbackReason = "fee_mismatch";
      violatedPhrases = feeMismatches;
    } else {
      copy = raw.copy as OnboardingCopy;
    }
  }

  let unavailableReason: UnavailableReason | undefined;
  if (!valid) unavailableReason = "config_invalid";
  else if (!isEnabled) unavailableReason = "disabled";

  return {
    valid,
    isEnabled,
    feeAmount: valid ? (feeAmountRaw as number) : null,
    currency: valid ? (currencyRaw as string) : null,
    configVersion,
    // Phase 16B-4 note: `copy`/`mandatoryDisclosures` below still carry the
    // FEE_TOKEN placeholder, unrendered — see this function's own header
    // comment. Always the server constant for mandatoryDisclosures —
    // raw.copy.mandatoryDisclosures (if an admin ever writes one) is never
    // read anywhere in this function.
    copy,
    mandatoryDisclosures: MANDATORY_ONBOARDING_DISCLOSURES,
    copyFallbackReason,
    violatedPhrases,
    unavailableReason,
  };
}
