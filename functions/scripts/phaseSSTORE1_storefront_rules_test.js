// ============================================================
//  Phase SELLER-STOREFRONT-EDIT-1 — sellers/{uid} owner allow-list + storefront images
// ============================================================
//
// Run with: JAVA_HOME=/opt/homebrew/opt/openjdk@21 firebase emulators:exec
//             --only firestore,storage "node scripts/phaseSSTORE1_storefront_rules_test.js"

const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const { ref, uploadBytes } = require("firebase/storage");

const PNG = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const IMG = { contentType: "image/png" };
const PDF = { contentType: "application/pdf" };

async function main() {
  const root = path.join(__dirname, "..", "..");
  const testEnv = await initializeTestEnvironment({
    projectId: "agrimore-66a4e",
    firestore: { rules: fs.readFileSync(path.join(root, "firestore.rules"), "utf8"), host: "127.0.0.1", port: 8080 },
    storage: { rules: fs.readFileSync(path.join(root, "storage.rules"), "utf8"), host: "127.0.0.1", port: 9199 },
  });
  const results = {};
  const record = (k, p) => p.then(
    () => { results[k] = "PASSED"; console.log(`${k}: PASSED`); },
    (e) => { results[k] = `FAILED — ${e.message}`; console.log(`${k}: FAILED — ${e.message}`); }
  );
  const seller = { userId: "s1", status: "approved", shopName: "Ravi Stores", rating: 4.2, createdAt: new Date(0) };
  try {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc("sellers/s1").set(seller);
      await ctx.firestore().doc("sellers/sus").set({ ...seller, userId: "sus", status: "suspended" });
    });
    const s1 = testEnv.authenticatedContext("s1").firestore();
    const s2 = testEnv.authenticatedContext("s2").firestore();
    const sus = testEnv.authenticatedContext("sus").firestore();
    const adminDb = testEnv.authenticatedContext("admin1", { role: "admin", admin: true }).firestore();
    const doc = (db, id = "s1") => db.doc(`sellers/${id}`);

    await record("f1_positive_storefront_edit",
      assertSucceeds(doc(s1).update({
        description: "Fresh rice and pulses since 1998.", highlights: ["Farm fresh", "Same-day dispatch"],
        logoUrl: "https://x/logo.png", coverImageUrl: "https://x/cover.png", updatedAt: new Date(),
      })));
    await record("f2_positive_existing_profile_screen_write",
      assertSucceeds(doc(s1).update({
        businessName: "Ravi Stores", name: "Ravi", phone: "+911234567890", gstNumber: "33ABCDE1234F1Z5",
        city: "Madurai", state: "TN", openingTime: "09:00", closingTime: "21:00", deliveryRadiusKm: 5, updatedAt: new Date(),
      })));
    await record("f3_positive_delivery_fee_merge_set",
      assertSucceeds(doc(s1).set({ deliveryFeeSchedule: { type: "flat", amount: 30 }, updatedAt: new Date() }, { merge: true })));
    await record("f4_positive_full_object_rewrite_with_unchanged_status",
      assertSucceeds(doc(s1).set({ ...seller, shopName: "Ravi Stores 2", description: "x", highlights: ["Farm fresh", "Same-day dispatch"],
        logoUrl: "https://x/logo.png", coverImageUrl: "https://x/cover.png", businessName: "Ravi Stores", name: "Ravi",
        phone: "+911234567890", gstNumber: "33ABCDE1234F1Z5", city: "Madurai", state: "TN", openingTime: "09:00",
        closingTime: "21:00", deliveryRadiusKm: 5, deliveryFeeSchedule: { type: "flat", amount: 30 }, updatedAt: new Date() })));
    await record("f5_negative_suspended_cannot_unsuspend_any_value",
      Promise.all(["Approved", "active", "pending", " approved"].map((v) => assertFails(doc(sus, "sus").update({ status: v })))));
    await record("f6_negative_cannot_set_rating", assertFails(doc(s1).update({ rating: 5 })));
    await record("f7_negative_cannot_self_verify_or_feature",
      Promise.all([assertFails(doc(s1).update({ isVerified: true })), assertFails(doc(s1).update({ isFeatured: true }))]));
    await record("f8_negative_cannot_set_commission", assertFails(doc(s1).update({ commissionRate: 0 })));
    await record("f9_negative_cannot_touch_server_fields",
      Promise.all([assertFails(doc(s1).update({ statsRebuiltAt: new Date() })), assertFails(doc(s1).update({ createdAt: new Date() }))]));
    await record("f10_negative_description_over_500", assertFails(doc(s1).update({ description: "x".repeat(501) })));
    await record("f11_negative_more_than_3_highlights", assertFails(doc(s1).update({ highlights: ["a", "b", "c", "d"] })));
    await record("f12_negative_other_seller_cannot_edit", assertFails(doc(s2).update({ description: "hijack" })));
    await record("f13_positive_admin_edits_anything", assertSucceeds(doc(adminDb).update({ rating: 4.5, isVerified: true })));
    await record("f14_positive_public_read", assertSucceeds(doc(testEnv.unauthenticatedContext().firestore()).get()));

    const st = (uid) => testEnv.authenticatedContext(uid).storage();
    await record("g1_positive_owner_uploads_storefront_image",
      assertSucceeds(uploadBytes(ref(st("s1"), "sellers/s1/storefront/logo.png"), PNG, IMG)));
    await record("g2_negative_other_seller_cannot_upload",
      assertFails(uploadBytes(ref(st("s2"), "sellers/s1/storefront/logo.png"), PNG, IMG)));
    await record("g3_negative_non_image",
      assertFails(uploadBytes(ref(st("s1"), "sellers/s1/storefront/doc.pdf"), PNG, PDF)));
    await record("g4_negative_owner_cannot_write_admin_seller_root",
      assertFails(uploadBytes(ref(st("s1"), "sellers/s1/logo.png"), PNG, IMG)));

    console.log("\n=== PHASE SELLER-STOREFRONT-EDIT-1 (rules) SUMMARY ===");
    const total = Object.keys(results).length;
    const passed = Object.values(results).filter((v) => v === "PASSED").length;
    for (const [k, v] of Object.entries(results)) console.log(`  ${v === "PASSED" ? "PASS" : "FAIL"}  ${k}`);
    console.log(`\n${passed}/${total} scenarios passed`);
    if (passed !== total) { console.error("PHASE SELLER-STOREFRONT-EDIT-1 (rules): FAILED"); process.exitCode = 1; }
    else console.log("PHASE SELLER-STOREFRONT-EDIT-1 (rules): ALL PASSED");
  } finally {
    await testEnv.cleanup();
  }
}
main().catch((e) => { console.error("harness error", e); process.exit(1); });
