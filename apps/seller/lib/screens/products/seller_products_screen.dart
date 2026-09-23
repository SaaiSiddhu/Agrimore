import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/seller_auth_provider.dart';
import '../../providers/seller_product_provider.dart';
import '../home/add_product_screen.dart';
import '../posts/create_post_screen.dart';
import 'widgets/product_list_controls.dart';

/// Stock levels (SellerProductProvider.lowStockProducts uses the same line).
const int kLowStockLine = 10;

/// C-01 Catalogue (ADR §10.4, SELLER-UI-1c): search, status tabs, bulk
/// publish/hide, and per product: live toggle, stock, edit, delete.
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

  void _toggle(String id) => setState(() => _selected.contains(id) ? _selected.remove(id) : _selected.add(id));

  Future<void> _bulk(bool publish) async {
    final l10n = AppLocalizations.of(context);
    final count = _selected.length;
    setState(() => _bulkBusy = true);
    final ok = await context.read<SellerProductProvider>().bulkSetActive({..._selected}, publish);
    if (!mounted) return;
    setState(() {
      _bulkBusy = false;
      if (ok) _selected.clear();
    });
    WsToast.show(context, ok ? l10n.bulkDone(count) : l10n.bulkFailed, tone: ok ? WsToastTone.success : WsToastTone.error);
  }

  Future<void> _editStock(ProductModel p) async {
    final l10n = AppLocalizations.of(context);
    final value = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _StockSheet(product: p),
    );
    final uid = _uid;
    if (value == null || uid == null || !mounted) return;
    final ok = await context.read<SellerProductProvider>().updateStock(p.id, value, uid);
    if (mounted) {
      WsToast.show(context, ok ? l10n.productStockSaved : l10n.productActionFailed,
          tone: ok ? WsToastTone.success : WsToastTone.error);
    }
  }

  Future<void> _delete(ProductModel p) async {
    final l10n = AppLocalizations.of(context);
    final yes = await wsConfirm(
      context,
      title: l10n.productDeleteTitle,
      message: l10n.productDeleteBody(p.name),
      confirmLabel: l10n.productDelete,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    final uid = _uid;
    if (!yes || uid == null || !mounted) return;
    final ok = await context.read<SellerProductProvider>().deleteProduct(p.id, uid);
    if (mounted) {
      WsToast.show(context, ok ? l10n.productDeleted : l10n.productActionFailed,
          tone: ok ? WsToastTone.success : WsToastTone.error);
    }
  }

  Future<void> _setLive(ProductModel p, bool live) async {
    final l10n = AppLocalizations.of(context);
    final uid = _uid;
    if (uid == null) return;
    HapticFeedback.selectionClick();
    final ok = await context.read<SellerProductProvider>().toggleProductActive(p.id, live, uid);
    if (!ok && mounted) WsToast.show(context, l10n.productActionFailed, tone: WsToastTone.error);
  }

  void _push(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final text = context.wsText;
    final provider = context.watch<SellerProductProvider>();
    final products = provider.products;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l10n.navCatalogue),
        actions: [
          IconButton(tooltip: l10n.productNewPost, icon: const Icon(AgIcons.image), onPressed: () => _push(const CreatePostScreen())),
        ],
      ),
      floatingActionButton: _selected.isNotEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _push(const AddProductScreen()),
              icon: const Icon(AgIcons.add),
              label: Text(l10n.homeAddProduct),
            ),
      bottomNavigationBar: _selected.isEmpty
          ? null
          : ProductBulkBar(
              count: _selected.length,
              busy: _bulkBusy,
              onPublish: () => _bulk(true),
              onHide: () => _bulk(false),
              onClear: () => setState(_selected.clear),
            ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(WsSpace.page, WsSpace.s8, WsSpace.page, 0),
          child: TextField(
            controller: _search,
            onChanged: (v) {
              provider.setSearchQuery(v);
              setState(() {});
            },
            decoration: InputDecoration(
              prefixIcon: const Icon(AgIcons.search),
              hintText: l10n.productSearchHint,
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: l10n.searchClear,
                      icon: const Icon(AgIcons.close),
                      onPressed: () {
                        _search.clear();
                        provider.setSearchQuery('');
                        setState(() {});
                      },
                    ),
            ),
          ),
        ),
        ProductFilterBar(provider: provider),
        Expanded(
          child: provider.error != null
              ? Padding(
                  padding: const EdgeInsets.all(WsSpace.page),
                  child: SaInfoBanner(
                    variant: SaBannerVariant.error,
                    message: l10n.productsLoadFailed,
                    actionLabel: l10n.statusRefresh,
                    onAction: _reload,
                  ),
                )
              : provider.isLoading && provider.allProducts.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : products.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(WsSpace.s32),
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Icon(AgIcons.inventory, size: WsIconSize.empty, color: t.textTertiary),
                              const SizedBox(height: WsSpace.s12),
                              Text(
                                provider.allProducts.isEmpty ? l10n.productsEmpty : l10n.productsNoneMatch,
                                style: text.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                            ]),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async => _reload(),
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(WsSpace.page, 0, WsSpace.page, WsSpace.s64 + WsSpace.s32),
                            itemCount: products.length,
                            itemBuilder: (context, i) {
                              final p = products[i];
                              return ProductSelectionFrame(
                                selected: _selected.contains(p.id),
                                selecting: _selected.isNotEmpty,
                                isDraft: p.isDraft,
                                onToggle: () => _toggle(p.id),
                                child: _ProductCard(
                                  product: p,
                                  onLive: (v) => _setLive(p, v),
                                  onStock: () => _editStock(p),
                                  onEdit: () => _push(AddProductScreen(existingProduct: p)),
                                  onDelete: () => _delete(p),
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ]),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onLive, required this.onStock, required this.onEdit, required this.onDelete});
  final ProductModel product;
  final ValueChanged<bool> onLive;
  final VoidCallback onStock;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final text = context.wsText;
    final p = product;
    final (String stockLabel, Color stockColor) = p.stock == 0
        ? (l10n.productOutOfStock, t.errorFg)
        : p.stock < kLowStockLine
            ? (l10n.productLowStock(AgFormat.count(p.stock)), t.warningFg)
            : (l10n.searchStock(AgFormat.count(p.stock)), t.successFg);
    final original = p.originalPrice;
    return Card(
      margin: const EdgeInsets.only(bottom: WsSpace.s8),
      child: Padding(
        padding: const EdgeInsets.all(WsSpace.s12),
        child: Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(WsRadius.small),
              child: SizedBox.square(
                dimension: WsSize.thumbLg,
                child: p.primaryImage.isEmpty
                    ? ColoredBox(color: t.surfaceSunken, child: Icon(AgIcons.image, color: t.textTertiary))
                    : CachedNetworkImage(
                        imageUrl: p.primaryImage,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => ColoredBox(color: t.surfaceSunken),
                      ),
              ),
            ),
            const SizedBox(width: WsSpace.s12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: WsSpace.s4),
                Row(children: [
                  Text(AgFormat.rupees(p.salePrice), style: text.titleSmall!.copyWith(fontFeatures: WsType.tabularFigures)),
                  if (original != null && original > p.salePrice) ...[
                    const SizedBox(width: WsSpace.s8),
                    Text(
                      AgFormat.rupees(original),
                      style: text.bodySmall!.copyWith(color: t.textTertiary, decoration: TextDecoration.lineThrough),
                    ),
                  ],
                ]),
                const SizedBox(height: WsSpace.s4),
                Text(stockLabel, style: text.labelMedium!.copyWith(color: stockColor)),
              ]),
            ),
            Semantics(
              label: p.isActive ? l10n.productLive : l10n.productHidden,
              // Switching a draft on publishes it (the provider clears isDraft).
              child: Switch(value: p.isActive && !p.isDraft, onChanged: onLive),
            ),
          ]),
          const Divider(height: WsSpace.s16),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton.icon(onPressed: onStock, icon: const Icon(AgIcons.inventory), label: Text(l10n.productStock)),
            TextButton.icon(onPressed: onEdit, icon: const Icon(AgIcons.edit), label: Text(l10n.productEdit)),
            TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(AgIcons.delete),
              label: Text(l10n.productDelete),
              style: TextButton.styleFrom(foregroundColor: t.errorFg),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _StockSheet extends StatefulWidget {
  const _StockSheet({required this.product});
  final ProductModel product;

  @override
  State<_StockSheet> createState() => _StockSheetState();
}

class _StockSheetState extends State<_StockSheet> {
  late final _value = TextEditingController(text: '${widget.product.stock}');
  bool _invalid = false;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  void _save() {
    final n = int.tryParse(_value.text.trim());
    if (n == null || n < 0) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(n);
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
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(l10n.productStockTitle, style: text.titleMedium),
            const SizedBox(height: WsSpace.s4),
            Text(widget.product.name, style: text.bodyMedium),
            const SizedBox(height: WsSpace.s16),
            TextField(
              key: const ValueKey('stockValue'),
              controller: _value,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: l10n.productStockLabel, errorText: _invalid ? l10n.counterQtyInvalid : null),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: WsSpace.s16),
            FilledButton(onPressed: _save, child: Text(l10n.accountSave)),
          ]),
        ),
      ),
    );
  }
}
