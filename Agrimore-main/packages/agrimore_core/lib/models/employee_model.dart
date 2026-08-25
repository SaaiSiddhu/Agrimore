import 'package:cloud_firestore/cloud_firestore.dart';

/// Employee (B2B sales rep) model.
/// Employees earn commission on B2B orders attributed to them via
/// [employeeCode], entered by the customer at checkout.
class EmployeeModel {
  final String id;
  final String userId;
  final String name;
  final String email;
  final String phone;
  final String employeeCode;
  final String status; // pending, approved, suspended
  final double commissionRate; // percentage
  final String createdBy; // self, admin
  final DateTime createdAt;
  final DateTime updatedAt;

  EmployeeModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    required this.phone,
    required this.employeeCode,
    this.status = 'pending',
    this.commissionRate = 0.0,
    this.createdBy = 'self',
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending';
  bool get isSuspended => status == 'suspended';

  /// Generate unique employee code: First 4 letters of name + 2 digit sequence.
  /// Mirrors WalletModel's referral code generation.
  static String generateEmployeeCode(String userId, String? name) {
    String namePrefix = 'EMPL';
    if (name != null && name.isNotEmpty) {
      final cleanName = name.replaceAll(' ', '').toUpperCase();
      namePrefix =
          cleanName.length >= 4 ? cleanName.substring(0, 4) : cleanName.padRight(4, 'X');
    }
    final sequence = (userId.hashCode.abs() % 100).toString().padLeft(2, '0');
    return '$namePrefix$sequence';
  }

  factory EmployeeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EmployeeModel.fromMap(data, doc.id);
  }

  factory EmployeeModel.fromMap(Map<String, dynamic> map, [String? id]) {
    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    final resolvedId = id ?? map['id'] ?? '';
    return EmployeeModel(
      id: resolvedId,
      userId: map['userId'] ?? resolvedId,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      employeeCode: map['employeeCode'] ?? '',
      status: map['status'] ?? 'pending',
      commissionRate: (map['commissionRate'] as num?)?.toDouble() ?? 0.0,
      createdBy: map['createdBy'] ?? 'self',
      createdAt: parseDateTime(map['createdAt']),
      updatedAt: parseDateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'email': email,
      'phone': phone,
      'employeeCode': employeeCode,
      'status': status,
      'commissionRate': commissionRate,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  EmployeeModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? email,
    String? phone,
    String? employeeCode,
    String? status,
    double? commissionRate,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EmployeeModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      employeeCode: employeeCode ?? this.employeeCode,
      status: status ?? this.status,
      commissionRate: commissionRate ?? this.commissionRate,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'EmployeeModel(id: $id, name: $name, employeeCode: $employeeCode, status: $status)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmployeeModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
