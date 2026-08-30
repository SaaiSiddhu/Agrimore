// Phase D-2, Workstream 3 — DEFECT D-3 fix proof:
// functions/src/customer/redemptionRules.ts's computeRedeemableAmount now
// fails CLOSED (allowed:false, amount:0) on any non-finite numeric input,
// instead of letting Math.min(...caps) get poisoned into NaN and slipping
// past Rule 5's `amount <= 0` check (NaN <= 0 is false in JavaScript) to
// return {allowed:true, amount:NaN}. Same no-emulator, pure-function,
// table-driven harness shape as phaseC_restrictions_test.js — this
// function takes no Firestore/transaction types at all.
// Run with: node scripts/phaseD2_failclosed_test.js
const { computeRedeemableAmount } = require("../lib/customer/redemptionRules");

const baseProgram = {
  redemptionEnabled: true,
  minOrderValueForRedemption: 0,
  maxCreditPerOrder: null,
  maxCreditPercentOfOrder: null,
};

// A fully valid input, used as the base for every scenario below and as
// its own CONTROL (scenario 10).
const validInput = {
  program: baseProgram,
  orderSubtotal: 1000,
  eligibleSubtotal: 1000,
  availableCredit: 500,
  requestedAmount: 500,
  orderGrandTotal: 1000,
};

function isRealNumber(value) {
  // Deliberately NOT Number.isFinite alone here — this helper also wants
  // to reject `null`/`undefined`, which Number.isFinite already does, so
  // it's equivalent, but spelled out for readability in this file's own
  // assertions (distinct from the guard under test).
  return typeof value === "number" && Number.isFinite(value);
}

const cases = [
  {
    name: "1_omitted_orderGrandTotal_fails_closed",
    input: (() => {
      const { orderGrandTotal, ...rest } = validInput;
      return rest; // orderGrandTotal entirely absent, not just undefined
    })(),
    expectAllowed: false,
    expectAmount: 0,
    expectNotNaN: true,
  },
  {
    name: "2_orderGrandTotal_NaN_fails_closed",
    input: { ...validInput, orderGrandTotal: NaN },
    expectAllowed: false,
    expectAmount: 0,
    expectNotNaN: true,
  },
  {
    name: "3_orderGrandTotal_Infinity_fails_closed",
    input: { ...validInput, orderGrandTotal: Infinity },
    expectAllowed: false,
    expectAmount: 0,
    expectNotNaN: true,
  },
  {
    name: "4_availableCredit_undefined_fails_closed",
    input: { ...validInput, availableCredit: undefined },
    expectAllowed: false,
    expectAmount: 0,
    expectNotNaN: true,
  },
  {
    name: "5_eligibleSubtotal_NaN_fails_closed",
    input: { ...validInput, eligibleSubtotal: NaN },
    expectAllowed: false,
    expectAmount: 0,
    expectNotNaN: true,
  },
  {
    name: "6_requestedAmount_NaN_fails_closed",
    input: { ...validInput, requestedAmount: NaN },
    expectAllowed: false,
    expectAmount: 0,
    expectNotNaN: true,
  },
  {
    name: "7_present_but_nonfinite_maxCreditPerOrder_fails_closed",
    input: { ...validInput, program: { ...baseProgram, maxCreditPerOrder: NaN } },
    expectAllowed: false,
    expectAmount: 0,
    expectNotNaN: true,
  },
  {
    name: "8_control_null_program_caps_still_mean_no_cap",
    input: { ...validInput, program: { ...baseProgram, maxCreditPerOrder: null, maxCreditPercentOfOrder: null } },
    expectAllowed: true,
    expectAmount: 500, // availableCredit/requestedAmount (500) bind — no cap from null caps
  },
  {
    name: "9_control_availableCredit_0_keeps_its_own_specific_reason",
    input: { ...validInput, availableCredit: 0 },
    expectAllowed: false,
    expectAmount: 0,
    expectReasonIncludes: "No Product Credit is available to redeem",
  },
  {
    name: "10_control_fully_valid_input_unchanged_behaviour",
    input: { ...validInput },
    expectAllowed: true,
    expectAmount: 500,
  },
];

function main() {
  let allPassed = true;
  const results = {};

  for (const testCase of cases) {
    const result = computeRedeemableAmount(testCase.input);
    let pass = result.allowed === testCase.expectAllowed && result.amount === testCase.expectAmount;
    if (pass && testCase.expectNotNaN) {
      // Belt-and-suspenders on top of the strict === above: === already
      // fails for NaN (NaN !== 0), but assert isRealNumber explicitly so a
      // future refactor that changed expectAmount to NaN wouldn't
      // accidentally make this pass for the wrong reason.
      pass = isRealNumber(result.amount);
    }
    if (pass && testCase.expectReasonIncludes) {
      pass = result.reasons.some((r) => r.includes(testCase.expectReasonIncludes));
    }
    results[testCase.name] = pass
      ? `PASSED — allowed=${result.allowed} amount=${result.amount} reasons=${JSON.stringify(result.reasons)}`
      : `FAILED — expected allowed=${testCase.expectAllowed} amount=${testCase.expectAmount}, got ${JSON.stringify(result)}`;
    if (!pass) allPassed = false;
  }

  console.log("=== PHASE D-2 — FAIL-CLOSED REDEMPTION INPUT VALIDATION TEST (DEFECT D-3) ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);
  console.log(allPassed ? "\nALL PASSED" : "\nSOME FAILED");
  process.exit(allPassed ? 0 : 1);
}

main();
