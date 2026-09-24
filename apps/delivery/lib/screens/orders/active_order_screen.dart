// lib/screens/orders/active_order_screen.dart
//
// The rider's order from acceptance to delivery: progress, a problem report
// after pickup (DLV-E1), the route (DLV-3B), the customer and the steps. Every
// step goes through a callable with where the rider is (DLV-3C); delivery is
// confirmed by the customer's code on the server (FIX-5) — this client never
// sees the expected code. DLV-P1: Workspace tokens and kit, lib/l10n strings.
import 'dart:io';

import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../delivery/delivery_problems.dart';
import '../../delivery/rider_steps.dart';
import '../../l10n/app_localizations.dart';
import '../../navigation/rider_navigation.dart';
import '../../providers/order_provider.dart';
import 'delivery_problem_panel.dart';
import 'widgets/rider_route_card.dart';

/// Delivery workflow states — each maps to a Firestore orderStatus.
enum DeliveryStep {
  accepted, // "delivery_accepted"
  arrivedAtStore, // "arrived_at_store"
  pickedUp, // "picked_up"
  outForDelivery, // "out_for_delivery"
  delivered, // "delivered" (requires the customer's code)
}

/// DLV-E1: through the shared status helper — this screen's own list missed
/// the `outForDelivery` spelling and showed such an order as just accepted.
DeliveryStep deliveryStepOf(String status) =>
    switch (DeliveryTaskStatus.fromOrderStatus(orderStatus: status, status: null, hasPartner: true)) {
      DeliveryTaskStatus.atPickup => DeliveryStep.arrivedAtStore,
      DeliveryTaskStatus.pickedUp => DeliveryStep.pickedUp,
      DeliveryTaskStatus.enRoute || DeliveryTaskStatus.atDrop || DeliveryTaskStatus.failedAttempt =>
        DeliveryStep.outForDelivery,
      DeliveryTaskStatus.delivered => DeliveryStep.delivered,
      _ => DeliveryStep.accepted,
    };

String _statusOf(DeliveryStep step) => switch (step) {
      DeliveryStep.accepted => 'delivery_accepted',
      DeliveryStep.arrivedAtStore => 'arrived_at_store',
      DeliveryStep.pickedUp => 'picked_up',
      DeliveryStep.outForDelivery => 'out_for_delivery',
      DeliveryStep.delivered => 'delivered',
    };

/// Same rule as the server (functions/src/seller/sellerTransitionOrder.ts
/// isCashOnDelivery): what the rider collects depends on it.
bool isCashOnDeliveryMethod(String method) {
  final m = method.toLowerCase();
  return m == 'cod' || m == 'cash_on_delivery' || m.contains('cash');
}

/// The timeline title of [step].
String deliveryStepTitle(AppLocalizations l, DeliveryStep step) => switch (step) {
      DeliveryStep.accepted => l.activeStepAccepted,
      DeliveryStep.arrivedAtStore => l.activeStepArrived,
      DeliveryStep.pickedUp => l.activeStepPickedUp,
      DeliveryStep.outForDelivery => l.activeStepOutForDelivery,
      DeliveryStep.delivered => l.activeStepDelivered,
    };

/// The button that moves the order to [next].
String deliveryStepAction(AppLocalizations l, DeliveryStep next) => switch (next) {
      DeliveryStep.accepted => l.activeStepAccepted,
      DeliveryStep.arrivedAtStore => l.activeActionArrived,
      DeliveryStep.pickedUp => l.activeActionPickedUp,
      DeliveryStep.outForDelivery => l.activeActionStart,
      DeliveryStep.delivered => l.activeActionComplete,
    };

IconData _stepIcon(DeliveryStep next) => switch (next) {
      DeliveryStep.accepted => AgIcons.success,
      DeliveryStep.arrivedAtStore => AgIcons.store,
      DeliveryStep.pickedUp => AgIcons.packed,
      DeliveryStep.outForDelivery => AgIcons.rider,
      DeliveryStep.delivered => AgIcons.shieldCheck,
    };

class ActiveOrderScreen extends StatefulWidget {
  final OrderModel order;

  const ActiveOrderScreen({super.key, required this.order});

  @override
  State<ActiveOrderScreen> createState() => _ActiveOrderScreenState();
}

class _ActiveOrderScreenState extends State<ActiveOrderScreen> {
  late DeliveryStep _currentStep = deliveryStepOf(widget.order.orderStatus);
  bool _isUpdating = false;
  File? _proofPhoto;
  final ImagePicker _picker = ImagePicker();

  OrderModel get _order => widget.order;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.ws;
    final text = Theme.of(context).textTheme;
    final address = _order.deliveryAddress;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.offerOrderNumber(_order.orderNumber)),
        centerTitle: true,
        actions: [
          IconButton(tooltip: l.activeCallCustomer, onPressed: _callCustomer, icon: const Icon(AgIcons.call)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(WsSpace.page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Section(
              title: l.activeSectionProgress,
              icon: AgIcons.delivery,
              child: WsTimeline(steps: [
                for (final s in DeliveryStep.values)
                  WsTimelineStep(
                    title: deliveryStepTitle(l, s),
                    state: s.index < _currentStep.index
                        ? WsTimelineState.done
                        : s == _currentStep
                            ? (s == DeliveryStep.delivered ? WsTimelineState.done : WsTimelineState.current)
                            : WsTimelineState.upcoming,
                  ),
              ]),
            ),
            const SizedBox(height: WsSpace.s16),

            // ── Report a problem after pickup / its state (DLV-E1) ──
            if (_currentStep != DeliveryStep.delivered) ...[
              DeliveryProblemPanel(orderId: _order.id),
              const SizedBox(height: WsSpace.s16),
            ],

            // ── Route: to the store, then to the customer (DLV-3B) ──
            if (_currentStep != DeliveryStep.delivered) ...[
              RiderRouteCard(
                orderId: _order.id,
                stepIndex: _currentStep.index,
                customerName: address.name,
                dropFallback: address.latitude != null && address.longitude != null
                    ? DeliveryPoint(lat: address.latitude!, lng: address.longitude!)
                    : null,
              ),
              const SizedBox(height: WsSpace.s16),
            ],

            _Section(
              title: l.activeSectionCustomer,
              icon: AgIcons.user,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(address.name, style: text.titleMedium),
                  if (address.phone.isNotEmpty) ...[
                    const SizedBox(height: WsSpace.s8),
                    // DLV-A1: Workspace buttons are full-width (Size.fromHeight);
                    // unwrapped in a Row they failed to lay out (DLV-C1 theme).
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _callCustomer,
                          icon: const Icon(AgIcons.call, size: WsIconSize.supporting),
                          label: Text(l.activeCall),
                        ),
                      ),
                      const SizedBox(width: WsSpace.s8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _navigateToAddress,
                          icon: const Icon(AgIcons.navigate, size: WsIconSize.supporting),
                          label: Text(l.activeNavigate),
                        ),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: WsSpace.s16),

            _Section(
              title: l.activeSectionAddress,
              icon: AgIcons.location,
              child: Text(address.fullAddress, style: text.bodyMedium?.copyWith(color: t.textPrimary)),
            ),
            const SizedBox(height: WsSpace.s16),

            _Section(
              title: l.activeSectionItems(_order.items.length),
              icon: AgIcons.orders,
              child: Column(children: [
                for (final item in _order.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: WsSpace.s8),
                    child: Row(children: [
                      Expanded(
                        child: Text(item.productName,
                            style: text.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      Text(l.activeItemQuantity(item.quantity), style: text.labelLarge?.copyWith(color: t.primary)),
                    ]),
                  ),
              ]),
            ),
            const SizedBox(height: WsSpace.s16),

            _Section(
              title: l.activeSectionPayment,
              icon: AgIcons.rupee,
              child: Row(children: [
                Expanded(
                  child: Text(
                    isCashOnDeliveryMethod(_order.paymentMethod) ? l.activePaymentCod : l.activePaymentPrepaid,
                    style: text.labelLarge,
                  ),
                ),
                Text(AgFormat.rupees(_order.total), style: text.titleLarge?.copyWith(color: t.primary)),
              ]),
            ),
            const SizedBox(height: WsSpace.s16),

            if (_currentStep == DeliveryStep.outForDelivery) ...[
              _proofSection(l),
              const SizedBox(height: WsSpace.s16),
            ],
            const SizedBox(height: WsSpace.s8),

            if (_currentStep != DeliveryStep.delivered) _nextStepButton(l),
            if (_currentStep == DeliveryStep.accepted || _currentStep == DeliveryStep.arrivedAtStore) ...[
              const SizedBox(height: WsSpace.s12),
              OutlinedButton.icon(
                onPressed: _isUpdating ? null : _confirmSellerNotReady,
                style: OutlinedButton.styleFrom(
                  foregroundColor: t.warningFg,
                  side: BorderSide(color: t.warningFg, width: WsSize.outline),
                ),
                icon: const Icon(AgIcons.clock),
                label: Text(l.activeSellerNotReady),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _proofSection(AppLocalizations l) {
    final t = context.ws;
    final text = Theme.of(context).textTheme;
    final photo = _proofPhoto;
    return _Section(
      title: l.activeProofTitle,
      icon: AgIcons.camera,
      child: photo != null
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(WsRadius.card),
                child: AspectRatio(aspectRatio: 16 / 9, child: Image.file(photo, fit: BoxFit.cover)),
              ),
              const SizedBox(height: WsSpace.s12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _takePhoto,
                    icon: const Icon(AgIcons.refresh, size: WsIconSize.supporting),
                    label: Text(l.activeProofRetake),
                  ),
                ),
                const SizedBox(width: WsSpace.s12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _proofPhoto = null),
                    style: OutlinedButton.styleFrom(foregroundColor: t.errorFg),
                    icon: const Icon(AgIcons.delete, size: WsIconSize.supporting),
                    label: Text(l.activeProofRemove),
                  ),
                ),
              ]),
            ])
          : InkWell(
              onTap: _takePhoto,
              borderRadius: BorderRadius.circular(WsRadius.card),
              child: Ink(
                padding: const EdgeInsets.symmetric(vertical: WsSpace.s24),
                decoration: BoxDecoration(
                  color: t.surfaceSunken,
                  borderRadius: BorderRadius.circular(WsRadius.card),
                  border: Border.all(color: t.inputBorder, width: WsSize.hairline),
                ),
                child: Column(children: [
                  Icon(AgIcons.addPhoto, size: WsIconSize.feature, color: t.textSecondary),
                  const SizedBox(height: WsSpace.s8),
                  Text(l.activeProofTake, style: text.labelLarge?.copyWith(color: t.textSecondary)),
                ]),
              ),
            ),
    );
  }

  Widget _nextStepButton(AppLocalizations l) {
    final next = DeliveryStep.values[_currentStep.index + 1];
    return FilledButton.icon(
      onPressed: _isUpdating ? null : () => _handleNextStep(next),
      icon: _isUpdating
          ? const SizedBox.square(
              dimension: WsIconSize.control, child: CircularProgressIndicator(strokeWidth: WsSize.focusRing))
          : Icon(_stepIcon(next)),
      label: Text(deliveryStepAction(l, next)),
    );
  }

  Future<void> _handleNextStep(DeliveryStep next) async {
    if (next == DeliveryStep.delivered) {
      _showVerificationSheet();
    } else {
      await _updateToStep(next);
    }
  }

  Future<void> _updateToStep(DeliveryStep step) async {
    final l = AppLocalizations.of(context);
    setState(() => _isUpdating = true);
    HapticFeedback.mediumImpact();
    final orderProvider = context.read<DeliveryOrderProvider>();

    // Phase DLV-3C: the step goes to the server with where the rider is. At
    // the store steps a far tap is asked about first (allowed, flagged —
    // D-DLV-GEOFENCE); "out for delivery" is often tapped after leaving.
    final fix = await currentRiderFix();
    if (step == DeliveryStep.arrivedAtStore || step == DeliveryStep.pickedUp) {
      final places = await stepPlaces(_order.id, _order);
      if (!mounted) return;
      final question = farTapQuestion(
        l,
        metersTo(fix?.latitude, fix?.longitude, places.store),
        atStore: true,
        action: step == DeliveryStep.arrivedAtStore ? FarTapAction.arrived : FarTapAction.pickedUp,
      );
      if (question != null && !await _confirmFarTap(question)) {
        if (mounted) setState(() => _isUpdating = false);
        return;
      }
    }
    if (!mounted) return;
    final failure = await orderProvider.advanceStep(_order.id, _statusOf(step), positionPayload(fix));
    if (!mounted) return;
    setState(() {
      _isUpdating = false;
      if (failure == null) _currentStep = step;
    });
    if (failure == null) {
      WsToast.show(context, l.activeStepDone(deliveryStepTitle(l, step)), tone: WsToastTone.success);
    } else {
      WsToast.show(context, failure.message(l), tone: WsToastTone.error);
    }
  }

  /// "You're 1.2 km from the store. Mark arrived anyway?" — true to go ahead.
  Future<bool> _confirmFarTap(String question) {
    final l = AppLocalizations.of(context);
    return wsConfirm(
      context,
      icon: AgIcons.locationOff,
      title: l.activeFarTitle,
      message: question,
      confirmLabel: l.actionContinue,
      cancelLabel: l.activeFarNotYet,
    );
  }

  Future<void> _confirmSellerNotReady() async {
    final l = AppLocalizations.of(context);
    final confirmed = await wsConfirm(
      context,
      title: l.activeSellerNotReadyTitle,
      message: l.activeSellerNotReadyBody,
      confirmLabel: l.activeSellerNotReadyConfirm,
      cancelLabel: l.activeSellerNotReadyWait,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isUpdating = true);
    final provider = context.read<DeliveryOrderProvider>();
    // Phase DLV-3C: releaseDeliveryOrder (the direct write was always denied).
    final failure = await provider.releaseOrder(_order.id, reason: 'seller_not_ready');
    if (!mounted) return;
    setState(() => _isUpdating = false);
    if (failure == null) {
      WsToast.show(context, l.activeReleased);
      Navigator.pop(context);
    } else {
      WsToast.show(context, failure.message(l), tone: WsToastTone.error);
    }
  }

  // ── The customer's code (the rider never sees the expected value) ──

  void _showVerificationSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      showDragHandle: true,
      builder: (_) => _VerifySheet(
        orderNumber: _order.orderNumber,
        submit: _completeDelivery,
        onDelivered: _showDelivered,
      ),
    );
  }

  /// Phase FIX-5 (finding N-5, P1). Returns null on success, or a sentence to
  /// show. The code goes to the confirmDelivery callable, which compares it
  /// server-side and performs the transition itself.
  Future<String?> _completeDelivery(String code) async {
    final l = AppLocalizations.of(context);
    setState(() => _isUpdating = true);
    HapticFeedback.heavyImpact();

    // DLV-E1: the proof photo is uploaded only AFTER the delivery is
    // confirmed (below), to one fixed object, and attached by the server.
    // Phase DLV-3C: where the rider is when the code is entered — recorded by
    // confirmDelivery, flagged beyond 300 m; a far entry is asked about first.
    final fix = await currentRiderFix();
    final places = await stepPlaces(_order.id, _order);
    if (!mounted) return l.deliverFailed;
    final question = farTapQuestion(
      l,
      metersTo(fix?.latitude, fix?.longitude, places.customer),
      atStore: false,
      action: FarTapAction.complete,
    );
    if (question != null && !await _confirmFarTap(question)) {
      if (mounted) setState(() => _isUpdating = false);
      return l.deliverNotCompletedFar;
    }

    try {
      await FirebaseFunctions.instance.httpsCallable('confirmDelivery').call<Map<String, dynamic>>({
        'orderId': _order.id,
        'code': code,
        ...positionPayload(fix),
      });
    } on FirebaseFunctionsException catch (e) {
      // feedback.md §2: never render the raw provider message; log the detail.
      debugPrint('confirmDelivery failed: ${e.code} ${e.message}');
      final details = e.details is Map ? e.details as Map : const {};
      if (mounted) setState(() => _isUpdating = false);
      return deliveryConfirmError(l, e.code,
          reason: details['reason'] as String?, retryAfterSec: details['retryAfterSec']);
    } catch (e) {
      debugPrint('confirmDelivery error: $e');
      if (mounted) setState(() => _isUpdating = false);
      return l.deliverFailed;
    }

    // DLV-E1: never throws — a photo that does not save is told as that,
    // and the confirmed delivery still counts.
    final photo = _proofPhoto;
    if (photo != null) {
      final saved = await saveDeliveryProof(
          FirebaseDeliveryProblemBackend(), _order.id, await photo.readAsBytes(), 'image/jpeg');
      if (!saved && mounted) WsToast.show(context, l.proofNotSaved, tone: WsToastTone.error);
    }
    if (mounted) {
      setState(() {
        _isUpdating = false;
        _currentStep = DeliveryStep.delivered;
      });
    }
    return null;
  }

  /// Shown after the code sheet has closed; its button returns to the dashboard.
  void _showDelivered() {
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) {
        final l = AppLocalizations.of(ctx);
        final t = ctx.ws;
        final text = Theme.of(ctx).textTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(WsSpace.s24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Icon(AgIcons.allDone, size: WsIconSize.empty, color: t.successFg),
              const SizedBox(height: WsSpace.s16),
              Text(l.deliveredTitle, textAlign: TextAlign.center, style: text.titleLarge),
              const SizedBox(height: WsSpace.s8),
              Text(l.deliveredBody(_order.orderNumber),
                  textAlign: TextAlign.center, style: text.bodyMedium?.copyWith(color: t.textSecondary)),
              const SizedBox(height: WsSpace.s24),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: Text(l.deliveredBack),
              ),
            ]),
          ),
        );
      },
    );
  }

  Future<void> _takePhoto() async {
    try {
      final photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70, maxWidth: 1200);
      if (photo != null && mounted) {
        setState(() => _proofPhoto = File(photo.path));
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      debugPrint('Camera error: $e');
    }
  }

  Future<void> _callCustomer() async {
    final phone = _order.deliveryAddress.phone;
    if (phone.isNotEmpty) {
      final url = Uri.parse('tel:$phone');
      if (await canLaunchUrl(url)) await launchUrl(url);
    }
  }

  Future<void> _navigateToAddress() async {
    final address = _order.deliveryAddress;
    if (address.latitude != null && address.longitude != null) {
      // DLV-3B: two-wheeler turn-by-turn, like the route card's Navigate.
      final dest = DeliveryPoint(lat: address.latitude!, lng: address.longitude!);
      final opened =
          await launchUrl(turnByTurnUri(dest), mode: LaunchMode.externalApplication).catchError((_) => false);
      if (!opened) await launchUrl(directionsUri(dest), mode: LaunchMode.externalApplication);
    }
  }

  // Phase DLV-S1: the Chat icon created a threads document from this
  // client and said "Chat thread is ready" with no chat screen behind it.
  // Removed; DLV-K1 hardened thread rules, and a rider chat needs a
  // customer-side chat first (owner decision).
}

/// The code entry. Stays open (with the error) until the server confirms.
class _VerifySheet extends StatefulWidget {
  const _VerifySheet({required this.orderNumber, required this.submit, required this.onDelivered});
  final String orderNumber;
  final Future<String?> Function(String code) submit;
  final VoidCallback onDelivered;

  @override
  State<_VerifySheet> createState() => _VerifySheetState();
}

class _VerifySheetState extends State<_VerifySheet> {
  final _code = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final l = AppLocalizations.of(context);
    final code = _code.text.trim();
    if (code.length < 6) {
      setState(() => _error = l.verifyIncomplete);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final error = await widget.submit(code);
    if (!mounted) return;
    if (error == null) {
      // Close the code sheet FIRST, then celebrate (a pop after the success
      // dialog opened used to close THAT one — seen in the DLV-3C run).
      Navigator.pop(context);
      widget.onDelivered();
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _submitting = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.ws;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          WsSpace.page, 0, WsSpace.page, MediaQuery.of(context).viewInsets.bottom + WsSpace.s24),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(AgIcons.shieldCheck, color: t.successFg),
            const SizedBox(width: WsSpace.s12),
            Expanded(child: Text(l.verifyTitle, style: text.titleLarge)),
          ]),
          const SizedBox(height: WsSpace.s12),
          Container(
            padding: const EdgeInsets.all(WsSpace.s12),
            decoration: BoxDecoration(color: t.infoBg, borderRadius: BorderRadius.circular(WsRadius.small)),
            child: Row(children: [
              Icon(AgIcons.info, size: WsIconSize.supporting, color: t.infoFg),
              const SizedBox(width: WsSpace.s8),
              Expanded(child: Text(l.verifyHint, style: text.bodySmall?.copyWith(color: t.infoFg))),
            ]),
          ),
          const SizedBox(height: WsSpace.s20),
          WsOtpInput(
            controller: _code,
            digitSemanticsLabel: (i) => l.verifyDigit(i + 1),
            hasError: _error != null,
            enabled: !_submitting,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: WsSpace.s8),
            Text(_error!, style: text.bodyMedium?.copyWith(color: t.errorFg)),
          ],
          const SizedBox(height: WsSpace.s20),
          FilledButton.icon(
            onPressed: _submitting ? null : _go,
            icon: _submitting
                ? const SizedBox.square(
                    dimension: WsIconSize.supporting, child: CircularProgressIndicator(strokeWidth: WsSize.focusRing))
                : const Icon(AgIcons.success),
            label: Text(_submitting ? l.verifySubmitting : l.verifySubmit),
          ),
          const SizedBox(height: WsSpace.s8),
          TextButton(onPressed: _submitting ? null : () => Navigator.pop(context), child: Text(l.cancel)),
        ]),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.ws;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(WsSpace.s16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(WsRadius.card),
        border: Border.all(color: t.divider, width: WsSize.hairline),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(icon, size: WsIconSize.supporting, color: t.primary),
          const SizedBox(width: WsSpace.s8),
          Expanded(child: Text(title, style: text.labelLarge?.copyWith(color: t.textSecondary))),
        ]),
        const SizedBox(height: WsSpace.s12),
        child,
      ]),
    );
  }
}
