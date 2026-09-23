import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../quote_rules.dart';
import 'quote_copy.dart';

/// What the seller entered on Q-03.
@immutable
class CounterOffer {
  const CounterOffer({required this.price, required this.quantity, required this.validForDays, required this.note});
  final double price;
  final int quantity;
  final int validForDays;
  final String note;
}

/// Q-03 Counter-offer sheet (ADR §10.4): price, quantity, validity and a
/// note, with a live total and how the price compares with the listed B2B
/// price. Pre-filled from the offer on the table.
Future<CounterOffer?> showQuoteCounterSheet(BuildContext context, RfqModel quote) {
  return showModalBottomSheet<CounterOffer>(
    context: context,
    isScrollControlled: true,
    builder: (_) => QuoteCounterSheet(quote: quote),
  );
}

class QuoteCounterSheet extends StatefulWidget {
  const QuoteCounterSheet({super.key, required this.quote});
  final RfqModel quote;

  @override
  State<QuoteCounterSheet> createState() => _QuoteCounterSheetState();
}

class _QuoteCounterSheetState extends State<QuoteCounterSheet> {
  static const int _maxNote = 500; // rfq.ts MAX_NOTES_LENGTH
  late final TextEditingController _price;
  late final TextEditingController _qty;
  final _note = TextEditingController();
  int _days = kDefaultQuoteValidityDays;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final offer = widget.quote.lastOffer;
    final price = offer?.price ?? widget.quote.listedB2bPrice;
    _price = TextEditingController(text: price == null ? '' : _plain(price));
    _qty = TextEditingController(text: offer == null ? '' : '${offer.quantity}');
  }

  static String _plain(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  void dispose() {
    _price.dispose();
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  double? get _priceValue {
    final v = double.tryParse(_price.text.trim());
    return v != null && v > 0 ? v : null;
  }

  int? get _qtyValue {
    final v = int.tryParse(_qty.text.trim());
    return v != null && v > 0 ? v : null;
  }

  void _send() {
    setState(() => _submitted = true);
    final price = _priceValue;
    final qty = _qtyValue;
    if (price == null || qty == null) return;
    Navigator.of(context).pop(CounterOffer(price: price, quantity: qty, validForDays: _days, note: _note.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final text = context.wsText;
    final price = _priceValue;
    final qty = _qtyValue;
    final moq = widget.quote.listedB2bMoq;
    final vs = price == null ? null : l10n.vsListed(price, widget.quote.listedB2bPrice);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(WsSpace.page, 0, WsSpace.page, WsSpace.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.counterTitle, style: text.titleMedium),
              const SizedBox(height: WsSpace.s4),
              Text(l10n.productOf(widget.quote), style: text.bodyMedium!.copyWith(color: t.textSecondary)),
              const SizedBox(height: WsSpace.s16),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('counterPrice'),
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: l10n.counterPriceLabel,
                      errorText: _submitted && price == null ? l10n.counterPriceInvalid : null,
                    ),
                  ),
                ),
                const SizedBox(width: WsSpace.s12),
                Expanded(
                  child: TextField(
                    key: const ValueKey('counterQty'),
                    controller: _qty,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: l10n.counterQtyLabel,
                      errorText: _submitted && qty == null ? l10n.counterQtyInvalid : null,
                      helperText: qty != null && moq != null && qty < moq ? l10n.counterBelowMoq(AgFormat.count(moq)) : null,
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: WsSpace.s16),
              Text(l10n.counterValidityLabel, style: text.labelLarge),
              const SizedBox(height: WsSpace.s8),
              Wrap(spacing: WsSpace.s8, runSpacing: WsSpace.s8, children: [
                for (final d in kQuoteValidityDays)
                  ChoiceChip(
                    label: Text(l10n.counterValidityDays(d)),
                    selected: _days == d,
                    onSelected: (_) => setState(() => _days = d),
                  ),
              ]),
              const SizedBox(height: WsSpace.s16),
              TextField(
                controller: _note,
                maxLength: _maxNote,
                maxLines: 2,
                decoration: InputDecoration(labelText: l10n.counterNoteLabel),
              ),
              const SizedBox(height: WsSpace.s8),
              Container(
                padding: const EdgeInsets.all(WsSpace.s16),
                decoration: BoxDecoration(
                  color: t.primarySubtle,
                  borderRadius: BorderRadius.circular(WsRadius.card),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(l10n.counterTotal, style: text.bodyMedium)),
                    Text(
                      price == null || qty == null ? '—' : AgFormat.rupees(price * qty),
                      style: text.titleMedium!.copyWith(fontFeatures: WsType.tabularFigures, color: t.primary),
                    ),
                  ]),
                  if (vs != null) ...[
                    const SizedBox(height: WsSpace.s4),
                    Text(vs, style: text.bodySmall!.copyWith(color: t.textSecondary)),
                  ],
                ]),
              ),
              const SizedBox(height: WsSpace.s16),
              FilledButton(onPressed: _send, child: Text(l10n.counterSend)),
              const SizedBox(height: WsSpace.s8),
              TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
            ],
          ),
        ),
      ),
    );
  }
}
