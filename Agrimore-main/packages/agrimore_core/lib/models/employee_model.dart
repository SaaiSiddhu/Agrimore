import 'package:cloud_firestore/cloud_firestore.dart';

/// Employee (B2B sales rep) model.
/// Employees earn commission on B2B orders attributed to them via
/// [employeeCode], entered by the customer at checkout.
///
/// Phase 16A: adds the ₹500 one-time Registration & Onboarding Fee fields.
/// User-facing screens should refer to this role as "AgriMore Sales
/// Associate" (see functions/src/employee/associateTerm.ts) — this class
/// name and every field name stay unchanged; only the copy shown to users
/// changes.
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

  // ---- Phase 16A: onboarding fee fields ----
  // All seven are written ONLY by Cloud Functions (see
  // functions/src/employee/activationCore.ts and adminOnboardingActions.ts)
  // — firestore.rules structurally denies any owner write to any of them.
  // This model only ever READS them; nothing in this phase adds a new
  // client write path for them.
  final bool onboardingPaid;
  final bool onboardingWaived;
  final double? onboardingFeeAmount;
  final String? onboardingPaymentId;
  final DateTime? onboardingPaidAt;
  final DateTime? onboardingWaivedAt;
  final DateTime? onboardingRefundedAt;

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
    this.onboardingPaid = false,
    this.onboardingWaived = false,
    this.onboardingFeeAmount,
    this.onboardingPaymentId,
    this.onboardingPaidAt,
    this.onboardingWaivedAt,
    this.onboardingRefundedAt,
  });

  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending';
  bool get isSuspended => status == 'suspended';

  /// True once this associate has cleared the ₹500 onboarding money gate —
  /// either by paying the fee ([onboardingPaid]) or having it waived by an
  /// admin ([onboardingWaived]) — AND that clearance has not since been
  /// reversed by a recorded refund ([onboardingRefundedAt] is null).
  ///
  /// This does NOT mean the associate is approved. Clearing the onboarding
  /// gate and admin approval (`status == 'approved'`) are two fully
  /// independent facts, decided by two fully independent actions — see
  /// functions/src/employee/activationCore.ts's header comment for why
  /// paying (or having waived) the fee must never itself grant `status`.
  /// A `pending` associate can have `hasClearedOnboardingGate == true` and
  /// still be waiting on admin approval; an `approved` associate can in
  /// principle still have `hasClearedOnboardingGate == false` if onboarding
  /// hasn't been completed yet (this phase adds no gating on that
  /// combination anywhere — see the completion report).
  bool get hasClearedOnboardingGate =>
      (onboardingPaid || onboardingWaived) && onboardingRefundedAt == null;

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

    // Optional onboarding date fields must stay null when absent — unlike
    // createdAt/updatedAt above, defaulting a missing value to
    // DateTime.now() here would fabricate a "paid at"/"waived at"/
    // "refunded at" timestamp on a legacy document that was never paid,
    // waived, or refunded. Every non-null value still goes through the
    // exact same parseDateTime() parsing logic above — this only guards
    // the null case before calling it, rather than duplicating a second
    // parsing helper.
    DateTime? parseOptionalDateTime(dynamic value) {
      if (value == null) return null;
      return parseDateTime(value);
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
      // == true (not `as bool?`) is deliberate: a missing, null, or
      // unexpectedly-typed value reads as false rather than throwing —
      // fail closed, mirroring this phase's server-side "never treat
      // unknown as paid" rule (see activationCore.ts).
      onboardingPaid: map['onboardingPaid'] == true,
      onboardingWaived: map['onboardingWaived'] == true,
      onboardingFeeAmount: (map['onboardingFeeAmount'] as num?)?.toDouble(),
      onboardingPaymentId: map['onboardingPaymentId'] as String?,
      onboardingPaidAt: parseOptionalDateTime(map['onboardingPaidAt']),
      onboardingWaivedAt: parseOptionalDateTime(map['onboardingWaivedAt']),
      onboardingRefundedAt: parseOptionalDateTime(map['onboardingRefundedAt']),
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
      'onboardingPaid': onboardingPaid,
      'onboardingWaived': onboardingWaived,
      'onboardingFeeAmount': onboardingFeeAmount,
      'onboardingPaymentId': onboardingPaymentId,
      'onboardingPaidAt':
          onboardingPaidAt != null ? Timestamp.fromDate(onboardingPaidAt!) : null,
      'onboardingWaivedAt':
          onboardingWaivedAt != null ? Timestamp.fromDate(onboardingWaivedAt!) : null,
      'onboardingRefundedAt':
          onboardingRefundedAt != null ? Timestamp.fromDate(onboardingRefundedAt!) : null,
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
    bool? onboardingPaid,
    bool? onboardingWaived,
    double? onboardingFeeAmount,
    String? onboardingPaymentId,
    DateTime? onboardingPaidAt,
    DateTime? onboardingWaivedAt,
    DateTime? onboardingRefundedAt,
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
      onboardingPaid: onboardingPaid ?? this.onboardingPaid,
      onboardingWaived: onboardingWaived ?? this.onboardingWaived,
      onboardingFeeAmount: onboardingFeeAmount ?? this.onboardingFeeAmount,
      onboardingPaymentId: onboardingPaymentId ?? this.onboardingPaymentId,
      onboardingPaidAt: onboardingPaidAt ?? this.onboardingPaidAt,
      onboardingWaivedAt: onboardingWaivedAt ?? this.onboardingWaivedAt,
      onboardingRefundedAt: onboardingRefundedAt ?? this.onboardingRefundedAt,
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
