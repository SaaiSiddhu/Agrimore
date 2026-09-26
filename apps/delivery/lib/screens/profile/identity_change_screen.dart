// lib/screens/profile/identity_change_screen.dart
//
// Phase DLVID1 — request a change to a locked identity field (name only;
// see rider_identity.dart for why "date of birth" is not offered). Mirrors
// the mockup's own three states: a form when there is nothing pending, a
// "pending review" card once submitted, and a rejected card with the
// server's own reason plus a "Correct and resend" action that reopens the
// form prefilled with what was rejected.
import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import '../../identity/rider_identity.dart';
import '../../l10n/app_localizations.dart';

String? _identityFieldErrorFor(AppLocalizations l, String? field) => switch (field) {
      'proposedValue' => l.errIdentityProposedValue,
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
    this.currentName = '',
    this.backend,
  });
  final String riderId;

  /// Blank when opened somewhere the caller does not already have it (e.g.
  /// from an inbox notice) -- only the form state's "Current name" display
  /// needs it, and a tap that landed here almost always means the request
  /// has already been reviewed, not that a fresh one is being started.
  final String currentName;

  /// Injectable for tests; defaults to the real callable-backed service.
  final RiderIdentityBackend? backend;

  @override
  State<IdentityChangeScreen> createState() => _IdentityChangeScreenState();
}

class _IdentityChangeScreenState extends State<IdentityChangeScreen> {
  late final RiderIdentityBackend _backend =
      widget.backend ?? CallableRiderIdentityBackend();
  late final Stream<IdentityChangeRequest?> _latest =
      _backend.latestRequest(widget.riderId);
  final _nameController = TextEditingController();
  final _reasonController = TextEditingController();
  String? _fieldProblem;
  IdentityRequestFailure? _failure;
  bool _saving = false;

  /// True once "Correct and resend" is tapped on a rejected request, so the
  /// form shows again even though [_latest] still reports that same
  /// rejected request until a fresh one is submitted.
  bool _forceForm = false;

  @override
  void dispose() {
    _nameController.dispose();
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
        changeType: kIdentityChangeTypeName,
        proposedValue: _nameController.text,
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
    _nameController.text = rejected.proposedValue;
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
            nameController: _nameController,
            reasonController: _reasonController,
            currentName: widget.currentName,
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
    required this.nameController,
    required this.reasonController,
    required this.currentName,
    required this.fieldProblem,
    required this.failure,
    required this.saving,
    required this.onSubmit,
  });
  final TextEditingController nameController;
  final TextEditingController reasonController;
  final String currentName;
  final String? fieldProblem;
  final IdentityRequestFailure? failure;
  final bool saving;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(DeliverySpace.page),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.identityChangeCurrentName,
            style: t.bodySmall.copyWith(color: c.textSecondary),
          ),
          Text(currentName, style: t.titleMedium.copyWith(color: c.textPrimary)),
          const SizedBox(height: DeliverySpace.lg),
          TextField(
            key: const ValueKey('identity-name'),
            controller: nameController,
            decoration: InputDecoration(
              labelText: l.identityChangeProposedName,
              errorText: fieldProblem == 'proposedValue'
                  ? _identityFieldErrorFor(l, fieldProblem)
                  : null,
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
          if (failure != null && fieldProblem == null)
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
