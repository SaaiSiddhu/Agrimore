// lib/screens/admin/delivery/order_assignment_screen.dart
//
// Phase DLV-2C — manual rider assignment. Lists APPROVED partners only (the
// pre-DLV-2C screen listed every isOnline partner, pending and suspended
// included), with what the dispatcher itself weighs: online, on another
// order, how old the last location is, and distance to the pickup. Busy and
// offline riders are shown but cannot be picked. The write is
// assignRiderToOrder (dispatch_queue.dart): one transaction that re-checks
// the order and the rider and leaves the order `delivery_accepted`, the
// state the rider app shows and on which dispatch closes.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../app/themes/admin_colors.dart';
import 'dispatch_queue.dart';

class OrderAssignmentScreen extends StatefulWidget {
  final OrderModel order;

  const OrderAssignmentScreen({super.key, required this.order});

  @override
  State<OrderAssignmentScreen> createState() => _OrderAssignmentScreenState();
}

class _OrderAssignmentScreenState extends State<OrderAssignmentScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<StreamSubscription> _subs = [];

  Map<String, dynamic>? _order;
  Map<String, Map<String, dynamic>> _partners = {};
  Set<String> _busy = {};
  double? _pickupLat;
  double? _pickupLng;
  final Set<int> _loaded = {}; // 0 order, 1 partners, 2 busy riders
  bool _loadFailed = false;
  String? _selected;
  bool _assigning = false;

  String get _orderId => widget.order.id;
  bool get _ready => _loaded.length == 3;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    setState(() {
      _loaded.clear();
      _loadFailed = false;
    });
    void failed(Object e) {
      debugPrint('Assignment screen load failed for $_orderId: $e');
      if (mounted) setState(() => _loadFailed = true);
    }

    _subs.add(_firestore.collection('orders').doc(_orderId).snapshots().listen(
        (d) {
      if (!mounted) return;
      setState(() {
        _order = d.data();
        _loaded.add(0);
      });
    }, onError: failed));
    _subs.add(_firestore
        .collection('delivery_partners')
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        _partners = {for (final d in snap.docs) d.id: d.data()};
        _loaded.add(1);
        _dropSelectionIfUnavailable();
      });
    }, onError: failed));
    _subs.add(_firestore
        .collection('orders')
        .where('orderStatus', whereIn: riderActiveOrderStatuses)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        _busy = {
          for (final d in snap.docs)
            if (d.id != _orderId &&
                d.data()['deliveryPartnerId'] is String &&
                (d.data()['deliveryPartnerId'] as String).isNotEmpty)
              d.data()['deliveryPartnerId'] as String,
        };
        _loaded.add(2);
        _dropSelectionIfUnavailable();
      });
    }, onError: failed));
    // The seller pickup point, as DLV-1A's projection resolved it.
    _firestore.collection('delivery_tasks').doc(_orderId).get().then((d) {
      final pickup = DeliveryPoint.fromMap(d.data()?['pickup']);
      if (!mounted || pickup == null) return;
      setState(() {
        _pickupLat = pickup.lat;
        _pickupLng = pickup.lng;
      });
    }).catchError((Object e) {
      debugPrint('Pickup point lookup failed for $_orderId: $e');
    });
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  List<AssignableRider> get _riders {
    final now = DateTime.now();
    return sortRiders(_partners.entries.map((e) => AssignableRider.fromMap(
          e.key,
          e.value,
          busy: _busy,
          now: now,
          pickupLat: _pickupLat,
          pickupLng: _pickupLng,
        )));
  }

  /// The listeners are live: a picked rider who goes offline, takes another
  /// order or loses approval while this screen is open is dropped from the
  /// selection rather than left on the Assign button.
  void _dropSelectionIfUnavailable() {
    final id = _selected;
    if (id == null) return;
    final still = _riders.any((r) => r.id == id && r.availability.canAssign);
    if (!still) _selected = null;
  }

  String _nameOf(String? id) =>
      (_partners[id]?['name'] as String?)?.trim().isNotEmpty == true
          ? _partners[id]!['name'] as String
          : 'this rider';

  @override
  Widget build(BuildContext context) {
    final mode = _order == null ? null : assignModeFor(_order!);
    final currentRider = _order?['deliveryPartnerId'] as String?;
    return Scaffold(
      backgroundColor: AdminColors.background,
      appBar: AppBar(
        title: Text(
            mode == AssignMode.reassign ? 'Reassign rider' : 'Assign rider'),
        backgroundColor: AdminColors.cardBackground,
      ),
      body: _body(mode, currentRider),
      bottomNavigationBar: mode == null || _loadFailed || !_ready
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton(
                  onPressed: _selected == null || _assigning
                      ? null
                      : () => _assign(mode),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AdminColors.primary,
                  ),
                  child: _assigning
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          _selected == null
                              ? 'Pick a rider'
                              : '${mode == AssignMode.reassign ? 'Reassign' : 'Assign'} '
                                  'to ${_nameOf(_selected)}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ),
            ),
    );
  }

  Widget _body(AssignMode? mode, String? currentRider) {
    if (_loadFailed) {
      return _centered(
        Icons.cloud_off_rounded,
        'Could not load riders',
        'Check your connection and try again.',
        action:
            FilledButton(onPressed: _listen, child: const Text('Try again')),
      );
    }
    if (!_ready) return const Center(child: CircularProgressIndicator());
    if (_order == null) {
      return _centered(Icons.search_off_rounded, 'Order not found',
          'It may have been deleted.');
    }
    final riders = _riders;
    final assignable = riders
        .where((r) => r.availability.canAssign && r.id != currentRider)
        .length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _orderCard(),
        const SizedBox(height: 12),
        if (mode == null)
          _notice(Icons.info_outline_rounded, notAssignableMessage(_order!),
              AdminColors.textSecondary)
        else if (mode == AssignMode.reassign)
          _notice(
              Icons.swap_horiz_rounded,
              '${currentRider != null && _partners.containsKey(currentRider) ? _nameOf(currentRider) : 'A rider'} '
              'has this order but has not picked it up. Reassigning takes it '
              'away from them and gives it to the rider you pick.',
              AdminColors.warningDark),
        if (_pickupLat == null && mode != null) ...[
          const SizedBox(height: 8),
          _notice(
              Icons.location_off_rounded,
              'The pickup location is not known, so distances are not shown.',
              AdminColors.textSecondary),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Approved riders',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AdminColors.textPrimary)),
            if (mode != null)
              Text('$assignable of ${riders.length} can take it now',
                  style: TextStyle(color: AdminColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 8),
        if (riders.isEmpty)
          _notice(Icons.person_off_rounded,
              'No approved delivery partners yet.', AdminColors.textSecondary)
        else
          for (final r in riders)
            _riderTile(r,
                enabled: mode != null && r.id != currentRider,
                isCurrent: r.id == currentRider),
      ],
    );
  }

  Widget _centered(IconData icon, String title, String body,
          {Widget? action}) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: AdminColors.textTertiary),
              const SizedBox(height: 12),
              Text(title,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AdminColors.textPrimary)),
              const SizedBox(height: 4),
              Text(body,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AdminColors.textSecondary)),
              if (action != null) ...[const SizedBox(height: 16), action],
            ],
          ),
        ),
      );

  Widget _notice(IconData icon, String text, Color color) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(
                child: Text(text,
                    style: TextStyle(color: AdminColors.textPrimary))),
          ],
        ),
      );

  Widget _orderCard() {
    final o = _order!;
    final total = (o['total'] as num?)?.toDouble();
    final address = widget.order.deliveryAddress;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('#${o['orderNumber'] ?? widget.order.orderNumber}',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AdminColors.textPrimary)),
              if (isCashOnDelivery(o['paymentMethod']))
                Text('Cash on delivery',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: AdminColors.info)),
              if (total != null)
                Text('₹${total.toStringAsFixed(0)}',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AdminColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(address.name,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            address.fullAddress,
            style: TextStyle(fontSize: 12, color: AdminColors.textSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _riderTile(AssignableRider r,
      {required bool enabled, required bool isCurrent}) {
    final canPick = enabled && r.availability.canAssign;
    final selected = _selected == r.id;
    final (String status, Color color) = switch (r.availability) {
      RiderAvailability.available => ('Free', AdminColors.success),
      RiderAvailability.staleLocation => (
          'Free · location out of date',
          AdminColors.warningDark
        ),
      RiderAvailability.noLocation => (
          'Free · no location yet',
          AdminColors.warningDark
        ),
      RiderAvailability.busy => ('On another order', AdminColors.textSecondary),
      RiderAvailability.offline => ('Offline', AdminColors.textSecondary),
    };
    final details = [
      vehicleLabel(r.vehicleType),
      if (r.vehicleNumber.isNotEmpty) r.vehicleNumber,
      if (r.distanceKm != null)
        '${r.distanceKm!.toStringAsFixed(1)} km from pickup',
      if (r.locationAge != null) 'location ${formatAge(r.locationAge!)}',
    ].join(' · ');
    return Opacity(
      opacity: canPick || isCurrent ? 1 : 0.55,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AdminColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AdminColors.primary : AdminColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: canPick && !_assigning
              ? () => setState(() => _selected = r.id)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AdminColors.primary.withValues(alpha: 0.1),
                  child: Text(
                    r.name.isEmpty ? '?' : r.name[0].toUpperCase(),
                    style: const TextStyle(
                        color: AdminColors.primary,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCurrent ? '${r.name} (has this order)' : r.name,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AdminColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      if (!isCurrent)
                        Text(status,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: color)),
                      if (details.isNotEmpty)
                        Text(details,
                            style: TextStyle(
                                fontSize: 12,
                                color: AdminColors.textSecondary)),
                      if (r.phone.isNotEmpty)
                        Text(r.phone,
                            style: TextStyle(
                                fontSize: 12,
                                color: AdminColors.textSecondary)),
                    ],
                  ),
                ),
                if (canPick)
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: selected
                        ? AdminColors.primary
                        : AdminColors.textTertiary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _assign(AssignMode mode) async {
    final riderId = _selected;
    if (riderId == null) return;
    final name = _nameOf(riderId);
    if (mode == AssignMode.reassign) {
      final ok = await DialogHelper.showConfirmation(
        context,
        title: 'Reassign to $name?',
        message: 'The rider who has it now will lose this order.',
        confirmText: 'Reassign',
      );
      if (ok != true || !mounted) return;
    }
    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    if (adminUid == null) {
      SnackbarHelper.showError(
          context, 'Your admin session has expired. Sign in again.');
      return;
    }
    setState(() => _assigning = true);
    try {
      final outcome = await assignRiderToOrder(
        firestore: _firestore,
        orderId: _orderId,
        riderId: riderId,
        adminUid: adminUid,
      );
      if (!mounted) return;
      if (outcome == AssignOutcome.assigned) {
        final number = _order?['orderNumber'] ?? widget.order.orderNumber;
        Navigator.of(context).pop();
        SnackbarHelper.showSuccess(context, '$name now has order #$number.');
        return;
      }
      setState(() {
        _assigning = false;
        if (outcome == AssignOutcome.riderBusy ||
            outcome == AssignOutcome.riderOffline ||
            outcome == AssignOutcome.riderNotApproved) {
          _selected = null;
        }
      });
      SnackbarHelper.showError(context, outcome.refusalMessage);
    } catch (e) {
      debugPrint('Rider assignment failed for $_orderId → $riderId: $e');
      if (!mounted) return;
      setState(() => _assigning = false);
      SnackbarHelper.showError(
          context, 'Could not assign the rider. Please try again.');
    }
  }
}
