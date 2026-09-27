// lib/screens/admin/delivery/delivery_flags.dart
//
// Phase DLV-3C — what the delivery team sees about where a rider was at each
// step. The server (functions/src/delivery/riderSteps.ts, confirmDelivery)
// writes orders.deliveryStepChecks.<step> for every step the new rider app
// takes, and adds an entry to orders.deliveryFlags when the rider was more
// than 300 m from the store/customer, used a mocked location, or sent none
// (D-DLV-GEOFENCE: flagged, never blocked). Neither field is client-writable.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../app/themes/admin_colors.dart';

/// One step's location record.
class StepCheck {
  final String step;
  final DateTime? at;
  final int? distanceMeters;
  final bool mocked;
  final List<String> flags;

  const StepCheck({required this.step, this.at, this.distanceMeters, this.mocked = false, this.flags = const []});

  bool get flagged => flags.isNotEmpty;

  static const order = ['arrived_at_store', 'picked_up', 'out_for_delivery', 'delivered'];

  /// Every recorded step of [data] (an order document), in delivery order.
  static List<StepCheck> fromOrder(Map<String, dynamic>? data) {
    final raw = data?['deliveryStepChecks'];
    if (raw is! Map) return const [];
    final out = <StepCheck>[];
    for (final e in raw.entries) {
      final v = e.value;
      if (e.key is! String || v is! Map) continue;
      final at = v['at'];
      out.add(StepCheck(
        step: e.key as String,
        at: at is Timestamp ? at.toDate() : at is DateTime ? at : null,
        distanceMeters: (v['distanceMeters'] as num?)?.round(),
        mocked: v['isMocked'] == true,
        flags: v['flags'] is List ? (v['flags'] as List).whereType<String>().toList() : const [],
      ));
    }
    int rank(String s) {
      final i = order.indexOf(s);
      return i < 0 ? order.length : i;
    }
    out.sort((a, b) => rank(a.step).compareTo(rank(b.step)));
    return out;
  }
}

/// True when the server flagged any step of this order.
bool orderHasDeliveryFlags(Map<String, dynamic>? data) =>
    data?['deliveryFlagged'] == true ||
    (data?['deliveryFlags'] is List && (data!['deliveryFlags'] as List).isNotEmpty);

String stepLabel(String step) => switch (step) {
      'arrived_at_store' => 'Arrived at store',
      'picked_up' => 'Picked up',
      'out_for_delivery' => 'Out for delivery',
      'delivered' => 'Delivered (code entered)',
      _ => step,
    };

String flagLabel(String flag) => switch (flag) {
      'far_from_store' => 'far from the store',
      'far_from_customer' => "far from the customer's address",
      'mocked_location' => 'fake-GPS (mocked) location',
      'no_location' => 'no location sent',
      _ => flag.replaceAll('_', ' '),
    };

/// "1.2 km away" / "80 m away" / "distance unknown".
String distanceText(int? meters) {
  if (meters == null) return 'distance unknown';
  final tens = (meters / 10).round() * 10;
  return tens < 1000 ? '$tens m away' : '${(meters / 1000).toStringAsFixed(1)} km away';
}

/// The step-by-step record, flagged steps first-class. Renders nothing for an
/// order the new rider app never touched.
class DeliveryFlagsCard extends StatelessWidget {
  // ADMR-51: an injectable Firestore instance, same pattern ADMR-48/49
  // established -- defaults to the real FirebaseFirestore.instance exactly
  // as the old field initializer did (zero behavior change for the one
  // real caller, admin_order_details_screen.dart), overridable in tests so
  // this widget no longer blocks a full happy-path render of the screen it
  // is embedded in.
  DeliveryFlagsCard({super.key, required this.orderId, this.data, FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final String orderId;

  /// The order document when the caller already streams it; else streamed here.
  final Map<String, dynamic>? data;

  final FirebaseFirestore _firestore;

  @override
  Widget build(BuildContext context) {
    if (data != null) return _body(data!);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('orders').doc(orderId).snapshots(),
      builder: (context, snap) => _body(snap.data?.data()),
    );
  }

  Widget _body(Map<String, dynamic>? d) {
    final checks = StepCheck.fromOrder(d);
    if (checks.isEmpty) return const SizedBox.shrink();
    final flagged = orderHasDeliveryFlags(d);
    final color = flagged ? AdminColors.warning : AdminColors.success;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: flagged ? AdminColors.warning : AdminColors.border, width: flagged ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(flagged ? Icons.wrong_location_rounded : Icons.where_to_vote_rounded, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  flagged ? 'Rider location flagged — please review' : 'Rider was on site at every step',
                  style: TextStyle(fontWeight: FontWeight.w800, color: AdminColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final c in checks)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(c.flagged ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                      size: 16, color: c.flagged ? AdminColors.warning : AdminColors.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      [
                        stepLabel(c.step),
                        if (c.step != 'out_for_delivery' || c.distanceMeters != null) distanceText(c.distanceMeters),
                        if (c.flagged) c.flags.map(flagLabel).join(', '),
                        if (c.at != null) _time(c.at!),
                      ].join(' · '),
                      style: TextStyle(fontSize: 13, color: c.flagged ? AdminColors.textPrimary : AdminColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _time(DateTime t) {
    final l = t.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.hour)}:${two(l.minute)}';
  }
}
