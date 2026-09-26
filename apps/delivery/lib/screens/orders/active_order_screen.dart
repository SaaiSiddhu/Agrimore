// lib/screens/orders/active_order_screen.dart
//
// Phases 21–24 — The rider's order from acceptance to delivery: progress, a
// problem report after pickup (DLV-E1), the route (DLV-3B), the customer and
// the steps. Every step goes through a callable with where the rider is
// (DLV-3C); delivery is confirmed by the customer's code on the server
// (FIX-5) — this client never sees the expected code.
import 'dart:io';

import 'package:agrimore_core/agrimore_core.dart'
    show DeliveryPoint, DeliveryTaskStatus, OrderModel;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../account/support_card.dart';
import '../../delivery/delivery_problems.dart';
import '../../delivery/rider_steps.dart';
import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../../navigation/rider_navigation.dart';
import '../../providers/order_provider.dart';
import '../../safety/emergency_sheet.dart';
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
DeliveryStep deliveryStepOf(String status) => switch (
    DeliveryTaskStatus.fromOrderStatus(
      orderStatus: status,
      status: null,
      hasPartner: true,
    )) {
      DeliveryTaskStatus.atPickup => DeliveryStep.arrivedAtStore,
      DeliveryTaskStatus.pickedUp => DeliveryStep.pickedUp,
      DeliveryTaskStatus.enRoute ||
      DeliveryTaskStatus.atDrop ||
      DeliveryTaskStatus.failedAttempt =>
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

/// Same rule as the server (`isCashOnDelivery`): what the rider collects depends on it.
bool isCashOnDeliveryMethod(String method) {
  final m = method.toLowerCase();
  return m == 'cod' || m == 'cash_on_delivery' || m.contains('cash');
}

/// The timeline title of [step].
String deliveryStepTitle(AppLocalizations l, DeliveryStep step) =>
    switch (step) {
      DeliveryStep.accepted => l.activeStepAccepted,
      DeliveryStep.arrivedAtStore => l.activeStepArrived,
      DeliveryStep.pickedUp => l.activeStepPickedUp,
      DeliveryStep.outForDelivery => l.activeStepOutForDelivery,
      DeliveryStep.delivered => l.activeStepDelivered,
    };

/// The button that moves the order to [next].
String deliveryStepAction(AppLocalizations l, DeliveryStep next) =>
    switch (next) {
      DeliveryStep.accepted => l.activeStepAccepted,
      DeliveryStep.arrivedAtStore => l.activeActionArrived,
      DeliveryStep.pickedUp => l.activeActionPickedUp,
      DeliveryStep.outForDelivery => l.activeActionStart,
      DeliveryStep.delivered => l.activeActionComplete,
    };

IconData _stepIcon(DeliveryStep next) => switch (next) {
      DeliveryStep.accepted => DeliveryIcons.checkCircle,
      DeliveryStep.arrivedAtStore => DeliveryIcons.store,
      DeliveryStep.pickedUp => DeliveryIcons.packageCheck,
      DeliveryStep.outForDelivery => DeliveryIcons.rider,
      DeliveryStep.delivered => DeliveryIcons.shieldCheck,
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
  void didUpdateWidget(ActiveOrderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.orderStatus != widget.order.orderStatus) {
      _currentStep = deliveryStepOf(widget.order.orderStatus);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    final address = _order.deliveryAddress;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: Text(l.offerOrderNumber(_order.orderNumber)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: l.activeCallCustomer,
            onPressed: _callCustomer,
            icon: const Icon(DeliveryIcons.phone),
          ),
          IconButton(
            tooltip: l.activeHelpTooltip,
            onPressed: _showHelp,
            icon: const Icon(DeliveryIcons.help),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DeliverySpace.page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Section(
              title: l.activeSectionProgress,
              icon: DeliveryIcons.activeOrder,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DeliveryStepIndicator(
                    currentStep: _currentStep.index,
                    labels: [
                      for (final s in DeliveryStep.values)
                        deliveryStepTitle(l, s),
                    ],
                  ),
                  const SizedBox(height: DeliverySpace.md),
                  for (final s in DeliveryStep.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: DeliverySpace.xxs,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            s.index <= _currentStep.index
                                ? DeliveryIcons.checkCircle
                                : DeliveryIcons.circle,
                            size: DeliveryIconSize.sm,
                            color: s.index < _currentStep.index
                                ? c.success.icon
                                : (s == _currentStep
                                    ? c.brand
                                    : c.textTertiary),
                          ),
                          const SizedBox(width: DeliverySpace.sm),
                          Expanded(
                            child: Text(
                              deliveryStepTitle(l, s),
                              style: (s == _currentStep
                                      ? t.titleSmall
                                      : t.bodyMedium)
                                  .copyWith(
                                color: s.index <= _currentStep.index
                                    ? c.textPrimary
                                    : c.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: DeliverySpace.lg),

            // ── Report a problem after pickup / its state (DLV-E1) ──
            if (_currentStep != DeliveryStep.delivered) ...[
              DeliveryProblemPanel(orderId: _order.id),
              const SizedBox(height: DeliverySpace.lg),
            ],

            // ── Route: to the store, then to the customer (DLV-3B) ──
            if (_currentStep != DeliveryStep.delivered) ...[
              RiderRouteCard(
                orderId: _order.id,
                stepIndex: _currentStep.index,
                customerName: address.name,
                dropFallback:
                    address.latitude != null && address.longitude != null
                        ? DeliveryPoint(
                            lat: address.latitude!,
                            lng: address.longitude!,
                          )
                        : null,
              ),
              const SizedBox(height: DeliverySpace.lg),
            ],

            _Section(
              title: l.activeSectionCustomer,
              icon: DeliveryIcons.user,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    address.name,
                    style: t.titleMedium.copyWith(color: c.textPrimary),
                  ),
                  if (address.phone.isNotEmpty) ...[
                    const SizedBox(height: DeliverySpace.sm),
                    Row(
                      children: [
                        Expanded(
                          child: DeliveryButton.secondary(
                            label: l.activeCall,
                            icon: DeliveryIcons.phone,
                            onPressed: _callCustomer,
                          ),
                        ),
                        const SizedBox(width: DeliverySpace.sm),
                        Expanded(
                          child: DeliveryButton.secondary(
                            label: l.activeNavigate,
                            icon: DeliveryIcons.navigation,
                            onPressed: _navigateToAddress,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: DeliverySpace.lg),

            _Section(
              title: l.activeSectionAddress,
              icon: DeliveryIcons.location,
              child: Text(
                address.fullAddress,
                style: t.bodyMedium.copyWith(color: c.textPrimary),
              ),
            ),
            const SizedBox(height: DeliverySpace.lg),

            _Section(
              title: l.activeSectionItems(_order.items.length),
              icon: DeliveryIcons.package,
              child: Column(
                children: [
                  for (final item in _order.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: DeliverySpace.sm),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.productName,
                              style:
                                  t.bodyMedium.copyWith(color: c.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            l.activeItemQuantity(item.quantity),
                            style: t.labelLarge.copyWith(color: c.brand),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: DeliverySpace.lg),

            _Section(
              title: l.activeSectionPayment,
              icon: DeliveryIcons.rupee,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isCashOnDeliveryMethod(_order.paymentMethod)
                          ? l.activePaymentCod
                          : l.activePaymentPrepaid,
                      style: t.labelLarge.copyWith(color: c.textPrimary),
                    ),
                  ),
                  Text(
                    DeliveryFormat.rupees(_order.total),
                    style: t.titleLarge.copyWith(color: c.brand),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DeliverySpace.lg),

            if (_currentStep == DeliveryStep.outForDelivery) ...[
              _proofSection(l),
              const SizedBox(height: DeliverySpace.lg),
            ],
            const SizedBox(height: DeliverySpace.sm),

            if (_currentStep != DeliveryStep.delivered) _nextStepButton(l),
            if (_currentStep == DeliveryStep.accepted ||
                _currentStep == DeliveryStep.arrivedAtStore) ...[
              const SizedBox(height: DeliverySpace.md),
              DeliveryButton.secondary(
                label: l.activeSellerNotReady,
                icon: DeliveryIcons.clock,
                onPressed: _isUpdating ? null : _confirmSellerNotReady,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _proofSection(AppLocalizations l) {
    final c = context.colors;
    final t = context.text;
    final photo = _proofPhoto;
    return _Section(
      title: l.activeProofTitle,
      icon: DeliveryIcons.camera,
      child: photo != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: DeliveryRadius.rMd,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.file(photo, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: DeliverySpace.md),
                Row(
                  children: [
                    Expanded(
                      child: DeliveryButton.secondary(
                        label: l.activeProofRetake,
                        icon: DeliveryIcons.refresh,
                        onPressed: _takePhoto,
                      ),
                    ),
                    const SizedBox(width: DeliverySpace.md),
                    Expanded(
                      child: DeliveryButton.ghost(
                        label: l.activeProofRemove,
                        icon: DeliveryIcons.delete,
                        onPressed: () => setState(() => _proofPhoto = null),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : InkWell(
              onTap: _takePhoto,
              borderRadius: DeliveryRadius.rMd,
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  vertical: DeliverySpace.xxl,
                ),
                decoration: BoxDecoration(
                  color: c.surfaceVariant,
                  borderRadius: DeliveryRadius.rMd,
                  border: Border.all(
                    color: c.borderStrong,
                    width: DeliverySize.hairline,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      DeliveryIcons.camera,
                      size: DeliveryIconSize.xl,
                      color: c.textSecondary,
                    ),
                    const SizedBox(height: DeliverySpace.sm),
                    Text(
                      l.activeProofTake,
                      style: t.labelLarge.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _nextStepButton(AppLocalizations l) {
    final next = DeliveryStep.values[_currentStep.index + 1];
    return DeliveryButton.primary(
      label: deliveryStepAction(l, next),
      icon: _stepIcon(next),
      isLoading: _isUpdating,
      onPressed: _isUpdating ? null : () => _handleNextStep(next),
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

    final fix = await currentRiderFix();
    if (step == DeliveryStep.arrivedAtStore ||
        step == DeliveryStep.pickedUp) {
      final places = await stepPlaces(_order.id, _order);
      if (!mounted) return;
      final question = farTapQuestion(
        l,
        metersTo(fix?.latitude, fix?.longitude, places.store),
        atStore: true,
        action: step == DeliveryStep.arrivedAtStore
            ? FarTapAction.arrived
            : FarTapAction.pickedUp,
      );
      if (question != null && !await _confirmFarTap(question)) {
        if (mounted) setState(() => _isUpdating = false);
        return;
      }
    }
    if (!mounted) return;
    final failure = await orderProvider.advanceStep(
      _order.id,
      _statusOf(step),
      positionPayload(fix),
    );
    if (!mounted) return;
    setState(() {
      _isUpdating = false;
      if (failure == null) _currentStep = step;
    });
    if (failure == null) {
      showDeliveryToast(
        context,
        message: l.activeStepDone(deliveryStepTitle(l, step)),
        tone: DeliveryBannerTone.success,
      );
    } else {
      showDeliveryToast(
        context,
        message: failure.message(l),
        tone: DeliveryBannerTone.danger,
      );
    }
  }

  Future<bool> _confirmFarTap(String question) {
    final l = AppLocalizations.of(context);
    return showDeliveryConfirmDialog(
      context: context,
      icon: DeliveryIcons.locationOff,
      title: l.activeFarTitle,
      body: question,
      confirmLabel: l.actionContinue,
      cancelLabel: l.activeFarNotYet,
    );
  }

  Future<void> _confirmSellerNotReady() async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDeliveryConfirmDialog(
      context: context,
      title: l.activeSellerNotReadyTitle,
      body: l.activeSellerNotReadyBody,
      confirmLabel: l.activeSellerNotReadyConfirm,
      cancelLabel: l.activeSellerNotReadyWait,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isUpdating = true);
    final provider = context.read<DeliveryOrderProvider>();
    final failure = await provider.releaseOrder(
      _order.id,
      reason: 'seller_not_ready',
    );
    if (!mounted) return;
    setState(() => _isUpdating = false);
    if (failure == null) {
      showDeliveryToast(context, message: l.activeReleased);
      Navigator.pop(context);
    } else {
      showDeliveryToast(
        context,
        message: failure.message(l),
        tone: DeliveryBannerTone.danger,
      );
    }
  }

  void _showHelp() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _HelpSheet(
        canReportProblem: isAfterPickup(_order.orderStatus),
        onReportProblem: () {
          Navigator.of(context).pop();
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (_) => ProblemReportSheet(
              orderId: _order.id,
              backend: FirebaseDeliveryProblemBackend(),
            ),
          );
        },
        onEmergency: () {
          Navigator.of(context).pop();
          showEmergencySheet(context);
        },
      ),
    );
  }

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

  Future<String?> _completeDelivery(String code) async {
    final l = AppLocalizations.of(context);
    setState(() => _isUpdating = true);
    HapticFeedback.heavyImpact();

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
      await FirebaseFunctions.instance
          .httpsCallable('confirmDelivery')
          .call<Map<String, dynamic>>({
        'orderId': _order.id,
        'code': code,
        ...positionPayload(fix),
      });
    } on FirebaseFunctionsException catch (e) {
      debugPrint('confirmDelivery failed: ${e.code} ${e.message}');
      final details = e.details is Map ? e.details as Map : const {};
      if (mounted) setState(() => _isUpdating = false);
      return deliveryConfirmError(
        l,
        e.code,
        reason: details['reason'] as String?,
        retryAfterSec: details['retryAfterSec'],
      );
    } catch (e) {
      debugPrint('confirmDelivery error: $e');
      if (mounted) setState(() => _isUpdating = false);
      return l.deliverFailed;
    }

    final photo = _proofPhoto;
    if (photo != null) {
      final saved = await saveDeliveryProof(
        FirebaseDeliveryProblemBackend(),
        _order.id,
        await photo.readAsBytes(),
        'image/jpeg',
      );
      if (!saved && mounted) {
        showDeliveryToast(
          context,
          message: l.proofNotSaved,
          tone: DeliveryBannerTone.danger,
        );
      }
    }
    if (mounted) {
      setState(() {
        _isUpdating = false;
        _currentStep = DeliveryStep.delivered;
      });
    }
    return null;
  }

  void _showDelivered() {
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) {
        final l = AppLocalizations.of(ctx);
        final c = ctx.colors;
        final t = ctx.text;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(DeliverySpace.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: DeliveryIllustration(
                    kind: DeliveryIllustrationKind.orderComplete,
                    size: DeliverySize.illustration,
                  ),
                ),
                const SizedBox(height: DeliverySpace.lg),
                Text(
                  l.deliveredTitle,
                  textAlign: TextAlign.center,
                  style: t.headlineSmall.copyWith(color: c.textPrimary),
                ),
                const SizedBox(height: DeliverySpace.sm),
                Text(
                  l.deliveredBody(_order.orderNumber),
                  textAlign: TextAlign.center,
                  style: t.bodyMedium.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: DeliverySpace.xxl),
                DeliveryButton.primary(
                  label: l.deliveredBack,
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _takePhoto() async {
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1200,
      );
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
      final dest = DeliveryPoint(
        lat: address.latitude!,
        lng: address.longitude!,
      );
      final opened = await launchUrl(
        turnByTurnUri(dest),
        mode: LaunchMode.externalApplication,
      ).catchError((_) => false);
      if (!opened) {
        await launchUrl(
          directionsUri(dest),
          mode: LaunchMode.externalApplication,
        );
      }
    }
  }
}

/// The code entry. Stays open (with the error) until the server confirms.
class _VerifySheet extends StatefulWidget {
  const _VerifySheet({
    required this.orderNumber,
    required this.submit,
    required this.onDelivered,
  });
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
    final c = context.colors;
    final t = context.text;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        DeliverySpace.page,
        DeliverySpace.xxs,
        DeliverySpace.page,
        MediaQuery.of(context).viewInsets.bottom + DeliverySpace.xxl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(DeliveryIcons.shieldCheck, color: c.success.icon),
                const SizedBox(width: DeliverySpace.md),
                Expanded(
                  child: Text(
                    l.verifyTitle,
                    style: t.headlineSmall.copyWith(color: c.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DeliverySpace.md),
            DeliveryBanner(
              tone: DeliveryBannerTone.info,
              body: l.verifyHint,
            ),
            const SizedBox(height: DeliverySpace.xl),
            DeliveryOtpField(
              controller: _code,
              length: 6,
              digitSemanticsLabel: (i) => l.verifyDigit(i + 1),
              errorText: _error,
              enabled: !_submitting,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onCompleted: (_) => FocusScope.of(context).unfocus(),
            ),
            const SizedBox(height: DeliverySpace.xl),
            DeliveryButton.primary(
              label: _submitting ? l.verifySubmitting : l.verifySubmit,
              icon: DeliveryIcons.checkCircle,
              isLoading: _submitting,
              onPressed: _submitting ? null : _go,
            ),
            const SizedBox(height: DeliverySpace.sm),
            DeliveryButton.ghost(
              label: l.cancel,
              onPressed: _submitting ? null : () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return DeliveryCard(
      padding: const EdgeInsets.all(DeliverySpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: DeliveryIconSize.sm, color: c.brand),
              const SizedBox(width: DeliverySpace.sm),
              Expanded(
                child: Text(
                  title,
                  style: t.labelLarge.copyWith(color: c.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: DeliverySpace.md),
          child,
        ],
      ),
    );
  }
}

/// Opened from the active-delivery AppBar (phase 20.7 / DLV-R1): a way to
/// reach problem-reporting and emergency help without leaving the active
/// order. Every action here reuses an already-built, already-tested widget
/// (ProblemReportSheet, showEmergencySheet, SupportContactButtons) — this
/// sheet is only the menu in front of them.
class _HelpSheet extends StatelessWidget {
  const _HelpSheet({
    required this.canReportProblem,
    required this.onReportProblem,
    required this.onEmergency,
  });

  final bool canReportProblem;
  final VoidCallback onReportProblem;
  final VoidCallback onEmergency;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        DeliverySpace.page,
        DeliverySpace.xxs,
        DeliverySpace.page,
        MediaQuery.of(context).viewInsets.bottom + DeliverySpace.xxl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.activeHelpSheetTitle,
              style: t.headlineSmall.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: DeliverySpace.xxs),
            Text(
              l.activeHelpSheetSubtitle,
              style: t.bodyMedium.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: DeliverySpace.lg),
            if (canReportProblem) ...[
              DeliveryButton.secondary(
                key: const ValueKey('help-report-problem'),
                label: l.problemReport,
                icon: DeliveryIcons.warning,
                onPressed: onReportProblem,
              ),
              const SizedBox(height: DeliverySpace.sm),
            ],
            DeliveryButton.secondary(
              key: const ValueKey('help-emergency'),
              label: l.emergencyTitle,
              icon: DeliveryIcons.emergency,
              onPressed: onEmergency,
            ),
            const SizedBox(height: DeliverySpace.xl),
            Text(
              l.verifyContactSupport,
              style: t.labelMedium.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: DeliverySpace.sm),
            const SupportContactButtons(),
            const SizedBox(height: DeliverySpace.lg),
            DeliveryButton.ghost(
              label: l.activeHelpBackToDelivery,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
