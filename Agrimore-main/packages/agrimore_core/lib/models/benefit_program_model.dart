import 'package:cloud_firestore/cloud_firestore.dart';

/// Lifecycle status of a [BenefitProgramModel]. Stored as a plain string in
/// Firestore. Anything outside [values] (missing, garbage) parses to
/// [draft] — the safest non-active state, never [active].
class BenefitProgramStatus {
  BenefitProgramStatus._();

  static const String draft = 'draft';
  static const String pendingApproval = 'pendingApproval';
  static const String active = 'active';
  static const String suspended = 'suspended';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';
  static const String expired = 'expired';
  static const String complianceHold = 'complianceHold';

  static const List<String> values = [
    draft,
    pendingApproval,
    active,
    suspended,
    completed,
    cancelled,
    expired,
    complianceHold,
  ];

  static String parse(dynamic value) {
    if (value is String && values.contains(value)) return value;
    return draft;
  }
}

/// How a program's Eligible Benefit is calculated. Stored as a plain string.
/// Anything outside [values] parses to [none] — zero benefit, never a
/// positive rate (D6: never silently apply a rate that wasn't explicitly
/// configured).
class BenefitRuleType {
  BenefitRuleType._();

  static const String none = 'none';
  static const String flatRupee = 'flatRupee';
  static const String percentage = 'percentage';
  static const String promotional = 'promotional';
  static const String tier = 'tier';
  static const String category = 'category';

  static const List<String> values = [none, flatRupee, percentage, promotional, tier, category];

  static String parse(dynamic value) {
    if (value is String && values.contains(value)) return value;
    return none;
  }
}

/// How often Product Credit is allocated. Stored as a plain string.
class CreditFrequency {
  CreditFrequency._();

  static const String monthly = 'monthly';
  static const String quarterly = 'quarterly';
  static const String annual = 'annual';

  static const List<String> values = [monthly, quarterly, annual];

  static String parse(dynamic value) {
    if (value is String && values.contains(value)) return value;
    return monthly;
  }
}

/// Admin-only configuration for a Customer Product Benefit Program.
/// Stored at /benefit_programs/{programId} — Cloud-Function write-only,
/// admin-read-only (see firestore.rules). This model only reads it; all
/// writes go through the `setBenefitProgramConfig` callable
/// (functions/src/admin/benefitProgramConfig.ts).
///
/// Fail-closed by construction: an absent or garbage [benefitRuleType]
/// resolves to [BenefitRuleType.none] (zero benefit), and an absent
/// [status] resolves to [BenefitProgramStatus.draft] (never active).
class BenefitProgramModel {
  final String id;
  final String name;
  final String description;
  final String status;
  final int durationMonths;

  /// Bumped by setBenefitProgramConfig on every change that alters benefit
  /// calculation inputs, so an already-accrued benefit remains explainable
  /// under the rules version in force when it accrued.
  final int rulesVersion;

  final DateTime? enrollmentOpensAt;
  final DateTime? enrollmentClosesAt;
  final double minProgramAmount;
  final double maxProgramAmount;

  final String benefitRuleType;
  final double benefitRateValue;
  final String creditFrequency;
  final int? creditExpiryDays;
  final List<String>? eligibleCategoryIds;

  /// Tier name -> rate, used only when benefitRuleType == tier.
  final Map<String, dynamic>? tierRates;

  /// Category id -> rate, used only when benefitRuleType == category.
  final Map<String, dynamic>? categoryRates;

  final DateTime createdAt;
  final DateTime updatedAt;
  final String? updatedBy;

  const BenefitProgramModel({
    required this.id,
    this.name = '',
    this.description = '',
    this.status = BenefitProgramStatus.draft,
    this.durationMonths = 0,
    this.rulesVersion = 1,
    this.enrollmentOpensAt,
    this.enrollmentClosesAt,
    this.minProgramAmount = 0,
    this.maxProgramAmount = 0,
    this.benefitRuleType = BenefitRuleType.none,
    this.benefitRateValue = 0,
    this.creditFrequency = CreditFrequency.monthly,
    this.creditExpiryDays,
    this.eligibleCategoryIds,
    this.tierRates,
    this.categoryRates,
    required this.createdAt,
    required this.updatedAt,
    this.updatedBy,
  });

  /// The fail-closed default: draft status, `none` benefit rule (zero
  /// benefit). Used whenever /benefit_programs/{programId} does not exist.
  factory BenefitProgramModel.notConfigured(String id) {
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    return BenefitProgramModel(id: id, createdAt: epoch, updatedAt: epoch);
  }

  factory BenefitProgramModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return BenefitProgramModel.fromMap(data, doc.id);
  }

  factory BenefitProgramModel.fromMap(Map<String, dynamic> map, String id) {
    return BenefitProgramModel(
      id: id,
      name: (map['name'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      status: BenefitProgramStatus.parse(map['status']),
      durationMonths: (map['durationMonths'] as num?)?.toInt() ?? 0,
      rulesVersion: (map['rulesVersion'] as num?)?.toInt() ?? 1,
      enrollmentOpensAt: _parseNullableDateTime(map['enrollmentOpensAt']),
      enrollmentClosesAt: _parseNullableDateTime(map['enrollmentClosesAt']),
      minProgramAmount: (map['minProgramAmount'] as num?)?.toDouble() ?? 0,
      maxProgramAmount: (map['maxProgramAmount'] as num?)?.toDouble() ?? 0,
      benefitRuleType: BenefitRuleType.parse(map['benefitRuleType']),
      benefitRateValue: (map['benefitRateValue'] as num?)?.toDouble() ?? 0,
      creditFrequency: CreditFrequency.parse(map['creditFrequency']),
      creditExpiryDays: (map['creditExpiryDays'] as num?)?.toInt(),
      eligibleCategoryIds: (map['eligibleCategoryIds'] as List?)?.whereType<String>().toList(),
      tierRates: (map['tierRates'] as Map?)?.map((k, v) => MapEntry(k.toString(), v)),
      categoryRates: (map['categoryRates'] as Map?)?.map((k, v) => MapEntry(k.toString(), v)),
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
      updatedBy: map['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'status': status,
      'durationMonths': durationMonths,
      'rulesVersion': rulesVersion,
      'enrollmentOpensAt': enrollmentOpensAt == null ? null : Timestamp.fromDate(enrollmentOpensAt!),
      'enrollmentClosesAt': enrollmentClosesAt == null ? null : Timestamp.fromDate(enrollmentClosesAt!),
      'minProgramAmount': minProgramAmount,
      'maxProgramAmount': maxProgramAmount,
      'benefitRuleType': benefitRuleType,
      'benefitRateValue': benefitRateValue,
      'creditFrequency': creditFrequency,
      'creditExpiryDays': creditExpiryDays,
      'eligibleCategoryIds': eligibleCategoryIds,
      'tierRates': tierRates,
      'categoryRates': categoryRates,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'updatedBy': updatedBy,
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

  bool get isActive => status == BenefitProgramStatus.active;

  BenefitProgramModel copyWith({
    String? id,
    String? name,
    String? description,
    String? status,
    int? durationMonths,
    int? rulesVersion,
    DateTime? enrollmentOpensAt,
    DateTime? enrollmentClosesAt,
    double? minProgramAmount,
    double? maxProgramAmount,
    String? benefitRuleType,
    double? benefitRateValue,
    String? creditFrequency,
    int? creditExpiryDays,
    List<String>? eligibleCategoryIds,
    Map<String, dynamic>? tierRates,
    Map<String, dynamic>? categoryRates,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return BenefitProgramModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      status: status ?? this.status,
      durationMonths: durationMonths ?? this.durationMonths,
      rulesVersion: rulesVersion ?? this.rulesVersion,
      enrollmentOpensAt: enrollmentOpensAt ?? this.enrollmentOpensAt,
      enrollmentClosesAt: enrollmentClosesAt ?? this.enrollmentClosesAt,
      minProgramAmount: minProgramAmount ?? this.minProgramAmount,
      maxProgramAmount: maxProgramAmount ?? this.maxProgramAmount,
      benefitRuleType: benefitRuleType ?? this.benefitRuleType,
      benefitRateValue: benefitRateValue ?? this.benefitRateValue,
      creditFrequency: creditFrequency ?? this.creditFrequency,
      creditExpiryDays: creditExpiryDays ?? this.creditExpiryDays,
      eligibleCategoryIds: eligibleCategoryIds ?? this.eligibleCategoryIds,
      tierRates: tierRates ?? this.tierRates,
      categoryRates: categoryRates ?? this.categoryRates,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  @override
  String toString() => 'BenefitProgram($id: $status, rule=$benefitRuleType, v$rulesVersion)';
}
