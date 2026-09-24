import 'package:agrimore_core/agrimore_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:seller/design_system/design_system.dart';
import 'package:seller/l10n/app_localizations.dart';
import 'package:seller/providers/seller_auth_provider.dart';
import 'package:seller/providers/seller_order_provider.dart';
import 'package:seller/screens/orders/order_stage.dart';
import 'package:seller/screens/orders/seller_order_detail_screen.dart';
import 'package:seller/screens/orders/seller_orders_screen.dart';

/// SELLER-UI-1b: stages follow the server state machine (confirmed =
/// accepted, to pack); the list filters and searches; the detail offers
/// exactly the next server-allowed step.
OrderModel _o(String id, String status, {String name = 'Priya', String method = 'cod'}) => OrderModel.fromMap({
      'userId': 'u',
      'sellerId': 's',
      'orderNumber': 'AGM-$id',
      'items': [
        {'productId': 'p', 'productName': 'Rice 5kg', 'productImage': '', 'price': 100, 'quantity': 2, 'userId': 'u', 'sellerId': 's'},
      ],
      'deliveryAddress': {'name': name, 'phone': '9999999999'},
      'subtotal': 200,
      'total': 220,
      'deliveryCharge': 20,
      'orderStatus': status,
      'paymentMethod': method,
    }, id);

Future<AppLocalizations> _pump(WidgetTester tester, Widget child, List<OrderModel> orders) async {
  late AppLocalizations l10n;
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<SellerAuthProvider>(create: (_) => SellerAuthProvider.preview(access: SellerAccess.approved)),
      ChangeNotifierProvider<SellerOrderProvider>(create: (_) => SellerOrderProvider.preview(orders)),
    ],
    child: MaterialApp(
      theme: SellerTheme.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) {
        l10n = AppLocalizations.of(context);
        return child;
      }),
    ),
  ));
  await tester.pump();
  return l10n;
}

void main() {
  group('order stages (sellerTransitionOrder.ts)', () {
    test('confirmed is accepted-to-pack, not to-accept', () {
      expect(orderStageOf('pending'), OrderStage.toAccept);
      expect(orderStageOf('confirmed'), OrderStage.toPack);
      expect(orderStageOf('processing'), OrderStage.packing);
      expect(orderStageOf('ready_for_pickup'), OrderStage.ready);
      expect(orderStageOf('Delivered'), OrderStage.delivered);
      expect(orderStageOf('rejected'), OrderStage.cancelled);
    });

    test('next action matches the server transitions', () {
      expect(nextSellerAction(OrderStage.toAccept), 'accept');
      expect(nextSellerAction(OrderStage.toPack), 'pack');
      expect(nextSellerAction(OrderStage.packing), 'ready');
      expect(nextSellerAction(OrderStage.ready), isNull);
      expect(nextSellerAction(OrderStage.delivered), isNull);
    });

    test('search covers number, customer and items', () {
      final o = _o('1', 'pending');
      expect(orderMatches(o, '#agm-1'), isTrue);
      expect(orderMatches(o, 'priya'), isTrue);
      expect(orderMatches(o, 'rice'), isTrue);
      expect(orderMatches(o, 'dal'), isFalse);
    });
  });

  testWidgets('list: stage chips with counts, filter and search', (tester) async {
    final l10n = await _pump(tester, const SellerOrdersScreen(), [
      _o('1', 'pending'),
      _o('2', 'confirmed', name: 'Ravi'),
      _o('3', 'delivered'),
    ]);
    Finder chip(String label) => find.widgetWithText(SellerChip, label);
    expect(tester.widget<SellerChip>(chip(l10n.stageToAccept)).count, 1);
    expect(tester.widget<SellerChip>(chip(l10n.stageToPack)).count, 1);
    expect(find.text('#AGM-3'), findsOneWidget);
    await tester.tap(chip(l10n.stageToPack));
    await tester.pump();
    expect(find.text('#AGM-2'), findsOneWidget);
    expect(find.text('#AGM-1'), findsNothing);
    await tester.tap(chip(l10n.filterAll));
    await tester.enterText(find.byType(TextField), 'ravi');
    await tester.pump();
    expect(find.text('#AGM-2'), findsOneWidget);
    expect(find.text('#AGM-3'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail: pending offers accept + reject', (tester) async {
    final l10n = await _pump(tester, SellerOrderDetailScreen(order: _o('1', 'pending')), const []);
    expect(find.text(l10n.orderAccept), findsOneWidget);
    expect(find.text(l10n.orderReject), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail: accepted (confirmed) offers start packing + cancel', (tester) async {
    final l10n = await _pump(tester, SellerOrderDetailScreen(order: _o('2', 'confirmed', method: 'razorpay')), const []);
    expect(find.text(l10n.orderStartPacking), findsOneWidget);
    expect(find.text(l10n.orderCancel), findsOneWidget);
    expect(find.text(l10n.orderAccept), findsNothing);
    expect(find.text(l10n.ordersPrepaid), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail: delivered has no actions', (tester) async {
    final l10n = await _pump(tester, SellerOrderDetailScreen(order: _o('3', 'delivered')), const []);
    expect(find.text(l10n.orderAccept), findsNothing);
    expect(find.text(l10n.orderMarkReady), findsNothing);
    expect(find.text(l10n.orderCancel), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
