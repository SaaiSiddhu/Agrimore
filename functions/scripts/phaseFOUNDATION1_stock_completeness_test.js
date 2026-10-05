// Read-only stock-audit classifier checks. Does not initialize Firebase or
// read/write Firestore.
const assert = require("node:assert/strict");
const { spawnSync } = require("node:child_process");
const { classifyStock, inspectProductStock } = require("../lib/customer/stockCompleteness");

const cases = [
  ["zero is valid stock", 0, { valid: true, quantity: 0 }],
  ["positive integer is valid stock", 25, { valid: true, quantity: 25 }],
  ["missing stock is reported", undefined, { valid: false, issue: "missing" }],
  ["null stock is reported", null, { valid: false, issue: "null" }],
  ["numeric strings are rejected", "25", { valid: false, issue: "nonnumeric" }],
  ["fractions are rejected", 1.5, { valid: false, issue: "fractional" }],
  ["negative counts are rejected", -1, { valid: false, issue: "negative" }],
  ["unsafe integers are rejected", Number.MAX_SAFE_INTEGER + 1, { valid: false, issue: "unsafe_integer" }],
  ["infinite values are rejected", Infinity, { valid: false, issue: "nonfinite" }],
];

for (const [label, value, expected] of cases) {
  assert.deepEqual(classifyStock(value), expected, label);
  process.stdout.write(`PASSED — ${label}\n`);
}

assert.deepEqual(inspectProductStock("inactive", { isActive: false }), []);
assert.deepEqual(inspectProductStock("draft", { isDraft: true }), []);
assert.deepEqual(inspectProductStock("base", { stock: 0 }), []);
assert.deepEqual(inspectProductStock("variants", {
  stock: 3,
  variants: [{ id: "ok", stock: 2 }, { id: "unknown" }, { id: "string", stock: "4" }],
}), [
  { productId: "variants", skuPath: "variants[1].stock", issue: "missing" },
  { productId: "variants", skuPath: "variants[2].stock", issue: "nonnumeric" },
]);
process.stdout.write("PASSED — sellability, valid zero, and each variant's raw stock are audited independently\n");

const auditScript = require("node:path").join(__dirname, "report_stock_completeness.js");
const liveGuard = spawnSync(process.execPath, [auditScript, "--project=demo-stock-audit"], {
  env: { ...process.env, FIRESTORE_EMULATOR_HOST: "" }, encoding: "utf8",
});
assert.equal(liveGuard.status, 1);
assert.match(liveGuard.stderr, /Refusing a live Firestore read/);
process.stdout.write("PASSED — audit refuses live Firestore reads unless explicitly authorized\n");

const writeGuard = spawnSync(process.execPath, [auditScript, "--project=demo-stock-audit", "--apply"], {
  env: { ...process.env, FIRESTORE_EMULATOR_HOST: "127.0.0.1:8080" }, encoding: "utf8",
});
assert.equal(writeGuard.status, 1);
assert.match(writeGuard.stderr, /read-only/);
process.stdout.write("PASSED — audit refuses all write/apply modes\n");

process.stdout.write("\n=== 15 stock-completeness checks passed ===\n");
