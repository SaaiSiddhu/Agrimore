// Phase DLV-0 — delivery security rules.
//
// Two defects, both reproduced against firestore.rules at 4d08840 with an
// emulator probe before this suite existed:
//
//  (1) The delivery verification code lived only on orders/{id}, and the
//      orders read rule is whole-document — so every approved delivery partner
//      could read the code of every unassigned ready_for_pickup order and of
//      its own order. DLV-0 (stage A) adds orders/{id}/secrets/delivery, which
//      only the order owner and an admin can read and no client can write.
//      The order-doc copy stays until a marketplace build that reads the new
//      location is released (stage B, DLV-0B) — so this suite proves the NEW
//      location is closed, not that the old one is (it cannot be yet).
//
//  (2) A partner could write anything on its own delivery_partners doc except
//      status → approved: bank account, rating, totalDeliveries, isVerified.
//      The owner update is now an allowlist of exactly the fields the released
//      apps/delivery build (0ea1e53) and the current source write:
//      currentLat, currentLng, lastLocationUpdate, isOnline, lastStatusUpdate,
//      updatedAt. Owner create cannot preset rating/totalDeliveries/isVerified/
//      currentOrderId or a non-pending status.
//
// Every denial is paired with a positive control so the suite cannot pass by
// the rules refusing everything.
//
// Run with:
//   firebase emulators:exec --only firestore "node scripts/phaseDLV0_delivery_security_test.js"
// Honours FIRESTORE_EMULATOR_HOST (set by emulators:exec), falling back to 127.0.0.1:8080.
const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");

const [EMU_HOST, EMU_PORT] = (process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080").split(":");

function baseClaims() {
  return { admin: false, seller: false, delivery_partner: false, employee: false };
}
const CLAIMS = {
  user: { ...baseClaims(), role: "user" },
  delivery: { ...baseClaims(), role: "delivery_partner", delivery_partner: true },
  admin: { ...baseClaims(), role: "admin", admin: true },
  applicant: { ...baseClaims(), role: "delivery_partner" }, // signed up, not yet approved
};

const CUSTOMER = "dlv0-customer";
const OTHER_CUSTOMER = "dlv0-other-customer";
const RIDER = "dlv0-rider";
const OTHER_RIDER = "dlv0-other-rider";
const ADMIN = "dlv0-admin";
const APPLICANT = "dlv0-applicant";

let testEnv;
const results = [];
function record(label, pass, detail) {
  results.push({ label, pass, detail });
  console.log(`${pass ? "PASSED" : "FAILED"} — ${label}${pass ? "" : ` :: ${detail}`}`);
}

async function scenario(label, expect, fn) {
  try {
    await (expect === "allow" ? assertSucceeds(fn()) : assertFails(fn()));
    record(label, true, "");
  } catch (e) {
    record(label, false, `expected ${expect} — ${String(e.message || e).slice(0, 200)}`);
  }
}

function ctx(kind, uid) {
  return testEnv.authenticatedContext(uid, CLAIMS[kind]).firestore();
}

async function seed() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.collection("users").doc(RIDER).set({ role: "delivery_partner" });
    await db.collection("users").doc(OTHER_RIDER).set({ role: "delivery_partner" });
    await db.collection("users").doc(ADMIN).set({ role: "admin" });
    await db.collection("users").doc(APPLICANT).set({ role: "delivery_partner" });
    const partner = {
      name: "Rider", phone: "9000000000", vehicleNumber: "TN01AB1234", vehicleType: "bike",
      status: "approved", isOnline: false, rating: 4.2, totalDeliveries: 10,
      bankAccountNumber: "111122223333", ifscCode: "SBIN0000001", upiId: "rider@upi",
    };
    await db.collection("delivery_partners").doc(RIDER).set(partner);
    await db.collection("delivery_partners").doc(OTHER_RIDER).set(partner);

    // Unassigned, visible to every approved partner via isAvailableDeliveryOrder().
    await db.collection("orders").doc("dlv0-open").set({
      userId: CUSTOMER, sellerId: "dlv0-seller", orderStatus: "ready_for_pickup",
      status: "ready_for_pickup", total: 500, deliveryVerificationCode: "123456",
    });
    await db.collection("orders").doc("dlv0-open").collection("secrets").doc("delivery")
      .set({ code: "123456", failedAttempts: 0 });

    // Assigned to RIDER, out for delivery.
    await db.collection("orders").doc("dlv0-mine").set({
      userId: CUSTOMER, sellerId: "dlv0-seller", orderStatus: "out_for_delivery",
      status: "out_for_delivery", total: 500, deliveryPartnerId: RIDER,
      deliveryVerificationCode: "654321",
    });
    await db.collection("orders").doc("dlv0-mine").collection("secrets").doc("delivery")
      .set({ code: "654321", failedAttempts: 0 });
  });
}

const secret = (db, oid) => db.collection("orders").doc(oid).collection("secrets").doc("delivery");
const partnerDoc = (db, uid) => db.collection("delivery_partners").doc(uid);

async function main() {
  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
  testEnv = await initializeTestEnvironment({
    projectId: "demo-dlv0",
    firestore: { rules, host: EMU_HOST, port: Number(EMU_PORT) },
  });
  await testEnv.clearFirestore();
  await seed();

  console.log("=== PHASE DLV-0 — delivery security rules ===");

  // ── (1) orders/{id}/secrets/delivery ──────────────────────────────────
  // Positive controls first: the order itself stays readable to the rider
  // (the app needs it), and the owner can read the secret.
  await scenario("s01_control_rider_can_still_read_its_assigned_order", "allow",
    () => ctx("delivery", RIDER).collection("orders").doc("dlv0-mine").get());
  await scenario("s02_control_rider_can_still_read_an_open_order", "allow",
    () => ctx("delivery", RIDER).collection("orders").doc("dlv0-open").get());
  await scenario("s03_control_order_owner_reads_own_delivery_secret", "allow",
    () => secret(ctx("user", CUSTOMER), "dlv0-mine").get());
  await scenario("s04_control_admin_reads_delivery_secret", "allow",
    () => secret(ctx("admin", ADMIN), "dlv0-mine").get());

  // THE FIX.
  await scenario("s05_assigned_rider_cannot_read_its_orders_secret", "deny",
    () => secret(ctx("delivery", RIDER), "dlv0-mine").get());
  await scenario("s06_rider_cannot_read_an_open_orders_secret", "deny",
    () => secret(ctx("delivery", OTHER_RIDER), "dlv0-open").get());
  await scenario("s07_another_customer_cannot_read_the_secret", "deny",
    () => secret(ctx("user", OTHER_CUSTOMER), "dlv0-mine").get());
  await scenario("s08_rider_cannot_list_secrets_subcollection", "deny",
    () => ctx("delivery", RIDER).collection("orders").doc("dlv0-mine").collection("secrets").get());
  await scenario("s09_owner_cannot_write_the_secret", "deny",
    () => secret(ctx("user", CUSTOMER), "dlv0-mine").set({ code: "000000" }));
  await scenario("s10_rider_cannot_reset_the_attempt_counter", "deny",
    () => secret(ctx("delivery", RIDER), "dlv0-mine").set({ failedAttempts: 0, lockedUntil: null }, { merge: true }));
  await scenario("s11_admin_client_cannot_write_the_secret_either", "deny",
    () => secret(ctx("admin", ADMIN), "dlv0-mine").set({ code: "000000" }));

  // ── (2) delivery_partners owner writes ───────────────────────────────
  // Positive controls: the EXACT payloads the released build (0ea1e53) and the
  // current source send — location_provider.dart's _uploadLocation (update)
  // and setOnlineStatus (set merge).
  await scenario("s12_control_rider_uploads_location", "allow",
    () => partnerDoc(ctx("delivery", RIDER), RIDER).update({
      currentLat: 9.96, currentLng: 78.12, lastLocationUpdate: new Date(),
    }));
  await scenario("s13_control_rider_goes_online_via_set_merge", "allow",
    () => partnerDoc(ctx("delivery", RIDER), RIDER).set({
      isOnline: true, lastStatusUpdate: new Date(),
    }, { merge: true }));
  await scenario("s14_control_rider_writes_updatedAt", "allow",
    () => partnerDoc(ctx("delivery", RIDER), RIDER).update({ isOnline: false, updatedAt: new Date() }));

  // THE FIX.
  await scenario("s15_rider_cannot_change_bank_account", "deny",
    () => partnerDoc(ctx("delivery", RIDER), RIDER).update({ bankAccountNumber: "999999999999" }));
  await scenario("s16_rider_cannot_change_ifsc_or_upi", "deny",
    () => partnerDoc(ctx("delivery", RIDER), RIDER).update({ ifscCode: "HDFC0000001", upiId: "x@upi" }));
  await scenario("s17_rider_cannot_set_own_rating", "deny",
    () => partnerDoc(ctx("delivery", RIDER), RIDER).update({ rating: 5 }));
  await scenario("s18_rider_cannot_inflate_totalDeliveries", "deny",
    () => partnerDoc(ctx("delivery", RIDER), RIDER).update({ totalDeliveries: 9999 }));
  await scenario("s19_rider_cannot_mark_itself_verified", "deny",
    () => partnerDoc(ctx("delivery", RIDER), RIDER).update({ isVerified: true }));
  await scenario("s20_rider_cannot_change_status_even_to_pending", "deny",
    () => partnerDoc(ctx("delivery", RIDER), RIDER).update({ status: "pending" }));
  await scenario("s21_rider_cannot_smuggle_bank_change_inside_a_location_write", "deny",
    () => partnerDoc(ctx("delivery", RIDER), RIDER).update({
      currentLat: 9.9, currentLng: 78.1, bankAccountNumber: "999999999999",
    }));
  await scenario("s22_rider_cannot_clear_its_currentOrderId", "deny",
    () => partnerDoc(ctx("delivery", RIDER), RIDER).update({ currentOrderId: null, isAvailable: true }));
  await scenario("s23_rider_cannot_write_another_riders_doc", "deny",
    () => partnerDoc(ctx("delivery", RIDER), OTHER_RIDER).update({ currentLat: 1, currentLng: 1 }));
  await scenario("s24_control_admin_can_still_edit_bank_and_status", "allow",
    () => partnerDoc(ctx("admin", ADMIN), RIDER).update({ bankAccountNumber: "444455556666", status: "approved" }));

  // Owner create — registration.
  // Positive control: the payload partner_registration_screen.dart sends
  // (DeliveryPartnerModel.toMap(): rating null, totalDeliveries 0, status pending).
  const registration = {
    id: APPLICANT, name: "New Rider", phone: "9111111111", photoUrl: null,
    vehicleNumber: "TN02CD5678", vehicleType: "bike", currentLat: null, currentLng: null,
    lastLocationUpdate: null, rating: null, totalDeliveries: 0, isOnline: false,
    aadhaarNumber: "123412341234", aadhaarFrontImage: "u1", aadhaarBackImage: "u2",
    selfieImage: "u3", licenseNumber: "L1", licenseImage: "u4", address: "a", city: "c",
    pincode: "625001", accountHolderName: "N", bankAccountNumber: "1", ifscCode: "I",
    upiId: "u@upi", status: "pending", createdAt: new Date(),
  };
  await scenario("s25_control_registration_payload_creates", "allow",
    () => partnerDoc(ctx("applicant", APPLICANT), APPLICANT).set(registration));
  await testEnv.withSecurityRulesDisabled((c) => c.firestore().collection("delivery_partners").doc(APPLICANT).delete());
  await scenario("s26_create_cannot_preset_rating", "deny",
    () => partnerDoc(ctx("applicant", APPLICANT), APPLICANT).set({ ...registration, rating: 5 }));
  await scenario("s27_create_cannot_preset_totalDeliveries", "deny",
    () => partnerDoc(ctx("applicant", APPLICANT), APPLICANT).set({ ...registration, totalDeliveries: 500 }));
  await scenario("s28_create_cannot_preset_isVerified", "deny",
    () => partnerDoc(ctx("applicant", APPLICANT), APPLICANT).set({ ...registration, isVerified: true }));
  await scenario("s29_create_cannot_self_approve", "deny",
    () => partnerDoc(ctx("applicant", APPLICANT), APPLICANT).set({ ...registration, status: "approved" }));
  await scenario("s30_create_cannot_use_a_non_pending_status", "deny",
    () => partnerDoc(ctx("applicant", APPLICANT), APPLICANT).set({ ...registration, status: "active" }));
  // setOnlineStatus()'s set-merge on a doc that does not exist yet is a create.
  await scenario("s31_control_online_toggle_create_without_status_allowed", "allow",
    () => partnerDoc(ctx("applicant", APPLICANT), APPLICANT).set({ isOnline: false, lastStatusUpdate: new Date() }, { merge: true }));

  await testEnv.clearFirestore();
  await testEnv.cleanup();

  const failed = results.filter((r) => !r.pass);
  console.log(`\n${results.length - failed.length}/${results.length} passed`);
  if (failed.length) {
    console.log("FAILED:", failed.map((f) => f.label).join(", "));
    process.exit(1);
  }
}

main().catch(async (e) => {
  console.error(e);
  try { await testEnv?.cleanup(); } catch (_) { /* ignore */ }
  process.exit(1);
});
