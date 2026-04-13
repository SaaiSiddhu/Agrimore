import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  // ✅ Core Fields (Immutable)
  final String uid;
  final String email;
  final String name;
  final String? phone;
  final String? photoUrl;
  final String role;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final bool isActive;
  final Map<String, dynamic>? metadata;

  // ✅ Constructor
  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    this.phone,
    this.photoUrl,
    required this.role,
    required this.createdAt,
    this.lastLogin,
    this.isActive = true,
    this.metadata,
  });

  // ✅ FROM MAP (Firestore Document)
  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'],
      photoUrl: map['photoUrl'],
      role: map['role'] ?? 'user',
      createdAt: _parseDateTime(map['createdAt']),
      lastLogin: map['lastLogin'] != null
          ? _parseDateTime(map['lastLogin'])
          : null,
      isActive: map['isActive'] ?? true,
      metadata: map['metadata'] != null
          ? Map<String, dynamic>.from(map['metadata'])
          : null,
    );
  }

  // ✅ FROM FIRESTORE DOCUMENT
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel.fromMap(data, doc.id);
  }

  // ✅ PARSE DATETIME HELPER
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }

  // ✅ TO MAP (For Firestore)
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'phone': phone,
      'photoUrl': photoUrl,
      'role': role,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLogin': lastLogin != null ? Timestamp.fromDate(lastLogin!) : null,
      'isActive': isActive,
      'metadata': metadata,
    };
  }

  // ✅ TO JSON (For API/Local Storage)
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'phone': phone,
      'photoUrl': photoUrl,
      'role': role,
      'createdAt': createdAt.toIso8601String(),
      'lastLogin': lastLogin?.toIso8601String(),
      'isActive': isActive,
      'metadata': metadata,
    };
  }

  // ✅ FROM JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'],
      photoUrl: json['photoUrl'],
      role: json['role'] ?? 'user',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      lastLogin: json['lastLogin'] != null
          ? DateTime.parse(json['lastLogin'])
          : null,
      isActive: json['isActive'] ?? true,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'])
          : null,
    );
  }

  // ✅ COPY WITH (For Immutability - IMPORTANT!)
  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    String? phone,
    String? photoUrl,
    String? role,
    DateTime? createdAt,
    DateTime? lastLogin,
    bool? isActive,
    Map<String, dynamic>? metadata,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
    );
  }

  // ✅ ROLE GETTERS
  bool get isAdmin => role == 'admin';
  bool get isSeller => role == 'seller';
  bool get isBuyer => role == 'user';
  bool get isModerator => role == 'moderator';
  bool get isDeliveryPartner => role == 'delivery_partner';

  // ✅ NAME INITIALS
  String get initials {
    final nameParts = name.split(' ');
    if (nameParts.length >= 2) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  // ✅ DISPLAY NAME
  String get displayName {
    return name.isNotEmpty ? name : 'User';
  }

  // ✅ FIRST NAME
  String get firstName {
    final parts = name.split(' ');
    return parts.isNotEmpty ? parts[0] : 'User';
  }

  // ✅ LAST NAME
  String get lastName {
    final parts = name.split(' ');
    return parts.length > 1 ? parts.sublist(1).join(' ') : '';
  }

  // ✅ ACCOUNT AGE IN DAYS
  int get accountAgeDays {
    return DateTime.now().difference(createdAt).inDays;
  }

  // ✅ IS NEW USER (Less than 7 days)
  bool get isNewUser => accountAgeDays < 7;

  // ✅ LAST LOGIN DURATION
  String get lastLoginDuration {
    if (lastLogin == null) return 'Never';
    final diff = DateTime.now().difference(lastLogin!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // ✅ PROFILE COMPLETE CHECK
  bool get isProfileComplete {
    return uid.isNotEmpty &&
        email.isNotEmpty &&
        name.isNotEmpty &&
        (phone?.isNotEmpty ?? false) &&
        (photoUrl?.isNotEmpty ?? false);
  }

  // ✅ PROFILE COMPLETION PERCENTAGE
  int get profileCompletionPercentage {
    int completed = 0;
    const int totalFields = 5;

    if (uid.isNotEmpty) completed++;
    if (email.isNotEmpty) completed++;
    if (name.isNotEmpty) completed++;
    if (phone?.isNotEmpty ?? false) completed++;
    if (photoUrl?.isNotEmpty ?? false) completed++;

    return ((completed / totalFields) * 100).toInt();
  }

  // ✅ EQUALITY
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          email == other.email;

  @override
  int get hashCode => uid.hashCode ^ email.hashCode;

  // ✅ TO STRING
  @override
  String toString() =>
      'UserModel(uid: $uid, email: $email, name: $name, role: $role, photoUrl: $photoUrl)';

  // ✅ DEBUG INFO
  String get debugInfo {
    return '''
    ╔═══════════════════════════════════════════════════╗
    ║ UserModel Debug Info                              ║
    ╠═══════════════════════════════════════════════════╣
    ║ UID: $uid
    ║ Email: $email
    ║ Name: $name
    ║ Phone: $phone
    ║ Photo: $photoUrl
    ║ Role: $role
    ║ Active: $isActive
    ║ Created: $createdAt
    ║ Last Login: $lastLogin
    ║ Account Age: $accountAgeDays days
    ║ Profile Complete: $isProfileComplete ($profileCompletionPercentage%)
    ╚═══════════════════════════════════════════════════╝
    ''';
  }
}
