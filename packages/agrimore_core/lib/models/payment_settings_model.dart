// Phase 15, Workstream 5 fix: `razorpayKeySecret` deleted from this model
// (constructor/fromMap/toMap/copyWith). Grepped: zero usages anywhere in
// apps/ or packages/ before this change — this model as a whole has no
// callers either (see this phase's completion report), so the field was a
// pure latent trap rather than an active vulnerability: settings/{docId} is
// `allow read: if true` (world-readable), so a future write of a real
// Razorpay secret through this field's toMap()/fromMap() would have landed
// in a publicly-readable Firestore document. The Razorpay secret's one
// legitimate home remains Cloud Functions environment config
// (functions/src/customer/payment.ts's getRazorpayCredentials()).
class PaymentSettingsModel {
  final bool codEnabled;
  final bool razorpayEnabled;
  final String? razorpayKeyId;
  final double minOrderAmountForCOD;
  final double maxOrderAmountForCOD;
  final List<String> supportedCurrencies;
  final Map<String, dynamic>? additionalSettings;

  PaymentSettingsModel({
    this.codEnabled = true,
    this.razorpayEnabled = true,
    this.razorpayKeyId,
    this.minOrderAmountForCOD = 0,
    this.maxOrderAmountForCOD = 50000,
    this.supportedCurrencies = const ['INR'],
    this.additionalSettings,
  });

  factory PaymentSettingsModel.fromMap(Map<String, dynamic> map) {
    return PaymentSettingsModel(
      codEnabled: map['codEnabled'] ?? true,
      razorpayEnabled: map['razorpayEnabled'] ?? true,
      razorpayKeyId: map['razorpayKeyId'],
      minOrderAmountForCOD: (map['minOrderAmountForCOD'] ?? 0).toDouble(),
      maxOrderAmountForCOD: (map['maxOrderAmountForCOD'] ?? 50000).toDouble(),
      supportedCurrencies:
          List<String>.from(map['supportedCurrencies'] ?? ['INR']),
      additionalSettings: map['additionalSettings'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'codEnabled': codEnabled,
      'razorpayEnabled': razorpayEnabled,
      'razorpayKeyId': razorpayKeyId,
      'minOrderAmountForCOD': minOrderAmountForCOD,
      'maxOrderAmountForCOD': maxOrderAmountForCOD,
      'supportedCurrencies': supportedCurrencies,
      'additionalSettings': additionalSettings,
    };
  }

  // Check if COD is available for order amount
  bool isCODAvailableForAmount(double amount) {
    return codEnabled &&
        amount >= minOrderAmountForCOD &&
        amount <= maxOrderAmountForCOD;
  }

  PaymentSettingsModel copyWith({
    bool? codEnabled,
    bool? razorpayEnabled,
    String? razorpayKeyId,
    double? minOrderAmountForCOD,
    double? maxOrderAmountForCOD,
    List<String>? supportedCurrencies,
    Map<String, dynamic>? additionalSettings,
  }) {
    return PaymentSettingsModel(
      codEnabled: codEnabled ?? this.codEnabled,
      razorpayEnabled: razorpayEnabled ?? this.razorpayEnabled,
      razorpayKeyId: razorpayKeyId ?? this.razorpayKeyId,
      minOrderAmountForCOD: minOrderAmountForCOD ?? this.minOrderAmountForCOD,
      maxOrderAmountForCOD: maxOrderAmountForCOD ?? this.maxOrderAmountForCOD,
      supportedCurrencies: supportedCurrencies ?? this.supportedCurrencies,
      additionalSettings: additionalSettings ?? this.additionalSettings,
    );
  }
}
