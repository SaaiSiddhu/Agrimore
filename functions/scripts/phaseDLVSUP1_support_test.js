// Phase DLVSUP1 — rider support tickets (functions/src/delivery/riderSupport.ts)
// against the Firestore emulator.
//
//  s — submit: recorded once per request id; a retry returns the same
//      ticket; category/message/attachment/relatedTo validated; a
//      suspended rider can still file; a non-rider cannot
//  a — admin: submitted -> seen -> closed with a written outcome,
//      attributable, repeat mark_seen is a no-op, closed stays closed,
//      closing an unseen ticket records who saw it
//
// Run with:
//   firebase emulators:exec --only firestore "node scripts/phaseDLVSUP1_support_test.js"
// Requires: npm run build. Honours FIRESTORE_EMULATOR_HOST.
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
const PROJECT = process.env.GCLOUD_PROJECT || "demo-dlvsup1-support";
if (!PROJECT.startsWith("demo-")) { console.error(`REFUSING: project ${PROJECT} is not a demo- project`); process.exit(2); }
const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: PROJECT });
const db = admin.firestore();
const S = require("../lib/delivery/riderSupport");

const results = [];
function record(label, pass, detail) {
  results.push({ label, pass });
  console.log(`${pass ? "PASSED" : "FAILED"} — ${label}${pass ? "" : ` :: ${detail}`}`);
}
const T0 = Date.UTC(2026, 8, 27, 10, 0, 0);
const MIN = 60000;
const get = async (p) => (await db.doc(p).get()).data();
let seq = 0;
const rid = () => `req-${String(++seq).padStart(6, "0")}`;

async function main() {
  console.log("=== PHASE DLVSUP1 — rider support tickets ===");
  await db.doc("delivery_partners/r1").set({ name: "Ravi", status: "approved" });
  await db.doc("delivery_partners/r2").set({ name: "Suresh", status: "approved" });
  await db.doc("delivery_partners/r3").set({ name: "Mani", status: "suspended" });

  // ── submit ──
  const req1 = rid();
  const v1 = await S.submitSupportRequestCore(db, "r1", { requestId: req1, category: "delivery_issue", message: "The customer was not reachable at the address." }, T0);
  const d1 = await get(`rider_support_tickets/${v1.ticketId}`);
  record("s01_recorded_pending_no_related_to", v1.kind === "submitted" && d1.status === "submitted" && d1.riderId === "r1" &&
    d1.category === "delivery_issue" && d1.relatedTo === null && d1.attachmentPath === null && d1.seenAt === null, JSON.stringify(d1));
  const again = await S.submitSupportRequestCore(db, "r1", { requestId: req1, category: "delivery_issue", message: "different text entirely" }, T0 + 5000);
  const count1 = (await db.collection("rider_support_tickets").where("riderId", "==", "r1").get()).size;
  record("s02_retry_same_request_id_returns_same_ticket", again.kind === "already" && again.ticketId === v1.ticketId && count1 === 1, JSON.stringify(again));

  const v2 = await S.submitSupportRequestCore(db, "r2",
    { requestId: rid(), category: "earnings_payouts", message: "Statement amount looks wrong for last week.",
      relatedTo: { type: "statement", id: "stmt-42" }, attachmentPath: "support_attachments/r2/req002.jpg" }, T0);
  const d2 = await get(`rider_support_tickets/${v2.ticketId}`);
  record("s03_related_to_and_attachment_stored", d2.relatedTo.type === "statement" && d2.relatedTo.id === "stmt-42" &&
    d2.attachmentPath === "support_attachments/r2/req002.jpg", JSON.stringify(d2));

  const v3 = await S.submitSupportRequestCore(db, "r3", { requestId: rid(), category: "account_documents", message: "Need help updating my licence file." }, T0);
  record("s04_suspended_rider_can_still_file", v3.kind === "submitted", JSON.stringify(v3));

  record("s05_bad_category_refused", (await S.submitSupportRequestCore(db, "r1", { requestId: rid(), category: "weather", message: "abc" }, T0)).reason === "bad_request", "");
  record("s06_short_message_refused", (await S.submitSupportRequestCore(db, "r1", { requestId: rid(), category: "delivery_issue", message: "hi" }, T0)).reason === "bad_request", "");
  record("s07_long_message_refused", (await S.submitSupportRequestCore(db, "r1", { requestId: rid(), category: "delivery_issue", message: "x".repeat(501) }, T0)).reason === "bad_request", "");
  record("s08_malformed_related_to_refused",
    (await S.submitSupportRequestCore(db, "r1", { requestId: rid(), category: "delivery_issue", message: "valid message here", relatedTo: { type: "invoice", id: "1" } }, T0)).reason === "bad_request", "");
  record("s09_not_a_rider_refused", (await S.submitSupportRequestCore(db, "stranger", { requestId: rid(), category: "delivery_issue", message: "valid message here" }, T0)).reason === "not_a_rider", "");

  // ── admin ──
  const bad = await S.updateSupportRequestCore(db, "admin1", v1.ticketId, "delete", null, T0 + MIN);
  const seen = await S.updateSupportRequestCore(db, "admin1", v1.ticketId, "mark_seen", null, T0 + MIN);
  const seen2 = await S.updateSupportRequestCore(db, "admin2", v1.ticketId, "mark_seen", null, T0 + 2 * MIN);
  let a1 = await get(`rider_support_tickets/${v1.ticketId}`);
  record("a01_mark_seen_once_attributable", bad.reason === "bad_request" && seen.kind === "updated" && seen2.kind === "unchanged" &&
    a1.status === "seen" && a1.seenBy === "admin1" && a1.seenAt.toMillis() === T0 + MIN, JSON.stringify(a1));

  const noNote = await S.updateSupportRequestCore(db, "admin1", v1.ticketId, "close", "ok", T0 + 3 * MIN);
  const closed = await S.updateSupportRequestCore(db, "admin1", v1.ticketId, "close", "Reassigned to a different rider; delivered successfully.", T0 + 3 * MIN);
  a1 = await get(`rider_support_tickets/${v1.ticketId}`);
  record("a02_close_needs_a_written_note", noNote.reason === "note_required" && closed.kind === "updated" &&
    a1.status === "closed" && a1.closedBy === "admin1" && a1.resolutionNote === "Reassigned to a different rider; delivered successfully.", JSON.stringify(a1));

  const again2 = await S.updateSupportRequestCore(db, "admin2", v1.ticketId, "close", "different text", T0 + 4 * MIN);
  const reseen = await S.updateSupportRequestCore(db, "admin2", v1.ticketId, "mark_seen", null, T0 + 4 * MIN);
  record("a03_closed_stays_closed", again2.reason === "already_closed" && reseen.kind === "unchanged" &&
    (await get(`rider_support_tickets/${v1.ticketId}`)).resolutionNote === "Reassigned to a different rider; delivered successfully.", "");

  const direct = await S.updateSupportRequestCore(db, "admin3", v2.ticketId, "close", "Credited the missing amount to next week's statement.", T0 + 5 * MIN);
  const d2b = await get(`rider_support_tickets/${v2.ticketId}`);
  record("a04_closing_an_unseen_ticket_records_who_saw_it", direct.kind === "updated" && d2b.seenBy === "admin3" && d2b.closedBy === "admin3", JSON.stringify(d2b));
  record("a05_missing_ticket", (await S.updateSupportRequestCore(db, "admin1", "nope", "mark_seen", null, T0)).reason === "not_found", "");

  const failed = results.filter((r) => !r.pass);
  console.log(`\n${results.length - failed.length}/${results.length} passed`);
  if (failed.length) { console.log("PHASE DLVSUP1 support: FAILED"); process.exit(1); }
  console.log("PHASE DLVSUP1 support: ALL PASSED");
  process.exit(0);
}
main().catch((e) => { console.error(e); process.exit(1); });
