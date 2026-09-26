// Phase DLVID1 — rider identity change requests, generalized in DLVID2
// (functions/src/delivery/riderIdentity.ts) on the Firestore emulator.
//  id1 a valid name request creates a pending doc and blocks the rider's account
//  id2 a second request while one is pending is refused (already_pending)
//  id3 an invalid changeType/name/reason is refused per-field
//  id4 approving writes the real field and clears the pending flag
//  id5 rejecting without a reason is refused; with one, records it and does
//      NOT change the field
//  id6 reviewing an already-reviewed or missing request is refused
//  id7 a valid vehicle request stores both proposed fields as one map
//  id8 proposing "bicycle" needs no plate number
//  id9 an invalid vehicleType is refused
//  id10 an invalid vehicleNumber (needs a plate, fails the regex) is refused
//  id11 approving a vehicle request writes BOTH fields together
// Run with: firebase emulators:exec --only firestore "node scripts/phaseDLVID1_identity_test.js"
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
const PROJECT = process.env.GCLOUD_PROJECT || "demo-dlvid1-identity";
if (!PROJECT.startsWith("demo-")) { console.error(`REFUSING: project ${PROJECT} is not a demo- project`); process.exit(2); }
const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: PROJECT });
const db = admin.firestore();
const I = require("../lib/delivery/riderIdentity");

const results = [];
const record = (label, pass, detail) => { results.push(pass); console.log(`${pass ? "PASSED" : "FAILED"} — ${label}${pass ? "" : ` :: ${detail}`}`); };
const get = async (p) => (await db.doc(p).get()).data();
const NOW = Date.UTC(2026, 8, 26, 10, 0, 0);

async function rider(id, name, extra = {}) {
  await db.doc(`delivery_partners/${id}`).set({ id, name, status: "approved", ...extra });
}

async function main() {
  console.log("=== PHASE DLVID1/DLVID2 — identity change requests ===");

  // id1
  await rider("r1", "Arjun K.");
  const v1 = await I.requestIdentityChangeCore(db, "r1", { changeType: "name", proposedValues: { name: "Arjun Kumar" }, reason: "New government ID" }, NOW);
  record("id1_request_created", v1.kind === "requested" && typeof v1.id === "string", JSON.stringify(v1));
  const req1 = await get(`rider_identity_change_requests/${v1.id}`);
  record("id1_request_fields", req1.riderId === "r1" && req1.changeType === "name" && req1.currentValues.name === "Arjun K." &&
    req1.proposedValues.name === "Arjun Kumar" && req1.status === "pending", JSON.stringify(req1));
  const partner1 = await get("delivery_partners/r1");
  record("id1_pending_flag_set", partner1.identityChangePending === v1.id, JSON.stringify(partner1));

  // id2
  const v2 = await I.requestIdentityChangeCore(db, "r1", { changeType: "name", proposedValues: { name: "Someone Else" }, reason: "Another reason here" }, NOW);
  record("id2_second_request_refused", v2.kind === "refused" && v2.reason === "already_pending", JSON.stringify(v2));

  // id3 — validation, against a rider with no pending request
  await rider("r2", "Priya S.");
  const bad1 = await I.requestIdentityChangeCore(db, "r2", { changeType: "dateOfBirth", proposedValues: { dateOfBirth: "1990-01-01" }, reason: "Because" }, NOW);
  record("id3_invalid_changeType_refused", bad1.kind === "refused" && bad1.reason === "invalid_changeType", JSON.stringify(bad1));
  const bad2 = await I.requestIdentityChangeCore(db, "r2", { changeType: "name", proposedValues: { name: "A" }, reason: "Because it changed" }, NOW);
  record("id3_invalid_name_refused", bad2.kind === "refused" && bad2.reason === "invalid_name", JSON.stringify(bad2));
  const bad3 = await I.requestIdentityChangeCore(db, "r2", { changeType: "name", proposedValues: { name: "Priya Sundaram" }, reason: "Hi" }, NOW);
  record("id3_invalid_reason_refused", bad3.kind === "refused" && bad3.reason === "invalid_reason", JSON.stringify(bad3));

  // id4 — approve r1's pending request
  const rv1 = await I.reviewIdentityChangeCore(db, "adminUid", v1.id, true, null, NOW);
  record("id4_approved", rv1.kind === "approved", JSON.stringify(rv1));
  const partnerAfterApprove = await get("delivery_partners/r1");
  record("id4_name_actually_changed", partnerAfterApprove.name === "Arjun Kumar", JSON.stringify(partnerAfterApprove));
  record("id4_pending_flag_cleared", partnerAfterApprove.identityChangePending === null, JSON.stringify(partnerAfterApprove));
  const reqAfterApprove = await get(`rider_identity_change_requests/${v1.id}`);
  record("id4_request_marked_approved", reqAfterApprove.status === "approved" && reqAfterApprove.reviewedBy === "adminUid" &&
    reqAfterApprove.rejectionReason === null, JSON.stringify(reqAfterApprove));

  // id5 — a fresh request for r2, then reject it
  const v3 = await I.requestIdentityChangeCore(db, "r2", { changeType: "name", proposedValues: { name: "Priya Sundaram" }, reason: "Full legal name" }, NOW);
  record("id5_setup", v3.kind === "requested", JSON.stringify(v3));
  const rejectNoReason = await I.reviewIdentityChangeCore(db, "adminUid", v3.id, false, null, NOW);
  record("id5_reject_without_reason_refused", rejectNoReason.kind === "refused" && rejectNoReason.reason === "reason_required", JSON.stringify(rejectNoReason));
  const rv3 = await I.reviewIdentityChangeCore(db, "adminUid", v3.id, false, "Supporting document is unclear", NOW);
  record("id5_rejected", rv3.kind === "rejected", JSON.stringify(rv3));
  const partnerAfterReject = await get("delivery_partners/r2");
  record("id5_name_unchanged_on_reject", partnerAfterReject.name === "Priya S." && partnerAfterReject.identityChangePending === null, JSON.stringify(partnerAfterReject));
  const reqAfterReject = await get(`rider_identity_change_requests/${v3.id}`);
  record("id5_rejection_reason_recorded", reqAfterReject.status === "rejected" && reqAfterReject.rejectionReason === "Supporting document is unclear", JSON.stringify(reqAfterReject));

  // id6
  const reviewAgain = await I.reviewIdentityChangeCore(db, "adminUid", v3.id, true, null, NOW);
  record("id6_already_reviewed_refused", reviewAgain.kind === "refused" && reviewAgain.reason === "not_pending", JSON.stringify(reviewAgain));
  const reviewMissing = await I.reviewIdentityChangeCore(db, "adminUid", "nonexistent-id", true, null, NOW);
  record("id6_missing_refused", reviewMissing.kind === "refused" && reviewMissing.reason === "not_found", JSON.stringify(reviewMissing));

  // id7 — a valid vehicle change request stores both proposed fields as one map
  await rider("r3", "Karthik R.", { vehicleType: "bike", vehicleNumber: "TN01AB1234" });
  const v7 = await I.requestIdentityChangeCore(db, "r3",
    { changeType: "vehicle", proposedValues: { vehicleType: "car", vehicleNumber: "tn09xy5678" }, reason: "Upgraded to a car" }, NOW);
  record("id7_vehicle_request_created", v7.kind === "requested", JSON.stringify(v7));
  const req7 = await get(`rider_identity_change_requests/${v7.id}`);
  record("id7_vehicle_request_fields", req7.changeType === "vehicle" &&
    req7.currentValues.vehicleType === "bike" && req7.currentValues.vehicleNumber === "TN01AB1234" &&
    req7.proposedValues.vehicleType === "car" && req7.proposedValues.vehicleNumber === "TN09XY5678", JSON.stringify(req7));

  // id8 — proposing "bicycle" needs no plate
  await rider("r4", "Meena V.", { vehicleType: "bike", vehicleNumber: "KA05CD9999" });
  const v8 = await I.requestIdentityChangeCore(db, "r4",
    { changeType: "vehicle", proposedValues: { vehicleType: "bicycle", vehicleNumber: "" }, reason: "Switching to a bicycle" }, NOW);
  record("id8_bicycle_needs_no_plate", v8.kind === "requested", JSON.stringify(v8));
  const req8 = await get(`rider_identity_change_requests/${v8.id}`);
  record("id8_bicycle_proposed_values", req8.proposedValues.vehicleType === "bicycle" && req8.proposedValues.vehicleNumber === "", JSON.stringify(req8));

  // id9 — invalid vehicleType refused
  await rider("r5", "Suresh N.");
  const bad4 = await I.requestIdentityChangeCore(db, "r5",
    { changeType: "vehicle", proposedValues: { vehicleType: "spaceship", vehicleNumber: "TN01AB1234" }, reason: "Because" }, NOW);
  record("id9_invalid_vehicleType_refused", bad4.kind === "refused" && bad4.reason === "invalid_vehicleType", JSON.stringify(bad4));

  // id10 — invalid vehicleNumber (motor vehicle, bad plate) refused
  const bad5 = await I.requestIdentityChangeCore(db, "r5",
    { changeType: "vehicle", proposedValues: { vehicleType: "car", vehicleNumber: "!!" }, reason: "Because" }, NOW);
  record("id10_invalid_vehicleNumber_refused", bad5.kind === "refused" && bad5.reason === "invalid_vehicleNumber", JSON.stringify(bad5));

  // id11 — approving a vehicle request writes BOTH fields together
  const rv7 = await I.reviewIdentityChangeCore(db, "adminUid", v7.id, true, null, NOW);
  record("id11_vehicle_approved", rv7.kind === "approved", JSON.stringify(rv7));
  const partnerAfterVehicleApprove = await get("delivery_partners/r3");
  record("id11_both_vehicle_fields_changed", partnerAfterVehicleApprove.vehicleType === "car" &&
    partnerAfterVehicleApprove.vehicleNumber === "TN09XY5678" && partnerAfterVehicleApprove.identityChangePending === null,
    JSON.stringify(partnerAfterVehicleApprove));

  const passed = results.filter(Boolean).length;
  console.log(`\n${passed}/${results.length} passed`);
  process.exit(passed === results.length ? 0 : 1);
}

main().catch((e) => { console.error(e); process.exit(1); });
