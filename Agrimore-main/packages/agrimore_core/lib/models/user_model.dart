import 'package:cloud_firestore/cloud_firestore.dart';

// Phase 16, Workstream 1: allowed `gender` values for the profile-completion
// flow. A defined, closed set — validated server-side too
// (completeUserProfile.ts) — chosen to include a non-binary option and a
// prefer-not-to-say option rather than a binary-only choice.
const List<String> kAllowedGenders = [
  'male',
  'female',
  'non_binary',
  'prefer_not_to_say',
];

// Phase 16, Workstream 1: minimum age enforced at profile completion. The
// owner did not specify a value, so this is a conservative, easily-changed
// default (India's Consumer Protection Act / most marketplace ToS use 18
// as the age of contractual capacity) rather than scattered inline logic —
// change this one constant to adjust the policy. The authoritative check
// lives server-side in completeUserProfile.ts; this copy is for client-side
// UX validation only.
const int kMinimumProfileAgeYears = 18;

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

  // Phase 16, Workstream 1: identity/profile-completion fields. All
  // null-safe and default sanely (false / null) for the ~93 pre-existing
  // `users` documents that predate this phase and don't have these fields
  // at all — a missing field reads exactly like an incomplete profile,
  // which is the safe default until the Workstream 1 backfill (or the
  // completeUserProfile callable) sets it explicitly.
  final DateTime? dateOfBirth;
  final String? gender;
  final bool profileCompleted;
  final bool phoneVerified;
  final bool emailVerified;
  final DateTime? profileCompletedAt;

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
    this.dateOfBirth,
    this.gender,
    this.profileCompleted = false,
    this.phoneVerified = false,
    this.emailVerified = false,
    this.profileCompletedAt,
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
      dateOfBirth:
          map['dateOfBirth'] != null ? _parseDateTime(map['dateOfBirth']) : null,
      gender: map['gender'],
      profileCompleted: map['profileCompleted'] ?? false,
      phoneVerified: map['phoneVerified'] ?? false,
      emailVerified: map['emailVerified'] ?? false,
      profileCompletedAt: map['profileCompletedAt'] != null
          ? _parseDateTime(map['profileCompletedAt'])
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
      'dateOfBirth':
          dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
      'gender': gender,
      'profileCompleted': profileCompleted,
      'phoneVerified': phoneVerified,
      'emailVerified': emailVerified,
      'profileCompletedAt': profileCompletedAt != null
          ? Timestamp.fromDate(profileCompletedAt!)
          : null,
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
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'gender': gender,
      'profileCompleted': profileCompleted,
      'phoneVerified': phoneVerified,
      'emailVerified': emailVerified,
      'profileCompletedAt': profileCompletedAt?.toIso8601String(),
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
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.parse(json['dateOfBirth'])
          : null,
      gender: json['gender'],
      profileCompleted: json['profileCompleted'] ?? false,
      phoneVerified: json['phoneVerified'] ?? false,
      emailVerified: json['emailVerified'] ?? false,
      profileCompletedAt: json['profileCompletedAt'] != null
          ? DateTime.parse(json['profileCompletedAt'])
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
    DateTime? dateOfBirth,
    String? gender,
    bool? profileCompleted,
    bool? phoneVerified,
    bool? emailVerified,
    DateTime? profileCompletedAt,
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
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      emailVerified: emailVerified ?? this.emailVerified,
      profileCompletedAt: profileCompletedAt ?? this.profileCompletedAt,
    );
  }

  // ✅ ROLE GETTERS
  bool get isAdmin => role == 'admin';
  bool get isSeller => role == 'seller';
  bool get isBuyer => role == 'user';
  bool get isModerator => role == 'moderator';
  bool get isDeliveryPartner => role == 'delivery_partner';
  bool get isEmployee => role == 'employee';

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
