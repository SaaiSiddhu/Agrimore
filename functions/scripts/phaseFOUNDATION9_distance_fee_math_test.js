// F3.3 distance-fee contract: integer paise, exact-route-metre pricing,
// hard cap and fail-closed behavior before route integration is active.
// Run after `npm run build` with `node scripts/phaseFOUNDATION9_distance_fee_math_test.js`.

const assert = require("node:assert/strict");
const { HttpsError } = require("firebase-functions/v2/https");
const { parseDeliveryFeeSchedule, computeFeeFromSchedule } = require("../lib/customer/deliveryFeeSchedule");

let passed = 0;
function check(name, fn) {
  fn();
  passed++;
  console.log(`PASSED — ${name}`);
}

function expectFailedPrecondition(fn) {
  assert.throws(fn, (error) => error instanceof HttpsError && error.code === "failed-precondition");
}

const schedule = parseDeliveryFeeSchedule({
  type: "distance",
  baseFeePaise: 2500,
  ratePerKmPaise: 3000,
});

check("parses a seller distance schedule stored entirely in integer paise", () => {
  assert.deepEqual(schedule, { type: "distance", baseFeePaise: 2500, ratePerKmPaise: 3000 });
});

check("computes one-way fee from exact metres and rounds the total to paise", () => {
  assert.equal(computeFeeFromSchedule(schedule, 10000, 1200), 61);
});

check("zero distance charges only the configured base fee", () => {
  assert.equal(computeFeeFromSchedule(schedule, 0, 0), 25);
});

check("rounds a half-paise fractional kilometre component to the nearest paise", () => {
  const fractional = parseDeliveryFeeSchedule({ type: "distance", baseFeePaise: 0, ratePerKmPaise: 1 });
  assert.equal(computeFeeFromSchedule(fractional, 0, 500), 0.01);
});

check("refuses to compute a distance schedule without server-verified route metres", () => {
  expectFailedPrecondition(() => computeFeeFromSchedule(schedule, 10000));
});

check("refuses negative route distance", () => {
  expectFailedPrecondition(() => computeFeeFromSchedule(schedule, 10000, -1));
});

check("refuses fractional route metres", () => {
  expectFailedPrecondition(() => computeFeeFromSchedule(schedule, 10000, 1.5));
});

check("refuses a calculated charge above the existing ₹1,000 ceiling", () => {
  expectFailedPrecondition(() => computeFeeFromSchedule(schedule, 0, 400000));
});

check("accepts exactly the existing ₹1,000 ceiling", () => {
  const atCap = parseDeliveryFeeSchedule({ type: "distance", baseFeePaise: 100000, ratePerKmPaise: 1 });
  assert.equal(computeFeeFromSchedule(atCap, 0, 0), 1000);
});

check("rejects negative, fractional, unsafe, or above-cap base components", () => {
  for (const baseFeePaise of [-1, 1.5, Number.MAX_SAFE_INTEGER + 1, 100001]) {
    expectFailedPrecondition(() => parseDeliveryFeeSchedule({ type: "distance", baseFeePaise, ratePerKmPaise: 1 }));
  }
});

check("rejects non-positive, fractional, unsafe, or above-cap per-km rates", () => {
  for (const ratePerKmPaise of [0, -1, 1.5, Number.MAX_SAFE_INTEGER + 1, 100001]) {
    expectFailedPrecondition(() => parseDeliveryFeeSchedule({ type: "distance", baseFeePaise: 0, ratePerKmPaise }));
  }
});

check("does not alter existing flat or subtotal-slab calculation", () => {
  const flat = parseDeliveryFeeSchedule({ type: "flat", amount: 12.5 });
  const slab = parseDeliveryFeeSchedule({ type: "slab", slabs: [{ minOrderValue: 0, fee: 40 }, { minOrderValue: 500, fee: 20 }] });
  assert.equal(computeFeeFromSchedule(flat, 100), 12.5);
  assert.equal(computeFeeFromSchedule(slab, 700), 20);
});

console.log(`\n=== ${passed} distance fee checks passed ===`);
