import 'package:agrimore_core/agrimore_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design_system/design_system.dart';
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
    final text = context.text;
    final results = searchSeller(
      _query.text,
      orders: context.watch<SellerOrderProvider>().allOrders,
      products: context.watch<SellerProductProvider>().allProducts,
      quotes: context.watch<RfqProvider>().myRfqs,
    );
    final tooShort = _query.text.trim().length < kSearchMinChars;

    Widget group(String title, int n, List<Widget> rows) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.only(top: SellerSpace.s8, bottom: SellerSpace.s8, left: SellerSpace.s4),
            child: Semantics(header: true, child: Text(l10n.searchGroup(title, n), style: text.labelLarge!.copyWith(color: context.colors.textSecondary))),
          ),
          SellerMenuGroup(children: rows),
        ]);

    Widget body;
    if (tooShort) {
      body = SellerEmptyState(icon: SellerIcons.search, title: l10n.searchPrompt, compact: true);
    } else if (results.isEmpty) {
      body = SellerEmptyState(
        icon: SellerIcons.search,
        title: l10n.searchNoResults(_query.text.trim()),
        actionLabel: l10n.searchClear,
        onAction: () => setState(_query.clear),
        compact: true,
      );
    } else {
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (results.exactOrder != null)
          SellerButton.secondary(
            label: l10n.searchOpenOrder(results.exactOrder!.orderNumber),
            icon: SellerIcons.externalLink,
            onPressed: () => _openOrder(results.exactOrder!),
          ),
        if (results.orders.isNotEmpty)
          group(l10n.kpiOrders, results.orders.length, [
            for (final o in results.orders)
              SellerListRow(
                icon: SellerIcons.orders,
                title: l10n.paymentsForOrder(o.orderNumber),
                subtitle: l10n.searchOrderLine(o.deliveryAddress.name, SellerFormat.date(o.createdAt)),
                value: SellerFormat.money(o.total),
                onTap: () => _openOrder(o),
              ),
          ]),
        if (results.products.isNotEmpty)
          group(l10n.searchProducts, results.products.length, [
            for (final p in results.products)
              SellerListRow(
                leading: SellerImage(url: p.primaryImage, size: SellerSize.thumbSm),
                title: p.name,
                subtitle: l10n.searchStock(SellerFormat.count(p.stock)),
                value: SellerFormat.money(p.salePrice),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AddProductScreen(existingProduct: p))),
              ),
          ]),
        if (results.quotes.isNotEmpty)
          group(l10n.quotesTitle, results.quotes.length, [
            for (final r in results.quotes)
              SellerListRow(
                icon: SellerIcons.quote,
                title: l10n.productOf(r),
                subtitle: l10n.buyerOf(r),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SellerRfqDetailScreen(rfqId: r.id))),
              ),
          ]),
      ]);
    }

    return Scaffold(
      appBar: SellerAppBar.detail(context, title: l10n.homeSearch),
      body: SellerPage(
        gap: SellerSpace.s12,
        children: [
          SellerSearchField(
            controller: _query,
            hint: l10n.searchHint,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              final exact = results.exactOrder;
              if (exact != null) _openOrder(exact);
            },
          ),
          body,
        ],
      ),
    );
  }
}
