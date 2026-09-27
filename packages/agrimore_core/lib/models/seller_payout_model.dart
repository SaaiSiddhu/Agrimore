import 'package:cloud_firestore/cloud_firestore.dart';

/// ADMR-30: a real, already-written `seller_payouts/{orderId}_{sellerId}`
/// document (functions/src/customer/sellerNotifications.ts's own
/// per-delivered-order payout creation, carried through pending/requested/
/// paid by functions/src/seller/sellerWallet.ts). A multi-vendor order can
/// have more than one of these — one per distinct seller among its items —
/// so this is always queried as a list by `orderId`, never fetched as a
/// single doc. Read-only visibility model; nothing here writes back.
class SellerPayoutRecord {
  final String id;
  final String sellerId;
  final String orderId;
  final String? orderNumber;
  final double grossAmount;
  final double commissionRate;
  final double commissionAmount;
  final double netAmount;
  final String status; // pending | requested | paid
  final int? itemCount;
  final DateTime? createdAt;
  final DateTime? paidAt;
  final String? paidBy;
  final String? paymentReference;
  final String? payoutMethod;
  final String? withdrawalId;

  const SellerPayoutRecord({
    required this.id,
    required this.sellerId,
    required this.orderId,
    this.orderNumber,
    required this.grossAmount,
    required this.commissionRate,
    required this.commissionAmount,
    required this.netAmount,
    required this.status,
    this.itemCount,
    this.createdAt,
    this.paidAt,
    this.paidBy,
    this.paymentReference,
    this.payoutMethod,
    this.withdrawalId,
  });

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'requested':
        return 'Requested';
      case 'paid':
        return 'Paid';
      default:
        return status;
    }
  }

  factory SellerPayoutRecord.fromMap(Map<String, dynamic> map, String id) {
    DateTime? parseTs(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return null;
    }

    return SellerPayoutRecord(
      id: id,
      sellerId: (map['sellerId'] as String?) ?? '',
      orderId: (map['orderId'] as String?) ?? '',
      orderNumber: map['orderNumber'] as String?,
      grossAmount: (map['grossAmount'] as num?)?.toDouble() ?? 0.0,
      commissionRate: (map['commissionRate'] as num?)?.toDouble() ?? 0.0,
      commissionAmount: (map['commissionAmount'] as num?)?.toDouble() ?? 0.0,
      netAmount: (map['netAmount'] as num?)?.toDouble() ??
          (map['amount'] as num?)?.toDouble() ??
          0.0,
      status: (map['status'] as String?) ?? 'pending',
      itemCount: (map['itemCount'] as num?)?.toInt(),
      createdAt: parseTs(map['createdAt']),
      paidAt: parseTs(map['paidAt']),
      paidBy: map['paidBy'] as String?,
      paymentReference: map['paymentReference'] as String?,
      payoutMethod: map['payoutMethod'] as String?,
      withdrawalId: map['withdrawalId'] as String?,
    );
  }
}
