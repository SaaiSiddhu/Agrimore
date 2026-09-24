// lib/providers/offer_provider.dart
//
// Phase DLV-2B — the offers sent to this rider (delivery_requests, written by
// functions/src/delivery/dispatch.ts). Replaces the platform-wide
// "Available Orders" list (D-DLV-LIST): a rider sees only its own offers, with
// no customer details until it accepts through acceptDeliveryOffer.
//
// The listener is an equality-only query (riderId + status), so it needs no
// composite index; expiry is applied here.
import 'package:agrimore_core/agrimore_core.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../offers/delivery_offer.dart';

/// The outcome of an accept/decline, already in the rider's words.
class OfferActionResult {
  final bool ok;
  final String? message;
  const OfferActionResult.success() : ok = true, message = null;
  const OfferActionResult.failure(this.message) : ok = false;
}

class OfferProvider extends ChangeNotifier {
  OfferProvider({FirebaseFirestore? firestore, FirebaseFunctions? functions})
      : _firestoreOverride = firestore,
        _functionsOverride = functions;

  // Resolved lazily so constructing the provider never touches Firebase.
  final FirebaseFirestore? _firestoreOverride;
  final FirebaseFunctions? _functionsOverride;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseFunctions get _functions =>
      _functionsOverride ?? FirebaseFunctions.instance;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  Timer? _expiryTimer;
  String? _riderId;
  List<DeliveryOffer> _offers = const [];
  final Set<String> _announced = {};

  /// Called once per newly arrived offer (the coordinator rings and opens it).
  void Function(DeliveryOffer offer)? onNewOffer;

  List<DeliveryOffer> get offers => _offers;

  /// The offer to show: the one expiring soonest.
  DeliveryOffer? get current => _offers.isEmpty ? null : _offers.first;

  DeliveryOffer? byOrderId(String orderId) {
    for (final o in _offers) {
      if (o.orderId == orderId) return o;
    }
    return null;
  }

  void start(String riderId) {
    if (_riderId == riderId && _sub != null) return;
    stop();
    _riderId = riderId;
    _sub = _firestore
        .collection('delivery_requests')
        .where('riderId', isEqualTo: riderId)
        .where('status', isEqualTo: 'offered')
        .snapshots()
        .listen(_onSnapshot, onError: (Object e) {
      debugPrint('Offer listener error: $e');
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _riderId = null;
    _offers = const [];
    _announced.clear();
    notifyListeners();
  }

  void _onSnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
    final now = DateTime.now();
    final live = snap.docs
        .map((d) => DeliveryOffer.fromMap(d.data()))
        .whereType<DeliveryOffer>()
        .where((o) => o.isLive(now))
        .toList()
      ..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    _offers = live;
    _scheduleExpiry();
    notifyListeners();
    for (final o in live) {
      if (_announced.add(o.orderId)) onNewOffer?.call(o);
    }
  }

  /// The server marks offers expired only once a minute; drop them locally
  /// the moment they lapse.
  void _scheduleExpiry() {
    _expiryTimer?.cancel();
    if (_offers.isEmpty) return;
    final wait = _offers.first.remaining(DateTime.now());
    _expiryTimer = Timer(wait + DeliveryTiming.offerExpirySlack, () {
      final now = DateTime.now();
      _offers = _offers.where((o) => o.isLive(now)).toList();
      _scheduleExpiry();
      notifyListeners();
    });
  }

  Future<OfferActionResult> accept(String orderId) => _call(
        'acceptDeliveryOffer',
        {'orderId': orderId},
      );

  /// [reason] is a DeliveryFailureReason wire value or null.
  Future<OfferActionResult> decline(String orderId, {String? reason}) => _call(
        'declineDeliveryOffer',
        {'orderId': orderId, if (reason != null) 'reason': reason},
      );

  Future<OfferActionResult> _call(String name, Map<String, dynamic> data) async {
    try {
      await _functions.httpsCallable(name).call<dynamic>(data);
      _offers = _offers.where((o) => o.orderId != data['orderId']).toList();
      notifyListeners();
      return const OfferActionResult.success();
    } on FirebaseFunctionsException catch (e) {
      debugPrint('$name failed: ${e.code} ${e.message} ${e.details}');
      final reason =
          e.details is Map ? (e.details as Map)['reason'] as String? : null;
      return OfferActionResult.failure(
          offerRefusalMessage(code: e.code, reason: reason));
    } catch (e) {
      debugPrint('$name failed: $e');
      return OfferActionResult.failure(
          offerRefusalMessage(code: 'unknown'));
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _expiryTimer?.cancel();
    super.dispose();
  }
}
