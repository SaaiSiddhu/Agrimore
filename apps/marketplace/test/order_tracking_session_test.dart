import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_marketplace/providers/auth_provider.dart';
import 'package:agrimore_marketplace/providers/order_provider.dart';
import 'package:agrimore_marketplace/screens/user/orders/order_tracking_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'foundation_edit_profile_form_test.dart' show FormAuth;

OrderModel row(String uid, String id) => OrderModel(
    id: id,
    userId: uid,
    orderNumber: id,
    items: [],
    deliveryAddress: AddressModel.fromMap({'userId': uid}),
    subtotal: 100,
    total: 100,
    paymentMethod: 'cod',
    createdAt: DateTime.utc(2026));

class TrackingOrders extends ChangeNotifier implements OrderProvider {
  OrderModel? selection;
  List<OrderTimelineModel> timeline = [];
  final reads = <String>[];
  @override
  OrderModel? get selectedOrder => selection;
  @override
  List<OrderTimelineModel> get selectedOrderTimeline => timeline;
  @override
  bool get isLoadingTimeline => false;
  @override
  Future<void> loadOrderById(String id) async {
    reads.add(id);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<void> mount(WidgetTester tester, FormAuth auth, TrackingOrders orders,
      OrderModel order,
      {bool dark = false, double width = 600}) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<OrderProvider>.value(value: orders)
        ],
        child: MaterialApp(
            theme: ThemeData(
                brightness: dark ? Brightness.dark : Brightness.light),
            home: OrderTrackingScreen(order: order))));
    await tester.pumpAndSettle();
  }

  testWidgets('own tracking fallback and read remain available',
      (tester) async {
    final auth = FormAuth(), orders = TrackingOrders();
    await mount(tester, auth, orders, row('owner_a', 'OWN-FIXTURE'));
    expect(find.text('OWN-FIXTURE'), findsOneWidget);
    expect(orders.reads, ['OWN-FIXTURE']);
  });
  testWidgets('foreign opening order neither renders nor reads',
      (tester) async {
    final auth = FormAuth(), orders = TrackingOrders();
    await mount(tester, auth, orders, row('owner_b', 'FOREIGN-FIXTURE'));
    expect(find.text('FOREIGN-FIXTURE'), findsNothing);
    expect(orders.reads, isEmpty);
  });
  for (final next in <String?>['owner_b', null, 'owner_a']) {
    testWidgets('opening tracking expires on auth change $next',
        (tester) async {
      final auth = FormAuth(), orders = TrackingOrders();
      await mount(tester, auth, orders, row('owner_a', 'OLD-FIXTURE'));
      auth.change(next);
      orders.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.text('OLD-FIXTURE'), findsNothing);
    });
  }
  testWidgets('selected data must match route and owner', (tester) async {
    final auth = FormAuth(), orders = TrackingOrders();
    orders.selection = row('owner_b', 'WRONG-FIXTURE');
    orders.timeline = [
      OrderTimelineModel(
          status: OrderStatus.pending,
          title: 'WRONG-TIMELINE',
          description: 'Fixture',
          timestamp: DateTime.utc(2026))
    ];
    await mount(tester, auth, orders, row('owner_a', 'OWN-FIXTURE'));
    expect(find.text('WRONG-FIXTURE'), findsNothing);
    expect(find.text('WRONG-TIMELINE'), findsNothing);
    expect(find.text('OWN-FIXTURE'), findsOneWidget);
  });
  testWidgets('same-owner other-route selection cannot replace route',
      (tester) async {
    final auth = FormAuth(), orders = TrackingOrders();
    orders.selection = row('owner_a', 'OTHER-ROUTE');
    await mount(tester, auth, orders, row('owner_a', 'OWN-FIXTURE'));
    expect(find.text('OTHER-ROUTE'), findsNothing);
    expect(find.text('OWN-FIXTURE'), findsOneWidget);
  });
  testWidgets('auth provider replacement invalidates retained route',
      (tester) async {
    final first = FormAuth(), second = FormAuth(), orders = TrackingOrders();
    final order = row('owner_a', 'OLD-FIXTURE');
    await mount(tester, first, orders, order);
    await mount(tester, second, orders, order);
    expect(find.text('OLD-FIXTURE'), findsNothing);
  });
  for (final dark in [false, true]) {
    testWidgets('phone-width tracking renders with brightness $dark',
        (tester) async {
      final auth = FormAuth(), orders = TrackingOrders();
      await mount(tester, auth, orders, row('owner_a', 'OWN-FIXTURE'),
          dark: dark, width: 390);
      expect(find.text('OWN-FIXTURE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('exact owned selected route exposes only its timeline',
      (tester) async {
    final auth = FormAuth(), orders = TrackingOrders();
    orders.selection = row('owner_a', 'OWN-FIXTURE')
        .copyWith(orderNumber: 'CONFIRMED-FIXTURE');
    orders.timeline = [
      OrderTimelineModel(
          status: OrderStatus.pending,
          title: 'SAVED-TIMELINE',
          description: 'Fixture',
          timestamp: DateTime.utc(2026))
    ];
    await mount(tester, auth, orders, row('owner_a', 'OWN-FIXTURE'));
    expect(find.text('CONFIRMED-FIXTURE'), findsOneWidget);
    expect(find.text('SAVED-TIMELINE'), findsOneWidget);
  });
  testWidgets('order provider replacement invalidates retained route',
      (tester) async {
    final auth = FormAuth(),
        first = TrackingOrders(),
        second = TrackingOrders();
    final order = row('owner_a', 'OLD-FIXTURE');
    await mount(tester, auth, first, order);
    await mount(tester, auth, second, order);
    expect(find.text('OLD-FIXTURE'), findsNothing);
    expect(second.reads, isEmpty);
  });
  testWidgets('retained state cannot adopt a different order route',
      (tester) async {
    final auth = FormAuth(), orders = TrackingOrders();
    await mount(tester, auth, orders, row('owner_a', 'OLD-FIXTURE'));
    await mount(tester, auth, orders, row('owner_a', 'NEW-FIXTURE'));
    expect(find.text('OLD-FIXTURE'), findsNothing);
    expect(find.text('NEW-FIXTURE'), findsNothing);
    expect(orders.reads, ['OLD-FIXTURE']);
  });
}
