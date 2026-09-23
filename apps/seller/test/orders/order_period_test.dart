import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:seller/l10n/app_localizations.dart';
import 'package:seller/providers/seller_auth_provider.dart';
import 'package:seller/providers/seller_order_provider.dart';
import 'package:seller/screens/orders/order_stage.dart';
import 'package:seller/screens/orders/seller_orders_screen.dart';

/// SELLER-POLISH-1 (gap 21): date-period and B2B filters on the order list.
OrderModel _o(String id, DateTime at, {String mode = 'B2C'}) => OrderModel.fromMap({
      'userId': 'u',
      'sellerId': 's',
      'orderNumber': 'AGM-$id',
      'items': [
        {'productId': 'p', 'productName': 'Rice 5kg', 'productImage': '', 'price': 100, 'quantity': 2, 'userId': 'u', 'sellerId': 's'},
      ],
      'deliveryAddress': {'name': 'Priya', 'phone': '9999999999'},
      'subtotal': 200,
      'total': 220,
      'deliveryCharge': 20,
      'orderStatus': 'pending',
      'paymentMethod': 'cod',
      'orderMode': mode,
      'createdAt': Timestamp.fromDate(at),
    }, id);

void main() {
  // 2026-09-23 10:00 IST = 04:30 UTC.
  final now = DateTime.utc(2026, 9, 23, 4, 30);

  test('today is the Indian calendar day', () {
    // 00:10 IST today = 18:40 UTC yesterday → today.
    expect(inPeriod(_o('a', DateTime.utc(2026, 9, 22, 18, 40)), OrderPeriod.today, now), isTrue);
    // 23:50 IST yesterday = 18:20 UTC yesterday → not today.
    expect(inPeriod(_o('b', DateTime.utc(2026, 9, 22, 18, 20)), OrderPeriod.today, now), isFalse);
  });

  test('7 / 30 day windows and all', () {
    final d10 = _o('c', now.subtract(const Duration(days: 10)));
    expect(inPeriod(d10, OrderPeriod.days7, now), isFalse);
    expect(inPeriod(d10, OrderPeriod.days30, now), isTrue);
    expect(inPeriod(_o('d', now.subtract(const Duration(days: 400))), OrderPeriod.all, now), isTrue);
  });

  test('B2B is the order mode, case-insensitive', () {
    expect(isB2bOrder(_o('e', now, mode: 'B2B')), isTrue);
    expect(isB2bOrder(_o('f', now, mode: 'b2b')), isTrue);
    expect(isB2bOrder(_o('g', now)), isFalse);
  });

  testWidgets('B2B chip and 7-day chip narrow the list', (tester) async {
    final real = DateTime.now();
    final orders = [
      _o('RETAIL1', real.subtract(const Duration(hours: 1))),
      _o('BULK1', real.subtract(const Duration(hours: 2)), mode: 'B2B'),
      _o('OLD1', real.subtract(const Duration(days: 20))),
    ];
    late AppLocalizations l10n;
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<SellerAuthProvider>(create: (_) => SellerAuthProvider.preview(access: SellerAccess.approved)),
        ChangeNotifierProvider<SellerOrderProvider>(create: (_) => SellerOrderProvider.preview(orders)),
      ],
      child: MaterialApp(
        theme: WorkspaceTheme.build(WorkspaceBrand.seller, Brightness.light),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) {
          l10n = AppLocalizations.of(context);
          return const SellerOrdersScreen();
        }),
      ),
    ));
    await tester.pump();
    expect(find.textContaining('OLD1'), findsOneWidget);

    await tester.tap(find.text(l10n.period7d));
    await tester.pump();
    expect(find.textContaining('OLD1'), findsNothing);
    expect(find.textContaining('RETAIL1'), findsOneWidget);

    await tester.tap(find.text(l10n.ordersB2bOnly));
    await tester.pump();
    expect(find.textContaining('RETAIL1'), findsNothing);
    expect(find.textContaining('BULK1'), findsOneWidget);
  });
}
