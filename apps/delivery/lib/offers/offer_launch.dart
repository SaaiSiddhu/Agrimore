// lib/offers/offer_launch.dart
//
// Phase DLV-2B — the hand-off between "something asked to show an offer"
// (a notification tap, the full-screen alert launching the app, an FCM message
// opening it) and the OfferCoordinator that owns the dashboard. The request is
// held until the rider is signed in and the offer is known.
import 'package:flutter/widgets.dart';

/// The delivery app's root navigator (MaterialApp.navigatorKey).
final GlobalKey<NavigatorState> deliveryNavigatorKey =
    GlobalKey<NavigatorState>();

class OfferLaunch {
  static final ValueNotifier<String?> requested = ValueNotifier<String?>(null);

  static void request(String? orderId) {
    if (orderId == null || orderId.isEmpty) return;
    requested.value = orderId;
  }

  static void clear() => requested.value = null;
}
