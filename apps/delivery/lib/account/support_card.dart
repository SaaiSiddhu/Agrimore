// lib/account/support_card.dart
//
// Phase DLV-A2 — the configured Agrimore support contacts
// (AppConstants.supportPhone / supportEmail), as actions. Opening the phone
// app or mail app is not contacting anyone; nothing here claims it is.
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';

class SupportContactButtons extends StatelessWidget {
  const SupportContactButtons({super.key, this.launcher});

  /// Injected in tests.
  final Future<bool> Function(Uri uri)? launcher;

  Future<void> _open(BuildContext context, Uri uri, String shown) async {
    bool ok;
    try {
      ok = await (launcher ?? (u) => launchUrl(u, mode: LaunchMode.externalApplication))(uri);
    } catch (_) {
      ok = false;
    }
    if (!ok && context.mounted) {
      WsToast.show(context, AppLocalizations.of(context).supportOpenFailed(shown), tone: WsToastTone.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final phone = AppConstants.supportPhone.replaceAll(RegExp(r'[\s-]'), '');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      OutlinedButton.icon(
        onPressed: () => _open(context, Uri(scheme: 'tel', path: phone), AppConstants.supportPhone),
        icon: const Icon(AgIcons.phone),
        label: Text(l.supportCall),
      ),
      const SizedBox(height: WsSpace.s8),
      OutlinedButton.icon(
        onPressed: () => _open(context, Uri(scheme: 'mailto', path: AppConstants.supportEmail), AppConstants.supportEmail),
        icon: const Icon(AgIcons.mail),
        label: Text(l.supportEmail),
      ),
    ]);
  }
}
