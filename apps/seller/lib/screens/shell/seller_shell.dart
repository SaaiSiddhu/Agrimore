import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/seller_auth_provider.dart';
import '../../providers/seller_order_provider.dart';
import '../../providers/seller_product_provider.dart';
import '../home/dashboard_screen.dart';
import '../orders/seller_orders_screen.dart';
import '../payments/payments_screen.dart';
import '../products/seller_products_screen.dart';
import '../profile/seller_profile_screen.dart';

/// Destinations, in bar order (ADR §8 IA: Home · Orders · Catalogue ·
/// Payments · Account).
enum SellerTab { home, orders, catalogue, payments, account }

/// `WsNavShell` for the seller app (ADR §7/§8, SELLER-UI-1a): a bottom
/// navigation bar on phones, a navigation rail from the expanded breakpoint.
/// Each destination keeps its state (IndexedStack).
class SellerShell extends StatefulWidget {
  const SellerShell({super.key, this.screens});

  /// Replaces the destination bodies in tests (same order as [SellerTab]).
  final List<Widget>? screens;

  /// Switches destination from anywhere inside the shell (e.g. Home's
  /// action queue). No-op outside a shell.
  static void goToTab(BuildContext context, SellerTab tab) {
    context.findAncestorStateOfType<_SellerShellState>()?._select(tab.index);
  }

  @override
  State<SellerShell> createState() => _SellerShellState();
}

class _SellerShellState extends State<SellerShell> {
  int _currentIndex = 0;

  static const List<Widget> _defaultScreens = [
    DashboardScreen(),
    SellerOrdersScreen(),
    SellerProductsScreen(),
    PaymentsScreen(),
    SellerProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.screens == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadSellerData());
    }
  }

  void _select(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
  }

  void _loadSellerData() {
    if (!mounted) return;
    final uid = context.read<SellerAuthProvider>().currentUser?.uid;
    if (uid == null) return;
    context.read<SellerProductProvider>().loadSellerProducts(uid);
    context.read<SellerOrderProvider>().loadSellerOrders(uid);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pending = context.watch<SellerOrderProvider>().pendingOrders;
    final screens = widget.screens ?? _defaultScreens;

    Widget ordersIcon(IconData icon) => Badge(
          isLabelVisible: pending > 0,
          label: Text(pending > 99 ? '99+' : AgFormat.count(pending)),
          child: Icon(icon),
        );

    final labels = [l10n.navHome, l10n.navOrders, l10n.navCatalogue, l10n.paymentsTitle, l10n.navAccount];
    const icons = [AgIcons.home, AgIcons.orders, AgIcons.inventory, AgIcons.wallet, AgIcons.store];
    String semantic(int i) => i == SellerTab.orders.index && pending > 0 ? l10n.navOrdersPending(pending) : labels[i];

    final body = IndexedStack(index: _currentIndex, children: screens);
    final wide = wsLayoutFor(MediaQuery.sizeOf(context).width).index >= WsLayout.expanded.index;

    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: _currentIndex,
            onDestinationSelected: _select,
            labelType: NavigationRailLabelType.all,
            destinations: [
              for (var i = 0; i < labels.length; i++)
                NavigationRailDestination(
                  icon: Semantics(
                    label: semantic(i),
                    excludeSemantics: true,
                    child: i == SellerTab.orders.index ? ordersIcon(icons[i]) : Icon(icons[i]),
                  ),
                  label: Text(labels[i]),
                ),
            ],
          ),
          const VerticalDivider(width: WsSize.hairline),
          Expanded(child: body),
        ]),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _select,
        destinations: [
          for (var i = 0; i < labels.length; i++)
            NavigationDestination(
              icon: i == SellerTab.orders.index ? ordersIcon(icons[i]) : Icon(icons[i]),
              label: labels[i],
              tooltip: semantic(i),
            ),
        ],
      ),
    );
  }
}
