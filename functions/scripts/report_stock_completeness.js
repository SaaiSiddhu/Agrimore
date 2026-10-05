// Read-only owner inventory audit. It never modifies Firestore documents.
// Default safety: run only against a Firebase emulator (FIRESTORE_EMULATOR_HOST
// set). A live catalog read requires an explicit --allow-live-read flag and an
// explicit --project value; this repository task never uses that flag.
//
// Emulator example:
//   firebase emulators:exec --only firestore --project demo-stock-audit \
//     "node scripts/report_stock_completeness.js --project=demo-stock-audit"

const admin = require("firebase-admin");
const { inspectProductStock } = require("../lib/customer/stockCompleteness");

function argValue(prefix) {
  const arg = process.argv.find((value) => value.startsWith(prefix));
  return arg ? arg.slice(prefix.length) : null;
}

async function buildReport(db, projectId, pageSize = 500) {
  let cursor = null;
  let scanned = 0;
  const issues = [];
  do {
    let query = db.collection("products").orderBy(admin.firestore.FieldPath.documentId()).limit(pageSize);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    for (const doc of page.docs) {
      scanned += 1;
      issues.push(...inspectProductStock(doc.id, doc.data()));
    }
    cursor = page.docs.length === pageSize ? page.docs[page.docs.length - 1] : null;
  } while (cursor);

  const byIssue = {};
  for (const row of issues) byIssue[row.issue] = (byIssue[row.issue] ?? 0) + 1;
  // The report deliberately excludes product names, addresses, owner data,
  // prices and complete product payloads. Owners can use the document/SKU
  // path to coordinate a physical count without exposing unrelated fields.
  return {
    generatedAt: new Date().toISOString(),
    projectId,
    readOnly: true,
    scannedProductDocuments: scanned,
    incompleteSellableSkus: issues.length,
    issueCounts: byIssue,
    rows: issues,
  };
}

async function main() {
  if (process.argv.includes("--apply") || process.argv.includes("--write")) {
    throw new Error("This audit is read-only and does not support write mode");
  }
  const projectId = argValue("--project=");
  const usingEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
  const allowLiveRead = process.argv.includes("--allow-live-read");
  if (!projectId) throw new Error("Pass an explicit --project=<id>");
  if (usingEmulator && !projectId.startsWith("demo-")) {
    throw new Error("Emulator audits must use a demo-* project ID");
  }
  if (!usingEmulator && !allowLiveRead) {
    throw new Error("Refusing a live Firestore read; use an emulator or explicitly pass --allow-live-read");
  }

  admin.initializeApp({ projectId });
  const report = await buildReport(admin.firestore(), projectId);
  process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
}

if (require.main === module) {
  main().catch((error) => {
    process.stderr.write(`Stock completeness audit stopped: ${error.message}\n`);
    process.exitCode = 1;
  });
}

module.exports = { buildReport };
