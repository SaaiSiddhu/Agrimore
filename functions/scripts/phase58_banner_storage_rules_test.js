// ============================================================
//  Phase ADMR-2 — category/section/sponsored banner storage.rules
// ============================================================
//
// FINDING: three admin CMS uploaders wrote to paths storage.rules never
// matched, so every upload fell through to the file's own final
// `match /{allPaths=**} { allow read, write: if false; }` and had been
// silently failing:
//   - category_management_screen.dart uploads to the NESTED
//     categories/icons/{name} and categories/banners/{name} — the existing
//     rule only matched the FLAT categories/{fileName} (one path segment).
//   - section_banner_provider.dart uploads to section_banners/{fileName} —
//     no block existed for that path at all.
//   - add_edit_sponsored_banner_dialog.dart uploads to
//     sponsored_banners/{fileName} — the existing rule covers a DIFFERENT
//     path, sponsored/{fileName} (no "_banners" suffix).
//
// Mirrors phase24_storage_rules_test.js's @firebase/rules-unit-testing
// pattern exactly: every block gets a positive AND a negative scenario —
// a suite that only asserts assertFails is vacuous (worker.md §3).
//
// Run with: firebase emulators:exec --only storage,firestore "node scripts/phase58_banner_storage_rules_test.js"

const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const { ref, uploadBytes, getBytes } = require("firebase/storage");

const REPO_ROOT = path.join(__dirname, "..", "..");
const PNG = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const IMG = { contentType: "image/png" };
const PDF = { contentType: "application/pdf" };

function baseClaims() {
  return { admin: false, seller: false, delivery_partner: false, employee: false };
}
const CLAIMS = {
  user: { ...baseClaims(), role: "user" },
  admin: { ...baseClaims(), role: "admin", admin: true },
};

let testEnv;
const results = [];
function record(block, label, pass, detail) {
  results.push({ block, label, pass, detail });
}

async function scenario(block, label, expect, fn) {
  try {
    await (expect === "allow" ? assertSucceeds(fn()) : assertFails(fn()));
    record(block, label, true, "");
  } catch (e) {
    record(block, label, false, `expected ${expect} — ${String(e.message || e).slice(0, 160)}`);
  }
}

function ctxStorage(kind, uid) {
  if (kind === "unauth") return testEnv.unauthenticatedContext().storage();
  return testEnv.authenticatedContext(uid, CLAIMS[kind]).storage();
}
const put = (s, p, meta = IMG) => () => uploadBytes(ref(s, p), PNG, meta);
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

  const U1 = "phase58-user-1";

  // 1 — categories/{folder}/{fileName}, the actual bug: THE EXACT PATH
  // SHAPE the admin screen writes to (nested, two segments).
  for (const folder of ["icons", "banners"]) {
    await seed(`categories/${folder}/seed.png`);
    await scenario(`categories/${folder}`, "public (unauthenticated) read is allowed",
      "allow", get(ctxStorage("unauth"), `categories/${folder}/seed.png`));
    await scenario(`categories/${folder}`, "admin writes an image", "allow",
      put(ctxStorage("admin", U1), `categories/${folder}/a.png`));
    await scenario(`categories/${folder}`, "plain user write is denied", "deny",
      put(ctxStorage("user", U1), `categories/${folder}/u.png`));
    await scenario(`categories/${folder}`, "admin writing a NON-image is denied", "deny",
      put(ctxStorage("admin", U1), `categories/${folder}/a.pdf`, PDF));
  }
  // A folder name the client never sends must still be refused — this is a
  // literal allowlist, not an open nested-path grant.
  await scenario("categories/{folder}", "an arbitrary folder name is denied even for admin",
    "deny", put(ctxStorage("admin", U1), "categories/arbitrary/a.png"));

  // 2 — categories/{fileName} (the pre-existing FLAT path) must still work
  // unchanged — this phase adds a sibling match, it does not touch this one.
  await seed("categories/seed.png");
  await scenario("categories(flat, unaffected)", "public read still allowed", "allow",
    get(ctxStorage("unauth"), "categories/seed.png"));
  await scenario("categories(flat, unaffected)", "admin write still allowed", "allow",
    put(ctxStorage("admin", U1), "categories/a.png"));
  await scenario("categories(flat, unaffected)", "plain user write still denied", "deny",
    put(ctxStorage("user", U1), "categories/u.png"));

  // 3 — section_banners/{fileName}: had NO block at all before this phase.
  await seed("section_banners/seed.png");
  await scenario("section_banners", "public (unauthenticated) read is allowed", "allow",
    get(ctxStorage("unauth"), "section_banners/seed.png"));
  await scenario("section_banners", "admin writes an image", "allow",
    put(ctxStorage("admin", U1), "section_banners/a.png"));
  await scenario("section_banners", "plain user write is denied", "deny",
    put(ctxStorage("user", U1), "section_banners/u.png"));
  await scenario("section_banners", "admin writing a NON-image is denied", "deny",
    put(ctxStorage("admin", U1), "section_banners/a.pdf", PDF));

  // 4 — sponsored_banners/{fileName}: the path the client ACTUALLY writes to.
  await seed("sponsored_banners/seed.png");
  await scenario("sponsored_banners", "public (unauthenticated) read is allowed", "allow",
    get(ctxStorage("unauth"), "sponsored_banners/seed.png"));
  await scenario("sponsored_banners", "admin writes an image", "allow",
    put(ctxStorage("admin", U1), "sponsored_banners/a.png"));
  await scenario("sponsored_banners", "plain user write is denied", "deny",
    put(ctxStorage("user", U1), "sponsored_banners/u.png"));
  await scenario("sponsored_banners", "admin writing a NON-image is denied", "deny",
    put(ctxStorage("admin", U1), "sponsored_banners/a.pdf", PDF));

  // 5 — sponsored/{fileName} (the pre-existing, now-confirmed-dead path)
  // must still work unchanged — this phase adds a sibling match at the
  // CORRECT path, it does not touch or remove this one.
  await seed("sponsored/seed.png");
  await scenario("sponsored(unaffected)", "public read still allowed", "allow",
    get(ctxStorage("unauth"), "sponsored/seed.png"));
  await scenario("sponsored(unaffected)", "admin write still allowed", "allow",
    put(ctxStorage("admin", U1), "sponsored/a.png"));

  await testEnv.cleanup();

  console.log("=== PHASE ADMR-2 — category/section/sponsored banner storage.rules ===\n");
  const blocks = [...new Set(results.map((r) => r.block))];
  for (const b of blocks) {
    const rows = results.filter((r) => r.block === b);
    console.log(`  ${b}  (${rows.filter((r) => r.pass).length}/${rows.length})`);
    for (const r of rows) console.log(`    ${r.pass ? "PASSED" : "FAILED"} — ${r.label}${r.pass ? "" : ` :: ${r.detail}`}`);
  }
  const failed = results.filter((r) => !r.pass);
  console.log(`\nblocks covered: ${blocks.length}  scenarios: ${results.length}  failed: ${failed.length}`);
  console.log(failed.length === 0 ? "ALL PASSED" : "SOME FAILED");
  process.exit(failed.length === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error("suite crashed:", e);
  process.exit(1);
});
