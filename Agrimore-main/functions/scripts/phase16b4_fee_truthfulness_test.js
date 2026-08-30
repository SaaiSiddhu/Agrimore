// ============================================================
//  Phase 16B-4 — fee-truthfulness regression suite
// ============================================================
//
// Pure Node, NO EMULATOR. Everything under test (formatFeeAmountForDisplay,
// interpolateFeeAmount, findFeeMismatches, findProhibitedClaims, and
// loadOnboardingConfig via a hand-rolled fake Firestore) is plain,
// synchronous-or-trivially-async TypeScript compiled to functions/lib/ by
// `npm run build` — this file requires that compiled output directly, the
// same pattern phase19_client_secret_guard_test.js uses for its own
// no-emulator checks. Ports 8080/5001/4000 are routinely held by a
// concurrent session's emulator on this machine; a test that needed one
// would not get run, so this one deliberately doesn't need one.
//
// Run with: node scripts/phase16b4_fee_truthfulness_test.js

const path = require("path");

const {
  DEFAULT_ONBOARDING_COPY,
  MANDATORY_ONBOARDING_DISCLOSURES,
  FEE_TOKEN,
  formatFeeAmountForDisplay,
  interpolateFeeAmount,
  findFeeMismatches,
  findProhibitedClaims,
  loadOnboardingConfig,
} = require(path.join(__dirname, "..", "lib", "employee", "onboardingConfig"));

const results = [];
function check(label, pass, detail) {
  results.push({ label, pass: !!pass, detail });
}

// Independent, TEST-ONLY leaf collector — deliberately NOT importing the
// module's own collectStringLeaves (it isn't exported, and re-implementing
// a 10-line tree-walk here is fine for a test; duplicating PRODUCT logic
// is what Workstream 1.4 actually warns against, not this).
function collectLeaves(value, out) {
  if (typeof value === "string") {
    out.push(value);
  } else if (Array.isArray(value)) {
    for (const item of value) collectLeaves(item, out);
  } else if (value && typeof value === "object") {
    for (const key of Object.keys(value)) collectLeaves(value[key], out);
  }
  return out;
}

// Same detection pattern as the production findFeeMismatches's own
// CURRENCY_MENTION_PATTERN (kept as an independent literal here, not
// imported, for the same "test shouldn't share the thing it's checking"
// reason as collectLeaves above) — used by scenarios 1/2 to assert ZERO
// hardcoded currency literals survive in the raw, un-interpolated
// constants.
const CURRENCY_LITERAL_PATTERN = /(?:₹|\brs\.?|\binr)\s*[\d][\d,]*(?:\.\d+)?/gi;

function findCurrencyLiterals(value) {
  const leaves = collectLeaves(value, []);
  const offenders = [];
  for (const leaf of leaves) {
    CURRENCY_LITERAL_PATTERN.lastIndex = 0;
    if (CURRENCY_LITERAL_PATTERN.test(leaf)) offenders.push(leaf);
  }
  return offenders;
}

function containsToken(value) {
  return collectLeaves(value, []).some((leaf) => leaf.includes(FEE_TOKEN));
}

// A hand-rolled fake Firestore — no emulator, no real admin SDK
// connection. Exactly matches the surface loadOnboardingConfig() actually
// calls: db.collection(name).doc(id).get() -> { exists, data() }. Passing
// no `tx` argument means loadOnboardingConfig takes the `tx ? ... : await
// ref.get()` else-branch, which is all this fake needs to satisfy.
function makeFakeDb(docData) {
  return {
    collection() {
      return {
        doc() {
          return {
            async get() {
              return {
                exists: docData !== null,
                data: () => docData,
              };
            },
          };
        },
      };
    },
  };
}

// A structurally-valid admin copy override — satisfies every check
// isCopyStructurallyValid performs (all REQUIRED_TOP_LEVEL_COPY_KEYS
// present, benefitGroups/journeySteps arrays, non-empty headline/feeLabel,
// summaryCard/earningsExplainer objects) — with a single controllable
// fee-bearing string so each scenario can vary exactly one thing.
function buildAdminCopy(feeText) {
  return {
    headline: "Admin Headline",
    feeLabel: feeText,
    supportingStatement: "Admin supporting statement.",
    whyTheFeeExists: { title: "Why", body: ["Admin body"] },
    benefitGroups: [{ key: "k", title: "T", items: ["item"] }],
    earningsExplainer: { title: "E", body: ["b"], flowSteps: [], variabilityFactors: [] },
    journeySteps: [{ step: 1, title: "S", body: "b" }],
    summaryCard: { title: "Summary", feeLine: feeText, includes: [], ctaLabel: "Go", ctaSubtext: "" },
    supportContact: { title: "Help", body: "b", email: "a@b.com", phone: "" },
  };
}

async function main() {
  // ---------------------------------------------------------------
  // Scenario 1 — DEFAULT_ONBOARDING_COPY contains ZERO hardcoded currency
  // amounts. The regression test that keeps this phase closed: if a
  // future edit reintroduces a literal "₹500" anywhere in the default
  // deck, this scenario fails loudly rather than silently reintroducing
  // Defect 1.
  // ---------------------------------------------------------------
  {
    const offenders = findCurrencyLiterals(DEFAULT_ONBOARDING_COPY);
    check(
      "1. DEFAULT_ONBOARDING_COPY has zero hardcoded currency amounts",
      offenders.length === 0,
      `found: ${JSON.stringify(offenders)}`
    );
  }

  // ---------------------------------------------------------------
  // Scenario 2 — MANDATORY_ONBOARDING_DISCLOSURES likewise.
  // ---------------------------------------------------------------
  {
    const offenders = findCurrencyLiterals(MANDATORY_ONBOARDING_DISCLOSURES);
    check(
      "2. MANDATORY_ONBOARDING_DISCLOSURES has zero hardcoded currency amounts",
      offenders.length === 0,
      `found: ${JSON.stringify(offenders)}`
    );
  }

  // ---------------------------------------------------------------
  // Scenario 3 — interpolation at 500, 750, and a fractional amount:
  // correct text in every fee sentence (all 7 templated locations plus
  // the disclosure).
  // ---------------------------------------------------------------
  {
    const cases = [
      { amount: 500, expected: "₹500" },
      { amount: 750, expected: "₹750" },
      { amount: 599.99, expected: "₹599.99" },
    ];
    for (const { amount, expected } of cases) {
      const copy = interpolateFeeAmount(DEFAULT_ONBOARDING_COPY, amount, "INR");
      const disclosures = interpolateFeeAmount(MANDATORY_ONBOARDING_DISCLOSURES, amount, "INR");
      const locations = {
        feeLabel: copy.feeLabel,
        supportingStatement: copy.supportingStatement,
        whyTheFeeExistsBody0: copy.whyTheFeeExists.body[0],
        journeyStep2Title: copy.journeySteps[1].title,
        summaryFeeLine: copy.summaryCard.feeLine,
        summaryCtaLabel: copy.summaryCard.ctaLabel,
        disclosure0: disclosures[0],
      };
      for (const [loc, text] of Object.entries(locations)) {
        check(
          `3. interpolation@₹${amount} :: ${loc} contains ${expected}`,
          typeof text === "string" && text.includes(expected),
          `got: "${text}"`
        );
      }
      // And none of them contain the token or a DIFFERENT amount's figure.
      const allTexts = Object.values(locations).join(" | ");
      check(
        `3. interpolation@₹${amount} :: no {{fee}} token survives`,
        !allTexts.includes(FEE_TOKEN),
        allTexts
      );
    }
  }

  // ---------------------------------------------------------------
  // Scenario 4 — feeAmount null/invalid: no number, no surviving {{fee}}
  // token, anywhere in copy or disclosures.
  // ---------------------------------------------------------------
  {
    const copy = interpolateFeeAmount(DEFAULT_ONBOARDING_COPY, null, null);
    const disclosures = interpolateFeeAmount(MANDATORY_ONBOARDING_DISCLOSURES, null, null);
    const tokenSurvives = containsToken(copy) || containsToken(disclosures);
    const currencyOffenders = [...findCurrencyLiterals(copy), ...findCurrencyLiterals(disclosures)];
    check("4. feeAmount=null :: no {{fee}} token survives", !tokenSurvives);
    check(
      "4. feeAmount=null :: no numeric currency literal present",
      currencyOffenders.length === 0,
      JSON.stringify(currencyOffenders)
    );
    check(
      "4. feeAmount=null :: neutral phrase present in feeLabel",
      copy.feeLabel.includes("the applicable amount"),
      copy.feeLabel
    );
  }

  // ---------------------------------------------------------------
  // Scenario 5 — non-INR currency: no ₹ emitted anywhere.
  // ---------------------------------------------------------------
  {
    const copy = interpolateFeeAmount(DEFAULT_ONBOARDING_COPY, 100, "USD");
    const leaves = collectLeaves(copy, []);
    const rupeeOffenders = leaves.filter((l) => l.includes("₹"));
    check(
      "5. non-INR currency (USD) :: no ₹ symbol anywhere in interpolated copy",
      rupeeOffenders.length === 0,
      JSON.stringify(rupeeOffenders)
    );
    check(
      "5. non-INR currency (USD) :: feeLabel renders 'USD 100.00'",
      copy.feeLabel.includes("USD 100.00"),
      copy.feeLabel
    );
  }

  // ---------------------------------------------------------------
  // Scenario 6 — the formatter's output never contains "earn ₹" and never
  // trips findProhibitedClaims, at a range of amounts.
  // ---------------------------------------------------------------
  {
    for (const amount of [500, 750, 1, 99999.99]) {
      const formatted = formatFeeAmountForDisplay(amount, "INR");
      check(
        `6. formatFeeAmountForDisplay(${amount}) never contains "earn ₹"`,
        !formatted.toLowerCase().includes("earn ₹"),
        formatted
      );
      const copy = interpolateFeeAmount(DEFAULT_ONBOARDING_COPY, amount, "INR");
      const claims = findProhibitedClaims(copy);
      check(
        `6. interpolated copy @ ₹${amount} never trips findProhibitedClaims`,
        claims.length === 0,
        JSON.stringify(claims)
      );
    }
  }

  // ---------------------------------------------------------------
  // Scenario 7 — mismatch detection via the real loadOnboardingConfig(),
  // against a fake Firestore (no emulator).
  // ---------------------------------------------------------------
  {
    // 7a. Contradicting admin copy ("₹500" while feeAmount is 750) is
    // rejected: the client receives the DEFAULT deck saying ₹750, and
    // copyFallbackReason === "fee_mismatch".
    const contradictingDb = makeFakeDb({
      feeAmount: 750,
      currency: "INR",
      isEnabled: true,
      version: 1,
      copy: buildAdminCopy("₹500"),
    });
    const contradictingResult = await loadOnboardingConfig(contradictingDb);
    check(
      "7a. contradicting admin copy (₹500 vs feeAmount 750) :: copyFallbackReason === 'fee_mismatch'",
      contradictingResult.copyFallbackReason === "fee_mismatch",
      contradictingResult.copyFallbackReason
    );
    check(
      "7a. contradicting admin copy :: client receives the DEFAULT deck's ₹750, not the admin's ₹500",
      contradictingResult.copy.feeLabel.includes("₹750") && !contradictingResult.copy.feeLabel.includes("₹500"),
      contradictingResult.copy.feeLabel
    );

    // 7b. Matching admin copy ("₹750" while feeAmount is 750) is accepted
    // — no fallback.
    const matchingDb = makeFakeDb({
      feeAmount: 750,
      currency: "INR",
      isEnabled: true,
      version: 1,
      copy: buildAdminCopy("₹750"),
    });
    const matchingResult = await loadOnboardingConfig(matchingDb);
    check(
      "7b. matching admin copy (₹750 vs feeAmount 750) :: no fallback (copyFallbackReason undefined)",
      matchingResult.copyFallbackReason === undefined,
      matchingResult.copyFallbackReason
    );
    check(
      "7b. matching admin copy :: admin's own text is used verbatim",
      matchingResult.copy.feeLabel === "₹750",
      matchingResult.copy.feeLabel
    );

    // 7c. {{fee}}-using admin copy is accepted and interpolated — no
    // fallback.
    const tokenDb = makeFakeDb({
      feeAmount: 750,
      currency: "INR",
      isEnabled: true,
      version: 1,
      copy: buildAdminCopy(FEE_TOKEN),
    });
    const tokenResult = await loadOnboardingConfig(tokenDb);
    check(
      "7c. {{fee}}-using admin copy :: no fallback (copyFallbackReason undefined)",
      tokenResult.copyFallbackReason === undefined,
      tokenResult.copyFallbackReason
    );
    check(
      "7c. {{fee}}-using admin copy :: interpolated to ₹750",
      tokenResult.copy.feeLabel === "₹750",
      tokenResult.copy.feeLabel
    );

    // 7d. Direct unit coverage of findFeeMismatches itself: the correctly
    // interpolated authoritative amount must NOT trip its own scanner
    // (round-trip: format -> re-parse -> must equal the original number).
    const selfConsistentCopy = interpolateFeeAmount(DEFAULT_ONBOARDING_COPY, 750, "INR");
    const selfMismatches = findFeeMismatches(selfConsistentCopy, 750);
    check(
      "7d. the interpolated authoritative amount never trips its own mismatch scanner",
      selfMismatches.length === 0,
      JSON.stringify(selfMismatches)
    );
  }

  // ---------------------------------------------------------------
  // Scenario 8 — locked decision 6: an admin copy.mandatoryDisclosures
  // value is still never returned to the client, even when present in
  // Firestore.
  // ---------------------------------------------------------------
  {
    const adminCopy = buildAdminCopy("₹750");
    adminCopy.mandatoryDisclosures = ["THIS SHOULD NEVER BE RETURNED — admin-injected disclosure"];
    const db = makeFakeDb({
      feeAmount: 750,
      currency: "INR",
      isEnabled: true,
      version: 1,
      copy: adminCopy,
    });
    const result = await loadOnboardingConfig(db);
    const returnedDisclosures = result.mandatoryDisclosures.join(" | ");
    check(
      "8. admin-injected copy.mandatoryDisclosures never reaches the client",
      !returnedDisclosures.includes("THIS SHOULD NEVER BE RETURNED"),
      returnedDisclosures
    );
    check(
      "8. mandatoryDisclosures still comes from the server constant (interpolated)",
      result.mandatoryDisclosures.length === MANDATORY_ONBOARDING_DISCLOSURES.length &&
        result.mandatoryDisclosures[0].includes("₹750"),
      JSON.stringify(result.mandatoryDisclosures)
    );
  }

  console.log("");
  for (const r of results) {
    console.log(`${r.pass ? "PASSED" : "FAILED"} — ${r.label}${r.pass ? "" : ` :: ${r.detail || ""}`}`);
  }
  const allPassed = results.every((r) => r.pass);
  console.log("");
  console.log(`${results.filter((r) => r.pass).length}/${results.length} checks passed`);
  console.log(allPassed ? "ALL PASSED" : "SOME FAILED");
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL:", e);
  process.exit(1);
});
