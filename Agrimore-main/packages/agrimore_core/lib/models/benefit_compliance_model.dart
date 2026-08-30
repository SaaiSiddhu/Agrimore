import 'package:cloud_firestore/cloud_firestore.dart';

/// Valid values for every review/approval status field on
/// [BenefitComplianceModel]. Stored as plain strings in Firestore (not a
/// native Firestore enum type) — any value outside this set is treated as
/// [notStarted] by [BenefitComplianceModel.fromMap], never as [approved].
class BenefitReviewStatus {
  BenefitReviewStatus._();

  static const String notStarted = 'NOT_STARTED';
  static const String inReview = 'IN_REVIEW';
  static const String approved = 'APPROVED';
  static const String rejected = 'REJECTED';

  static const List<String> values = [notStarted, inReview, approved, rejected];

  /// Fail-closed parse: anything not in [values] (missing, garbage, or an
  /// unrecognized string) resolves to [notStarted] — never to [approved].
  static String parse(dynamic value) {
    if (value is String && values.contains(value)) return value;
    return notStarted;
  }
}

/// Legal/compliance approval record for the Customer Product Benefit
/// Program. Stored as the singleton document at
/// /compliance_config/{programId} (programId is currently always
/// 'benefit_program'). This document is Cloud-Function write-only and
/// admin-read-only — see firestore.rules.
///
/// Every status field defaults to [BenefitReviewStatus.notStarted] when the
/// document or field is missing, so an absent document is never mistaken
/// for approval.
class BenefitComplianceModel {
  final String id;

  final String legalReviewStatus;
  final String complianceApprovalStatus;
  final String? approvedMarketingCopyVersion;
  final String? approvedBenefitStructure;
  final String? approvedProductTerms;
  final DateTime? approvalDate;
  final String? reviewer;
  final String jurisdiction;
  final String? internalNotes;

  /// Banning of Unregulated Deposit Schemes Act, 2019 review status.
  final String budsActReviewStatus;

  /// Reserve Bank of India review status.
  final String rbiReviewStatus;
  final String? legalOpinionDocumentRef;

  final DateTime updatedAt;
  final String? updatedBy;

  const BenefitComplianceModel({
    required this.id,
    this.legalReviewStatus = BenefitReviewStatus.notStarted,
    this.complianceApprovalStatus = BenefitReviewStatus.notStarted,
    this.approvedMarketingCopyVersion,
    this.approvedBenefitStructure,
    this.approvedProductTerms,
    this.approvalDate,
    this.reviewer,
    this.jurisdiction = 'IN-TN',
    this.internalNotes,
    this.budsActReviewStatus = BenefitReviewStatus.notStarted,
    this.rbiReviewStatus = BenefitReviewStatus.notStarted,
    this.legalOpinionDocumentRef,
    required this.updatedAt,
    this.updatedBy,
  });

  /// The fail-closed default: every status NOT_STARTED, i.e. not launchable.
  /// Used whenever /compliance_config/{programId} does not exist.
  factory BenefitComplianceModel.notStarted(String id) {
    return BenefitComplianceModel(id: id, updatedAt: DateTime.fromMillisecondsSinceEpoch(0));
  }

  factory BenefitComplianceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return BenefitComplianceModel.fromMap(data, doc.id);
  }

  factory BenefitComplianceModel.fromMap(Map<String, dynamic> map, String id) {
    return BenefitComplianceModel(
      id: id,
      legalReviewStatus: BenefitReviewStatus.parse(map['legalReviewStatus']),
      complianceApprovalStatus:
          BenefitReviewStatus.parse(map['complianceApprovalStatus']),
      approvedMarketingCopyVersion: map['approvedMarketingCopyVersion'] as String?,
      approvedBenefitStructure: map['approvedBenefitStructure'] as String?,
      approvedProductTerms: map['approvedProductTerms'] as String?,
      approvalDate: _parseNullableDateTime(map['approvalDate']),
      reviewer: map['reviewer'] as String?,
      jurisdiction: (map['jurisdiction'] as String?) ?? 'IN-TN',
      internalNotes: map['internalNotes'] as String?,
      budsActReviewStatus: BenefitReviewStatus.parse(map['budsActReviewStatus']),
      rbiReviewStatus: BenefitReviewStatus.parse(map['rbiReviewStatus']),
      legalOpinionDocumentRef: map['legalOpinionDocumentRef'] as String?,
      updatedAt: _parseDateTime(map['updatedAt']),
      updatedBy: map['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'legalReviewStatus': legalReviewStatus,
      'complianceApprovalStatus': complianceApprovalStatus,
      'approvedMarketingCopyVersion': approvedMarketingCopyVersion,
      'approvedBenefitStructure': approvedBenefitStructure,
      'approvedProductTerms': approvedProductTerms,
      'approvalDate':
          approvalDate == null ? null : Timestamp.fromDate(approvalDate!),
      'reviewer': reviewer,
      'jurisdiction': jurisdiction,
      'internalNotes': internalNotes,
      'budsActReviewStatus': budsActReviewStatus,
      'rbiReviewStatus': rbiReviewStatus,
      'legalOpinionDocumentRef': legalOpinionDocumentRef,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'updatedBy': updatedBy,
    };
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static DateTime? _parseNullableDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// True only when both legal and compliance review are APPROVED — the
  /// same condition Cloud Functions' assertProgramLaunchable() checks
  /// (functions/src/admin/complianceGate.ts), duplicated here for admin UI
  /// display only. This getter has no effect on server-side enforcement.
  bool get isFullyApproved =>
      legalReviewStatus == BenefitReviewStatus.approved &&
      complianceApprovalStatus == BenefitReviewStatus.approved;

  BenefitComplianceModel copyWith({
    String? id,
    String? legalReviewStatus,
    String? complianceApprovalStatus,
    String? approvedMarketingCopyVersion,
    String? approvedBenefitStructure,
    String? approvedProductTerms,
    DateTime? approvalDate,
    String? reviewer,
    String? jurisdiction,
    String? internalNotes,
    String? budsActReviewStatus,
    String? rbiReviewStatus,
    String? legalOpinionDocumentRef,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return BenefitComplianceModel(
      id: id ?? this.id,
      legalReviewStatus: legalReviewStatus ?? this.legalReviewStatus,
      complianceApprovalStatus:
          complianceApprovalStatus ?? this.complianceApprovalStatus,
      approvedMarketingCopyVersion:
          approvedMarketingCopyVersion ?? this.approvedMarketingCopyVersion,
      approvedBenefitStructure:
          approvedBenefitStructure ?? this.approvedBenefitStructure,
      approvedProductTerms: approvedProductTerms ?? this.approvedProductTerms,
      approvalDate: approvalDate ?? this.approvalDate,
      reviewer: reviewer ?? this.reviewer,
      jurisdiction: jurisdiction ?? this.jurisdiction,
      internalNotes: internalNotes ?? this.internalNotes,
      budsActReviewStatus: budsActReviewStatus ?? this.budsActReviewStatus,
      rbiReviewStatus: rbiReviewStatus ?? this.rbiReviewStatus,
      legalOpinionDocumentRef:
          legalOpinionDocumentRef ?? this.legalOpinionDocumentRef,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  @override
  String toString() =>
      'BenefitCompliance(legal: $legalReviewStatus, compliance: $complianceApprovalStatus)';
}
