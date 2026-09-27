import 'package:cloud_firestore/cloud_firestore.dart';

/// ADMR-28: a real, already-written `delivery_requests/{orderId}_{riderId}`
/// document — one per rider ever offered an order (functions/src/delivery/
/// dispatch.ts's own `sendOffers`). Read-only visibility model; nothing
/// here writes back to this collection.
class DispatchOfferRecord {
  final String riderId;
  final String status; // offered | dispatching | expired | withdrawn | accepted | declined
  final int wave;
  final double? pickupDistanceKm;
  final double? dropDistanceKm;
  final double? estimatedPay;
  final double? codAmount;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  const DispatchOfferRecord({
    required this.riderId,
    required this.status,
    required this.wave,
    this.pickupDistanceKm,
    this.dropDistanceKm,
    this.estimatedPay,
    this.codAmount,
    this.createdAt,
    this.expiresAt,
  });

  factory DispatchOfferRecord.fromMap(Map<String, dynamic> map) {
    DateTime? parseTs(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return null;
    }

    return DispatchOfferRecord(
      // dispatch.ts writes both `riderId` and a legacy-alias `partnerId` —
      // prefer riderId, fall back for any older-shaped record.
      riderId: (map['riderId'] ?? map['partnerId'] ?? '') as String,
      status: (map['status'] as String?) ?? 'offered',
      wave: (map['wave'] as num?)?.toInt() ?? 1,
      pickupDistanceKm: (map['pickupDistanceKm'] as num?)?.toDouble(),
      dropDistanceKm: (map['dropDistanceKm'] as num?)?.toDouble(),
      estimatedPay: (map['estimatedPay'] as num?)?.toDouble(),
      codAmount: (map['codAmount'] as num?)?.toDouble(),
      createdAt: parseTs(map['createdAt']),
      expiresAt: parseTs(map['expiresAt']),
    );
  }

  String get statusDisplayName {
    switch (status) {
      case 'offered':
        return 'Offered';
      case 'dispatching':
        return 'Dispatching';
      case 'expired':
        return 'Expired';
      case 'withdrawn':
        return 'Withdrawn';
      case 'accepted':
        return 'Accepted';
      case 'declined':
        return 'Declined';
      default:
        return status;
    }
  }
}
