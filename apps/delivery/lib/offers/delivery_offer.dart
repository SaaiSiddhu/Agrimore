// lib/offers/delivery_offer.dart
//
// Phase DLV-2B — one delivery offer (delivery_requests/{orderId}_{riderId},
// written by functions/src/delivery/dispatch.ts). Carries no customer name,
// phone or address: those are only readable once the rider has accepted.
//
// Pure Dart (no Flutter, no Firebase calls) so the rules below are unit-tested
// in test/offers_test.dart.
import 'package:cloud_firestore/cloud_firestore.dart';

class DeliveryOffer {
  final String orderId;
  final String orderNumber;
  final DateTime expiresAt;
  final double? pickupDistanceKm;
  final String? pickupArea;
  final String? dropPincode;
  final double? dropDistanceKm;
  final int itemCount;
  final double codAmount;
  final int wave;

  /// DLV-4A/4B: pay for this order as offered (base + distance on the
  /// straight line × 1.35); the pay at delivery also counts road distance
  /// and waiting. Null for an offer made before DLV-4A.
  final double? estimatedPay;

  const DeliveryOffer({
    required this.orderId,
    required this.orderNumber,
    required this.expiresAt,
    this.pickupDistanceKm,
    this.pickupArea,
    this.dropPincode,
    this.dropDistanceKm,
    this.itemCount = 0,
    this.codAmount = 0,
    this.wave = 1,
    this.estimatedPay,
  });

  /// Offers last 30 s (dispatch.ts OFFER_TTL_MS); the countdown ring is drawn
  /// against this.
  static const Duration lifetime = Duration(seconds: 30);

  bool get isCod => codAmount > 0;

  Duration remaining(DateTime now) {
    final r = expiresAt.difference(now);
    return r.isNegative ? Duration.zero : r;
  }

  bool isLive(DateTime now) => expiresAt.isAfter(now);

  /// 1.0 at the start of the offer, 0.0 at expiry.
  double fractionLeft(DateTime now) {
    final r = remaining(now).inMilliseconds / lifetime.inMilliseconds;
    return r.clamp(0.0, 1.0);
  }

  static DateTime? _date(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) {
      final ms = int.tryParse(v);
      if (ms != null) return DateTime.fromMillisecondsSinceEpoch(ms);
    }
    return null;
  }

  static double? _num(dynamic v) => v is num ? v.toDouble() : null;

  /// Null when the document is not a usable offer (no order id or expiry).
  static DeliveryOffer? fromMap(Map<String, dynamic> m) {
    final orderId = m['orderId'];
    final expiresAt = _date(m['expiresAt']);
    if (orderId is! String || orderId.isEmpty || expiresAt == null) return null;
    return DeliveryOffer(
      orderId: orderId,
      orderNumber: (m['orderNumber'] as String?) ?? orderId,
      expiresAt: expiresAt,
      pickupDistanceKm: _num(m['pickupDistanceKm']),
      pickupArea: m['pickupArea'] as String?,
      dropPincode: m['dropPincode'] as String?,
      dropDistanceKm: _num(m['dropDistanceKm']),
      itemCount: (m['itemCount'] as num?)?.toInt() ?? 0,
      codAmount: _num(m['codAmount']) ?? 0,
      wave: (m['wave'] as num?)?.toInt() ?? 1,
      estimatedPay: _num(m['estimatedPay']),
    );
  }

  /// One line for the notification body. Mirrors dispatch.ts sendOfferPush,
  /// led by the pay when the offer carries it (DLV-4B).
  String get summary => [
        if (estimatedPay != null) 'Earn ~₹${estimatedPay!.round()}',
        pickupDistanceKm == null
            ? 'Pickup nearby'
            : 'Pickup ${pickupDistanceKm!.toStringAsFixed(1)} km away',
        '$itemCount item${itemCount == 1 ? '' : 's'}',
        if (isCod) 'Collect ₹${codAmount.round()}',
      ].join(' · ');
}

/// What a refused accept/decline means for the rider. `reason` is the
/// callable's details.reason (dispatchCallables.ts); never shows raw server
/// text (feedback.md §2).
String offerRefusalMessage({required String code, String? reason}) {
  if (code == 'failed-precondition') {
    switch (reason) {
      case 'taken':
        return 'Another delivery partner took this order.';
      case 'expired':
        return 'This offer has expired.';
      case 'busy':
        return 'Finish your current delivery before taking another.';
      case 'not_eligible':
        return 'Your account cannot take orders right now.';
      case 'no_offer':
        return 'This order is no longer offered to you.';
    }
  }
  if (code == 'unauthenticated') return 'Please sign in again.';
  if (code == 'unavailable' || code == 'deadline-exceeded') {
    return 'No connection. Check your internet and try again.';
  }
  return 'Could not update this offer. Please try again.';
}

/// Notification payload for an offer, and its inverse.
const String offerPayloadPrefix = 'delivery_offer:';
String offerPayload(String orderId) => '$offerPayloadPrefix$orderId';
String? orderIdFromPayload(String? payload) {
  if (payload == null || !payload.startsWith(offerPayloadPrefix)) return null;
  final id = payload.substring(offerPayloadPrefix.length);
  return id.isEmpty ? null : id;
}

/// The Android tag the server puts on the offer push (dispatch.ts), so the
/// app can clear the system copy when it raises its own full-screen alert.
String offerNotificationTag(String orderId) => 'delivery_offer_$orderId';

/// A notification id that is the same in the main and background isolates
/// (String.hashCode is not guaranteed stable across isolates): 31-bit FNV-1a.
int offerNotificationId(String orderId) {
  var h = 0x811c9dc5;
  for (final c in orderId.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  final id = h & 0x7fffffff;
  // 0 is the id FCM uses for its own system notifications.
  return id == 0 ? 1 : id;
}
