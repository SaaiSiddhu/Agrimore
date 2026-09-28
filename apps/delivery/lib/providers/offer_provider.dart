// lib/providers/offer_provider.dart
//
// Phase DLV-2B — the offers sent to this rider (delivery_requests, written by
// functions/src/delivery/dispatch.ts). Replaces the platform-wide
// "Available Orders" list (D-DLV-LIST): a rider sees only its own offers, with
// no customer details until it accepts through acceptDeliveryOffer.
//
// The listener is an equality-only query (riderId + status), so it needs no
// composite index; expiry is applied here.
import '../l10n/app_localizations.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../offers/delivery_offer.dart';

/// The outcome of an accept/decline, already in the rider's words.
/// An accept/decline outcome; a refusal keeps the callable's code and
/// details.reason, and is worded by [message].
class OfferActionResult {
  final bool ok;
  final String? code;
  final String? reason;
  const OfferActionResult.success() : ok = true, code = null, reason = null;
  const OfferActionResult.failure(String this.code, [this.reason]) : ok = false;

  String? message(AppLocalizations l) => ok ? null : offerRefusalMessage(l, code: code!, reason: reason);
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
  bool _disposed = false;

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

  // Section 6 (2026-09-28 continuation review): an account switch rekeys
  // OfferCoordinator (RiderSessionGate.build() returns a new
  // ValueKey(uid)), which tears the old element down and mounts the new
  // one in the SAME build pass -- old.dispose() calls this directly, and
  // new.initState()'s own start() calls it again first (the same shared
  // OfferProvider instance still holds the previous rider's _riderId/_sub,
  // so start()'s own `if (_riderId == riderId && _sub != null) return;`
  // guard does not short-circuit). A synchronous notifyListeners() here
  // then tries to mark this provider's InheritedProvider scope -- an
  // ANCESTOR of RiderSessionGate, not a descendant -- dirty while
  // RiderSessionGate is still building: Flutter explicitly forbids that
  // ("a widget can be marked as needing to be built during the build
  // phase only if one of its ANCESTORS is currently building"), and
  // throws. Found only by a genuinely connected test driving a real
  // account switch through the real widget tree -- no existing test
  // (offers_test.dart, delivery_shell_test.dart) ever called start()/
  // stop() on a real OfferProvider. The state mutation stays synchronous;
  // only the notification is deferred a frame, which every real call site
  // (a fresh start(), a plain sign-out) tolerates identically.
  void stop() {
    _sub?.cancel();
    _sub = null;
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _riderId = null;
    _offers = const [];
    _announced.clear();
    // Guarded: this callback can outlive the widget tree that scheduled it
    // (e.g. a test's own teardown replaces the whole tree, disposing this
    // provider, before the next frame the callback was deferred to).
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) notifyListeners();
    });
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
      return OfferActionResult.failure(e.code, reason);
    } catch (e) {
      debugPrint('$name failed: $e');
      return const OfferActionResult.failure('unknown');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _expiryTimer?.cancel();
    super.dispose();
  }
}
