// lib/offers/offer_coordinator.dart
//
// Phase DLV-2B — sits above the dashboard for a signed-in, approved rider:
// starts listening to this rider's offers, rings (the same full-screen,
// insistent alert the background handler raises) and opens the incoming-offer
// screen for each new one, and honours OfferLaunch requests from notification
// taps and full-screen launches. One offer screen at a time; when it closes,
// the next live offer (if any) opens.
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';

import '../providers/offer_provider.dart';
import '../screens/offers/incoming_offer_screen.dart';
import 'delivery_offer.dart';
import 'offer_alerts.dart';
import 'offer_launch.dart';

class OfferCoordinator extends StatefulWidget {
  const OfferCoordinator({super.key, required this.riderId, required this.child});

  final String riderId;
  final Widget child;

  @override
  State<OfferCoordinator> createState() => _OfferCoordinatorState();
}

class _OfferCoordinatorState extends State<OfferCoordinator> {
  late final OfferProvider _offers;

  @override
  void initState() {
    super.initState();
    _offers = context.read<OfferProvider>();
    _offers.onNewOffer = _onNewOffer;
    _offers.addListener(_onOffersChanged);
    OfferLaunch.requested.addListener(_onLaunchRequest);
    _offers.start(widget.riderId);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onLaunchRequest());
  }

  @override
  void dispose() {
    _offers.onNewOffer = null;
    _offers.removeListener(_onOffersChanged);
    OfferLaunch.requested.removeListener(_onLaunchRequest);
    _offers.stop();
    super.dispose();
  }

  void _onNewOffer(DeliveryOffer offer) {
    showOfferAlert(
      FlutterLocalNotificationsPlugin(),
      orderId: offer.orderId,
      expiresAt: offer.expiresAt,
      body: offer.summary,
    );
    _open(offer.orderId);
  }

  /// A requested offer may arrive in the listener after the request.
  void _onOffersChanged() => _onLaunchRequest();

  void _onLaunchRequest() {
    final id = OfferLaunch.requested.value;
    if (id == null) return;
    if (_offers.byOrderId(id) != null) {
      OfferLaunch.clear();
      _open(id);
    }
  }

  void _open(String orderId) {
    if (IncomingOfferScreen.openOrderId != null) return;
    final nav = deliveryNavigatorKey.currentState;
    if (nav == null) return;
    nav
        .push(MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => IncomingOfferScreen(orderId: orderId),
        ))
        .then((_) {
      // Next offer in line, if one is still live.
      final next = _offers.current;
      if (mounted && next != null && next.orderId != orderId) {
        _open(next.orderId);
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
