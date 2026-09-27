import 'package:cloud_firestore/cloud_firestore.dart';

/// ADMR-40: a real, already-written `rider_incidents/{incidentId}` document
/// (functions/src/delivery/riderIncidents.ts's own `reportIncidentCore`/
/// `updateIncidentCore`) — a rider's SOS/safety report, not necessarily
/// tied to any single order (`activeOrderIds` may hold several, or none).
/// Read-only visibility model; the full unfiltered list already has its
/// own admin screen (`rider_incidents_screen.dart`), not duplicated here.
class RiderIncidentRecord {
  final String incidentId;
  final String riderId;
  final String? riderName;
  final String kind; // sos (INCIDENT_KINDS today)
  final String? note;
  final String status; // reported | acknowledged | resolved
  final String? resolution;
  final List<String> activeOrderIds;
  final DateTime? createdAt;

  const RiderIncidentRecord({
    required this.incidentId,
    required this.riderId,
    this.riderName,
    required this.kind,
    this.note,
    required this.status,
    this.resolution,
    required this.activeOrderIds,
    this.createdAt,
  });

  String get kindLabel {
    switch (kind) {
      case 'sos':
        return 'Emergency (SOS)';
      default:
        return kind;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'reported':
        return 'Reported';
      case 'acknowledged':
        return 'Acknowledged';
      case 'resolved':
        return 'Resolved';
      default:
        return status;
    }
  }

  factory RiderIncidentRecord.fromMap(Map<String, dynamic> map, String incidentId) {
    DateTime? parseTs(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return null;
    }

    final rawIds = map['activeOrderIds'];
    return RiderIncidentRecord(
      incidentId: incidentId,
      riderId: (map['riderId'] as String?) ?? '',
      riderName: map['riderName'] as String?,
      kind: (map['kind'] as String?) ?? 'sos',
      note: map['note'] as String?,
      status: (map['status'] as String?) ?? 'reported',
      resolution: map['resolution'] as String?,
      activeOrderIds: rawIds is List ? rawIds.whereType<String>().toList() : const [],
      createdAt: parseTs(map['createdAt']),
    );
  }
}
