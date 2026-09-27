// Phase DLVDOC2 — per-document review status
// (functions/src/delivery/riderDocumentReview.ts) on the Firestore emulator.
// Storage is faked via the same injectable lookup/copy seams the production
// callables use (ObjectLookup/ObjectCopy) -- this suite proves the Firestore
// state machine and its guard conditions, not Storage's own behavior.
//  dr1  a valid submission (staged file exists) creates a pending doc and
//       sets documentReviewPending/documentReview on the partner
//  dr2  a second submission for the SAME document while one is pending is
//       refused (already_pending)
//  dr3  an invalid docType is refused
//  dr4  an invalid submissionId shape is refused
//  dr5  a missing/invalid staged upload is refused (upload_missing), and
//       nothing is written to Firestore
//  dr6  a pending submission for one document does not block a DIFFERENT
//       document for the same rider
//  dr7  approving copies the staged path onto the live path, records the
//       verdict, and clears the pending flag for that document only
//  dr8  rejecting without a reason is refused; with one, records it and
//       does NOT call copy at all
//  dr9  reviewing an already-reviewed submission is refused (not_pending)
//  dr10 reviewing a missing submission is refused (not_found)
//  dr11 a NEW submission for the same document is accepted once the prior
//       one has been decided (the block is only while genuinely pending)
//  dr12 none of the above ever touches the whole-application status or
//       kycDocuments fields -- the three-way distinction the brief requires
//  dr13 a submission for a uid with no delivery_partners doc is refused
// Run with: firebase emulators:exec --only firestore "node scripts/phaseDLVDOC2_document_review_test.js"
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
const PROJECT = process.env.GCLOUD_PROJECT || "demo-dlvdoc2-document-review";
if (!PROJECT.startsWith("demo-")) { console.error(`REFUSING: project ${PROJECT} is not a demo- project`); process.exit(2); }
const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: PROJECT });
const db = admin.firestore();
const R = require("../lib/delivery/riderDocumentReview");

const results = [];
const record = (label, pass, detail) => { results.push(pass); console.log(`${pass ? "PASSED" : "FAILED"} — ${label}${pass ? "" : ` :: ${detail}`}`); };
const get = async (p) => (await db.doc(p).get()).data();
const NOW = Date.UTC(2026, 8, 27, 10, 0, 0);

async function rider(id, extra = {}) {
  await db.doc(`delivery_partners/${id}`).set({
    id, status: "approved", kycDocuments: { aadhaarFront: `delivery_documents/${id}/aadhaarFront` }, ...extra,
  });
}

function fakeLookup(validPaths) {
  return async (path) => (validPaths.has(path) ? { size: 12345, contentType: "image/jpeg" } : null);
}
function fakeCopy(log) {
  return async (src, dest) => { log.push({ src, dest }); };
}

async function main() {
  console.log("=== PHASE DLVDOC2 — per-document review status ===");
  const copyLog = [];
  const copy = fakeCopy(copyLog);

  // dr1
  await rider("r1");
  const staged1 = R.stagingPath("r1", "sub-r1-aadhaarFront-1");
  const lookup1 = fakeLookup(new Set([staged1]));
  const v1 = await R.submitDocumentReplacementCore(db, "r1", { docType: "aadhaarFront", submissionId: "sub-r1-aadhaarFront-1" }, lookup1, NOW);
  record("dr1_submitted", v1.kind === "submitted" && v1.id === "sub-r1-aadhaarFront-1", JSON.stringify(v1));
  const sub1 = await get("document_review_submissions/sub-r1-aadhaarFront-1");
  record("dr1_submission_fields", sub1.riderId === "r1" && sub1.docType === "aadhaarFront" &&
    sub1.stagingPath === staged1 && sub1.status === "pending", JSON.stringify(sub1));
  const partner1 = await get("delivery_partners/r1");
  record("dr1_partner_pending_set", partner1.documentReviewPending.aadhaarFront === "sub-r1-aadhaarFront-1", JSON.stringify(partner1));
  record("dr1_partner_review_set", partner1.documentReview.aadhaarFront.status === "pending", JSON.stringify(partner1));

  // dr2
  const staged2 = R.stagingPath("r1", "sub-r1-aadhaarFront-2");
  const lookup2 = fakeLookup(new Set([staged2]));
  const v2 = await R.submitDocumentReplacementCore(db, "r1", { docType: "aadhaarFront", submissionId: "sub-r1-aadhaarFront-2" }, lookup2, NOW);
  record("dr2_second_submission_refused", v2.kind === "refused" && v2.reason === "already_pending", JSON.stringify(v2));

  // dr3
  const bad1 = await R.submitDocumentReplacementCore(db, "r1", { docType: "passport", submissionId: "sub-bad-1" }, fakeLookup(new Set()), NOW);
  record("dr3_invalid_docType_refused", bad1.kind === "refused" && bad1.reason === "invalid_docType", JSON.stringify(bad1));

  // dr4
  const bad2 = await R.submitDocumentReplacementCore(db, "r1", { docType: "selfie", submissionId: "a b" }, fakeLookup(new Set()), NOW);
  record("dr4_invalid_submissionId_refused", bad2.kind === "refused" && bad2.reason === "invalid_submissionId", JSON.stringify(bad2));

  // dr5
  await rider("r2");
  const bad3 = await R.submitDocumentReplacementCore(db, "r2", { docType: "selfie", submissionId: "sub-r2-selfie-1" }, fakeLookup(new Set()), NOW);
  record("dr5_upload_missing_refused", bad3.kind === "refused" && bad3.reason === "upload_missing", JSON.stringify(bad3));
  const noSub = await get("document_review_submissions/sub-r2-selfie-1");
  record("dr5_nothing_written", noSub === undefined, JSON.stringify(noSub));

  // dr6 — r1 has aadhaarFront pending; selfie for r1 must still go through
  const staged6 = R.stagingPath("r1", "sub-r1-selfie-1");
  const v6 = await R.submitDocumentReplacementCore(db, "r1", { docType: "selfie", submissionId: "sub-r1-selfie-1" }, fakeLookup(new Set([staged6])), NOW);
  record("dr6_different_document_not_blocked", v6.kind === "submitted", JSON.stringify(v6));

  // dr7 — approve r1's aadhaarFront submission
  const rv1 = await R.reviewDocumentSubmissionCore(db, "adminUid", "sub-r1-aadhaarFront-1", true, null, copy, NOW);
  record("dr7_approved", rv1.kind === "approved", JSON.stringify(rv1));
  record("dr7_copy_called_with_live_path", copyLog.some((c) => c.src === staged1 && c.dest === "delivery_documents/r1/aadhaarFront"), JSON.stringify(copyLog));
  const partnerAfterApprove = await get("delivery_partners/r1");
  record("dr7_review_marked_approved", partnerAfterApprove.documentReview.aadhaarFront.status === "approved", JSON.stringify(partnerAfterApprove));
  record("dr7_pending_cleared_for_that_doc_only", partnerAfterApprove.documentReviewPending.aadhaarFront === undefined &&
    partnerAfterApprove.documentReviewPending.selfie === "sub-r1-selfie-1", JSON.stringify(partnerAfterApprove));
  const subAfterApprove = await get("document_review_submissions/sub-r1-aadhaarFront-1");
  record("dr7_submission_marked_approved", subAfterApprove.status === "approved" && subAfterApprove.reviewedBy === "adminUid", JSON.stringify(subAfterApprove));

  // dr8 — reject r1's selfie submission
  const copyCountBefore = copyLog.length;
  const rejectNoReason = await R.reviewDocumentSubmissionCore(db, "adminUid", "sub-r1-selfie-1", false, null, copy, NOW);
  record("dr8_reject_without_reason_refused", rejectNoReason.kind === "refused" && rejectNoReason.reason === "reason_required", JSON.stringify(rejectNoReason));
  const rv8 = await R.reviewDocumentSubmissionCore(db, "adminUid", "sub-r1-selfie-1", false, "Photo is blurry", copy, NOW);
  record("dr8_rejected", rv8.kind === "rejected", JSON.stringify(rv8));
  record("dr8_copy_not_called_on_reject", copyLog.length === copyCountBefore, JSON.stringify(copyLog));
  const partnerAfterReject = await get("delivery_partners/r1");
  record("dr8_rejection_reason_recorded", partnerAfterReject.documentReview.selfie.status === "rejected" &&
    partnerAfterReject.documentReview.selfie.rejectionReason === "Photo is blurry", JSON.stringify(partnerAfterReject));

  // dr9
  const reviewAgain = await R.reviewDocumentSubmissionCore(db, "adminUid", "sub-r1-aadhaarFront-1", true, null, copy, NOW);
  record("dr9_already_reviewed_refused", reviewAgain.kind === "refused" && reviewAgain.reason === "not_pending", JSON.stringify(reviewAgain));

  // dr10
  const reviewMissing = await R.reviewDocumentSubmissionCore(db, "adminUid", "nonexistent-id", true, null, copy, NOW);
  record("dr10_missing_refused", reviewMissing.kind === "refused" && reviewMissing.reason === "not_found", JSON.stringify(reviewMissing));

  // dr11 — aadhaarFront was approved (no longer pending); a new submission for it now succeeds
  const staged11 = R.stagingPath("r1", "sub-r1-aadhaarFront-3");
  const v11 = await R.submitDocumentReplacementCore(db, "r1", { docType: "aadhaarFront", submissionId: "sub-r1-aadhaarFront-3" }, fakeLookup(new Set([staged11])), NOW);
  record("dr11_resubmission_after_decision_accepted", v11.kind === "submitted", JSON.stringify(v11));

  // dr12
  const partnerFinal = await get("delivery_partners/r1");
  record("dr12_whole_application_status_untouched", partnerFinal.status === "approved", JSON.stringify(partnerFinal));
  record("dr12_kycDocuments_field_untouched_by_rules_engine", partnerFinal.kycDocuments.aadhaarFront === "delivery_documents/r1/aadhaarFront", JSON.stringify(partnerFinal));

  // dr13
  const staged13 = R.stagingPath("ghost", "sub-ghost-selfie-1");
  const v13 = await R.submitDocumentReplacementCore(db, "ghost", { docType: "selfie", submissionId: "sub-ghost-selfie-1" }, fakeLookup(new Set([staged13])), NOW);
  record("dr13_not_a_rider_refused", v13.kind === "refused" && v13.reason === "not_a_rider", JSON.stringify(v13));

  const passed = results.filter(Boolean).length;
  console.log(`\n${passed}/${results.length} passed`);
  process.exit(passed === results.length ? 0 : 1);
}

main().catch((e) => { console.error(e); process.exit(1); });
