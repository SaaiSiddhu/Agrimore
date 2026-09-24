import 'package:agrimore_core/agrimore_core.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';

/// "Contact AgriMore" (board 23-06): headset in a mint circle, Call support
/// and Email support rows that hand off to the phone's apps. Contacts come
/// from `AppConstants` (agrimore_core), never retyped here.
class SellerSupportCard extends StatelessWidget {
  const SellerSupportCard({super.key});

  Future<void> _launch(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Support launch failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = context.text;
    final phoneDigits = AppConstants.supportPhone.replaceAll(RegExp(r'[^\d+]'), '');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const SellerIconTile(icon: SellerIcons.support, circle: true, size: SellerSize.avatarLg),
        const SizedBox(width: SellerSpace.s12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Semantics(header: true, child: Text(l10n.supportTitle, style: text.titleMedium)),
            Text(l10n.supportSubtitle, style: text.bodyMedium),
          ]),
        ),
      ]),
      const SizedBox(height: SellerSpace.s12),
      SellerMenuGroup(children: [
        SellerListRow(
          icon: SellerIcons.phone,
          title: l10n.supportCallTitle,
          subtitle: AppConstants.supportPhone,
          onTap: () => _launch(Uri(scheme: 'tel', path: phoneDigits)),
        ),
        SellerListRow(
          icon: SellerIcons.mail,
          title: l10n.supportEmailTitle,
          subtitle: AppConstants.supportEmail,
          onTap: () => _launch(Uri(scheme: 'mailto', path: AppConstants.supportEmail)),
        ),
      ]),
      const SizedBox(height: SellerSpace.s8),
      Text(l10n.supportOpensApps, style: text.bodySmall),
    ]);
  }
}
