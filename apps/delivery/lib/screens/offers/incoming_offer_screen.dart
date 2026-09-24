// lib/screens/offers/incoming_offer_screen.dart
//
// Phase DLV-2B — the full-screen incoming offer (D-DLV-LIST / D-DLV-ALERT).
// Shows what the offer carries — pickup distance and area, drop pincode and
// distance, item count, cash to collect — never the customer's name, phone or
// address (the rider only gets those by accepting). Accept and decline go
// through DLV-2A's callables; a refusal (taken, expired, busy…) is shown in
// the rider's words and the screen closes.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../offers/delivery_offer.dart';
import '../../offers/offer_alerts.dart';
import '../../offers/offer_launch.dart';
import '../../offers/offer_platform.dart';
import '../../providers/offer_provider.dart';
import '../orders/active_order_screen.dart';

class IncomingOfferScreen extends StatefulWidget {
  const IncomingOfferScreen({super.key, required this.orderId});

  final String orderId;

  /// The order whose offer is on screen, so the coordinator never stacks two.
  static String? openOrderId;

  @override
  State<IncomingOfferScreen> createState() => _IncomingOfferScreenState();
}

class _IncomingOfferScreenState extends State<IncomingOfferScreen> {
  Timer? _tick;
  bool _busy = false;
  bool _closing = false;
  DeliveryOffer? _last;

  @override
  void initState() {
    super.initState();
    IncomingOfferScreen.openOrderId = widget.orderId;
    OfferPlatform.showOverLockScreen(true);
    _tick = Timer.periodic(DeliveryTiming.offerCountdownTick, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    if (IncomingOfferScreen.openOrderId == widget.orderId) {
      IncomingOfferScreen.openOrderId = null;
    }
    // Stop the ring and give the lock screen back.
    cancelOfferAlert(FlutterLocalNotificationsPlugin(), widget.orderId);
    OfferPlatform.showOverLockScreen(false);
    super.dispose();
  }

  /// Closes the screen and, if given, tells the rider why on the screen below.
  void _close([String? message]) {
    if (_closing) return;
    _closing = true;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
    if (message != null) {
      final ctx = deliveryNavigatorKey.currentContext;
      if (ctx != null) WsToast.show(ctx, message);
    }
  }

  Future<void> _accept() async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    final provider = context.read<OfferProvider>();
    final result = await provider.accept(widget.orderId);
    if (!mounted) return;
    if (!result.ok) {
      setState(() => _busy = false);
      _close(result.message(l));
      return;
    }
    await cancelOfferAlert(FlutterLocalNotificationsPlugin(), widget.orderId);
    // The order is now this rider's, so its full details are readable.
    try {
      final doc = await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).get();
      if (!mounted) return;
      final order = OrderModel.fromMap(doc.data() ?? {}, doc.id);
      _closing = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ActiveOrderScreen(order: order)),
      );
    } catch (e) {
      debugPrint('Opening accepted order failed: $e');
      if (!mounted) return;
      // Accepted all the same: the dashboard's active-order card opens it.
      _close(l.offerAcceptedOpenDashboard);
    }
  }

  Future<void> _decline() async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    final provider = context.read<OfferProvider>();
    final result = await provider.decline(widget.orderId);
    if (!mounted) return;
    _close(result.message(l));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.ws;
    final text = Theme.of(context).textTheme;
    final provider = context.watch<OfferProvider>();
    final now = DateTime.now();
    final offer = provider.byOrderId(widget.orderId);
    if (offer != null) _last = offer;

    // Gone from the live list (expired, taken, withdrawn) while we were not
    // mid-action: close after this frame.
    if (!_busy && !_closing && (offer == null || !offer.isLive(now))) {
      final expired = _last != null && !_last!.isLive(now);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _close(_last == null ? null : (expired ? l.offerExpired : l.offerGone));
      });
    }

    final shown = offer ?? _last;
    if (shown == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final secondsLeft = (shown.remaining(now).inMilliseconds / 1000).ceil();
    final drop = [
      if (shown.dropDistanceKm != null) l.offerDropKm(shown.dropDistanceKm!.toStringAsFixed(1)),
      if (shown.dropPincode != null) l.offerDropPin(shown.dropPincode!),
    ].join(' · ');

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: t.surface,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(WsSpace.s24),
            // Details scroll; Accept/Decline stay pinned at the bottom so a
            // small phone can never push them off-screen (the widget test
            // caught a 29 px overflow at 600 px height).
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: WsSpace.s12),
                        Text(l.offerNotificationTitle, style: text.headlineSmall?.copyWith(color: t.textPrimary)),
                        const SizedBox(height: WsSpace.s4),
                        Text(l.offerOrderNumber(shown.orderNumber), style: text.bodyMedium?.copyWith(color: t.textSecondary)),
                        const SizedBox(height: WsSpace.s24),
                        WsCountdownRing(
                          fractionLeft: shown.fractionLeft(now),
                          secondsLeft: secondsLeft,
                          unitLabel: l.offerSeconds,
                          urgent: secondsLeft <= 10,
                        ),
                        const SizedBox(height: WsSpace.s24),
                        // DLV-4B: what this order pays, before the rider decides.
                        if (shown.estimatedPay != null)
                          _Row(
                            icon: AgIcons.wallet,
                            label: l.offerEarnLabel,
                            value: l.offerEarnValue(AgFormat.rupeesWhole(shown.estimatedPay!.round())),
                            emphasise: true,
                          ),
                        _Row(
                          icon: AgIcons.rupee,
                          label: l.offerPaymentLabel,
                          value: shown.isCod
                              ? l.offerPaymentCod(AgFormat.rupeesWhole(shown.codAmount.round()))
                              : l.offerPaymentPrepaid,
                          emphasise: shown.isCod,
                        ),
                        _Row(
                          icon: AgIcons.store,
                          label: l.offerPickupLabel,
                          value: [
                            shown.pickupDistanceKm == null
                                ? l.offerPickupNearby
                                : l.offerPickupKm(shown.pickupDistanceKm!.toStringAsFixed(1)),
                            if (shown.pickupArea != null) shown.pickupArea!,
                          ].join(' · '),
                        ),
                        _Row(icon: AgIcons.location, label: l.offerDropLabel, value: drop.isEmpty ? l.offerDropHidden : drop),
                        _Row(icon: AgIcons.product, label: l.offerItemsLabel, value: '${shown.itemCount}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: WsSpace.s16),
                FilledButton(
                  onPressed: _busy ? null : _accept,
                  child: _busy
                      ? const SizedBox.square(
                          dimension: WsIconSize.control, child: CircularProgressIndicator(strokeWidth: WsSize.focusRing))
                      : Text(l.offerAccept),
                ),
                const SizedBox(height: WsSpace.s12),
                OutlinedButton(onPressed: _busy ? null : _decline, child: Text(l.offerDecline)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value, this.emphasise = false});

  final IconData icon;
  final String label;
  final String value;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final t = context.ws;
    final text = Theme.of(context).textTheme;
    // Label above value: at large font scales a side-by-side label squeezed
    // the value into three lines (seen on the emulator).
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: WsSpace.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: WsSpace.s2),
            child: Icon(icon, color: t.primary),
          ),
          const SizedBox(width: WsSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.bodySmall?.copyWith(color: t.textSecondary)),
                Text(
                  value,
                  style: (emphasise ? text.titleMedium : text.bodyLarge)
                      ?.copyWith(color: emphasise ? t.primary : t.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
