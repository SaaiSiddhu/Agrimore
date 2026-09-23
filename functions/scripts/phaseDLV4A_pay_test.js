// Phase DLV-4A — rider pay rules, pure (functions/src/delivery/riderPay.ts).
// No emulator needed. Run with: node scripts/phaseDLV4A_pay_test.js
// Requires: npm run build.
const P = require("../lib/delivery/riderPay");

const results = [];
function record(label, pass, detail) {
  results.push({ label, pass });
  console.log(`${pass ? "PASSED" : "FAILED"} — ${label}${pass ? "" : ` :: ${detail}`}`);
}
const STORE = { lat: 9.9252, lng: 78.1198 };
const HOME = { lat: 9.8982, lng: 78.1198 }; // 3.0 km south
const D = P.DEFAULT_RIDER_PAY_RATES;

console.log("=== PHASE DLV-4A — rider pay (pure) ===");
record("p01_defaults_are_the_owner_seed", D.basePay === 25 && D.perKm === 6 && D.waitingPerMin === 1 && D.waitingFreeMin === 10 && D.codCashLimit === 2000 && D.maxKm === 25, JSON.stringify(D));
const s1 = P.sanitizeRates({ basePay: 30, perKm: "7", waitingPerMin: -1, codCashLimit: 5000, maxKm: 0, junk: 9 });
record("p02_bad_rates_fall_back_and_are_named", s1.rates.basePay === 30 && s1.rates.perKm === 6 && s1.rates.waitingPerMin === 1 &&
  s1.rates.codCashLimit === 5000 && s1.rates.maxKm === 25 && s1.rejected.sort().join() === "maxKm,perKm,waitingPerMin", JSON.stringify(s1));
record("p03_no_settings_doc_means_defaults", JSON.stringify(P.sanitizeRates(undefined).rates) === JSON.stringify(D), "");

const via = { plan: "via_pickup", legs: [{ distanceMeters: 2100 }, { distanceMeters: 3911 }], origin: { lat: 9.94, lng: 78.12 } };
record("p04_road_distance_from_a_via_pickup_route", (() => { const t = P.tripKm({ pickup: STORE, drop: HOME, route: via }); return t.source === "route" && Math.abs(t.km - 3.911) < 1e-9; })(), "");
const toDropAtStore = { plan: "to_drop", legs: [{ distanceMeters: 3922 }], origin: { lat: STORE.lat + 0.0005, lng: STORE.lng } };
const toDropFar = { plan: "to_drop", legs: [{ distanceMeters: 1500 }], origin: { lat: 9.91, lng: 78.12 } };
record("p05_to_drop_route_counts_only_if_computed_at_the_store",
  P.tripKm({ pickup: STORE, drop: HOME, route: toDropAtStore }).source === "route" &&
  P.tripKm({ pickup: STORE, drop: HOME, route: toDropFar }).source === "straight_line", "");
const sl = P.tripKm({ pickup: STORE, drop: HOME });
record("p06_fallback_straight_line_x_1_35", sl.source === "straight_line" && Math.abs(sl.km - 3.002 * 1.35) < 0.02, JSON.stringify(sl));
record("p07_no_points_no_distance", P.tripKm(null).source === "none" && P.tripKm({ pickup: STORE }).km === 0, "");

const t0 = Date.UTC(2026, 8, 23, 12, 0, 0);
record("p08_waiting_beyond_10_min_only_capped_at_60",
  P.billableWaitMinutes(t0, t0 + 8 * 60000, D) === 0 &&
  P.billableWaitMinutes(t0, t0 + 17.9 * 60000, D) === 7 &&
  P.billableWaitMinutes(t0, t0 + 300 * 60000, D) === 50 &&
  P.billableWaitMinutes(null, t0, D) === 0 && P.billableWaitMinutes(t0 + 5, t0, D) === 0, "");

const pay = P.riderPay(D, 3.911, 7);
record("p09_pay_is_base_plus_km_plus_waiting_on_the_km_shown", pay.total === 55.46 && pay.lines[1].amount === 23.46 && pay.lines.length === 3 &&
  pay.lines[1].km === 3.91 && pay.lines[2].minutes === 7, JSON.stringify(pay));
record("p10_no_waiting_line_when_none", P.riderPay(D, 2, 0).lines.length === 2 && P.riderPay(D, 2, 0).total === 37, "");
record("p11_distance_capped_at_max_km", P.riderPay(D, 400, 0).total === 25 + 25 * 6, JSON.stringify(P.riderPay(D, 400, 0)));

record("p12_settle_nets_cash_against_pay",
  JSON.stringify(P.settle(900, 300)) === JSON.stringify({ netted: 300, payout: 600, cashAfter: 0 }) &&
  JSON.stringify(P.settle(900, 2500)) === JSON.stringify({ netted: 900, payout: 0, cashAfter: 1600 }) &&
  JSON.stringify(P.settle(0, 0)) === JSON.stringify({ netted: 0, payout: 0, cashAfter: 0 }), "");

// Monday 2026-09-28 00:30 IST = Sunday 2026-09-27 19:00 UTC → cutoff Monday 00:00 IST.
const c = P.statementCutoff(Date.UTC(2026, 8, 27, 19, 0, 0));
record("p13_statement_cutoff_is_monday_midnight_ist", c.cutoffMs === Date.UTC(2026, 8, 27, 18, 30, 0) && c.weekKey === "2026-W39", JSON.stringify(c));
const mid = P.statementCutoff(Date.UTC(2026, 8, 24, 6, 0, 0)); // a Thursday
record("p14_mid_week_run_cuts_at_the_previous_monday", mid.cutoffMs === Date.UTC(2026, 8, 20, 18, 30, 0) && mid.weekKey === "2026-W38", JSON.stringify(mid));

const ok = P.validateBankDetails({ accountHolderName: " Ravi Kumar ", bankAccountNumber: "1234 5678 9012", ifscCode: "sbin0001234" });
record("p15_bank_details_normalised", ok.ok && ok.value.bankAccountNumber === "123456789012" && ok.value.ifscCode === "SBIN0001234" &&
  ok.value.accountHolderName === "Ravi Kumar" && ok.value.upiId === null, JSON.stringify(ok));
record("p16_bank_details_refused",
  P.validateBankDetails({ accountHolderName: "Ravi", bankAccountNumber: "12", ifscCode: "SBIN0001234" }).error === "bankAccountNumber" &&
  P.validateBankDetails({ accountHolderName: "Ravi", bankAccountNumber: "123456789", ifscCode: "SBIN1001234" }).error === "ifscCode" &&
  P.validateBankDetails({ upiId: "not-a-upi" }).error === "upiId" &&
  P.validateBankDetails({}).error === "empty" &&
  P.validateBankDetails({ upiId: "ravi.k@okaxis" }).ok === true, "");
record("p17_payout_destination", P.hasPayoutDestination({ bankAccountNumber: "123456789", ifscCode: "SBIN0001234" }) &&
  P.hasPayoutDestination({ upiId: "r@upi" }) && !P.hasPayoutDestination({ bankAccountNumber: "123" }) && !P.hasPayoutDestination(undefined), "");

const failed = results.filter((r) => !r.pass);
console.log(`\n${results.length - failed.length}/${results.length} passed`);
if (failed.length) { console.log("PHASE DLV-4A pay: FAILED"); process.exit(1); }
console.log("PHASE DLV-4A pay: ALL PASSED");
process.exit(0);
