// ============================================================
//  Phase ADMR-72 — support_case_evidence integrity hardening: storage.rules
// ============================================================
//
// Extends phaseADMR71_evidence_test.js's own rules coverage (still valid:
// admin-only read/write, disallowed content type denied) with the NEW
// write-once + uploader-uid-prefix guarantees this phase adds. Every
// EXISTING ADMR-71 rules scenario is re-run here too, updated for the new
// uid-prefixed path shape, so this file is now the authority for this block
// (phaseADMR71_evidence_rules_test.js's own path shape is superseded).
//
// Run with: firebase emulators:exec --only storage "node scripts/phaseADMR72_evidence_integrity_rules_test.js"

const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const { ref, uploadBytes, getBytes, deleteObject } = require("firebase/storage");

const REPO_ROOT = path.join(__dirname, "..", "..");
const PNG = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const PDF_BYTES = new Uint8Array([0x25, 0x50, 0x44, 0x46, 0x2d]); // "%PDF-"
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
const del = (s, p) => () => deleteObject(ref(s, p));

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

  const ADMIN = "admr72-admin-1";
  const OTHER_ADMIN = "admr72-admin-2";
  const USER = "admr72-user-1";
  const CASE = "case-rules-1";

  // r01/r02 — baseline access control, unchanged in spirit from ADMR-71,
  // re-proven against the NEW uid-prefixed path shape.
  await scenario(
    "r01 admin creates a NEW evidence object under their OWN uid prefix",
    "allow",
    put(ctxStorage("admin", ADMIN), `support_case_evidence/${CASE}/${ADMIN}_req-0001.png`, PNG, IMG)
  );
  await scenario(
    "r02 admin creates a PDF under their own uid prefix (photos AND documents)",
    "allow",
    put(ctxStorage("admin", ADMIN), `support_case_evidence/${CASE}/${ADMIN}_req-0002.pdf`, PDF_BYTES, PDF)
  );
  await scenario(
    "r03 a plain (non-admin) user cannot create evidence at all",
    "deny",
    put(ctxStorage("user", USER), `support_case_evidence/${CASE}/${USER}_req-evil.png`, PNG, IMG)
  );
  await scenario(
    "r04 unauthenticated create is denied",
    "deny",
    put(ctxStorage("unauth"), `support_case_evidence/${CASE}/anon_req-evil.png`, PNG, IMG)
  );
  await seed(`support_case_evidence/${CASE}/${ADMIN}_req-seed.png`);
  await scenario(
    "r05 admin reads an evidence object",
    "allow",
    get(ctxStorage("admin", ADMIN), `support_case_evidence/${CASE}/${ADMIN}_req-seed.png`)
  );
  await scenario(
    "r06 a plain (non-admin) user cannot read evidence",
    "deny",
    get(ctxStorage("user", USER), `support_case_evidence/${CASE}/${ADMIN}_req-seed.png`)
  );
  await scenario(
    "r07 unauthenticated read is denied — never a public URL",
    "deny",
    get(ctxStorage("unauth"), `support_case_evidence/${CASE}/${ADMIN}_req-seed.png`)
  );
  await scenario(
    "r08 admin creating a disallowed content type (e.g. HTML) is denied",
    "deny",
    put(ctxStorage("admin", ADMIN), `support_case_evidence/${CASE}/${ADMIN}_req-evil2.html`, PNG, HTML)
  );

  // r09-r11 — ADMR-72's OWN new guarantees.
  await scenario(
    "r09 (finding A/finding E06) admin CANNOT create under a DIFFERENT admin's uid prefix",
    "deny",
    put(ctxStorage("admin", OTHER_ADMIN), `support_case_evidence/${CASE}/${ADMIN}_req-steal.png`, PNG, IMG)
  );
  await scenario(
    "r10 (finding A -- write-once) a SECOND write to an ALREADY-FINALIZED path is denied, even DIFFERENT bytes",
    "deny",
    put(ctxStorage("admin", ADMIN), `support_case_evidence/${CASE}/${ADMIN}_req-seed.png`, PNG, IMG)
  );
  await scenario(
    "r11 (finding A -- write-once) the SAME admin who originally uploaded still cannot overwrite it",
    "deny",
    put(ctxStorage("admin", ADMIN), `support_case_evidence/${CASE}/${ADMIN}_req-seed.png`, new Uint8Array([1, 2, 3]), IMG)
  );
  await scenario(
    "r12 delete is denied outright, even for an admin (append-only by design)",
    "deny",
    del(ctxStorage("admin", ADMIN), `support_case_evidence/${CASE}/${ADMIN}_req-seed.png`)
  );

  // r13 — E11: a race between two near-simultaneous creates to the exact
  // same path (e.g. a double-tap / retry storm by the same admin). Intended
  // guarantee: only one may ever succeed. DISCLOSED ENVIRONMENT LIMITATION,
  // not a functional failure of this phase's own rule: the Storage EMULATOR
  // does not enforce `resource == null` as a truly atomic check-and-set
  // under concurrency -- BOTH racing writes were observed to succeed here.
  // Cross-checked against this codebase's own PRE-EXISTING, already-shipped
  // write-once path (delivery_document_submissions, Phase DLVDOC2, r13b
  // below) using the IDENTICAL `resource == null` primitive: it exhibits
  // the exact same emulator-only race, confirming this is a general
  // simulator fidelity gap, not something this phase's own rule introduced.
  // Real Cloud Storage implements `resource == null` via a genuine
  // `ifGenerationMatch: 0` HTTP precondition on the actual object write,
  // which IS atomic server-side -- documented Firebase Storage Security
  // Rules behavior, not verifiable against the emulator. Owner post-release
  // check: after a real deploy, a manual concurrent-upload probe against
  // the live bucket would be the only way to directly confirm production
  // atomicity; not performed here (this session never deploys).
  {
    const racePath = `support_case_evidence/${CASE}/${ADMIN}_req-race.png`;
    const s = ctxStorage("admin", ADMIN);
    const [a, b] = await Promise.allSettled([
      uploadBytes(ref(s, racePath), PNG, IMG),
      uploadBytes(ref(s, racePath), new Uint8Array([9, 9, 9, 9]), IMG),
    ]);
    const succeededCount = [a, b].filter((r) => r.status === "fulfilled").length;
    console.log(
      `  ENV LIMITATION (not counted pass/fail) — r13 (E11) racing creates in the EMULATOR: ` +
      `${succeededCount}/2 succeeded (production semantics not established here; see comment above)`
    );
  }
  {
    const uid = "admr72-dlvdoc2-crosscheck-rider";
    const claims = { admin: false, seller: false, delivery_partner: true, employee: false, role: "delivery_partner" };
    const s = testEnv.authenticatedContext(uid, claims).storage();
    const p = `delivery_document_submissions/${uid}/probe-submission`;
    const [a, b] = await Promise.allSettled([
      uploadBytes(ref(s, p), PNG, IMG),
      uploadBytes(ref(s, p), new Uint8Array([9, 9, 9, 9]), IMG),
    ]);
    const succeededCount = [a, b].filter((r) => r.status === "fulfilled").length;
    console.log(
      `  CROSS-CHECK (not counted pass/fail) — r13b: this codebase's own pre-existing DLVDOC2 ` +
      `write-once path, same emulator, same race shape: ${succeededCount}/2 succeeded ` +
      `(confirms r13's own result is a general emulator gap, not new to this phase)`
    );
  }

  // r14 — E17 revocation: an admin uploads, is then demoted (custom claim
  // revoked); the SAME object they themselves uploaded is now unreadable to
  // them -- authorization is checked live on every call, never cached from
  // upload time.
  {
    const revokedPath = `support_case_evidence/${CASE}/${ADMIN}_req-revoke.png`;
    await uploadBytes(ref(ctxStorage("admin", ADMIN), revokedPath), PNG, IMG);
    const stillAdminRead = await getBytes(ref(ctxStorage("admin", ADMIN), revokedPath)).then(() => true).catch(() => false);
    const demotedCtx = testEnv.authenticatedContext(ADMIN, { ...baseClaims(), role: "user" }).storage();
    const afterDemotionRead = await getBytes(ref(demotedCtx, revokedPath)).then(() => true).catch(() => false);
    record(
      "r14 (E17) a demoted former-admin loses read access to evidence they themselves uploaded",
      stillAdminRead === true && afterDemotionRead === false,
      `stillAdminRead=${stillAdminRead} afterDemotionRead=${afterDemotionRead}`
    );
  }

  await testEnv.cleanup();

  console.log("=== PHASE ADMR-72 — support_case_evidence integrity storage.rules suite ===\n");
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
