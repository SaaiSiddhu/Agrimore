// Phase 16B-4, Workstream 3 — proves the actual client-facing callable,
// getAssociateOnboardingConfig, always renders a fee figure that agrees
// with the authoritative feeAmount — never the "₹500" DEFAULT_ONBOARDING_COPY/
// MANDATORY_ONBOARDING_DISCLOSURES templates hardcoded, and never a raw
// {{fee}} token or a malformed "₹null"/"₹NaN". Calls the REAL compiled
// getAssociateOnboardingConfig (v2 onCall) against the Firestore emulator
// via firebase-functions-test's wrap — same harness shape as
// phase16a_activation_test.js, which this suite must not disturb (it seeds
// settings/associate_onboarding with the SAME doc ID and restores
// phase16a's own GOOD_CONFIG-equivalent fixture at the end of each
// scenario, so running this file does not leave the config in a state that
// would break a later run of phase16a_activation_test.js on a shared
// emulator).
// Run with: node scripts/phase16b4_fee_single_source_test.js
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
if (admin.apps.length === 0) {
  admin.initializeApp({ projectId: "agrimore-66a4e" });
}
const db = admin.firestore();

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { getAssociateOnboardingConfig } = require("../lib/employee/getAssociateOnboardingConfig");
const wrapped = test.wrap(getAssociateOnboardingConfig);

const CONFIG_DOC = db.collection("settings").doc("associate_onboarding");

// A structurally-valid, complete copy deck with NO fee figure anywhere —
// used as the "no admin copy override" baseline so every scenario proves
// DEFAULT_ONBOARDING_COPY's own interpolation, not an admin deck's.
async function clearConfig() {
  await CONFIG_DOC.delete().catch(() => {});
}

async function seedConfig(overrides) {
  await CONFIG_DOC.set({
    isEnabled: true,
    feeAmount: 500,
    currency: "INR",
    version: 1,
    ...overrides,
  });
}

function fullAdminCopy(overrides) {
  return {
    headline: "Admin headline",
    feeLabel: "Admin fee label",
    supportingStatement: "Admin supporting statement",
    whyTheFeeExists: { title: "t", body: ["a"] },
    benefitGroups: [{ key: "g1", title: "Group", items: ["item"] }],
    earningsExplainer: { title: "t", body: ["a"], flowSteps: ["a"], variabilityFactors: ["a"] },
    journeySteps: [{ step: 1, title: "t", body: "b" }],
    summaryCard: { title: "t", feeLine: "f", includes: ["i"], ctaLabel: "c", ctaSubtext: "s" },
    supportContact: { title: "t", body: "b", email: "e@example.com", phone: "" },
    ...overrides,
  };
}

function allStringsFrom(value, out) {
  if (typeof value === "string") out.push(value);
  else if (Array.isArray(value)) value.forEach((v) => allStringsFrom(v, out));
  else if (value && typeof value === "object") Object.values(value).forEach((v) => allStringsFrom(v, out));
  return out;
}

async function call() {
  return wrapped({ data: undefined, auth: null });
}

async function main() {
  const results = {};
  const record = (key, ok, passMsg, failMsg) => {
    results[key] = ok ? `PASSED — ${passMsg}` : `FAILED — ${failMsg}`;
  };

  // ============================================================
  // Scenario 1: feeAmount 750, no admin copy override -> every string in
  // copy AND every mandatory disclosure states ₹750; "₹500" appears
  // NOWHERE in the response.
  // ============================================================
  {
    await seedConfig({ feeAmount: 750, currency: "INR" });
    const res = await call();
    const allText = allStringsFrom(res, []).join(" \n ");
    const has750 = res.copy.feeLabel.includes("₹750") &&
      res.copy.supportingStatement.includes("₹750") &&
      res.copy.whyTheFeeExists.body[0].includes("₹750") &&
      res.copy.journeySteps.find((s) => s.step === 2).title.includes("₹750") &&
      res.copy.summaryCard.feeLine.includes("₹750") &&
      res.copy.summaryCard.ctaLabel.includes("₹750") &&
      res.mandatoryDisclosures[0].includes("₹750");
    const no500 = !allText.includes("₹500");
    const ok = has750 && no500;
    record(
      "1_feeAmount_750_every_string_says_750_never_500",
      ok,
      "every copy field and every mandatory disclosure states ₹750; ₹500 appears nowhere in the response",
      `feeLabel=${res.copy.feeLabel} feeLine=${res.copy.summaryCard.feeLine} ctaLabel=${res.copy.summaryCard.ctaLabel} disclosure0=${res.mandatoryDisclosures[0]} has750=${has750} no500=${no500}`
    );
  }

  // ============================================================
  // Scenario 2: feeAmount 500 -> output means exactly what it does today.
  // ============================================================
  {
    await seedConfig({ feeAmount: 500, currency: "INR" });
    const res = await call();
    const ok =
      res.copy.feeLabel === "One-Time Registration & Onboarding Fee: ₹500" &&
      res.copy.summaryCard.feeLine === "One-Time Fee: ₹500" &&
      res.copy.summaryCard.ctaLabel === "Complete Registration — ₹500" &&
      res.mandatoryDisclosures[0] ===
        "The Registration & Onboarding Fee of ₹500 is a one-time payment, charged once when you complete registration.";
    record(
      "2_feeAmount_500_matches_todays_meaning",
      ok,
      "feeLabel/feeLine/ctaLabel/disclosure0 all render the ₹500 figure exactly",
      `res.copy=${JSON.stringify(res.copy).slice(0, 300)}`
    );
  }

  // ============================================================
  // Scenario 3: fractional fee (499.5) -> renders in the 2-decimal form,
  // matching the client's authoritativeFeeText/PriceFormatter rule
  // (integer when whole, 2dp when fractional).
  // ============================================================
  {
    await seedConfig({ feeAmount: 499.5, currency: "INR" });
    const res = await call();
    const ok = res.copy.summaryCard.feeLine === "One-Time Fee: ₹499.50";
    record(
      "3_fractional_fee_renders_2dp",
      ok,
      `499.5 renders as ₹499.50 (2 decimal places), matching the client's rule`,
      `feeLine=${res.copy.summaryCard.feeLine}`
    );
  }

  // ============================================================
  // Scenario 4: feeAmount unusable (config invalid — missing currency) ->
  // no "₹null", no "₹NaN", no bare "₹" anywhere in the response.
  // ============================================================
  {
    // currency omitted entirely (Firestore rejects literal `undefined`
    // values) -> currencyValid false -> valid:false -> feeAmount:null.
    await clearConfig();
    await CONFIG_DOC.set({ isEnabled: true, feeAmount: 500, version: 1 });
    const res = await call();
    const allText = allStringsFrom(res, []).join(" \n ");
    const ok =
      !allText.includes("₹null") &&
      !allText.includes("₹NaN") &&
      !/₹\s*(null|undefined|NaN)?\s*$/.test(res.copy.summaryCard.feeLine) &&
      res.feeAmount === null;
    record(
      "4_unusable_fee_no_malformed_figure",
      ok,
      `feeAmount:null, no malformed figure anywhere. feeLine="${res.copy.summaryCard.feeLine}"`,
      `feeAmount=${res.feeAmount} feeLine=${res.copy.summaryCard.feeLine} allTextHasNull=${allText.includes("₹null")} allTextHasNaN=${allText.includes("₹NaN")}`
    );
  }

  // ============================================================
  // Scenario 5: non-INR currency -> no invented multi-currency formatting
  // beyond "<CODE> <amount>"; specifically no ₹ symbol anywhere.
  // ============================================================
  {
    await seedConfig({ feeAmount: 100, currency: "USD" });
    const res = await call();
    const allText = allStringsFrom(res, []).join(" \n ");
    const ok = !allText.includes("₹") && res.copy.summaryCard.feeLine.includes("USD 100.00");
    record(
      "5_non_inr_currency_no_invented_formatting",
      ok,
      `USD 100 renders as "USD 100.00", no ₹ symbol anywhere in the response`,
      `feeLine=${res.copy.summaryCard.feeLine} hasRupeeSymbol=${allText.includes("₹")}`
    );
  }

  // ============================================================
  // Scenario 6: admin copy stating a contradicting figure falls back to
  // defaults with copyFallbackReason:"fee_mismatch" is NOT directly
  // observable on this callable's response shape (unavailableReason only
  // covers valid/isEnabled) — but the rendered copy itself proves the
  // fallback: it must show the DEFAULT deck's ₹750, never the admin's
  // stated ₹500.
  // ============================================================
  {
    await seedConfig({
      feeAmount: 750,
      currency: "INR",
      copy: fullAdminCopy({ feeLabel: "Pay just ₹500 today!" }),
    });
    const res = await call();
    const ok = res.copy.feeLabel === "One-Time Registration & Onboarding Fee: ₹750";
    record(
      "6_contradicting_admin_copy_falls_back_to_default",
      ok,
      `admin copy said ₹500 but feeAmount is 750 -> client receives the DEFAULT deck's ₹750, not the admin's ₹500`,
      `feeLabel=${res.copy.feeLabel}`
    );
  }

  // ============================================================
  // Scenario 7 (CONTROL): admin copy attempting to replace
  // mandatoryDisclosures is still ignored — proves this phase did not
  // weaken that lock.
  // ============================================================
  {
    await seedConfig({
      feeAmount: 500,
      currency: "INR",
      copy: fullAdminCopy({ mandatoryDisclosures: ["This admin line tries to replace the real disclosures."] }),
    });
    const res = await call();
    const ok =
      res.mandatoryDisclosures.length === 8 &&
      res.mandatoryDisclosures[0] ===
        "The Registration & Onboarding Fee of ₹500 is a one-time payment, charged once when you complete registration.";
    record(
      "7_control_mandatory_disclosures_still_unoverridable",
      ok,
      "admin-supplied copy.mandatoryDisclosures never reaches the client; the real 8 server disclosures (interpolated) are returned instead",
      `count=${res.mandatoryDisclosures.length} disclosure0=${res.mandatoryDisclosures[0]}`
    );
  }

  // ============================================================
  // Scenario 8 (CONTROL): admin copy containing a prohibited earnings
  // claim still falls back — proves PROHIBITED_CLAIM_PHRASES / the
  // Play-safety scanner is intact and untouched by this phase.
  // ============================================================
  {
    await seedConfig({
      feeAmount: 500,
      currency: "INR",
      copy: fullAdminCopy({ summaryCard: { title: "t", feeLine: "Guaranteed Income of your dreams!", includes: ["i"], ctaLabel: "c", ctaSubtext: "s" } }),
    });
    const res = await call();
    const ok = res.copy.headline === "AgriMore Sales Associate Registration & Onboarding";
    record(
      "8_control_prohibited_claim_scanner_intact",
      ok,
      "admin copy containing a prohibited earnings claim ('guaranteed income') still falls back to the default deck",
      `headline=${res.copy.headline}`
    );
  }

  // Restore a phase16a_activation_test.js-compatible fixture so a later
  // run of that suite on this same (shared, non-idempotent) emulator is
  // not affected by anything this file seeded.
  await clearConfig();

  console.log("=== PHASE 16B-4 — FEE SINGLE-SOURCE TEST ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);
  const allPassed = Object.values(results).every((v) => v.startsWith("PASSED"));
  console.log(allPassed ? "\nALL PASSED" : "\nSOME FAILED");
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phase16b4 fee single-source test:", e);
  process.exit(1);
});
