// ============================================================
//  Phase ADMR-71 — support_case_evidence storage.rules suite
// ============================================================
//
// Mirrors phase24_storage_rules_test.js's own @firebase/rules-unit-testing
// pattern exactly, scoped to the one new block this phase adds. Unlike
// every isImage()-only block phase24 already covers, this path allows BOTH
// images and PDF ("photos, documents" per the owner's own spec) -- proven
// with a positive PDF scenario, not just images. Admin-only both ways (no
// owner-uid prefix check needed: fileName is the case's own requestId, a
// deterministic, non-participant path, since only admins operate the case
// system at all).
//
// Run with: firebase emulators:exec --only storage "node scripts/phaseADMR71_evidence_rules_test.js"

const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const { ref, uploadBytes, getBytes } = require("firebase/storage");

const REPO_ROOT = path.join(__dirname, "..", "..");
const PNG = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const PDF_BYTES = new Uint8Array([0x25, 0x50, 0x44, 0x46]); // "%PDF"
const IMG = { contentType: "image/png" };
const PDF = { contentType: "application/pdf" };
const HTML = { contentType: "text/html" };

function baseClaims() {
  return { admin: false, seller: false, delivery_partner: false, employee: false };
}
const CLAIMS = {
  user: { ...baseClaims(), role: "user" },
  admin: { ...baseClaims(), role: "admin", admin: true },
};

let testEnv;
const results = [];
function record(label, pass, detail) {
  results.push({ label, pass, detail });
}

async function scenario(label, expect, fn) {
  try {
    await (expect === "allow" ? assertSucceeds(fn()) : assertFails(fn()));
    record(label, true, "");
  } catch (e) {
    record(label, false, `expected ${expect} — ${String(e.message || e).slice(0, 160)}`);
  }
}

function ctxStorage(kind, uid) {
  if (kind === "unauth") return testEnv.unauthenticatedContext().storage();
  return testEnv.authenticatedContext(uid, CLAIMS[kind]).storage();
}
const put = (s, p, bytes, meta) => () => uploadBytes(ref(s, p), bytes, meta);
const get = (s, p) => () => getBytes(ref(s, p));

async function seed(p) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await uploadBytes(ref(ctx.storage(), p), PNG, IMG);
  });
}

async function main() {
  testEnv = await initializeTestEnvironment({
    projectId: "agrimore-66a4e",
    storage: {
      rules: fs.readFileSync(path.join(REPO_ROOT, "storage.rules"), "utf8"),
      host: "127.0.0.1",
      port: 9199,
    },
  });

  const ADMIN = "admr71-admin-1";
  const OTHER_ADMIN = "admr71-admin-2";
  const USER = "admr71-user-1";
  const CASE = "case-rules-1";

  await seed(`support_case_evidence/${CASE}/seed-req-00000001.png`);

  await scenario(
    "admin uploads an image evidence file",
    "allow",
    put(ctxStorage("admin", ADMIN), `support_case_evidence/${CASE}/req-00000002.png`, PNG, IMG)
  );
  await scenario(
    "admin uploads a PDF evidence file (photos AND documents, per spec)",
    "allow",
    put(ctxStorage("admin", ADMIN), `support_case_evidence/${CASE}/req-00000003.pdf`, PDF_BYTES, PDF)
  );
  await scenario(
    "a DIFFERENT admin can also upload to the same case (admin-only, not owner-scoped)",
    "allow",
    put(ctxStorage("admin", OTHER_ADMIN), `support_case_evidence/${CASE}/req-00000004.png`, PNG, IMG)
  );
  await scenario(
    "admin reads an evidence file",
    "allow",
    get(ctxStorage("admin", ADMIN), `support_case_evidence/${CASE}/seed-req-00000001.png`)
  );
  await scenario(
    "a plain (non-admin) user cannot upload evidence",
    "deny",
    put(ctxStorage("user", USER), `support_case_evidence/${CASE}/req-evil.png`, PNG, IMG)
  );
  await scenario(
    "a plain (non-admin) user cannot read evidence",
    "deny",
    get(ctxStorage("user", USER), `support_case_evidence/${CASE}/seed-req-00000001.png`)
  );
  await scenario(
    "unauthenticated read is denied — never a public URL",
    "deny",
    get(ctxStorage("unauth"), `support_case_evidence/${CASE}/seed-req-00000001.png`)
  );
  await scenario(
    "unauthenticated write is denied",
    "deny",
    put(ctxStorage("unauth"), `support_case_evidence/${CASE}/req-evil2.png`, PNG, IMG)
  );
  await scenario(
    "admin uploading a disallowed content type (e.g. HTML) is denied",
    "deny",
    put(ctxStorage("admin", ADMIN), `support_case_evidence/${CASE}/req-evil3.html`, PNG, HTML)
  );

  await testEnv.cleanup();

  console.log("=== PHASE ADMR-71 — support_case_evidence storage.rules suite ===\n");
  for (const r of results) console.log(`  ${r.pass ? "PASSED" : "FAILED"} — ${r.label}${r.pass ? "" : ` :: ${r.detail}`}`);
  const failed = results.filter((r) => !r.pass);
  console.log(`\nscenarios: ${results.length}  failed: ${failed.length}`);
  console.log(failed.length === 0 ? "ALL PASSED" : "SOME FAILED");
  process.exit(failed.length === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error("suite crashed:", e);
  process.exit(1);
});
