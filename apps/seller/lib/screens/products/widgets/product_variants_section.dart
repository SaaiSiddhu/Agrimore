import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';

/// Upper bound on options per product (keeps the product document small).
const int kMaxVariants = 20;

/// C-03 step 4 (ADR, SELLER-CATALOGUE-2): options such as sizes or pack
/// weights, each with its own price and stock. Checkout prices and
/// decrements the chosen option server-side (orderPricing.findVariant).
class ProductVariantsSection extends StatelessWidget {
  const ProductVariantsSection({super.key, required this.variants, required this.onChanged});
  final List<ProductVariant> variants;
  final ValueChanged<List<ProductVariant>> onChanged;

  Future<void> _edit(BuildContext context, [int? index]) async {
    final result = await showModalBottomSheet<ProductVariant>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _VariantSheet(
        initial: index == null ? null : variants[index],
        existingNames: {for (var i = 0; i < variants.length; i++) if (i != index) variants[i].name.toLowerCase()},
      ),
    );
    if (result == null) return;
    final next = [...variants];
    if (index == null) {
      next.add(result);
    } else {
      next[index] = result;
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final text = context.wsText;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(WsSpace.s16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.variantsTitle, style: text.titleSmall),
          Text(l10n.variantsHint, style: text.bodySmall!.copyWith(color: t.textSecondary)),
          const SizedBox(height: WsSpace.s8),
          for (var i = 0; i < variants.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(variants[i].name, style: text.bodyLarge),
              subtitle: Text(
                l10n.variantsLine(AgFormat.rupees(variants[i].salePrice), AgFormat.count(variants[i].stock)),
                style: text.bodySmall,
              ),
              onTap: () => _edit(context, i),
              trailing: IconButton(
                tooltip: l10n.variantsRemove(variants[i].name),
                icon: Icon(AgIcons.delete, color: t.errorFg),
                onPressed: () => onChanged([...variants]..removeAt(i)),
              ),
            ),
          if (variants.length < kMaxVariants)
            TextButton.icon(onPressed: () => _edit(context), icon: const Icon(AgIcons.add), label: Text(l10n.variantsAdd)),
        ]),
      ),
    );
  }
}

class _VariantSheet extends StatefulWidget {
  const _VariantSheet({this.initial, required this.existingNames});
  final ProductVariant? initial;
  final Set<String> existingNames;

  @override
  State<_VariantSheet> createState() => _VariantSheetState();
}

class _VariantSheetState extends State<_VariantSheet> {
  static const int _maxName = 40;
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _price = TextEditingController(text: widget.initial == null ? '' : _plain(widget.initial!.salePrice));
  late final _stock = TextEditingController(text: widget.initial == null ? '' : '${widget.initial!.stock}');

  static String _plain(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _stock.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final name = _name.text.trim();
    final initial = widget.initial;
    Navigator.of(context).pop(ProductVariant(
      // Stable id: keep an existing one; new ones get a slug of the name
      // plus time so two edits never collide.
      id: initial != null && initial.id.isNotEmpty
          ? initial.id
          : '${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      sku: initial?.sku,
      salePrice: double.parse(_price.text.trim()),
      originalPrice: initial?.originalPrice,
      stock: int.parse(_stock.text.trim()),
      images: initial?.images ?? const [],
      options: initial?.options ?? const {},
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = context.wsText;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(WsSpace.page, 0, WsSpace.page, WsSpace.s24),
          child: Form(
            key: _form,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(widget.initial == null ? l10n.variantsAdd : l10n.variantsEdit, style: text.titleMedium),
              const SizedBox(height: WsSpace.s12),
              TextFormField(
                key: const ValueKey('variantName'),
                controller: _name,
                maxLength: _maxName,
                decoration: InputDecoration(labelText: l10n.variantsName, hintText: l10n.variantsNameHint),
                validator: (v) {
                  final n = (v ?? '').trim();
                  if (n.isEmpty) return l10n.editorRequired;
                  if (widget.existingNames.contains(n.toLowerCase())) return l10n.variantsDuplicate;
                  return null;
                },
              ),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: TextFormField(
                    key: const ValueKey('variantPrice'),
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    decoration: InputDecoration(labelText: l10n.editorSalePrice),
                    validator: (v) => (double.tryParse((v ?? '').trim()) ?? 0) > 0 ? null : l10n.counterPriceInvalid,
                  ),
                ),
                const SizedBox(width: WsSpace.s12),
                Expanded(
                  child: TextFormField(
                    key: const ValueKey('variantStock'),
                    controller: _stock,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(labelText: l10n.editorStock),
                    validator: (v) => int.tryParse((v ?? '').trim()) == null ? l10n.counterQtyInvalid : null,
                  ),
                ),
              ]),
              const SizedBox(height: WsSpace.s16),
              FilledButton(onPressed: _save, child: Text(l10n.accountSave)),
            ]),
          ),
        ),
      ),
    );
  }
}
