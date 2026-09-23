// lib/navigation/rider_navigation.dart
//
// Phase DLV-3B — the rider's way to the store, then to the customer, the
// way Swiggy/Zomato riders get it: an in-app map drawing the same road route
// the customer sees (delivery_tasks/{orderId}.route, D-DLV-ROUTES), and one
// tap into Google Maps turn-by-turn in two-wheeler mode for the actual ride.
// Pure: no Flutter, no plugins — covered by test/rider_navigation_test.dart.
import 'dart:math' as math;

import 'package:agrimore_core/agrimore_core.dart';

/// Where the rider is heading now.
enum RiderLeg { toStore, toCustomer }

/// The active-order screen's step, as the delivery-task status the shared
/// route logic understands (DeliveryRoute.legsAhead). Local, so the card
/// switches the moment the rider taps a step, not when the projection lands.
/// Order of [stepIndex]: accepted, arrived at store, picked up, out for
/// delivery, delivered.
DeliveryTaskStatus? taskStatusForStep(int stepIndex) => switch (stepIndex) {
      0 => DeliveryTaskStatus.assigned,
      1 => DeliveryTaskStatus.atPickup,
      2 => DeliveryTaskStatus.pickedUp,
      3 => DeliveryTaskStatus.enRoute,
      _ => null,
    };

RiderLeg? riderLegFor(DeliveryTaskStatus? status) => switch (status) {
      DeliveryTaskStatus.assigned || DeliveryTaskStatus.atPickup => RiderLeg.toStore,
      DeliveryTaskStatus.pickedUp || DeliveryTaskStatus.enRoute || DeliveryTaskStatus.atDrop => RiderLeg.toCustomer,
      _ => null,
    };

String _ll(DeliveryPoint p) => '${p.lat.toStringAsFixed(6)},${p.lng.toStringAsFixed(6)}';

/// Google Maps turn-by-turn, two-wheeler (`mode=l`), straight into
/// navigation — the Android "google.navigation:" intent.
Uri turnByTurnUri(DeliveryPoint dest) => Uri.parse('google.navigation:q=${_ll(dest)}&mode=l');

/// The universal Maps URL — used where the intent has no handler (no Google
/// Maps app, web). `dir_action=navigate` starts navigation when the phone is
/// near the origin, else shows the route preview.
Uri directionsUri(DeliveryPoint dest) => Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': _ll(dest),
      'travelmode': 'two-wheeler',
      'dir_action': 'navigate',
    });

double _meters(DeliveryPoint a, DeliveryPoint b) =>
    DeliveryEtaCalculator.straightLineKm(a.lat, a.lng, b.lat, b.lng) * 1000;

/// Length of a polyline in metres.
double polylineMeters(List<DeliveryPoint> line) {
  var total = 0.0;
  for (var i = 1; i < line.length; i++) {
    total += _meters(line[i - 1], line[i]);
  }
  return total;
}

/// What is left of the active leg for the headline: metres along the road
/// from the rider, and the leg's own duration scaled to what is left.
class LegRemaining {
  final double meters;
  final int? seconds;
  const LegRemaining(this.meters, this.seconds);
}

LegRemaining legRemaining({
  required List<DeliveryPoint> leg,
  required List<DeliveryPoint> ahead,
  int? legSeconds,
}) {
  final total = polylineMeters(leg);
  final left = polylineMeters(ahead);
  final secs = legSeconds == null || total <= 0 ? null : (legSeconds * (left / total).clamp(0.0, 1.0)).round();
  return LegRemaining(left, secs);
}

/// "9 min · 2.6 km"; "1 min · 350 m" when close.
String legSummary(LegRemaining r) {
  // Round first, then pick the unit: 999.6 m is "1.0 km", not "1000 m".
  final tens = (r.meters / 10).round() * 10;
  final dist = tens < 1000 ? '$tens m' : '${(r.meters / 1000).toStringAsFixed(1)} km';
  if (r.seconds == null) return dist;
  final min = math.max(1, (r.seconds! / 60).ceil());
  return '$min min · $dist';
}

/// The Web-Mercator zoom at which the box around [pts] fits [widthPx] ×
/// [heightPx] (256-px tiles), clamped to 3–17. Computed rather than asking
/// the map (newLatLngBounds) — on web that ran before layout and left the
/// camera at zoom 0 (found on the customer screen, DLV-3B).
double fitZoomFor(List<DeliveryPoint> pts, {required double widthPx, required double heightPx}) {
  if (pts.isEmpty) return 15;
  double mercY(double lat) {
    final s = math.sin(lat.clamp(-85.0, 85.0) * math.pi / 180);
    return math.log((1 + s) / (1 - s)) / 2;
  }

  final lats = pts.map((p) => p.lat), lngs = pts.map((p) => p.lng);
  final lngSpan = lngs.reduce(math.max) - lngs.reduce(math.min);
  final ySpan = mercY(lats.reduce(math.max)) - mercY(lats.reduce(math.min));
  final w = math.max(widthPx, 1.0), h = math.max(heightPx, 1.0);
  final zx = lngSpan <= 1e-9 ? 17.0 : math.log(w * 360 / (lngSpan * 256)) / math.ln2;
  final zy = ySpan <= 1e-9 ? 17.0 : math.log(h * 2 * math.pi / (ySpan * 256)) / math.ln2;
  return math.min(zx, zy).clamp(3.0, 17.0);
}
