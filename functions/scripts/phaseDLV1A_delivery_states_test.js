// Phase DLV-1A — the TypeScript mirror of the delivery vocabulary.
//
// Asserted against packages/agrimore_core/test/fixtures/delivery_status_table.json,
// the SAME table packages/agrimore_core/test/delivery/delivery_enums_test.dart
// asserts the Dart enum against. This is the parity guard: the server
// (syncDeliveryTask, and DLV-2's transition callables) and every app must
// agree on what a status string means and which moves are legal.
//
// No emulator. Run with:
//   cd functions && npm run build && node scripts/phaseDLV1A_delivery_states_test.js
const fs = require("fs");
const path = require("path");
const {
  TASK_STATUSES,
  taskStatusFromWire,
  isTerminal,
  canTransition,
  taskStatusFromOrder,
} = require("../lib/delivery/states");

const table = JSON.parse(fs.readFileSync(
  path.join(__dirname, "..", "..", "packages", "agrimore_core", "test", "fixtures", "delivery_status_table.json"),
  "utf8"
));

// The fixture names states by their Dart enum name; TS works in wire values.
const wireOf = (name) => table.taskStatusWire[name];

let passed = 0;
const failures = [];
function check(label, ok, detail) {
  if (ok) passed++;
  else failures.push(`${label} :: ${detail}`);
}

// 1 — exactly the table's states, same wire values.
{
  const expected = Object.values(table.taskStatusWire).sort();
  const actual = [...TASK_STATUSES].sort();
  check("states_match_table", JSON.stringify(expected) === JSON.stringify(actual),
    `table=${expected} ts=${actual}`);
  for (const [name, wire] of Object.entries(table.taskStatusWire)) {
    check(`fromWire_${name}`, taskStatusFromWire(wire) === wire, `got ${taskStatusFromWire(wire)}`);
    check(`fromWire_upper_${name}`, taskStatusFromWire(wire.toUpperCase()) === wire, "case-insensitive");
  }
  check("fromWire_unknown_is_null", taskStatusFromWire("nonsense") === null && taskStatusFromWire(undefined) === null,
    "unknown must be null");
}

// 2 — terminal states.
for (const name of Object.keys(table.taskStatusWire)) {
  const want = table.terminal.includes(name);
  check(`terminal_${name}`, isTerminal(wireOf(name)) === want, `want ${want}`);
}

// 3 — every (from, to) pair.
for (const from of Object.keys(table.taskStatusWire)) {
  for (const to of Object.keys(table.taskStatusWire)) {
    const want = table.transitions[from].includes(to);
    check(`transition_${from}_${to}`, canTransition(wireOf(from), wireOf(to)) === want, `want ${want}`);
  }
}

// 4 — every legacy order status case.
table.fromOrderStatus.forEach((c, i) => {
  const got = taskStatusFromOrder({
    orderStatus: c.orderStatus,
    status: c.status,
    deliveryPartnerId: c.hasPartner ? "rider-1" : null,
  });
  const want = c.expect === null ? null : wireOf(c.expect);
  check(`fromOrder_${i}_${c.orderStatus}_${c.status}_${c.hasPartner}`, got === want, `want ${want} got ${got}`);
});

// 5 — "has a partner" means a non-empty string, as firestore.rules reads it.
check("empty_partner_is_no_partner",
  taskStatusFromOrder({ orderStatus: "ready_for_pickup", deliveryPartnerId: "" }) === "searching",
  "empty string must not count as assigned");

// 6 — DLV-C1: the busy/active list is the fixture's list, in order.
{
  const { RIDER_ACTIVE_ORDER_STATUSES } = require("../lib/delivery/dispatch");
  check("rider_active_list_matches_table",
    JSON.stringify(RIDER_ACTIVE_ORDER_STATUSES) === JSON.stringify(table.riderActiveOrderStatuses),
    `${JSON.stringify(RIDER_ACTIVE_ORDER_STATUSES)} vs ${JSON.stringify(table.riderActiveOrderStatuses)}`);
  // Every entry is a rider leg that is not over.
  table.riderActiveOrderStatuses.forEach((v) => {
    const t = taskStatusFromOrder({ orderStatus: v, deliveryPartnerId: "r1" });
    check(`rider_active_${v}_is_open_leg`, t !== null && !isTerminal(t) && t !== "searching", `got ${t}`);
  });
}

// DLV-P1: server time limits the rider app mirrors (DeliveryTiming).
{
  const { OFFER_TTL_MS, LOCATION_FRESHNESS_MS } = require("../lib/delivery/dispatch");
  const { SILENT_OFFLINE_MS } = require("../lib/delivery/riderPresence");
  check("timing_offer_lifetime", OFFER_TTL_MS === table.timing.offerLifetimeMs, `${OFFER_TTL_MS} vs ${table.timing.offerLifetimeMs}`);
  check("timing_silent_offline", SILENT_OFFLINE_MS === table.timing.riderSilentOfflineMs, `${SILENT_OFFLINE_MS} vs ${table.timing.riderSilentOfflineMs}`);
  check("timing_location_freshness", LOCATION_FRESHNESS_MS === table.timing.dispatchLocationFreshnessMs,
    `${LOCATION_FRESHNESS_MS} vs ${table.timing.dispatchLocationFreshnessMs}`);
}

const total = passed + failures.length;
console.log(`=== PHASE DLV-1A — delivery states (TS mirror) ===`);
failures.forEach((f) => console.log(`FAILED — ${f}`));
console.log(`${passed}/${total} checks passed`);
if (failures.length) { console.log("PHASE DLV-1A states: FAILED"); process.exit(1); }
console.log("PHASE DLV-1A states: ALL PASSED");
