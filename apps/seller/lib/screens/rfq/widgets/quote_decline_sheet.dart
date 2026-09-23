import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../quote_rules.dart';
import 'quote_copy.dart';

/// Decline sheet: a required reason, an optional note and the consequence.
/// Returns the text the buyer will read (reason label, then the note).
Future<String?> showQuoteDeclineSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
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
    final t = context.ws;
    final text = context.wsText;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(WsSpace.page, 0, WsSpace.page, WsSpace.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.declineTitle, style: text.titleMedium),
              const SizedBox(height: WsSpace.s8),
              Text(l10n.declinePrompt, style: text.bodyMedium),
              RadioGroup<String>(
                groupValue: _reason,
                onChanged: (v) => setState(() => _reason = v),
                child: Column(children: [
                  for (final r in kQuoteDeclineReasons)
                    RadioListTile<String>(
                      value: r,
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.declineReasonLabel(r), style: text.bodyLarge),
                    ),
                ]),
              ),
              TextField(
                controller: _note,
                maxLength: _maxNote,
                maxLines: 2,
                decoration: InputDecoration(labelText: l10n.declineNoteLabel),
              ),
              const SizedBox(height: WsSpace.s8),
              SaInfoBanner(variant: SaBannerVariant.info, message: l10n.declineConsequence),
              const SizedBox(height: WsSpace.s16),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: t.errorFg, foregroundColor: t.surface),
                onPressed: _reason == null
                    ? null
                    : () {
                        final label = l10n.declineReasonLabel(_reason!);
                        final note = _note.text.trim();
                        Navigator.of(context).pop(note.isEmpty ? label : '$label — $note');
                      },
                child: Text(l10n.declineCta),
              ),
              const SizedBox(height: WsSpace.s8),
              TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.declineKeep)),
            ],
          ),
        ),
      ),
    );
  }
}
