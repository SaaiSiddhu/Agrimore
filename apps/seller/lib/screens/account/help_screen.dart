import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../auth/widgets/support_contact_card.dart';

/// M-10 Help & support (ADR §10.6, SELLER-ACCOUNT-1b): searchable FAQs and
/// the support contacts.
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
    final t = context.ws;
    final text = context.wsText;
    final faqs = <(String, String)>[
      (l10n.faqPayoutQ, l10n.faqPayoutA),
      (l10n.faqOrderQ, l10n.faqOrderA),
      (l10n.faqQuoteQ, l10n.faqQuoteA),
      (l10n.faqInvoiceQ, l10n.faqInvoiceA),
      (l10n.faqReviewQ, l10n.faqReviewA),
      (l10n.faqStorefrontQ, l10n.faqStorefrontA),
    ];
    final q = _query.text.trim().toLowerCase();
    final shown = q.isEmpty
        ? faqs
        : faqs.where((f) => f.$1.toLowerCase().contains(q) || f.$2.toLowerCase().contains(q)).toList();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.back,
          icon: const Icon(AgIcons.arrowLeft),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(l10n.helpTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(WsSpace.page),
        children: [
          TextField(
            controller: _query,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(prefixIcon: const Icon(AgIcons.search), hintText: l10n.helpSearch),
          ),
          const SizedBox(height: WsSpace.s16),
          Text(l10n.helpFaqTitle, style: text.titleMedium),
          const SizedBox(height: WsSpace.s8),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: WsSpace.s16),
              child: Text(l10n.helpNoMatch, style: text.bodyMedium!.copyWith(color: t.textSecondary)),
            )
          else
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(children: [
                for (final f in shown)
                  ExpansionTile(
                    title: Text(f.$1, style: text.titleSmall),
                    childrenPadding: const EdgeInsets.fromLTRB(WsSpace.s16, 0, WsSpace.s16, WsSpace.s16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text(f.$2, style: text.bodyMedium)],
                  ),
              ]),
            ),
          const SizedBox(height: WsSpace.s24),
          Text(l10n.helpContactTitle, style: text.titleMedium),
          const SizedBox(height: WsSpace.s8),
          const SupportContactCard(),
        ],
      ),
    );
  }
}
