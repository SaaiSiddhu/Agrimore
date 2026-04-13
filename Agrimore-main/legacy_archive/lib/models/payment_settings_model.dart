class PaymentSettingsModel {
  final bool codEnabled;
  final bool razorpayEnabled;
  final String? razorpayKeyId;
  final String? razorpayKeySecret;
  final double minOrderAmountForCOD;
  final double maxOrderAmountForCOD;
  final List<String> supportedCurrencies;
  final Map<String, dynamic>? additionalSettings;

  PaymentSettingsModel({
    this.codEnabled = true,
    this.razorpayEnabled = true,
    this.razorpayKeyId,
    this.razorpayKeySecret,
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
      razorpayKeySecret: map['razorpayKeySecret'],
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
      'razorpayKeySecret': razorpayKeySecret,
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
    String? razorpayKeySecret,
    double? minOrderAmountForCOD,
    double? maxOrderAmountForCOD,
    List<String>? supportedCurrencies,
    Map<String, dynamic>? additionalSettings,
  }) {
    return PaymentSettingsModel(
      codEnabled: codEnabled ?? this.codEnabled,
      razorpayEnabled: razorpayEnabled ?? this.razorpayEnabled,
      razorpayKeyId: razorpayKeyId ?? this.razorpayKeyId,
      razorpayKeySecret: razorpayKeySecret ?? this.razorpayKeySecret,
      minOrderAmountForCOD: minOrderAmountForCOD ?? this.minOrderAmountForCOD,
      maxOrderAmountForCOD: maxOrderAmountForCOD ?? this.maxOrderAmountForCOD,
      supportedCurrencies: supportedCurrencies ?? this.supportedCurrencies,
      additionalSettings: additionalSettings ?? this.additionalSettings,
    );
  }
}
