import 'package:cloud_firestore/cloud_firestore.dart';

/// Lifecycle status of a [CustomerEnrollmentModel]. Stored as a plain
/// string. Anything outside [values] parses to [pendingEnrollment] — never
/// [active] or [benefitEligible].
class BenefitEnrollmentStatus {
  BenefitEnrollmentStatus._();

  static const String pendingEnrollment = 'pendingEnrollment';
  static const String active = 'active';
  static const String benefitEligible = 'benefitEligible';
  static const String benefitPending = 'benefitPending';
  static const String suspended = 'suspended';
  static const String completed = 'completed';
  static const String closed = 'closed';

  static const List<String> values = [
    pendingEnrollment,
    active,
    benefitEligible,
    benefitPending,
    suspended,
    completed,
    closed,
  ];

  static const List<String> accrualEligible = [active, benefitEligible];

  static String parse(dynamic value) {
    if (value is String && values.contains(value)) return value;
    return pendingEnrollment;
  }
}

/// A RECORD of a customer's participation in a Customer Product Benefit
/// Program — created only by the admin-only `createBenefitEnrollment`
/// callable (functions/src/customer/benefitEnrollment.ts). This is not a
/// purchase flow: `programAmount` is a recorded number describing an
/// arrangement agreed elsewhere; nothing in this model or its writer
/// accepts, holds, or moves money.
///
/// Stored at /benefit_enrollments/{enrollmentId} — Cloud-Function
/// write-only, readable by its owner (customerId) or an admin.
class CustomerEnrollmentModel {
  final String id;
  final String customerId;
  final String programId;
  final String status;
  final double programAmount;

  /// The program's rulesVersion at the moment of enrollment — preserved so
  /// a later program config change never retroactively changes what this
  /// enrollment was promised.
  final int rulesVersionAtEnrollment;

  final DateTime enrollmentDate;
  final DateTime startDate;
  final DateTime maturityDate;
  final DateTime? completionDate;

  final String consentTermsVersion;
  final DateTime? consentAcceptedAt;
  final Map<String, dynamic>? consentMetadata;

  /// 'YYYY-MM' of the last period this enrollment was accrued for, or null
  /// if never accrued.
  final String? lastAccrualPeriod;

  final DateTime createdAt;
  final DateTime updatedAt;

  const CustomerEnrollmentModel({
    required this.id,
    required this.customerId,
    required this.programId,
    this.status = BenefitEnrollmentStatus.pendingEnrollment,
    this.programAmount = 0,
    this.rulesVersionAtEnrollment = 1,
    required this.enrollmentDate,
    required this.startDate,
    required this.maturityDate,
    this.completionDate,
    this.consentTermsVersion = '',
    this.consentAcceptedAt,
    this.consentMetadata,
    this.lastAccrualPeriod,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CustomerEnrollmentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CustomerEnrollmentModel.fromMap(data, doc.id);
  }

  factory CustomerEnrollmentModel.fromMap(Map<String, dynamic> map, String id) {
    return CustomerEnrollmentModel(
      id: id,
      customerId: (map['customerId'] as String?) ?? '',
      programId: (map['programId'] as String?) ?? '',
      status: BenefitEnrollmentStatus.parse(map['status']),
      programAmount: (map['programAmount'] as num?)?.toDouble() ?? 0,
      rulesVersionAtEnrollment: (map['rulesVersionAtEnrollment'] as num?)?.toInt() ?? 1,
      enrollmentDate: _parseDateTime(map['enrollmentDate']),
      startDate: _parseDateTime(map['startDate']),
      maturityDate: _parseDateTime(map['maturityDate']),
      completionDate: _parseNullableDateTime(map['completionDate']),
      consentTermsVersion: (map['consentTermsVersion'] as String?) ?? '',
      consentAcceptedAt: _parseNullableDateTime(map['consentAcceptedAt']),
      consentMetadata: (map['consentMetadata'] as Map?)?.map((k, v) => MapEntry(k.toString(), v)),
      lastAccrualPeriod: map['lastAccrualPeriod'] as String?,
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'programId': programId,
      'status': status,
      'programAmount': programAmount,
      'rulesVersionAtEnrollment': rulesVersionAtEnrollment,
      'enrollmentDate': Timestamp.fromDate(enrollmentDate),
      'startDate': Timestamp.fromDate(startDate),
      'maturityDate': Timestamp.fromDate(maturityDate),
      'completionDate': completionDate == null ? null : Timestamp.fromDate(completionDate!),
      'consentTermsVersion': consentTermsVersion,
      'consentAcceptedAt': consentAcceptedAt == null ? null : Timestamp.fromDate(consentAcceptedAt!),
      'consentMetadata': consentMetadata,
      'lastAccrualPeriod': lastAccrualPeriod,
      'createdAt': Timestamp.fromDate(createdAt),
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

  bool get isAccrualEligible => BenefitEnrollmentStatus.accrualEligible.contains(status);

  CustomerEnrollmentModel copyWith({
    String? id,
    String? customerId,
    String? programId,
    String? status,
    double? programAmount,
    int? rulesVersionAtEnrollment,
    DateTime? enrollmentDate,
    DateTime? startDate,
    DateTime? maturityDate,
    DateTime? completionDate,
    String? consentTermsVersion,
    DateTime? consentAcceptedAt,
    Map<String, dynamic>? consentMetadata,
    String? lastAccrualPeriod,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomerEnrollmentModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      programId: programId ?? this.programId,
      status: status ?? this.status,
      programAmount: programAmount ?? this.programAmount,
      rulesVersionAtEnrollment: rulesVersionAtEnrollment ?? this.rulesVersionAtEnrollment,
      enrollmentDate: enrollmentDate ?? this.enrollmentDate,
      startDate: startDate ?? this.startDate,
      maturityDate: maturityDate ?? this.maturityDate,
      completionDate: completionDate ?? this.completionDate,
      consentTermsVersion: consentTermsVersion ?? this.consentTermsVersion,
      consentAcceptedAt: consentAcceptedAt ?? this.consentAcceptedAt,
      consentMetadata: consentMetadata ?? this.consentMetadata,
      lastAccrualPeriod: lastAccrualPeriod ?? this.lastAccrualPeriod,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'CustomerEnrollment($id: customer=$customerId, program=$programId, $status)';
}
