// Phase DLV-3B — road routes for customer tracking (D-DLV-ROUTES).
//
// Pure: polyline decoding (Google's reference example), off-route distance,
// the request (two-wheeler, traffic-aware, via the store before pickup),
// and every rerouteReason branch. Core (Firestore emulator, a FAKE fetcher —
// Google is never called): first route written; a second ping inside 20 s
// costs nothing; pickup re-routes straight to the customer; straying 300 m
// re-routes; a failing API is not retried on every ping; no key → no call;
// the per-order cap holds.
//
// Run with:
//   firebase emulators:exec --only firestore "node scripts/phaseDLV3B_route_test.js"
// Requires: npm run build. Honours FIRESTORE_EMULATOR_HOST.
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: "demo-dlv3b-route" });
const db = admin.firestore();
const { Timestamp } = require("firebase-admin/firestore");
const R = require("../lib/delivery/deliveryRoute");

const results = [];
function record(label, pass, detail) {
  results.push({ label, pass });
  console.log(`${pass ? "PASSED" : "FAILED"} — ${label}${pass ? "" : ` :: ${detail}`}`);
}
const near = (a, b, eps = 1e-5) => Math.abs(a - b) < eps;
const T0 = Date.UTC(2026, 8, 23, 12, 0, 0);
const S = 1000;
const STORE = { lat: 9.9252, lng: 78.1198 };
const HOME = { lat: 9.8982, lng: 78.1198 };

// A fake Google: remembers every call; answers with one leg per waypoint.
function fakeGoogle({ fail = false } = {}) {
  const calls = [];
  const fetcher = async (body, key) => {
    calls.push({ body, key });
    if (fail) throw new Error("Routes API 500: boom");
    const legs = body.intermediates ? 2 : 1;
    return { routes: [{ duration: legs === 2 ? "1500s" : "700s", distanceMeters: legs === 2 ? 5200 : 3100,
      legs: Array.from({ length: legs }, (_, i) => ({ duration: i === 0 ? "600s" : "900s", distanceMeters: 2000 + i,
        polyline: { encodedPolyline: i === 0 ? "_p~iF~ps|U_ulLnnqC" : "_mqNvxq`@" } })) }] };
  };
  return { calls, fetcher };
}

async function task(id, data) { await db.doc(`delivery_tasks/${id}`).set({ orderId: id, pickup: STORE, drop: HOME, ...data }); }
async function live(id, p, atMs) { await db.doc(`delivery_tasks/${id}/live/rider`).set({ riderId: "r", lat: p.lat, lng: p.lng, at: Timestamp.fromMillis(atMs) }); }
const routeOf = async (id) => (await db.doc(`delivery_tasks/${id}`).get()).data().route;

async function main() {
  console.log("=== PHASE DLV-3B — road routes ===");
  // ── pure ──
  const pts = R.decodePolyline("_p~iF~ps|U_ulLnnqC_mqNvxq`@");
  record("p01_decodes_googles_reference_polyline",
    pts.length === 3 && near(pts[0].lat, 38.5) && near(pts[0].lng, -120.2) && near(pts[1].lat, 40.7) &&
    near(pts[1].lng, -120.95) && near(pts[2].lat, 43.252) && near(pts[2].lng, -126.453), JSON.stringify(pts));
  record("p02_truncated_polyline_does_not_throw", Array.isArray(R.decodePolyline("_p~iF~ps")), "");
  const line = [{ lat: 9.92, lng: 78.11 }, { lat: 9.92, lng: 78.12 }];
  const d0 = R.distanceToPolylineMeters({ lat: 9.92, lng: 78.115 }, line);
  const d200 = R.distanceToPolylineMeters({ lat: 9.92 + 200 / 111320, lng: 78.115 }, line);
  record("p03_distance_to_route", d0 < 1 && Math.abs(d200 - 200) < 2, `${d0} ${d200}`);
  const reqVia = R.routeRequest("via_pickup", { lat: 1, lng: 2 }, STORE, HOME);
  const reqDrop = R.routeRequest("to_drop", { lat: 1, lng: 2 }, STORE, HOME);
  record("p04_request_two_wheeler_traffic_aware_via_store",
    reqVia.travelMode === "TWO_WHEELER" && reqVia.routingPreference === "TRAFFIC_AWARE" && reqVia.regionCode === "IN" &&
    reqVia.intermediates?.[0]?.location?.latLng?.latitude === STORE.lat && reqDrop.intermediates === undefined &&
    reqDrop.destination.location.latLng.latitude === HOME.lat, JSON.stringify(reqVia));
  const fresh = { lat: 9.93, lng: 78.12, at: Timestamp.fromMillis(T0) };
  record("p05_plans", R.routePlanFor("assigned") === "via_pickup" && R.routePlanFor("at_pickup") === "to_drop" &&
    R.routePlanFor("en_route") === "to_drop" && R.routePlanFor("searching") === null && R.routePlanFor("delivered") === null, "");
  record("p06_no_route_while_searching_or_finished",
    R.rerouteReason({ status: "searching", pickup: STORE, drop: HOME }, fresh, T0) === null &&
    R.rerouteReason({ status: "delivered", pickup: STORE, drop: HOME }, fresh, T0) === null, "");
  record("p07_no_route_from_a_stale_position",
    R.rerouteReason({ status: "assigned", pickup: STORE, drop: HOME }, { ...fresh, at: Timestamp.fromMillis(T0 - 3 * 60 * S) }, T0) === null, "");
  record("p08_no_route_without_points",
    R.rerouteReason({ status: "assigned", drop: HOME }, fresh, T0) === null &&
    R.rerouteReason({ status: "en_route", pickup: STORE }, fresh, T0) === null, "");

  // ── core, fake Google ──
  let g = fakeGoogle();
  await task("r1", { status: "assigned" });
  await live("r1", { lat: 9.94, lng: 78.12 }, T0);
  const first = await R.refreshRouteCore(db, "r1", T0, "test-key", g.fetcher);
  let rt = await routeOf("r1");
  record("c01_first_route_via_store_written",
    first === "first" && g.calls.length === 1 && g.calls[0].key === "test-key" && rt.plan === "via_pickup" &&
    rt.legs.length === 2 && rt.legs[0].durationSeconds === 600 && rt.durationSeconds === 1500 && rt.count === 1 &&
    rt.origin.lat === 9.94, JSON.stringify(rt));
  const again = await R.refreshRouteCore(db, "r1", T0 + 10 * S, "test-key", g.fetcher);
  record("c02_second_ping_within_20s_costs_nothing", again === null && g.calls.length === 1, `${again} ${g.calls.length}`);

  await db.doc("delivery_tasks/r1").update({ status: "picked_up" });
  await live("r1", { lat: 9.925, lng: 78.12 }, T0 + 25 * S);
  const stage = await R.refreshRouteCore(db, "r1", T0 + 25 * S, "test-key", g.fetcher);
  rt = await routeOf("r1");
  record("c03_pickup_reroutes_straight_to_customer",
    stage === "stage" && g.calls.length === 2 && g.calls[1].body.intermediates === undefined && rt.plan === "to_drop" &&
    rt.legs.length === 1 && rt.count === 2, JSON.stringify({ stage, rt }));

  // The fake leg-0 polyline is far away (California): any real position is
  // "off route" — a legitimate stray test once the gap has passed.
  await live("r1", { lat: 9.92, lng: 78.12 }, T0 + 50 * S);
  const off = await R.refreshRouteCore(db, "r1", T0 + 50 * S, "test-key", g.fetcher);
  record("c04_straying_reroutes", off === "off_route" && g.calls.length === 3, `${off}`);

  // On route and young: nothing.
  await db.doc("delivery_tasks/r2").set({ orderId: "r2", status: "en_route", pickup: STORE, drop: HOME,
    route: { plan: "to_drop", legs: [{ polyline: "", durationSeconds: 300 }], computedAt: Timestamp.fromMillis(T0), count: 1 } });
  await live("r2", { lat: 9.92, lng: 78.12 }, T0 + 60 * S);
  const g2 = fakeGoogle();
  const onRoute = await R.refreshRouteCore(db, "r2", T0 + 60 * S, "test-key", g2.fetcher);
  record("c05_young_route_not_recomputed", onRoute === null && g2.calls.length === 0, `${onRoute}`);
  const aged = await R.refreshRouteCore(db, "r2", T0 + 6 * 60 * S, "test-key", g2.fetcher).catch(() => "stale-live");
  record("c06_route_older_than_5_min_is_refreshed_when_position_fresh",
    aged === null /* live point is now 5 min old → stale, no call */ && g2.calls.length === 0, `${aged}`);
  await live("r2", { lat: 9.92, lng: 78.12 }, T0 + 6 * 60 * S);
  const aged2 = await R.refreshRouteCore(db, "r2", T0 + 6 * 60 * S, "test-key", g2.fetcher);
  record("c07_age_refresh", aged2 === "age" && g2.calls.length === 1, `${aged2}`);

  // A failing API: one attempt, then quiet for 20 s even though pings continue.
  const bad = fakeGoogle({ fail: true });
  await task("r3", { status: "assigned" });
  await live("r3", { lat: 9.94, lng: 78.12 }, T0);
  const f1 = await R.refreshRouteCore(db, "r3", T0, "test-key", bad.fetcher);
  await live("r3", { lat: 9.94, lng: 78.12 }, T0 + 10 * S);
  const f2 = await R.refreshRouteCore(db, "r3", T0 + 10 * S, "test-key", bad.fetcher);
  rt = await routeOf("r3");
  record("c08_failing_api_not_retried_on_every_ping",
    f1 === null && f2 === null && bad.calls.length === 1 && rt && rt.legs === undefined, JSON.stringify(rt));
  await live("r3", { lat: 9.94, lng: 78.12 }, T0 + 25 * S);
  await R.refreshRouteCore(db, "r3", T0 + 25 * S, "test-key", bad.fetcher);
  record("c09_retried_after_the_gap", bad.calls.length === 2, `${bad.calls.length}`);

  // No key: nothing is sent anywhere.
  const g4 = fakeGoogle();
  await task("r4", { status: "assigned" });
  await live("r4", { lat: 9.94, lng: 78.12 }, T0);
  const nokey = await R.refreshRouteCore(db, "r4", T0, "", g4.fetcher);
  record("c10_no_key_no_call", nokey === null && g4.calls.length === 0, `${nokey}`);

  // The per-order cap.
  const g5 = fakeGoogle();
  await db.doc("delivery_tasks/r5").set({ orderId: "r5", status: "en_route", pickup: STORE, drop: HOME,
    route: { plan: "to_drop", legs: [{ polyline: "_p~iF~ps|U" }], computedAt: Timestamp.fromMillis(T0), count: R.MAX_ROUTES_PER_ORDER } });
  await live("r5", { lat: 9.92, lng: 78.12 }, T0 + 60 * S);
  const capped = await R.refreshRouteCore(db, "r5", T0 + 60 * S, "test-key", g5.fetcher);
  record("c11_per_order_cap", capped === null && g5.calls.length === 0, `${capped}`);

  const failed = results.filter((r) => !r.pass);
  console.log(`\n${results.length - failed.length}/${results.length} passed`);
  if (failed.length) { console.log("PHASE DLV-3B route: FAILED"); process.exit(1); }
  console.log("PHASE DLV-3B route: ALL PASSED");
  process.exit(0);
}
main().catch((e) => { console.error(e); process.exit(1); });
