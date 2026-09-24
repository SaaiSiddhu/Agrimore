import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../quote_rules.dart';
import 'quote_copy.dart';

/// Decline sheet (board 20-07): a required reason, an optional note and the
/// consequence. Returns the text the buyer will read (reason, then note).
Future<String?> showQuoteDeclineSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const QuoteDeclineSheet(),
  );
}

class QuoteDeclineSheet extends StatefulWidget {
  const QuoteDeclineSheet({super.key});

  @override
  State<QuoteDeclineSheet> createState() => _QuoteDeclineSheetState();
}

class _QuoteDeclineSheetState extends State<QuoteDeclineSheet> {
  static const int _maxNote = 300; // + the label stays under rfq.ts's 500
  String? _reason;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SellerSheetFrame(
      title: l10n.declineTitle,
      subtitle: l10n.declinePrompt,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Semantics(
          container: true,
          label: l10n.declinePrompt,
          child: Column(children: [
            for (final r in kQuoteDeclineReasons)
              SellerChoiceRow<String>(value: r, groupValue: _reason, title: l10n.declineReasonLabel(r), onChanged: (v) => setState(() => _reason = v)),
          ]),
        ),
        const SizedBox(height: SellerSpace.s12),
        SellerTextField(label: l10n.declineNoteLabel, controller: _note, maxLength: _maxNote, maxLines: 3, minLines: 2),
        const SizedBox(height: SellerSpace.s12),
        SellerBanner(tone: SellerTone.info, message: l10n.declineConsequence),
      ]),
      footer: SellerButtonBar(children: [
        SellerButton.secondary(label: l10n.declineKeep, onPressed: () => Navigator.of(context).pop()),
        SellerButton.danger(
          label: l10n.declineCta,
          onPressed: _reason == null
              ? null
              : () {
                  final label = l10n.declineReasonLabel(_reason!);
                  final note = _note.text.trim();
                  Navigator.of(context).pop(note.isEmpty ? label : l10n.quoteDeclineTerms(label, note));
                },
        ),
      ]),
    );
  }
}
