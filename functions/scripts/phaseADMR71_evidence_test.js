// ============================================================
//  Phase ADMR-71 — private evidence attachments (support cases)
// ============================================================
//
// Two-tier strategy, mirroring this codebase's own established split
// (riderExceptions.ts: attachProofCore tested with a fake lookup in
// phaseDLVE1_exceptions_test.js, the real storageLookup proven separately
// in phaseDLVE1_http_test.js):
//   e01-e10  attachSupportCaseEvidenceCore called DIRECTLY with a FAKE
//            lookup -- fast, no Storage emulator I/O, covers every
//            business-logic branch (bad request, not found, no file, wrong
//            type, too large, success, replay, conflict, path determinism).
//   e11-e12  the REAL onCall wrapper (attachSupportCaseEvidence, via .run())
//            against a REAL Storage emulator object -- proves the actual
//            storageLookup function, not a stand-in, and that a non-admin
//            is refused.
//
// Run with: JAVA_HOME=/opt/homebrew/opt/openjdk@21 firebase emulators:exec
//             --only firestore,storage "node scripts/phaseADMR71_evidence_test.js"

process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
process.env.FIREBASE_STORAGE_EMULATOR_HOST = process.env.FIREBASE_STORAGE_EMULATOR_HOST || "127.0.0.1:9199";
process.env.STORAGE_EMULATOR_HOST = process.env.STORAGE_EMULATOR_HOST || `http://${process.env.FIREBASE_STORAGE_EMULATOR_HOST}`;
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
if (!admin.apps.length) admin.initializeApp({ projectId: "agrimore-66a4e", storageBucket: "agrimore-66a4e.appspot.com" });
const db = admin.firestore();
const { Timestamp } = require("firebase-admin/firestore");

const X = require("../lib/admin/supportCases");
const { attachSupportCaseEvidenceCore, attachSupportCaseEvidence, evidencePath, MAX_EVIDENCE_BYTES } = X;

const ADMIN1 = { uid: "id-admin1", token: { admin: true, role: "admin" } };
const NOW = Date.now();

const results = {};
const check = (k, ok, detail) => {
  results[k] = ok ? "PASSED" : `FAILED — ${detail}`;
  console.log(`${k}: ${ok ? "PASSED" : "FAILED"}${ok ? "" : ` — ${detail}`}`);
};

async function call(fn, auth, data) {
  try {
    return { ok: true, res: await fn.run({ auth, data }) };
  } catch (e) {
    return { ok: false, code: e.code, message: e.message, details: e.details };
  }
}

function fakeLookup(map) {
  const seen = [];
  const fn = async (path) => {
    seen.push(path);
    return Object.prototype.hasOwnProperty.call(map, path) ? map[path] : null;
  };
  fn.seen = seen;
  return fn;
}

async function seed() {
  await db.doc("users/id-admin1").set({ role: "admin" });
  await db.doc("users/id-cust-real").set({ role: "user" });
  const seedAt = Timestamp.fromMillis(NOW - 60000);
  await db.doc("support_cases/case-e1").set({
    caseId: "case-e1", title: "Damaged parcel", category: "delivery_issue",
    primaryActor: { type: "customer", id: "id-cust-real" }, status: "open",
    createdBy: "id-admin1", createdAt: seedAt, updatedAt: seedAt, version: 1, linkedRecords: [],
  });
}

async function main() {
  await seed();
  const caseId = "case-e1";
  const IMG = { size: 50000, contentType: "image/jpeg" };
  const PDF = { size: 90000, contentType: "application/pdf" };

  // e01 — bad_request: requestId too short
  {
    const lookup = fakeLookup({});
    const v = await attachSupportCaseEvidenceCore(db, "id-admin1", caseId, "short", "a.jpg", lookup, NOW);
    check("e01_requestId_too_short_is_bad_request", v.kind === "refused" && v.reason === "bad_request", JSON.stringify(v));
  }

  // e02 — not_found: case does not exist
  {
    const path = evidencePath("case-nonexistent", "evid-req-0002");
    const lookup = fakeLookup({ [path]: IMG });
    const v = await attachSupportCaseEvidenceCore(db, "id-admin1", "case-nonexistent", "evid-req-0002", "a.jpg", lookup, NOW);
    check("e02_case_not_found", v.kind === "refused" && v.reason === "not_found", JSON.stringify(v));
  }

  // e03 — no_file: nothing uploaded at the deterministic path
  {
    const lookup = fakeLookup({});
    const v = await attachSupportCaseEvidenceCore(db, "id-admin1", caseId, "evid-req-0003", "a.jpg", lookup, NOW);
    check("e03_no_file_uploaded_yet", v.kind === "refused" && v.reason === "no_file", JSON.stringify(v));
  }

  // e04 — not_allowed_type
  {
    const path = evidencePath(caseId, "evid-req-0004");
    const lookup = fakeLookup({ [path]: { size: 1000, contentType: "text/html" } });
    const v = await attachSupportCaseEvidenceCore(db, "id-admin1", caseId, "evid-req-0004", "a.html", lookup, NOW);
    check("e04_disallowed_content_type", v.kind === "refused" && v.reason === "not_allowed_type", JSON.stringify(v));
  }

  // e05 — too_large
  {
    const path = evidencePath(caseId, "evid-req-0005");
    const lookup = fakeLookup({ [path]: { size: MAX_EVIDENCE_BYTES + 1, contentType: "image/png" } });
    const v = await attachSupportCaseEvidenceCore(db, "id-admin1", caseId, "evid-req-0005", "big.png", lookup, NOW);
    check("e05_oversized_file_refused", v.kind === "refused" && v.reason === "too_large", JSON.stringify(v));
  }

  // e06 — success: evidence doc + event written atomically, case.updatedAt bumped
  let e06evidenceId;
  {
    const path = evidencePath(caseId, "evid-req-0006");
    const lookup = fakeLookup({ [path]: IMG });
    const before = (await db.doc(`support_cases/${caseId}`).get()).data();
    const v = await attachSupportCaseEvidenceCore(db, "id-admin1", caseId, "evid-req-0006", "photo.jpg", lookup, NOW);
    e06evidenceId = v.kind === "attached" ? v.evidenceId : undefined;
    const doc = e06evidenceId ? (await db.doc(`support_case_evidence/${e06evidenceId}`).get()).data() : null;
    const events = await db.collection("support_case_events")
      .where("caseId", "==", caseId).where("type", "==", "evidence_attached").get();
    const after = (await db.doc(`support_cases/${caseId}`).get()).data();
    check(
      "e06_success_writes_evidence_and_event_atomically_bumps_case",
      v.kind === "attached" && v.alreadyApplied === false &&
        doc && doc.storagePath === path && doc.size === IMG.size && doc.contentType === IMG.contentType &&
        doc.uploadedBy === "id-admin1" && doc.originalFileName === "photo.jpg" &&
        events.size === 1 && after.updatedAt.toMillis() > before.updatedAt.toMillis(),
      JSON.stringify({ v, doc, events: events.size })
    );
  }

  // e07 — replay: same requestId, same originalFileName -> alreadyApplied, no duplicate
  {
    const path = evidencePath(caseId, "evid-req-0006");
    const lookup = fakeLookup({ [path]: IMG });
    const v = await attachSupportCaseEvidenceCore(db, "id-admin1", caseId, "evid-req-0006", "photo.jpg", lookup, NOW + 1000);
    const events = await db.collection("support_case_events")
      .where("caseId", "==", caseId).where("type", "==", "evidence_attached").get();
    check(
      "e07_same_requestId_same_payload_is_a_true_replay",
      v.kind === "attached" && v.alreadyApplied === true && v.evidenceId === e06evidenceId &&
        lookup.seen.length === 0 && events.size === 1,
      JSON.stringify({ v, seenLookups: lookup.seen, events: events.size })
    );
  }

  // e08 — conflict: same requestId, different originalFileName -> refused, nothing new written
  {
    const path = evidencePath(caseId, "evid-req-0006");
    const lookup = fakeLookup({ [path]: IMG });
    const v = await attachSupportCaseEvidenceCore(db, "id-admin1", caseId, "evid-req-0006", "different-name.jpg", lookup, NOW + 2000);
    const events = await db.collection("support_case_events")
      .where("caseId", "==", caseId).where("type", "==", "evidence_attached").get();
    check(
      "e08_same_requestId_different_payload_is_refused_not_silently_applied",
      v.kind === "refused" && v.reason === "request_id_conflict" && events.size === 1,
      JSON.stringify({ v, events: events.size })
    );
  }

  // e09 — a SECOND, distinct requestId on the SAME case creates a SECOND
  // evidence record (evidence is additive, many files per case).
  {
    const path = evidencePath(caseId, "evid-req-0009");
    const lookup = fakeLookup({ [path]: PDF });
    const v = await attachSupportCaseEvidenceCore(db, "id-admin1", caseId, "evid-req-0009", "invoice.pdf", lookup, NOW + 3000);
    const all = await db.collection("support_case_evidence").where("caseId", "==", caseId).get();
    check(
      "e09_a_second_distinct_upload_adds_a_second_record_pdf_allowed",
      v.kind === "attached" && v.alreadyApplied === false && all.size === 2,
      JSON.stringify({ v, count: all.size })
    );
  }

  // e10 — path determinism: the lookup is always called with EXACTLY
  // support_case_evidence/{caseId}/{requestId}, derived server-side, never
  // a client-supplied path -- the same closed-by-construction property
  // proofPath(orderId) gives delivery proofs.
  {
    const lookup = fakeLookup({ [evidencePath(caseId, "evid-req-0010")]: IMG });
    await attachSupportCaseEvidenceCore(db, "id-admin1", caseId, "evid-req-0010", "x.jpg", lookup, NOW + 4000);
    check(
      "e10_lookup_path_is_deterministic_from_caseId_and_requestId",
      lookup.seen.length === 1 && lookup.seen[0] === `support_case_evidence/${caseId}/evid-req-0010`,
      JSON.stringify(lookup.seen)
    );
  }

  // e11 — REAL Storage emulator + the REAL onCall wrapper (storageLookup,
  // not a fake): upload real bytes to the deterministic path, then finalize.
  {
    const requestId = "evid-req-real0011";
    const path = evidencePath(caseId, requestId);
    await admin.storage().bucket().file(path).save(Buffer.from([0x89, 0x50, 0x4e, 0x47]), { contentType: "image/png" });
    const r = await call(attachSupportCaseEvidence, ADMIN1, { caseId, requestId, originalFileName: "real.png" });
    const doc = r.ok ? (await db.doc(`support_case_evidence/${r.res.evidenceId}`).get()).data() : null;
    check(
      "e11_real_storage_emulator_object_verified_by_the_real_storageLookup",
      r.ok && doc && doc.storagePath === path && doc.size === 4 && doc.contentType === "image/png",
      JSON.stringify({ r, doc })
    );
  }

  // e12 — a non-admin is refused by the real onCall wrapper's own requireAdmin.
  {
    const requestId = "evid-req-real0012";
    const CUST = { uid: "id-cust-real", token: {} };
    const r = await call(attachSupportCaseEvidence, CUST, { caseId, requestId, originalFileName: "x.jpg" });
    check("e12_non_admin_refused", !r.ok && r.code === "permission-denied", JSON.stringify(r));
  }

  const failed = Object.values(results).filter((v) => v.startsWith("FAILED")).length;
  console.log(`\n${Object.keys(results).length - failed}/${Object.keys(results).length} passed`);
  process.exit(failed ? 1 : 0);
}

main().catch((e) => {
  console.error("suite crashed:", e);
  process.exit(1);
});
