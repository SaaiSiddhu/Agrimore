// Phase DLV-3B — the rider's route card logic (lib/navigation/rider_navigation.dart).
import 'package:agrimore_core/agrimore_core.dart';
import 'package:delivery/navigation/rider_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const store = DeliveryPoint(lat: 9.9252, lng: 78.1198);
  const km = 1 / 111.2;

  test('the step decides the leg: store until pickup, customer after', () {
    expect(riderLegFor(taskStatusForStep(0)), RiderLeg.toStore); // accepted
    expect(riderLegFor(taskStatusForStep(1)), RiderLeg.toStore); // at the store
    expect(riderLegFor(taskStatusForStep(2)), RiderLeg.toCustomer); // picked up
    expect(riderLegFor(taskStatusForStep(3)), RiderLeg.toCustomer); // out for delivery
    expect(riderLegFor(taskStatusForStep(4)), isNull); // delivered: no card
  });

  test('Navigate opens Google Maps turn-by-turn in two-wheeler mode', () {
    final u = turnByTurnUri(store);
    expect(u.toString(), 'google.navigation:q=9.925200,78.119800&mode=l');
    final w = directionsUri(store);
    expect(w.host, 'www.google.com');
    expect(w.path, '/maps/dir/');
    expect(w.queryParameters['api'], '1');
    expect(w.queryParameters['destination'], '9.925200,78.119800');
    expect(w.queryParameters['travelmode'], 'two-wheeler');
    expect(w.queryParameters['dir_action'], 'navigate');
  });

  test('what is left of the leg: road metres and a scaled duration', () {
    final leg = [
      store,
      const DeliveryPoint(lat: 9.9252 + 1 * km, lng: 78.1198),
      const DeliveryPoint(lat: 9.9252 + 2 * km, lng: 78.1198),
    ];
    expect(polylineMeters(leg), closeTo(2000, 5));
    final half = legRemaining(leg: leg, ahead: leg.sublist(1), legSeconds: 600);
    expect(half.meters, closeTo(1000, 5));
    expect(half.seconds, closeTo(300, 2));
    expect(legSummary(half), '5 min · 1.0 km');
    expect(legSummary(const LegRemaining(347, 40)), '1 min · 350 m');
    expect(legSummary(const LegRemaining(2600, null)), '2.6 km');
  });

  test('camera zoom fits the points; one point is street level', () {
    final near = fitZoomFor([store, const DeliveryPoint(lat: 9.9252 + 3 * km, lng: 78.1198)], widthPx: 340, heightPx: 192);
    final far = fitZoomFor([store, const DeliveryPoint(lat: 9.9252 + 30 * km, lng: 78.1198)], widthPx: 340, heightPx: 192);
    expect(near, inInclusiveRange(12, 15));
    expect(far, closeTo(near - 3.32, 0.1)); // 10× the span ≈ 3.3 zoom levels out
    expect(fitZoomFor([store], widthPx: 300, heightPx: 200), 17);
  });
}
