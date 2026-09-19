import 'package:flutter/material.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../home/dashboard_screen.dart';
import '../orders/orders_screen.dart';
import '../wallet/wallet_screen.dart';
import '../profile/profile_screen.dart';

/// Controller interface allowing child screens within [EmployeeShellScreen]
/// to switch tabs programmatically (e.g. from Dashboard -> Orders or Wallet).
abstract class EmployeeShellController {
  void switchTab(int index);

  static EmployeeShellController? of(BuildContext context) {
    final _ShellScope? scope =
        context.dependOnInheritedWidgetOfExactType<_ShellScope>();
    return scope?.controller;
  }
}

class _ShellScope extends InheritedWidget {
  final EmployeeShellController controller;
  final int currentIndex;

  const _ShellScope({
    required this.controller,
    required this.currentIndex,
    required super.child,
  });

  @override
  bool updateShouldNotify(_ShellScope oldWidget) =>
      currentIndex != oldWidget.currentIndex;
}

/// The persistent 4-tab authenticated root shell for approved Sales Associates.
///
/// Houses:
/// 0: Home / Sales Dashboard ([DashboardScreen])
/// 1: Attributed Orders ([OrdersScreen])
/// 2: Commission Wallet & Payouts ([WalletScreen])
/// 3: Associate Profile & Support ([ProfileScreen])
class EmployeeShellScreen extends StatefulWidget {
  final int initialTab;

  const EmployeeShellScreen({
    super.key,
    this.initialTab = 0,
  });

  @override
  State<EmployeeShellScreen> createState() => _EmployeeShellScreenState();
}

class _EmployeeShellScreenState extends State<EmployeeShellScreen>
    implements EmployeeShellController {
  late int _currentIndex;

  static const List<Widget> _tabs = [
    DashboardScreen(),
    OrdersScreen(),
    WalletScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab.clamp(0, _tabs.length - 1);
  }

  @override
  void switchTab(int index) {
    if (index >= 0 && index < _tabs.length && index != _currentIndex) {
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.saTokens;
    return _ShellScope(
      controller: this,
      currentIndex: _currentIndex,
      child: Scaffold(
        backgroundColor: tokens.pageBackground,
        body: IndexedStack(
          index: _currentIndex,
          children: _tabs,
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: tokens.divider, width: 1),
            ),
          ),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: switchTab,
            backgroundColor: tokens.surface,
            indicatorColor: Colors.transparent,
            elevation: 0,
            height: MediaQuery.textScalerOf(context).scale(1.0) > 1.2 ? 72 : 64,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              NavigationDestination(
                icon: Icon(Icons.home_outlined, color: tokens.textSecondary),
                selectedIcon: Icon(Icons.home, color: tokens.primary),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(SaIcons.shoppingBag, color: tokens.textSecondary),
                selectedIcon: Icon(SaIcons.shoppingBag, color: tokens.primary),
                label: 'Orders',
              ),
              NavigationDestination(
                icon: Icon(SaIcons.wallet, color: tokens.textSecondary),
                selectedIcon: Icon(SaIcons.wallet, color: tokens.primary),
                label: 'Wallet',
              ),
              NavigationDestination(
                icon: Icon(SaIcons.user, color: tokens.textSecondary),
                selectedIcon: Icon(SaIcons.user, color: tokens.primary),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
