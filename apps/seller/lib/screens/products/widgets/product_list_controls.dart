import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/seller_product_provider.dart';

String productFilterLabel(AppLocalizations l10n, ProductListFilter f) => switch (f) {
      ProductListFilter.all => l10n.filterAll,
      ProductListFilter.active => l10n.filterActive,
      ProductListFilter.draft => l10n.filterDraft,
      ProductListFilter.lowStock => l10n.filterLowStock,
      ProductListFilter.outOfStock => l10n.filterOutOfStock,
      ProductListFilter.inactive => l10n.filterInactive,
    };

/// C-01 status chips (boards 10, 18-01): All · Active · Drafts · Low stock ·
/// Out of stock · Inactive, each with its live count.
class ProductFilterBar extends StatelessWidget {
  const ProductFilterBar({super.key, required this.provider});
  final SellerProductProvider provider;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SellerChipBar(padding: EdgeInsets.symmetric(horizontal: context.pageInset), children: [
      for (final f in ProductListFilter.values)
        SellerChip(
          label: productFilterLabel(l10n, f),
          count: provider.countFor(f),
          selected: provider.filter == f,
          onSelected: (_) => provider.setFilter(f),
        ),
    ]);
  }
}

/// Bottom bar while products are selected (board 18-03): clear, count,
/// [Hide (n)] and [Publish (n)]. Replaces the Add product action.
class ProductBulkBar extends StatelessWidget {
  const ProductBulkBar({
    super.key,
    required this.count,
    required this.busy,
    required this.onPublish,
    required this.onHide,
    required this.onClear,
  });

  final int count;
  final bool busy;
  final VoidCallback onPublish;
  final VoidCallback onHide;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SellerStickyFooter(
      maxWidth: SellerSize.contentMaxWidth,
      // The count is in the app bar; this bar holds the actions.
      child: SellerButtonBar(children: [
        SellerButton.secondary(label: l10n.bulkHideCount(count), icon: SellerIcons.eyeOff, onPressed: busy ? null : onHide),
        SellerButton(label: l10n.bulkPublishCount(count), icon: SellerIcons.upload, loading: busy, onPressed: onPublish),
      ]),
    );
  }
}
