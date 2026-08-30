// ============================================================
//  Associate Onboarding Configuration — Phase 16A, Workstream 1
// ============================================================
//
// settings/associate_onboarding (Firestore) is the single source of truth
// for the ₹500 one-time Registration & Onboarding Fee amount AND for every
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

import * as admin from "firebase-admin";

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
// as `mandatoryDisclosures`, regardless of anything present (or absent) in
// the Firestore document's own `copy.mandatoryDisclosures` — that field,
// if present in Firestore, is never read by this module at all. Plain,
// non-promissory language throughout; no fixed earnings figures anywhere.
export const MANDATORY_ONBOARDING_DISCLOSURES: readonly string[] = [
  "The ₹500 Registration & Onboarding Fee is a one-time payment, charged once when you complete registration.",
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
  feeLabel: "One-Time Registration & Onboarding Fee: ₹500",
  supportingStatement:
    "Complete your AgriMore onboarding and gain access to the tools, training, product catalogue, sales platform, commission tracking, and support you need to start retail sales. ₹500 is a one-time payment — it is not a monthly or recurring subscription charge.",
  whyTheFeeExists: {
    title: "Why this fee exists",
    body: [
      "A one-time Registration & Onboarding Fee of ₹500 is collected to activate your associate account and provide access to AgriMore's sales tools, resources, training, platform access, and support services.",
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
    { step: 2, title: "Complete ₹500 Onboarding", body: "Pay the one-time Registration & Onboarding Fee." },
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
    feeLine: "One-Time Fee: ₹500",
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
    ctaLabel: "Complete Registration — ₹500",
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
export type CopyFallbackReason = "missing" | "malformed" | "prohibited_claim";
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
  const feeAmountValid =
    typeof feeAmountRaw === "number" && Number.isFinite(feeAmountRaw) && feeAmountRaw > 0;

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
    if (claims.length > 0) {
      copyFallbackReason = "prohibited_claim";
      violatedPhrases = claims;
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
    copy,
    // Always the server constant — raw.copy.mandatoryDisclosures (if an
    // admin ever writes one) is never read anywhere in this function.
    mandatoryDisclosures: MANDATORY_ONBOARDING_DISCLOSURES,
    copyFallbackReason,
    violatedPhrases,
    unavailableReason,
  };
}
