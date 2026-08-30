import 'package:cloud_firestore/cloud_firestore.dart';

/// A PROJECTION of a customer's Product Credit balance — fast to read, but
/// never authoritative. The /product_credit_ledger/{entryId} collection is
/// the source of truth; this document exists purely so a client doesn't
/// have to sum the ledger on every read. Stored at
/// /product_credit_balances/{customerId}, Cloud-Function write-only,
/// updated only by `appendLedgerEntry`
/// (functions/src/customer/productCreditLedger.ts) in the same transaction
/// as the ledger entry that changed it — see that file for why the two can
/// never diverge, and `reconcileProductCreditBalances` for how drift is
/// detected/corrected if it ever does.
class ProductCreditBalanceModel {
  final String customerId;
  final double available;
  final double pending;
  final double onHold;
  final double lifetimeEarned;
  final double lifetimeUsed;
  final double lifetimeExpired;
  final DateTime? nextCreditDate;
  final String? lastLedgerEntryId;
  final DateTime updatedAt;

  const ProductCreditBalanceModel({
    required this.customerId,
    this.available = 0,
    this.pending = 0,
    this.onHold = 0,
    this.lifetimeEarned = 0,
    this.lifetimeUsed = 0,
    this.lifetimeExpired = 0,
    this.nextCreditDate,
    this.lastLedgerEntryId,
    required this.updatedAt,
  });

  /// The fail-closed default: every balance zero. Used whenever
  /// /product_credit_balances/{customerId} does not exist — a customer
  /// with no ledger entries has no credit, not an error.
  factory ProductCreditBalanceModel.zero(String customerId) {
    return ProductCreditBalanceModel(
      customerId: customerId,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  factory ProductCreditBalanceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ProductCreditBalanceModel.fromMap(data, doc.id);
  }

  factory ProductCreditBalanceModel.fromMap(Map<String, dynamic> map, String customerId) {
    return ProductCreditBalanceModel(
      customerId: customerId,
      available: (map['available'] as num?)?.toDouble() ?? 0,
      pending: (map['pending'] as num?)?.toDouble() ?? 0,
      onHold: (map['onHold'] as num?)?.toDouble() ?? 0,
      lifetimeEarned: (map['lifetimeEarned'] as num?)?.toDouble() ?? 0,
      lifetimeUsed: (map['lifetimeUsed'] as num?)?.toDouble() ?? 0,
      lifetimeExpired: (map['lifetimeExpired'] as num?)?.toDouble() ?? 0,
      nextCreditDate: _parseNullableDateTime(map['nextCreditDate']),
      lastLedgerEntryId: map['lastLedgerEntryId'] as String?,
      updatedAt: _parseDateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'available': available,
      'pending': pending,
      'onHold': onHold,
      'lifetimeEarned': lifetimeEarned,
      'lifetimeUsed': lifetimeUsed,
      'lifetimeExpired': lifetimeExpired,
      'nextCreditDate': nextCreditDate == null ? null : Timestamp.fromDate(nextCreditDate!),
      'lastLedgerEntryId': lastLedgerEntryId,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static DateTime? _parseNullableDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  ProductCreditBalanceModel copyWith({
    String? customerId,
    double? available,
    double? pending,
    double? onHold,
    double? lifetimeEarned,
    double? lifetimeUsed,
    double? lifetimeExpired,
    DateTime? nextCreditDate,
    String? lastLedgerEntryId,
    DateTime? updatedAt,
  }) {
    return ProductCreditBalanceModel(
      customerId: customerId ?? this.customerId,
      available: available ?? this.available,
      pending: pending ?? this.pending,
      onHold: onHold ?? this.onHold,
      lifetimeEarned: lifetimeEarned ?? this.lifetimeEarned,
      lifetimeUsed: lifetimeUsed ?? this.lifetimeUsed,
      lifetimeExpired: lifetimeExpired ?? this.lifetimeExpired,
      nextCreditDate: nextCreditDate ?? this.nextCreditDate,
      lastLedgerEntryId: lastLedgerEntryId ?? this.lastLedgerEntryId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'ProductCreditBalance($customerId: available=$available, onHold=$onHold)';
}
