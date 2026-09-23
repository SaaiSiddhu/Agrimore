// lib/screens/admin/delivery/dispatch_queue.dart
//
// Phase DLV-2C — what the admin dispatch queue reads and the one write it
// makes (manual rider assignment).
//
// Reads DLV-2A's server-written collections (both admin-readable, neither
// client-writable): delivery_dispatch/{orderId} — wave state and the
// needsAdmin flag (D-DLV-NO-TAKER) — and delivery_requests/{orderId}_{rider},
// one per offer. Every query is equality-only, so no composite index.
//
// The assignment writes the same order fields as the acceptDeliveryOffer
// callable (functions/src/delivery/dispatchCallables.ts): orderStatus and
// status `delivery_accepted`. That is the state the rider app shows as an
// active order, and onOrderStatusChanged answers it by closing dispatch
// (withdrawing open offers) at once. The pre-DLV-2C screen wrote
// `ready_for_pickup`, which the rider app never shows.
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_core/agrimore_core.dart';

/// Order statuses in which a rider is on a job. Mirrors
/// RIDER_ACTIVE_ORDER_STATUSES in functions/src/delivery/dispatch.ts
/// (test/dispatch_queue_test.dart checks the two agree).
const List<String> riderActiveOrderStatuses = [
  'delivery_accepted',
  'arrived_at_store',
  'reached_pickup',
  'picked_up',
  'parcel_picked',
  'out_for_delivery',
  'outfordelivery',
  'outForDelivery',
];

/// A rider location older than this is not used for dispatch. Mirrors
/// LOCATION_FRESHNESS_MS in functions/src/delivery/dispatch.ts.
const Duration locationFreshness = Duration(minutes: 5);

DateTime? _date(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  return null;
}

double? _num(dynamic v) => v is num ? v.toDouble() : null;

String? _str(dynamic v) => v is String && v.trim().isNotEmpty ? v : null;

List<String> _strings(dynamic v) =>
    v is List ? v.whereType<String>().toList() : const [];

/// Cash on delivery, by the same test as dispatch.ts isCod.
bool isCashOnDelivery(dynamic paymentMethod) {
  final m = paymentMethod is String ? paymentMethod.toLowerCase() : '';
  return m == 'cod' || m == 'cash_on_delivery' || m.contains('cash');
}

/// One delivery_dispatch document.
class DispatchEntry {
  DispatchEntry({
    required this.orderId,
    required this.status,
    required this.wave,
    required this.radiusKm,
    required this.needsAdmin,
    required this.needsAdminSince,
    required this.startedAt,
    required this.lastWaveAt,
    required this.offeredTo,
    required this.declinedBy,
    required this.assignedTo,
    required this.stopReason,
  });

  factory DispatchEntry.fromMap(String id, Map<String, dynamic> m) =>
      DispatchEntry(
        orderId: _str(m['orderId']) ?? id,
        status: _str(m['status']) ?? 'unknown',
        wave: (m['wave'] as num?)?.toInt() ?? 0,
        radiusKm: _num(m['radiusKm']),
        needsAdmin: m['needsAdmin'] == true,
        needsAdminSince: _date(m['needsAdminSince']),
        startedAt: _date(m['startedAt']),
        lastWaveAt: _date(m['lastWaveAt']),
        offeredTo: _strings(m['offeredTo']),
        declinedBy: _strings(m['declinedBy']),
        assignedTo: _str(m['assignedTo']),
        stopReason: _str(m['stopReason']),
      );

  final String orderId;
  final String status;
  final int wave;
  final double? radiusKm;
  final bool needsAdmin;
  final DateTime? needsAdminSince;
  final DateTime? startedAt;
  final DateTime? lastWaveAt;
  final List<String> offeredTo;
  final List<String> declinedBy;
  final String? assignedTo;
  final String? stopReason;

  bool get isOpen => status == 'dispatching';

  /// Waves 1–3 are the first round (5 / 8 / 12 km); later waves are the
  /// every-2-minute retries of D-DLV-NO-TAKER.
  bool get isRetrying => wave > 3;

  Duration searchingFor(DateTime now) =>
      startedAt == null ? Duration.zero : now.difference(startedAt!);
}

/// Needs-a-rider orders first, the longest-flagged first; then the rest of
/// the searching orders, the longest-searching first.
List<DispatchEntry> sortDispatchQueue(Iterable<DispatchEntry> entries) {
  final list = entries.toList();
  int byDate(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }

  list.sort((a, b) {
    if (a.needsAdmin != b.needsAdmin) return a.needsAdmin ? -1 : 1;
    final c = a.needsAdmin
        ? byDate(a.needsAdminSince ?? a.startedAt, b.needsAdminSince ?? b.startedAt)
        : byDate(a.startedAt, b.startedAt);
    return c != 0 ? c : a.orderId.compareTo(b.orderId);
  });
  return list;
}

/// One delivery_requests document: one offer of the order to one rider.
class OfferEvent {
  OfferEvent({
    required this.riderId,
    required this.wave,
    required this.status,
    required this.rawStatus,
    required this.pickupDistanceKm,
    required this.offeredAt,
    required this.expiresAt,
    required this.closedAt,
  });

  factory OfferEvent.fromMap(Map<String, dynamic> m) => OfferEvent(
        riderId: _str(m['riderId']) ?? _str(m['partnerId']) ?? '',
        wave: (m['wave'] as num?)?.toInt(),
        status: DeliveryOfferStatus.fromWire(m['status'] as String?),
        rawStatus: _str(m['status']) ?? '',
        pickupDistanceKm: _num(m['pickupDistanceKm']),
        offeredAt: _date(m['createdAt']),
        expiresAt: _date(m['expiresAt']),
        closedAt: _date(m['acceptedAt']) ?? _date(m['closedAt']),
      );

  final String riderId;
  final int? wave;
  final DeliveryOfferStatus? status;
  final String rawStatus;
  final double? pickupDistanceKm;
  final DateTime? offeredAt;
  final DateTime? expiresAt;
  final DateTime? closedAt;

  /// An `offered` document past its 30 s is expired even before the
  /// scheduler marks it (it runs once a minute).
  bool isLive(DateTime now) =>
      status == DeliveryOfferStatus.offered &&
      (expiresAt == null || expiresAt!.isAfter(now));

  String label(DateTime now) => switch (status) {
        DeliveryOfferStatus.offered => isLive(now) ? 'Ringing' : 'No answer',
        DeliveryOfferStatus.accepted => 'Accepted',
        DeliveryOfferStatus.declined => 'Declined',
        DeliveryOfferStatus.expired => 'No answer',
        DeliveryOfferStatus.withdrawn => 'Withdrawn',
        null => rawStatus.isEmpty ? 'Unknown' : rawStatus,
      };
}

/// Offers in the order they were made: by wave, then time.
List<OfferEvent> sortOfferTimeline(Iterable<OfferEvent> offers) {
  final list = offers.toList();
  list.sort((a, b) {
    final w = (a.wave ?? 0).compareTo(b.wave ?? 0);
    if (w != 0) return w;
    final at = a.offeredAt, bt = b.offeredAt;
    if (at != null && bt != null && at != bt) return at.compareTo(bt);
    return a.riderId.compareTo(b.riderId);
  });
  return list;
}

/// Great-circle distance in km (the same formula as dispatch.ts distanceKm).
double greatCircleKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) *
          math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(a)));
}

/// Why a rider can or cannot be given an order right now, best first.
enum RiderAvailability {
  /// Online, free, location fresh.
  available,

  /// Online and free, but the last location is older than 5 min — the
  /// distance shown may be wrong.
  staleLocation,

  /// Online and free, but has never shared a location.
  noLocation,

  /// On another order.
  busy,

  /// Off duty.
  offline;

  bool get canAssign =>
      this == available || this == staleLocation || this == noLocation;
}

/// An approved rider as the assignment screen lists them.
class AssignableRider {
  AssignableRider({
    required this.id,
    required this.name,
    required this.phone,
    required this.vehicleType,
    required this.vehicleNumber,
    required this.availability,
    required this.locationAge,
    required this.distanceKm,
    required this.lat,
    required this.lng,
  });

  /// [pickupLat]/[pickupLng]: the seller pickup point (delivery_tasks
  /// `pickup`), null when unknown. [busy]: riders on an active order.
  factory AssignableRider.fromMap(
    String id,
    Map<String, dynamic> m, {
    required Set<String> busy,
    required DateTime now,
    double? pickupLat,
    double? pickupLng,
  }) {
    final lat = _num(m['currentLat']);
    final lng = _num(m['currentLng']);
    final seen = _date(m['lastLocationUpdate']);
    final age = seen == null ? null : now.difference(seen);
    final RiderAvailability availability;
    if (m['isOnline'] != true) {
      availability = RiderAvailability.offline;
    } else if (busy.contains(id)) {
      availability = RiderAvailability.busy;
    } else if (lat == null || lng == null) {
      availability = RiderAvailability.noLocation;
    } else if (age == null || age > locationFreshness) {
      availability = RiderAvailability.staleLocation;
    } else {
      availability = RiderAvailability.available;
    }
    return AssignableRider(
      id: id,
      name: _str(m['name']) ?? 'Unnamed partner',
      phone: _str(m['phone']) ?? '',
      vehicleType: VehicleType.fromWire(m['vehicleType'] as String?),
      vehicleNumber: _str(m['vehicleNumber']) ?? '',
      availability: availability,
      locationAge: age,
      distanceKm: lat != null && lng != null && pickupLat != null && pickupLng != null
          ? greatCircleKm(pickupLat, pickupLng, lat, lng)
          : null,
      lat: lat,
      lng: lng,
    );
  }

  final String id;
  final String name;
  final String phone;
  final VehicleType vehicleType;
  final String vehicleNumber;
  final RiderAvailability availability;
  final Duration? locationAge;
  final double? distanceKm;
  final double? lat;
  final double? lng;
}

/// Assignable riders first (fresh location, then stale, then none), nearest
/// first within each; then busy, then offline riders, by name.
List<AssignableRider> sortRiders(Iterable<AssignableRider> riders) {
  final list = riders.toList();
  list.sort((a, b) {
    final c = a.availability.index.compareTo(b.availability.index);
    if (c != 0) return c;
    final ad = a.distanceKm, bd = b.distanceKm;
    if (ad != null && bd != null && ad != bd) return ad.compareTo(bd);
    if (ad != null && bd == null) return -1;
    if (ad == null && bd != null) return 1;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return list;
}

String vehicleLabel(VehicleType t) => switch (t) {
      VehicleType.bicycle => 'Bicycle',
      VehicleType.bike => 'Bike',
      VehicleType.scooter => 'Scooter',
      VehicleType.ev => 'EV',
      VehicleType.threeWheeler => 'Three-wheeler',
      VehicleType.car => 'Car',
      VehicleType.van => 'Van',
    };

/// "4 min ago", "2 h ago", "3 d ago".
String formatAge(Duration d) {
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}

/// Whether the order, as stored, can take a rider from the admin:
/// [AssignMode.assign] while it waits for one, [AssignMode.reassign] once a
/// rider has it but has not yet picked it up, null otherwise.
enum AssignMode { assign, reassign }

AssignMode? assignModeFor(Map<String, dynamic> order) {
  final partner = _str(order['deliveryPartnerId']);
  final s = DeliveryTaskStatus.fromOrderStatus(
    orderStatus: order['orderStatus'] as String?,
    status: order['status'] as String?,
    hasPartner: partner != null,
  );
  if (s == DeliveryTaskStatus.searching) return AssignMode.assign;
  if (s == DeliveryTaskStatus.assigned && partner != null) {
    return AssignMode.reassign;
  }
  return null;
}

/// Why an order cannot take a rider, in words an admin can act on.
String notAssignableMessage(Map<String, dynamic> order) {
  final s = DeliveryTaskStatus.fromOrderStatus(
    orderStatus: order['orderStatus'] as String?,
    status: order['status'] as String?,
    hasPartner: _str(order['deliveryPartnerId']) != null,
  );
  return switch (s) {
    null => 'This order is not packed yet. A rider can be assigned once the '
        'seller marks it ready for pickup.',
    DeliveryTaskStatus.delivered ||
    DeliveryTaskStatus.returned =>
      'This order has already been delivered.',
    DeliveryTaskStatus.cancelled => 'This order was cancelled.',
    _ => 'The rider has already picked this order up, so it cannot be '
        'reassigned here.',
  };
}

enum AssignOutcome {
  assigned,
  orderMissing,
  orderNotAssignable,
  alreadyThisRider,
  riderNotApproved,
  riderOffline,
  riderBusy,
}

extension AssignOutcomeX on AssignOutcome {
  /// What the admin is told when the assignment did not happen.
  String get refusalMessage => switch (this) {
        AssignOutcome.assigned => '',
        AssignOutcome.orderMissing => 'This order no longer exists.',
        AssignOutcome.orderNotAssignable =>
          'This order changed and can no longer take this rider. '
              'Refresh and check its status.',
        AssignOutcome.alreadyThisRider =>
          'This rider already has this order.',
        AssignOutcome.riderNotApproved =>
          'This partner is not approved to deliver.',
        AssignOutcome.riderOffline =>
          'This partner has gone offline. Pick someone who is online.',
        AssignOutcome.riderBusy =>
          'This partner has just taken another order. Pick someone else.',
      };
}

/// The order fields written by an admin assignment — the acceptDeliveryOffer
/// set plus who assigned it and the display copy of the rider that customer
/// tracking reads (order_model.dart, delivery_tracking_service.dart).
Map<String, dynamic> assignmentOrderUpdate({
  required String riderId,
  required Map<String, dynamic> rider,
  required String adminUid,
  String? previousRiderId,
}) =>
    {
      'deliveryPartnerId': riderId,
      'orderStatus': 'delivery_accepted',
      'status': 'delivery_accepted',
      'deliveryAcceptedAt': FieldValue.serverTimestamp(),
      'deliveryAcceptedVia': 'admin',
      'deliveryAssignedBy': adminUid,
      if (previousRiderId != null) 'deliveryReassignedFrom': previousRiderId,
      'deliveryPartner': {
        'id': riderId,
        'name': rider['name'],
        'phone': rider['phone'],
        'vehicleType': rider['vehicleType'],
        'vehicleNumber': rider['vehicleNumber'],
        'currentLat': rider['currentLat'],
        'currentLng': rider['currentLng'],
      },
      'updatedAt': FieldValue.serverTimestamp(),
    };

/// Gives [orderId] to [riderId], or says why not.
///
/// The busy check is a query, so it runs just before the transaction (a
/// client transaction cannot hold a query); the order and the rider are
/// re-read inside it, so an order a rider accepted meanwhile, or a rider who
/// went offline or was suspended, is refused rather than overwritten.
Future<AssignOutcome> assignRiderToOrder({
  required FirebaseFirestore firestore,
  required String orderId,
  required String riderId,
  required String adminUid,
}) async {
  final riderOrders = await firestore
      .collection('orders')
      .where('deliveryPartnerId', isEqualTo: riderId)
      .get();
  final busyElsewhere = riderOrders.docs.any((d) =>
      d.id != orderId &&
      riderActiveOrderStatuses.contains(d.data()['orderStatus']));
  if (busyElsewhere) return AssignOutcome.riderBusy;

  final orderRef = firestore.collection('orders').doc(orderId);
  final riderRef = firestore.collection('delivery_partners').doc(riderId);
  return firestore.runTransaction<AssignOutcome>((tx) async {
    final orderSnap = await tx.get(orderRef);
    final riderSnap = await tx.get(riderRef);
    if (!orderSnap.exists) return AssignOutcome.orderMissing;
    final order = orderSnap.data()!;
    final mode = assignModeFor(order);
    if (mode == null) return AssignOutcome.orderNotAssignable;
    final previous = _str(order['deliveryPartnerId']);
    if (previous == riderId) return AssignOutcome.alreadyThisRider;

    final rider = riderSnap.data();
    if (rider == null || rider['status'] != 'approved') {
      return AssignOutcome.riderNotApproved;
    }
    if (rider['isOnline'] != true) return AssignOutcome.riderOffline;

    DocumentSnapshot<Map<String, dynamic>>? previousSnap;
    if (previous != null) {
      previousSnap =
          await tx.get(firestore.collection('delivery_partners').doc(previous));
    }

    tx.update(
      orderRef,
      assignmentOrderUpdate(
        riderId: riderId,
        rider: rider,
        adminUid: adminUid,
        previousRiderId: previous,
      ),
    );
    final timeline = orderRef.collection('timeline').doc();
    tx.set(timeline, {
      'id': timeline.id,
      'status': 'delivery_accepted',
      'title': previous == null ? 'Rider Assigned' : 'Rider Reassigned',
      'description': previous == null
          ? 'Delivery partner ${rider['name'] ?? ''} assigned by admin'.trim()
          : 'Order moved to delivery partner ${rider['name'] ?? ''} by admin'
              .trim(),
      'partnerId': riderId,
      'assignedBy': adminUid,
      'timestamp': FieldValue.serverTimestamp(),
    });
    // Legacy availability fields, kept in step for older readers.
    tx.update(riderRef, {'currentOrderId': orderId, 'isAvailable': false});
    if (previousSnap != null &&
        previousSnap.exists &&
        previousSnap.data()?['currentOrderId'] == orderId) {
      tx.update(previousSnap.reference,
          {'currentOrderId': null, 'isAvailable': true});
    }
    return AssignOutcome.assigned;
  });
}
