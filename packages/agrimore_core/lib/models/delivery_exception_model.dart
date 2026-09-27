import 'package:cloud_firestore/cloud_firestore.dart';

/// ADMR-40: a real, already-written `delivery_exceptions/{exceptionId}`
/// document (functions/src/delivery/riderExceptions.ts's own
/// `reportExceptionCore`/`updateExceptionCore`) — a rider-reported failed
/// delivery attempt after pickup. Read-only visibility model; the full
/// unfiltered list already has its own admin screen
/// (`delivery_problems_screen.dart`), not duplicated here.
class DeliveryExceptionRecord {
  final String exceptionId;
  final String orderId;
  final String riderId;
  final String reason; // customer_unreachable | customer_refused | wrong_address | address_not_found | payment_issue | damaged_goods | vehicle_issue | safety | other
  final String? note;
  final String status; // reported | acknowledged | resolved
  final String custody; // rider | seller
  final String? disposition; // reattempt | returned_to_seller
  final String? resolution;
  final DateTime? createdAt;

  const DeliveryExceptionRecord({
    required this.exceptionId,
    required this.orderId,
    required this.riderId,
    required this.reason,
    this.note,
    required this.status,
    required this.custody,
    this.disposition,
    this.resolution,
    this.createdAt,
  });

  String get reasonLabel {
    switch (reason) {
      case 'customer_unreachable':
        return 'Customer unreachable';
      case 'customer_refused':
        return 'Customer refused delivery';
      case 'wrong_address':
        return 'Wrong address';
      case 'address_not_found':
        return 'Address not found';
      case 'payment_issue':
        return 'Payment issue (COD)';
      case 'damaged_goods':
        return 'Goods damaged';
      case 'vehicle_issue':
        return 'Rider vehicle issue';
      case 'safety':
        return 'Safety concern';
      default:
        return reason;
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

  factory DeliveryExceptionRecord.fromMap(Map<String, dynamic> map, String exceptionId) {
    DateTime? parseTs(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return null;
    }

    return DeliveryExceptionRecord(
      exceptionId: exceptionId,
      orderId: (map['orderId'] as String?) ?? '',
      riderId: (map['riderId'] as String?) ?? '',
      reason: (map['reason'] as String?) ?? 'other',
      note: map['note'] as String?,
      status: (map['status'] as String?) ?? 'reported',
      custody: (map['custody'] as String?) ?? 'rider',
      disposition: map['disposition'] as String?,
      resolution: map['resolution'] as String?,
      createdAt: parseTs(map['createdAt']),
    );
  }
}
