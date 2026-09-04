import 'package:cloud_firestore/cloud_firestore.dart';

/// Admin-configurable wallet settings
/// Stored as singleton document at /settings/wallet_config
class WalletConfigModel {
  final String id;
  
  // Referral Settings
  final int referrerBonus;
  final int referredBonus;
  final int referralFirstOrderBonus;
  
  // Coins Usage Settings
  final double maxCoinsPercentage;
  final double minOrderForCoins;
  
  // Cashback Settings
  final int signupBonus;
  final double cashbackPercentage;
  final double firstOrderCashback;
  
  // Top-up Bonuses (amount -> bonus coins)
  final Map<int, int> topupBonuses;
  
  // Feature Toggles
  final bool isReferralEnabled;
  final bool isCashbackEnabled;
  final bool isCoinsEnabled;
  final bool isWalletEnabled;
  
  final DateTime updatedAt;
  final String? updatedBy;

  WalletConfigModel({
    required this.id,
    required this.referrerBonus,
    required this.referredBonus,
    required this.referralFirstOrderBonus,
    required this.maxCoinsPercentage,
    required this.minOrderForCoins,
    required this.signupBonus,
    required this.cashbackPercentage,
    required this.firstOrderCashback,
    required this.topupBonuses,
    required this.isReferralEnabled,
    required this.isCashbackEnabled,
    required this.isCoinsEnabled,
    required this.isWalletEnabled,
    required this.updatedAt,
    this.updatedBy,
  });

  /// Default configuration values
  factory WalletConfigModel.defaults() {
    return WalletConfigModel(
      id: 'wallet_config',
      referrerBonus: 100,
      referredBonus: 50,
      referralFirstOrderBonus: 50,
      maxCoinsPercentage: 10,
      minOrderForCoins: 200,
      signupBonus: 50,
      cashbackPercentage: 1,
      firstOrderCashback: 2,
      topupBonuses: {
        500: 25,
        1000: 75,
        2000: 200,
      },
      isReferralEnabled: true,
      isCashbackEnabled: true,
      isCoinsEnabled: true,
      isWalletEnabled: true,
      updatedAt: DateTime.now(),
      updatedBy: null,
    );
  }

  /// Create from Firestore document
  factory WalletConfigModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WalletConfigModel.fromMap(data, doc.id);
  }

  /// Create from Map
  factory WalletConfigModel.fromMap(Map<String, dynamic> map, String id) {
    // Parse topupBonuses from Map
    Map<int, int> bonuses = {};
    if (map['topupBonuses'] != null) {
      (map['topupBonuses'] as Map<String, dynamic>).forEach((key, value) {
        bonuses[int.parse(key)] = value as int;
      });
    }

    return WalletConfigModel(
      id: id,
      referrerBonus: map['referrerBonus'] ?? 100,
      referredBonus: map['referredBonus'] ?? 50,
      referralFirstOrderBonus: map['referralFirstOrderBonus'] ?? 50,
      maxCoinsPercentage: (map['maxCoinsPercentage'] ?? 10).toDouble(),
      minOrderForCoins: (map['minOrderForCoins'] ?? 200).toDouble(),
      signupBonus: map['signupBonus'] ?? 50,
      cashbackPercentage: (map['cashbackPercentage'] ?? 1).toDouble(),
      firstOrderCashback: (map['firstOrderCashback'] ?? 2).toDouble(),
      topupBonuses: bonuses.isNotEmpty ? bonuses : {500: 25, 1000: 75, 2000: 200},
      isReferralEnabled: map['isReferralEnabled'] ?? true,
      isCashbackEnabled: map['isCashbackEnabled'] ?? true,
      isCoinsEnabled: map['isCoinsEnabled'] ?? true,
      isWalletEnabled: map['isWalletEnabled'] ?? true,
      updatedAt: _parseDateTime(map['updatedAt']),
      updatedBy: map['updatedBy'],
    );
  }

  /// Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    // Convert topupBonuses keys to strings for Firestore
    Map<String, int> bonusesMap = {};
    topupBonuses.forEach((key, value) {
      bonusesMap[key.toString()] = value;
    });

    return {
      'referrerBonus': referrerBonus,
      'referredBonus': referredBonus,
      'referralFirstOrderBonus': referralFirstOrderBonus,
      'maxCoinsPercentage': maxCoinsPercentage,
      'minOrderForCoins': minOrderForCoins,
      'signupBonus': signupBonus,
      'cashbackPercentage': cashbackPercentage,
      'firstOrderCashback': firstOrderCashback,
      'topupBonuses': bonusesMap,
      'isReferralEnabled': isReferralEnabled,
      'isCashbackEnabled': isCashbackEnabled,
      'isCoinsEnabled': isCoinsEnabled,
      'isWalletEnabled': isWalletEnabled,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'updatedBy': updatedBy,
    };
  }

  /// Parse DateTime from various formats
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }

  /// Get bonus coins for a top-up amount
  int getBonusForAmount(double amount) {
    int bonus = 0;
    final sortedAmounts = topupBonuses.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final threshold in sortedAmounts) {
      if (amount >= threshold) {
        bonus = topupBonuses[threshold]!;
        break;
      }
    }
    return bonus;
  }

  /// Copy with updated fields
  WalletConfigModel copyWith({
    String? id,
    int? referrerBonus,
    int? referredBonus,
    int? referralFirstOrderBonus,
    double? maxCoinsPercentage,
    double? minOrderForCoins,
    int? signupBonus,
    double? cashbackPercentage,
    double? firstOrderCashback,
    Map<int, int>? topupBonuses,
    bool? isReferralEnabled,
    bool? isCashbackEnabled,
    bool? isCoinsEnabled,
    bool? isWalletEnabled,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return WalletConfigModel(
      id: id ?? this.id,
      referrerBonus: referrerBonus ?? this.referrerBonus,
      referredBonus: referredBonus ?? this.referredBonus,
      referralFirstOrderBonus: referralFirstOrderBonus ?? this.referralFirstOrderBonus,
      maxCoinsPercentage: maxCoinsPercentage ?? this.maxCoinsPercentage,
      minOrderForCoins: minOrderForCoins ?? this.minOrderForCoins,
      signupBonus: signupBonus ?? this.signupBonus,
      cashbackPercentage: cashbackPercentage ?? this.cashbackPercentage,
      firstOrderCashback: firstOrderCashback ?? this.firstOrderCashback,
      topupBonuses: topupBonuses ?? this.topupBonuses,
      isReferralEnabled: isReferralEnabled ?? this.isReferralEnabled,
      isCashbackEnabled: isCashbackEnabled ?? this.isCashbackEnabled,
      isCoinsEnabled: isCoinsEnabled ?? this.isCoinsEnabled,
      isWalletEnabled: isWalletEnabled ?? this.isWalletEnabled,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  @override
  String toString() => 'WalletConfig(referrer: $referrerBonus, cashback: $cashbackPercentage%)';
}
