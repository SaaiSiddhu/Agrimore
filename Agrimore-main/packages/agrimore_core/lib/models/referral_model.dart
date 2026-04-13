import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for tracking referrals between users
class ReferralModel {
  final String id;
  final String referrerUserId;
  final String? referrerEmail;
  final String referredUserId;
  final String? referredEmail;
  final String referralCode;
  final int referrerBonus;
  final int referredBonus;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime? completedAt;

  ReferralModel({
    required this.id,
    required this.referrerUserId,
    this.referrerEmail,
    required this.referredUserId,
    this.referredEmail,
    required this.referralCode,
    required this.referrerBonus,
    required this.referredBonus,
    required this.isCompleted,
    required this.createdAt,
    this.completedAt,
  });

  /// Create pending referral (not yet completed)
  factory ReferralModel.create({
    required String referrerUserId,
    String? referrerEmail,
    required String referredUserId,
    String? referredEmail,
    required String referralCode,
    required int referrerBonus,
    required int referredBonus,
  }) {
    return ReferralModel(
      id: '',
      referrerUserId: referrerUserId,
      referrerEmail: referrerEmail,
      referredUserId: referredUserId,
      referredEmail: referredEmail,
      referralCode: referralCode,
      referrerBonus: referrerBonus,
      referredBonus: referredBonus,
      isCompleted: false,
      createdAt: DateTime.now(),
      completedAt: null,
    );
  }

  /// Create from Firestore document
  factory ReferralModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReferralModel.fromMap(data, doc.id);
  }

  /// Create from Map
  factory ReferralModel.fromMap(Map<String, dynamic> map, String id) {
    return ReferralModel(
      id: id,
      referrerUserId: map['referrerUserId'] ?? '',
      referrerEmail: map['referrerEmail'],
      referredUserId: map['referredUserId'] ?? '',
      referredEmail: map['referredEmail'],
      referralCode: map['referralCode'] ?? '',
      referrerBonus: map['referrerBonus'] ?? 0,
      referredBonus: map['referredBonus'] ?? 0,
      isCompleted: map['isCompleted'] ?? false,
      createdAt: _parseDateTime(map['createdAt']),
      completedAt: map['completedAt'] != null 
          ? _parseDateTime(map['completedAt']) 
          : null,
    );
  }

  /// Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'referrerUserId': referrerUserId,
      'referrerEmail': referrerEmail,
      'referredUserId': referredUserId,
      'referredEmail': referredEmail,
      'referralCode': referralCode,
      'referrerBonus': referrerBonus,
      'referredBonus': referredBonus,
      'isCompleted': isCompleted,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
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

  /// Mark referral as completed
  ReferralModel markCompleted() {
    return copyWith(
      isCompleted: true,
      completedAt: DateTime.now(),
    );
  }

  /// Copy with updated fields
  ReferralModel copyWith({
    String? id,
    String? referrerUserId,
    String? referrerEmail,
    String? referredUserId,
    String? referredEmail,
    String? referralCode,
    int? referrerBonus,
    int? referredBonus,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return ReferralModel(
      id: id ?? this.id,
      referrerUserId: referrerUserId ?? this.referrerUserId,
      referrerEmail: referrerEmail ?? this.referrerEmail,
      referredUserId: referredUserId ?? this.referredUserId,
      referredEmail: referredEmail ?? this.referredEmail,
      referralCode: referralCode ?? this.referralCode,
      referrerBonus: referrerBonus ?? this.referrerBonus,
      referredBonus: referredBonus ?? this.referredBonus,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  String toString() => 'Referral($referralCode: $referrerUserId -> $referredUserId, completed: $isCompleted)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReferralModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
