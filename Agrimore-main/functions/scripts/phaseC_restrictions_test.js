// Phase C, Workstream 3 — Product Credit redemption restrictions engine.
// Table-driven proof of functions/src/customer/redemptionRules.ts's
// computeRedeemableAmount: redemptionEnabled false, below the minimum
// order value, an absolute cap, a percentage cap, a percentage cap of 0
// (means no credit, not unlimited), ineligible categories (eligibleSubtotal
// 0), a request above the available balance, and the round-DOWN rounding
// rule. This is a pure function — no emulator/Firestore needed at all.
// Run with: node scripts/phaseC_restrictions_test.js
const { computeRedeemableAmount } = require("../lib/customer/redemptionRules");

const baseProgram = {
  redemptionEnabled: true,
  minOrderValueForRedemption: 0,
  maxCreditPerOrder: null,
  maxCreditPercentOfOrder: null,
};

const cases = [
  {
    name: "redemptionEnabled false -> disallowed",
    input: {
      program: { ...baseProgram, redemptionEnabled: false },
      orderSubtotal: 1000,
      eligibleSubtotal: 1000,
      availableCredit: 500,
      requestedAmount: 500,
    },
    expectAllowed: false,
    expectAmount: 0,
  },
  {
    name: "below minimum order value -> disallowed, with shortfall",
    input: {
      program: { ...baseProgram, minOrderValueForRedemption: 500 },
      orderSubtotal: 300,
      eligibleSubtotal: 300,
      availableCredit: 500,
      requestedAmount: 500,
    },
    expectAllowed: false,
    expectAmount: 0,
    expectReasonIncludes: "200", // shortfall = 500 - 300
  },
  {
    name: "absolute cap (maxCreditPerOrder) binds",
    input: {
      program: { ...baseProgram, maxCreditPerOrder: 100 },
      orderSubtotal: 1000,
      eligibleSubtotal: 1000,
      availableCredit: 500,
      requestedAmount: 500,
    },
    expectAllowed: true,
    expectAmount: 100,
  },
  {
    name: "percentage cap (10% of eligible order value) binds",
    input: {
      program: { ...baseProgram, maxCreditPercentOfOrder: 10 },
      orderSubtotal: 1000,
      eligibleSubtotal: 1000,
      availableCredit: 500,
      requestedAmount: 500,
    },
    expectAllowed: true,
    expectAmount: 100, // 10% of 1000
  },
  {
    name: "percentage cap of 0 -> no credit at all, never unlimited",
    input: {
      program: { ...baseProgram, maxCreditPercentOfOrder: 0 },
      orderSubtotal: 1000,
      eligibleSubtotal: 1000,
      availableCredit: 500,
      requestedAmount: 500,
    },
    expectAllowed: false,
    expectAmount: 0,
  },
  {
    name: "ineligible categories -> eligibleSubtotal 0 -> disallowed",
    input: {
      program: { ...baseProgram },
      orderSubtotal: 1000,
      eligibleSubtotal: 0,
      availableCredit: 500,
      requestedAmount: 500,
    },
    expectAllowed: false,
    expectAmount: 0,
  },
  {
    name: "requested far above available -> capped to availableCredit",
    input: {
      program: { ...baseProgram },
      orderSubtotal: 1000,
      eligibleSubtotal: 1000,
      availableCredit: 300,
      requestedAmount: 999999,
    },
    expectAllowed: true,
    expectAmount: 300,
  },
  {
    name: "round-DOWN proof: 33.335 available/requested floors to 33.33, never rounds up to 33.34",
    input: {
      program: { ...baseProgram },
      orderSubtotal: 1000,
      eligibleSubtotal: 1000,
      availableCredit: 33.335,
      requestedAmount: 33.335,
    },
    expectAllowed: true,
    expectAmount: 33.33,
  },
  {
    name: "empty cart (subtotal 0, eligible 0) -> disallowed",
    input: {
      program: { ...baseProgram },
      orderSubtotal: 0,
      eligibleSubtotal: 0,
      availableCredit: 500,
      requestedAmount: 500,
    },
    expectAllowed: false,
    expectAmount: 0,
  },
  {
    name: "availableCredit 0 -> disallowed",
    input: {
      program: { ...baseProgram },
      orderSubtotal: 1000,
      eligibleSubtotal: 1000,
      availableCredit: 0,
      requestedAmount: 500,
    },
    expectAllowed: false,
    expectAmount: 0,
  },
  {
    name: "maxCreditPerOrder 0 -> no credit at all",
    input: {
      program: { ...baseProgram, maxCreditPerOrder: 0 },
      orderSubtotal: 1000,
      eligibleSubtotal: 1000,
      availableCredit: 500,
      requestedAmount: 500,
    },
    expectAllowed: false,
    expectAmount: 0,
  },
];

function main() {
  let allPassed = true;
  const results = {};

  for (const testCase of cases) {
    const result = computeRedeemableAmount(testCase.input);
    let pass = result.allowed === testCase.expectAllowed && result.amount === testCase.expectAmount;
    if (pass && testCase.expectReasonIncludes) {
      pass = result.reasons.some((r) => r.includes(testCase.expectReasonIncludes));
    }
    results[testCase.name] = pass
      ? `PASSED — allowed=${result.allowed} amount=${result.amount} reasons=${JSON.stringify(result.reasons)}`
      : `FAILED — expected allowed=${testCase.expectAllowed} amount=${testCase.expectAmount}, got ${JSON.stringify(result)}`;
    if (!pass) allPassed = false;
  }

  console.log("=== PHASE C — REDEMPTION RESTRICTIONS TEST (table-driven) ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);
  console.log(allPassed ? "\nALL PASSED" : "\nSOME FAILED");
  process.exit(allPassed ? 0 : 1);
}

main();
