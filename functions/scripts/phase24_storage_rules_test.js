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
// Originally (Phase SEC-3) proved CURRENT behaviour only, deliberately not a
// statement of desired behaviour — SEC-3 was not permitted to edit
// storage.rules itself, so scenarios more permissive than their section
// comment suggested were labelled OBSERVED-PERMISSIVE and reported upward
// rather than fixed.
//
// FIX-11 is that follow-up phase. Every OBSERVED-PERMISSIVE scenario SEC-3
// found is now a FIX-11-labelled DENY scenario below, alongside a positive
// control proving the legitimate access path still works. Any comment
// still saying "OBSERVED-PERMISSIVE" below is a defect this phase did not
// touch — check its finding id before assuming it is covered.
//
// Every block gets BOTH a positive and a negative scenario: a suite that
// only asserts assertFails is vacuous (worker.md §3).
//
// Mirrors phase14_rules_test.js's @firebase/rules-unit-testing pattern.
//
// FIX-11 update: now ALSO configures firestore (not just storage) in the
// same testEnv. The chat and delivery_proofs blocks' rules cross-read
// Firestore (firestore.get()) to resolve thread participants and delivery-
// partner assignment, so this suite needs a real Firestore emulator behind
// it, not just Storage's own.
// Run with: firebase emulators:exec --only storage,firestore "node scripts/phase24_storage_rules_test.js"

const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const { ref, uploadBytes, getBytes } = require("firebase/storage");
const { doc, setDoc } = require("firebase/firestore");

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

// FIX-11: seeds a Firestore document the storage rules' firestore.get()
// calls read (threads/{id}.participantIds, orders/{id}.deliveryPartnerId).
async function seedFirestoreDoc(collectionPath, docId, data) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), collectionPath, docId), data);
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
    firestore: {
      rules: fs.readFileSync(path.join(REPO_ROOT, "firestore.rules"), "utf8"),
      host: "127.0.0.1",
      port: 8080,
    },
  });

  const U1 = "phase24-user-1";
  const U2 = "phase24-user-2";

  // 1 — products: public read; FIX-11 restricted write to admin-only (no
  // seller-facing code uses this path — a bare Uuid().v4() filename with no
  // owner prefix made any seller able to overwrite any other seller's file).
  await seed("products/seed.png");
  await scenario("products", "public (unauthenticated) read is allowed", "allow", get(ctxStorage("unauth"), "products/seed.png"));
  await scenario("products", "admin writes an image", "allow", put(ctxStorage("admin", U1), "products/a.png"));
  await scenario("products", "FIX-11: seller write is now denied (was allowed pre-fix)", "deny", put(ctxStorage("seller", U1), "products/s.png"));
  await scenario("products", "plain user write is denied", "deny", put(ctxStorage("user", U1), "products/u.png"));
  await scenario("products", "admin writing a NON-image is denied", "deny", put(ctxStorage("admin", U1), "products/a.pdf", PDF));

  // 2 — product_images: public read; FIX-11 scoped seller write to their OWN
  // uid-prefixed filename (add_product_screen.dart already names files
  // `${sellerId}_...`, sellerId == the uploader's own uid — no client change
  // needed). Admin is exempt from the prefix.
  await seed("product_images/seed.png");
  await scenario("product_images", "public (unauthenticated) read is allowed", "allow", get(ctxStorage("unauth"), "product_images/seed.png"));
  await scenario("product_images", "seller writes an image under their OWN uid prefix", "allow", put(ctxStorage("seller", U1), `product_images/${U1}_s.png`));
  await scenario("product_images", "admin writes an image with no uid prefix at all", "allow", put(ctxStorage("admin", U1), "product_images/a.png"));
  await scenario("product_images", "FIX-11: seller writing under ANOTHER seller's uid prefix is denied", "deny", put(ctxStorage("seller", U2), `product_images/${U1}_evil.png`));
  await scenario("product_images", "plain user write is denied", "deny", put(ctxStorage("user", U1), `product_images/${U1}_u.png`));
  await scenario("product_images", "seller writing a NON-image is denied", "deny", put(ctxStorage("seller", U1), `product_images/${U1}_s.pdf`, PDF));

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

  // 7 — sponsored: public read; FIX-11 restricted write to admin-only (same
  // reasoning as products above — no seller-facing code uses this path).
  await seed("sponsored/seed.png");
  await scenario("sponsored", "public read is allowed", "allow", get(ctxStorage("unauth"), "sponsored/seed.png"));
  await scenario("sponsored", "admin writes", "allow", put(ctxStorage("admin", U1), "sponsored/a.png"));
  await scenario("sponsored", "FIX-11: seller write is now denied (was allowed pre-fix)", "deny", put(ctxStorage("seller", U1), "sponsored/s.png"));
  await scenario("sponsored", "plain user write is denied", "deny", put(ctxStorage("user", U1), "sponsored/u.png"));

  // 8 — categories: public read, admin-only write
  await seed("categories/seed.png");
  await scenario("categories", "public read is allowed", "allow", get(ctxStorage("unauth"), "categories/seed.png"));
  await scenario("categories", "admin writes", "allow", put(ctxStorage("admin", U1), "categories/a.png"));
  await scenario("categories", "seller write is denied", "deny", put(ctxStorage("seller", U1), "categories/s.png"));

  // 9 — chat: FIX-11 scoped to thread PARTICIPANTS (threads/{id}.participantIds
  // in Firestore, cross-read via firestore.get()) instead of any signed-in
  // user, and added isImage(). U1 is a real participant of thread-A; U2 is
  // not — both seeded in Firestore, not just assumed by naming.
  await seedFirestoreDoc("threads", "thread-A", { participantIds: [U1], orderId: "order-thread-A" });
  await seed("chat/thread-A/seed.png");
  await scenario("chat", "a real participant reads an attachment", "allow", get(ctxStorage("user", U1), "chat/thread-A/seed.png"));
  await scenario("chat", "unauthenticated read is denied", "deny", get(ctxStorage("unauth"), "chat/thread-A/seed.png"));
  await scenario("chat", "a real participant writes an attachment", "allow", put(ctxStorage("user", U1), "chat/thread-A/u.png"));
  await scenario("chat", "admin reads any thread's attachment", "allow", get(ctxStorage("admin", U2), "chat/thread-A/seed.png"));
  await scenario("chat", "FIX-11: an unrelated (non-participant) user reading another thread's attachment is now denied", "deny", get(ctxStorage("user", U2), "chat/thread-A/seed.png"));
  await scenario("chat", "FIX-11: an unrelated (non-participant) user WRITING into another thread is now denied", "deny", put(ctxStorage("user", U2), "chat/thread-A/evil.png"));
  await scenario("chat", "FIX-11: a NON-image attachment from a real participant is now denied", "deny", put(ctxStorage("user", U1), "chat/thread-A/u.pdf", PDF));

  // 10/11/12 — seller/employee/delivery documents: owner or admin read,
  // owner-only write. FIX-11 added isImage() — no app code was found
  // uploading anything here, so this is a pure tightening with nothing
  // legitimate to protect from breaking.
  for (const dir of ["seller_documents", "employee_documents", "delivery_documents"]) {
    await seed(`${dir}/${U1}/seed.png`);
    await scenario(dir, "owner reads own document", "allow", get(ctxStorage("user", U1), `${dir}/${U1}/seed.png`));
    await scenario(dir, "admin reads someone's document", "allow", get(ctxStorage("admin", U2), `${dir}/${U1}/seed.png`));
    await scenario(dir, "an unrelated user reading it is denied", "deny", get(ctxStorage("user", U2), `${dir}/${U1}/seed.png`));
    await scenario(dir, "owner uploads an image", "allow", put(ctxStorage("user", U1), `${dir}/${U1}/doc.png`));
    await scenario(dir, "FIX-11: owner uploading a NON-image (e.g. HTML/JS) is now denied", "deny", put(ctxStorage("user", U1), `${dir}/${U1}/doc.pdf`, PDF));
    await scenario(dir, "an unrelated user writing into someone's folder is denied", "deny", put(ctxStorage("user", U2), `${dir}/${U1}/evil.png`));
  }

  // 13 — delivery_proofs: FIX-11 scoped both read and write to the order's
  // ASSIGNED delivery partner (orders/{id}.deliveryPartnerId in Firestore,
  // cross-read via firestore.get() after parsing the orderId back out of the
  // filename — active_order_screen.dart already names files
  // `{orderId}_{timestamp}.jpg`, no client change needed). order-proof-1 is
  // assigned to U1; U2 is a different, unassigned delivery partner.
  await seedFirestoreDoc("orders", "order-proof-1", { deliveryPartnerId: U1, userId: "phase24-customer" });
  await seed("delivery_proofs/order-proof-1_seed.png");
  await scenario("delivery_proofs", "the ASSIGNED delivery partner writes a proof photo", "allow", put(ctxStorage("delivery", U1), "delivery_proofs/order-proof-1_d.png"));
  await scenario("delivery_proofs", "admin writes", "allow", put(ctxStorage("admin", U1), "delivery_proofs/order-proof-1_a.png"));
  await scenario("delivery_proofs", "plain user write is denied", "deny", put(ctxStorage("user", U1), "delivery_proofs/order-proof-1_u.png"));
  await scenario("delivery_proofs", "FIX-11: an UNASSIGNED delivery partner writing to this order's proof is now denied", "deny", put(ctxStorage("delivery", U2), "delivery_proofs/order-proof-1_evil.png"));
  await scenario("delivery_proofs", "the ASSIGNED delivery partner reads their own proof photo", "allow", get(ctxStorage("delivery", U1), "delivery_proofs/order-proof-1_seed.png"));
  await scenario("delivery_proofs", "admin reads any proof photo", "allow", get(ctxStorage("admin", U2), "delivery_proofs/order-proof-1_seed.png"));
  await scenario("delivery_proofs", "FIX-11: an UNASSIGNED delivery partner (or any other authenticated user) reading this proof is now denied", "deny", get(ctxStorage("delivery", U2), "delivery_proofs/order-proof-1_seed.png"));
  await scenario("delivery_proofs", "unauthenticated read is denied", "deny", get(ctxStorage("unauth"), "delivery_proofs/order-proof-1_seed.png"));

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
