import 'package:agrimore_core/agrimore_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design_system/design_system.dart';
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
    useSafeArea: true,
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

  /// Board 20-05/20-06: price, quantity (MOQ is a warning, not a block),
  /// validity chips (7 days by default), note, live total with the
  /// comparison, [Cancel][Send offer].
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final text = context.text;
    final price = _priceValue;
    final qty = _qtyValue;
    final moq = widget.quote.listedB2bMoq;
    final vs = price == null ? null : l10n.vsListed(price, widget.quote.listedB2bPrice);
    final priceField = SellerTextField(
      fieldKey: const ValueKey('counterPrice'),
      label: l10n.counterPriceLabel,
      required: true,
      controller: _price,
      prefixText: SellerFormat.rupeeSymbol,
      tabular: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      onChanged: (_) => setState(() {}),
      errorText: _submitted && price == null ? l10n.counterPriceInvalid : null,
    );
    final qtyField = SellerTextField(
      fieldKey: const ValueKey('counterQty'),
      label: l10n.counterQtyLabel,
      required: true,
      controller: _qty,
      tabular: true,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (_) => setState(() {}),
      errorText: _submitted && qty == null ? l10n.counterQtyInvalid : null,
    );
    return SellerSheetFrame(
      title: l10n.counterTitle,
      subtitle: l10n.counterToBuyer(l10n.buyerOf(widget.quote)),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (context.largeText) ...[priceField, const SizedBox(height: SellerSpace.s12), qtyField]
        else
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: priceField),
            const SizedBox(width: SellerSpace.s12),
            Expanded(child: qtyField),
          ]),
        if (qty != null && moq != null && qty < moq) ...[
          const SizedBox(height: SellerSpace.s12),
          SellerBanner(tone: SellerTone.warning, title: l10n.counterBelowMoq(SellerFormat.count(moq)), message: l10n.counterMoqWarning),
        ],
        const SizedBox(height: SellerSpace.s16),
        SellerFieldLabel(label: l10n.counterValidityLabel),
        const SizedBox(height: SellerSpace.s6),
        Wrap(spacing: SellerSpace.s8, runSpacing: SellerSpace.s4, children: [
          for (final d in kQuoteValidityDays)
            SellerChip(label: l10n.counterValidityDays(d), selected: _days == d, onSelected: (_) => setState(() => _days = d)),
        ]),
        const SizedBox(height: SellerSpace.s16),
        SellerTextField(label: l10n.counterNoteLabel, controller: _note, maxLength: _maxNote, maxLines: 3, minLines: 2),
        const SizedBox(height: SellerSpace.s12),
        SellerCard(
          tone: SellerCardTone.mint,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(l10n.counterTotal, style: text.titleSmall)),
              Text(price == null || qty == null ? '—' : SellerFormat.money(price * qty), style: text.titleLarge!.copyWith(color: c.textPrimary).tabular),
            ]),
            if (vs != null) Text(vs, style: text.bodyMedium!.copyWith(color: c.textPrimary)),
          ]),
        ),
      ]),
      footer: SellerButtonBar(children: [
        SellerButton.secondary(label: l10n.cancel, onPressed: () => Navigator.of(context).pop()),
        SellerButton(label: l10n.counterSend, icon: SellerIcons.send, onPressed: _send),
      ]),
    );
  }
}
