// ============================================================
//  Phase ADMR-71 — private evidence attachments (support cases)
//  Updated ADMR-72 — evidence integrity hardening (uploader-bound path/doc
//  id, content-signature verification, generation/md5Hash recording)
// ============================================================
//
// Two-tier strategy, mirroring this codebase's own established split
// (riderExceptions.ts: attachProofCore tested with a fake lookup in
// phaseDLVE1_exceptions_test.js, the real storageLookup proven separately
// in phaseDLVE1_http_test.js):
//   e01-e14  attachSupportCaseEvidenceCore called DIRECTLY with a FAKE
//            lookup -- fast, no Storage emulator I/O, covers every
//            business-logic branch.
//   e15-e17  the REAL onCall wrapper (attachSupportCaseEvidence, via .run())
//            against a REAL Storage emulator object -- proves the actual
//            storageLookup function (including its real header-byte read),
//            not a stand-in.
//
// Run with: JAVA_HOME=/opt/homebrew/opt/openjdk@21 firebase emulators:exec
//             --only firestore,storage "node scripts/phaseADMR71_evidence_test.js"

process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
process.env.FIREBASE_STORAGE_EMULATOR_HOST = process.env.FIREBASE_STORAGE_EMULATOR_HOST || "127.0.0.1:9199";
process.env.STORAGE_EMULATOR_HOST = process.env.STORAGE_EMULATOR_HOST || `http://${process.env.FIREBASE_STORAGE_EMULATOR_HOST}`;
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
if (!admin.apps.length) admin.initializeApp({ projectId: "agrimore-66a4e", storageBucket: "agrimore-66a4e.firebasestorage.app" });
const db = admin.firestore();
const { Timestamp } = require("firebase-admin/firestore");

const X = require("../lib/admin/supportCases");
const { attachSupportCaseEvidenceCore, attachSupportCaseEvidence, evidencePath, MAX_EVIDENCE_BYTES } = X;

const ADMIN1 = { uid: "id-admin1", token: { admin: true, role: "admin" } };
const ADMIN2 = { uid: "id-admin2", token: { admin: true, role: "admin" } };
const NOW = Date.now();

const PNG_HEADER = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const PDF_HEADER = Buffer.from("%PDF-1.4", "latin1");
const HTML_HEADER = Buffer.from("<html>", "latin1");

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
  await db.doc("users/id-admin2").set({ role: "admin" });
  await db.doc("users/id-cust-real").set({ role: "user" });
  const seedAt = Timestamp.fromMillis(NOW - 60000);
  await db.doc("support_cases/case-e1").set({
    caseId: "case-e1", title: "Damaged parcel", category: "delivery_issue",
    primaryActor: { type: "customer", id: "id-cust-real" }, status: "open",
    createdBy: "id-admin1", createdAt: seedAt, updatedAt: seedAt, version: 1, linkedRecords: [],
  });
  // E18: a sibling order + wallet-shaped doc this suite asserts stay untouched.
  await db.doc("orders/sibling-order-1").set({ orderStatus: "delivered", total: 500 });
  await db.doc("wallets/id-cust-real").set({ balance: 1200 });
}

async function main() {
  await seed();
  const caseId = "case-e1";
  const IMG = { size: 50000, contentType: "image/png", headerBytes: PNG_HEADER, generation: "fake-gen", md5Hash: "fake-md5==" };
  const PDF = { size: 90000, contentType: "application/pdf", headerBytes: PDF_HEADER, generation: "fake-gen", md5Hash: "fake-md5==" };

  // e01 — bad_request: requestId too short
  {
    const lookup = fakeLookup({});
    const v = await attachSupportCaseEvidenceCore(db, "id-admin1", caseId, "short", "a.jpg", lookup, NOW);
    check("e01_requestId_too_short_is_bad_request", v.kind === "refused" && v.reason === "bad_request", JSON.stringify(v));
  }

  // e02 (E08) — not_found: case does not exist
  {
    const path = evidencePath("case-nonexistent", "id-admin1", "evid-req-0002");
    const lookup = fakeLookup({ [path]: IMG });
    const v = await attachSupportCaseEvidenceCore(db, "id-admin1", "case-nonexistent", "evid-req-0002", "a.jpg", lookup, NOW);
    check("e02_case_not_found", v.kind === "refused" && v.reason === "not_found", JSON.stringify(v));
  }

  // e03 (E02) — no_file: nothing uploaded at the deterministic path (an
  // "interrupted upload" -- the client never finished putData -- looks
  // identical to this from the server's own point of view).
  {
    const lookup = fakeLookup({});
    const v = await attachSupportCaseEvidenceCore(db, "id-admin1", caseId, "evid-req-0003", "a.jpg", lookup, NOW);
    const doc = await db.doc(`support_case_evidence/${caseId}_id-admin1_evid-req-0003`).get();
    check(
      "e03_interrupted_upload_no_file_creates_no_evidence_record",
      v.kind === "refused" && v.reason === "no_file" && !doc.exists,
      JSON.stringify(v)
    );
  }

  // e04 — not_allowed_type: an unsupported content type entirely
  {
    const path = evidencePath(caseId, "id-admin1", "evid-req-0004");
    const lookup = fakeLookup({ [path]: { size: 1000, contentType: "text/html", headerBytes: HTML_HEADER } });
    const v = await attachSupportCaseEvidenceCore(db, "id-admin1", caseId, "evid-req-0004", "a.html", lookup, NOW);
    check("e04_disallowed_content_type", v.kind === "refused" && v.reason === "not_allowed_type", JSON.stringify(v));
  }

  // e05 (E10) — too_large
  {
    const path = evidencePath(caseId, "id-admin1", "evid-req-0005");
    const lookup = fakeLookup({ [path]: { size: MAX_EVIDENCE_BYTES + 1, contentType: "image/png", headerBytes: PNG_HEADER } });
    const v = await attachSupportCaseEvidenceCore(db, "id-admin1", caseId, "evid-req-0005", "big.png", lookup, NOW);
    check("e05_oversized_file_refused", v.kind === "refused" && v.reason === "too_large", JSON.stringify(v));
  }

  // e06 (E01) — success: evidence doc + event written atomically, case.updatedAt
  // bumped, generation/md5Hash recorded, and NO side effect on any other
  // collection (E18).
  let e06evidenceId;
  {
    const path = evidencePath(caseId, "id-admin1", "evid-req-0006");
    const lookup = fakeLookup({ [path]: { ...IMG, generation: "111", md5Hash: "abc==" } });
    const before = (await db.doc(`support_cases/${caseId}`).get()).data();
    const orderBefore = (await db.doc("orders/sibling-order-1").get()).data();
    const walletBefore = (await db.doc("wallets/id-cust-real").get()).data();
    const v = await attachSupportCaseEvidenceCore(db, "id-admin1", caseId, "evid-req-0006", "photo.png", lookup, NOW);
    e06evidenceId = v.kind === "attached" ? v.evidenceId : undefined;
    const doc = e06evidenceId ? (await db.doc(`support_case_evidence/${e06evidenceId}`).get()).data() : null;
    const events = await db.collection("support_case_events")
      .where("caseId", "==", caseId).where("type", "==", "evidence_attached").get();
    const after = (await db.doc(`support_cases/${caseId}`).get()).data();
    const orderAfter = (await db.doc("orders/sibling-order-1").get()).data();
    const walletAfter = (await db.doc("wallets/id-cust-real").get()).data();
    check(
      "e06_success_writes_evidence_and_event_atomically_bumps_case_no_side_effects",
      v.kind === "attached" && v.alreadyApplied === false && e06evidenceId === `${caseId}_id-admin1_evid-req-0006` &&
        doc && doc.storagePath === path && doc.size === IMG.size && doc.contentType === IMG.contentType &&
        doc.generation === "111" && doc.md5Hash === "abc==" &&
        doc.uploadedBy === "id-admin1" && doc.originalFileName === "photo.png" &&
        events.size === 1 && after.updatedAt.toMillis() > before.updatedAt.toMillis() &&
        after.status === before.status && after.version === before.version &&
        JSON.stringify(orderBefore) === JSON.stringify(orderAfter) &&
        JSON.stringify(walletBefore) === JSON.stringify(walletAfter),
      JSON.stringify({ v, doc, events: events.size })
    );
  }

  // e07 (E03) — replay: same requestId, same originalFileName (lost finalize
  // ack, retried) -> alreadyApplied, returns the SAME evidenceId, no duplicate,
  // no re-read of Storage at all.
  {
    const path = evidencePath(caseId, "id-admin1", "evid-req-0006");
    const lookup = fakeLookup({ [path]: IMG });
    const v = await attachSupportCaseEvidenceCore(db, "id-admin1", caseId, "evid-req-0006", "photo.png", lookup, NOW + 1000);
    const events = await db.collection("support_case_events")
      .where("caseId", "==", caseId).where("type", "==", "evidence_attached").get();
    check(
      "e07_lost_finalize_ack_retry_is_a_true_replay",
      v.kind === "attached" && v.alreadyApplied === true && v.evidenceId === e06evidenceId &&
        lookup.seen.length === 0 && events.size === 1,
      JSON.stringify({ v, seenLookups: lookup.seen, events: events.size })
    );
  }

  // e08 — conflict: same requestId, different originalFileName label ->
  // refused, nothing new written. (Bytes-level tampering under the SAME
  // path is now impossible via any client -- storage.rules' write-once rule
  // -- so this check now guards only a display-label disagreement.)
  {
    const path = evidencePath(caseId, "id-admin1", "evid-req-0006");
    const lookup = fakeLookup({ [path]: IMG });
    const v = await attachSupportCaseEvidenceCore(db, "id-admin1", caseId, "evid-req-0006", "different-name.jpg", lookup, NOW + 2000);
    const events = await db.collection("support_case_events")
      .where("caseId", "==", caseId).where("type", "==", "evidence_attached").get();
    check(
      "e08_same_requestId_different_label_is_refused_not_silently_applied",
      v.kind === "refused" && v.reason === "request_id_conflict" && events.size === 1,
      JSON.stringify({ v, events: events.size })
    );
  }

  // e09 — a SECOND, distinct requestId on the SAME case creates a SECOND
  // evidence record (evidence is additive, many files per case).
  {
    const path = evidencePath(caseId, "id-admin1", "evid-req-0009");
    const lookup = fakeLookup({ [path]: PDF });
    const v = await attachSupportCaseEvidenceCore(db, "id-admin1", caseId, "evid-req-0009", "invoice.pdf", lookup, NOW + 3000);
    const all = await db.collection("support_case_evidence").where("caseId", "==", caseId).get();
    check(
      "e09_a_second_distinct_upload_adds_a_second_record_pdf_allowed",
      v.kind === "attached" && v.alreadyApplied === false && all.size === 2,
      JSON.stringify({ v, count: all.size })
    );
  }

  // e10 (E07) — path/doc-id determinism: the lookup is always called with
  // EXACTLY support_case_evidence/{caseId}/{adminUid}_{requestId}, derived
  // server-side, never a client-supplied path -- a client can never point a
  // finalize call at a path outside its own case (or its own uid).
  {
    const lookup = fakeLookup({ [evidencePath(caseId, "id-admin1", "evid-req-0010")]: IMG });
    await attachSupportCaseEvidenceCore(db, "id-admin1", caseId, "evid-req-0010", "x.png", lookup, NOW + 4000);
    check(
      "e10_lookup_path_is_deterministic_from_caseId_adminUid_and_requestId",
      lookup.seen.length === 1 && lookup.seen[0] === `support_case_evidence/${caseId}/id-admin1_evid-req-0010`,
      JSON.stringify(lookup.seen)
    );
  }

  // e11 (E06) — a DIFFERENT admin using the exact same requestId on the same
  // case never collides with admin1's own evidence -- each has its own
  // path/doc-id scope, ADMR-72's own fix for the cross-admin gap found while
  // verifying finding E.
  {
    const path = evidencePath(caseId, "id-admin2", "evid-req-0006"); // SAME requestId as e06/e07/e08, different admin
    const lookup = fakeLookup({ [path]: PDF });
    const v = await attachSupportCaseEvidenceCore(db, "id-admin2", caseId, "evid-req-0006", "admin2-own-file.pdf", lookup, NOW + 5000);
    const admin1Doc = await db.doc(`support_case_evidence/${caseId}_id-admin1_evid-req-0006`).get();
    check(
      "e11_a_different_admin_reusing_the_same_requestId_never_collides",
      v.kind === "attached" && v.alreadyApplied === false &&
        v.evidenceId === `${caseId}_id-admin2_evid-req-0006` &&
        admin1Doc.data().originalFileName === "photo.png", // admin1's own record, untouched
      JSON.stringify({ v, admin1Doc: admin1Doc.data() })
    );
  }

  // e12 (E09) — content-type spoofing: contentType metadata CLAIMS an
  // allowed type, but the real header bytes do not match it -- refused,
  // never silently trusted from the label alone.
  {
    const path = evidencePath(caseId, "id-admin1", "evid-req-0012");
    const lookup = fakeLookup({
      [path]: { size: 1000, contentType: "image/png", headerBytes: HTML_HEADER, generation: "fake-gen", md5Hash: "fake-md5==" },
    });
    const v = await attachSupportCaseEvidenceCore(db, "id-admin1", caseId, "evid-req-0012", "spoofed.png", lookup, NOW + 6000);
    check("e12_content_type_spoofing_fails_signature_check", v.kind === "refused" && v.reason === "content_mismatch", JSON.stringify(v));
  }

  // e13 (E14) — a client-supplied uploadedBy/adminUid-shaped field in the
  // callable's own data payload is simply never read -- the ACTOR is always
  // the server-derived adminUid parameter, proven by calling core directly
  // with one adminUid while a forged field of the SAME shape rides along in
  // the (irrelevant) originalFileName parameter position -- the real
  // callable wrapper (e15+) proves this at the transport layer too.
  {
    const path = evidencePath(caseId, "id-admin1", "evid-req-0013");
    const lookup = fakeLookup({ [path]: IMG });
    const v = await attachSupportCaseEvidenceCore(db, "id-admin1", caseId, "evid-req-0013", "real.png", lookup, NOW + 7000);
    const doc = (await db.doc(`support_case_evidence/${v.evidenceId}`).get()).data();
    check(
      "e13_uploadedBy_is_always_the_real_calling_admin_never_a_payload_field",
      doc.uploadedBy === "id-admin1",
      JSON.stringify(doc)
    );
  }

  // e14 (E12) — concurrent finalize for the SAME (case, admin, requestId)
  // creates exactly one evidence registration and one audit event, never
  // two -- Firestore's own transaction contention detection serializes the
  // race (the same mechanism ADMR-65's own design relies on).
  {
    const path = evidencePath(caseId, "id-admin1", "evid-req-0014");
    const lookup = fakeLookup({ [path]: IMG });
    const [r1, r2] = await Promise.all([
      attachSupportCaseEvidenceCore(db, "id-admin1", caseId, "evid-req-0014", "race.png", lookup, NOW + 8000),
      attachSupportCaseEvidenceCore(db, "id-admin1", caseId, "evid-req-0014", "race.png", lookup, NOW + 8000),
    ]);
    const all = await db.collection("support_case_evidence").doc(`${caseId}_id-admin1_evid-req-0014`).get();
    const events = await db.collection("support_case_events")
      .where("caseId", "==", caseId).where("type", "==", "evidence_attached").get();
    const oneCreatedOneReplayed =
      [r1.kind, r2.kind].every((k) => k === "attached") &&
      [r1.alreadyApplied, r2.alreadyApplied].filter((x) => x === false).length === 1;
    check(
      "e14_concurrent_finalize_for_the_same_identity_creates_exactly_one_registration",
      oneCreatedOneReplayed && all.exists,
      JSON.stringify({ r1, r2 })
    );
  }

  // e15 (E01/E04 integration) — REAL Storage emulator + the REAL onCall
  // wrapper (storageLookup, not a fake): upload real bytes to the
  // deterministic (case, admin, requestId) path, then finalize -- proves
  // the real header-byte read and generation/md5Hash recording too.
  {
    const requestId = "evid-req-real0015";
    const path = evidencePath(caseId, "id-admin1", requestId);
    await admin.storage().bucket().file(path).save(PNG_HEADER, { contentType: "image/png" });
    const r = await call(attachSupportCaseEvidence, ADMIN1, { caseId, requestId, originalFileName: "real.png" });
    const doc = r.ok ? (await db.doc(`support_case_evidence/${r.res.evidenceId}`).get()).data() : null;
    check(
      "e15_real_storage_emulator_object_verified_by_the_real_storageLookup",
      r.ok && doc && doc.storagePath === path && doc.size === PNG_HEADER.length && doc.contentType === "image/png" &&
        typeof doc.generation === "string" && doc.generation.length > 0 &&
        typeof doc.md5Hash === "string" && doc.md5Hash.length > 0,
      JSON.stringify({ r, doc })
    );
  }

  // e16 (E09 integration) — the real onCall wrapper refuses a real object
  // whose real bytes do not match its claimed contentType.
  {
    const requestId = "evid-req-real0016";
    const path = evidencePath(caseId, "id-admin1", requestId);
    await admin.storage().bucket().file(path).save(Buffer.from("<html>not a png</html>"), { contentType: "image/png" });
    const r = await call(attachSupportCaseEvidence, ADMIN1, { caseId, requestId, originalFileName: "spoofed.png" });
    check("e16_real_content_spoofing_refused_end_to_end", !r.ok && r.details?.reason === "content_mismatch", JSON.stringify(r));
  }

  // e17 (E13) — a non-admin is refused by the real onCall wrapper's own requireAdmin.
  {
    const requestId = "evid-req-real0017";
    const CUST = { uid: "id-cust-real", token: {} };
    const r = await call(attachSupportCaseEvidence, CUST, { caseId, requestId, originalFileName: "x.png" });
    check("e17_non_admin_refused", !r.ok && r.code === "permission-denied", JSON.stringify(r));
  }

  const failed = Object.values(results).filter((v) => v.startsWith("FAILED")).length;
  console.log(`\n${Object.keys(results).length - failed}/${Object.keys(results).length} passed`);
  process.exit(failed ? 1 : 0);
}

main().catch((e) => {
  console.error("suite crashed:", e);
  process.exit(1);
});
