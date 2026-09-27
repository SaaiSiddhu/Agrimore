import 'package:cloud_firestore/cloud_firestore.dart';

/// ADMR-29: a real, already-written `commission_exceptions/{id}` document —
/// functions/src/customer/employeeCommission.ts writes one instead of
/// silently paying nothing when a commission rate cannot be resolved for an
/// attributed order. Read-only visibility model; nothing here writes back
/// (the existing `commission_exceptions_screen.dart` is the retry surface,
/// not duplicated here).
class CommissionExceptionRecord {
  final String id;
  final String orderId;
  final String? orderNumber;
  final String employeeUid;
  final String orderMode; // B2C | B2B
  final double? total;
  final String reason;
  final String status; // unresolved | resolved
  final DateTime? createdAt;

  const CommissionExceptionRecord({
    required this.id,
    required this.orderId,
    this.orderNumber,
    required this.employeeUid,
    required this.orderMode,
    this.total,
    required this.reason,
    required this.status,
    this.createdAt,
  });

  factory CommissionExceptionRecord.fromMap(Map<String, dynamic> map, String id) {
    DateTime? parseTs(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return null;
    }

    return CommissionExceptionRecord(
      id: id,
      orderId: (map['orderId'] as String?) ?? '',
      orderNumber: map['orderNumber'] as String?,
      employeeUid: (map['employeeUid'] as String?) ?? '',
      orderMode: (map['orderMode'] as String?) ?? 'B2C',
      total: (map['total'] as num?)?.toDouble(),
      reason: (map['reason'] as String?) ?? 'unknown',
      status: (map['status'] as String?) ?? 'unresolved',
      createdAt: parseTs(map['createdAt']),
    );
  }
}
