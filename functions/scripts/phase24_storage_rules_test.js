// ============================================================
//  Phase 24 (SEC-3) — storage.rules emulator suite
// ============================================================
//
// storage.rules had NO test of any kind before this file: invariant I10 in
// references/security.md ("Storage: every path explicit, images checked,
// default deny") was the only row in the catalogue whose "Proven by" column
// read **no suite exists** (finding A-10). 149 lines and 13 real match
// blocks were shipping unverified.
//
// This suite proves CURRENT behaviour. It is deliberately NOT a statement of
// desired behaviour: where a rule is more permissive than its section
// comment suggests, the scenario is labelled OBSERVED-PERMISSIVE and the
// finding is reported upward. Phase SEC-3 must not edit storage.rules —
// tightening a live rule is its own phase, with its own client-release
// sequencing (B2B_PHASE_SEQUENCING).
//
// Every block gets BOTH a positive and a negative scenario: a suite that
// only asserts assertFails is vacuous (worker.md §3).
//
// Mirrors phase14_rules_test.js's @firebase/rules-unit-testing pattern.
// Run with: firebase emulators:exec --only storage "node scripts/phase24_storage_rules_test.js"

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
  delivery: { ...baseClaims(), role: "delivery_partner", delivery_partner: true },
  employee: { ...baseClaims(), role: "employee", employee: true },
};

let testEnv;
const results = [];
function record(block, label, pass, detail) {
  results.push({ block, label, pass, detail });
}

// Runs one scenario and records whether the rules engine behaved as expected.
// `expect` is "allow" or "deny"; the assertion helper does the work, so a
// wrong expectation shows up as a FAILED row, never as a silent pass.
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

  const U1 = "phase24-user-1";
  const U2 = "phase24-user-2";

  // 1/2 — products, product_images: public read; seller|admin write, image + size
  for (const dir of ["products", "product_images"]) {
    await seed(`${dir}/seed.png`);
    await scenario(dir, "public (unauthenticated) read is allowed", "allow", get(ctxStorage("unauth"), `${dir}/seed.png`));
    await scenario(dir, "seller writes an image", "allow", put(ctxStorage("seller", U1), `${dir}/s.png`));
    await scenario(dir, "admin writes an image", "allow", put(ctxStorage("admin", U1), `${dir}/a.png`));
    await scenario(dir, "plain user write is denied", "deny", put(ctxStorage("user", U1), `${dir}/u.png`));
    await scenario(dir, "seller writing a NON-image is denied", "deny", put(ctxStorage("seller", U1), `${dir}/s.pdf`, PDF));
  }

  // 3/4 — profiles, users: owner-only read and write, image + size
  for (const dir of ["profiles", "users"]) {
    await seed(`${dir}/${U1}/seed.png`);
    await scenario(dir, "owner reads own file", "allow", get(ctxStorage("user", U1), `${dir}/${U1}/seed.png`));
    await scenario(dir, "owner writes own file", "allow", put(ctxStorage("user", U1), `${dir}/${U1}/me.png`));
    await scenario(dir, "another user reading someone else's file is denied", "deny", get(ctxStorage("user", U2), `${dir}/${U1}/seed.png`));
    await scenario(dir, "another user writing into someone else's folder is denied", "deny", put(ctxStorage("user", U2), `${dir}/${U1}/evil.png`));
    await scenario(dir, "unauthenticated read is denied", "deny", get(ctxStorage("unauth"), `${dir}/${U1}/seed.png`));
    await scenario(dir, "owner writing a NON-image is denied", "deny", put(ctxStorage("user", U1), `${dir}/${U1}/me.pdf`, PDF));
  }

  // 5 — banners: public read, admin-only write
  await seed("banners/seed.png");
  await scenario("banners", "public read is allowed", "allow", get(ctxStorage("unauth"), "banners/seed.png"));
  await scenario("banners", "admin writes", "allow", put(ctxStorage("admin", U1), "banners/a.png"));
  await scenario("banners", "seller write is denied", "deny", put(ctxStorage("seller", U1), "banners/s.png"));

  // 6 — notifications: authenticated read, admin-only write
  await seed("notifications/seed.png");
  await scenario("notifications", "authenticated read is allowed", "allow", get(ctxStorage("user", U1), "notifications/seed.png"));
  await scenario("notifications", "unauthenticated read is denied", "deny", get(ctxStorage("unauth"), "notifications/seed.png"));
  await scenario("notifications", "admin writes", "allow", put(ctxStorage("admin", U1), "notifications/a.png"));
  await scenario("notifications", "plain user write is denied", "deny", put(ctxStorage("user", U1), "notifications/u.png"));

  // 7 — sponsored: public read, seller|admin write
  await seed("sponsored/seed.png");
  await scenario("sponsored", "public read is allowed", "allow", get(ctxStorage("unauth"), "sponsored/seed.png"));
  await scenario("sponsored", "seller writes", "allow", put(ctxStorage("seller", U1), "sponsored/s.png"));
  await scenario("sponsored", "plain user write is denied", "deny", put(ctxStorage("user", U1), "sponsored/u.png"));

  // 8 — categories: public read, admin-only write
  await seed("categories/seed.png");
  await scenario("categories", "public read is allowed", "allow", get(ctxStorage("unauth"), "categories/seed.png"));
  await scenario("categories", "admin writes", "allow", put(ctxStorage("admin", U1), "categories/a.png"));
  await scenario("categories", "seller write is denied", "deny", put(ctxStorage("seller", U1), "categories/s.png"));

  // 9 — chat: authenticated read/write, size only. See OBSERVED-PERMISSIVE below.
  await seed("chat/thread-A/seed.png");
  await scenario("chat", "a participant-shaped user reads an attachment", "allow", get(ctxStorage("user", U1), "chat/thread-A/seed.png"));
  await scenario("chat", "unauthenticated read is denied", "deny", get(ctxStorage("unauth"), "chat/thread-A/seed.png"));
  await scenario("chat", "authenticated user writes an attachment", "allow", put(ctxStorage("user", U1), "chat/thread-A/u.png"));
  await scenario("chat", "OBSERVED-PERMISSIVE: an unrelated user reads ANOTHER thread's attachment", "allow", get(ctxStorage("user", U2), "chat/thread-A/seed.png"));
  await scenario("chat", "OBSERVED-PERMISSIVE: an unrelated user WRITES into another thread", "allow", put(ctxStorage("user", U2), "chat/thread-A/evil.png"));
  await scenario("chat", "OBSERVED-PERMISSIVE: a NON-image attachment is accepted (no isImage check)", "allow", put(ctxStorage("user", U1), "chat/thread-A/u.pdf", PDF));

  // 10/11/12 — seller/employee/delivery documents: owner or admin read, owner-only write, no image check
  for (const dir of ["seller_documents", "employee_documents", "delivery_documents"]) {
    await seed(`${dir}/${U1}/seed.png`);
    await scenario(dir, "owner reads own document", "allow", get(ctxStorage("user", U1), `${dir}/${U1}/seed.png`));
    await scenario(dir, "admin reads someone's document", "allow", get(ctxStorage("admin", U2), `${dir}/${U1}/seed.png`));
    await scenario(dir, "an unrelated user reading it is denied", "deny", get(ctxStorage("user", U2), `${dir}/${U1}/seed.png`));
    await scenario(dir, "owner uploads a PDF (documents are deliberately not image-only)", "allow", put(ctxStorage("user", U1), `${dir}/${U1}/doc.pdf`, PDF));
    await scenario(dir, "an unrelated user writing into someone's folder is denied", "deny", put(ctxStorage("user", U2), `${dir}/${U1}/evil.pdf`, PDF));
  }

  // 13 — delivery_proofs: authenticated read, delivery|admin write
  await seed("delivery_proofs/seed.png");
  await scenario("delivery_proofs", "delivery partner writes a proof photo", "allow", put(ctxStorage("delivery", U1), "delivery_proofs/d.png"));
  await scenario("delivery_proofs", "admin writes", "allow", put(ctxStorage("admin", U1), "delivery_proofs/a.png"));
  await scenario("delivery_proofs", "plain user write is denied", "deny", put(ctxStorage("user", U1), "delivery_proofs/u.png"));
  await scenario("delivery_proofs", "OBSERVED-PERMISSIVE: any authenticated user reads every proof photo", "allow", get(ctxStorage("user", U2), "delivery_proofs/seed.png"));
  await scenario("delivery_proofs", "unauthenticated read is denied", "deny", get(ctxStorage("unauth"), "delivery_proofs/seed.png"));

  // 14 — {allPaths=**}: default deny for anything not matched above
  await seed("unmatched_area/seed.png");
  await scenario("{allPaths=**}", "unmatched path read is denied even for admin", "deny", get(ctxStorage("admin", U1), "unmatched_area/seed.png"));
  await scenario("{allPaths=**}", "unmatched path write is denied even for admin", "deny", put(ctxStorage("admin", U1), "unmatched_area/a.png"));
  await scenario("{allPaths=**}", "unmatched path read is denied for a plain user", "deny", get(ctxStorage("user", U1), "unmatched_area/seed.png"));

  await testEnv.cleanup();

  console.log("=== PHASE 24 (SEC-3) — storage.rules emulator suite ===\n");
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
