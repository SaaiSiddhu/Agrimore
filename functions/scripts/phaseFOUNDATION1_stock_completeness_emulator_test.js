// Read-only pagination/report test. Run with the Firestore emulator:
//   firebase emulators:exec --only firestore --project demo-stock-audit \
//     "node scripts/phaseFOUNDATION1_stock_completeness_emulator_test.js"
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "demo-stock-audit";

const assert = require("node:assert/strict");
const admin = require("firebase-admin");
admin.initializeApp({ projectId: "demo-stock-audit" });
const { buildReport } = require("./report_stock_completeness");

async function main() {
  const db = admin.firestore();
  await db.collection("products").doc("audit-complete").set({ stock: 0, isActive: true });
  await db.collection("products").doc("audit-incomplete").set({ isActive: true, variants: [{ id: "v0", stock: "2" }] });
  await db.collection("products").doc("audit-draft").set({ isDraft: true });
  const before = await db.collection("products").get();
  const beforeData = new Map(before.docs.map((doc) => [doc.id, doc.data()]));

  const report = await buildReport(db, "demo-stock-audit", 2);
  assert.equal(report.readOnly, true);
  assert.equal(report.scannedProductDocuments, 3);
  assert.equal(report.incompleteSellableSkus, 2);
  assert.deepEqual(report.rows, [
    { productId: "audit-incomplete", skuPath: "stock", issue: "missing" },
    { productId: "audit-incomplete", skuPath: "variants[0].stock", issue: "nonnumeric" },
  ]);

  const after = await db.collection("products").get();
  assert.deepEqual(new Map(after.docs.map((doc) => [doc.id, doc.data()])), beforeData);
  process.stdout.write("PASSED — paged read-only audit reports unknown stock without changing product documents\n");
  process.stdout.write("\n=== 1 emulator stock-audit check passed ===\n");
}

main().catch((error) => {
  process.stderr.write(`${error.stack || error}\n`);
  process.exitCode = 1;
});
