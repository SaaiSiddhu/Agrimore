import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Transaction type - credit (money in) or debit (money out)
enum TransactionType { credit, debit }

/// Source of the transaction
enum TransactionSource {
  topup,      // Added money via payment gateway
  refund,     // Order refund
  cashback,   // Cashback earned on order
  referral,   // Referral bonus
  order,      // Payment for order
  bonus,      // Sign-up / promo bonus
  expiry,     // Expired coins
  adjustment, // Admin manual adjustment
}

/// Model for wallet transaction history
class WalletTransactionModel {
  final String id;
  final String walletId;
  final String userId;
  final TransactionType type;
  final TransactionSource source;
  final double amount;
  final int coins;
  final double balanceAfter;
  final int coinsAfter;
  final String? orderId;
  final String description;
  final String? referenceId;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final Map<String, dynamic>? metadata;

  WalletTransactionModel({
    required this.id,
    required this.walletId,
    required this.userId,
    required this.type,
    required this.source,
    required this.amount,
    required this.coins,
    required this.balanceAfter,
    required this.coinsAfter,
    this.orderId,
    required this.description,
    this.referenceId,
    required this.createdAt,
    this.expiresAt,
    this.metadata,
  });

  // Display Helpers

  /// Formatted amount with sign (+₹100 or -₹100)
  String get formattedAmount {
    if (amount > 0) {
      final sign = type == TransactionType.credit ? '+' : '-';
      return '$sign₹${amount.toStringAsFixed(2)}';
    } else if (coins > 0) {
      final sign = type == TransactionType.credit ? '+' : '-';
      return '$sign$coins coins';
    }
    return '₹0.00';
  }

  /// Formatted date (e.g., "Jan 2, 2026")
  String get formattedDate {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[createdAt.month - 1]} ${createdAt.day}, ${createdAt.year}';
  }

  /// Formatted time (e.g., "10:30 AM")
  String get formattedTime {
    final hour = createdAt.hour > 12 ? createdAt.hour - 12 : createdAt.hour;
    final period = createdAt.hour >= 12 ? 'PM' : 'AM';
    final minute = createdAt.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  /// Icon based on transaction source
  IconData get icon {
    switch (source) {
      case TransactionSource.topup:
        return Icons.add_circle_outline;
      case TransactionSource.refund:
        return Icons.refresh;
      case TransactionSource.cashback:
        return Icons.card_giftcard;
      case TransactionSource.referral:
        return Icons.people;
      case TransactionSource.order:
        return Icons.shopping_bag_outlined;
      case TransactionSource.bonus:
        return Icons.celebration;
      case TransactionSource.expiry:
        return Icons.timer_off;
      case TransactionSource.adjustment:
        return Icons.tune;
    }
  }

  /// Color based on transaction type
  Color get color {
    return type == TransactionType.credit 
        ? const Color(0xFF4CAF50) // Green
        : const Color(0xFFE53935); // Red
  }

  /// Source label for display
  String get sourceLabel {
    switch (source) {
      case TransactionSource.topup:
        return 'Top-up';
      case TransactionSource.refund:
        return 'Refund';
      case TransactionSource.cashback:
        return 'Cashback';
      case TransactionSource.referral:
        return 'Referral Bonus';
      case TransactionSource.order:
        return 'Order Payment';
      case TransactionSource.bonus:
        return 'Bonus';
      case TransactionSource.expiry:
        return 'Expired';
      case TransactionSource.adjustment:
        return 'Adjustment';
    }
  }

  /// Create from Firestore document
  factory WalletTransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WalletTransactionModel.fromMap(data, doc.id);
  }

  /// Create from Map
  factory WalletTransactionModel.fromMap(Map<String, dynamic> map, String id) {
    return WalletTransactionModel(
      id: id,
      walletId: map['walletId'] ?? '',
      userId: map['userId'] ?? '',
      type: TransactionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TransactionType.credit,
      ),
      source: TransactionSource.values.firstWhere(
        (e) => e.name == map['source'],
        orElse: () => TransactionSource.adjustment,
      ),
      amount: (map['amount'] ?? 0).toDouble(),
      coins: map['coins'] ?? 0,
      balanceAfter: (map['balanceAfter'] ?? 0).toDouble(),
      coinsAfter: map['coinsAfter'] ?? 0,
      orderId: map['orderId'],
      description: map['description'] ?? '',
      referenceId: map['referenceId'],
      createdAt: _parseDateTime(map['createdAt']),
      expiresAt: map['expiresAt'] != null ? _parseDateTime(map['expiresAt']) : null,
      metadata: map['metadata'] != null 
          ? Map<String, dynamic>.from(map['metadata']) 
          : null,
    );
  }

  /// Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'walletId': walletId,
      'userId': userId,
      'type': type.name,
      'source': source.name,
      'amount': amount,
      'coins': coins,
      'balanceAfter': balanceAfter,
      'coinsAfter': coinsAfter,
      'orderId': orderId,
      'description': description,
      'referenceId': referenceId,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'metadata': metadata,
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

  @override
  String toString() => 'WalletTransaction($id: ${type.name} ${source.name} $formattedAmount)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WalletTransactionModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
