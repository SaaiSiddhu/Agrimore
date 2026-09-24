import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import 'policies_screen.dart';
import 'widgets/support_card.dart';

/// Help & support (boards 23-05, 23-06; one screen): contact card, FAQ
/// search with a result count, expandable answers, and seller policies.
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = context.text;
    final faqs = <(String, String)>[
      (l10n.faqPayoutQ, l10n.faqPayoutA),
      (l10n.faqOrderQ, l10n.faqOrderA),
      (l10n.faqQuoteQ, l10n.faqQuoteA),
      (l10n.faqInvoiceQ, l10n.faqInvoiceA),
      (l10n.faqReviewQ, l10n.faqReviewA),
      (l10n.faqStorefrontQ, l10n.faqStorefrontA),
    ];
    final q = _query.text.trim().toLowerCase();
    final shown = q.isEmpty ? faqs : faqs.where((f) => f.$1.toLowerCase().contains(q) || f.$2.toLowerCase().contains(q)).toList();
    return Scaffold(
      appBar: SellerAppBar.detail(context, title: l10n.helpTitle),
      body: SellerPage(
        gap: SellerSpace.s16,
        children: [
          const SellerSupportCard(),
          const Divider(),
          SellerSectionHeader(title: l10n.helpFaqTitle),
          SellerSearchField(controller: _query, hint: l10n.helpSearch, onChanged: (_) => setState(() {})),
          if (q.isNotEmpty) Semantics(liveRegion: true, child: Text(l10n.helpResults(shown.length), style: text.bodyMedium)),
          if (shown.isEmpty)
            SellerEmptyState(icon: SellerIcons.search, title: l10n.helpNoMatchTitle, message: l10n.helpNoMatchBody, compact: true)
          else
            for (final f in shown) SellerExpandableRow(title: f.$1, child: Text(f.$2)),
          SellerMenuGroup(children: [
            SellerListRow(
              icon: SellerIcons.policy,
              title: l10n.accountLegal,
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SellerPoliciesScreen())),
            ),
          ]),
        ],
      ),
    );
  }
}
