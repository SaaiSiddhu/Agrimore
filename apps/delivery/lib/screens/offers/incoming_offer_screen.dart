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
import 'package:agrimore_ui/agrimore_ui.dart' show SnackbarHelper;

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
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) {
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
      if (ctx != null) SnackbarHelper.showInfo(ctx, message);
    }
  }

  Future<void> _accept() async {
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    final provider = context.read<OfferProvider>();
    final result = await provider.accept(widget.orderId);
    if (!mounted) return;
    if (!result.ok) {
      setState(() => _busy = false);
      _close(result.message);
      return;
    }
    await cancelOfferAlert(FlutterLocalNotificationsPlugin(), widget.orderId);
    // The order is now this rider's, so its full details are readable.
    try {
      final doc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .get();
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
      _close('Order accepted. Open it from your dashboard.');
    }
  }

  Future<void> _decline() async {
    setState(() => _busy = true);
    final provider = context.read<OfferProvider>();
    final result = await provider.decline(widget.orderId);
    if (!mounted) return;
    _close(result.ok ? null : result.message);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OfferProvider>();
    final now = DateTime.now();
    final offer = provider.byOrderId(widget.orderId);
    if (offer != null) _last = offer;

    // Gone from the live list (expired, taken, withdrawn) while we were not
    // mid-action: close after this frame.
    if (!_busy && !_closing && (offer == null || !offer.isLive(now))) {
      final expired = _last != null && !_last!.isLive(now);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _close(_last == null
              ? null
              : expired
                  ? 'The offer expired.'
                  : 'This order is no longer available.');
        }
      });
    }

    final shown = offer ?? _last;
    final cs = Theme.of(context).colorScheme;
    if (shown == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final secondsLeft = (shown.remaining(now).inMilliseconds / 1000).ceil();

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: cs.surface,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            // Details scroll; Accept/Decline stay pinned at the bottom so a
            // small phone can never push them off-screen (the widget test
            // caught a 29 px overflow at 600 px height).
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        Text(
                          'New delivery request',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Order #${shown.orderNumber}',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: 150,
                          height: 150,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CircularProgressIndicator(
                                value: shown.fractionLeft(now),
                                strokeWidth: 10,
                                backgroundColor: cs.surfaceContainerHighest,
                                color:
                                    secondsLeft <= 10 ? cs.error : cs.primary,
                              ),
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '$secondsLeft',
                                      style: TextStyle(
                                        fontSize: 44,
                                        fontWeight: FontWeight.w900,
                                        color: cs.onSurface,
                                      ),
                                    ),
                                    Text(
                                      'seconds',
                                      style:
                                          TextStyle(color: cs.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        _Row(
                          icon: Icons.storefront_rounded,
                          label: 'Pickup',
                          value: [
                            shown.pickupDistanceKm == null
                                ? 'Nearby'
                                : '${shown.pickupDistanceKm!.toStringAsFixed(1)} km away',
                            if (shown.pickupArea != null) shown.pickupArea!,
                          ].join(' · '),
                        ),
                        _Row(
                          icon: Icons.location_on_rounded,
                          label: 'Drop',
                          value: [
                            if (shown.dropDistanceKm != null)
                              '${shown.dropDistanceKm!.toStringAsFixed(1)} km from pickup',
                            if (shown.dropPincode != null)
                              'PIN ${shown.dropPincode}',
                          ].join(' · ').ifEmpty('Shown after you accept'),
                        ),
                        _Row(
                          icon: Icons.inventory_2_rounded,
                          label: 'Items',
                          value: '${shown.itemCount}',
                        ),
                        _Row(
                          icon: Icons.payments_rounded,
                          label: 'Payment',
                          value: shown.isCod
                              ? 'Collect ₹${shown.codAmount.round()} in cash'
                              : 'Prepaid — nothing to collect',
                          emphasise: shown.isCod,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: _busy ? null : _accept,
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Text(
                            'Accept order',
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _busy ? null : _decline,
                    child: const Text('Decline'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    this.emphasise = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: cs.primary),
          const SizedBox(width: 12),
          SizedBox(
            width: 72,
            child: Text(label, style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: emphasise ? FontWeight.w800 : FontWeight.w600,
                color: emphasise ? cs.primary : cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
