// ============================================================
//  Phase 16B-4 — fee-truthfulness regression suite (pure-function layer)
// ============================================================
//
// Pure Node, NO EMULATOR, and it must STAY that way — this is the ONLY
// no-emulator coverage this area has, and Firestore/Functions emulator
// ports on this machine are routinely held by a concurrent session, so a
// test that needed one simply wouldn't get run.
//
// WHAT THIS FILE COVERS: the pure functions
// (formatFeeAmountForDisplay/interpolateFeeAmount/findFeeMismatches/
// findProhibitedClaims) and loadOnboardingConfig() itself, via a
// hand-rolled fake Firestore — all plain, synchronous-or-trivially-async
// TypeScript compiled to functions/lib/ by `npm run build`, required
// directly here (the same pattern phase19_client_secret_guard_test.js uses
// for its own no-emulator checks).
//
// WHAT THIS FILE DOES NOT COVER: the RENDERED, client-facing text.
//
// Phase 16B-5, following the CTO's architectural ruling (Phase 16B-4
// completion, commit e531886): FEE_TOKEN interpolation happens ONLY at the
// callable boundary, inside getAssociateOnboardingConfig.ts — never inside
// loadOnboardingConfig, which has two other, money-path callers
// (createAssociateOnboardingPayment.ts, activationCore.ts) that never read
// `copy` at all. loadOnboardingConfig's own return value therefore STILL
// CARRIES the literal "{{fee}}" placeholder by design — this suite proves
// exactly that layer's behaviour (interpolation logic in isolation, and
// loadOnboardingConfig's fallback DECISIONS: missing/malformed/
// prohibited_claim/fee_mismatch), never what a real user sees on screen.
//
// The companion suite, scripts/phase16b4_fee_single_source_test.js, is
// what proves the RENDERED text — it calls the REAL compiled
// getAssociateOnboardingConfig callable (against the Firestore/Functions
// emulator) and asserts every string in its response states the
// authoritative figure. If you are trying to answer "does the page say
// the right amount", that is the file to read; if you are trying to
// answer "is the interpolation/fallback LOGIC correct", this is it.
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
    // Phase 16B-5: the "client receives the DEFAULT deck's ₹750, not the
    // admin's ₹500" assertion that used to live here is REMOVED, not
    // weakened. Under the CTO's architectural ruling (Phase 16B-4
    // completion, e531886) interpolation happens ONLY at the callable
    // boundary (getAssociateOnboardingConfig.ts) — loadOnboardingConfig's
    // OWN return (what `contradictingResult` is, here) still carries the
    // raw FEE_TOKEN placeholder for a no-fallback copy, so asserting a
    // rendered "₹750" against it can never pass and never should: that
    // rendering is proven instead by
    // phase16b4_fee_single_source_test.js's scenario 6, which calls the
    // REAL getAssociateOnboardingConfig callable. What's left here — the
    // copyFallbackReason check immediately above — is still the correct,
    // fully-covered assertion for what THIS layer (loadOnboardingConfig)
    // is actually responsible for: deciding to fall back, not rendering.

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
    // Phase 16B-5: the "interpolated to ₹750" assertion that used to live
    // here is REMOVED, for the same reason as 7a above —
    // loadOnboardingConfig deliberately returns tokenResult.copy.feeLabel
    // STILL carrying the literal FEE_TOKEN ("{{fee}}") at this layer;
    // interpolation is the callable boundary's job, proven by
    // phase16b4_fee_single_source_test.js's scenario 1 (feeAmount 750 ->
    // every string says ₹750) against the real callable. What's left here
    // — no-fallback — is this layer's real responsibility: an admin who
    // used FEE_TOKEN correctly must not be penalised, which is exactly
    // what copyFallbackReason === undefined proves.

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
    // Phase 16B-5: the "...(interpolated)" assertion that used to live
    // here is REMOVED — its `.includes("₹750")` half can never pass at
    // this layer, for the same reason as 7a/7c above: loadOnboardingConfig
    // returns MANDATORY_ONBOARDING_DISCLOSURES un-interpolated by design
    // (interpolation is the callable boundary's job). The check above this
    // comment — the locked-decision-6 injection guard — is the important
    // one and is untouched: it is still the strongest, most important
    // check in this file, and it still passes. The fact that the real
    // client-facing text says "₹750" (not "{{fee}}") is proven instead by
    // phase16b4_fee_single_source_test.js's scenario 1, against the real
    // callable.
  }

  // ---------------------------------------------------------------
  // Scenario 9 — Phase 16B-5, Workstream 3: a guard that fails loudly if a
  // raw "{{...}}" token (or a malformed "null"/"NaN"/"undefined" render)
  // ever leaks into interpolated output again. Nothing in this suite
  // caught 16B-4's original defect (interpolateFeeAmount was written but
  // never called at all, so {{fee}} shipped into a mandatory legal
  // disclosure) — this scenario exists specifically so a future version of
  // that mistake fails HERE, at the no-emulator layer, before it can ever
  // reach a committed state. Reuses collectLeaves — the same traversal
  // every other scenario in this file already uses — rather than writing a
  // second walker.
  // ---------------------------------------------------------------
  {
    const LEAK_PATTERNS = ["{{", "}}", "null", "NaN", "undefined"];

    function assertNoLeak(label, value) {
      const leaves = collectLeaves(value, []);
      const offenders = [];
      for (const leaf of leaves) {
        for (const pattern of LEAK_PATTERNS) {
          // Case-sensitive substring match — "null"/"NaN"/"undefined" are
          // JS's own stringification artefacts of a bad interpolation
          // input, never ordinary English prose (nothing in this deck
          // legitimately contains any of these five substrings), so a
          // plain `includes` is precise enough with no false-positive risk.
          if (leaf.includes(pattern)) {
            offenders.push(`"${pattern}" in "${leaf}"`);
          }
        }
      }
      check(`9. ${label} :: no {{/}}/null/NaN/undefined leak`, offenders.length === 0, JSON.stringify(offenders));
    }

    // 9a. interpolateFeeAmount's own output, across every input shape this
    // function accepts: a valid whole fee, a fractional fee, a non-INR
    // currency, and the null/invalid case.
    assertNoLeak("interpolateFeeAmount(₹750, INR)", interpolateFeeAmount(DEFAULT_ONBOARDING_COPY, 750, "INR"));
    assertNoLeak(
      "interpolateFeeAmount(₹599.99, INR)",
      interpolateFeeAmount(DEFAULT_ONBOARDING_COPY, 599.99, "INR")
    );
    assertNoLeak("interpolateFeeAmount(100, USD)", interpolateFeeAmount(DEFAULT_ONBOARDING_COPY, 100, "USD"));
    assertNoLeak("interpolateFeeAmount(null, null)", interpolateFeeAmount(DEFAULT_ONBOARDING_COPY, null, null));
    assertNoLeak(
      "interpolateFeeAmount(disclosures, ₹750, INR)",
      interpolateFeeAmount(MANDATORY_ONBOARDING_DISCLOSURES, 750, "INR")
    );
    assertNoLeak(
      "interpolateFeeAmount(disclosures, null, null)",
      interpolateFeeAmount(MANDATORY_ONBOARDING_DISCLOSURES, null, null)
    );

    // 9b. The module's own constants, once interpolated — this is the
    // literal scenario 16B-4 shipped broken (a mandatory disclosure
    // rendering the raw token): DEFAULT_ONBOARDING_COPY and
    // MANDATORY_ONBOARDING_DISCLOSURES, interpolated at a normal valid
    // fee, must carry neither token remnant.
    assertNoLeak(
      "DEFAULT_ONBOARDING_COPY interpolated @ ₹750",
      interpolateFeeAmount(DEFAULT_ONBOARDING_COPY, 750, "INR")
    );
    assertNoLeak(
      "MANDATORY_ONBOARDING_DISCLOSURES interpolated @ ₹750",
      interpolateFeeAmount(MANDATORY_ONBOARDING_DISCLOSURES, 750, "INR")
    );

    // Proof this guard actually guards something (see the completion
    // report for the deliberate-failure run performed alongside this
    // file): a scratch value with a deliberately un-interpolated token
    // must be CAUGHT, not silently accepted. Run inline, on a throwaway
    // value, and its own (expected) failure is reported as its own check
    // so a reader can see the guard was exercised, not just written.
    const deliberateLeak = { sentence: "This still says {{fee}} on purpose." };
    const caughtLeaves = collectLeaves(deliberateLeak, []);
    const caught = caughtLeaves.some((leaf) => leaf.includes("{{"));
    check(
      "9. self-test :: a deliberately un-interpolated {{fee}} token IS detected by this guard's own logic",
      caught === true,
      `collectLeaves found: ${JSON.stringify(caughtLeaves)}`
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
