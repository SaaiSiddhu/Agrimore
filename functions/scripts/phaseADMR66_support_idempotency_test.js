// ============================================================
//  Phase ADMR-66 — support-command idempotency + atomic audit events
// ============================================================
//
// Run with: JAVA_HOME=/opt/homebrew/opt/openjdk@21 firebase emulators:exec
//             --only firestore "node scripts/phaseADMR66_support_idempotency_test.js"

process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });
const db = admin.firestore();

const {
  createSupportCase, addSupportCaseNote, assignSupportCase, changeSupportCaseStatus,
  resolveSupportCase, reopenSupportCase, linkSupportCaseRecord, unlinkSupportCaseRecord,
} = require("../lib/admin/supportCases");

const ADMIN1 = { uid: "id-admin1", token: { admin: true, role: "admin" } };
const ADMIN2 = { uid: "id-admin2", token: { admin: true, role: "admin" } };

async function call(fn, auth, data) {
  try {
    return { ok: true, res: await fn.run({ auth, data }) };
  } catch (e) {
    return { ok: false, code: e.code, message: e.message, details: e.details };
  }
}

async function seed() {
  await db.doc("users/id-admin1").set({ role: "admin" });
  await db.doc("users/id-admin2").set({ role: "admin" });
  await db.doc("users/id-cust-real").set({ role: "user" });
}

async function casesMatching(requestId, adminUid) {
  // The deterministic id IS req_${adminUid}_${requestId} -- reading it back
  // directly is the simplest, most direct way to assert "exactly one case
  // exists for this identity," no query needed.
  const snap = await db.doc(`support_cases/req_${adminUid}_${requestId}`).get();
  return snap.exists ? [snap] : [];
}

async function eventsFor(caseId, type) {
  const snap = await db.collection("support_case_events")
    .where("caseId", "==", caseId).where("type", "==", type).get();
  return snap.docs;
}

async function main() {
  const results = {};
  const check = (k, ok, detail) => {
    results[k] = ok ? "PASSED" : `FAILED — ${detail}`;
    console.log(`${k}: ${ok ? "PASSED" : "FAILED"} — ${detail}`);
  };

  await seed();

  // ── createSupportCase idempotency ──
  {
    const r1 = await call(createSupportCase, ADMIN1, {
      title: "Late delivery", category: "delivery_issue",
      primaryActor: { type: "customer", id: "id-cust-real" }, requestId: "idem-create-01",
    });
    const r2 = await call(createSupportCase, ADMIN1, {
      title: "Late delivery", category: "delivery_issue",
      primaryActor: { type: "customer", id: "id-cust-real" }, requestId: "idem-create-01",
    });
    const matches = await casesMatching("idem-create-01", "id-admin1");
    const createdEvents = await eventsFor(r1.res.caseId, "created");
    check(
      "i01_same_requestId_same_payload_is_a_true_replay",
      r1.ok && r2.ok && !r1.res.alreadyApplied && r2.res.alreadyApplied === true &&
        r1.res.caseId === r2.res.caseId && matches.length === 1 && createdEvents.length === 1,
      JSON.stringify({ r1, r2, matches: matches.length, createdEvents: createdEvents.length })
    );
  }
  {
    const r1 = await call(createSupportCase, ADMIN1, {
      title: "Payment issue", category: "payment_issue",
      primaryActor: { type: "customer", id: "id-cust-real" }, requestId: "idem-create-02",
    });
    const r2 = await call(createSupportCase, ADMIN1, {
      title: "A completely different title", category: "payment_issue",
      primaryActor: { type: "customer", id: "id-cust-real" }, requestId: "idem-create-02",
    });
    const doc = (await db.doc(`support_cases/req_id-admin1_idem-create-02`).get()).data();
    check(
      "i02_same_requestId_different_payload_is_refused_not_silently_applied",
      r1.ok && !r2.ok && r2.code === "invalid-argument" && r2.details?.reason === "request_id_conflict" &&
        doc.title === "Payment issue",
      JSON.stringify({ r1, r2, doc })
    );
  }
  {
    const r1 = await call(createSupportCase, ADMIN1, {
      title: "Same title, different request", category: "c",
      primaryActor: { type: "customer", id: "id-cust-real" }, requestId: "idem-create-03a",
    });
    const r2 = await call(createSupportCase, ADMIN1, {
      title: "Same title, different request", category: "c",
      primaryActor: { type: "customer", id: "id-cust-real" }, requestId: "idem-create-03b",
    });
    check(
      "i03_different_requestId_is_a_genuinely_new_case_even_with_identical_text",
      r1.ok && r2.ok && r1.res.caseId !== r2.res.caseId,
      JSON.stringify({ r1, r2 })
    );
  }
  {
    const r1 = await call(createSupportCase, ADMIN1, {
      title: "Admin one's case", category: "c",
      primaryActor: { type: "customer", id: "id-cust-real" }, requestId: "idem-create-shared",
    });
    const r2 = await call(createSupportCase, ADMIN2, {
      title: "Admin two's case", category: "c",
      primaryActor: { type: "customer", id: "id-cust-real" }, requestId: "idem-create-shared",
    });
    check(
      "i04_same_requestId_used_by_a_different_admin_never_collides",
      r1.ok && r2.ok && r1.res.caseId !== r2.res.caseId &&
        r1.res.caseId === "req_id-admin1_idem-create-shared" &&
        r2.res.caseId === "req_id-admin2_idem-create-shared",
      JSON.stringify({ r1, r2 })
    );
  }
  {
    const r = await call(createSupportCase, ADMIN1, {
      title: "t", category: "c", primaryActor: { type: "customer", id: "id-cust-real" }, requestId: "short",
    });
    check("i05_malformed_requestId_refused", !r.ok && r.details?.reason === "bad_request", JSON.stringify(r));
  }

  // ── addSupportCaseNote idempotency ──
  let noteCaseId;
  {
    const created = await call(createSupportCase, ADMIN1, {
      title: "Notes idempotency", category: "c",
      primaryActor: { type: "customer", id: "id-cust-real" }, requestId: "idem-notes-base",
    });
    noteCaseId = created.res.caseId;
    const r1 = await call(addSupportCaseNote, ADMIN1, { caseId: noteCaseId, text: "Called back.", requestId: "idem-note-01" });
    const r2 = await call(addSupportCaseNote, ADMIN1, { caseId: noteCaseId, text: "Called back.", requestId: "idem-note-01" });
    const notes = await db.collection("support_case_notes").where("caseId", "==", noteCaseId).get();
    const noteAddedEvents = await eventsFor(noteCaseId, "note_added");
    check(
      "i06_same_requestId_same_text_is_a_true_replay",
      r1.ok && r2.ok && !r1.res.alreadyApplied && r2.res.alreadyApplied === true &&
        r1.res.noteId === r2.res.noteId && notes.size === 1 && noteAddedEvents.length === 1,
      JSON.stringify({ r1, r2, notes: notes.size, noteAddedEvents: noteAddedEvents.length })
    );
  }
  {
    const r1 = await call(addSupportCaseNote, ADMIN1, { caseId: noteCaseId, text: "First version.", requestId: "idem-note-02" });
    const r2 = await call(addSupportCaseNote, ADMIN1, { caseId: noteCaseId, text: "Edited version.", requestId: "idem-note-02" });
    const note = (await db.doc(`support_case_notes/${noteCaseId}_idem-note-02`).get()).data();
    check(
      "i07_same_requestId_different_text_is_refused_not_silently_applied",
      r1.ok && !r2.ok && r2.code === "invalid-argument" && r2.details?.reason === "request_id_conflict" &&
        note.text === "First version.",
      JSON.stringify({ r1, r2, note })
    );
  }
  {
    // A note's own requestId is scoped by caseId, not adminUid -- two
    // DIFFERENT cases reusing the same literal requestId string must not
    // collide with each other either.
    const otherCase = await call(createSupportCase, ADMIN1, {
      title: "A second case", category: "c",
      primaryActor: { type: "customer", id: "id-cust-real" }, requestId: "idem-notes-other",
    });
    const r1 = await call(addSupportCaseNote, ADMIN1, { caseId: noteCaseId, text: "Note on case A.", requestId: "idem-note-shared" });
    const r2 = await call(addSupportCaseNote, ADMIN1, { caseId: otherCase.res.caseId, text: "Note on case B.", requestId: "idem-note-shared" });
    check(
      "i08_same_requestId_on_a_different_case_never_collides",
      r1.ok && r2.ok && r1.res.noteId !== r2.res.noteId,
      JSON.stringify({ r1, r2 })
    );
  }

  // ── version semantics: a note never invalidates a concurrent status edit ──
  {
    const created = await call(createSupportCase, ADMIN1, {
      title: "Version semantics", category: "c",
      primaryActor: { type: "customer", id: "id-cust-real" }, requestId: "idem-version-sem",
    });
    const caseId = created.res.caseId; // version 1
    // A note is added -- this must NOT bump `version`, so a status-change
    // still captured at version 1 (before the note) succeeds cleanly.
    await call(addSupportCaseNote, ADMIN1, { caseId, text: "A concurrent note.", requestId: "idem-version-note" });
    const statusChange = await call(changeSupportCaseStatus, ADMIN1, {
      caseId, status: "in_progress", expectedVersion: 1,
    });
    const doc = (await db.doc(`support_cases/${caseId}`).get()).data();
    check(
      "i09_a_note_never_bumps_version_so_it_cannot_invalidate_a_concurrent_status_edit",
      statusChange.ok && doc.status === "in_progress" && doc.version === 2,
      JSON.stringify({ statusChange, doc })
    );
  }

  // ── atomic mutation + event: a broad sample across every command type ──
  {
    const created = await call(createSupportCase, ADMIN1, {
      title: "Atomicity sample", category: "c",
      primaryActor: { type: "customer", id: "id-cust-real" }, requestId: "idem-atomic-sample",
    });
    const caseId = created.res.caseId;
    await call(assignSupportCase, ADMIN1, { caseId, assigneeUid: "id-admin1", expectedVersion: 1 });
    await call(linkSupportCaseRecord, ADMIN1, {
      caseId, link: { type: "user", id: "id-cust-real" }, expectedVersion: 2,
    });
    await call(unlinkSupportCaseRecord, ADMIN1, {
      caseId, link: { type: "user", id: "id-cust-real" }, expectedVersion: 3,
    });
    await call(resolveSupportCase, ADMIN1, { caseId, resolutionSummary: "Resolved for the sample.", expectedVersion: 4 });
    await call(reopenSupportCase, ADMIN1, { caseId, reason: "Reopened for the sample.", expectedVersion: 5 });
    const events = await db.collection("support_case_events").where("caseId", "==", caseId).get();
    const types = events.docs.map((d) => d.data().type).sort();
    check(
      "a01_every_command_type_produces_exactly_one_event_each",
      JSON.stringify(types) === JSON.stringify(
        ["assigned", "created", "link_added", "link_removed", "reopened", "resolved"].sort()
      ),
      JSON.stringify(types)
    );
  }

  const failed = Object.entries(results).filter(([, v]) => v !== "PASSED");
  console.log(`\n${Object.keys(results).length - failed.length}/${Object.keys(results).length} scenarios passed`);
  if (failed.length) {
    console.log("FAILURES:", failed.map(([k]) => k).join(", "));
    console.log("PHASE ADMR-66 (idempotency): FAILED");
    process.exitCode = 1;
  } else {
    console.log("PHASE ADMR-66 (idempotency): ALL PASSED");
  }
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
