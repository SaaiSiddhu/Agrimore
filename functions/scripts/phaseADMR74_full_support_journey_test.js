// ============================================================
//  Phase ADMR-74 — the complete support journey, end to end
// ============================================================
//
// Owner's prompt section 10: exercise one COMPLETE operational journey
// through real callables against the real Firestore + Storage emulators --
// not separate unit tests, one continuous story, proving the pieces this
// session built across ADMR-61 through ADMR-73 actually work TOGETHER:
//   1. A rider files a real ticket (submitSupportRequest).
//   2. An admin creates its canonical case (createSupportCaseFromSource).
//   3. Primary actor + source link verified on the case itself.
//   4. The admin links the order the ticket was actually about.
//   5. The order's own linked-cases view shows this case (and ONLY this
//      case -- a second, unrelated case on the same customer must not leak
//      in, proving the array-contains-on-Map filter is load-bearing for
//      real, the same guarantee ADMR-67 established).
//   6. Assign the case.
//   7. Add an internal note.
//   8. Attach evidence (real bytes to the real Storage emulator) and verify
//      it (recorded generation/md5Hash match the object's OWN live metadata
//      -- proving a "view" would return the exact bytes checked).
//   9. Move to waiting with a reason.
//  10. Resolve with a summary.
//  11. Confirm the rider's own ticket and the order are BOTH untouched by
//      any of the above -- resolving support never rewrites source status,
//      never touches money/custody.
//  12. Reopen with a reason.
//  13. The full audit event sequence, in order, matches every action taken.
//
// Also: ordinary case creation directly from Customer/Seller/Associate
// workspaces (createSupportCase with each actor type) -- already proven
// exhaustively by ADMR-61/66's own suites; one confirming call per type
// here, not a re-litigation.
//
// Run with: JAVA_HOME=/opt/homebrew/opt/openjdk@21 firebase emulators:exec
//             --only firestore,storage "node scripts/phaseADMR74_full_support_journey_test.js"

process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
process.env.FIREBASE_STORAGE_EMULATOR_HOST = process.env.FIREBASE_STORAGE_EMULATOR_HOST || "127.0.0.1:9199";
process.env.STORAGE_EMULATOR_HOST = process.env.STORAGE_EMULATOR_HOST || `http://${process.env.FIREBASE_STORAGE_EMULATOR_HOST}`;
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
if (!admin.apps.length) admin.initializeApp({ projectId: "agrimore-66a4e", storageBucket: "agrimore-66a4e.firebasestorage.app" });
const db = admin.firestore();

const SC = require("../lib/admin/supportCases");
const RS = require("../lib/delivery/riderSupport");
const {
  createSupportCaseFromSource, linkSupportCaseRecord, unlinkSupportCaseRecord,
  assignSupportCase, addSupportCaseNote, attachSupportCaseEvidence,
  changeSupportCaseStatus, resolveSupportCase, reopenSupportCase, createSupportCase,
} = SC;
const { submitSupportRequest } = RS;

const RIDER = { uid: "j-rider-1", token: {} };
const ADMIN1 = { uid: "j-admin-1", token: { admin: true, role: "admin" } };
const ADMIN2 = { uid: "j-admin-2", token: { admin: true, role: "admin" } };

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

async function seed() {
  await db.doc("users/j-admin-1").set({ role: "admin" });
  await db.doc("users/j-admin-2").set({ role: "admin" });
  await db.doc("delivery_partners/j-rider-1").set({ name: "Journey Rider", status: "approved" });
  await db.doc("orders/j-order-1").set({
    orderNumber: "ORD-J1", userId: "j-cust-1", deliveryPartnerId: "j-rider-1",
    orderStatus: "delivered", status: "delivered", total: 799,
  });
  // A DIFFERENT, unrelated case on the SAME customer -- must never leak
  // into order-1's own linked-cases view (step 5's own negative control).
  await db.doc("users/j-cust-1").set({ role: "user" });
  await db.doc("sellers/j-seller-1").set({ shopName: "Journey Seller" });
  await db.doc("employees/j-assoc-1").set({ name: "Journey Associate" });
}

async function main() {
  await seed();
  const nowBase = Date.now();

  // 1 — a rider files a real ticket
  const ticketReqId = "journey-ticket-req-01";
  const submit = await call(submitSupportRequest, RIDER, {
    requestId: ticketReqId, category: "delivery_issue", message: "Order ORD-J1 arrived damaged",
  });
  const ticketId = submit.ok ? submit.res.ticketId : undefined;
  check("j01_rider_files_a_real_ticket", submit.ok && !submit.res.alreadySubmitted && !!ticketId, JSON.stringify(submit));

  // 2 — admin creates the canonical case from that ticket
  const fromSource = await call(createSupportCaseFromSource, ADMIN1, {
    sourceType: "rider_ticket", sourceId: ticketId, title: "Damaged parcel — ORD-J1", category: "delivery_issue",
  });
  const caseId = fromSource.ok ? fromSource.res.caseId : undefined;
  check("j02_admin_creates_the_canonical_case", fromSource.ok && fromSource.res.alreadyExisted === false && !!caseId, JSON.stringify(fromSource));

  // 3 — primary actor + source link verified on the case itself
  {
    const doc = (await db.doc(`support_cases/${caseId}`).get()).data();
    check(
      "j03_primary_actor_and_source_link_are_correct",
      doc.primaryActor.type === "rider" && doc.primaryActor.id === "j-rider-1" &&
        doc.linkedRecords.some((l) => l.type === "rider_ticket" && l.id === ticketId),
      JSON.stringify(doc)
    );
  }

  // 4 — link the order the ticket was actually about
  let caseVersion;
  {
    const before = (await db.doc(`support_cases/${caseId}`).get()).data();
    const link = await call(linkSupportCaseRecord, ADMIN1, {
      caseId, link: { type: "order", id: "j-order-1" }, expectedVersion: before.version,
    });
    caseVersion = link.ok ? before.version + 1 : before.version;
    check("j04_admin_links_the_real_order", link.ok && link.res.alreadyLinked === false, JSON.stringify(link));
  }

  // A second, DISTRACTOR case on the same customer -- linked to a DIFFERENT
  // order, never order-1 -- exists purely as j05's own negative control.
  const distractor = await call(createSupportCase, ADMIN1, {
    title: "Unrelated case, same customer", category: "other",
    primaryActor: { type: "customer", id: "j-cust-1" }, requestId: "journey-distractor-01",
  });
  check("j04b_distractor_case_created_for_the_negative_control", distractor.ok, JSON.stringify(distractor));

  // 5 — the order's OWN linked-cases view (the real query
  // OrderLinkedSupportCasesSection issues) shows this case, and ONLY this
  // case -- the distractor (same customer, no order link) must not leak in.
  {
    const forOrder = await db.collection("support_cases")
      .where("linkedRecords", "array-contains", { type: "order", id: "j-order-1" })
      .get();
    const ids = forOrder.docs.map((d) => d.id);
    check(
      "j05_order_linked_view_shows_this_case_only_not_the_distractor",
      ids.length === 1 && ids[0] === caseId,
      JSON.stringify(ids)
    );
  }

  // 6 — assign the case
  {
    const assign = await call(assignSupportCase, ADMIN1, { caseId, assigneeUid: "j-admin-2", expectedVersion: caseVersion });
    if (assign.ok) caseVersion += 1;
    check("j06_case_assigned", assign.ok, JSON.stringify(assign));
  }

  // 7 — add an internal note
  {
    const note = await call(addSupportCaseNote, ADMIN2, {
      caseId, text: "Called the customer, arranging a replacement.", requestId: "journey-note-01",
    });
    check("j07_internal_note_added", note.ok && !note.res.alreadyApplied, JSON.stringify(note));
  }

  // 8 — attach evidence (real bytes, real Storage emulator) then verify it
  {
    const requestId = "journey-evidence-01";
    const path = SC.evidencePath(caseId, "j-admin-2", requestId);
    const bytes = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0xde, 0xad, 0xbe, 0xef]);
    await admin.storage().bucket().file(path).save(bytes, { contentType: "image/png" });
    const attach = await call(attachSupportCaseEvidence, ADMIN2, {
      caseId, requestId, originalFileName: "damaged_parcel.png",
    });
    const evidenceDoc = attach.ok ? (await db.doc(`support_case_evidence/${attach.res.evidenceId}`).get()).data() : null;
    const [liveMeta] = attach.ok ? await admin.storage().bucket().file(path).getMetadata() : [null];
    check(
      "j08_evidence_attached_and_its_recorded_identity_matches_the_live_object",
      attach.ok && evidenceDoc && liveMeta &&
        evidenceDoc.generation === String(liveMeta.generation) && evidenceDoc.md5Hash === liveMeta.md5Hash,
      JSON.stringify({ attach, evidenceDoc, liveGeneration: liveMeta?.generation })
    );
  }

  // 9 — move to waiting with a reason
  {
    const wait = await call(changeSupportCaseStatus, ADMIN2, {
      caseId, status: "waiting", waitingReason: "Waiting for the seller to confirm a replacement.", expectedVersion: caseVersion,
    });
    if (wait.ok) caseVersion += 1;
    check("j09_moved_to_waiting_with_a_reason", wait.ok, JSON.stringify(wait));
  }

  // 10 — resolve with a summary
  {
    const resolve = await call(resolveSupportCase, ADMIN2, {
      caseId, resolutionSummary: "Replacement sent by the seller directly.", expectedVersion: caseVersion,
    });
    if (resolve.ok) caseVersion += 1;
    check("j10_resolved_with_a_summary", resolve.ok, JSON.stringify(resolve));
  }

  // 11 — the rider's own ticket and the order are BOTH untouched
  {
    const ticket = (await db.doc(`rider_support_tickets/${ticketId}`).get()).data();
    const order = (await db.doc("orders/j-order-1").get()).data();
    check(
      "j11_resolving_the_case_never_rewrites_the_source_ticket_or_the_order",
      ticket.status === "submitted" && order.orderStatus === "delivered" && order.total === 799,
      JSON.stringify({ ticketStatus: ticket.status, orderStatus: order.orderStatus, orderTotal: order.total })
    );
  }

  // 12 — reopen with a reason
  {
    const reopen = await call(reopenSupportCase, ADMIN1, {
      caseId, reason: "Customer says the replacement never arrived.", expectedVersion: caseVersion,
    });
    if (reopen.ok) caseVersion += 1;
    check("j12_reopened_with_a_reason", reopen.ok, JSON.stringify(reopen));
  }

  // 13 — the full audit sequence, in order, matches every real action taken
  {
    const events = await db.collection("support_case_events").where("caseId", "==", caseId)
      .orderBy("at", "asc").get();
    const seq = events.docs.map((d) => d.data().type);
    const expected = ["created", "link_added", "assigned", "note_added", "evidence_attached", "status_changed", "resolved", "reopened"];
    check("j13_audit_sequence_matches_every_action_in_order", JSON.stringify(seq) === JSON.stringify(expected), JSON.stringify(seq));
  }

  // Ordinary case creation from Customer/Seller/Associate workspaces --
  // already exhaustively proven by ADMR-61/66; one confirming call per
  // type here, not a re-litigation.
  for (const [type, id] of [["customer", "j-cust-1"], ["seller", "j-seller-1"], ["associate", "j-assoc-1"]]) {
    const r = await call(createSupportCase, ADMIN1, {
      title: `Ordinary ${type} case`, category: "other",
      primaryActor: { type, id }, requestId: `journey-ordinary-${type}`,
    });
    check(`j14_ordinary_case_creation_from_${type}_workspace`, r.ok && !r.res.alreadyApplied, JSON.stringify(r));
  }

  const failed = Object.values(results).filter((v) => v.startsWith("FAILED")).length;
  console.log(`\n${Object.keys(results).length - failed}/${Object.keys(results).length} passed`);
  process.exit(failed ? 1 : 0);
}

main().catch((e) => {
  console.error("suite crashed:", e);
  process.exit(1);
});
