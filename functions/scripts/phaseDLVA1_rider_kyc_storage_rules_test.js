// ============================================================
//  Phase DLV-A1 — delivery_documents/{uid}: KYC photos freeze once decided
// ============================================================
// The owner may upload / overwrite / delete their KYC photos only before
// delivery_partners/{uid} exists (registration uploads first) or while it is
// pending or rejected. Approved, suspended and deactivated riders cannot swap
// the Aadhaar or licence an admin reviewed. Image-only and owner-only rules
// from FIX-11 still hold.
//
// Run with: firebase emulators:exec --only storage,firestore --project demo-dlva1-kyc \
//             "node scripts/phaseDLVA1_rider_kyc_storage_rules_test.js"
// Honours FIRESTORE_EMULATOR_HOST and FIREBASE_STORAGE_EMULATOR_HOST.
const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const { ref, uploadBytes, getBytes, deleteObject } = require("firebase/storage");

const ROOT = path.join(__dirname, "..", "..");
const PROJECT = process.env.GCLOUD_PROJECT || "demo-dlva1-kyc";
const hp = (v, d) => { const [h, p] = (v || d).split(":"); return { host: h, port: Number(p) }; };
const PNG = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const IMG = { contentType: "image/png" };
const PDF = { contentType: "application/pdf" };

async function main() {
  const testEnv = await initializeTestEnvironment({
    projectId: PROJECT,
    storage: { rules: fs.readFileSync(path.join(ROOT, "storage.rules"), "utf8"), ...hp(process.env.FIREBASE_STORAGE_EMULATOR_HOST, "127.0.0.1:9199") },
    firestore: { rules: fs.readFileSync(path.join(ROOT, "firestore.rules"), "utf8"), ...hp(process.env.FIRESTORE_EMULATOR_HOST, "127.0.0.1:8080") },
  });
  const results = [];
  const scenario = async (label, expect, fn) => {
    try {
      await (expect === "allow" ? assertSucceeds(fn()) : assertFails(fn()));
      results.push(true); console.log(`${label}: PASSED`);
    } catch (e) {
      results.push(false); console.log(`${label}: FAILED — expected ${expect} — ${String(e.message || e).slice(0, 160)}`);
    }
  };
  const partner = (uid, data) => testEnv.withSecurityRulesDisabled((ctx) => ctx.firestore().doc(`delivery_partners/${uid}`).set(data));
  const seedFile = (p) => testEnv.withSecurityRulesDisabled((ctx) => uploadBytes(ref(ctx.storage(), p), PNG, IMG));
  const st = (uid, claims = {}) => testEnv.authenticatedContext(uid, claims).storage();
  const put = (s, p, meta = IMG) => () => uploadBytes(ref(s, p), PNG, meta);
  const del = (s, p) => () => deleteObject(ref(s, p));
  try {
    // New applicant: no partner record yet.
    await scenario("k01_new_applicant_uploads_before_the_record_exists", "allow", put(st("new1"), "delivery_documents/new1/aadhaarFront"));
    await scenario("k02_new_applicant_overwrites_on_retry", "allow", put(st("new1"), "delivery_documents/new1/aadhaarFront"));
    await scenario("k03_non_image_refused", "deny", put(st("new1"), "delivery_documents/new1/license", PDF));
    await scenario("k04_other_user_cannot_write_into_the_folder", "deny", put(st("new2"), "delivery_documents/new1/selfie"));
    await scenario("k05_signed_out_refused", "deny", put(testEnv.unauthenticatedContext().storage(), "delivery_documents/new1/selfie"));

    for (const [uid, status, expect] of [["pend", "pending", "allow"], ["rej", "rejected", "allow"], ["appr", "approved", "deny"],
      ["susp", "suspended", "deny"], ["deac", "deactivated", "deny"]]) {
      await partner(uid, { status });
      await seedFile(`delivery_documents/${uid}/license`);
      await scenario(`k06_${status}_rider_overwrites_licence_${expect}`, expect, put(st(uid, status === "approved" ? { delivery_partner: true } : {}), `delivery_documents/${uid}/license`));
      await seedFile(`delivery_documents/${uid}/selfie`);
      await scenario(`k07_${status}_rider_deletes_selfie_${expect}`, expect, del(st(uid), `delivery_documents/${uid}/selfie`));
    }
    await partner("nostat", { name: "legacy" });
    await scenario("k08_record_without_status_reads_as_pending", "allow", put(st("nostat"), "delivery_documents/nostat/license"));
    await seedFile("delivery_documents/appr/aadhaarBack");
    await scenario("k09_owner_still_reads_after_approval", "allow", () => getBytes(ref(st("appr"), "delivery_documents/appr/aadhaarBack")));
    await scenario("k10_admin_reads", "allow", () => getBytes(ref(st("adm", { admin: true }), "delivery_documents/appr/aadhaarBack")));
    await scenario("k11_admin_may_delete", "allow", del(st("adm", { admin: true }), "delivery_documents/appr/aadhaarBack"));
    await scenario("k12_other_rider_cannot_read", "deny", () => getBytes(ref(st("pend"), "delivery_documents/appr/license")));

    const passed = results.filter(Boolean).length;
    console.log(`\n${passed}/${results.length} scenarios passed`);
    await testEnv.cleanup();
    if (passed !== results.length) { console.log("PHASE DLV-A1 KYC storage: FAILED"); process.exit(1); }
    console.log("PHASE DLV-A1 KYC storage: ALL PASSED");
    process.exit(0);
  } catch (e) {
    console.error(e); await testEnv.cleanup(); process.exit(1);
  }
}
main();
