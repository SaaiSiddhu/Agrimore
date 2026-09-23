import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/rfq_provider.dart';
import '../../providers/seller_order_provider.dart';
import '../../providers/seller_product_provider.dart';
import '../home/add_product_screen.dart';
import '../orders/seller_order_detail_screen.dart';
import '../rfq/seller_rfq_detail_screen.dart';
import '../rfq/widgets/quote_copy.dart';
import 'search_rules.dart';

/// H-03 Global search (ADR §10.2, SELLER-HOME-1b): orders, products and
/// quotes in one place; an exact order number opens that order.
class SellerSearchScreen extends StatefulWidget {
  const SellerSearchScreen({super.key});

  @override
  State<SellerSearchScreen> createState() => _SellerSearchScreenState();
}

class _SellerSearchScreenState extends State<SellerSearchScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _openOrder(OrderModel o) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SellerOrderDetailScreen(order: o)));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final text = context.wsText;
    final results = searchSeller(
      _query.text,
      orders: context.watch<SellerOrderProvider>().allOrders,
      products: context.watch<SellerProductProvider>().allProducts,
      quotes: context.watch<RfqProvider>().myRfqs,
    );
    final tooShort = _query.text.trim().length < kSearchMinChars;

    Widget header(String title, int n) => Padding(
          padding: const EdgeInsets.fromLTRB(WsSpace.page, WsSpace.s16, WsSpace.page, WsSpace.s4),
          child: Text(l10n.searchGroup(title, n), style: text.labelLarge!.copyWith(color: t.textSecondary)),
        );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.back,
          icon: const Icon(AgIcons.arrowLeft),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        title: TextField(
          controller: _query,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) {
            final exact = results.exactOrder;
            if (exact != null) _openOrder(exact);
          },
          decoration: InputDecoration(
            hintText: l10n.searchHint,
            border: InputBorder.none,
            suffixIcon: _query.text.isEmpty
                ? null
                : IconButton(
                    tooltip: l10n.searchClear,
                    icon: const Icon(AgIcons.close),
                    onPressed: () => setState(_query.clear),
                  ),
          ),
        ),
      ),
      body: tooShort
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(WsSpace.s32),
                child: Text(l10n.searchPrompt, style: text.bodyMedium, textAlign: TextAlign.center),
              ),
            )
          : results.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(WsSpace.s32),
                    child: Text(l10n.searchNoResults(_query.text.trim()),
                        style: text.bodyMedium, textAlign: TextAlign.center),
                  ),
                )
              : ListView(children: [
                  if (results.exactOrder != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(WsSpace.page, WsSpace.s12, WsSpace.page, 0),
                      child: FilledButton.icon(
                        onPressed: () => _openOrder(results.exactOrder!),
                        icon: const Icon(AgIcons.orders),
                        label: Text(l10n.searchOpenOrder(results.exactOrder!.orderNumber)),
                      ),
                    ),
                  if (results.orders.isNotEmpty) ...[
                    header(l10n.kpiOrders, results.orders.length),
                    for (final o in results.orders)
                      ListTile(
                        onTap: () => _openOrder(o),
                        leading: const Icon(AgIcons.orders),
                        title: Text(l10n.paymentsForOrder(o.orderNumber), style: text.titleSmall),
                        subtitle: Text(l10n.searchOrderLine(o.deliveryAddress.name, AgFormat.date(o.createdAt)), style: text.bodySmall),
                        trailing: Text(AgFormat.rupees(o.total),
                            style: text.bodyMedium!.copyWith(fontFeatures: WsType.tabularFigures)),
                      ),
                  ],
                  if (results.products.isNotEmpty) ...[
                    header(l10n.searchProducts, results.products.length),
                    for (final p in results.products)
                      ListTile(
                        onTap: () => Navigator.of(context)
                            .push(MaterialPageRoute<void>(builder: (_) => AddProductScreen(existingProduct: p))),
                        leading: const Icon(AgIcons.product),
                        title: Text(p.name, style: text.titleSmall),
                        subtitle: Text(l10n.searchStock(AgFormat.count(p.stock)), style: text.bodySmall),
                        trailing: Text(AgFormat.rupees(p.salePrice),
                            style: text.bodyMedium!.copyWith(fontFeatures: WsType.tabularFigures)),
                      ),
                  ],
                  if (results.quotes.isNotEmpty) ...[
                    header(l10n.quotesTitle, results.quotes.length),
                    for (final r in results.quotes)
                      ListTile(
                        onTap: () => Navigator.of(context)
                            .push(MaterialPageRoute<void>(builder: (_) => SellerRfqDetailScreen(rfqId: r.id))),
                        leading: const Icon(AgIcons.quote),
                        title: Text(l10n.productOf(r), style: text.titleSmall),
                        subtitle: Text(l10n.buyerOf(r), style: text.bodySmall),
                      ),
                  ],
                  const SizedBox(height: WsSpace.s24),
                ]),
    );
  }
}
