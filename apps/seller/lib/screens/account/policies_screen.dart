import 'package:agrimore_core/agrimore_core.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';

/// Seller policies (board 23-07): the three rules as numbered cards, then
/// the legal documents (configured URLs, opened in the browser).
class SellerPoliciesScreen extends StatelessWidget {
  const SellerPoliciesScreen({super.key});

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Policy link failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final text = context.text;
    final rules = [l10n.legalAccurate, l10n.legalPackOnTime, l10n.legalPayouts];
    return Scaffold(
      appBar: SellerAppBar.detail(context, title: l10n.accountLegal),
      body: SellerPage(
        gap: SellerSpace.s12,
        children: [
          for (var i = 0; i < rules.length; i++)
            SellerCard(
              tone: SellerCardTone.subtle,
              child: MergeSemantics(
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: SellerSize.avatarSm,
                    height: SellerSize.avatarSm,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: c.primaryContainer, shape: BoxShape.circle),
                    child: Text(SellerFormat.count(i + 1), style: text.labelLarge!.copyWith(color: c.onPrimaryContainer)),
                  ),
                  const SizedBox(width: SellerSpace.s12),
                  Expanded(child: Text(rules[i], style: text.bodyLarge)),
                  const SizedBox(width: SellerSpace.s8),
                  Icon(SellerIcons.shield, size: SellerIconSize.md, color: c.primary),
                ]),
              ),
            ),
          const SizedBox(height: SellerSpace.s8),
          SellerMenuGroup(title: l10n.policiesLegalDocs, children: [
            SellerListRow(icon: SellerIcons.document, title: l10n.legalTerms, trailing: const Icon(SellerIcons.externalLink), showChevron: false, onTap: () => _open(AppConstants.termsUrl)),
            SellerListRow(icon: SellerIcons.document, title: l10n.legalPrivacy, trailing: const Icon(SellerIcons.externalLink), showChevron: false, onTap: () => _open(AppConstants.privacyPolicyUrl)),
          ]),
          Text(l10n.policiesOpensBrowser, style: text.bodySmall),
        ],
      ),
    );
  }
}
