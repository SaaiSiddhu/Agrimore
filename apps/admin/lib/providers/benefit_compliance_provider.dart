import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:agrimore_core/agrimore_core.dart';

/// One entry from the Cloud-Function-write-only `compliance_audit_log`
/// collection — display data only, read via [BenefitComplianceProvider].
class BenefitAuditLogEntry {
  final String id;
  final String actorUid;
  final String? actorEmail;
  final String action;
  final String target;
  final dynamic previousValue;
  final dynamic newValue;
  final String? reason;
  final DateTime? createdAt;

  const BenefitAuditLogEntry({
    required this.id,
    required this.actorUid,
    this.actorEmail,
    required this.action,
    required this.target,
    this.previousValue,
    this.newValue,
    this.reason,
    this.createdAt,
  });

  factory BenefitAuditLogEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return BenefitAuditLogEntry(
      id: doc.id,
      actorUid: data['actorUid'] as String? ?? '',
      actorEmail: data['actorEmail'] as String?,
      action: data['action'] as String? ?? '',
      target: data['target'] as String? ?? '',
      previousValue: data['previousValue'],
      newValue: data['newValue'],
      reason: data['reason'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Admin provider for the Customer Product Benefit Program's compliance and
/// feature-flag control plane (Phase A).
///
/// `feature_flags/benefit_program` and `compliance_config/benefit_program`
/// are both write:false in firestore.rules for every client, including this
/// admin app — the ONLY way to change either document is through the
/// `setBenefitFeatureFlag`/`setComplianceStatus` callables in
/// functions/src/admin/complianceGate.ts, which audit-log every change.
/// This provider streams the two documents read-only and forwards writes to
/// those callables; it never writes to Firestore directly.
class BenefitComplianceProvider with ChangeNotifier {
  BenefitComplianceProvider({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance {
    _listen();
  }

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  StreamSubscription<DocumentSnapshot>? _flagsSub;
  StreamSubscription<DocumentSnapshot>? _complianceSub;
  StreamSubscription<QuerySnapshot>? _auditSub;

  BenefitFeatureFlagsModel _flags = BenefitFeatureFlagsModel.disabled();
  BenefitComplianceModel _compliance =
      BenefitComplianceModel.notStarted('benefit_program');
  List<BenefitAuditLogEntry> _auditLog = [];

  bool _isLoading = true;
  bool _isMutating = false;
  String? _error;

  BenefitFeatureFlagsModel get flags => _flags;
  BenefitComplianceModel get compliance => _compliance;
  List<BenefitAuditLogEntry> get auditLog => _auditLog;
  bool get isLoading => _isLoading;
  bool get isMutating => _isMutating;
  String? get error => _error;

  /// Client-side mirror of assertProgramLaunchable() in
  /// functions/src/admin/complianceGate.ts, for display only — the server
  /// callable is the actual enforcement point, not this getter.
  bool get isLaunchable =>
      _compliance.legalReviewStatus == BenefitReviewStatus.approved &&
      _compliance.complianceApprovalStatus == BenefitReviewStatus.approved &&
      _flags.benefitProgramEnabled;

  List<String> get launchBlockedReasons {
    final reasons = <String>[];
    if (_compliance.legalReviewStatus != BenefitReviewStatus.approved) {
      reasons.add('Legal review is not APPROVED');
    }
    if (_compliance.complianceApprovalStatus != BenefitReviewStatus.approved) {
      reasons.add('Compliance approval is not APPROVED');
    }
    if (!_flags.benefitProgramEnabled) {
      reasons.add('BENEFIT_PROGRAM_ENABLED is off');
    }
    return reasons;
  }

  void _listen() {
    _flagsSub = _db
        .doc('feature_flags/benefit_program')
        .snapshots()
        .listen((doc) {
      _flags = doc.exists
          ? BenefitFeatureFlagsModel.fromMap(doc.data())
          : BenefitFeatureFlagsModel.disabled();
      _isLoading = false;
      notifyListeners();
    }, onError: (e) {
      debugPrint('BenefitComplianceProvider: flags stream error: $e');
      _flags = BenefitFeatureFlagsModel.disabled();
      _isLoading = false;
      notifyListeners();
    });

    _complianceSub = _db
        .doc('compliance_config/benefit_program')
        .snapshots()
        .listen((doc) {
      _compliance = doc.exists
          ? BenefitComplianceModel.fromFirestore(doc)
          : BenefitComplianceModel.notStarted('benefit_program');
      notifyListeners();
    }, onError: (e) {
      debugPrint('BenefitComplianceProvider: compliance stream error: $e');
      _compliance = BenefitComplianceModel.notStarted('benefit_program');
      notifyListeners();
    });

    _auditSub = _db
        .collection('compliance_audit_log')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snap) {
      _auditLog = snap.docs.map(BenefitAuditLogEntry.fromFirestore).toList();
      notifyListeners();
    }, onError: (e) {
      debugPrint('BenefitComplianceProvider: audit log stream error: $e');
    });
  }

  /// Calls setBenefitFeatureFlag. Returns true on success; on failure sets
  /// [error] to a human-readable message (including the server's refusal
  /// reason for hard-blocked or approval-gated flags) and returns false.
  Future<bool> setFlag({
    required String flag,
    required bool value,
    required String reason,
  }) async {
    _isMutating = true;
    _error = null;
    notifyListeners();

    try {
      final callable = _functions.httpsCallable('setBenefitFeatureFlag');
      await callable.call({'flag': flag, 'value': value, 'reason': reason});
      _isMutating = false;
      notifyListeners();
      return true;
    } on FirebaseFunctionsException catch (e) {
      _error = e.message ?? 'Failed to update $flag';
      _isMutating = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Failed to update $flag: $e';
      _isMutating = false;
      notifyListeners();
      return false;
    }
  }

  /// Calls setComplianceStatus. `value` may be a String, a DateTime (for
  /// approvalDate), or null.
  Future<bool> setComplianceField({
    required String field,
    required Object? value,
    required String reason,
  }) async {
    _isMutating = true;
    _error = null;
    notifyListeners();

    try {
      final callable = _functions.httpsCallable('setComplianceStatus');
      final serializedValue =
          value is DateTime ? value.toIso8601String() : value;
      await callable.call({
        'field': field,
        'value': serializedValue,
        'reason': reason,
      });
      _isMutating = false;
      notifyListeners();
      return true;
    } on FirebaseFunctionsException catch (e) {
      _error = e.message ?? 'Failed to update $field';
      _isMutating = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Failed to update $field: $e';
      _isMutating = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _flagsSub?.cancel();
    _complianceSub?.cancel();
    _auditSub?.cancel();
    super.dispose();
  }
}
