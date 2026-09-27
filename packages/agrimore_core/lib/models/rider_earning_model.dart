import 'package:cloud_firestore/cloud_firestore.dart';

/// ADMR-29: a real, already-written `rider_earnings/{orderId}` document —
/// exactly one per delivered order (functions/src/delivery/riderMoney.ts's
/// own `recordDeliveryEarningCore`, the order's own id is the doc id, so a
/// direct `.doc(orderId).get()` needs no query at all). Read-only
/// visibility model; nothing here writes back to this collection.
class PayLineRecord {
  final String type; // trip_base | distance | waiting
  final double amount;
  final double? km;
  final int? minutes;

  const PayLineRecord({
    required this.type,
    required this.amount,
    this.km,
    this.minutes,
  });

  factory PayLineRecord.fromMap(Map<String, dynamic> map) {
    return PayLineRecord(
      type: (map['type'] as String?) ?? 'trip_base',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      km: (map['km'] as num?)?.toDouble(),
      minutes: (map['minutes'] as num?)?.toInt(),
    );
  }

  String get label {
    switch (type) {
      case 'trip_base':
        return 'Trip base';
      case 'distance':
        return 'Distance';
      case 'waiting':
        return 'Waiting';
      default:
        return type;
    }
  }
}

class RiderEarningRecord {
  final String orderId;
  final String riderId;
  final String? orderNumber;
  final List<PayLineRecord> lines;
  final double total;
  final double km;
  final String kmSource; // route | straight_line | none
  final int waitMinutes;
  final double codCollected;
  final String? statementId;
  final DateTime? createdAt;

  const RiderEarningRecord({
    required this.orderId,
    required this.riderId,
    this.orderNumber,
    required this.lines,
    required this.total,
    required this.km,
    required this.kmSource,
    required this.waitMinutes,
    required this.codCollected,
    this.statementId,
    this.createdAt,
  });

  /// Not yet swept into a weekly `rider_payouts` statement — a real,
  /// honest "not yet settled" state, not an invented one.
  bool get isSettled => statementId != null;

  factory RiderEarningRecord.fromMap(Map<String, dynamic> map, String orderId) {
    DateTime? parseTs(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return null;
    }

    final rawLines = map['lines'];
    return RiderEarningRecord(
      orderId: orderId,
      riderId: (map['riderId'] as String?) ?? '',
      orderNumber: map['orderNumber'] as String?,
      lines: rawLines is List
          ? rawLines
              .whereType<Map>()
              .map((l) => PayLineRecord.fromMap(Map<String, dynamic>.from(l)))
              .toList()
          : const [],
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      km: (map['km'] as num?)?.toDouble() ?? 0.0,
      kmSource: (map['kmSource'] as String?) ?? 'none',
      waitMinutes: (map['waitMinutes'] as num?)?.toInt() ?? 0,
      codCollected: (map['codCollected'] as num?)?.toDouble() ?? 0.0,
      statementId: map['statementId'] as String?,
      createdAt: parseTs(map['createdAt']),
    );
  }
}
