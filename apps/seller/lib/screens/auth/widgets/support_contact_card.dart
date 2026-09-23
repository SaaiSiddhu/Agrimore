import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';

/// "Contact AgriMore" card used by the status and restricted screens.
/// Contacts come from `AppConstants` (agrimore_core), never retyped here.
class SupportContactCard extends StatelessWidget {
  const SupportContactCard({super.key});

  Future<void> _launch(Uri uri) async {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final text = context.wsText;
    final phoneDigits = AppConstants.supportPhone.replaceAll(RegExp(r'[^\d+]'), '');

    Widget row(IconData icon, String label, VoidCallback onTap) {
      return ListTile(
        leading: Icon(icon, color: t.primary, size: WsIconSize.control),
        title: Text(label, style: text.bodyLarge),
        trailing: Icon(AgIcons.chevronRight, color: t.textSecondary, size: WsIconSize.control),
        onTap: onTap,
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: WsSpace.s8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(WsSpace.s16, WsSpace.s8, WsSpace.s16, WsSpace.s4),
              child: Text(l10n.supportTitle, style: text.titleSmall),
            ),
            row(
              AgIcons.phone,
              l10n.supportCall(AppConstants.supportPhone),
              () => _launch(Uri(scheme: 'tel', path: phoneDigits)),
            ),
            row(
              AgIcons.mail,
              l10n.supportEmail(AppConstants.supportEmail),
              () => _launch(Uri(scheme: 'mailto', path: AppConstants.supportEmail)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sign-out with a confirm sheet (principle 7: confirm what the user would
/// have to redo). Shared by the status and restricted screens.
class SignOutButton extends StatelessWidget {
  const SignOutButton({super.key, required this.onConfirmed});
  final Future<void> Function() onConfirmed;

  Future<void> _confirm(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final text = context.wsText;
    final yes = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(WsSpace.page, 0, WsSpace.page, WsSpace.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.signOutConfirmTitle, style: text.titleMedium),
              const SizedBox(height: WsSpace.s8),
              Text(l10n.signOutConfirmBody, style: text.bodyLarge),
              const SizedBox(height: WsSpace.s24),
              SaLoadingButton(text: l10n.signOut, onPressed: () => Navigator.of(sheet).pop(true)),
              const SizedBox(height: WsSpace.s8),
              SaLoadingButton(
                text: l10n.cancel,
                variant: SaButtonVariant.outlined,
                onPressed: () => Navigator.of(sheet).pop(false),
              ),
            ],
          ),
        ),
      ),
    );
    if (yes == true) await onConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextButton.icon(
      onPressed: () => _confirm(context),
      icon: const Icon(AgIcons.logOut, size: WsIconSize.control),
      label: Text(l10n.signOut),
    );
  }
}
