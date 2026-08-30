// ============================================================
//  Callable: getAssociateOnboardingConfig — Phase 16A, Workstream 2
// ============================================================
//
// Returns the merged, validated onboarding config (fee, copy, mandatory
// disclosures) for the Phase 16B onboarding page. Deliberately routes
// through loadOnboardingConfig() rather than letting the client read
// settings/associate_onboarding directly, so every response is guaranteed
// to carry the mandatory disclosures and never carry admin copy that
// tripped the prohibited-claim guard.

import { onCall } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { log } from "../common/helpers";
import { loadOnboardingConfig, interpolateFeeAmount } from "./onboardingConfig";

export const getAssociateOnboardingConfig = onCall(
  { minInstances: 0, memory: "256MiB" },
  async () => {
    // Decision (2a): callable WITHOUT requiring authentication — see the
    // completion report's Decisions section for the full write-up. Short
    // version: settings/associate_onboarding is already `allow read: if
    // true` in firestore.rules (Workstream 1e), so a client can already
    // read the raw document with zero auth regardless of what this
    // function requires; the onboarding page must also be able to show
    // the fee/benefits BEFORE sign-in. Requiring auth here would only
    // push callers toward that raw read, which bypasses the
    // mandatory-disclosure merge and prohibited-claim guard entirely —
    // defeating Workstream 1's purpose. This returns no secret and no
    // internal id (2d), so the abuse surface is a billable invocation of a
    // cheap, side-effect-free read — bounded by Cloud Functions' own
    // platform-level cost controls, not something this phase adds its own
    // throttle for.
    const db = admin.firestore();
    const config = await loadOnboardingConfig(db);

    if (config.copyFallbackReason === "prohibited_claim") {
      log.error(
        `🚨 settings/associate_onboarding copy contains a prohibited earnings claim — serving DEFAULT copy instead. Matched phrases: ${(
          config.violatedPhrases || []
        ).join(", ")}`
      );
      // Fire-and-forget audit write — this callable is not inside any
      // transaction, so writing here (after all reads) is safe.
      await db.collection("onboarding_events").add({
        type: "config_violation",
        detail: `prohibited_claim: ${(config.violatedPhrases || []).join(", ")}`,
        configVersion: config.configVersion,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    // Phase 16B-4: mirrors the prohibited_claim block above exactly — an
    // admin copy override stating a rupee figure that disagrees with
    // feeAmount is caught by onboardingConfig.ts's findFeeMismatches (run
    // against the admin's RAW text) and already fell back to the default
    // copy inside loadOnboardingConfig(); this just logs/audits it, same
    // shape as prohibited_claim.
    if (config.copyFallbackReason === "fee_mismatch") {
      log.error(
        `🚨 settings/associate_onboarding copy states a rupee figure that disagrees with feeAmount (${
          config.feeAmount
        }) — serving DEFAULT copy instead. Offending sentences: ${(config.violatedPhrases || []).join(", ")}`
      );
      await db.collection("onboarding_events").add({
        type: "config_violation",
        detail: `fee_mismatch: ${(config.violatedPhrases || []).join(", ")}`,
        configVersion: config.configVersion,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    // Phase 16B-4: this callable is the ONLY place FEE_TOKEN is ever
    // interpolated — see onboardingConfig.ts's header comment for why
    // (loadOnboardingConfig has two other, money-path callers that never
    // read `copy`, and a pre-existing test asserts loadOnboardingConfig's
    // raw return against the raw module constants). config.feeAmount/
    // config.currency are already `valid ? amount : null` from
    // loadOnboardingConfig, so interpolateFeeAmount's own null-handling
    // (substitutes a neutral, non-numeric phrase — never "null", "NaN", or
    // a bare currency symbol) applies automatically whenever the fee is
    // unusable.
    const renderedCopy = interpolateFeeAmount(config.copy, config.feeAmount, config.currency);
    const renderedDisclosures = interpolateFeeAmount(
      config.mandatoryDisclosures,
      config.feeAmount,
      config.currency
    );

    return {
      // Never return a fee/enabled state the server would not itself
      // honour — activateAssociateOnboarding and
      // createAssociateOnboardingPayment both read through this exact
      // same loadOnboardingConfig(), so isEnabled/feeAmount here are
      // always the same values they will enforce.
      isEnabled: config.valid && config.isEnabled,
      feeAmount: config.valid ? config.feeAmount : null,
      currency: config.valid ? config.currency : null,
      copy: renderedCopy,
      // Separate top-level array (2b) — never nested inside `copy` — so a
      // UI cannot accidentally drop it by only rendering known `copy`
      // fields.
      mandatoryDisclosures: renderedDisclosures,
      configVersion: config.configVersion,
      unavailableReason:
        config.valid && config.isEnabled ? null : config.unavailableReason || "config_invalid",
    };
  }
);
