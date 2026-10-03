import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_marketplace/providers/auth_provider.dart';
import 'package:agrimore_marketplace/providers/order_provider.dart';
import 'package:agrimore_marketplace/providers/theme_provider.dart';
import 'package:agrimore_marketplace/screens/user/orders/orders_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'foundation_edit_profile_form_test.dart' show FormAuth, FormTheme;
import 'order_tracking_session_test.dart' show row, TrackingOrders;

class ListOrders extends TrackingOrders {
  List<OrderModel> rows = [];
  int loads = 0;
  String? failure;
  @override
  List<OrderModel> get orders => rows;
  @override
  bool get isLoading => false;
  @override
  String? get error => failure;
  @override
  void loadOrders() {
    loads++;
  }
}

class ListNavigation extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route route, Route? previous) {
    pushes++;
  }
}

void main() {
  Future<void> mount(WidgetTester t, FormAuth a, ListOrders o,
      {bool dark = false, double width = 600, ListNavigation? nav}) async {
    t.view.physicalSize = Size(width, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: a),
          ChangeNotifierProvider<OrderProvider>.value(value: o),
          ChangeNotifierProvider<ThemeProvider>.value(value: FormTheme(dark)),
        ],
        child: MaterialApp(
            navigatorObservers: nav == null ? [] : [nav],
            home: const OrdersScreen())));
    await t.pumpAndSettle();
  }

  testWidgets('own order list and opening reload remain available', (t) async {
    final a = FormAuth(), o = ListOrders();
    o.rows = [row('owner_a', 'OWN-FIXTURE').copyWith(orderStatus: 'delivered')];
    await mount(t, a, o);
    expect(find.textContaining('OWN-FIXTURE'), findsOneWidget);
    expect(o.loads, 1);
  });
  testWidgets('foreign rows cannot render in list', (t) async {
    final a = FormAuth(), o = ListOrders();
    o.rows = [
      row('owner_b', 'FOREIGN-FIXTURE').copyWith(orderStatus: 'delivered')
    ];
    await mount(t, a, o);
    expect(find.textContaining('FOREIGN-FIXTURE'), findsNothing);
  });
  for (final uid in <String?>['owner_b', null, 'owner_a']) {
    testWidgets('opening list expires on auth change $uid', (t) async {
      final a = FormAuth(), o = ListOrders();
      o.rows = [
        row('owner_a', 'OWN-FIXTURE').copyWith(orderStatus: 'delivered')
      ];
      await mount(t, a, o);
      a.change(uid);
      await t.pumpAndSettle();
      expect(find.textContaining('OWN-FIXTURE'), findsNothing);
    });
  }
  testWidgets('signed-out opening performs no reload', (t) async {
    final a = FormAuth()..owner = null, o = ListOrders();
    await mount(t, a, o);
    expect(o.loads, 0);
  });
  testWidgets('replacement auth provider expires retained list', (t) async {
    final a = FormAuth(), o = ListOrders();
    o.rows = [row('owner_a', 'OWN-FIXTURE').copyWith(orderStatus: 'delivered')];
    await mount(t, a, o);
    await mount(t, FormAuth(), o);
    expect(find.textContaining('OWN-FIXTURE'), findsNothing);
  });
  testWidgets('replacement orders provider expires retained list', (t) async {
    final a = FormAuth(), first = ListOrders(), second = ListOrders();
    first.rows = [
      row('owner_a', 'OWN-FIXTURE').copyWith(orderStatus: 'delivered')
    ];
    second.rows = first.rows;
    await mount(t, a, first);
    await mount(t, a, second);
    expect(find.textContaining('OWN-FIXTURE'), findsNothing);
  });
  testWidgets('read failure copy never exposes provider detail', (t) async {
    final a = FormAuth(),
        o = ListOrders()..failure = 'unsafe fixture SDK detail';
    await mount(t, a, o);
    expect(find.textContaining('unsafe fixture'), findsNothing);
  });
  testWidgets('captured retry cannot reload replacement account', (t) async {
    final a = FormAuth(), o = ListOrders()..failure = 'Fixture';
    await mount(t, a, o);
    final retry = t
        .widget<InkWell>(find
            .ancestor(
                of: find.text('Try Again'), matching: find.byType(InkWell))
            .first)
        .onTap!;
    a.change('owner_b');
    await t.pumpAndSettle();
    retry();
    await t.pump();
    expect(o.loads, 1);
  });
  testWidgets('captured order card cannot navigate after auth changes',
      (t) async {
    final a = FormAuth(), o = ListOrders(), nav = ListNavigation();
    o.rows = [row('owner_a', 'OWN-FIXTURE').copyWith(orderStatus: 'delivered')];
    await mount(t, a, o, nav: nav);
    final card = t
        .widget<GestureDetector>(find
            .ancestor(
                of: find.textContaining('OWN-FIXTURE'),
                matching: find.byType(GestureDetector))
            .first)
        .onTap!;
    a.change('owner_b');
    await t.pumpAndSettle();
    final before = nav.pushes;
    card();
    await t.pump();
    expect(nav.pushes, before);
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  });
  for (final dark in [false, true]) {
    testWidgets('owned delivered list renders on phone dark=$dark', (t) async {
      final a = FormAuth(), o = ListOrders();
      o.rows = [
        row('owner_a', 'OWN-FIXTURE').copyWith(orderStatus: 'delivered')
      ];
      await mount(t, a, o, dark: dark, width: 390);
      expect(find.textContaining('OWN-FIXTURE'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.ensureVisible(find.text('Delivered').first);
      await t.pumpAndSettle();
      await t.tap(find.text('Delivered').first);
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Confirmed').first);
      await t.pumpAndSettle();
      await t.tap(find.text('Confirmed').first);
      await t.pumpAndSettle();
      expect(find.textContaining('OWN-FIXTURE'), findsNothing);
      expect(find.text('No Confirmed Orders'), findsOneWidget);
      await t.ensureVisible(find.text('Delivered').first);
      await t.pumpAndSettle();
      await t.tap(find.text('Delivered').first);
      await t.pumpAndSettle();
      expect(find.textContaining('OWN-FIXTURE'), findsOneWidget);
    });
  }
  testWidgets('refresh reloads current owner and refuses expired callback',
      (t) async {
    final a = FormAuth(), o = ListOrders();
    o.rows = [row('owner_a', 'OWN-FIXTURE').copyWith(orderStatus: 'delivered')];
    await mount(t, a, o);
    final refresh =
        t.widget<RefreshIndicator>(find.byType(RefreshIndicator)).onRefresh;
    await refresh();
    expect(o.loads, 2);
    a.change('owner_b');
    await t.pumpAndSettle();
    await refresh();
    expect(o.loads, 2);
  });
  testWidgets('captured tracking and detail callbacks refuse disposal',
      (t) async {
    final a = FormAuth(), o = ListOrders(), nav = ListNavigation();
    o.rows = [row('owner_a', 'OWN-FIXTURE').copyWith(orderStatus: 'delivered')];
    await mount(t, a, o, nav: nav);
    final dynamic card =
        t.widget(find.byKey(ValueKey('owner_a:1:OWN-FIXTURE')));
    final VoidCallback track = card.onTrack, detail = card.onTap;
    await t.pumpWidget(const SizedBox());
    final before = nav.pushes;
    track();
    detail();
    await t.pump();
    expect(nav.pushes, before);
    expect(t.takeException(), isNull);
  });
  testWidgets('captured tracking callback refuses provider replacement',
      (t) async {
    final a = FormAuth(),
        o = ListOrders(),
        replacement = ListOrders(),
        nav = ListNavigation();
    o.rows = [row('owner_a', 'OWN-FIXTURE').copyWith(orderStatus: 'delivered')];
    replacement.rows = o.rows;
    await mount(t, a, o, nav: nav);
    final dynamic card =
        t.widget(find.byKey(ValueKey('owner_a:1:OWN-FIXTURE')));
    final VoidCallback track = card.onTrack;
    await mount(t, a, replacement, nav: nav);
    final before = nav.pushes;
    track();
    await t.pump();
    expect(nav.pushes, before);
  });
}
