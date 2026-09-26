// Phase DLVID1 — rider identity change requests
// (functions/src/delivery/riderIdentity.ts) on the Firestore emulator.
//  id1 a valid request creates a pending doc and blocks the rider's account
//  id2 a second request while one is pending is refused (already_pending)
//  id3 an invalid changeType/proposedValue/reason is refused per-field
//  id4 approving writes the real field and clears the pending flag
//  id5 rejecting without a reason is refused; with one, records it and does
//      NOT change the field
//  id6 reviewing an already-reviewed or missing request is refused
// Run with: firebase emulators:exec --only firestore "node scripts/phaseDLVID1_identity_test.js"
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
const PROJECT = process.env.GCLOUD_PROJECT || "demo-dlvid1-identity";
if (!PROJECT.startsWith("demo-")) { console.error("REFUSING: not a demo- project"); process.exit(2); }
const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: PROJECT });
const db = admin.firestore();
const I = require("../lib/delivery/riderIdentity");

const results = [];
const record = (label, pass, detail) => { results.push(pass); console.log(`${pass ? "PASSED" : "FAILED"} — ${label}${pass ? "" : ` :: ${detail}`}`); };
const get = async (p) => (await db.doc(p).get()).data();
const NOW = Date.UTC(2026, 8, 26, 10, 0, 0);

async function rider(id, name) {
  await db.doc(`delivery_partners/${id}`).set({ id, name, status: "approved" });
}

async function main() {
  console.log("=== PHASE DLVID1 — identity change requests ===");

  // id1
  await rider("r1", "Arjun K.");
  const v1 = await I.requestIdentityChangeCore(db, "r1", { changeType: "name", proposedValue: "Arjun Kumar", reason: "New government ID" }, NOW);
  record("id1_request_created", v1.kind === "requested" && typeof v1.id === "string", JSON.stringify(v1));
  const req1 = await get(`rider_identity_change_requests/${v1.id}`);
  record("id1_request_fields", req1.riderId === "r1" && req1.changeType === "name" && req1.currentValue === "Arjun K." &&
    req1.proposedValue === "Arjun Kumar" && req1.status === "pending", JSON.stringify(req1));
  const partner1 = await get("delivery_partners/r1");
  record("id1_pending_flag_set", partner1.identityChangePending === v1.id, JSON.stringify(partner1));

  // id2
  const v2 = await I.requestIdentityChangeCore(db, "r1", { changeType: "name", proposedValue: "Someone Else", reason: "Another reason here" }, NOW);
  record("id2_second_request_refused", v2.kind === "refused" && v2.reason === "already_pending", JSON.stringify(v2));

  // id3 — validation, against a rider with no pending request
  await rider("r2", "Priya S.");
  const bad1 = await I.requestIdentityChangeCore(db, "r2", { changeType: "dateOfBirth", proposedValue: "1990-01-01", reason: "Because" }, NOW);
  record("id3_invalid_changeType_refused", bad1.kind === "refused" && bad1.reason === "invalid_changeType", JSON.stringify(bad1));
  const bad2 = await I.requestIdentityChangeCore(db, "r2", { changeType: "name", proposedValue: "A", reason: "Because it changed" }, NOW);
  record("id3_invalid_proposedValue_refused", bad2.kind === "refused" && bad2.reason === "invalid_proposedValue", JSON.stringify(bad2));
  const bad3 = await I.requestIdentityChangeCore(db, "r2", { changeType: "name", proposedValue: "Priya Sundaram", reason: "Hi" }, NOW);
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
  const v3 = await I.requestIdentityChangeCore(db, "r2", { changeType: "name", proposedValue: "Priya Sundaram", reason: "Full legal name" }, NOW);
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

  const passed = results.filter(Boolean).length;
  console.log(`\n${passed}/${results.length} passed`);
  process.exit(passed === results.length ? 0 : 1);
}

main().catch((e) => { console.error(e); process.exit(1); });
