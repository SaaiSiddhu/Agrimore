// Phase 16A — Associate Onboarding activation core test. Exercises the
// REAL compiled functions/lib/employee/activationCore.js (via
// performOnboardingActivation) and functions/lib/employee/onboardingConfig.js
// (via loadOnboardingConfig) against the Firestore emulator using the real
// firebase-admin SDK — not a re-implementation of the gate. Seeds
// verified_payments / employees / settings docs directly via the Admin
// SDK (which bypasses firestore.rules entirely, same as every Cloud
// Function does), then invokes the actual activation logic.
//
// Requires `npm run build` to have been run first (this imports from
// lib/, not src/) and the Firestore emulator to be running on 127.0.0.1:8080.
// Run with: node scripts/phase16a_activation_test.js
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
if (admin.apps.length === 0) {
  admin.initializeApp({ projectId: "agrimore-66a4e" });
}
const db = admin.firestore();

const { performOnboardingActivation } = require("../lib/employee/activationCore");
const { loadOnboardingConfig, MANDATORY_ONBOARDING_DISCLOSURES, DEFAULT_ONBOARDING_COPY } = require("../lib/employee/onboardingConfig");

const CONFIG_DOC = db.collection("settings").doc("associate_onboarding");

const GOOD_CONFIG = {
  isEnabled: true,
  feeAmount: 500,
  currency: "INR",
  feeIsOneTime: true,
  version: 7,
  copy: {
    headline: "Test headline",
    feeLabel: "Test fee label",
    supportingStatement: "Test supporting statement",
    whyTheFeeExists: { title: "t", body: ["a"] },
    benefitGroups: [{ key: "g1", title: "Group", items: ["item"] }],
    earningsExplainer: { title: "t", body: ["a"], flowSteps: ["a"], variabilityFactors: ["a"] },
    journeySteps: [{ step: 1, title: "t", body: "b" }],
    summaryCard: { title: "t", feeLine: "f", includes: ["i"], ctaLabel: "c", ctaSubtext: "s" },
    supportContact: { title: "t", body: "b", email: "e@example.com", phone: "" },
  },
};

async function seedGoodConfig() {
  await CONFIG_DOC.set(GOOD_CONFIG);
}

async function seedEmployee(uid, overrides = {}) {
  await db.collection("employees").doc(uid).set({
    userId: uid,
    name: "Test",
    email: `${uid}@p16a-test.example`,
    phone: "9999999999",
    employeeCode: uid.toUpperCase().slice(0, 6),
    status: "pending",
    commissionRate: 0,
    createdBy: "self",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    ...overrides,
  });
}

async function seedPayment(paymentId, overrides = {}) {
  await db.collection("verified_payments").doc(paymentId).set({
    orderId: `order_${paymentId}`,
    paymentId,
    userId: null,
    signatureVerified: true,
    verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    method: "upi",
    amount: 500,
    currency: "INR",
    status: "captured",
    ...overrides,
  });
}

async function main() {
  const results = {};

  // ============================================
  // 18: Happy path activates and consumes
  // ============================================
  {
    const uid = "p16a-act-18";
    const paymentId = "pay_p16a_18";
    await seedGoodConfig();
    await seedEmployee(uid);
    await seedPayment(paymentId, { userId: uid, amount: 500 });

    const result = await performOnboardingActivation({ db, uid, paymentId, source: "client" });
    const employeeSnap = await db.collection("employees").doc(uid).get();
    const paymentSnap = await db.collection("verified_payments").doc(paymentId).get();

    const ok =
      result.ok === true &&
      result.alreadyActive === false &&
      employeeSnap.data().onboardingPaid === true &&
      employeeSnap.data().onboardingFeeAmount === 500 &&
      employeeSnap.data().onboardingPaymentId === paymentId &&
      paymentSnap.data().consumedByOnboardingFor === uid;
    results["18_happy_path_activates_and_consumes"] = ok
      ? "PASSED — activation succeeded, employee marked paid, payment marked consumed"
      : `FAILED — result=${JSON.stringify(result)} employee=${JSON.stringify(employeeSnap.data())} payment=${JSON.stringify(paymentSnap.data())}`;
  }

  // ============================================
  // 19: Replaying the same paymentId → alreadyActive, no second consumption
  // ============================================
  {
    const uid = "p16a-act-18"; // reuse scenario 18's already-activated associate
    const paymentId = "pay_p16a_18";
    const result = await performOnboardingActivation({ db, uid, paymentId, source: "client" });
    const eventsSnap = await db.collection("onboarding_events").where("uid", "==", uid).get();
    const activationEvents = eventsSnap.docs.filter((d) => d.data().type === "activation");
    const ok = result.ok === true && result.alreadyActive === true && activationEvents.length === 1;
    results["19_replay_same_payment_is_idempotent"] = ok
      ? "PASSED — replaying an already-consumed paymentId returns alreadyActive with no second consumption/event"
      : `FAILED — result=${JSON.stringify(result)} activationEventCount=${activationEvents.length}`;
  }

  // ============================================
  // 20: Another user's paymentId is rejected
  // ============================================
  {
    const owner = "p16a-act-20-owner";
    const attacker = "p16a-act-20-attacker";
    const paymentId = "pay_p16a_20";
    await seedEmployee(owner);
    await seedEmployee(attacker);
    await seedPayment(paymentId, { userId: owner, amount: 500 });

    const result = await performOnboardingActivation({ db, uid: attacker, paymentId, source: "client" });
    const ok = result.ok === false && result.failureCode === "payment_wrong_user";
    results["20_cross_user_payment_rejected"] = ok
      ? "PASSED — a different user's paymentId was rejected with payment_wrong_user"
      : `FAILED — result=${JSON.stringify(result)}`;
  }

  // ============================================
  // 21: A verified_payments doc with NO userId (legacy) is rejected
  // ============================================
  {
    const uid = "p16a-act-21";
    const paymentId = "pay_p16a_21";
    await seedEmployee(uid);
    // Deliberately omit userId entirely (pre-Phase-14 legacy shape).
    await db.collection("verified_payments").doc(paymentId).set({
      orderId: `order_${paymentId}`,
      paymentId,
      signatureVerified: true,
      amount: 500,
      currency: "INR",
      status: "captured",
    });

    const result = await performOnboardingActivation({ db, uid, paymentId, source: "client" });
    const ok = result.ok === false && result.failureCode === "payment_wrong_user";
    results["21_legacy_no_userid_payment_rejected"] = ok
      ? "PASSED — a legacy verified_payments doc with no userId fails closed (payment_wrong_user), never treated as a match"
      : `FAILED — result=${JSON.stringify(result)}`;
  }

  // ============================================
  // 22: A payment with status !== 'captured' is rejected
  // ============================================
  {
    const uid = "p16a-act-22";
    const paymentId = "pay_p16a_22";
    await seedEmployee(uid);
    await seedPayment(paymentId, { userId: uid, amount: 500, status: "authorized" });

    const result = await performOnboardingActivation({ db, uid, paymentId, source: "client" });
    const ok = result.ok === false && result.failureCode === "payment_not_captured";
    results["22_uncaptured_payment_rejected"] = ok
      ? "PASSED — a non-captured payment was rejected"
      : `FAILED — result=${JSON.stringify(result)}`;
  }

  // ============================================
  // 23: An amount below the configured fee is rejected
  // ============================================
  {
    const uid = "p16a-act-23";
    const paymentId = "pay_p16a_23";
    await seedEmployee(uid);
    await seedPayment(paymentId, { userId: uid, amount: 1 });

    const result = await performOnboardingActivation({ db, uid, paymentId, source: "client" });
    const ok = result.ok === false && result.failureCode === "payment_amount_mismatch";
    results["23_underpayment_rejected"] = ok
      ? "PASSED — an amount below the configured fee was rejected (payment_amount_mismatch)"
      : `FAILED — result=${JSON.stringify(result)}`;
  }

  // ============================================
  // 24: A payment already carrying consumedByOrderId is rejected
  // ============================================
  {
    const uid = "p16a-act-24";
    const paymentId = "pay_p16a_24";
    await seedEmployee(uid);
    await seedPayment(paymentId, { userId: uid, amount: 500, consumedByOrderId: "order_real_123" });

    const result = await performOnboardingActivation({ db, uid, paymentId, source: "client" });
    const ok = result.ok === false && result.failureCode === "payment_already_consumed_by_order";
    results["24_order_consumed_payment_rejected_for_onboarding"] = ok
      ? "PASSED — a payment already consumed by a real order cannot also activate onboarding"
      : `FAILED — result=${JSON.stringify(result)}`;
  }

  // ============================================
  // 25: Activation NEVER sets status to 'approved'
  // ============================================
  {
    const uid = "p16a-act-25";
    const paymentId = "pay_p16a_25";
    await seedEmployee(uid, { status: "pending" });
    await seedPayment(paymentId, { userId: uid, amount: 500 });

    await performOnboardingActivation({ db, uid, paymentId, source: "client" });
    const employeeSnap = await db.collection("employees").doc(uid).get();
    const ok = employeeSnap.data().status === "pending";
    results["25_activation_never_sets_status_approved"] = ok
      ? "PASSED — status field is untouched by activation (still 'pending')"
      : `FAILED — status=${employeeSnap.data().status}`;
  }

  // ============================================
  // 26: Config isEnabled:false blocks activation
  // ============================================
  {
    const uid = "p16a-act-26";
    const paymentId = "pay_p16a_26";
    await CONFIG_DOC.set({ ...GOOD_CONFIG, isEnabled: false });
    await seedEmployee(uid);
    await seedPayment(paymentId, { userId: uid, amount: 500 });

    const result = await performOnboardingActivation({ db, uid, paymentId, source: "client" });
    const ok = result.ok === false && result.failureCode === "config_disabled";
    results["26_disabled_config_blocks_activation"] = ok
      ? "PASSED — isEnabled:false blocks activation (config_disabled)"
      : `FAILED — result=${JSON.stringify(result)}`;
    await seedGoodConfig(); // restore for subsequent scenarios
  }

  // ============================================
  // 27: Missing config blocks activation (fail-closed)
  // ============================================
  {
    const uid = "p16a-act-27";
    const paymentId = "pay_p16a_27";
    await CONFIG_DOC.delete();
    await seedEmployee(uid);
    await seedPayment(paymentId, { userId: uid, amount: 500 });

    const result = await performOnboardingActivation({ db, uid, paymentId, source: "client" });
    const ok = result.ok === false && result.failureCode === "config_invalid";
    results["27_missing_config_fails_closed"] = ok
      ? "PASSED — a missing settings/associate_onboarding document fails closed (config_invalid)"
      : `FAILED — result=${JSON.stringify(result)}`;
    await seedGoodConfig(); // restore for subsequent scenarios
  }

  // ============================================
  // 28: A Firestore config attempting to override the mandatory
  // disclosures does NOT succeed in removing them.
  // ============================================
  {
    await CONFIG_DOC.set({
      ...GOOD_CONFIG,
      copy: {
        ...GOOD_CONFIG.copy,
        mandatoryDisclosures: ["This admin-authored line tries to replace the real disclosures."],
      },
    });
    const loaded = await loadOnboardingConfig(db);
    const same =
      loaded.mandatoryDisclosures.length === MANDATORY_ONBOARDING_DISCLOSURES.length &&
      loaded.mandatoryDisclosures.every((line, i) => line === MANDATORY_ONBOARDING_DISCLOSURES[i]);
    results["28_mandatory_disclosures_cannot_be_overridden"] = same
      ? "PASSED — loadOnboardingConfig ignores any Firestore-supplied copy.mandatoryDisclosures and always returns the real server constant"
      : `FAILED — returned=${JSON.stringify(loaded.mandatoryDisclosures)}`;
    await seedGoodConfig();
  }

  // ============================================
  // 29: A Firestore config containing a prohibited earnings claim causes
  // the server DEFAULT copy to be served instead.
  // ============================================
  {
    await CONFIG_DOC.set({
      ...GOOD_CONFIG,
      copy: {
        ...GOOD_CONFIG.copy,
        summaryCard: { ...GOOD_CONFIG.copy.summaryCard, feeLine: "Guaranteed Income of your dreams!" },
      },
    });
    const loaded = await loadOnboardingConfig(db);
    const ok =
      loaded.copyFallbackReason === "prohibited_claim" &&
      loaded.copy.headline === DEFAULT_ONBOARDING_COPY.headline &&
      loaded.copy.summaryCard.feeLine === DEFAULT_ONBOARDING_COPY.summaryCard.feeLine;
    results["29_prohibited_claim_serves_default_copy"] = ok
      ? "PASSED — copy containing a prohibited earnings claim causes the server DEFAULT copy to be served, with copyFallbackReason='prohibited_claim'"
      : `FAILED — copyFallbackReason=${loaded.copyFallbackReason} copy=${JSON.stringify(loaded.copy).slice(0, 300)}`;
    await seedGoodConfig();
  }

  console.log("=== PHASE 16A — ASSOCIATE ONBOARDING ACTIVATION CORE TEST ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);

  const allPassed = Object.values(results).every((v) => v.startsWith("PASSED"));
  console.log(allPassed ? "\nALL PASSED" : "\nSOME FAILED");
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phase16a activation test:", e);
  process.exit(1);
});
