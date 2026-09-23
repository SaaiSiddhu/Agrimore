// Phase DLV-3B — owner smoke test for the Google Routes API key
// (D-DLV-ROUTES). Makes ONE real computeRoutes call with the exact request
// refreshDeliveryRoute sends (two-wheeler, traffic-aware, via the store,
// HIGH_QUALITY polyline) and checks the answer follows roads. Writes nothing
// anywhere; never prints the key.
//
// Run with (after `npm run build`):
//   GOOGLE_ROUTES_API_KEY=... node scripts/routes_smoke.js
//   GOOGLE_ROUTES_API_KEY=... node scripts/routes_smoke.js <riderLat,lng> <storeLat,lng> <homeLat,lng>
// Default points are in Madurai. One call ≈ one billable Routes request
// (inside the monthly free allowance).
const R = require("../lib/delivery/deliveryRoute");

const key = process.env.GOOGLE_ROUTES_API_KEY || "";
if (!key) {
  console.error("Set GOOGLE_ROUTES_API_KEY in the environment (it is never printed).");
  process.exit(2);
}
const pt = (s, d) => {
  if (!s) return d;
  const [lat, lng] = s.split(",").map(Number);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) throw new Error(`bad point: ${s}`);
  return { lat, lng };
};
const rider = pt(process.argv[2], { lat: 9.9432, lng: 78.1198 });
const store = pt(process.argv[3], { lat: 9.9252, lng: 78.1198 });
const home = pt(process.argv[4], { lat: 9.8982, lng: 78.1198 });

// Direction changes over 30° — a straight line has none; a road route has many.
function turns(p) {
  let n = 0;
  for (let i = 2; i < p.length; i++) {
    const a1 = Math.atan2(p[i - 1].lat - p[i - 2].lat, p[i - 1].lng - p[i - 2].lng);
    const a2 = Math.atan2(p[i].lat - p[i - 1].lat, p[i].lng - p[i - 1].lng);
    let d = Math.abs(a2 - a1) * 180 / Math.PI;
    if (d > 180) d = 360 - d;
    if (d > 30) n++;
  }
  return n;
}

(async () => {
  const body = R.routeRequest("via_pickup", rider, store, home);
  let json;
  try {
    json = await R.googleFetcher(body, key);
  } catch (e) {
    // The message carries Google's status and reason, never the key.
    console.error(`FAILED — ${(e && e.message) || e}`);
    console.error("Check: Routes API enabled on the project, billing on, the key's API restriction includes the Routes API.");
    process.exit(1);
  }
  const route = json && json.routes && json.routes[0];
  const legs = (route && route.legs) || [];
  let ok = legs.length === 2;
  legs.forEach((l, i) => {
    const p = R.decodePolyline((l.polyline && l.polyline.encodedPolyline) || "");
    const t = turns(p);
    console.log(`leg ${i + 1} (${i === 0 ? "rider → store" : "store → home"}): ${p.length} points, ${t} turns, ` +
      `${l.distanceMeters ?? "?"} m, ${l.duration ?? "?"}`);
    if (p.length < 10) ok = false;
  });
  console.log(`total: ${route ? `${route.distanceMeters ?? "?"} m, ${route.duration ?? "?"}` : "no route"}`);
  console.log(ok ? "ROUTES SMOKE: PASSED — road geometry returned" : "ROUTES SMOKE: FAILED — no road geometry");
  process.exit(ok ? 0 : 1);
})();
