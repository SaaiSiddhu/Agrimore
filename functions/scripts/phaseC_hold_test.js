// Phase C, Workstream 5/6 — quote + hold + release lifecycle.
// Proves functions/src/customer/productCreditHold.ts and the stale-hold
// sweep in productCreditExpiry.ts against a real emulator: redemption
// disabled, the compliance gate closed, a real hold reserving credit,
// requoting replacing the prior hold, a manual release restoring the
// balance exactly, idempotent double-release, the sweep releasing an
// expired hold (and doing nothing on a second run), and a client-requested
// amount far above the balance being capped down. quoteOrderWithCredit/
// releaseProductCreditHold are v2 onCall, wrapped as `wrapped({data, auth})`
// — releaseExpiredProductCreditHolds is a v1 pubsub schedule function,
// wrapped and invoked as `wrapped()`.
// Run with: node scripts/phaseC_hold_test.js
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { quoteOrderWithCredit, releaseProductCreditHold } = require("../lib/customer/productCreditHold");
const { releaseExpiredProductCreditHolds } = require("../lib/customer/productCreditExpiry");

const wrappedQuote = test.wrap(quoteOrderWithCredit);
const wrappedRelease = test.wrap(releaseProductCreditHold);
const wrappedSweep = test.wrap(releaseExpiredProductCreditHolds);

const db = admin.firestore();

async function callAndCapture(wrapped, payload, auth) {
  try {
    const result = await wrapped({ data: payload, auth });
    return { ok: true, result };
  } catch (e) {
    return { ok: false, code: e.code, message: e.message };
  }
}

async function seedProduct(productId, salePrice, sellerId, state = {}) {
  await db.collection("products").doc(productId).set({
    name: `Product ${productId}`,
    salePrice,
    sellerId,
    images: [],
    isB2BEnabled: false,
    ...state,
  });
}

async function seedProgram(programId, overrides) {
  await db.collection("benefit_programs").doc(programId).set({
    name: `Program ${programId}`,
    status: "active",
    durationMonths: 12,
    rulesVersion: 1,
    benefitRuleType: "flatRupee",
    benefitRateValue: 500,
    creditFrequency: "monthly",
    minProgramAmount: 0,
    maxProgramAmount: 0,
    redemptionEnabled: true,
    minOrderValueForRedemption: 0,
    maxCreditPerOrder: null,
    maxCreditPercentOfOrder: null,
    redeemableCategoryIds: null,
    ...overrides,
  });
}

async function seedEnrollment(enrollmentId, customerId, programId) {
  await db.collection("benefit_enrollments").doc(enrollmentId).set({
    customerId,
    programId,
    status: "active",
    programAmount: 100000,
    rulesVersionAtEnrollment: 1,
    startDate: admin.firestore.Timestamp.fromDate(new Date("2026-01-01")),
    maturityDate: admin.firestore.Timestamp.fromDate(new Date("2027-01-01")),
  });
}

async function seedBalance(customerId, available) {
  await db
    .collection("product_credit_balances")
    .doc(customerId)
    .set({ available, pending: 0, onHold: 0, lifetimeEarned: available, lifetimeUsed: 0, lifetimeExpired: 0 });
}

async function getBalance(customerId) {
  const snap = await db.collection("product_credit_balances").doc(customerId).get();
  return snap.data() || {};
}

async function approveComplianceAndFlags({ redemptionEnabled = true } = {}) {
  await db
    .doc("compliance_config/benefit_program")
    .set({ legalReviewStatus: "APPROVED", complianceApprovalStatus: "APPROVED" }, { merge: true });
  await db
    .doc("feature_flags/benefit_program")
    .set(
      { BENEFIT_PROGRAM_ENABLED: true, PRODUCT_CREDIT_REDEMPTION_ENABLED: redemptionEnabled },
      { merge: true }
    );
}

async function resetGate() {
  await db.doc("compliance_config/benefit_program").delete().catch(() => {});
  await db.doc("feature_flags/benefit_program").delete().catch(() => {});
}

const auth = (uid) => ({ uid, token: {} });

async function main() {
  let allPassed = true;
  const results = {};

  await resetGate();

  // Scenario 1: quote with redemption disabled (gate launchable, but
  // PRODUCT_CREDIT_REDEMPTION_ENABLED false) -> creditApplied 0, no hold,
  // no ledger entry.
  {
    const customerId = "phaseC-hold-c1";
    await seedProduct("phaseC-hold-p1", 1000, "seller1");
    await approveComplianceAndFlags({ redemptionEnabled: false });
    await seedBalance(customerId, 500);

    const r = await callAndCapture(
      wrappedQuote,
      { items: [{ productId: "phaseC-hold-p1", quantity: 1 }], orderMode: "B2C" },
      auth(customerId)
    );
    const holdsSnap = await db.collection("product_credit_holds").where("customerId", "==", customerId).get();
    const pass = r.ok && r.result.creditApplied === 0 && r.result.holdId === null && holdsSnap.empty;
    results.scenario1_redemption_disabled_no_hold = pass
      ? `PASSED — creditApplied=0, holdId=null, no hold document written. reasons=${JSON.stringify(r.result?.reasons)}`
      : `FAILED — ${JSON.stringify(r)}, holdsCount=${holdsSnap.size}`;
    if (!pass) allPassed = false;
  }

  // Scenario 2: quote when not launchable (compliance not approved) ->
  // creditApplied 0, no hold.
  {
    const customerId = "phaseC-hold-c2";
    await seedProduct("phaseC-hold-p2", 1000, "seller2");
    await resetGate(); // compliance unapproved, flags absent
    await seedBalance(customerId, 500);

    const r = await callAndCapture(
      wrappedQuote,
      { items: [{ productId: "phaseC-hold-p2", quantity: 1 }], orderMode: "B2C" },
      auth(customerId)
    );
    const pass = r.ok && r.result.creditApplied === 0 && r.result.holdId === null;
    results.scenario2_not_launchable_no_hold = pass
      ? `PASSED — creditApplied=0, holdId=null when the compliance gate is not launchable`
      : `FAILED — ${JSON.stringify(r)}`;
    if (!pass) allPassed = false;
  }

  // Scenario 3: quote with credit available -> hold created, available
  // down, onHold up, payable = total - creditApplied.
  let scenario3HoldId = null;
  let scenario3CustomerId = "phaseC-hold-c3";
  {
    const customerId = scenario3CustomerId;
    await seedProduct("phaseC-hold-p3", 1000, "seller3");
    await seedProgram("phaseC-hold-prog3", {});
    await seedEnrollment("phaseC-hold-enroll3", customerId, "phaseC-hold-prog3");
    await approveComplianceAndFlags({ redemptionEnabled: true });
    await seedBalance(customerId, 500);

    const r = await callAndCapture(
      wrappedQuote,
      { items: [{ productId: "phaseC-hold-p3", quantity: 1 }], orderMode: "B2C" },
      auth(customerId)
    );
    const bal = await getBalance(customerId);
    const pass =
      r.ok &&
      r.result.creditApplied === 500 &&
      r.result.holdId &&
      r.result.payable === roundMoneyLocal(r.result.total - r.result.creditApplied) &&
      bal.available === 0 &&
      bal.onHold === 500;
    scenario3HoldId = r.result?.holdId;
    results.scenario3_hold_created_and_balance_moved = pass
      ? `PASSED — creditApplied=${r.result.creditApplied}, holdId=${r.result.holdId}, available=${bal.available}, onHold=${bal.onHold}, payable=${r.result.payable}`
      : `FAILED — ${JSON.stringify(r)}, balance=${JSON.stringify(bal)}`;
    if (!pass) allPassed = false;
  }

  // Scenario 4: a second quote replaces the first hold — exactly one
  // active hold survives, the first is RELEASEd.
  let scenario4HoldId = null;
  {
    const customerId = scenario3CustomerId;
    const r = await callAndCapture(
      wrappedQuote,
      { items: [{ productId: "phaseC-hold-p3", quantity: 1 }], orderMode: "B2C" },
      auth(customerId)
    );
    scenario4HoldId = r.result?.holdId;

    const firstHoldSnap = await db.collection("product_credit_holds").doc(scenario3HoldId).get();
    const activeHoldsSnap = await db
      .collection("product_credit_holds")
      .where("customerId", "==", customerId)
      .where("status", "==", "active")
      .get();

    const pass =
      r.ok &&
      scenario4HoldId &&
      scenario4HoldId !== scenario3HoldId &&
      firstHoldSnap.data()?.status === "released" &&
      activeHoldsSnap.size === 1 &&
      activeHoldsSnap.docs[0].id === scenario4HoldId;
    results.scenario4_requote_replaces_prior_hold = pass
      ? `PASSED — new holdId=${scenario4HoldId}, old hold ${scenario3HoldId} status=released, exactly 1 active hold remains`
      : `FAILED — ${JSON.stringify(r)}, firstHoldStatus=${firstHoldSnap.data()?.status}, activeCount=${activeHoldsSnap.size}`;
    if (!pass) allPassed = false;
  }

  // Scenario 5: release restores available exactly and marks the hold released.
  {
    const customerId = scenario3CustomerId;
    const balBefore = await getBalance(customerId);
    const r = await callAndCapture(wrappedRelease, { holdId: scenario4HoldId, reason: "test release" }, auth(customerId));
    const balAfter = await getBalance(customerId);
    const holdDoc = await db.collection("product_credit_holds").doc(scenario4HoldId).get();

    const pass =
      r.ok &&
      r.result.alreadyReleased === false &&
      balAfter.available === balBefore.available + 500 &&
      balAfter.onHold === 0 &&
      holdDoc.data()?.status === "released";
    results.scenario5_release_restores_balance_exactly = pass
      ? `PASSED — available restored from ${balBefore.available} to ${balAfter.available}, onHold=0, hold status=released`
      : `FAILED — ${JSON.stringify(r)}, before=${JSON.stringify(balBefore)}, after=${JSON.stringify(balAfter)}, holdStatus=${holdDoc.data()?.status}`;
    if (!pass) allPassed = false;
  }

  // Scenario 6: releasing an already-released hold twice is a successful
  // no-op (idempotency) — no double-restoration, no error.
  {
    const customerId = scenario3CustomerId;
    const balBefore = await getBalance(customerId);
    const r = await callAndCapture(wrappedRelease, { holdId: scenario4HoldId, reason: "second release attempt" }, auth(customerId));
    const balAfter = await getBalance(customerId);

    const pass = r.ok && r.result.alreadyReleased === true && balAfter.available === balBefore.available;
    results.scenario6_double_release_is_idempotent_noop = pass
      ? `PASSED — releasing an already-released hold returned alreadyReleased=true and did not change the balance (${balAfter.available})`
      : `FAILED — ${JSON.stringify(r)}, before=${JSON.stringify(balBefore)}, after=${JSON.stringify(balAfter)}`;
    if (!pass) allPassed = false;
  }

  // Scenario 7: an expired hold + sweep -> available restored, hold
  // 'expired'; a second sweep run changes nothing.
  {
    const customerId = "phaseC-hold-c7";
    await seedBalance(customerId, 1000);
    await db.collection("product_credit_holds").doc("phaseC-hold-expiredhold7").set({
      id: "phaseC-hold-expiredhold7",
      customerId,
      enrollmentId: "phaseC-hold-enroll7",
      amount: 400,
      status: "active",
      ledgerEntryId: null,
      cartFingerprint: "test-fingerprint",
      quotedTotal: 1000,
      quotedPayable: 600,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() - 60000), // 1 minute in the past
      releasedAt: null,
      settledAt: null,
    });
    // Manually take the hold out of `available` to mirror what a real quote
    // would have done (HOLD entry), so the sweep's restoration is meaningful.
    await db.collection("product_credit_balances").doc(customerId).set(
      { available: 600, onHold: 400, pending: 0, lifetimeEarned: 1000, lifetimeUsed: 0, lifetimeExpired: 0 },
      { merge: true }
    );

    await wrappedSweep();
    const balAfterFirstSweep = await getBalance(customerId);
    const holdAfterFirstSweep = await db.collection("product_credit_holds").doc("phaseC-hold-expiredhold7").get();

    const firstSweepPass =
      balAfterFirstSweep.available === 1000 &&
      balAfterFirstSweep.onHold === 0 &&
      holdAfterFirstSweep.data()?.status === "expired";

    // Second sweep run — must be a no-op (idempotent).
    await wrappedSweep();
    const balAfterSecondSweep = await getBalance(customerId);
    const secondSweepPass = balAfterSecondSweep.available === balAfterFirstSweep.available;

    const pass = firstSweepPass && secondSweepPass;
    results.scenario7_sweep_releases_expired_hold_idempotently = pass
      ? `PASSED — first sweep restored available to ${balAfterFirstSweep.available} and set hold status=expired; second sweep changed nothing (${balAfterSecondSweep.available})`
      : `FAILED — afterFirst=${JSON.stringify(balAfterFirstSweep)} holdStatus=${holdAfterFirstSweep.data()?.status}, afterSecond=${JSON.stringify(balAfterSecondSweep)}`;
    if (!pass) allPassed = false;
  }

  // Scenario 8: requestedCreditAmount far above the balance is capped to
  // what the rules allow (the available balance, in this unconstrained
  // program config).
  {
    const customerId = "phaseC-hold-c8";
    await seedProduct("phaseC-hold-p8", 2000, "seller8");
    await seedProgram("phaseC-hold-prog8", {});
    await seedEnrollment("phaseC-hold-enroll8", customerId, "phaseC-hold-prog8");
    await approveComplianceAndFlags({ redemptionEnabled: true });
    await seedBalance(customerId, 150);

    const r = await callAndCapture(
      wrappedQuote,
      {
        items: [{ productId: "phaseC-hold-p8", quantity: 1 }],
        orderMode: "B2C",
        requestedCreditAmount: 999999,
      },
      auth(customerId)
    );
    const pass = r.ok && r.result.creditApplied === 150;
    results.scenario8_requested_amount_capped_to_rules = pass
      ? `PASSED — requestedCreditAmount=999999 was capped down to the actual available balance (${r.result.creditApplied})`
      : `FAILED — ${JSON.stringify(r)}`;
    if (!pass) allPassed = false;
  }

  // Scenario 9 (CAT-16): a category-restricted program must still credit a
  // product whose categoryId is missing but whose legacy `category` field is
  // a map with its own `id` — resolveCategoryId's own added fallback.
  {
    const customerId = "phaseC-cat16-c9";
    await db.collection("products").doc("phaseC-cat16-p9").set({
      name: "Product phaseC-cat16-p9",
      salePrice: 1000,
      sellerId: "seller9",
      images: [],
      isB2BEnabled: false,
      category: { id: "phaseC-cat16-realcat", name: "Test Category" },
    });
    await seedProgram("phaseC-cat16-prog9", { redeemableCategoryIds: ["phaseC-cat16-realcat"] });
    await seedEnrollment("phaseC-cat16-enroll9", customerId, "phaseC-cat16-prog9");
    await approveComplianceAndFlags({ redemptionEnabled: true });
    await seedBalance(customerId, 500);

    const r = await callAndCapture(
      wrappedQuote,
      { items: [{ productId: "phaseC-cat16-p9", quantity: 1 }], orderMode: "B2C" },
      auth(customerId)
    );
    const pass = r.ok && r.result.creditApplied === 500;
    results.scenario9_category_as_map_resolves_for_restricted_program = pass
      ? `PASSED — a category-restricted program credited a legacy category-as-map product in full (creditApplied=${r.result.creditApplied})`
      : `FAILED — ${JSON.stringify(r)}`;
    if (!pass) allPassed = false;
  }

  // Scenario 10 (CAT-16): same as 9, but the product has neither categoryId
  // nor a category field at all — only the legacy categoryName fallback.
  {
    const customerId = "phaseC-cat16-c10";
    await db.collection("products").doc("phaseC-cat16-p10").set({
      name: "Product phaseC-cat16-p10",
      salePrice: 800,
      sellerId: "seller10",
      images: [],
      isB2BEnabled: false,
      categoryName: "phaseC-cat16-realcat2",
    });
    await seedProgram("phaseC-cat16-prog10", { redeemableCategoryIds: ["phaseC-cat16-realcat2"] });
    await seedEnrollment("phaseC-cat16-enroll10", customerId, "phaseC-cat16-prog10");
    await approveComplianceAndFlags({ redemptionEnabled: true });
    await seedBalance(customerId, 300);

    const r = await callAndCapture(
      wrappedQuote,
      { items: [{ productId: "phaseC-cat16-p10", quantity: 1 }], orderMode: "B2C" },
      auth(customerId)
    );
    const pass = r.ok && r.result.creditApplied === 300;
    results.scenario10_categoryName_fallback_resolves_for_restricted_program = pass
      ? `PASSED — a category-restricted program credited a categoryName-only product in full (creditApplied=${r.result.creditApplied})`
      : `FAILED — ${JSON.stringify(r)}`;
    if (!pass) allPassed = false;
  }

  // F3.1 controls: the shared pricing path must reject explicit unavailable
  // states while retaining the documented legacy defaults (covered by the
  // existing quote scenarios whose products omit both fields).
  for (const [scenario, state] of [
    [11, { isActive: false }],
    [12, { isActive: true, isDraft: true }],
  ]) {
    const customerId = `phaseC-elig-c${scenario}`;
    const productId = `phaseC-elig-p${scenario}`;
    await seedProduct(productId, 1000, `seller${scenario}`, state);
    const r = await callAndCapture(
      wrappedQuote,
      { items: [{ productId, quantity: 1 }], orderMode: "B2C" },
      auth(customerId)
    );
    const holds = await db.collection("product_credit_holds")
      .where("customerId", "==", customerId).get();
    const pass = !r.ok && r.code === "failed-precondition" && holds.empty;
    results[`scenario${scenario}_explicitly_unpurchasable_quote_rejected`] = pass
      ? "PASSED — unavailable product rejected before hold creation"
      : `FAILED — ${JSON.stringify(r)}, holdsCount=${holds.size}`;
    if (!pass) allPassed = false;
  }
  {
    const customerId = "phaseC-elig-c13";
    const productId = "phaseC-elig-p13";
    await seedProduct(productId, 1000, "seller13", { isActive: true, isDraft: false });
    const r = await callAndCapture(
      wrappedQuote,
      { items: [{ productId, quantity: 1 }], orderMode: "B2C" },
      auth(customerId)
    );
    const pass = r.ok && Math.abs(r.result.total - 1000) <= 0.02;
    results.scenario13_explicitly_active_quote_remains_available = pass
      ? "PASSED — active product pricing remains available"
      : `FAILED — ${JSON.stringify(r)}`;
    if (!pass) allPassed = false;
  }

  console.log("=== PHASE C — QUOTE/HOLD/RELEASE LIFECYCLE TEST ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);
  console.log(allPassed ? "\nALL PASSED" : "\nSOME FAILED");
  process.exit(allPassed ? 0 : 1);
}

function roundMoneyLocal(v) {
  return Math.round(v * 100) / 100;
}

main().catch((e) => {
  console.error("FATAL ERROR running phaseC hold test:", e);
  process.exit(1);
});
