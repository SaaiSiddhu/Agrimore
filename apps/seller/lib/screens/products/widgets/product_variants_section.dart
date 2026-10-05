import 'package:agrimore_core/agrimore_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';

/// Upper bound on options per product (keeps the product document small).
const int kMaxVariants = 20;

/// Pack options (board 18-05, SELLER-CATALOGUE-2): sizes or pack weights,
/// each with its own price and stock. Checkout prices and decrements the
/// chosen option server-side (orderPricing.findVariant).
class ProductVariantsSection extends StatelessWidget {
  const ProductVariantsSection({super.key, required this.variants, required this.onChanged});
  final List<ProductVariant> variants;
  final ValueChanged<List<ProductVariant>> onChanged;

  Future<void> _edit(BuildContext context, [int? index]) async {
    final result = await showModalBottomSheet<ProductVariant>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
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
    final c = context.colors;
    final add = variants.length < kMaxVariants
        ? SellerButton.secondary(label: l10n.variantsAdd, icon: SellerIcons.add, expand: true, onPressed: () => _edit(context))
        : null;
    if (variants.isEmpty) {
      return SellerEmptyState(
        icon: SellerIcons.packing,
        title: l10n.variantsEmptyTitle,
        message: l10n.variantsEmptyBody,
        actionLabel: l10n.variantsAdd,
        actionIcon: SellerIcons.add,
        onAction: () => _edit(context),
        compact: true,
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SellerSectionHeader(title: l10n.variantsCount(variants.length), subtitle: l10n.variantsHint),
      SellerMenuGroup(children: [
        for (var i = 0; i < variants.length; i++)
          SellerListRow(
            title: variants[i].name,
            subtitle: l10n.variantsLine(SellerFormat.money(variants[i].salePrice), variants[i].stockConfigured ? SellerFormat.count(variants[i].stock) : l10n.productStockUnknown),
            icon: SellerIcons.packing,
            showChevron: false,
            onTap: () => _edit(context, i),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              SellerIconButton(icon: SellerIcons.edit, label: l10n.variantsEditNamed(variants[i].name), color: c.primary, onPressed: () => _edit(context, i)),
              SellerIconButton(
                icon: SellerIcons.delete,
                label: l10n.variantsRemove(variants[i].name),
                color: c.danger,
                onPressed: () => onChanged([...variants]..removeAt(i)),
              ),
            ]),
          ),
      ]),
      const SizedBox(height: SellerSpace.s12),
      if (add != null) add,
      const SizedBox(height: SellerSpace.s8),
      Text(l10n.variantsStockRule, style: context.text.bodySmall),
    ]);
  }
}

/// Add / edit option sheet: name, selling price, stock (board 18-05).
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
  late final _stock = TextEditingController(text: widget.initial == null || !widget.initial!.stockConfigured ? '' : '${widget.initial!.stock}');

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
    final price = SellerTextField(
      fieldKey: const ValueKey('variantPrice'),
      label: l10n.editorSalePrice,
      required: true,
      controller: _price,
      prefixText: SellerFormat.rupeeSymbol,
      tabular: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      validator: (v) => (double.tryParse(v.trim()) ?? 0) > 0 ? null : l10n.counterPriceInvalid,
    );
    final stock = SellerTextField(
      fieldKey: const ValueKey('variantStock'),
      label: l10n.editorStock,
      required: true,
      controller: _stock,
      tabular: true,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: (v) => int.tryParse(v.trim()) == null ? l10n.counterQtyInvalid : null,
    );
    return SellerSheetFrame(
      title: widget.initial == null ? l10n.variantsAdd : l10n.variantsEdit,
      body: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (widget.initial != null && !widget.initial!.stockConfigured) ...[
            SellerBanner(tone: SellerTone.info, message: l10n.productStockBackfillHelp),
            const SizedBox(height: SellerSpace.s12),
          ],
          SellerTextField(
            fieldKey: const ValueKey('variantName'),
            label: l10n.variantsName,
            hint: l10n.variantsNameHint,
            required: true,
            controller: _name,
            maxLength: _maxName,
            validator: (v) {
              final n = v.trim();
              if (n.isEmpty) return l10n.editorRequired;
              if (widget.existingNames.contains(n.toLowerCase())) return l10n.variantsDuplicate;
              return null;
            },
          ),
          const SizedBox(height: SellerSpace.s12),
          if (context.largeText) ...[price, const SizedBox(height: SellerSpace.s12), stock]
          else
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: price),
              const SizedBox(width: SellerSpace.s12),
              Expanded(child: stock),
            ]),
        ]),
      ),
      footer: SellerButton(label: l10n.accountSave, expand: true, onPressed: _save),
    );
  }
}
