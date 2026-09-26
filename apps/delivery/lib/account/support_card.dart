// lib/account/support_card.dart
//
// Phase DLV-A2 — the configured Agrimore support contacts
// (AppConstants.supportPhone / supportEmail), as actions. Opening the phone
// app or mail app is not contacting anyone; nothing here claims it is.
import 'package:agrimore_core/agrimore_core.dart' show AppConstants;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design_system/design_system.dart';
import '../l10n/app_localizations.dart';

/// Opens the phone app on the configured support number, with the same
/// graceful-failure toast the button pair below uses. Shared with
/// help_support_screen.dart's "Call support" row (Phase DLVSUP1) so both
/// entry points behave identically instead of duplicating the launch logic.
Future<void> openSupportCall(
  BuildContext context, {
  Future<bool> Function(Uri uri)? launcher,
}) =>
    _open(
      context,
      Uri(scheme: 'tel', path: AppConstants.supportPhone.replaceAll(RegExp(r'[\s-]'), '')),
      AppConstants.supportPhone,
      launcher,
    );

Future<void> _open(
  BuildContext context,
  Uri uri,
  String shown, [
  Future<bool> Function(Uri uri)? launcher,
]) async {
  bool ok;
  try {
    ok = await (launcher ??
        (u) => launchUrl(u, mode: LaunchMode.externalApplication))(uri);
  } catch (_) {
    ok = false;
  }
  if (!ok && context.mounted) {
    showDeliveryToast(
      context,
      message: AppLocalizations.of(context).supportOpenFailed(shown),
      tone: DeliveryBannerTone.danger,
    );
  }
}

class SupportContactButtons extends StatelessWidget {
  const SupportContactButtons({super.key, this.launcher});

  /// Injected in tests.
  final Future<bool> Function(Uri uri)? launcher;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DeliveryButton.secondary(
          label: l.supportCall,
          icon: DeliveryIcons.phone,
          onPressed: () => openSupportCall(context, launcher: launcher),
        ),
        const SizedBox(height: DeliverySpace.sm),
        DeliveryButton.secondary(
          label: l.supportEmail,
          icon: DeliveryIcons.mail,
          onPressed: () => _open(
            context,
            Uri(scheme: 'mailto', path: AppConstants.supportEmail),
            AppConstants.supportEmail,
            launcher,
          ),
        ),
      ],
    );
  }
}
