// ============================================================
//  Phase ADMR-70 — authorization audit, callable layer
// ============================================================
//
// ADMR-61's own H14 test already proves createSupportCaseCore's
// createdBy cannot be forged via the payload. This extends the SAME
// proof to the other six commands -- each passes a forged, extraneous
// actor-identity-shaped field alongside its real payload and confirms
// the resulting audit trail still shows the REAL caller, never the
// forged value. Also proves directly (not just architecturally) that
// unlinking a record never touches that record's own document.
//
// Run with: JAVA_HOME=/opt/homebrew/opt/openjdk@21 firebase emulators:exec
//             --only firestore "node scripts/phaseADMR70_authorization_audit_test.js"

process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });
const db = admin.firestore();

const {
  createSupportCase, assignSupportCase, changeSupportCaseStatus, addSupportCaseNote,
  resolveSupportCase, reopenSupportCase, linkSupportCaseRecord, unlinkSupportCaseRecord,
} = require("../lib/admin/supportCases");

const REAL_ADMIN = { uid: "aud-admin-real", token: { admin: true, role: "admin" } };
const FORGED_UID = "aud-attacker-uid";

async function call(fn, auth, data) {
  try {
    return { ok: true, res: await fn.run({ auth, data }) };
  } catch (e) {
    return { ok: false, code: e.code, message: e.message, details: e.details };
  }
}

async function seed() {
  await db.doc("users/aud-admin-real").set({ role: "admin" });
  await db.doc("users/aud-cust-real").set({ role: "user" });
  await db.doc("orders/aud-order-real").set({ orderNumber: "ORD-AUD1", status: "delivered" });
}

async function eventsFor(caseId, type) {
  const snap = await db.collection("support_case_events").where("caseId", "==", caseId).where("type", "==", type).get();
  return snap.docs.map((d) => d.data());
}

async function newCase(requestId) {
  const r = await call(createSupportCase, REAL_ADMIN, {
    title: "audit base case", category: "c",
    primaryActor: { type: "customer", id: "aud-cust-real" }, requestId,
  });
  return r.res.caseId;
}

async function main() {
  const results = {};
  const check = (k, ok, detail) => {
    results[k] = ok ? "PASSED" : `FAILED — ${detail}`;
    console.log(`${k}: ${ok ? "PASSED" : "FAILED"} — ${detail}`);
  };

  await seed();

  // ── fa01: assign ──
  {
    const caseId = await newCase("audit-req-fa01");
    await call(assignSupportCase, REAL_ADMIN, {
      caseId, assigneeUid: "aud-admin-real", expectedVersion: 1,
      actorUid: FORGED_UID, performedBy: FORGED_UID, // forged, extraneous
    });
    const events = await eventsFor(caseId, "assigned");
    check(
      "fa01_assign_event_actor_cannot_be_forged",
      events.length === 1 && events[0].actorUid === "aud-admin-real",
      JSON.stringify(events)
    );
  }

  // ── fa02: changeStatus ──
  {
    const caseId = await newCase("audit-req-fa02");
    await call(changeSupportCaseStatus, REAL_ADMIN, {
      caseId, status: "in_progress", expectedVersion: 1,
      actorUid: FORGED_UID,
    });
    const events = await eventsFor(caseId, "status_changed");
    check(
      "fa02_status_change_event_actor_cannot_be_forged",
      events.length === 1 && events[0].actorUid === "aud-admin-real",
      JSON.stringify(events)
    );
  }

  // ── fa03: addNote ──
  {
    const caseId = await newCase("audit-req-fa03");
    const r = await call(addSupportCaseNote, REAL_ADMIN, {
      caseId, text: "a real note", requestId: "audit-note-fa03",
      authorUid: FORGED_UID,
    });
    const note = (await db.doc(`support_case_notes/${caseId}_audit-note-fa03`).get()).data();
    const events = await eventsFor(caseId, "note_added");
    check(
      "fa03_note_author_and_event_actor_cannot_be_forged",
      r.ok && note.authorUid === "aud-admin-real" && events.length === 1 && events[0].actorUid === "aud-admin-real",
      JSON.stringify({ note, events })
    );
  }

  // ── fa04: resolve ──
  {
    const caseId = await newCase("audit-req-fa04");
    await call(resolveSupportCase, REAL_ADMIN, {
      caseId, resolutionSummary: "Fixed it.", expectedVersion: 1,
      resolvedBy: FORGED_UID,
    });
    const doc = (await db.doc(`support_cases/${caseId}`).get()).data();
    const events = await eventsFor(caseId, "resolved");
    check(
      "fa04_resolvedBy_and_event_actor_cannot_be_forged",
      doc.resolvedBy === "aud-admin-real" && events.length === 1 && events[0].actorUid === "aud-admin-real",
      JSON.stringify({ resolvedBy: doc.resolvedBy, events })
    );
  }

  // ── fa05: reopen ──
  {
    const caseId = await newCase("audit-req-fa05");
    const resolved = await call(resolveSupportCase, REAL_ADMIN, {
      caseId, resolutionSummary: "Resolved for the audit.", expectedVersion: 1,
    });
    if (!resolved.ok) throw new Error(`fa05 setup: resolve failed unexpectedly: ${JSON.stringify(resolved)}`);
    await call(reopenSupportCase, REAL_ADMIN, {
      caseId, reason: "Customer disputes this.", expectedVersion: 2,
      reopenedBy: FORGED_UID,
    });
    const doc = (await db.doc(`support_cases/${caseId}`).get()).data();
    const events = await eventsFor(caseId, "reopened");
    check(
      "fa05_reopenedBy_and_event_actor_cannot_be_forged",
      doc.reopenedBy === "aud-admin-real" && events.length === 1 && events[0].actorUid === "aud-admin-real",
      JSON.stringify({ reopenedBy: doc.reopenedBy, events })
    );
  }

  // ── fa06: link ──
  {
    const caseId = await newCase("audit-req-fa06");
    await call(linkSupportCaseRecord, REAL_ADMIN, {
      caseId, link: { type: "order", id: "aud-order-real" }, expectedVersion: 1,
      actorUid: FORGED_UID,
    });
    const events = await eventsFor(caseId, "link_added");
    check(
      "fa06_link_event_actor_cannot_be_forged",
      events.length === 1 && events[0].actorUid === "aud-admin-real",
      JSON.stringify(events)
    );
  }

  // ── fa07: unlink -- forged actor AND the source record itself untouched ──
  {
    const caseId = await newCase("audit-req-fa07");
    await call(linkSupportCaseRecord, REAL_ADMIN, {
      caseId, link: { type: "order", id: "aud-order-real" }, expectedVersion: 1,
    });
    const orderBefore = (await db.doc("orders/aud-order-real").get()).data();

    await call(unlinkSupportCaseRecord, REAL_ADMIN, {
      caseId, link: { type: "order", id: "aud-order-real" }, expectedVersion: 2,
      actorUid: FORGED_UID,
    });

    const orderAfter = (await db.doc("orders/aud-order-real").get()).data();
    const events = await eventsFor(caseId, "link_removed");
    check(
      "fa07_unlink_event_actor_cannot_be_forged_and_the_source_record_itself_is_completely_untouched",
      events.length === 1 && events[0].actorUid === "aud-admin-real" &&
        JSON.stringify(orderBefore) === JSON.stringify(orderAfter),
      JSON.stringify({ events, orderBefore, orderAfter })
    );
  }

  const failed = Object.entries(results).filter(([, v]) => v !== "PASSED");
  console.log(`\n${Object.keys(results).length - failed.length}/${Object.keys(results).length} scenarios passed`);
  if (failed.length) {
    console.log("FAILURES:", failed.map(([k]) => k).join(", "));
    console.log("PHASE ADMR-70 (authorization audit): FAILED");
    process.exitCode = 1;
  } else {
    console.log("PHASE ADMR-70 (authorization audit): ALL PASSED");
  }
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
