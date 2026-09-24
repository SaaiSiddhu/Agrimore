import 'package:agrimore_core/agrimore_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/seller_auth_provider.dart';
import '../../providers/seller_product_provider.dart';
import '../home/add_product_screen.dart';
import '../posts/create_post_screen.dart';
import 'widgets/product_list_controls.dart';

/// Stock levels (SellerProductProvider.lowStockProducts uses the same line).
const int kLowStockLine = 10;

/// Stock badge: "25 in stock" · "Only 3 left" · "Out of stock" — text, icon
/// and tone (board 12).
Widget productStockBadge(AppLocalizations l10n, ProductModel p) {
  if (p.stock <= 0) return SellerStatusBadge(label: l10n.productOutOfStock, tone: SellerTone.danger, icon: SellerIcons.cancelled);
  if (p.stock < kLowStockLine) {
    return SellerStatusBadge(label: l10n.productLowStock(SellerFormat.count(p.stock)), tone: SellerTone.warning, icon: SellerIcons.warning);
  }
  return SellerStatusBadge(label: l10n.searchStock(SellerFormat.count(p.stock)), tone: SellerTone.success, icon: SellerIcons.success);
}

/// C-01 Catalogue (boards 18-01…18-03, selected revision 18-02): search,
/// status chips, product cards (visibility switch, Edit + overflow), long
/// press to select, bulk publish/hide with a result per product.
class SellerProductsScreen extends StatefulWidget {
  const SellerProductsScreen({super.key});

  @override
  State<SellerProductsScreen> createState() => _SellerProductsScreenState();
}

class _SellerProductsScreenState extends State<SellerProductsScreen> {
  final _search = TextEditingController();
  final Set<String> _selected = {};
  bool _bulkBusy = false;

  String? get _uid => context.read<SellerAuthProvider>().currentUser?.uid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    final uid = _uid;
    if (uid != null) context.read<SellerProductProvider>().loadSellerProducts(uid);
  }

  void _toggle(String id) {
    HapticFeedback.selectionClick();
    setState(() => _selected.contains(id) ? _selected.remove(id) : _selected.add(id));
  }

  Future<void> _bulk(bool publish) async {
    final l10n = AppLocalizations.of(context);
    final ids = {..._selected};
    setState(() => _bulkBusy = true);
    final failed = await context.read<SellerProductProvider>().bulkSetActiveEach(ids, publish);
    if (!mounted) return;
    setState(() {
      _bulkBusy = false;
      // Failed products stay selected so the seller can retry them.
      _selected
        ..clear()
        ..addAll(failed);
    });
    if (failed.isEmpty) {
      SellerToast.show(context, l10n.bulkDone(ids.length), tone: SellerToastTone.success);
    } else if (failed.length == ids.length) {
      SellerToast.show(context, l10n.bulkFailed, tone: SellerToastTone.danger);
    } else {
      SellerToast.show(context, l10n.bulkPartial(ids.length - failed.length, failed.length), tone: SellerToastTone.danger);
    }
  }

  Future<void> _editStock(ProductModel p) async {
    final l10n = AppLocalizations.of(context);
    final uid = _uid;
    final provider = context.read<SellerProductProvider>();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _StockSheet(
        product: p,
        onSave: (value) => uid == null ? Future.value(false) : provider.updateStock(p.id, value, uid),
      ),
    );
    if (saved == true && mounted) SellerToast.show(context, l10n.productStockSaved, tone: SellerToastTone.success);
  }

  Future<void> _delete(ProductModel p) async {
    final l10n = AppLocalizations.of(context);
    final yes = await sellerConfirm(
      context,
      title: l10n.productDeleteTitle,
      message: l10n.productDeleteBody(p.name),
      confirmLabel: l10n.productDelete,
      cancelLabel: l10n.cancel,
      icon: SellerIcons.delete,
      destructive: true,
    );
    final uid = _uid;
    if (!yes || uid == null || !mounted) return;
    final ok = await context.read<SellerProductProvider>().deleteProduct(p.id, uid);
    if (mounted) {
      SellerToast.show(context, ok ? l10n.productDeleted : l10n.productActionFailed,
          tone: ok ? SellerToastTone.success : SellerToastTone.danger);
    }
  }

  Future<void> _setLive(ProductModel p, bool live) async {
    final l10n = AppLocalizations.of(context);
    final uid = _uid;
    if (uid == null) return;
    HapticFeedback.selectionClick();
    final ok = await context.read<SellerProductProvider>().toggleProductActive(p.id, live, uid);
    if (!ok && mounted) SellerToast.show(context, l10n.productVisibilityFailed, tone: SellerToastTone.danger);
  }

  void _push(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  Future<void> _sortMenu(SellerProductProvider provider) async {
    final l10n = AppLocalizations.of(context);
    final chosen = await showSellerSheet<ProductSort>(
      context,
      title: l10n.sortTitle,
      builder: (ctx) => Column(children: [
        for (final (s, label) in [
          (ProductSort.newest, l10n.sortNewest),
          (ProductSort.nameAz, l10n.sortNameAz),
          (ProductSort.priceLow, l10n.sortPriceLow),
          (ProductSort.priceHigh, l10n.sortPriceHigh),
          (ProductSort.stockLow, l10n.sortStockLow),
        ])
          SellerChoiceRow<ProductSort>(value: s, groupValue: provider.sort, title: label, onChanged: (v) => Navigator.of(ctx).pop(v)),
      ]),
    );
    if (chosen != null) provider.setSort(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<SellerProductProvider>();
    final products = provider.products;
    final selecting = _selected.isNotEmpty;

    Widget body;
    if (provider.error != null && provider.allProducts.isEmpty) {
      body = SellerErrorState(title: l10n.productsLoadFailed, onRetry: _reload);
    } else if (provider.isLoading && provider.allProducts.isEmpty) {
      body = SellerSkeletonList(label: l10n.dsLoading);
    } else if (products.isEmpty) {
      body = provider.allProducts.isEmpty
          ? SellerEmptyState(
              icon: SellerIcons.catalogue,
              title: l10n.productsEmpty,
              actionLabel: l10n.homeAddProduct,
              actionIcon: SellerIcons.add,
              onAction: () => _push(const AddProductScreen()),
            )
          : SellerEmptyState(icon: SellerIcons.search, title: l10n.productsNoneMatch);
    } else {
      body = RefreshIndicator(
        onRefresh: () async => _reload(),
        child: ListView.separated(
          padding: EdgeInsets.fromLTRB(context.pageInset, SellerSpace.s4, context.pageInset, SellerSpace.s24),
          itemCount: products.length,
          separatorBuilder: (_, __) => const SizedBox(height: SellerSpace.s12),
          itemBuilder: (context, i) {
            final p = products[i];
            return _ProductCard(
              product: p,
              selecting: selecting,
              selected: _selected.contains(p.id),
              onSelect: () => _toggle(p.id),
              onLive: (v) => _setLive(p, v),
              onStock: () => _editStock(p),
              onEdit: () => _push(AddProductScreen(existingProduct: p)),
              onDelete: () => _delete(p),
            );
          },
        ),
      );
    }

    return PopScope<Object?>(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_selected.clear);
      },
      child: Scaffold(
        appBar: selecting
            ? SellerAppBar.detail(
                context,
                title: l10n.selectedCount(_selected.length),
                close: true,
                onBack: () => setState(_selected.clear),
              )
            : SellerAppBar.root(context, title: l10n.navCatalogue, actions: [
                SellerIconButton(icon: SellerIcons.sort, label: l10n.sortTitle, onPressed: () => _sortMenu(provider)),
                SellerIconButton(icon: SellerIcons.post, label: l10n.productNewPost, onPressed: () => _push(const CreatePostScreen())),
                SellerIconButton(icon: SellerIcons.add, label: l10n.homeAddProduct, filled: true, onPressed: () => _push(const AddProductScreen())),
              ]),
        body: Column(children: [
          Padding(
            padding: EdgeInsets.fromLTRB(context.pageInset, SellerSpace.s4, context.pageInset, SellerSpace.s8),
            child: SellerSearchField(
              controller: _search,
              hint: l10n.productSearchHint,
              onChanged: (v) {
                provider.setSearchQuery(v);
                setState(() {});
              },
            ),
          ),
          ProductFilterBar(provider: provider),
          Expanded(child: body),
          if (selecting)
            ProductBulkBar(
              count: _selected.length,
              busy: _bulkBusy,
              onPublish: () => _bulk(true),
              onHide: () => _bulk(false),
              onClear: () => setState(_selected.clear),
            )
          else if (provider.allProducts.isNotEmpty)
            SellerStickyFooter(
              maxWidth: SellerSize.contentMaxWidth,
              child: SellerButton.tonal(label: l10n.homeAddProduct, icon: SellerIcons.add, expand: true, onPressed: () => _push(const AddProductScreen())),
            ),
        ]),
      ),
    );
  }
}

/// Product card (board 18-02): photo, name + Draft tag, category, stock
/// badge, price + struck MRP, "Visible to buyers" switch, [Edit] + [⋯].
/// Long press selects; while selecting a tap toggles and a check shows.
class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.selecting,
    required this.selected,
    required this.onSelect,
    required this.onLive,
    required this.onStock,
    required this.onEdit,
    required this.onDelete,
  });

  final ProductModel product;
  final bool selecting;
  final bool selected;
  final VoidCallback onSelect;
  final ValueChanged<bool> onLive;
  final VoidCallback onStock;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final text = context.text;
    final p = product;
    final original = p.originalPrice;
    final visible = p.isActive && !p.isDraft;

    final summary = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (selecting) ...[
        Padding(
          padding: const EdgeInsets.only(top: SellerSpace.s4),
          child: Icon(selected ? SellerIcons.success : SellerIcons.unselected, color: selected ? c.primary : c.controlBorder),
        ),
        const SizedBox(width: SellerSpace.s8),
      ],
      SellerImage(url: p.primaryImage, size: SellerSize.thumbXl),
      const SizedBox(width: SellerSpace.s12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(p.name, style: text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis)),
            if (p.isDraft) ...[const SizedBox(width: SellerSpace.s8), SellerTag(label: l10n.draftBadge.toUpperCase())],
          ]),
          if ((p.categoryName ?? '').isNotEmpty) Text(p.categoryName!, style: text.bodyMedium),
          const SizedBox(height: SellerSpace.s4),
          productStockBadge(l10n, p),
          const SizedBox(height: SellerSpace.s4),
          Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: SellerSpace.s8, children: [
            Text(SellerFormat.money(p.salePrice), style: text.titleLarge!.tabular),
            if (original != null && original > p.salePrice)
              Text(
                l10n.productMrp(SellerFormat.money(original)),
                style: text.bodyMedium!.copyWith(decoration: TextDecoration.lineThrough).tabular,
              ),
          ]),
        ]),
      ),
    ]);

    if (selecting) {
      return SellerCard(
        onTap: onSelect,
        onLongPress: onSelect,
        selected: selected,
        semanticLabel: '${p.name}, ${selected ? l10n.dsSelected : l10n.dsNotSelected}',
        child: summary,
      );
    }

    return SellerCard(
      onLongPress: onSelect,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        summary,
        const SizedBox(height: SellerSpace.s8),
        SellerSwitchRow(title: l10n.productLive, subtitle: visible ? null : l10n.productHidden, value: visible, onChanged: onLive),
        const SizedBox(height: SellerSpace.s8),
        Row(children: [
          Expanded(
            child: SellerButton.secondary(
              label: l10n.productEdit,
              icon: SellerIcons.edit,
              compact: true,
              semanticLabel: l10n.productEditNamed(p.name),
              onPressed: onEdit,
            ),
          ),
          const SizedBox(width: SellerSpace.s8),
          MenuAnchor(
            builder: (context, controller, _) => SellerIconButton(
              icon: SellerIcons.moreHorizontal,
              label: l10n.productMoreActions(p.name),
              bordered: true,
              onPressed: () => controller.isOpen ? controller.close() : controller.open(),
            ),
            menuChildren: [
              MenuItemButton(leadingIcon: const Icon(SellerIcons.stock), onPressed: onStock, child: Text(l10n.productStock)),
              MenuItemButton(
                leadingIcon: Icon(SellerIcons.delete, color: c.danger),
                onPressed: onDelete,
                child: Text(l10n.productDelete, style: text.bodyLarge!.copyWith(color: c.danger)),
              ),
            ],
          ),
        ]),
      ]),
    );
  }
}

/// "Update stock" sheet (board 18-03): product summary, units field, Save.
/// Saving happens here, so a failure keeps the sheet and what was typed.
class _StockSheet extends StatefulWidget {
  const _StockSheet({required this.product, required this.onSave});
  final ProductModel product;
  final Future<bool> Function(int value) onSave;

  @override
  State<_StockSheet> createState() => _StockSheetState();
}

class _StockSheetState extends State<_StockSheet> {
  late final _value = TextEditingController(text: '${widget.product.stock}');
  bool _invalid = false;
  bool _saving = false;
  bool _failed = false;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final n = int.tryParse(_value.text.trim());
    if (n == null || n < 0) {
      setState(() => _invalid = true);
      return;
    }
    setState(() {
      _invalid = false;
      _failed = false;
      _saving = true;
    });
    final ok = await widget.onSave(n);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = context.text;
    final p = widget.product;
    return SellerSheetFrame(
      title: l10n.productStockTitle,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SellerCard(
          tone: SellerCardTone.sunken,
          child: Row(children: [
            SellerImage(url: p.primaryImage, size: SellerSize.thumbMd),
            const SizedBox(width: SellerSpace.s12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: text.titleSmall),
                Text(SellerFormat.money(p.salePrice), style: text.bodyMedium!.tabular),
                Text(l10n.productCurrentStock(SellerFormat.count(p.stock)), style: text.bodyMedium),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: SellerSpace.s16),
        SellerTextField(
          fieldKey: const ValueKey('stockValue'),
          label: l10n.productStockLabel,
          controller: _value,
          autofocus: true,
          tabular: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          errorText: _invalid ? l10n.counterQtyInvalid : null,
          onSubmitted: (_) => _save(),
        ),
        if (_failed) ...[
          const SizedBox(height: SellerSpace.s12),
          SellerBanner(tone: SellerTone.danger, message: l10n.productStockSaveFailed),
        ],
      ]),
      footer: SellerButton(label: l10n.accountSave, expand: true, loading: _saving, loadingLabel: l10n.saving, onPressed: _save),
    );
  }
}
