// Phase ADMR-90 — the TypeScript side of the support-case link-record-type
// contract.
//
// Asserted against apps/admin/test/fixtures/support_link_record_types.json,
// the SAME file apps/admin/test/support_link_record_types_parity_test.dart
// asserts the Dart constants against. This is the parity guard: a support
// case's linkedRecords must mean the same thing — the same allowed types,
// the same backing collection for each — on the server and in the admin
// app, exactly the pattern functions/scripts/phaseDLV1A_delivery_states_test.js
// already establishes for the delivery vocabulary.
//
// No emulator. Run with:
//   cd functions && npm run build && node scripts/phaseADMR90_support_link_type_parity_test.js
const fs = require("fs");
const path = require("path");
const { LINK_RECORD_TYPES, LINK_COLLECTION } = require("../lib/admin/supportCases");

const fixture = JSON.parse(fs.readFileSync(
  path.join(__dirname, "..", "..", "apps", "admin", "test", "fixtures", "support_link_record_types.json"),
  "utf8"
));

let passed = 0;
const failures = [];
function check(label, ok, detail) {
  if (ok) passed++;
  else failures.push(`${label} :: ${detail}`);
}

// 1 — exactly the fixture's types, in the fixture's own order (order matters:
// it drives the Add-link dialog's own presented option order on the Dart side).
check(
  "link_record_types_match_fixture_order",
  JSON.stringify(LINK_RECORD_TYPES) === JSON.stringify(fixture.linkRecordTypes),
  `ts=${JSON.stringify(LINK_RECORD_TYPES)} fixture=${JSON.stringify(fixture.linkRecordTypes)}`
);

// 2 — exactly the fixture's collection mapping, key for key, value for value.
{
  const tsKeys = Object.keys(LINK_COLLECTION).sort();
  const fixtureKeys = Object.keys(fixture.linkRecordCollection).sort();
  check("link_collection_same_keys", JSON.stringify(tsKeys) === JSON.stringify(fixtureKeys),
    `ts=${JSON.stringify(tsKeys)} fixture=${JSON.stringify(fixtureKeys)}`);
  for (const type of fixtureKeys) {
    check(`link_collection_${type}`, LINK_COLLECTION[type] === fixture.linkRecordCollection[type],
      `ts=${LINK_COLLECTION[type]} fixture=${fixture.linkRecordCollection[type]}`);
  }
}

// 3 — every fixture type has a collection entry, and vice versa (catches a
// type added to LINK_RECORD_TYPES with no matching LINK_COLLECTION entry,
// which would throw at runtime the first time that type is actually used).
for (const type of fixture.linkRecordTypes) {
  check(`type_has_collection_${type}`, typeof LINK_COLLECTION[type] === "string" && LINK_COLLECTION[type].length > 0,
    `LINK_COLLECTION[${type}] = ${LINK_COLLECTION[type]}`);
}

const total = passed + failures.length;
console.log("=== PHASE ADMR-90 — support-case link-record-type contract (TS side) ===");
failures.forEach((f) => console.log(`FAILED — ${f}`));
console.log(`${passed}/${total} checks passed`);
if (failures.length) { console.log("PHASE ADMR-90: FAILED"); process.exit(1); }
console.log("PHASE ADMR-90: ALL PASSED");
