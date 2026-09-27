import 'package:cloud_firestore/cloud_firestore.dart';

/// ADMR-29: a real, already-written `rider_support_tickets/{ticketId}`
/// document (functions/src/delivery/riderSupport.ts's own
/// `submitSupportRequestCore`). Read-only visibility model, scoped here to
/// tickets whose own `relatedTo` field points at a specific order — the
/// per-order link that surfaces on Order 360; the full unfiltered list
/// already has its own admin screen (`rider_support_screen.dart`), not
/// duplicated here.
class RiderSupportTicketRecord {
  final String ticketId;
  final String riderId;
  final String category; // delivery_issue | earnings_payouts | account_documents
  final String? relatedToType; // order | statement
  final String? relatedToId;
  final String message;
  final String status; // submitted | seen | closed
  final DateTime? createdAt;
  final DateTime? seenAt;
  final DateTime? closedAt;
  final String? resolutionNote;

  const RiderSupportTicketRecord({
    required this.ticketId,
    required this.riderId,
    required this.category,
    this.relatedToType,
    this.relatedToId,
    required this.message,
    required this.status,
    this.createdAt,
    this.seenAt,
    this.closedAt,
    this.resolutionNote,
  });

  String get categoryLabel {
    switch (category) {
      case 'delivery_issue':
        return 'Delivery issue';
      case 'earnings_payouts':
        return 'Earnings & payouts';
      case 'account_documents':
        return 'Account & documents';
      default:
        return category;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'submitted':
        return 'Submitted';
      case 'seen':
        return 'Seen';
      case 'closed':
        return 'Closed';
      default:
        return status;
    }
  }

  factory RiderSupportTicketRecord.fromMap(Map<String, dynamic> map, String ticketId) {
    DateTime? parseTs(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return null;
    }

    final relatedTo = map['relatedTo'];
    final relatedToMap = relatedTo is Map ? Map<String, dynamic>.from(relatedTo) : null;

    return RiderSupportTicketRecord(
      ticketId: ticketId,
      riderId: (map['riderId'] as String?) ?? '',
      category: (map['category'] as String?) ?? 'delivery_issue',
      relatedToType: relatedToMap?['type'] as String?,
      relatedToId: relatedToMap?['id'] as String?,
      message: (map['message'] as String?) ?? '',
      status: (map['status'] as String?) ?? 'submitted',
      createdAt: parseTs(map['createdAt']),
      seenAt: parseTs(map['seenAt']),
      closedAt: parseTs(map['closedAt']),
      resolutionNote: map['resolutionNote'] as String?,
    );
  }
}
