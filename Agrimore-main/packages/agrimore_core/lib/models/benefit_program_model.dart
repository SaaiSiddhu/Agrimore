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

  /// The window a `promotional`-rule program's rate actually applies in —
  /// deliberately SEPARATE from [enrollmentOpensAt]/[enrollmentClosesAt]
  /// (Phase C, Workstream 2): when a customer may JOIN the program is not
  /// the same question as when a promotional rate is IN EFFECT. Phase B
  /// conflated the two as a stopgap; this corrects it. Null on either side
  /// means "no bound in that direction" (see BenefitCalculationProgram in
  /// benefitCalculation.ts for how an unset window is treated).
  final DateTime? promotionalFrom;
  final DateTime? promotionalTo;

  // ---- Redemption restrictions (Phase C, Workstream 3) ----

  /// Cart subtotal below which no credit may be redeemed. Default 0 (no
  /// minimum).
  final double minOrderValueForRedemption;

  /// Absolute rupee cap on credit applied to a single order. Null = no cap.
  final double? maxCreditPerOrder;

  /// 0-100 cap on credit as a percentage of the (eligible) order value.
  /// Null = no percentage cap. A configured 0 means "no credit at all",
  /// never "unlimited" — see redemptionRules.ts.
  final double? maxCreditPercentOfOrder;

  /// Category ids credit may be redeemed against. Null/empty = every
  /// category is eligible.
  final List<String>? redeemableCategoryIds;

  /// Master switch for redemption on this program. Defaults to false —
  /// redemption must be deliberately turned on, mirroring every other
  /// fail-closed default in this model.
  final bool redemptionEnabled;

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
    this.promotionalFrom,
    this.promotionalTo,
    this.minOrderValueForRedemption = 0,
    this.maxCreditPerOrder,
    this.maxCreditPercentOfOrder,
    this.redeemableCategoryIds,
    this.redemptionEnabled = false,
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
      promotionalFrom: _parseNullableDateTime(map['promotionalFrom']),
      promotionalTo: _parseNullableDateTime(map['promotionalTo']),
      minOrderValueForRedemption: (map['minOrderValueForRedemption'] as num?)?.toDouble() ?? 0,
      maxCreditPerOrder: (map['maxCreditPerOrder'] as num?)?.toDouble(),
      maxCreditPercentOfOrder: (map['maxCreditPercentOfOrder'] as num?)?.toDouble(),
      redeemableCategoryIds: (map['redeemableCategoryIds'] as List?)?.whereType<String>().toList(),
      redemptionEnabled: map['redemptionEnabled'] == true,
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
      'promotionalFrom': promotionalFrom == null ? null : Timestamp.fromDate(promotionalFrom!),
      'promotionalTo': promotionalTo == null ? null : Timestamp.fromDate(promotionalTo!),
      'minOrderValueForRedemption': minOrderValueForRedemption,
      'maxCreditPerOrder': maxCreditPerOrder,
      'maxCreditPercentOfOrder': maxCreditPercentOfOrder,
      'redeemableCategoryIds': redeemableCategoryIds,
      'redemptionEnabled': redemptionEnabled,
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
    DateTime? promotionalFrom,
    DateTime? promotionalTo,
    double? minOrderValueForRedemption,
    double? maxCreditPerOrder,
    double? maxCreditPercentOfOrder,
    List<String>? redeemableCategoryIds,
    bool? redemptionEnabled,
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
      promotionalFrom: promotionalFrom ?? this.promotionalFrom,
      promotionalTo: promotionalTo ?? this.promotionalTo,
      minOrderValueForRedemption: minOrderValueForRedemption ?? this.minOrderValueForRedemption,
      maxCreditPerOrder: maxCreditPerOrder ?? this.maxCreditPerOrder,
      maxCreditPercentOfOrder: maxCreditPercentOfOrder ?? this.maxCreditPercentOfOrder,
      redeemableCategoryIds: redeemableCategoryIds ?? this.redeemableCategoryIds,
      redemptionEnabled: redemptionEnabled ?? this.redemptionEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  @override
  String toString() => 'BenefitProgram($id: $status, rule=$benefitRuleType, v$rulesVersion)';
}
