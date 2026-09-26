// lib/screens/profile/identity_change_screen.dart
//
// Phase DLVID1 — request a change to a locked identity field (name only;
// see rider_identity.dart for why "date of birth" is not offered). Mirrors
// the mockup's own three states: a form when there is nothing pending, a
// "pending review" card once submitted, and a rejected card with the
// server's own reason plus a "Correct and resend" action that reopens the
// form prefilled with what was rejected.
//
// Phase DLVID2 generalized this to a second changeType, "vehicle" (type +
// number together). Which type this screen instance handles is fixed by
// the caller (the profile screen's own "Request name change" / "Request
// vehicle update" buttons), not chosen inside the screen -- so [_latest] is
// filtered to requests of that same type: the backend still gates ONE
// identity change in flight at a time, of either type (one
// identityChangePending flag on delivery_partners), so a rider mid-review
// on a name change who opens the vehicle screen correctly sees the plain
// form, and a submit from there surfaces the existing "already pending"
// message rather than a wrong pending/rejected card borrowed from the
// other type.
import 'package:agrimore_core/agrimore_core.dart' show VehicleType;
import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import '../../identity/rider_identity.dart';
import '../../l10n/app_localizations.dart';
import '../auth/rider_registration_screen.dart' show vehicleLabel;

String? _identityFieldErrorFor(AppLocalizations l, String? field) => switch (field) {
      'name' => l.errIdentityName,
      'vehicleType' => l.errIdentityVehicleType,
      'vehicleNumber' => l.errVehicleNumber,
      'reason' => l.errIdentityReason,
      _ => null,
    };

String _identityFailureText(AppLocalizations l, IdentityRequestFailure f) => switch (f) {
      IdentityRequestFailure.alreadyPending => l.identityChangeAlreadyPending,
      IdentityRequestFailure.network => l.identityChangeNetworkError,
      IdentityRequestFailure.invalid => l.identityChangeInvalid,
      IdentityRequestFailure.unknown => l.identityChangeInvalid,
    };

class IdentityChangeScreen extends StatefulWidget {
  const IdentityChangeScreen({
    super.key,
    required this.riderId,
    this.changeType = kIdentityChangeTypeName,
    this.currentName = '',
    this.currentVehicleType,
    this.currentVehicleNumber = '',
    this.backend,
  });
  final String riderId;

  /// [kIdentityChangeTypeName] or [kIdentityChangeTypeVehicle]. Fixed by
  /// which profile button opened this screen.
  final String changeType;

  /// Blank when opened somewhere the caller does not already have it (e.g.
  /// from an inbox notice) -- only the form state's "Current name" display
  /// needs it, and a tap that landed here almost always means the request
  /// has already been reviewed, not that a fresh one is being started.
  final String currentName;

  final VehicleType? currentVehicleType;
  final String currentVehicleNumber;

  /// Injectable for tests; defaults to the real callable-backed service.
  final RiderIdentityBackend? backend;

  @override
  State<IdentityChangeScreen> createState() => _IdentityChangeScreenState();
}

class _IdentityChangeScreenState extends State<IdentityChangeScreen> {
  late final RiderIdentityBackend _backend =
      widget.backend ?? CallableRiderIdentityBackend();

  /// Filtered to this screen's own changeType -- see the file header for why.
  late final Stream<IdentityChangeRequest?> _latest = _backend
      .latestRequest(widget.riderId)
      .map((r) => r?.changeType == widget.changeType ? r : null);

  final _nameController = TextEditingController();
  final _vehicleNumberController = TextEditingController();
  final _reasonController = TextEditingController();
  late VehicleType? _vehicleType = widget.currentVehicleType;
  String? _fieldProblem;
  IdentityRequestFailure? _failure;
  bool _saving = false;

  /// True once "Correct and resend" is tapped on a rejected request, so the
  /// form shows again even though [_latest] still reports that same
  /// rejected request until a fresh one is submitted.
  bool _forceForm = false;

  bool get _isVehicle => widget.changeType == kIdentityChangeTypeVehicle;

  @override
  void initState() {
    super.initState();
    _vehicleNumberController.text = widget.currentVehicleNumber;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _vehicleNumberController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _fieldProblem = null;
      _failure = null;
    });
    try {
      await _backend.requestChange(
        changeType: widget.changeType,
        proposedValues: _isVehicle
            ? {
                'vehicleType': _vehicleType?.wire ?? '',
                'vehicleNumber': _vehicleNumberController.text,
              }
            : {'name': _nameController.text},
        reason: _reasonController.text,
      );
      if (mounted) {
        setState(() => _forceForm = false);
        showDeliveryToast(
          context,
          message: AppLocalizations.of(context).identityChangeSubmitted,
          tone: DeliveryBannerTone.success,
        );
      }
    } on IdentityRequestException catch (e) {
      if (mounted) {
        setState(() {
          _failure = e.failure;
          _fieldProblem = e.field;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _correct(IdentityChangeRequest rejected) {
    if (_isVehicle) {
      _vehicleType = VehicleType.fromWire(rejected.proposedValues['vehicleType']);
      _vehicleNumberController.text = rejected.proposedValues['vehicleNumber'] ?? '';
    } else {
      _nameController.text = rejected.proposedValues['name'] ?? '';
    }
    _reasonController.text = rejected.reason;
    setState(() => _forceForm = true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(title: Text(l.identityChangeTitle)),
      body: StreamBuilder<IdentityChangeRequest?>(
        stream: _latest,
        builder: (context, snap) {
          final latest = snap.data;
          if (!_forceForm &&
              latest != null &&
              latest.status == IdentityChangeStatus.pending) {
            return _StatusCard(
              icon: DeliveryIcons.clock,
              title: l.identityChangePendingTitle,
              body: l.identityChangePendingBody,
            );
          }
          if (!_forceForm &&
              latest != null &&
              latest.status == IdentityChangeStatus.rejected) {
            return _StatusCard(
              icon: DeliveryIcons.close,
              title: l.identityChangeRejectedTitle,
              body: latest.rejectionReason ?? '',
              action: DeliveryButton.primary(
                key: const ValueKey('identity-correct'),
                label: l.identityChangeCorrect,
                onPressed: () => _correct(latest),
              ),
            );
          }
          return _Form(
            isVehicle: _isVehicle,
            nameController: _nameController,
            vehicleNumberController: _vehicleNumberController,
            reasonController: _reasonController,
            currentName: widget.currentName,
            currentVehicleType: widget.currentVehicleType,
            currentVehicleNumber: widget.currentVehicleNumber,
            vehicleType: _vehicleType,
            onVehicleTypeChanged: (v) => setState(() => _vehicleType = v),
            fieldProblem: _fieldProblem,
            failure: _failure,
            saving: _saving,
            onSubmit: _submit,
          );
        },
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Padding(
      padding: const EdgeInsets.all(DeliverySpace.page),
      child: DeliveryCard(
        padding: const EdgeInsets.all(DeliverySpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(icon, color: c.textSecondary, size: DeliveryIconSize.hero),
            const SizedBox(height: DeliverySpace.md),
            Text(title, style: t.titleMedium.copyWith(color: c.textPrimary)),
            const SizedBox(height: DeliverySpace.sm),
            Text(body, style: t.bodyMedium.copyWith(color: c.textSecondary)),
            if (action != null) ...[
              const SizedBox(height: DeliverySpace.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({
    required this.isVehicle,
    required this.nameController,
    required this.vehicleNumberController,
    required this.reasonController,
    required this.currentName,
    required this.currentVehicleType,
    required this.currentVehicleNumber,
    required this.vehicleType,
    required this.onVehicleTypeChanged,
    required this.fieldProblem,
    required this.failure,
    required this.saving,
    required this.onSubmit,
  });
  final bool isVehicle;
  final TextEditingController nameController;
  final TextEditingController vehicleNumberController;
  final TextEditingController reasonController;
  final String currentName;
  final VehicleType? currentVehicleType;
  final String currentVehicleNumber;
  final VehicleType? vehicleType;
  final ValueChanged<VehicleType?> onVehicleTypeChanged;
  final String? fieldProblem;
  final IdentityRequestFailure? failure;
  final bool saving;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    final needsPlate = vehicleType != VehicleType.bicycle;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(DeliverySpace.page),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isVehicle ? l.identityChangeCurrentVehicle : l.identityChangeCurrentName,
            style: t.bodySmall.copyWith(color: c.textSecondary),
          ),
          Text(
            isVehicle
                ? [
                    if (currentVehicleType != null) vehicleLabel(l, currentVehicleType!),
                    if (currentVehicleNumber.isNotEmpty) currentVehicleNumber,
                  ].join(' · ')
                : currentName,
            style: t.titleMedium.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: DeliverySpace.lg),
          if (isVehicle) ...[
            DropdownButtonFormField<VehicleType>(
              key: const ValueKey('identity-vehicle-type'),
              initialValue: vehicleType,
              decoration: InputDecoration(
                labelText: l.identityChangeProposedVehicleType,
                errorText: _identityFieldErrorFor(l, fieldProblem == 'vehicleType' ? fieldProblem : null),
              ),
              items: [
                for (final v in VehicleType.values)
                  DropdownMenuItem(value: v, child: Text(vehicleLabel(l, v))),
              ],
              onChanged: onVehicleTypeChanged,
            ),
            if (needsPlate) ...[
              const SizedBox(height: DeliverySpace.md),
              TextField(
                key: const ValueKey('identity-vehicle-number'),
                controller: vehicleNumberController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: l.identityChangeProposedVehicleNumber,
                  errorText: _identityFieldErrorFor(l, fieldProblem == 'vehicleNumber' ? fieldProblem : null),
                ),
              ),
            ],
          ] else
            TextField(
              key: const ValueKey('identity-name'),
              controller: nameController,
              decoration: InputDecoration(
                labelText: l.identityChangeProposedName,
                errorText: _identityFieldErrorFor(l, fieldProblem == 'name' ? fieldProblem : null),
              ),
            ),
          const SizedBox(height: DeliverySpace.md),
          TextField(
            key: const ValueKey('identity-reason'),
            controller: reasonController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: l.identityChangeReasonLabel,
              errorMaxLines: 3,
              errorText: fieldProblem == 'reason'
                  ? _identityFieldErrorFor(l, fieldProblem)
                  : null,
            ),
          ),
          if (failure != null && _identityFieldErrorFor(l, fieldProblem) == null)
            Padding(
              padding: const EdgeInsets.only(top: DeliverySpace.sm),
              child: Text(
                _identityFailureText(l, failure!),
                style: t.bodyMedium.copyWith(color: c.danger.text),
              ),
            ),
          const SizedBox(height: DeliverySpace.lg),
          DeliveryButton.primary(
            key: const ValueKey('identity-submit'),
            label: l.identityChangeSubmit,
            isLoading: saving,
            onPressed: saving ? null : onSubmit,
          ),
        ],
      ),
    );
  }
}
