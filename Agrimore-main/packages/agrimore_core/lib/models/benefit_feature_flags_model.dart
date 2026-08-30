/// Feature flags for the AgriMore Customer Product Benefit Program.
/// Stored as the singleton document at /feature_flags/benefit_program.
///
/// Every flag defaults to `false` whenever the document is missing, a key
/// is absent, or a key holds a non-boolean value — this model can never
/// resolve a flag to `true` on its own. The document is Cloud-Function
/// write-only (see firestore.rules); this model only reads it.
class BenefitFeatureFlagsModel {
  final bool benefitProgramEnabled;
  final bool newEnrollmentEnabled;
  final bool monthlyCreditEnabled;
  final bool percentageBenefitEnabled;
  final bool benefitExamplesEnabled;
  final bool productCreditRedemptionEnabled;
  final bool benefitAccumulationEnabled;
  final bool compoundingEnabled;
  final bool cashRedemptionEnabled;
  final bool principalIntakeEnabled;
  final bool principalReturnEnabled;

  const BenefitFeatureFlagsModel({
    this.benefitProgramEnabled = false,
    this.newEnrollmentEnabled = false,
    this.monthlyCreditEnabled = false,
    this.percentageBenefitEnabled = false,
    this.benefitExamplesEnabled = false,
    this.productCreditRedemptionEnabled = false,
    this.benefitAccumulationEnabled = false,
    this.compoundingEnabled = false,
    this.cashRedemptionEnabled = false,
    this.principalIntakeEnabled = false,
    this.principalReturnEnabled = false,
  });

  /// All flags off. Used whenever the flag document is missing, unreadable,
  /// or the client is offline — the fail-closed default.
  factory BenefitFeatureFlagsModel.disabled() =>
      const BenefitFeatureFlagsModel();

  static bool _boolFlag(Map<String, dynamic> map, String key) {
    final value = map[key];
    return value is bool ? value : false;
  }

  /// Create from a raw Firestore map. `null` (missing document) and any
  /// non-boolean field value both resolve to `false` for that flag.
  factory BenefitFeatureFlagsModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const BenefitFeatureFlagsModel();
    return BenefitFeatureFlagsModel(
      benefitProgramEnabled: _boolFlag(map, 'BENEFIT_PROGRAM_ENABLED'),
      newEnrollmentEnabled: _boolFlag(map, 'NEW_ENROLLMENT_ENABLED'),
      monthlyCreditEnabled: _boolFlag(map, 'MONTHLY_CREDIT_ENABLED'),
      percentageBenefitEnabled: _boolFlag(map, 'PERCENTAGE_BENEFIT_ENABLED'),
      benefitExamplesEnabled: _boolFlag(map, 'BENEFIT_EXAMPLES_ENABLED'),
      productCreditRedemptionEnabled:
          _boolFlag(map, 'PRODUCT_CREDIT_REDEMPTION_ENABLED'),
      benefitAccumulationEnabled:
          _boolFlag(map, 'BENEFIT_ACCUMULATION_ENABLED'),
      compoundingEnabled: _boolFlag(map, 'COMPOUNDING_ENABLED'),
      cashRedemptionEnabled: _boolFlag(map, 'CASH_REDEMPTION_ENABLED'),
      principalIntakeEnabled: _boolFlag(map, 'PRINCIPAL_INTAKE_ENABLED'),
      principalReturnEnabled: _boolFlag(map, 'PRINCIPAL_RETURN_ENABLED'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'BENEFIT_PROGRAM_ENABLED': benefitProgramEnabled,
      'NEW_ENROLLMENT_ENABLED': newEnrollmentEnabled,
      'MONTHLY_CREDIT_ENABLED': monthlyCreditEnabled,
      'PERCENTAGE_BENEFIT_ENABLED': percentageBenefitEnabled,
      'BENEFIT_EXAMPLES_ENABLED': benefitExamplesEnabled,
      'PRODUCT_CREDIT_REDEMPTION_ENABLED': productCreditRedemptionEnabled,
      'BENEFIT_ACCUMULATION_ENABLED': benefitAccumulationEnabled,
      'COMPOUNDING_ENABLED': compoundingEnabled,
      'CASH_REDEMPTION_ENABLED': cashRedemptionEnabled,
      'PRINCIPAL_INTAKE_ENABLED': principalIntakeEnabled,
      'PRINCIPAL_RETURN_ENABLED': principalReturnEnabled,
    };
  }

  BenefitFeatureFlagsModel copyWith({
    bool? benefitProgramEnabled,
    bool? newEnrollmentEnabled,
    bool? monthlyCreditEnabled,
    bool? percentageBenefitEnabled,
    bool? benefitExamplesEnabled,
    bool? productCreditRedemptionEnabled,
    bool? benefitAccumulationEnabled,
    bool? compoundingEnabled,
    bool? cashRedemptionEnabled,
    bool? principalIntakeEnabled,
    bool? principalReturnEnabled,
  }) {
    return BenefitFeatureFlagsModel(
      benefitProgramEnabled:
          benefitProgramEnabled ?? this.benefitProgramEnabled,
      newEnrollmentEnabled: newEnrollmentEnabled ?? this.newEnrollmentEnabled,
      monthlyCreditEnabled: monthlyCreditEnabled ?? this.monthlyCreditEnabled,
      percentageBenefitEnabled:
          percentageBenefitEnabled ?? this.percentageBenefitEnabled,
      benefitExamplesEnabled:
          benefitExamplesEnabled ?? this.benefitExamplesEnabled,
      productCreditRedemptionEnabled: productCreditRedemptionEnabled ??
          this.productCreditRedemptionEnabled,
      benefitAccumulationEnabled:
          benefitAccumulationEnabled ?? this.benefitAccumulationEnabled,
      compoundingEnabled: compoundingEnabled ?? this.compoundingEnabled,
      cashRedemptionEnabled:
          cashRedemptionEnabled ?? this.cashRedemptionEnabled,
      principalIntakeEnabled:
          principalIntakeEnabled ?? this.principalIntakeEnabled,
      principalReturnEnabled:
          principalReturnEnabled ?? this.principalReturnEnabled,
    );
  }

  @override
  String toString() =>
      'BenefitFeatureFlags(programEnabled: $benefitProgramEnabled, newEnrollment: $newEnrollmentEnabled)';
}
