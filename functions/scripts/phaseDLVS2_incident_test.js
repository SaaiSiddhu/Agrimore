// Phase DLV-S2 — rider incidents (functions/src/delivery/riderIncidents.ts)
// against the Firestore emulator.
//
//  r — report: recorded once per request id; a retry returns the same
//      incident; active orders are resolved by the server (none, one, two);
//      location is the device fix, else the last server position marked
//      fresh/stale with its own time, else "unavailable"; a suspended rider
//      can still report; a non-rider cannot; bad input and a flood are refused
//  a — admin: reported → acknowledged → resolved with a written resolution,
//      attributable, repeat acknowledge is a no-op, resolved stays resolved
//
// Run with:
//   firebase emulators:exec --only firestore "node scripts/phaseDLVS2_incident_test.js"
// Requires: npm run build. Honours FIRESTORE_EMULATOR_HOST.
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: "demo-dlvs2-incident" });
const db = admin.firestore();
const { Timestamp } = require("firebase-admin/firestore");
const I = require("../lib/delivery/riderIncidents");

const results = [];
function record(label, pass, detail) {
  results.push({ label, pass });
  console.log(`${pass ? "PASSED" : "FAILED"} — ${label}${pass ? "" : ` :: ${detail}`}`);
}
const T0 = Date.UTC(2026, 8, 24, 10, 0, 0);
const MIN = 60000;
const get = async (p) => (await db.doc(p).get()).data();
let seq = 0;
const rid = () => `req-${String(++seq).padStart(6, "0")}`;

async function main() {
  console.log("=== PHASE DLV-S2 — rider incidents ===");
  await db.doc("delivery_partners/r1").set({ name: "Ravi", status: "approved", currentLat: 9.93, currentLng: 78.12, lastLocationUpdate: Timestamp.fromMillis(T0 - 30000) });
  await db.doc("delivery_partners/r2").set({ name: "Suresh", status: "approved", currentLat: 9.9, currentLng: 78.1, lastLocationUpdate: Timestamp.fromMillis(T0 - 30 * MIN) });
  await db.doc("delivery_partners/r3").set({ name: "Mani", status: "suspended" });
  await db.doc("orders/o-active").set({ deliveryPartnerId: "r1", orderStatus: "picked_up", status: "picked_up" });
  await db.doc("orders/o-done").set({ deliveryPartnerId: "r1", orderStatus: "delivered", status: "delivered" });
  await db.doc("orders/o-a").set({ deliveryPartnerId: "r2", orderStatus: "out_for_delivery", status: "out_for_delivery" });
  await db.doc("orders/o-b").set({ deliveryPartnerId: "r2", orderStatus: "delivery_accepted", status: "delivery_accepted" });

  // ── report ──
  const req1 = rid();
  const v1 = await I.reportIncidentCore(db, "r1", { requestId: req1, kind: "sos", lat: 9.931, lng: 78.121, accuracy: 9, isMocked: false }, T0);
  const d1 = await get(`rider_incidents/${v1.incidentId}`);
  record("r01_recorded_with_server_resolved_order_and_device_fix", v1.kind === "reported" && d1.status === "reported" &&
    d1.orderId === "o-active" && d1.activeOrderIds.join() === "o-active" && d1.location.freshness === "fresh" && d1.location.source === "device" &&
    d1.location.lat === 9.931 && d1.acknowledgedAt === null && d1.riderId === "r1", JSON.stringify(d1));
  const again = await I.reportIncidentCore(db, "r1", { requestId: req1, kind: "sos" }, T0 + 5000);
  const count1 = (await db.collection("rider_incidents").where("riderId", "==", "r1").get()).size;
  record("r02_retry_same_request_id_returns_same_incident", again.kind === "already" && again.incidentId === v1.incidentId && count1 === 1, JSON.stringify(again));
  const v2 = await I.reportIncidentCore(db, "r1", { requestId: rid() }, T0);
  const d2 = await get(`rider_incidents/${v2.incidentId}`);
  record("r03_no_device_fix_uses_fresh_server_position_with_its_time", d2.location.freshness === "fresh" && d2.location.source === "server" &&
    d2.location.at.toMillis() === T0 - 30000, JSON.stringify(d2.location));
  const v3 = await I.reportIncidentCore(db, "r2", { requestId: rid() }, T0);
  const d3 = await get(`rider_incidents/${v3.incidentId}`);
  record("r04_old_server_position_is_marked_stale_and_two_orders_are_both_recorded",
    d3.location.freshness === "stale" && d3.location.at.toMillis() === T0 - 30 * MIN &&
    d3.activeOrderIds.join() === "o-a,o-b" && d3.orderId === null, JSON.stringify(d3));
  const v4 = await I.reportIncidentCore(db, "r3", { requestId: rid(), note: "bike accident near the bridge" }, T0);
  const d4 = await get(`rider_incidents/${v4.incidentId}`);
  record("r05_suspended_rider_can_still_report_no_position_is_unavailable", v4.kind === "reported" && d4.riderStatus === "suspended" &&
    d4.location.freshness === "unavailable" && d4.location.lat === undefined && d4.activeOrderIds.length === 0 && d4.note === "bike accident near the bridge", JSON.stringify(d4));
  record("r06_not_a_rider_refused", (await I.reportIncidentCore(db, "stranger", { requestId: rid() }, T0)).reason === "not_a_rider", "");
  record("r07_bad_input_refused",
    (await I.reportIncidentCore(db, "r1", { requestId: "short" }, T0)).reason === "bad_request" &&
    (await I.reportIncidentCore(db, "r1", { requestId: rid(), kind: "prank" }, T0)).reason === "bad_request" &&
    (await I.reportIncidentCore(db, "r1", { requestId: rid(), note: "x".repeat(501) }, T0)).reason === "bad_request" &&
    (await I.reportIncidentCore(db, "r1", { requestId: rid(), note: 42 }, T0)).reason === "bad_request", "");
  // r1 already has 2 in the window; three more fill it, the next is refused, and later it is allowed again.
  for (let k = 0; k < 3; k++) await I.reportIncidentCore(db, "r1", { requestId: rid() }, T0 + k * 1000);
  const flood = await I.reportIncidentCore(db, "r1", { requestId: rid() }, T0 + 4000);
  const later = await I.reportIncidentCore(db, "r1", { requestId: rid() }, T0 + 11 * MIN);
  record("r08_flood_is_bounded_and_the_window_moves", flood.reason === "too_many" && later.kind === "reported", JSON.stringify({ flood, later }));
  const mocked = await I.reportIncidentCore(db, "r2", { requestId: rid(), lat: 9.9, lng: 78.1, isMocked: true }, T0);
  record("r09_mocked_fix_is_kept_and_marked", (await get(`rider_incidents/${mocked.incidentId}`)).location.isMocked === true, "");

  // ── admin ──
  const bad = await I.updateIncidentCore(db, "admin1", v1.incidentId, "delete", null, T0 + MIN);
  const ack = await I.updateIncidentCore(db, "admin1", v1.incidentId, "acknowledge", null, T0 + MIN);
  const ack2 = await I.updateIncidentCore(db, "admin2", v1.incidentId, "acknowledge", null, T0 + 2 * MIN);
  let a1 = await get(`rider_incidents/${v1.incidentId}`);
  record("a01_acknowledge_once_attributable", bad.reason === "bad_request" && ack.kind === "updated" && ack2.kind === "unchanged" &&
    a1.status === "acknowledged" && a1.acknowledgedBy === "admin1" && a1.acknowledgedAt.toMillis() === T0 + MIN, JSON.stringify(a1));
  const noText = await I.updateIncidentCore(db, "admin1", v1.incidentId, "resolve", "ok", T0 + 3 * MIN);
  const res = await I.updateIncidentCore(db, "admin1", v1.incidentId, "resolve", "Called the rider; safe, bike towed.", T0 + 3 * MIN);
  a1 = await get(`rider_incidents/${v1.incidentId}`);
  record("a02_resolve_needs_a_written_resolution", noText.reason === "resolution_required" && res.kind === "updated" &&
    a1.status === "resolved" && a1.resolvedBy === "admin1" && a1.resolution === "Called the rider; safe, bike towed.", JSON.stringify(a1));
  const again2 = await I.updateIncidentCore(db, "admin2", v1.incidentId, "resolve", "different text", T0 + 4 * MIN);
  const reack = await I.updateIncidentCore(db, "admin2", v1.incidentId, "acknowledge", null, T0 + 4 * MIN);
  record("a03_resolved_stays_resolved", again2.reason === "already_resolved" && reack.kind === "unchanged" &&
    (await get(`rider_incidents/${v1.incidentId}`)).resolution === "Called the rider; safe, bike towed.", "");
  const direct = await I.updateIncidentCore(db, "admin3", v4.incidentId, "resolve", "Spoke to the rider, reported to the police.", T0 + 5 * MIN);
  const d4b = await get(`rider_incidents/${v4.incidentId}`);
  record("a04_resolving_an_unseen_report_records_who_saw_it", direct.kind === "updated" && d4b.acknowledgedBy === "admin3" && d4b.resolvedBy === "admin3", JSON.stringify(d4b));
  record("a05_missing_incident", (await I.updateIncidentCore(db, "admin1", "nope", "acknowledge", null, T0)).reason === "not_found", "");

  const failed = results.filter((r) => !r.pass);
  console.log(`\n${results.length - failed.length}/${results.length} passed`);
  if (failed.length) { console.log("PHASE DLV-S2 incidents: FAILED"); process.exit(1); }
  console.log("PHASE DLV-S2 incidents: ALL PASSED");
  process.exit(0);
}
main().catch((e) => { console.error(e); process.exit(1); });
