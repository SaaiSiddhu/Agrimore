// ============================================================
//  Phase ADMIN-SELLER-CMS-1 — sellers/{sellerId}/{fileName} storage.rules suite
// ============================================================
//
// This phase added one new storage.rules block (admin's "Manage Sellers" edit
// screen uploads a seller's logo/cover here via the shared ImageUploader,
// generalized in this same phase to accept a storageFolder instead of its old
// hardcoded `products/`). The block mirrors `products/{fileName}` exactly —
// public read, admin-only write — rather than `profiles/{userId}/{fileName}`'s
// owner-only shape, since this is admin-authored seller branding, not seller
// self-serve. `isAdmin()` only reads the auth token's own custom claims, no
// firestore.get() cross-read, so unlike phase24_storage_rules_test /
// phase48_business_posts_test this suite needs ONLY the storage emulator —
// gate.sh's own `*storage*` wildcard dispatch already routes it correctly by
// filename with no dispatch-table change needed (confirmed against the
// FIX-GATE-1 fix to that same case statement before writing this file).
//
// Every scenario pairs a positive control with the negative case it guards
// against, mirroring phase24's own pattern (a suite that only asserts
// assertFails is vacuous, worker.md §3).
//
// Run with: firebase emulators:exec --only storage "node scripts/phase_admin_seller_cms1_storage_rules_test.js"

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
  seller: { ...baseClaims(), role: "seller", seller: true },
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

  const ADMIN_1 = "admin-seller-cms1-admin-1";
  const SELLER_1 = "admin-seller-cms1-seller-1";
  const USER_1 = "admin-seller-cms1-user-1";
  const SELLER_A = "seller-A";
  const SELLER_B = "seller-B";

  await seed(`sellers/${SELLER_A}/seed.png`);

  await scenario(
    "sellers/{sellerId}",
    "public (unauthenticated) read is allowed",
    "allow",
    get(ctxStorage("unauth"), `sellers/${SELLER_A}/seed.png`),
  );

  await scenario(
    "sellers/{sellerId}",
    "admin writes a logo image into seller A's folder",
    "allow",
    put(ctxStorage("admin", ADMIN_1), `sellers/${SELLER_A}/logo.png`),
  );

  await scenario(
    "sellers/{sellerId}",
    "the SAME admin can also write into a DIFFERENT seller's folder (path wildcard generalizes, not scoped to admin's own uid)",
    "allow",
    put(ctxStorage("admin", ADMIN_1), `sellers/${SELLER_B}/cover.png`),
  );

  await scenario(
    "sellers/{sellerId}",
    "an approved seller writing into their OWN sellerId folder is denied — admin-only, not seller self-serve",
    "deny",
    put(ctxStorage("seller", SELLER_1), `sellers/${SELLER_1}/s.png`),
  );

  await scenario(
    "sellers/{sellerId}",
    "a plain authenticated user write is denied",
    "deny",
    put(ctxStorage("user", USER_1), `sellers/${SELLER_A}/u.png`),
  );

  await scenario(
    "sellers/{sellerId}",
    "unauthenticated write is denied",
    "deny",
    put(ctxStorage("unauth"), `sellers/${SELLER_A}/anon.png`),
  );

  await scenario(
    "sellers/{sellerId}",
    "admin writing a NON-image (e.g. a PDF) is denied",
    "deny",
    put(ctxStorage("admin", ADMIN_1), `sellers/${SELLER_A}/a.pdf`, PDF),
  );

  await testEnv.cleanup();

  console.log("=== Phase ADMIN-SELLER-CMS-1 — sellers/{sellerId}/{fileName} storage.rules suite ===\n");
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
