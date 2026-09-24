import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';

/// Sticky footer of every application step (board 16-03): [Back] and the
/// main action (Save and continue / Submit application).
class StepFooter extends StatelessWidget {
  const StepFooter({
    super.key,
    required this.primaryLabel,
    required this.busyLabel,
    required this.busy,
    required this.onPrimary,
    this.onBack,
  });

  final String primaryLabel;
  final String busyLabel;
  final bool busy;
  final VoidCallback? onPrimary;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primary = SellerButton(label: primaryLabel, loading: busy, loadingLabel: busyLabel, onPressed: onPrimary);
    return SellerStickyFooter(
      child: onBack == null
          ? primary
          : SellerButtonBar(children: [
              SellerButton.secondary(label: l10n.back, icon: SellerIcons.back, onPressed: busy ? null : onBack),
              primary,
            ]),
    );
  }
}

/// Sign out with a confirmation (drafts are kept).
class ApplicationSignOut extends StatelessWidget {
  const ApplicationSignOut({super.key, required this.onConfirmed});
  final Future<void> Function() onConfirmed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SellerButton.tertiary(
      label: l10n.applySignOut,
      icon: SellerIcons.logOut,
      onPressed: () async {
        final yes = await sellerConfirm(
          context,
          icon: SellerIcons.logOut,
          title: l10n.applySignOutTitle,
          message: l10n.applySignOutBody,
          confirmLabel: l10n.applySignOut,
          cancelLabel: l10n.cancel,
          destructive: true,
        );
        if (yes) await onConfirmed();
      },
    );
  }
}
