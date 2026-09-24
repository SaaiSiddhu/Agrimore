import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/seller_auth_provider.dart';
import '../../providers/seller_order_provider.dart';
import '../../providers/seller_product_provider.dart';
import '../home/dashboard_screen.dart';
import '../orders/order_stage.dart';
import '../orders/seller_orders_screen.dart';
import '../payments/payments_screen.dart';
import '../products/seller_products_screen.dart';
import '../profile/seller_profile_screen.dart';

/// Destinations, in bar order (ADR §8 IA: Home · Orders · Catalogue ·
/// Payments · Account).
enum SellerTab { home, orders, catalogue, payments, account }

/// The seller shell (ADR §7/§8, board 04): a bottom navigation bar on phones,
/// a navigation rail from 600 dp.
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
    // Orders that need the seller to act (accept, pack or mark ready).
    final pending = context.watch<SellerOrderProvider>().allOrders.where(needsSellerAction).length;
    final screens = widget.screens ?? _defaultScreens;

    final items = [
      SellerNavItem(icon: SellerIcons.home, label: l10n.navHome),
      SellerNavItem(
        icon: SellerIcons.orders,
        label: l10n.navOrders,
        badgeCount: pending,
        semanticLabel: pending > 0 ? l10n.navOrdersPending(pending) : null,
      ),
      SellerNavItem(icon: SellerIcons.catalogue, label: l10n.navCatalogue),
      SellerNavItem(icon: SellerIcons.payments, label: l10n.paymentsTitle),
      SellerNavItem(icon: SellerIcons.account, label: l10n.navAccount),
    ];

    final body = IndexedStack(index: _currentIndex, children: screens);
    // Android back on another root returns to Home before leaving the app.
    final guarded = PopScope<Object?>(
      canPop: _currentIndex == SellerTab.home.index,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(SellerTab.home.index);
      },
      child: body,
    );

    // Rail from 600 dp (board 04), bottom bar below.
    if (context.layout != SellerLayout.compact) {
      return Scaffold(
        body: Row(children: [
          SellerNavRail(
            items: items,
            selectedIndex: _currentIndex,
            onSelected: _select,
            leading: const SellerLeafMark(),
          ),
          Expanded(child: guarded),
        ]),
      );
    }

    return Scaffold(
      body: guarded,
      bottomNavigationBar: SellerNavBar(items: items, selectedIndex: _currentIndex, onSelected: _select),
    );
  }
}
