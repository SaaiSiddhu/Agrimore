// Phase DLV-S2 — admin Rider Incidents helpers (rider_incidents_admin.dart).
import 'package:agrimore_admin/screens/admin/delivery/rider_incidents_admin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final at = DateTime.utc(2026, 9, 24, 10);

  test('position lines say how far to trust the point', () {
    expect(incidentLocationLine(null, at), startsWith('No position'));
    expect(incidentLocationLine({'freshness': 'unavailable'}, at), startsWith('No position'));
    expect(
      incidentLocationLine({'freshness': 'fresh', 'source': 'device', 'lat': 9.9, 'lng': 78.1, 'accuracy': 8.6, 'isMocked': false, 'at': at}, at),
      "Phone's position at the report · ±9 m",
    );
    expect(
      incidentLocationLine({'freshness': 'fresh', 'source': 'device', 'lat': 9.9, 'lng': 78.1, 'isMocked': true, 'at': at}, at),
      contains('MOCK LOCATION'),
    );
    expect(
      incidentLocationLine({'freshness': 'fresh', 'source': 'server', 'lat': 9.9, 'lng': 78.1, 'at': at.subtract(const Duration(seconds: 90))}, at),
      'Last shared position, 1 min before the report',
    );
    expect(
      incidentLocationLine({'freshness': 'stale', 'source': 'server', 'lat': 9.9, 'lng': 78.1, 'at': at.subtract(const Duration(hours: 3))}, at),
      'Old position — last shared 3 h before the report',
    );
  });

  test('map link only with a real point', () {
    expect(incidentMapsUrl({'lat': 9.93, 'lng': 78.12}), 'https://www.google.com/maps/search/?api=1&query=9.93,78.12');
    expect(incidentMapsUrl({'freshness': 'unavailable'}), isNull);
    expect(incidentMapsUrl(null), isNull);
  });

  test('orders line calls out more than one active order', () {
    expect(incidentOrdersLine(const []), 'No active order');
    expect(incidentOrdersLine(['o1']), 'Order o1');
    expect(incidentOrdersLine(['o1', 'o2']), '2 active orders — check each: o1, o2');
    expect(incidentOrdersLine(null), 'No active order');
  });

  test('resolution bounds match the server (3–500 after trim)', () {
    expect(resolutionError('  ok '), isNotNull);
    expect(resolutionError('Called; safe'), isNull);
    expect(resolutionError('x' * 501), isNotNull);
    expect(resolutionError('x' * 500), isNull);
  });

  test('labels and refusals', () {
    expect(incidentStatusLabel('reported'), 'New — not acknowledged');
    expect(incidentStatusLabel('resolved'), 'Resolved');
    expect(incidentRefusal('failed-precondition', 'already_resolved'), contains('already resolved'));
    expect(incidentRefusal('permission-denied', null), 'Only admins can update incidents.');
    expect(ageLabel(const Duration(seconds: 20)), 'just now');
    expect(ageLabel(const Duration(days: 3)), '3 days');
    expect(openIncidentStatuses, ['reported', 'acknowledged']);
  });
}
