/// Phase DLV-1A — rider, offer and money vocabulary for the delivery module.
///
/// Every enum keeps the string already stored in Firestore as its [wire]
/// value where one exists, and parses every legacy spelling found in the
/// repository at 71630df. `fromWire` never throws.
library;

String? _norm(String? v) => v?.trim().toLowerCase();

/// Rider availability. Target replacement for delivery_partners.isOnline /
/// isAvailable / currentOrderId (not yet written anywhere — DLV-2).
enum RiderDutyStatus {
  offline('offline'),
  online('online'),
  onTask('on_task'),
  onBreak('on_break'),
  suspended('suspended');

  const RiderDutyStatus(this.wire);
  final String wire;

  static RiderDutyStatus fromWire(String? value) {
    final v = _norm(value);
    for (final s in values) {
      if (s.wire == v) return s;
    }
    return offline;
  }
}

/// delivery_partners.status. Wire values are exactly today's strings:
/// DLV-0's create rule requires 'pending' and isDeliveryPartner() /
/// roleClaims.ts require 'approved'.
enum RiderKycStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected'),
  suspended('suspended'),
  deactivated('deactivated');

  const RiderKycStatus(this.wire);
  final String wire;

  /// Only an approved rider may go online or take orders.
  bool get canOperate => this == approved;

  /// Absent reads as pending — add_delivery_partner_dialog.dart has never
  /// written `status`, and apps/delivery's auth_provider.dart treats that as
  /// pending (DLV-1B fixes the dialog).
  static RiderKycStatus fromWire(String? value) {
    final v = _norm(value);
    for (final s in values) {
      if (s.wire == v) return s;
    }
    return pending;
  }
}

/// delivery_partners.vehicleType.
enum VehicleType {
  bicycle('bicycle'),
  bike('bike'),
  scooter('scooter'),
  ev('ev'),
  threeWheeler('three_wheeler'),
  car('car'),
  van('van');

  const VehicleType(this.wire);
  final String wire;

  static const Map<String, VehicleType> _aliases = {
    // partner_registration_screen.dart offers Bike / Cycle / Van.
    'cycle': bicycle,
    'motorbike': bike,
    'motorcycle': bike,
    'two_wheeler': bike,
    'electric': ev,
    'auto': threeWheeler,
  };

  /// Unknown or absent reads as bike, DeliveryPartnerModel's own default.
  static VehicleType fromWire(String? value) {
    final v = _norm(value);
    for (final s in values) {
      if (s.wire == v) return s;
    }
    return _aliases[v] ?? bike;
  }
}

/// One offer of one order to one rider (delivery_requests/*).
enum DeliveryOfferStatus {
  offered('offered'),
  accepted('accepted'),
  declined('declined'),
  expired('expired'),
  withdrawn('withdrawn');

  const DeliveryOfferStatus(this.wire);
  final String wire;

  static const Map<String, DeliveryOfferStatus> _aliases = {
    // functions/src/admin/notifications.ts writes "pending" for a new offer.
    'pending': offered,
    'rejected': declined,
    'closed': withdrawn,
    'cancelled': withdrawn,
  };

  static DeliveryOfferStatus? fromWire(String? value) {
    final v = _norm(value);
    for (final s in values) {
      if (s.wire == v) return s;
    }
    return _aliases[v];
  }
}

/// Why a delivery attempt failed or a rider released an order.
enum DeliveryFailureReason {
  customerUnreachable('customer_unreachable'),
  customerRefused('customer_refused'),
  wrongAddress('wrong_address'),
  addressNotFound('address_not_found'),
  paymentIssue('payment_issue'),
  // DLV-E1: goods damaged or missing when the rider reached the customer.
  damagedGoods('damaged_goods'),
  sellerNotReady('seller_not_ready'),
  vehicleIssue('vehicle_issue'),
  safety('safety'),
  other('other');

  const DeliveryFailureReason(this.wire);
  final String wire;

  static DeliveryFailureReason fromWire(String? value) {
    final v = _norm(value);
    for (final s in values) {
      if (s.wire == v) return s;
    }
    return other;
  }
}

/// orders.codSettlementStatus. 'pending' is what confirmDelivery writes today.
enum CodSettlementStatus {
  notApplicable('not_applicable'),
  pending('pending'),
  collected('collected'),
  deposited('deposited'),
  reconciled('reconciled'),
  disputed('disputed');

  const CodSettlementStatus(this.wire);
  final String wire;

  static CodSettlementStatus fromWire(String? value) {
    final v = _norm(value);
    for (final s in values) {
      if (s.wire == v) return s;
    }
    return notApplicable;
  }
}

/// A line in a rider's earnings ledger (DLV-4).
enum EarningType {
  tripBase('trip_base'),
  distance('distance'),
  waiting('waiting'),
  surge('surge'),
  incentive('incentive'),
  tip('tip'),
  penalty('penalty'),
  adjustment('adjustment');

  const EarningType(this.wire);
  final String wire;

  /// Null for an unknown value: an earnings line must never be silently
  /// re-typed.
  static EarningType? fromWire(String? value) {
    final v = _norm(value);
    for (final s in values) {
      if (s.wire == v) return s;
    }
    return null;
  }
}
