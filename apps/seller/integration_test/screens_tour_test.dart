import 'package:agrimore_core/agrimore_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:seller/providers/seller_application_provider.dart';
import 'package:seller/providers/seller_settings_provider.dart';
import 'package:seller/screens/account/help_screen.dart';
import 'package:seller/screens/account/settings_screen.dart';
import 'package:seller/screens/auth/application_status_screen.dart';
import 'package:seller/screens/home/add_product_screen.dart';
import 'package:seller/screens/home/dashboard_screen.dart';
import 'package:seller/screens/home/home_stats.dart';
import 'package:seller/screens/insights/insights_screen.dart';
import 'package:seller/screens/onboarding/application_screen.dart';
import 'package:seller/screens/orders/seller_order_detail_screen.dart';
import 'package:seller/screens/orders/seller_orders_screen.dart';
import 'package:seller/screens/payments/payments_screen.dart';
import 'package:seller/screens/products/seller_products_screen.dart';
import 'package:seller/screens/profile/seller_profile_screen.dart';
import 'package:seller/screens/rfq/seller_rfq_detail_screen.dart';
import 'package:seller/screens/rfq/seller_rfq_inbox_screen.dart';
import 'package:seller/screens/shell/seller_shell.dart';

import '../test/support/seller_fixtures.dart';

/// On-device visual tour (Android emulator): every redesigned screen with
/// illustrative TEST data from the fixtures — no Firebase, no network, no
/// production data. Screenshots land in evidence/android/ via the driver.
///
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/screens_tour_test.dart -d emulator-5554
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.now().toUtc();

  final keys = istDayKeys(now, 14);
  final stats = {
    for (var i = 0; i < keys.length; i++)
      keys[i]: DayStat(day: keys[i], gross: 1200.0 + (i * 137) % 900, orders: 2 + i % 3, b2bGross: i.isEven ? 400 : 0),
  };
  final orders = [
    fixtureOrder('1042', 'pending', method: 'razorpay', quantity: 5, price: 116),
    fixtureOrder('1041', 'processing', name: 'Ramesh Kumar', product: 'Green chillies', quantity: 1, price: 320),
    fixtureOrder('1040', 'delivered', name: 'Green Valley Foods', quantity: 3, price: 320, method: 'razorpay'),
  ];
  final products = [
    fixtureProduct('a', name: 'Fresh tomatoes', stock: 25, draft: true, active: false),
    fixtureProduct('b', name: 'Green chillies', stock: 3, price: 120),
    fixtureProduct('c', name: 'Rice', stock: 0, price: 60),
  ];
  final quote = RfqModel(
    id: 'q1',
    buyerId: 'b',
    sellerId: 's',
    productId: 'p',
    status: RfqStatus.negotiating,
    awaitingResponseFrom: RfqRole.seller,
    lastOffer: RfqOffer(price: 52, quantity: 20, by: RfqRole.buyer, expiresAt: now.add(const Duration(days: 3))),
    createdAt: now.subtract(const Duration(days: 1)),
    updatedAt: now,
    history: [RfqHistoryEntry(actor: RfqRole.buyer, action: 'offer', price: 52, quantity: 20, at: now.subtract(const Duration(hours: 5)))],
    productName: 'Fresh tomatoes',
    listedB2bPrice: 56,
    listedB2bMoq: 10,
    buyerBusinessName: 'Green Valley Foods',
  );
  final seller = {'shopName': 'Kaveri Fresh', 'city': 'Chennai', 'state': 'Tamil Nadu', 'rating': 4.5, 'reviewCount': 20};
  final payouts = [
    PayoutEntry(id: 'a', orderNumber: '1042', gross: 580, commission: 29, net: 551, status: 'pending', createdAt: now.subtract(const Duration(days: 1))),
    PayoutEntry(id: 'b', orderNumber: '1041', gross: 320, commission: 16, net: 304, status: 'paid', createdAt: now.subtract(const Duration(days: 2)), paidAt: now),
  ];

  var converted = false;

  Future<void> shot(WidgetTester tester, String name, Widget screen, {Brightness b = Brightness.light, double scale = 1}) async {
    await pumpSellerApp(
      tester,
      screen,
      orders: orders,
      products: products,
      quotes: [quote],
      user: fixtureSeller(),
      brightness: b,
      textScale: scale,
      deviceView: true,
    );
    await tester.pump(const Duration(milliseconds: 600));
    if (!converted) {
      await binding.convertFlutterSurfaceToImage();
      converted = true;
    }
    await tester.pump();
    await binding.takeScreenshot(name);
  }

  testWidgets('seller redesign tour', (tester) async {
    Future<void> go(String name, Widget screen, {Brightness b = Brightness.light, double scale = 1}) =>
        shot(tester, name, screen, b: b, scale: scale);

    Widget shell(Widget body) => SellerShell(screens: [body, body, body, body, body]);
    await go('01_home_light', shell(DashboardScreen(stats: stats, pendingPayout: 551, rating: 4.5, reviewCount: 20)));
    await go('02_home_dark', shell(DashboardScreen(stats: stats, pendingPayout: 551, rating: 4.5, reviewCount: 20)), b: Brightness.dark);
    await go('03_home_text200', DashboardScreen(stats: stats, pendingPayout: 551), scale: 2);
    await go('04_orders_light', const SellerOrdersScreen());
    await go('05_orders_dark', const SellerOrdersScreen(), b: Brightness.dark);
    await go('06_order_detail', SellerOrderDetailScreen(order: orders.first));
    await go('07_catalogue', const SellerProductsScreen());
    await go('08_product_editor', AddProductScreen(existingProduct: products[1]));
    await go('09_payments', PaymentsScreen(entries: payouts, payoutDetails: const {'payoutMethod': 'bank', 'bankName': 'Example Bank', 'accountNumber': '123456784821'}));
    await go('10_quotes_inbox', SellerRfqInboxScreen(now: now));
    await go('11_quote_detail', SellerRfqDetailScreen(rfqId: 'q1', now: now));
    await go('12_insights', InsightsScreen(stats: stats, now: now));
    await go('13_account', SellerProfileScreen(seller: seller, payout: const PayoutView(available: true)));
    await go('14_account_dark', SellerProfileScreen(seller: seller, payout: const PayoutView(available: true)), b: Brightness.dark);
    await go('15_settings', ChangeNotifierProvider(create: (_) => SellerSettingsProvider(), child: const SellerSettingsScreen(versionOverride: '1.0.0 (100)')));
    await go('16_help', const HelpScreen());
    await go('17_application_step1', ApplicationScreen(provider: SellerApplicationProvider.preview(data: const {'userId': 'u1', 'status': 'draft'}, uid: 'u1')));
    await go('18_application_status', const ApplicationStatusScreen());
  });
}
