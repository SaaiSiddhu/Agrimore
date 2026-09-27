import 'package:cloud_firestore/cloud_firestore.dart';

/// ADMR-49: a real, already-written `payment_security_logs/{logId}` document
/// (functions/src/customer/payment.ts's/wallet.ts's own signature-mismatch
/// handling) — recorded every time a Razorpay HMAC signature check fails on
/// a payment or wallet top-up verification. firestore.rules already grants
/// `allow read: if isAdmin()` on this collection; this is a read-only
/// visibility model, nothing here changes what gets written or when.
class PaymentSecurityLogRecord {
  final String logId;
  final String type; // wallet_topup_signature_mismatch | signature_mismatch | (future values)
  final String paymentId;
  final String orderId;
  final String? uid;
  final int receivedSignatureLength;
  final bool signatureMatched;
  final DateTime? flaggedAt;

  const PaymentSecurityLogRecord({
    required this.logId,
    required this.type,
    required this.paymentId,
    required this.orderId,
    this.uid,
    required this.receivedSignatureLength,
    required this.signatureMatched,
    this.flaggedAt,
  });

  String get typeLabel {
    switch (type) {
      case 'wallet_topup_signature_mismatch':
        return 'Wallet top-up signature mismatch';
      case 'signature_mismatch':
        return 'Payment signature mismatch';
      default:
        return type;
    }
  }

  factory PaymentSecurityLogRecord.fromMap(Map<String, dynamic> map, String logId) {
    DateTime? parseTs(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return null;
    }

    return PaymentSecurityLogRecord(
      logId: logId,
      type: (map['type'] as String?) ?? 'signature_mismatch',
      paymentId: (map['paymentId'] as String?) ?? '',
      orderId: (map['orderId'] as String?) ?? '',
      uid: map['uid'] as String?,
      receivedSignatureLength: (map['receivedSignatureLength'] as num?)?.toInt() ?? 0,
      signatureMatched: (map['signatureMatched'] as bool?) ?? false,
      flaggedAt: parseTs(map['flaggedAt']),
    );
  }
}
