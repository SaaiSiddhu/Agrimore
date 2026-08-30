import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:agrimore_core/agrimore_core.dart';

/// Reads the Customer Product Benefit Program's feature flags.
///
/// Document: `feature_flags/benefit_program` — public read, Cloud-Function
/// write-only (see firestore.rules). This service never writes it.
///
/// Fails closed on every error path: a missing document, an unreadable
/// field, an offline client, or any Firestore read failure all resolve to
/// every flag being `false`. Callers must never see this service throw.
class BenefitFlagService {
  BenefitFlagService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const _docPath = 'feature_flags/benefit_program';

  BenefitFeatureFlagsModel _cached = BenefitFeatureFlagsModel.disabled();

  /// Last-fetched flags. Starts fully disabled before the first fetch.
  BenefitFeatureFlagsModel get cached => _cached;

  /// Fetches the current flags, updates [cached], and returns them.
  /// Never throws — any failure resolves to all-flags-false.
  Future<BenefitFeatureFlagsModel> fetchFlags() async {
    try {
      final doc = await _db.doc(_docPath).get();
      _cached = doc.exists
          ? BenefitFeatureFlagsModel.fromMap(doc.data())
          : BenefitFeatureFlagsModel.disabled();
    } catch (e) {
      debugPrint('BenefitFlagService.fetchFlags: fail-closed on error: $e');
      _cached = BenefitFeatureFlagsModel.disabled();
    }
    return _cached;
  }

  /// Live updates to the flag document. Any stream error (including
  /// permission or offline errors) fails closed to a fully-disabled value
  /// rather than propagating the error to the listener.
  Stream<BenefitFeatureFlagsModel> watchFlags() {
    return _db.doc(_docPath).snapshots().map((doc) {
      final flags = doc.exists
          ? BenefitFeatureFlagsModel.fromMap(doc.data())
          : BenefitFeatureFlagsModel.disabled();
      _cached = flags;
      return flags;
    }).handleError((e) {
      debugPrint('BenefitFlagService.watchFlags: fail-closed on error: $e');
      _cached = BenefitFeatureFlagsModel.disabled();
      return _cached;
    });
  }

  bool get isBenefitProgramEnabled => _cached.benefitProgramEnabled;
  bool get isNewEnrollmentEnabled => _cached.newEnrollmentEnabled;
  bool get isMonthlyCreditEnabled => _cached.monthlyCreditEnabled;
  bool get isPercentageBenefitEnabled => _cached.percentageBenefitEnabled;
  bool get isBenefitExamplesEnabled => _cached.benefitExamplesEnabled;
  bool get isProductCreditRedemptionEnabled =>
      _cached.productCreditRedemptionEnabled;
  bool get isBenefitAccumulationEnabled => _cached.benefitAccumulationEnabled;
  bool get isCompoundingEnabled => _cached.compoundingEnabled;
  bool get isCashRedemptionEnabled => _cached.cashRedemptionEnabled;
  bool get isPrincipalIntakeEnabled => _cached.principalIntakeEnabled;
  bool get isPrincipalReturnEnabled => _cached.principalReturnEnabled;
}
