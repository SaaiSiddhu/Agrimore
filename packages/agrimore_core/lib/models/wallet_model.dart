import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Wallet model representing a user's wallet with balance and coins
class WalletModel {
  final String id;
  final String userId;
  final double balance;
  final int coins;
  final double lifetimeEarnings;
  final double lifetimeSpent;
  final int lifetimeCoinsEarned;
  final int lifetimeCoinsUsed;
  final String referralCode;
  final String? referredBy;
  final int referralCount;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  // Server-side idempotency guard for creditSignupBonus
  // (functions/src/customer/wallet.ts) — prevents the welcome bonus from
  // being credited more than once for the same wallet.
  final bool signupBonusCredited;

  WalletModel({
    required this.id,
    required this.userId,
    required this.balance,
    required this.coins,
    required this.lifetimeEarnings,
    required this.lifetimeSpent,
    required this.lifetimeCoinsEarned,
    required this.lifetimeCoinsUsed,
    required this.referralCode,
    this.referredBy,
    required this.referralCount,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.signupBonusCredited = false,
  });

  // Computed Properties
  double get totalAvailable => balance + coins.toDouble();
  bool get hasBalance => balance > 0;
  bool get hasCoins => coins > 0;
  bool get canUseWallet => isActive && (hasBalance || hasCoins);

  /// Calculate max coins usable for an order based on percentage limit
  int maxCoinsUsable(double orderTotal, double maxPercentage) {
    final maxAllowed = (orderTotal * maxPercentage / 100).floor();
    return min(coins, maxAllowed);
  }

  /// Create empty wallet for new user.
  ///
  /// Phase FIX-N6F (finding N-6F): referralCode used to be generated HERE,
  /// client-side — a <4-char name prefix><2-digit userId.hashCode % 100>
  /// scheme that was not just tamperable but genuinely collision-prone for
  /// two entirely honest users (only 100 values per prefix, and
  /// String.hashCode has no cross-version/cross-platform stability
  /// guarantee). firestore.rules now requires this field to be exactly ''
  /// at create time; the real code is assigned by the new
  /// assignReferralCode trigger (functions/src/customer/wallet.ts,
  /// wallets/{userId}.onCreate) the moment this document lands, with a real
  /// uniqueness check. The caller's own existing wallets/{uid}.snapshots()
  /// listener (wallet_provider.dart) picks it up automatically — no new
  /// client-side waiting logic needed.
  factory WalletModel.empty(String userId) {
    final now = DateTime.now();
    return WalletModel(
      id: userId,
      userId: userId,
      balance: 0,
      coins: 0,
      lifetimeEarnings: 0,
      lifetimeSpent: 0,
      lifetimeCoinsEarned: 0,
      lifetimeCoinsUsed: 0,
      referralCode: '',
      referredBy: null,
      referralCount: 0,
      isActive: true,
      createdAt: now,
      updatedAt: now,
      signupBonusCredited: false,
    );
  }

  /// Create from Firestore document
  factory WalletModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WalletModel.fromMap(data, doc.id);
  }

  /// Create from Map
  factory WalletModel.fromMap(Map<String, dynamic> map, String id) {
    return WalletModel(
      id: id,
      userId: map['userId'] ?? id,
      balance: (map['balance'] ?? 0).toDouble(),
      coins: map['coins'] ?? 0,
      lifetimeEarnings: (map['lifetimeEarnings'] ?? 0).toDouble(),
      lifetimeSpent: (map['lifetimeSpent'] ?? 0).toDouble(),
      lifetimeCoinsEarned: map['lifetimeCoinsEarned'] ?? 0,
      lifetimeCoinsUsed: map['lifetimeCoinsUsed'] ?? 0,
      referralCode: map['referralCode'] ?? '',
      referredBy: map['referredBy'],
      referralCount: map['referralCount'] ?? 0,
      isActive: map['isActive'] ?? true,
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
      signupBonusCredited: map['signupBonusCredited'] ?? false,
    );
  }

  /// Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'balance': balance,
      'coins': coins,
      'lifetimeEarnings': lifetimeEarnings,
      'lifetimeSpent': lifetimeSpent,
      'lifetimeCoinsEarned': lifetimeCoinsEarned,
      'lifetimeCoinsUsed': lifetimeCoinsUsed,
      'referralCode': referralCode,
      'referredBy': referredBy,
      'referralCount': referralCount,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'signupBonusCredited': signupBonusCredited,
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

  /// Copy with updated fields
  WalletModel copyWith({
    String? id,
    String? userId,
    double? balance,
    int? coins,
    double? lifetimeEarnings,
    double? lifetimeSpent,
    int? lifetimeCoinsEarned,
    int? lifetimeCoinsUsed,
    String? referralCode,
    String? referredBy,
    int? referralCount,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? signupBonusCredited,
  }) {
    return WalletModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      balance: balance ?? this.balance,
      coins: coins ?? this.coins,
      lifetimeEarnings: lifetimeEarnings ?? this.lifetimeEarnings,
      lifetimeSpent: lifetimeSpent ?? this.lifetimeSpent,
      lifetimeCoinsEarned: lifetimeCoinsEarned ?? this.lifetimeCoinsEarned,
      lifetimeCoinsUsed: lifetimeCoinsUsed ?? this.lifetimeCoinsUsed,
      referralCode: referralCode ?? this.referralCode,
      referredBy: referredBy ?? this.referredBy,
      referralCount: referralCount ?? this.referralCount,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      signupBonusCredited: signupBonusCredited ?? this.signupBonusCredited,
    );
  }

  @override
  String toString() => 'WalletModel(userId: $userId, balance: ₹$balance, coins: $coins)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WalletModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
