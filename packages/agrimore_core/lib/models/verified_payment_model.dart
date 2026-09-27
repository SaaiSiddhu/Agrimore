import 'package:cloud_firestore/cloud_firestore.dart';

/// ADMR-53: a real, already-written `verified_payments/{paymentId}` document
/// — written by functions/src/customer/payment.ts (checkout, real and
/// sandbox), functions/src/employee/razorpayOnboardingWebhook.ts (associate
/// onboarding), and read as proof-of-payment by seller/aiConnection.ts and
/// employee/activationCore.ts. Every real consumer reads this by a specific,
/// already-known paymentId (never a list query) — this is a read-only
/// support/reconciliation lookup model, nothing here changes what gets
/// written or when.
class VerifiedPaymentRecord {
  final String paymentId;
  final String? orderId;
  final String? userId;
  final String? status;
  final double? amount;
  final String? currency;
  final String? method;
  final String? bank;
  final String? email;
  final String? contact;
  final String? upiId;
  final bool signatureVerified;
  final bool isTest;
  final DateTime? verifiedAt;

  const VerifiedPaymentRecord({
    required this.paymentId,
    this.orderId,
    this.userId,
    this.status,
    this.amount,
    this.currency,
    this.method,
    this.bank,
    this.email,
    this.contact,
    this.upiId,
    this.signatureVerified = false,
    this.isTest = false,
    this.verifiedAt,
  });

  factory VerifiedPaymentRecord.fromMap(Map<String, dynamic> map, String paymentId) {
    DateTime? parseTs(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return null;
    }

    return VerifiedPaymentRecord(
      paymentId: paymentId,
      orderId: map['orderId'] as String?,
      userId: map['userId'] as String?,
      status: map['status'] as String?,
      amount: (map['amount'] as num?)?.toDouble(),
      currency: map['currency'] as String?,
      method: map['method'] as String?,
      bank: map['bank'] as String?,
      email: map['email'] as String?,
      contact: map['contact'] as String?,
      upiId: map['upiId'] as String?,
      signatureVerified: (map['signatureVerified'] as bool?) ?? false,
      isTest: (map['isTest'] as bool?) ?? false,
      verifiedAt: parseTs(map['verifiedAt']),
    );
  }
}
