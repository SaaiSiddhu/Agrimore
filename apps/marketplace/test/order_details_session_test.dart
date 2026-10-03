import 'dart:async';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_marketplace/providers/cart_provider.dart';
import 'package:agrimore_marketplace/providers/auth_provider.dart';
import 'package:agrimore_marketplace/providers/order_provider.dart';
import 'package:agrimore_marketplace/providers/theme_provider.dart';
import 'package:agrimore_marketplace/screens/user/orders/order_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'foundation_edit_profile_form_test.dart' show FormAuth, FormTheme;
import 'order_tracking_session_test.dart' show TrackingOrders, row;

class DetailOrders extends TrackingOrders {
  @override
  bool get isLoading => false;
  final cancellations = <String>[];
  final reply = Completer<bool>();
  @override
  Future<bool> cancelOrder(String id, String reason) {
    cancellations.add(id);
    return reply.future;
  }
}

class DetailCart extends ChangeNotifier implements CartProvider {
  final additions = <List<CartItemModel>>[];
  final reply = Completer<bool>();
  @override
  Future<bool> addOrderItems(List<CartItemModel> items) {
    additions.add(items);
    return reply.future;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  Future<void> mount(WidgetTester t, FormAuth auth, DetailOrders orders,
      {String id = 'OWN-FIXTURE',
      bool dark = false,
      DetailCart? cart,
      double width = 600}) async {
    t.view.physicalSize = Size(width, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<OrderProvider>.value(value: orders),
      ChangeNotifierProvider<ThemeProvider>.value(value: FormTheme(dark)),
      if (cart != null) ChangeNotifierProvider<CartProvider>.value(value: cart),
    ], child: MaterialApp(home: OrderDetailsScreen(orderId: id))));
    await t.pumpAndSettle();
  }

  testWidgets('own exact route is visible and loaded', (t) async {
    final a = FormAuth(), o = DetailOrders();
    o.selection =
        row('owner_a', 'OWN-FIXTURE').copyWith(orderStatus: 'delivered');
    await mount(t, a, o);
    expect(find.text('Order #OWN-FIXTURE'), findsOneWidget);
    expect(o.reads, ['OWN-FIXTURE']);
  });
  for (final owner in ['owner_a', 'owner_b']) {
    testWidgets('another selection cannot replace detail route $owner',
        (t) async {
      final a = FormAuth(), o = DetailOrders();
      o.selection =
          row(owner, 'OTHER-FIXTURE').copyWith(orderStatus: 'delivered');
      await mount(t, a, o);
      expect(find.text('Order #OTHER-FIXTURE'), findsNothing);
    });
  }
  for (final owner in <String?>['owner_b', null, 'owner_a']) {
    testWidgets('opening detail expires on auth change $owner', (t) async {
      final a = FormAuth(), o = DetailOrders();
      o.selection =
          row('owner_a', 'OWN-FIXTURE').copyWith(orderStatus: 'delivered');
      await mount(t, a, o);
      a.change(owner);
      await t.pumpAndSettle();
      expect(find.text('Order #OWN-FIXTURE'), findsNothing);
    });
  }
  testWidgets('auth provider replacement expires retained detail', (t) async {
    final a = FormAuth(), o = DetailOrders();
    o.selection =
        row('owner_a', 'OWN-FIXTURE').copyWith(orderStatus: 'delivered');
    await mount(t, a, o);
    await mount(t, FormAuth(), o);
    expect(find.text('Order #OWN-FIXTURE'), findsNothing);
  });
  testWidgets('retained detail cannot adopt another route ID', (t) async {
    final a = FormAuth(), o = DetailOrders();
    o.selection =
        row('owner_a', 'OWN-FIXTURE').copyWith(orderStatus: 'delivered');
    await mount(t, a, o);
    await mount(t, a, o, id: 'NEW-FIXTURE');
    expect(find.text('Order #OWN-FIXTURE'), findsNothing);
    expect(o.reads, ['OWN-FIXTURE']);
  });
  testWidgets('signed-out opening route does not read', (t) async {
    final a = FormAuth()..owner = null, o = DetailOrders();
    o.selection =
        row('owner_a', 'OWN-FIXTURE').copyWith(orderStatus: 'delivered');
    await mount(t, a, o);
    expect(o.reads, isEmpty);
    expect(find.text('Order #OWN-FIXTURE'), findsNothing);
  });
  testWidgets('replacement order provider expires retained detail', (t) async {
    final a = FormAuth(), first = DetailOrders(), second = DetailOrders();
    first.selection =
        row('owner_a', 'OWN-FIXTURE').copyWith(orderStatus: 'delivered');
    second.selection = first.selection;
    await mount(t, a, first);
    await mount(t, a, second);
    expect(second.reads, isEmpty);
    expect(find.text('Order #OWN-FIXTURE'), findsNothing);
  });
  for (final dark in [false, true]) {
    testWidgets('phone detail renders brightness $dark', (t) async {
      final a = FormAuth(), o = DetailOrders();
      o.selection =
          row('owner_a', 'OWN-FIXTURE').copyWith(orderStatus: 'delivered');
      await mount(t, a, o, dark: dark, width: 390);
      expect(find.text('Order #OWN-FIXTURE'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
  Future<void> openCancel(WidgetTester t, FormAuth a, DetailOrders o) async {
    o.selection =
        row('owner_a', 'OWN-FIXTURE').copyWith(createdAt: DateTime.now());
    await mount(t, a, o);
    await t.tap(find.text('Payment'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Cancel Order (1 Hour Window)'));
    await t.tap(find.text('Cancel Order (1 Hour Window)'));
    await t.pumpAndSettle();
  }

  testWidgets('cancel dialog hides and refuses old confirmation after switch',
      (t) async {
    final a = FormAuth(), o = DetailOrders();
    await openCancel(t, a, o);
    final old = t
        .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Cancel Order'))
        .onPressed!;
    a.change('owner_b');
    await t.pumpAndSettle();
    expect(
        find.text('Are you sure you want to cancel this order?'), findsNothing);
    old();
    await t.pump();
    expect(o.cancellations, isEmpty);
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  });
  for (final success in [true, false]) {
    testWidgets('held cancellation has no old feedback after switch $success',
        (t) async {
      final a = FormAuth(), o = DetailOrders();
      await openCancel(t, a, o);
      await t.enterText(find.byType(TextField), 'Fixture reason');
      await t.tap(find.widgetWithText(ElevatedButton, 'Cancel Order'));
      await t.pumpAndSettle();
      expect(o.cancellations, ['OWN-FIXTURE']);
      a.change('owner_b');
      o.reply.complete(success);
      await t.pumpAndSettle();
      expect(find.textContaining('cancelled successfully'), findsNothing);
      expect(find.textContaining('Failed to cancel order'), findsNothing);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('reorder modal clears old products and refuses late selection',
      (t) async {
    final a = FormAuth(), o = DetailOrders(), c = DetailCart();
    final item = CartItemModel(
        id: 'fixture',
        productId: 'fixture',
        productName: 'PRIVATE-ITEM',
        productImage: '',
        price: 100,
        quantity: 1,
        userId: 'owner_a',
        addedAt: DateTime.utc(2026));
    o.selection = row('owner_a', 'OWN-FIXTURE')
        .copyWith(orderStatus: 'delivered', items: [item]);
    await mount(t, a, o, cart: c);
    await t.ensureVisible(find.text('Reorder Items'));
    await t.tap(find.text('Reorder Items'));
    await t.pumpAndSettle();
    expect(find.text('Select Items to Reorder'), findsOneWidget);
    a.change('owner_b');
    await t.pumpAndSettle();
    expect(find.text('PRIVATE-ITEM'), findsNothing);
    expect(find.text('Select Items to Reorder'), findsNothing);
    Navigator.of(t.element(find
            .text('Your session changed. Reopen this order to continue.')
            .last))
        .pop([item]);
    await t.pumpAndSettle();
    expect(c.additions, isEmpty);
  });

  Future<void> startReorder(
      WidgetTester t, FormAuth a, DetailOrders o, DetailCart c) async {
    final item = CartItemModel(
        id: 'fixture',
        productId: 'fixture',
        productName: 'PRIVATE-ITEM',
        productImage: '',
        price: 100,
        quantity: 1,
        userId: 'owner_a',
        addedAt: DateTime.utc(2026));
    o.selection = row('owner_a', 'OWN-FIXTURE')
        .copyWith(orderStatus: 'delivered', items: [item]);
    await mount(t, a, o, cart: c);
    await t.ensureVisible(find.text('Reorder Items'));
    await t.tap(find.text('Reorder Items'));
    await t.pumpAndSettle();
    Navigator.of(t.element(find.text('Select Items to Reorder'))).pop([item]);
    await t.pumpAndSettle();
    expect(c.additions.length, 1);
  }

  for (final success in [true, false]) {
    testWidgets(
        'held cart result cannot report or navigate after switch $success',
        (t) async {
      final a = FormAuth(), o = DetailOrders(), c = DetailCart();
      await startReorder(t, a, o, c);
      a.change('owner_b');
      c.reply.complete(success);
      await t.pumpAndSettle();
      expect(find.textContaining('Added 1 item'), findsNothing);
      expect(find.text('Unable to add these items. Please try again.'),
          findsNothing);
      expect(find.text('Your session changed. Reopen this order to continue.'),
          findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('cart response refuses a replaced cart provider', (t) async {
    final a = FormAuth(), o = DetailOrders(), c = DetailCart();
    await startReorder(t, a, o, c);
    await mount(t, a, o, cart: DetailCart());
    c.reply.complete(true);
    await t.pumpAndSettle();
    expect(find.textContaining('Added 1 item'), findsNothing);
    expect(find.text('Order #OWN-FIXTURE'), findsOneWidget);
  });
  testWidgets(
      'confirmed cart result cannot navigate after session expires during delay',
      (t) async {
    final a = FormAuth(), o = DetailOrders(), c = DetailCart();
    await startReorder(t, a, o, c);
    c.reply.complete(true);
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Added 1 item'), findsOneWidget);
    a.change('owner_b');
    await t.pumpAndSettle();
    expect(find.textContaining('Added 1 item'), findsNothing);
    expect(find.text('Your session changed. Reopen this order to continue.'),
        findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('failed reorder displays safe confirmed response', (t) async {
    final a = FormAuth(), o = DetailOrders(), c = DetailCart();
    await startReorder(t, a, o, c);
    c.reply.complete(false);
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('Unable to add these items. Please try again.'),
        findsOneWidget);
    expect(find.textContaining('unsafe fixture'), findsNothing);
    await t.pump(const Duration(seconds: 4));
    await t.pumpAndSettle();
  });
  testWidgets('disposed detail ignores held cancellation result', (t) async {
    final a = FormAuth(), o = DetailOrders();
    await openCancel(t, a, o);
    await t.enterText(find.byType(TextField), 'Fixture reason');
    await t.tap(find.widgetWithText(ElevatedButton, 'Cancel Order'));
    await t.pumpAndSettle();
    await t.pumpWidget(const SizedBox());
    o.reply.complete(true);
    await t.pump();
    expect(t.takeException(), isNull);
  });
}
