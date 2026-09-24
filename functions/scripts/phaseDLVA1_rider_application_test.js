// Phase DLV-A1 — submitRiderApplicationCore (functions/src/delivery/riderApplication.ts)
// against the Firestore emulator; Storage is a fake lookup here (the HTTP
// suite uses the real Storage emulator).
//
//  v — validation: stable problem keys; phone normalised; bicycle needs no plate;
//      bank all-or-nothing; name stored exactly as entered (no " Partner")
//  s — submit: one transaction writes users + delivery_partners, status
//      pending, storage PATHS not URLs; documents must exist, be images, fit
//  r — resubmission from pending/rejected updates the same record and clears
//      legacy URL fields; approved/suspended cannot; other roles are refused
//
// Run with: firebase emulators:exec --only firestore "node scripts/phaseDLVA1_rider_application_test.js"
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: "demo-dlva1-app" });
const db = admin.firestore();
const A = require("../lib/delivery/riderApplication");

const results = [];
const record = (label, pass, detail) => { results.push(pass); console.log(`${pass ? "PASSED" : "FAILED"} — ${label}${pass ? "" : ` :: ${detail}`}`); };
const good = {
  name: " Ravi Kumar ", phone: "+91 98765-43210", altPhone: "", vehicleType: "bike", vehicleNumber: "tn 58 ab 1234",
  licenseNumber: "TN58-2020-0001234", aadhaarNumber: "2345 6789 0123", address: "12, Main Road, Anna Nagar", city: "Madurai",
  pincode: "625020", accountHolderName: "", bankAccountNumber: "", ifscCode: "", upiId: "ravi@okaxis",
};
const allDocs = (over = {}) => async (path) => {
  const key = path.split("/").pop();
  return key in over ? over[key] : { size: 120000, contentType: "image/jpeg" };
};
const get = async (p) => (await db.doc(p).get()).data();

async function main() {
  console.log("=== PHASE DLV-A1 — rider application ===");
  // ── validation ──
  let v = A.validateRiderApplication(good);
  record("v01_good_application_is_clean", v.problems.length === 0 && v.application.phone === "9876543210" &&
    v.application.vehicleNumber === "TN58AB1234" && v.application.name === "Ravi Kumar" && v.application.bankAccountNumber === null, JSON.stringify(v));
  v = A.validateRiderApplication({});
  record("v02_empty_lists_every_required_field", ["name", "phone", "vehicleType", "vehicleNumber", "licenseNumber", "aadhaarNumber", "address", "city", "pincode"]
    .every((k) => v.problems.includes(k)), JSON.stringify(v.problems));
  v = A.validateRiderApplication({ ...good, vehicleType: "bicycle", vehicleNumber: "" });
  record("v03_bicycle_needs_no_plate", v.problems.length === 0 && v.application.vehicleNumber === null, JSON.stringify(v.problems));
  v = A.validateRiderApplication({ ...good, bankAccountNumber: "123456789012" });
  record("v04_bank_is_all_or_nothing", v.problems.includes("accountHolderName") && v.problems.includes("ifscCode"), JSON.stringify(v.problems));
  v = A.validateRiderApplication({ ...good, altPhone: "9876543210" });
  record("v05_alt_phone_must_differ", v.problems.includes("altPhone"), JSON.stringify(v.problems));
  v = A.validateRiderApplication({ ...good, aadhaarNumber: "1234 5678 9012", phone: "12345", pincode: "0600", upiId: "nope" });
  record("v06_bad_formats", ["aadhaarNumber", "phone", "pincode", "upiId"].every((k) => v.problems.includes(k)), JSON.stringify(v.problems));

  // ── submit ──
  let r = await A.submitRiderApplicationCore(db, "u1", "u1@x.in", good, allDocs());
  const u1 = await get("users/u1"), p1 = await get("delivery_partners/u1");
  record("s01_one_submit_writes_both_records", r.kind === "submitted" && !r.resubmitted && u1.role === "delivery_partner" &&
    u1.name === "Ravi Kumar" && u1.email === "u1@x.in" && p1.status === "pending" && p1.isOnline === false, JSON.stringify({ r, u1 }));
  record("s02_documents_are_paths_not_urls", p1.kycDocuments.aadhaarFront === "delivery_documents/u1/aadhaarFront" &&
    p1.kycDocuments.license === "delivery_documents/u1/license" && p1.aadhaarFrontImage === undefined && !JSON.stringify(p1).includes("http"), JSON.stringify(p1.kycDocuments));
  r = await A.submitRiderApplicationCore(db, "u2", "u2@x.in", good, allDocs({ license: null }));
  record("s03_missing_photo_refused_nothing_written", r.reason === "documents" && r.problems.includes("documents.license") &&
    !(await db.doc("delivery_partners/u2").get()).exists && !(await db.doc("users/u2").get()).exists, JSON.stringify(r));
  r = await A.submitRiderApplicationCore(db, "u2", "u2@x.in", good, allDocs({ selfie: { size: 900, contentType: "text/html" } }));
  record("s04_non_image_refused", r.reason === "documents" && r.problems.includes("documents.selfie"), JSON.stringify(r));
  r = await A.submitRiderApplicationCore(db, "u2", "u2@x.in", good, allDocs({ aadhaarBack: { size: 10 * 1024 * 1024, contentType: "image/png" } }));
  record("s05_too_large_refused", r.reason === "documents" && r.problems.includes("documents.aadhaarBack"), JSON.stringify(r));
  r = await A.submitRiderApplicationCore(db, "u2", "u2@x.in", { ...good, phone: "1" }, allDocs());
  record("s06_invalid_fields_refused_with_keys", r.reason === "invalid" && r.problems.includes("phone"), JSON.stringify(r));

  // ── resubmission / roles ──
  await db.doc("delivery_partners/u1").update({ status: "rejected", rejectionReason: "Blurry licence", aadhaarFrontImage: "https://old/url" });
  r = await A.submitRiderApplicationCore(db, "u1", "u1@x.in", { ...good, city: "Chennai" }, allDocs());
  const p1b = await get("delivery_partners/u1");
  record("r01_rejected_rider_resubmits_same_record", r.kind === "submitted" && r.resubmitted && p1b.status === "pending" &&
    p1b.city === "Chennai" && p1b.resubmissionCount === 1 && p1b.previousStatus === "rejected" && p1b.aadhaarFrontImage === undefined, JSON.stringify(p1b));
  r = await A.submitRiderApplicationCore(db, "u1", "u1@x.in", good, allDocs());
  record("r02_pending_retry_is_idempotent", r.kind === "submitted" && (await get("delivery_partners/u1")).status === "pending" &&
    (await db.collection("delivery_partners").get()).size === 1, JSON.stringify(r));
  for (const st of ["approved", "suspended", "deactivated"]) {
    await db.doc("delivery_partners/u3").set({ status: st, name: "X" });
    await db.doc("users/u3").set({ role: "delivery_partner" });
    r = await A.submitRiderApplicationCore(db, "u3", "u3@x.in", good, allDocs());
    record(`r03_${st}_rider_cannot_resubmit`, r.reason === "already_registered" && (await get("delivery_partners/u3")).status === st, JSON.stringify(r));
  }
  for (const role of ["user", "seller", "admin", "employee"]) {
    await db.doc(`users/role-${role}`).set({ role, name: "Keep" });
    r = await A.submitRiderApplicationCore(db, `role-${role}`, null, good, allDocs());
    const u = await get(`users/role-${role}`);
    record(`r04_${role}_account_keeps_its_role`, r.reason === "other_account_role" && u.role === role && u.name === "Keep" &&
      !(await db.doc(`delivery_partners/role-${role}`).get()).exists, JSON.stringify(r));
  }
  await db.doc("users/noRole").set({ name: "Half", email: "h@x.in" });
  r = await A.submitRiderApplicationCore(db, "noRole", "h@x.in", good, allDocs());
  record("r05_profile_without_role_may_register", r.kind === "submitted" && (await get("users/noRole")).role === "delivery_partner", JSON.stringify(r));

  const failed = results.filter((x) => !x).length;
  console.log(`\n${results.length - failed}/${results.length} passed`);
  if (failed) { console.log("PHASE DLV-A1 application: FAILED"); process.exit(1); }
  console.log("PHASE DLV-A1 application: ALL PASSED"); process.exit(0);
}
main().catch((e) => { console.error(e); process.exit(1); });
