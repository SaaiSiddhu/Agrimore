import 'package:cloud_firestore/cloud_firestore.dart';

/// The seven Product Credit ledger entry types (D3). All seven are defined
/// now, even though Phase B's own code paths only ever write CREDIT,
/// EXPIRY, and ADJUSTMENT — HOLD/RELEASE/REDEMPTION/REVERSAL exist so
/// Phase C (redemption) needs no schema migration.
class ProductCreditLedgerEntryType {
  ProductCreditLedgerEntryType._();

  static const String credit = 'CREDIT';
  static const String redemption = 'REDEMPTION';
  static const String reversal = 'REVERSAL';
  static const String expiry = 'EXPIRY';
  static const String adjustment = 'ADJUSTMENT';
  static const String hold = 'HOLD';
  static const String release = 'RELEASE';

  static const List<String> values = [
    credit,
    redemption,
    reversal,
    expiry,
    adjustment,
    hold,
    release,
  ];

  /// Unmatched/missing values parse to [adjustment] rather than [credit] —
  /// the safest fallback, since an ADJUSTMENT's direction is always
  /// explicit (metadata.direction) rather than implied by type alone.
  static String parse(dynamic value) {
    if (value is String && values.contains(value)) return value;
    return adjustment;
  }
}

/// An immutable entry in the Product Credit ledger — the source of truth
/// for a customer's Product Credit. Stored at
/// /product_credit_ledger/{entryId}, Cloud-Function write-only, append-only
/// (create/update/delete all false in firestore.rules for every client).
/// `amount` is always positive; direction is carried entirely by `type` —
/// see functions/src/customer/productCreditLedger.ts's appendLedgerEntry
/// for the exact arithmetic each type applies to the balance projection.
class ProductCreditLedgerModel {
  final String id;
  final String customerId;
  final String enrollmentId;
  final String type;

  /// Always >= 0. Direction is carried by [type], never by sign.
  final double amount;

  /// 'YYYY-MM', set on CREDIT entries produced by the accrual engine.
  final String? period;

  final String status;
  final String? referenceId;

  /// For REVERSAL/RELEASE: the id of the ledger entry this one reverses or
  /// releases.
  final String? relatedEntryId;

  /// Null until Phase C (redemption) exists.
  final String? orderId;

  final DateTime? expiresAt;
  final String description;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  const ProductCreditLedgerModel({
    required this.id,
    required this.customerId,
    required this.enrollmentId,
    required this.type,
    required this.amount,
    this.period,
    this.status = 'posted',
    this.referenceId,
    this.relatedEntryId,
    this.orderId,
    this.expiresAt,
    this.description = '',
    this.metadata,
    required this.createdAt,
  });

  factory ProductCreditLedgerModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ProductCreditLedgerModel.fromMap(data, doc.id);
  }

  factory ProductCreditLedgerModel.fromMap(Map<String, dynamic> map, String id) {
    return ProductCreditLedgerModel(
      id: id,
      customerId: (map['customerId'] as String?) ?? '',
      enrollmentId: (map['enrollmentId'] as String?) ?? '',
      type: ProductCreditLedgerEntryType.parse(map['type']),
      amount: ((map['amount'] as num?) ?? 0).abs().toDouble(),
      period: map['period'] as String?,
      status: (map['status'] as String?) ?? 'posted',
      referenceId: map['referenceId'] as String?,
      relatedEntryId: map['relatedEntryId'] as String?,
      orderId: map['orderId'] as String?,
      expiresAt: _parseNullableDateTime(map['expiresAt']),
      description: (map['description'] as String?) ?? '',
      metadata: (map['metadata'] as Map?)?.map((k, v) => MapEntry(k.toString(), v)),
      createdAt: _parseDateTime(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'enrollmentId': enrollmentId,
      'type': type,
      'amount': amount,
      'period': period,
      'status': status,
      'referenceId': referenceId,
      'relatedEntryId': relatedEntryId,
      'orderId': orderId,
      'expiresAt': expiresAt == null ? null : Timestamp.fromDate(expiresAt!),
      'description': description,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
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

  ProductCreditLedgerModel copyWith({
    String? id,
    String? customerId,
    String? enrollmentId,
    String? type,
    double? amount,
    String? period,
    String? status,
    String? referenceId,
    String? relatedEntryId,
    String? orderId,
    DateTime? expiresAt,
    String? description,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) {
    return ProductCreditLedgerModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      enrollmentId: enrollmentId ?? this.enrollmentId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      period: period ?? this.period,
      status: status ?? this.status,
      referenceId: referenceId ?? this.referenceId,
      relatedEntryId: relatedEntryId ?? this.relatedEntryId,
      orderId: orderId ?? this.orderId,
      expiresAt: expiresAt ?? this.expiresAt,
      description: description ?? this.description,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'ProductCreditLedger($id: $type ₹$amount for $customerId)';
}
