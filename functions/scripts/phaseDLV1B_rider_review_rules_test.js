// Phase DLV-1B — rider onboarding review, against firestore.rules.
//
// The admin review sheet (apps/admin delivery_partner_management_screen.dart)
// writes, in ONE batch:
//   delivery_partners/{uid}: status, reviewedBy, reviewedAt,
//                            rejectionReason | suspensionReason, (isOnline:false on suspend)
//   users/{uid}:             deliveryStatus (mirror — roleClaims.ts treats EITHER
//                            field being 'approved' as approved, so a stale
//                            'approved' here would keep a suspended rider's claim)
// and add_delivery_partner_dialog.dart now creates admin-made riders with
// status 'approved'. This suite proves those admin writes are allowed and that
// a rider can forge none of them (DLV-0's owner allowlist is unchanged).
//
// Run with:
//   firebase emulators:exec --only firestore "node scripts/phaseDLV1B_rider_review_rules_test.js"
// Honours FIRESTORE_EMULATOR_HOST (set by emulators:exec), falling back to 127.0.0.1:8080.
const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");

const [EMU_HOST, EMU_PORT] = (process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080").split(":");
const base = { admin: false, seller: false, delivery_partner: false, employee: false };
const CLAIMS = {
  admin: { ...base, role: "admin", admin: true },
  applicant: { ...base, role: "delivery_partner" },
  rider: { ...base, role: "delivery_partner", delivery_partner: true },
};

const ADMIN = "dlv1b-admin";
const APPLICANT = "dlv1b-applicant";
const RIDER = "dlv1b-rider";
const NEW_RIDER = "dlv1b-admin-made";
// Denials run against a rider that is ALREADY suspended and a separate
// rejected applicant, so every forged write is a real change — a write that
// sets a field to the value it already holds is a no-op Firestore allows.
const SUSPENDED = "dlv1b-suspended";
const REJECTED = "dlv1b-rejected";

let testEnv;
const results = [];
async function scenario(label, expect, fn) {
  try {
    await (expect === "allow" ? assertSucceeds(fn()) : assertFails(fn()));
    results.push({ label, pass: true });
    console.log(`PASSED — ${label}`);
  } catch (e) {
    results.push({ label, pass: false });
    console.log(`FAILED — ${label} :: expected ${expect} — ${String(e.message || e).slice(0, 160)}`);
  }
}
const db = (kind, uid) => testEnv.authenticatedContext(uid, CLAIMS[kind]).firestore();

async function reviewBatch(d, uid, fields) {
  const b = d.batch();
  b.set(d.collection("delivery_partners").doc(uid), {
    ...fields, reviewedBy: ADMIN, reviewedAt: new Date(),
  }, { merge: true });
  b.set(d.collection("users").doc(uid), { deliveryStatus: fields.status }, { merge: true });
  return b.commit();
}

async function main() {
  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
  testEnv = await initializeTestEnvironment({
    projectId: "demo-dlv1b",
    firestore: { rules, host: EMU_HOST, port: Number(EMU_PORT) },
  });
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (c) => {
    const f = c.firestore();
    await f.collection("users").doc(ADMIN).set({ role: "admin" });
    await f.collection("users").doc(APPLICANT).set({ role: "delivery_partner", name: "A" });
    await f.collection("delivery_partners").doc(APPLICANT).set({ name: "A", status: "pending", isOnline: false });
    await f.collection("users").doc(RIDER).set({ role: "delivery_partner", name: "R" });
    await f.collection("delivery_partners").doc(RIDER).set({ name: "R", status: "approved", isOnline: true });
    await f.collection("users").doc(SUSPENDED).set({ role: "delivery_partner", name: "S", deliveryStatus: "suspended" });
    await f.collection("delivery_partners").doc(SUSPENDED).set({ name: "S", status: "suspended", suspensionReason: "Late", isOnline: false });
    await f.collection("users").doc(REJECTED).set({ role: "delivery_partner", name: "J" });
    await f.collection("delivery_partners").doc(REJECTED).set({ name: "J", status: "rejected", rejectionReason: "Blurry" });
  });

  console.log("=== PHASE DLV-1B — rider review rules ===");

  // Admin review writes (positive controls — the screen's exact batches).
  await scenario("v01_admin_approves_an_applicant", "allow",
    () => reviewBatch(db("admin", ADMIN), APPLICANT, { status: "approved" }));
  await scenario("v02_admin_rejects_with_a_reason", "allow",
    () => reviewBatch(db("admin", ADMIN), APPLICANT, { status: "rejected", rejectionReason: "Licence photo unreadable" }));
  await scenario("v03_admin_suspends_and_forces_offline", "allow",
    () => reviewBatch(db("admin", ADMIN), RIDER, { status: "suspended", suspensionReason: "Repeated late deliveries", isOnline: false }));
  await scenario("v04_admin_reinstates", "allow",
    () => reviewBatch(db("admin", ADMIN), RIDER, { status: "approved", suspensionReason: null }));
  await scenario("v05_admin_creates_a_partner_already_approved", "allow",
    () => db("admin", ADMIN).collection("delivery_partners").doc(NEW_RIDER).set({
      id: NEW_RIDER, name: "Made", phone: "9", vehicleNumber: "TN1", vehicleType: "bike",
      isOnline: false, isAvailable: true, isVerified: true, rating: 5.0, totalDeliveries: 0,
      status: "approved", reviewedBy: ADMIN, reviewedAt: new Date(), createdAt: new Date(),
    }));

  // A rider can forge none of it.
  await scenario("v06_rider_cannot_reinstate_itself", "deny",
    () => db("rider", SUSPENDED).collection("delivery_partners").doc(SUSPENDED).update({ status: "approved" }));
  await scenario("v07_rider_cannot_clear_its_suspension_reason", "deny",
    () => db("rider", SUSPENDED).collection("delivery_partners").doc(SUSPENDED).update({ suspensionReason: null }));
  await scenario("v08_rider_cannot_write_reviewedBy", "deny",
    () => db("rider", SUSPENDED).collection("delivery_partners").doc(SUSPENDED).update({ reviewedBy: SUSPENDED }));
  await scenario("v09_applicant_cannot_clear_its_rejection", "deny",
    () => db("applicant", REJECTED).collection("delivery_partners").doc(REJECTED).update({ status: "pending", rejectionReason: null }));
  await scenario("v10_rider_cannot_set_users_deliveryStatus_approved", "deny",
    () => db("rider", SUSPENDED).collection("users").doc(SUSPENDED).set({ deliveryStatus: "approved" }, { merge: true }));
  // Positive control for the rider app's own write while blocked:
  // setOnlineStatus(false) when the gate shows the blocked screen.
  await scenario("v11_suspended_rider_can_still_go_offline", "allow",
    () => db("rider", SUSPENDED).collection("delivery_partners").doc(SUSPENDED).set({ isOnline: true, lastStatusUpdate: new Date() }, { merge: true })
      .then(() => db("rider", SUSPENDED).collection("delivery_partners").doc(SUSPENDED).set({ isOnline: false, lastStatusUpdate: new Date() }, { merge: true })));
  // And can read its own doc (the app listens to it for the status/reason).
  await scenario("v12_rider_reads_own_status_and_reason", "allow",
    () => db("rider", SUSPENDED).collection("delivery_partners").doc(SUSPENDED).get());

  await testEnv.clearFirestore();
  await testEnv.cleanup();
  const failed = results.filter((r) => !r.pass);
  console.log(`\n${results.length - failed.length}/${results.length} passed`);
  if (failed.length) { console.log("PHASE DLV-1B rules: FAILED"); process.exit(1); }
  console.log("PHASE DLV-1B rules: ALL PASSED");
}

main().catch(async (e) => { console.error(e); try { await testEnv?.cleanup(); } catch (_) { /* ignore */ } process.exit(1); });
