// lib/screens/admin/delivery/rider_review.dart
//
// Phase DLV-1B — what an admin can do to a delivery partner's onboarding
// status, and the exact write it makes.
//
// Admin-client writes, mirroring seller_requests_management_screen.dart's
// precedent (the admin branch of firestore.rules is unrestricted; DLV-0's
// owner allowlist stops a rider forging any of these fields —
// phaseDLV1B_rider_review_rules_test.js). The live syncDeliveryRoleClaims /
// syncUserRoleClaims triggers re-mint the rider's custom claim from the
// result. A revoked claim reaches the rider's ID token on its next refresh
// (up to an hour); the rider app also listens to its own status and leaves
// duty immediately.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_core/agrimore_core.dart';

enum RiderReviewAction { approve, reject, suspend, reinstate }

extension RiderReviewActionX on RiderReviewAction {
  String get label => switch (this) {
        RiderReviewAction.approve => 'Approve',
        RiderReviewAction.reject => 'Reject',
        RiderReviewAction.suspend => 'Suspend',
        RiderReviewAction.reinstate => 'Reinstate',
      };

  /// Reject and suspend must say why — the rider is shown this reason.
  bool get needsReason =>
      this == RiderReviewAction.reject || this == RiderReviewAction.suspend;

  RiderKycStatus get resultingStatus => switch (this) {
        RiderReviewAction.approve => RiderKycStatus.approved,
        RiderReviewAction.reject => RiderKycStatus.rejected,
        RiderReviewAction.suspend => RiderKycStatus.suspended,
        RiderReviewAction.reinstate => RiderKycStatus.approved,
      };

  String get successMessage => switch (this) {
        RiderReviewAction.approve => 'Delivery partner approved',
        RiderReviewAction.reject => 'Application rejected',
        RiderReviewAction.suspend => 'Delivery partner suspended',
        RiderReviewAction.reinstate => 'Delivery partner reinstated',
      };
}

/// The actions offered for a partner in [status].
List<RiderReviewAction> availableRiderActions(RiderKycStatus status) =>
    switch (status) {
      RiderKycStatus.pending => const [
          RiderReviewAction.approve,
          RiderReviewAction.reject,
        ],
      // A rejected applicant can be approved on re-review (e.g. after they
      // send a clearer document to support).
      RiderKycStatus.rejected => const [RiderReviewAction.approve],
      RiderKycStatus.approved => const [RiderReviewAction.suspend],
      RiderKycStatus.suspended => const [RiderReviewAction.reinstate],
      RiderKycStatus.deactivated => const [],
    };

/// Applies [action] to partner [uid] in one batch.
///
/// `users/{uid}.deliveryStatus` is written too: roleClaims.ts counts a rider as
/// approved when EITHER that field or `delivery_partners.status` says so, so a
/// stale 'approved' there would keep a suspended rider's claim.
Future<void> applyRiderReview({
  required FirebaseFirestore firestore,
  required String uid,
  required RiderReviewAction action,
  required String adminUid,
  String? reason,
}) async {
  final status = action.resultingStatus;
  final trimmed = reason?.trim();
  final partner = <String, dynamic>{
    'status': status.wire,
    'reviewedBy': adminUid,
    'reviewedAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };
  switch (action) {
    case RiderReviewAction.approve:
      partner['rejectionReason'] = null;
    case RiderReviewAction.reject:
      partner['rejectionReason'] = trimmed;
    case RiderReviewAction.suspend:
      partner['suspensionReason'] = trimmed;
      // Off duty now; the rider app also stops its own tracking on the
      // status change.
      partner['isOnline'] = false;
    case RiderReviewAction.reinstate:
      partner['suspensionReason'] = null;
  }

  final batch = firestore.batch()
    ..set(firestore.collection('delivery_partners').doc(uid), partner,
        SetOptions(merge: true))
    ..set(firestore.collection('users').doc(uid),
        {'deliveryStatus': status.wire}, SetOptions(merge: true));
  await batch.commit();
}

/// Display name for a vehicle type (the enum name reads as 'Ev').
String vehicleLabel(VehicleType v) => switch (v) {
      VehicleType.bicycle => 'Bicycle',
      VehicleType.bike => 'Bike',
      VehicleType.scooter => 'Scooter',
      VehicleType.ev => 'EV',
      VehicleType.threeWheeler => 'Three-wheeler',
      VehicleType.car => 'Car',
      VehicleType.van => 'Van',
    };

/// Last four digits only — the review sheet never shows a full account or
/// Aadhaar number.
String maskTail(String? value, {int keep = 4}) {
  final v = (value ?? '').replaceAll(RegExp(r'\s|-'), '');
  if (v.isEmpty) return 'Not provided';
  if (v.length <= keep) return '•' * v.length;
  return '•••• ${v.substring(v.length - keep)}';
}
