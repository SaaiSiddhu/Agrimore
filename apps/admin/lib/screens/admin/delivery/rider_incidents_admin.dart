// lib/screens/admin/delivery/rider_incidents_admin.dart
//
// Phase DLV-S2 — pure helpers for the admin Rider Incidents screen, over the
// records reportRiderIncident writes (functions/src/delivery/riderIncidents.ts).
// The rider sees "Seen by the Agrimore team" only after Acknowledge, and the
// resolution text word for word — so both are deliberate admin actions.
// Covered by test/rider_incidents_admin_test.dart.

/// Statuses still needing the team.
const openIncidentStatuses = ['reported', 'acknowledged'];

String incidentStatusLabel(String? status) => switch (status) {
      'reported' => 'New — not acknowledged',
      'acknowledged' => 'Acknowledged',
      'resolved' => 'Resolved',
      _ => 'Unknown',
    };

/// "just now" / "7 min" / "3 h" / "2 days".
String ageLabel(Duration d) {
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min';
  if (d.inHours < 48) return '${d.inHours} h';
  return '${d.inDays} days';
}

DateTime? _time(Object? v) {
  if (v is DateTime) return v;
  try {
    return (v as dynamic)?.toDate() as DateTime?;
  } catch (_) {
    return null;
  }
}

num? _n(Object? v) => v is num && v.isFinite ? v : null;

/// Where the rider was, and how much to trust it — never a bare pin.
String incidentLocationLine(Map<String, dynamic>? loc, DateTime reportedAt) {
  final lat = _n(loc?['lat']), lng = _n(loc?['lng']);
  if (loc == null || loc['freshness'] == 'unavailable' || lat == null || lng == null) {
    return 'No position — the phone gave none and the rider had not shared one recently';
  }
  final at = _time(loc['at']);
  final before = at == null ? null : reportedAt.difference(at);
  if (loc['freshness'] == 'stale') {
    return 'Old position — last shared ${before == null ? 'at an unknown time' : '${ageLabel(before)} before the report'}';
  }
  if (loc['source'] == 'device') {
    final acc = _n(loc['accuracy']);
    return [
      "Phone's position at the report",
      if (acc != null) '±${acc.round()} m',
      if (loc['isMocked'] == true) 'MOCK LOCATION reported by the phone',
    ].join(' · ');
  }
  return 'Last shared position${before == null ? '' : ', ${ageLabel(before)} before the report'}';
}

/// A Google Maps link for the recorded position, or null.
String? incidentMapsUrl(Map<String, dynamic>? loc) {
  final lat = _n(loc?['lat']), lng = _n(loc?['lng']);
  if (lat == null || lng == null) return null;
  return 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
}

/// The orders on the rider at the time of the report.
String incidentOrdersLine(Object? ids) {
  final list = ids is List ? ids.whereType<String>().toList() : const <String>[];
  if (list.isEmpty) return 'No active order';
  if (list.length == 1) return 'Order ${list.first}';
  return '${list.length} active orders — check each: ${list.join(', ')}';
}

/// Same bounds as updateIncidentCore (3–500 characters after trimming).
String? resolutionError(String text) {
  final t = text.trim();
  if (t.length < 3) return 'Write what was done (at least 3 characters)';
  if (t.length > 500) return 'Keep it under 500 characters';
  return null;
}

/// Refusals from updateRiderIncident.
String incidentRefusal(String code, String? reason) => switch (reason) {
      'already_resolved' => 'Someone already resolved this incident.',
      'resolution_required' => 'Write what was done (3–500 characters).',
      'not_found' => 'This incident no longer exists.',
      _ =>
        code == 'permission-denied' ? 'Only admins can update incidents.' : 'Could not update the incident. Try again.',
    };
