// ============================================================
//  Phase ADMR-61 — unified support case callables
// ============================================================
//
// Run with: JAVA_HOME=/opt/homebrew/opt/openjdk@21 firebase emulators:exec
//             --only firestore "node scripts/phaseADMR61_support_cases_test.js"

// Respect an already-set FIRESTORE_EMULATOR_HOST (e.g. an alternate port
// when 8080 is taken by something unrelated) rather than clobbering it --
// hardcoding this unconditionally caused every real Firestore call in this
// script to hang silently against an unresponsive port during ADMR-61's
// own development, not fail fast.
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });
const db = admin.firestore();

const {
  createSupportCase, assignSupportCase, changeSupportCaseStatus,
  addSupportCaseNote, resolveSupportCase, reopenSupportCase,
} = require("../lib/admin/supportCases");

const ADMIN1 = { uid: "sc-admin1", token: { admin: true, role: "admin" } };
const ADMIN2 = { uid: "sc-admin2", token: { admin: true, role: "admin" } };
const CUSTOMER_CALLER = { uid: "sc-customer", token: { role: "user" } };

async function call(fn, auth, data) {
  try {
    return { ok: true, res: await fn.run({ auth, data }) };
  } catch (e) {
    return { ok: false, code: e.code, message: e.message, details: e.details };
  }
}

async function seedActors() {
  await db.doc("users/sc-admin1").set({ role: "admin" });
  await db.doc("users/sc-admin2").set({ role: "admin" });
  await db.doc("users/sc-customer").set({ role: "user" });
  await db.doc("users/sc-cust-real").set({ role: "user" });
  await db.doc("sellers/sc-seller-real").set({ shopName: "Shop" });
}

async function eventsFor(caseId) {
  const snap = await db.collection("support_case_events").where("caseId", "==", caseId).get();
  return snap.docs.map((d) => d.data());
}

async function main() {
  const results = {};
  const check = (k, ok, detail) => {
    results[k] = ok ? "PASSED" : `FAILED — ${detail}`;
    console.log(`${k}: ${ok ? "PASSED" : "FAILED"} — ${detail}`);
  };

  await seedActors();

  // ── create: authorization ──
  {
    const r = await call(createSupportCase, undefined, {
      title: "t", category: "c", primaryActor: { type: "customer", id: "sc-cust-real" },
    });
    check("c01_unauthenticated_denied", !r.ok && r.code === "unauthenticated", JSON.stringify(r));
  }
  {
    const r = await call(createSupportCase, CUSTOMER_CALLER, {
      title: "t", category: "c", primaryActor: { type: "customer", id: "sc-cust-real" },
    });
    check("c02_non_admin_denied", !r.ok && r.code === "permission-denied", JSON.stringify(r));
  }

  // ── H09: create validates linked identity ──
  {
    const r = await call(createSupportCase, ADMIN1, {
      title: "t", category: "c", primaryActor: { type: "customer", id: "does-not-exist" },
    });
    check("c03_h09_unknown_actor_refused", !r.ok && r.code === "invalid-argument" && r.details?.reason === "actor_not_found", JSON.stringify(r));
  }
  {
    const r = await call(createSupportCase, ADMIN1, {
      title: "Delivery delayed", category: "delivery_issue", primaryActor: { type: "customer", id: "sc-cust-real" },
    });
    const doc = r.ok ? (await db.collection("support_cases").doc(r.res.caseId).get()).data() : null;
    check("c04_h09_real_actor_creates_case",
      r.ok && doc?.status === "open" && doc?.version === 1 && doc?.createdBy === "sc-admin1",
      JSON.stringify({ r, doc }));
  }
  // H14: the caller cannot forge who created it via the payload.
  {
    const r = await call(createSupportCase, ADMIN1, {
      title: "t2", category: "c", primaryActor: { type: "seller", id: "sc-seller-real" }, createdBy: "someone-else",
    });
    const doc = r.ok ? (await db.collection("support_cases").doc(r.res.caseId).get()).data() : null;
    check("c05_h14_creator_cannot_be_forged", r.ok && doc?.createdBy === "sc-admin1", JSON.stringify({ r, doc }));
  }
  {
    const events = await eventsFor((await call(createSupportCase, ADMIN1, {
      title: "t3", category: "c", primaryActor: { type: "seller", id: "sc-seller-real" },
    })).res.caseId);
    check("c06_create_writes_a_real_event", events.length === 1 && events[0].type === "created" && events[0].actorUid === "sc-admin1", JSON.stringify(events));
  }

  // ── H12: two competing assignments ──
  let raceCaseId;
  {
    const created = await call(createSupportCase, ADMIN1, {
      title: "race", category: "c", primaryActor: { type: "customer", id: "sc-cust-real" },
    });
    raceCaseId = created.res.caseId; // version 1
    const first = await call(assignSupportCase, ADMIN1, { caseId: raceCaseId, assigneeUid: "sc-admin1", expectedVersion: 1 });
    const second = await call(assignSupportCase, ADMIN2, { caseId: raceCaseId, assigneeUid: "sc-admin2", expectedVersion: 1 });
    const doc = (await db.collection("support_cases").doc(raceCaseId).get()).data();
    check("c07_h12_first_assignment_wins_second_explicitly_refused",
      first.ok && !second.ok && second.code === "failed-precondition" && second.details?.reason === "version_mismatch" &&
        doc.assignedTo === "sc-admin1" && doc.version === 2,
      JSON.stringify({ first, second, doc }));
  }
  {
    const r = await call(assignSupportCase, ADMIN1, { caseId: raceCaseId, assigneeUid: "sc-admin2", expectedVersion: 2 });
    const doc = (await db.collection("support_cases").doc(raceCaseId).get()).data();
    check("c08_correct_version_reassigns", r.ok && doc.assignedTo === "sc-admin2" && doc.version === 3, JSON.stringify({ r, doc }));
  }
  {
    const r = await call(assignSupportCase, ADMIN1, { caseId: raceCaseId, assigneeUid: "sc-admin-fake", expectedVersion: 3 });
    check("c09_cannot_assign_to_a_non_admin", !r.ok && r.code === "invalid-argument" && r.details?.reason === "assignee_not_admin", JSON.stringify(r));
  }

  // ── status change ──
  {
    const created = await call(createSupportCase, ADMIN1, { title: "status", category: "c", primaryActor: { type: "customer", id: "sc-cust-real" } });
    const caseId = created.res.caseId;
    const r1 = await call(changeSupportCaseStatus, ADMIN1, { caseId, status: "waiting", expectedVersion: 1 });
    check("c10_waiting_needs_a_reason", !r1.ok && r1.code === "invalid-argument", JSON.stringify(r1));
    const r2 = await call(changeSupportCaseStatus, ADMIN1, { caseId, status: "waiting", waitingReason: "awaiting rider reply", expectedVersion: 1 });
    const doc = (await db.collection("support_cases").doc(caseId).get()).data();
    check("c11_waiting_with_reason_ok", r2.ok && doc.status === "waiting" && doc.waitingReason === "awaiting rider reply", JSON.stringify({ r2, doc }));
    const stale = await call(changeSupportCaseStatus, ADMIN1, { caseId, status: "in_progress", expectedVersion: 1 });
    check("c12_stale_version_status_change_refused", !stale.ok && stale.details?.reason === "version_mismatch", JSON.stringify(stale));
    const viaWrongCommand = await call(changeSupportCaseStatus, ADMIN1, { caseId, status: "resolved", expectedVersion: 2 });
    check("c13_cannot_resolve_via_status_change", !viaWrongCommand.ok && viaWrongCommand.code === "invalid-argument", JSON.stringify(viaWrongCommand));
  }

  // ── add note (append-only) ──
  {
    const created = await call(createSupportCase, ADMIN1, { title: "notes", category: "c", primaryActor: { type: "customer", id: "sc-cust-real" } });
    const caseId = created.res.caseId;
    const r1 = await call(addSupportCaseNote, ADMIN1, { caseId, text: "" });
    check("c14_empty_note_refused", !r1.ok && r1.code === "invalid-argument", JSON.stringify(r1));
    const r2 = await call(addSupportCaseNote, ADMIN1, { caseId, text: "Called the customer, no answer yet." });
    const r3 = await call(addSupportCaseNote, ADMIN2, { caseId, text: "Tried again, reached them." });
    const notes = await db.collection("support_case_notes").where("caseId", "==", caseId).get();
    check("c15_two_admins_can_each_add_their_own_note",
      r2.ok && r3.ok && notes.size === 2 && notes.docs.some((d) => d.data().authorUid === "sc-admin1") && notes.docs.some((d) => d.data().authorUid === "sc-admin2"),
      `notes=${notes.size}`);
  }

  // ── resolve / reopen ──
  {
    const created = await call(createSupportCase, ADMIN1, { title: "lifecycle", category: "c", primaryActor: { type: "customer", id: "sc-cust-real" } });
    const caseId = created.res.caseId;
    const badResolve = await call(resolveSupportCase, ADMIN1, { caseId, resolutionSummary: "", expectedVersion: 1 });
    check("c16_resolve_needs_a_real_summary", !badResolve.ok && badResolve.code === "invalid-argument", JSON.stringify(badResolve));
    const resolve1 = await call(resolveSupportCase, ADMIN1, { caseId, resolutionSummary: "Refund issued by seller directly.", expectedVersion: 1 });
    const doc1 = (await db.collection("support_cases").doc(caseId).get()).data();
    check("c17_resolve_succeeds",
      resolve1.ok && doc1.status === "resolved" && doc1.resolvedBy === "sc-admin1" && doc1.resolutionSummary && doc1.version === 2,
      JSON.stringify({ resolve1, doc1 }));
    const resolveAgain = await call(resolveSupportCase, ADMIN1, { caseId, resolutionSummary: "again", expectedVersion: 2 });
    check("c18_h16_cannot_resolve_an_already_resolved_case", !resolveAgain.ok && resolveAgain.details?.reason === "already_resolved", JSON.stringify(resolveAgain));
    const reopenNoReason = await call(reopenSupportCase, ADMIN2, { caseId, reason: "", expectedVersion: 2 });
    check("c19_reopen_needs_a_reason", !reopenNoReason.ok && reopenNoReason.code === "invalid-argument", JSON.stringify(reopenNoReason));
    const reopen = await call(reopenSupportCase, ADMIN2, { caseId, reason: "Customer says the refund never arrived.", expectedVersion: 2 });
    const doc2 = (await db.collection("support_cases").doc(caseId).get()).data();
    check("c20_h18_reopen_records_actor_and_reason",
      reopen.ok && doc2.status === "open" && doc2.reopenedBy === "sc-admin2" && doc2.reopenReason && doc2.version === 3,
      JSON.stringify({ reopen, doc2 }));
    const events = await eventsFor(caseId);
    check("c21_full_lifecycle_has_a_complete_event_trail",
      ["created", "resolved", "reopened"].every((t) => events.some((e) => e.type === t)), JSON.stringify(events.map((e) => e.type)));
    const reopenNotResolved = await call(reopenSupportCase, ADMIN1, { caseId, reason: "again", expectedVersion: 3 });
    check("c22_cannot_reopen_a_case_that_is_not_resolved", !reopenNotResolved.ok && reopenNotResolved.details?.reason === "not_resolved", JSON.stringify(reopenNotResolved));
  }

  // ── not-found handling ──
  {
    const r = await call(assignSupportCase, ADMIN1, { caseId: "missing", assigneeUid: "sc-admin1", expectedVersion: 1 });
    check("c23_missing_case_not_found", !r.ok && r.code === "not-found", JSON.stringify(r));
  }

  console.log("\n=== PHASE ADMR-61 (callable) SUMMARY ===");
  const total = Object.keys(results).length;
  const passed = Object.values(results).filter((v) => v === "PASSED").length;
  for (const [k, v] of Object.entries(results)) console.log(`  ${v === "PASSED" ? "PASS" : "FAIL"}  ${k}`);
  console.log(`\n${passed}/${total} scenarios passed`);
  if (passed !== total) { console.error("PHASE ADMR-61 (callable): FAILED"); process.exitCode = 1; }
  else console.log("PHASE ADMR-61 (callable): ALL PASSED");
}

main().catch((e) => { console.error("harness error", e); process.exit(1); });
