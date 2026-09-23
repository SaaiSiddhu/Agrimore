// lib/screens/admin/delivery/dispatch_queue_screen.dart
//
// Phase DLV-2C — orders still looking for a rider. D-DLV-NO-TAKER: when
// three waves of offers (5 / 8 / 12 km) find no taker, DLV-2A keeps
// re-offering every 2 minutes AND flags the order `needsAdmin`; this is
// where an admin sees those orders, what each offer came to, and assigns
// a rider by hand.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../../app/themes/admin_colors.dart';
import 'delivery_flags.dart';
import 'dispatch_queue.dart';
import 'order_assignment_screen.dart';

enum _QueueFilter { needsRider, all }

class DispatchQueueScreen extends StatefulWidget {
  const DispatchQueueScreen({super.key});

  @override
  State<DispatchQueueScreen> createState() => _DispatchQueueScreenState();
}

class _DispatchQueueScreenState extends State<DispatchQueueScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription? _subscription;
  Timer? _clock;
  List<DispatchEntry> _entries = [];
  bool _isLoading = true;
  bool _loadFailed = false;
  _QueueFilter _filter = _QueueFilter.needsRider;
  bool _filterChosen = false;

  @override
  void initState() {
    super.initState();
    _listen();
    // "Searching for 4 min" ages while the screen is open.
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  void _listen() {
    _subscription?.cancel();
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    _subscription = _firestore
        .collection('delivery_dispatch')
        .where('status', isEqualTo: 'dispatching')
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        _entries = sortDispatchQueue(
            snap.docs.map((d) => DispatchEntry.fromMap(d.id, d.data())));
        _isLoading = false;
        _loadFailed = false;
        // Open on "all searching" when nothing needs a rider yet.
        if (!_filterChosen) {
          _filterChosen = true;
          if (!_entries.any((e) => e.needsAdmin)) _filter = _QueueFilter.all;
        }
      });
    }, onError: (Object e) {
      debugPrint('Dispatch queue load failed: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _clock?.cancel();
    super.dispose();
  }

  List<DispatchEntry> get _visible => _filter == _QueueFilter.needsRider
      ? _entries.where((e) => e.needsAdmin).toList()
      : _entries;

  @override
  Widget build(BuildContext context) {
    final needs = _entries.where((e) => e.needsAdmin).length;
    return Scaffold(
      backgroundColor: AdminColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'Orders waiting for a rider. Riders are offered each order in '
              'waves; when nobody takes it, it is flagged here and offered '
              'again every 2 minutes until someone accepts or you assign one.',
              style: TextStyle(fontSize: 13, color: AdminColors.textSecondary),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text('Needs a rider ($needs)'),
                  selected: _filter == _QueueFilter.needsRider,
                  onSelected: (_) =>
                      setState(() => _filter = _QueueFilter.needsRider),
                ),
                ChoiceChip(
                  label: Text('All searching (${_entries.length})'),
                  selected: _filter == _QueueFilter.all,
                  onSelected: (_) => setState(() => _filter = _QueueFilter.all),
                ),
              ],
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_loadFailed) {
      return _Message(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load the dispatch queue',
        body: 'Check your connection and try again.',
        action: FilledButton(onPressed: _listen, child: const Text('Try again')),
      );
    }
    final list = _visible;
    if (list.isEmpty) {
      return _Message(
        icon: Icons.check_circle_outline_rounded,
        title: _filter == _QueueFilter.needsRider
            ? 'No order needs a rider'
            : 'No order is waiting for a rider',
        body: _filter == _QueueFilter.needsRider && _entries.isNotEmpty
            ? '${_entries.length} ${_entries.length == 1 ? 'order is' : 'orders are'} '
                'still being offered to riders.'
            : 'Orders appear here when the seller marks them ready for pickup.',
      );
    }
    final now = DateTime.now();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _DispatchCard(entry: list[i], now: now),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(
      {required this.icon, required this.title, required this.body, this.action});

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: AdminColors.textTertiary),
              const SizedBox(height: 12),
              Text(title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AdminColors.textPrimary)),
              const SizedBox(height: 4),
              Text(body,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AdminColors.textSecondary)),
              if (action != null) ...[const SizedBox(height: 16), action!],
            ],
          ),
        ),
      );
}

String _duration(Duration d) {
  if (d.inMinutes < 1) return 'under a minute';
  if (d.inMinutes < 60) return '${d.inMinutes} min';
  final h = d.inHours, m = d.inMinutes % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}

String _waveText(DispatchEntry e) {
  if (e.wave == 0) return 'Starting';
  if (e.isRetrying) return 'Re-offering every 2 min · retry ${e.wave - 3}';
  final r = e.radiusKm == null ? '' : ' · ${e.radiusKm!.toStringAsFixed(0)} km';
  return 'Wave ${e.wave} of 3$r';
}

class _DispatchCard extends StatelessWidget {
  const _DispatchCard({required this.entry, required this.now});

  final DispatchEntry entry;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .doc(entry.orderId)
          .snapshots(),
      builder: (context, snap) {
        final order = snap.data?.data();
        final number = order?['orderNumber']?.toString();
        final total = (order?['total'] as num?)?.toDouble();
        final cod = isCashOnDelivery(order?['paymentMethod']);
        return Material(
          color: AdminColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => DispatchDetailScreen(orderId: entry.orderId))),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: entry.needsAdmin
                      ? AdminColors.warning
                      : AdminColors.border,
                  width: entry.needsAdmin ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        number == null ? 'Order ${entry.orderId}' : '#$number',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AdminColors.textPrimary),
                      ),
                      if (entry.needsAdmin)
                        const _Tag('Needs a rider', AdminColors.warningDark),
                      if (cod) const _Tag('Cash on delivery', AdminColors.info),
                      if (total != null)
                        Text('₹${total.toStringAsFixed(0)}',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AdminColors.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Searching for ${_duration(entry.searchingFor(now))} · '
                    '${_waveText(entry)}',
                    style: TextStyle(color: AdminColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${entry.offeredTo.length} offered · '
                    '${entry.declinedBy.length} declined',
                    style: TextStyle(
                        fontSize: 12, color: AdminColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      );
}

/// One order's dispatch: its state, every offer made, and the way to assign.
class DispatchDetailScreen extends StatefulWidget {
  const DispatchDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<DispatchDetailScreen> createState() => _DispatchDetailScreenState();
}

class _DispatchDetailScreenState extends State<DispatchDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, String> _riderNames = {};

  /// Offer documents carry rider ids only; names come from
  /// delivery_partners, fetched once per rider.
  void _resolveNames(Iterable<String> ids) {
    for (final id in ids) {
      if (id.isEmpty || _riderNames.containsKey(id)) continue;
      _riderNames[id] = '';
      _firestore.collection('delivery_partners').doc(id).get().then((d) {
        if (!mounted) return;
        setState(() => _riderNames[id] =
            (d.data()?['name'] as String?)?.trim().isNotEmpty == true
                ? d.data()!['name'] as String
                : 'Partner ${id.substring(0, id.length < 6 ? id.length : 6)}');
      }).catchError((Object e) {
        debugPrint('Rider name lookup failed for $id: $e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.background,
      appBar: AppBar(
        title: const Text('Dispatch'),
        backgroundColor: AdminColors.cardBackground,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _firestore.collection('orders').doc(widget.orderId).snapshots(),
        builder: (context, orderSnap) {
          if (orderSnap.hasError) {
            return const _Message(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load this order',
              body: 'Check your connection and open it again.',
            );
          }
          if (!orderSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final orderData = orderSnap.data!.data();
          if (orderData == null) {
            return const _Message(
              icon: Icons.search_off_rounded,
              title: 'Order not found',
              body: 'It may have been deleted.',
            );
          }
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _firestore
                .collection('delivery_dispatch')
                .doc(widget.orderId)
                .snapshots(),
            builder: (context, dispatchSnap) {
              final d = dispatchSnap.data?.data();
              final entry =
                  d == null ? null : DispatchEntry.fromMap(widget.orderId, d);
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _orderHeader(orderData),
                  const SizedBox(height: 12),
                  // Phase DLV-3C: where the rider was at each step.
                  DeliveryFlagsCard(orderId: widget.orderId, data: orderData),
                  _dispatchState(entry),
                  const SizedBox(height: 12),
                  _assignButton(orderData),
                  const SizedBox(height: 20),
                  Text('Offers',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AdminColors.textPrimary)),
                  const SizedBox(height: 8),
                  _timeline(),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AdminColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdminColors.border),
        ),
        child: child,
      );

  Widget _orderHeader(Map<String, dynamic> o) {
    final total = (o['total'] as num?)?.toDouble();
    final cod = isCashOnDelivery(o['paymentMethod']);
    final address = o['deliveryAddress'] is Map
        ? Map<String, dynamic>.from(o['deliveryAddress'] as Map)
        : const <String, dynamic>{};
    final area = [address['city'], address['pincode']]
        .whereType<Object>()
        .map((v) => v.toString())
        .where((v) => v.isNotEmpty)
        .join(' · ');
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('#${o['orderNumber'] ?? widget.orderId}',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AdminColors.textPrimary)),
              if (cod) const _Tag('Cash on delivery', AdminColors.info),
              if (total != null)
                Text('₹${total.toStringAsFixed(0)}',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AdminColors.textPrimary)),
            ],
          ),
          if (area.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Deliver to $area',
                style: TextStyle(color: AdminColors.textSecondary)),
          ],
        ],
      ),
    );
  }

  Widget _dispatchState(DispatchEntry? e) {
    final now = DateTime.now();
    final String title;
    final String body;
    final Color color;
    if (e == null) {
      title = 'Not dispatched';
      body = 'This order has not been offered to riders.';
      color = AdminColors.textSecondary;
    } else if (e.isOpen && e.needsAdmin) {
      title = 'Needs a rider';
      body = '${e.offeredTo.isEmpty ? 'No rider was free within 12 km of the pickup' : 'No rider took it in 3 waves'}. '
          'Still re-offering every 2 minutes'
          '${e.needsAdminSince == null ? '' : ' — flagged ${formatAge(now.difference(e.needsAdminSince!))}'}.';
      color = AdminColors.warningDark;
    } else if (e.isOpen) {
      title = 'Searching';
      body = 'Offering to riders — ${_waveText(e).toLowerCase()}. '
          'Searching for ${_duration(e.searchingFor(now))}.';
      color = AdminColors.info;
    } else if (e.status == 'assigned') {
      title = 'Rider assigned';
      body = 'Dispatch finished; a rider has this order.';
      color = AdminColors.success;
    } else {
      title = 'Stopped';
      body = 'Dispatch stopped — the order is no longer waiting for a rider.';
      color = AdminColors.textSecondary;
    }
    return _card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.radar_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        TextStyle(fontWeight: FontWeight.w700, color: color)),
                const SizedBox(height: 2),
                Text(body, style: TextStyle(color: AdminColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _assignButton(Map<String, dynamic> o) {
    final mode = assignModeFor(o);
    if (mode == null) {
      return Text(notAssignableMessage(o),
          style: TextStyle(color: AdminColors.textSecondary));
    }
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AdminColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(mode == AssignMode.assign ? 'Assign a rider' : 'Reassign'),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => OrderAssignmentScreen(
                order: OrderModel.fromMap(o, widget.orderId)))),
      ),
    );
  }

  Widget _timeline() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('delivery_requests')
          .where('orderId', isEqualTo: widget.orderId)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Text('Could not load the offers. Open this order again.',
              style: TextStyle(color: AdminColors.error));
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final offers = sortOfferTimeline(
            snap.data!.docs.map((d) => OfferEvent.fromMap(d.data())));
        if (offers.isEmpty) {
          return Text(
              'No rider has been offered this order yet — none was online, '
              'approved, free and within 12 km of the pickup.',
              style: TextStyle(color: AdminColors.textSecondary));
        }
        _resolveNames(offers.map((o) => o.riderId));
        final now = DateTime.now();
        return _card(
          child: Column(
            children: [
              for (final o in offers) _offerRow(o, now),
            ],
          ),
        );
      },
    );
  }

  Widget _offerRow(OfferEvent o, DateTime now) {
    final name = _riderNames[o.riderId];
    final color = switch (o.status) {
      DeliveryOfferStatus.accepted => AdminColors.success,
      DeliveryOfferStatus.declined => AdminColors.error,
      DeliveryOfferStatus.offered when o.isLive(now) => AdminColors.info,
      _ => AdminColors.textSecondary,
    };
    final details = [
      if (o.wave != null) 'Wave ${o.wave}',
      if (o.pickupDistanceKm != null)
        '${o.pickupDistanceKm!.toStringAsFixed(1)} km from pickup',
      if (o.offeredAt != null) formatAge(now.difference(o.offeredAt!)),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    name == null || name.isEmpty ? 'Loading rider…' : name,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AdminColors.textPrimary)),
                if (details.isNotEmpty)
                  Text(details,
                      style: TextStyle(
                          fontSize: 12, color: AdminColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _Tag(o.label(now), color),
        ],
      ),
    );
  }
}
