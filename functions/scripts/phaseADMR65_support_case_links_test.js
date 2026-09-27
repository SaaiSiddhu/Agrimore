// ============================================================
//  Phase ADMR-65 — support case link/unlink + create-from-source
// ============================================================
//
// Run with: JAVA_HOME=/opt/homebrew/opt/openjdk@21 firebase emulators:exec
//             --only firestore "node scripts/phaseADMR65_support_case_links_test.js"

process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });
const db = admin.firestore();

const {
  createSupportCase, linkSupportCaseRecord, unlinkSupportCaseRecord,
  createSupportCaseFromSource,
} = require("../lib/admin/supportCases");

const ADMIN1 = { uid: "sl-admin1", token: { admin: true, role: "admin" } };
const CUSTOMER_CALLER = { uid: "sl-customer", token: { role: "user" } };

async function call(fn, auth, data) {
  try {
    return { ok: true, res: await fn.run({ auth, data }) };
  } catch (e) {
    return { ok: false, code: e.code, message: e.message, details: e.details };
  }
}

async function eventsFor(caseId) {
  const snap = await db.collection("support_case_events").where("caseId", "==", caseId).get();
  return snap.docs.map((d) => d.data());
}

async function seed() {
  await db.doc("users/sl-admin1").set({ role: "admin" });
  await db.doc("users/sl-customer").set({ role: "user" });
  await db.doc("delivery_partners/sl-rider-real").set({ name: "Real Rider" });
  await db.doc("orders/sl-order-real").set({ orderNumber: "ORD-SL1" });
  await db.doc("rider_support_tickets/sl-ticket-real").set({
    riderId: "sl-rider-real", category: "delivery_issue", message: "m", status: "submitted",
  });
  await db.doc("rider_incidents/sl-incident-real").set({
    riderId: "sl-rider-real", kind: "sos", status: "reported",
  });
  await db.doc("delivery_exceptions/sl-exc-real").set({
    riderId: "sl-rider-real", orderId: "sl-order-real", reason: "customer_unreachable", status: "reported",
  });
  // A ticket with no riderId at all, and one pointing at a rider that does
  // not actually exist -- both genuinely malformed, neither should ever
  // become a case.
  await db.doc("rider_support_tickets/sl-ticket-noriderfield").set({
    category: "delivery_issue", message: "m", status: "submitted",
  });
  await db.doc("rider_support_tickets/sl-ticket-ghostrider").set({
    riderId: "sl-rider-does-not-exist", category: "delivery_issue", message: "m", status: "submitted",
  });
}

async function newCase(actorType, actorId) {
  const r = await call(createSupportCase, ADMIN1, {
    title: "base case", category: "c", primaryActor: { type: actorType, id: actorId },
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

  // ── link: authorization (spot check — requireAdmin is the same wrapper
  //    every other callable in this file already proves in ADMR-61) ──
  {
    const caseId = await newCase("rider", "sl-rider-real");
    const r = await call(linkSupportCaseRecord, undefined, {
      caseId, link: { type: "order", id: "sl-order-real" }, expectedVersion: 1,
    });
    check("l00_unauthenticated_denied", !r.ok && r.code === "unauthenticated", JSON.stringify(r));
  }

  // ── link: real success + event ──
  {
    const caseId = await newCase("rider", "sl-rider-real");
    const r = await call(linkSupportCaseRecord, ADMIN1, {
      caseId, link: { type: "order", id: "sl-order-real" }, expectedVersion: 1,
    });
    const doc = (await db.doc(`support_cases/${caseId}`).get()).data();
    const events = await eventsFor(caseId);
    check(
      "l01_link_succeeds_and_bumps_version",
      r.ok && r.res.success === true && doc.version === 2 &&
        doc.linkedRecords.length === 1 && doc.linkedRecords[0].type === "order" &&
        events.some((e) => e.type === "link_added"),
      JSON.stringify({ r, doc, events })
    );
  }

  // ── link: unknown target refused ──
  {
    const caseId = await newCase("rider", "sl-rider-real");
    const r = await call(linkSupportCaseRecord, ADMIN1, {
      caseId, link: { type: "order", id: "does-not-exist" }, expectedVersion: 1,
    });
    check("l02_unknown_target_refused", !r.ok && r.code === "invalid-argument" && r.details?.reason === "target_not_found", JSON.stringify(r));
  }

  // ── link: invalid type is bad_request, never silently accepted ──
  {
    const caseId = await newCase("rider", "sl-rider-real");
    const r = await call(linkSupportCaseRecord, ADMIN1, {
      caseId, link: { type: "not_a_real_type", id: "sl-order-real" }, expectedVersion: 1,
    });
    check("l03_unrecognized_link_type_refused", !r.ok && r.code === "invalid-argument" && r.details?.reason === "bad_request", JSON.stringify(r));
  }

  // ── link: idempotent re-link, no duplicate, no second event ──
  {
    const caseId = await newCase("rider", "sl-rider-real");
    await call(linkSupportCaseRecord, ADMIN1, { caseId, link: { type: "order", id: "sl-order-real" }, expectedVersion: 1 });
    const r2 = await call(linkSupportCaseRecord, ADMIN1, { caseId, link: { type: "order", id: "sl-order-real" }, expectedVersion: 2 });
    const doc = (await db.doc(`support_cases/${caseId}`).get()).data();
    const events = await eventsFor(caseId);
    const linkAddedCount = events.filter((e) => e.type === "link_added").length;
    check(
      "l04_relinking_same_record_is_idempotent",
      r2.ok && r2.res.alreadyLinked === true && doc.version === 2 &&
        doc.linkedRecords.length === 1 && linkAddedCount === 1,
      JSON.stringify({ r2, doc, linkAddedCount })
    );
  }

  // ── link: version mismatch refused ──
  {
    const caseId = await newCase("rider", "sl-rider-real");
    const r = await call(linkSupportCaseRecord, ADMIN1, {
      caseId, link: { type: "order", id: "sl-order-real" }, expectedVersion: 99,
    });
    check("l05_stale_version_refused", !r.ok && r.code === "failed-precondition" && r.details?.reason === "version_mismatch", JSON.stringify(r));
  }

  // ── unlink: real success + event ──
  {
    const caseId = await newCase("rider", "sl-rider-real");
    await call(linkSupportCaseRecord, ADMIN1, { caseId, link: { type: "order", id: "sl-order-real" }, expectedVersion: 1 });
    const r = await call(unlinkSupportCaseRecord, ADMIN1, {
      caseId, link: { type: "order", id: "sl-order-real" }, expectedVersion: 2,
    });
    const doc = (await db.doc(`support_cases/${caseId}`).get()).data();
    const events = await eventsFor(caseId);
    check(
      "u01_unlink_succeeds_and_removes_it",
      r.ok && doc.version === 3 && doc.linkedRecords.length === 0 &&
        events.some((e) => e.type === "link_removed"),
      JSON.stringify({ r, doc })
    );
  }

  // ── unlink: a record never linked is a genuine refusal, not a silent no-op ──
  {
    const caseId = await newCase("rider", "sl-rider-real");
    const r = await call(unlinkSupportCaseRecord, ADMIN1, {
      caseId, link: { type: "order", id: "sl-order-real" }, expectedVersion: 1,
    });
    check("u02_unlinking_a_record_never_linked_refused", !r.ok && r.code === "failed-precondition" && r.details?.reason === "link_not_found", JSON.stringify(r));
  }

  // ── unlink: version mismatch refused ──
  {
    const caseId = await newCase("rider", "sl-rider-real");
    await call(linkSupportCaseRecord, ADMIN1, { caseId, link: { type: "order", id: "sl-order-real" }, expectedVersion: 1 });
    const r = await call(unlinkSupportCaseRecord, ADMIN1, {
      caseId, link: { type: "order", id: "sl-order-real" }, expectedVersion: 1,
    });
    check("u03_stale_version_refused", !r.ok && r.code === "failed-precondition" && r.details?.reason === "version_mismatch", JSON.stringify(r));
  }

  // ── create-from-source: real success, actor correctly derived ──
  {
    const r = await call(createSupportCaseFromSource, ADMIN1, {
      sourceType: "rider_ticket", sourceId: "sl-ticket-real", title: "From ticket", category: "delivery_issue",
    });
    const caseId = r.ok ? r.res.caseId : null;
    const doc = caseId ? (await db.doc(`support_cases/${caseId}`).get()).data() : null;
    check(
      "f01_creates_with_actor_derived_from_source",
      r.ok && r.res.alreadyExisted === false && doc &&
        doc.primaryActor.type === "rider" && doc.primaryActor.id === "sl-rider-real" &&
        doc.linkedRecords.length === 1 && doc.linkedRecords[0].type === "rider_ticket" &&
        doc.linkedRecords[0].id === "sl-ticket-real",
      JSON.stringify({ r, doc })
    );
  }

  // ── create-from-source: calling again for the SAME source returns the
  //    SAME case, never a duplicate (the H-series duplicate-prevention
  //    criterion) ──
  {
    const r1 = await call(createSupportCaseFromSource, ADMIN1, {
      sourceType: "rider_incident", sourceId: "sl-incident-real", title: "From incident", category: "delivery_issue",
    });
    const r2 = await call(createSupportCaseFromSource, ADMIN1, {
      sourceType: "rider_incident", sourceId: "sl-incident-real", title: "From incident (retry)", category: "delivery_issue",
    });
    check(
      "f02_repeat_call_for_same_source_returns_same_case_not_a_duplicate",
      r1.ok && r2.ok && r2.res.alreadyExisted === true &&
        r1.res.caseId === r2.res.caseId,
      JSON.stringify({ r1, r2 })
    );
  }

  // ── create-from-source: a third real source type also works ──
  {
    const r = await call(createSupportCaseFromSource, ADMIN1, {
      sourceType: "delivery_exception", sourceId: "sl-exc-real", title: "From exception", category: "delivery_issue",
    });
    check("f03_delivery_exception_source_also_works", r.ok && r.res.alreadyExisted === false, JSON.stringify(r));
  }

  // ── create-from-source: unknown source refused ──
  {
    const r = await call(createSupportCaseFromSource, ADMIN1, {
      sourceType: "rider_ticket", sourceId: "does-not-exist", title: "t", category: "c",
    });
    check("f04_unknown_source_refused", !r.ok && r.code === "not-found" && r.details?.reason === "source_not_found", JSON.stringify(r));
  }

  // ── create-from-source: a source with no riderId at all is refused ──
  {
    const r = await call(createSupportCaseFromSource, ADMIN1, {
      sourceType: "rider_ticket", sourceId: "sl-ticket-noriderfield", title: "t", category: "c",
    });
    check("f05_source_with_no_riderid_refused", !r.ok && r.details?.reason === "source_actor_missing", JSON.stringify(r));
  }

  // ── create-from-source: a riderId that doesn't correspond to a real
  //    rider is ALSO refused — proves the second, independent existence
  //    check, not just "is riderId a non-empty string" ──
  {
    const r = await call(createSupportCaseFromSource, ADMIN1, {
      sourceType: "rider_ticket", sourceId: "sl-ticket-ghostrider", title: "t", category: "c",
    });
    check("f06_riderid_pointing_at_a_nonexistent_rider_refused", !r.ok && r.details?.reason === "source_actor_missing", JSON.stringify(r));
  }

  // ── create-from-source: bad request ──
  {
    const r = await call(createSupportCaseFromSource, ADMIN1, {
      sourceType: "not_a_real_source", sourceId: "x", title: "t", category: "c",
    });
    check("f07_unrecognized_source_type_refused", !r.ok && r.details?.reason === "bad_request", JSON.stringify(r));
  }

  // ── create-from-source: a genuine concurrent race for the SAME source
  //    yields exactly one real create and one "existed", never two cases
  //    — the actual reason for the deterministic-id design ──
  {
    await db.doc("rider_support_tickets/sl-ticket-race").set({
      riderId: "sl-rider-real", category: "delivery_issue", message: "m", status: "submitted",
    });
    const [r1, r2] = await Promise.all([
      call(createSupportCaseFromSource, ADMIN1, {
        sourceType: "rider_ticket", sourceId: "sl-ticket-race", title: "Race A", category: "delivery_issue",
      }),
      call(createSupportCaseFromSource, ADMIN1, {
        sourceType: "rider_ticket", sourceId: "sl-ticket-race", title: "Race B", category: "delivery_issue",
      }),
    ]);
    const bothOk = r1.ok && r2.ok;
    const oneCreatedOneExisted =
      bothOk && r1.res.alreadyExisted !== r2.res.alreadyExisted &&
      r1.res.caseId === r2.res.caseId;
    const snap = await db.collection("support_cases")
      .where("linkedRecords", "array-contains", { type: "rider_ticket", id: "sl-ticket-race" })
      .get();
    check(
      "f08_concurrent_race_for_same_source_never_double_creates",
      oneCreatedOneExisted && snap.size === 1,
      JSON.stringify({ r1, r2, sizeFound: snap.size })
    );
  }

  const failed = Object.entries(results).filter(([, v]) => v !== "PASSED");
  console.log(`\n${Object.keys(results).length - failed.length}/${Object.keys(results).length} scenarios passed`);
  if (failed.length) {
    console.log("FAILURES:", failed.map(([k]) => k).join(", "));
    console.log("PHASE ADMR-65 (links): FAILED");
    process.exitCode = 1;
  } else {
    console.log("PHASE ADMR-65 (links): ALL PASSED");
  }
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
