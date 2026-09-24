// ============================================================
//  Phase DLV-E1 — rules for exceptions, the new order fields and proof photos
// ============================================================
//  f — delivery_exceptions: reporting rider and admin read; nobody writes
//  o — openDeliveryException / deliveryProofPath are server-written: the
//      customer, the seller and the assigned rider cannot set them
//  s — delivery_proofs/{orderId}_proof: the assigned rider may upload until
//      the proof is attached, then not; admin still may; another rider never
//
// Run with: firebase emulators:exec --only firestore,storage --project demo-dlve1-rules \
//             "node scripts/phaseDLVE1_rules_test.js"
const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const { ref, uploadBytes } = require("firebase/storage");

const ROOT = path.join(__dirname, "..", "..");
const PROJECT = process.env.GCLOUD_PROJECT || "demo-dlve1-rules";
const hp = (v, d) => { const [h, p] = (v || d).split(":"); return { host: h, port: Number(p) }; };
const PNG = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const IMG = { contentType: "image/png" };

async function main() {
  const env = await initializeTestEnvironment({
    projectId: PROJECT,
    firestore: { rules: fs.readFileSync(path.join(ROOT, "firestore.rules"), "utf8"), ...hp(process.env.FIRESTORE_EMULATOR_HOST, "127.0.0.1:8080") },
    storage: { rules: fs.readFileSync(path.join(ROOT, "storage.rules"), "utf8"), ...hp(process.env.FIREBASE_STORAGE_EMULATOR_HOST, "127.0.0.1:9199") },
  });
  const results = [];
  const scenario = async (label, expect, fn) => {
    try { await (expect === "allow" ? assertSucceeds(fn()) : assertFails(fn())); results.push(true); console.log(`${label}: PASSED`); }
    catch (e) { results.push(false); console.log(`${label}: FAILED — expected ${expect} — ${String(e.message || e).slice(0, 140)}`); }
  };
  try {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await db.doc("users/r1").set({ role: "delivery_partner" });
      await db.doc("users/r2").set({ role: "delivery_partner" });
      await db.doc("delivery_partners/r1").set({ status: "approved" });
      await db.doc("delivery_partners/r2").set({ status: "approved" });
      await db.doc("users/s1").set({ role: "seller" });
      await db.doc("delivery_exceptions/o1_req00001").set({ riderId: "r1", orderId: "o1", status: "reported" });
      await db.doc("orders/o1").set({ userId: "c1", sellerId: "s1", deliveryPartnerId: "r1", orderStatus: "out_for_delivery", status: "out_for_delivery", total: 100 });
      await db.doc("orders/o2").set({ userId: "c1", sellerId: "s1", deliveryPartnerId: "r1", orderStatus: "delivered", status: "delivered", total: 100, deliveryProofPath: "delivery_proofs/o2_proof" });
    });
    const r1 = env.authenticatedContext("r1", { delivery_partner: true });
    const r2 = env.authenticatedContext("r2", { delivery_partner: true });
    const adm = env.authenticatedContext("adm", { admin: true, role: "admin" });
    const cust = env.authenticatedContext("c1", {});
    const seller = env.authenticatedContext("s1", { seller: true, role: "seller" });

    await scenario("f01_reporting_rider_reads", "allow", () => r1.firestore().doc("delivery_exceptions/o1_req00001").get());
    await scenario("f02_other_rider_cannot_read", "deny", () => r2.firestore().doc("delivery_exceptions/o1_req00001").get());
    await scenario("f03_admin_reads", "allow", () => adm.firestore().doc("delivery_exceptions/o1_req00001").get());
    await scenario("f04_rider_cannot_create", "deny", () => r1.firestore().doc("delivery_exceptions/o1_fake0001").set({ riderId: "r1", orderId: "o1" }));
    await scenario("f05_rider_cannot_resolve_own", "deny", () => r1.firestore().doc("delivery_exceptions/o1_req00001").update({ status: "resolved" }));

    const marker = { openDeliveryException: { id: "x", reason: "safety" } };
    await scenario("o01_customer_cannot_set_exception_marker", "deny", () => cust.firestore().doc("orders/o1").update(marker));
    await scenario("o02_seller_cannot_set_exception_marker", "deny", () => seller.firestore().doc("orders/o1").update(marker));
    await scenario("o03_rider_cannot_set_exception_marker", "deny", () => r1.firestore().doc("orders/o1").update(marker));
    await scenario("o04_rider_cannot_set_proof_path", "deny", () => r1.firestore().doc("orders/o1").update({ deliveryProofPath: "delivery_proofs/o9_proof" }));
    await scenario("o05_customer_cannot_clear_proof_path", "deny", () => cust.firestore().doc("orders/o2").update({ deliveryProofPath: null }));

    await scenario("s01_assigned_rider_uploads_before_attach", "allow", () => uploadBytes(ref(r1.storage(), "delivery_proofs/o1_proof"), PNG, IMG));
    await scenario("s02_other_rider_cannot_upload", "deny", () => uploadBytes(ref(r2.storage(), "delivery_proofs/o1_proof"), PNG, IMG));
    await scenario("s03_rider_cannot_replace_attached_proof", "deny", () => uploadBytes(ref(r1.storage(), "delivery_proofs/o2_proof"), PNG, IMG));
    await scenario("s04_admin_may_replace", "allow", () => uploadBytes(ref(adm.storage(), "delivery_proofs/o2_proof"), PNG, IMG));

    const passed = results.filter(Boolean).length;
    console.log(`\n${passed}/${results.length} scenarios passed`);
    await env.cleanup();
    process.exit(passed === results.length ? 0 : 1);
  } catch (e) { console.error(e); await env.cleanup(); process.exit(1); }
}
main();
