import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/seller_product_provider.dart';

/// C-01 status tabs (ADR §10.4): All · Active · Drafts · Out of stock ·
/// Inactive, each with its live count.
class ProductFilterBar extends StatelessWidget {
  const ProductFilterBar({super.key, required this.provider});
  final SellerProductProvider provider;

  String _label(AppLocalizations l10n, ProductListFilter f) => switch (f) {
        ProductListFilter.all => l10n.filterAll,
        ProductListFilter.active => l10n.filterActive,
        ProductListFilter.draft => l10n.filterDraft,
        ProductListFilter.lowStock => l10n.filterLowStock,
        ProductListFilter.outOfStock => l10n.filterOutOfStock,
        ProductListFilter.inactive => l10n.filterInactive,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: WsSize.minTouchTarget,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: WsSpace.s16),
        itemCount: ProductListFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: WsSpace.s8),
        itemBuilder: (context, i) {
          final f = ProductListFilter.values[i];
          return Center(
            child: ChoiceChip(
              label: Text(l10n.filterWithCount(_label(l10n, f), AgFormat.count(provider.countFor(f)))),
              selected: provider.filter == f,
              onSelected: (_) => provider.setFilter(f),
            ),
          );
        },
      ),
    );
  }
}

/// Selection frame around a product card: a check mark when selected, a
/// Draft badge for drafts. Long-press starts selection; while selecting, a
/// tap toggles.
class ProductSelectionFrame extends StatelessWidget {
  const ProductSelectionFrame({
    super.key,
    required this.selected,
    required this.selecting,
    required this.isDraft,
    required this.onToggle,
    required this.child,
  });

  final bool selected;
  final bool selecting;
  final bool isDraft;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    return GestureDetector(
      onLongPress: onToggle,
      onTap: selecting ? onToggle : null,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          AbsorbPointer(absorbing: selecting, child: child),
          if (selected)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: t.primarySubtle.withValues(alpha: WsOpacity.scrim),
                    borderRadius: BorderRadius.circular(WsRadius.card),
                    border: Border.all(color: t.primary, width: WsSize.focusRing),
                  ),
                ),
              ),
            ),
          if (selected)
            Positioned(
              top: WsSpace.s8,
              right: WsSpace.s8,
              child: Icon(AgIcons.success, color: t.primary, size: WsIconSize.nav),
            ),
          if (isDraft)
            Positioned(
              top: WsSpace.s8,
              left: WsSpace.s8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: WsSpace.s8, vertical: WsSpace.s2),
                decoration: BoxDecoration(
                  color: t.surfaceSunken,
                  borderRadius: BorderRadius.circular(WsRadius.small),
                  border: Border.all(color: t.divider),
                ),
                child: Text(l10n.draftBadge.toUpperCase(), style: context.wsText.labelSmall),
              ),
            ),
        ],
      ),
    );
  }
}

/// Sticky bar shown while products are selected: count, Publish, Hide, Clear.
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
    final t = context.ws;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.divider, width: WsSize.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: WsSpace.s16, vertical: WsSpace.s8),
          child: Row(
            children: [
              IconButton(tooltip: l10n.bulkClear, onPressed: busy ? null : onClear, icon: const Icon(AgIcons.close)),
              Expanded(child: Text(l10n.selectedCount(count), style: context.wsText.titleSmall)),
              TextButton(onPressed: busy ? null : onHide, child: Text(l10n.bulkDeactivate)),
              const SizedBox(width: WsSpace.s8),
              FilledButton(onPressed: busy ? null : onPublish, child: Text(l10n.bulkActivate)),
            ],
          ),
        ),
      ),
    );
  }
}
