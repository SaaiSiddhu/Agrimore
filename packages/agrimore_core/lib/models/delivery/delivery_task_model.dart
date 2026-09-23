import 'package:cloud_firestore/cloud_firestore.dart';

import 'delivery_eta.dart' show DeliveryRoute;
import 'delivery_task_status.dart';

/// Phase DLV-1A — delivery_tasks/{orderId}, one rider leg per order.
///
/// Written ONLY by the syncDeliveryTask Cloud Function (firestore.rules:
/// read by the assigned rider, the customer, the seller and admin; no client
/// write). Deliberately carries no customer name, phone or address text —
/// the drop point is coordinates and pincode only.
class DeliveryTaskModel {
  final String orderId;
  final String? orderNumber;

  /// Null when the stored value is not one this build knows.
  final DeliveryTaskStatus? status;
  final String? riderId;
  final String? sellerId;
  final String? customerId;
  final DeliveryPoint? pickup;
  final DeliveryPoint? drop;
  final String? paymentMethod;
  final double codAmount;

  /// First time the leg entered each status, keyed by [DeliveryTaskStatus.wire].
  final Map<String, DateTime> stepAt;

  /// The raw order status the projection last saw.
  final String? legacyStatus;

  /// False when the last change was a jump [DeliveryTaskStatus.canTransitionTo]
  /// would refuse (admin edits, old clients). Recorded, not enforced.
  final bool lastTransitionAllowed;
  final DateTime? updatedAt;

  /// Phase DLV-3B: the road route the refreshDeliveryRoute function last
  /// computed (Google Routes, D-DLV-ROUTES); null when there is none.
  final DeliveryRoute? route;

  const DeliveryTaskModel({
    required this.orderId,
    this.orderNumber,
    this.status,
    this.riderId,
    this.sellerId,
    this.customerId,
    this.pickup,
    this.drop,
    this.paymentMethod,
    this.codAmount = 0,
    this.stepAt = const {},
    this.legacyStatus,
    this.lastTransitionAllowed = true,
    this.updatedAt,
    this.route,
  });

  bool get isCod => codAmount > 0;

  static DateTime? _date(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }

  factory DeliveryTaskModel.fromMap(Map<String, dynamic> map, String id) {
    final rawSteps = map['stepAt'];
    final steps = <String, DateTime>{};
    if (rawSteps is Map) {
      rawSteps.forEach((k, v) {
        final d = _date(v);
        if (k is String && d != null) steps[k] = d;
      });
    }
    return DeliveryTaskModel(
      orderId: (map['orderId'] as String?) ?? id,
      orderNumber: map['orderNumber'] as String?,
      status: DeliveryTaskStatus.fromWire(map['status'] as String?),
      riderId: map['riderId'] as String?,
      sellerId: map['sellerId'] as String?,
      customerId: map['customerId'] as String?,
      pickup: DeliveryPoint.fromMap(map['pickup']),
      drop: DeliveryPoint.fromMap(map['drop']),
      paymentMethod: map['paymentMethod'] as String?,
      codAmount: (map['codAmount'] as num?)?.toDouble() ?? 0,
      stepAt: steps,
      legacyStatus: map['legacyStatus'] as String?,
      lastTransitionAllowed: map['lastTransitionAllowed'] as bool? ?? true,
      updatedAt: _date(map['updatedAt']),
      route: DeliveryRoute.fromMap(map['route']),
    );
  }

  factory DeliveryTaskModel.fromFirestore(DocumentSnapshot doc) =>
      DeliveryTaskModel.fromMap(
        (doc.data() as Map<String, dynamic>?) ?? const {},
        doc.id,
      );

  Map<String, dynamic> toMap() => {
        'orderId': orderId,
        'orderNumber': orderNumber,
        'status': status?.wire,
        'riderId': riderId,
        'sellerId': sellerId,
        'customerId': customerId,
        'pickup': pickup?.toMap(),
        'drop': drop?.toMap(),
        'paymentMethod': paymentMethod,
        'codAmount': codAmount,
        'stepAt': stepAt.map((k, v) => MapEntry(k, Timestamp.fromDate(v))),
        'legacyStatus': legacyStatus,
        'lastTransitionAllowed': lastTransitionAllowed,
        'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      };

  DeliveryTaskModel copyWith({
    String? orderId,
    String? orderNumber,
    DeliveryTaskStatus? status,
    String? riderId,
    String? sellerId,
    String? customerId,
    DeliveryPoint? pickup,
    DeliveryPoint? drop,
    String? paymentMethod,
    double? codAmount,
    Map<String, DateTime>? stepAt,
    String? legacyStatus,
    bool? lastTransitionAllowed,
    DateTime? updatedAt,
    DeliveryRoute? route,
  }) =>
      DeliveryTaskModel(
        orderId: orderId ?? this.orderId,
        orderNumber: orderNumber ?? this.orderNumber,
        status: status ?? this.status,
        riderId: riderId ?? this.riderId,
        sellerId: sellerId ?? this.sellerId,
        customerId: customerId ?? this.customerId,
        pickup: pickup ?? this.pickup,
        drop: drop ?? this.drop,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        codAmount: codAmount ?? this.codAmount,
        stepAt: stepAt ?? this.stepAt,
        legacyStatus: legacyStatus ?? this.legacyStatus,
        lastTransitionAllowed:
            lastTransitionAllowed ?? this.lastTransitionAllowed,
        updatedAt: updatedAt ?? this.updatedAt,
        route: route ?? this.route,
      );
}

/// A pickup or drop coordinate. Pincode only on the drop.
class DeliveryPoint {
  final double lat;
  final double lng;
  final String? pincode;

  const DeliveryPoint({required this.lat, required this.lng, this.pincode});

  static DeliveryPoint? fromMap(dynamic map) {
    if (map is! Map) return null;
    final lat = (map['lat'] as num?)?.toDouble();
    final lng = (map['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return DeliveryPoint(lat: lat, lng: lng, pincode: map['pincode'] as String?);
  }

  Map<String, dynamic> toMap() => {
        'lat': lat,
        'lng': lng,
        if (pincode != null) 'pincode': pincode,
      };
}
