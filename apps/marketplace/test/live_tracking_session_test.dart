import 'dart:async';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_marketplace/providers/auth_provider.dart';
import 'package:agrimore_marketplace/providers/order_provider.dart';
import 'package:agrimore_marketplace/providers/theme_provider.dart';
import 'package:agrimore_marketplace/screens/user/orders/live_tracking_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:agrimore_marketplace/screens/user/orders/widgets/delivered_view.dart';
import 'package:agrimore_marketplace/screens/user/orders/widgets/tracking_sections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'foundation_edit_profile_form_test.dart' show FormAuth, FormTheme;
import 'order_tracking_session_test.dart' show TrackingOrders, row;

class Feeds {
  final orders = StreamController<OrderModel?>.broadcast();
  final tasks = StreamController<DeliveryTaskModel?>.broadcast();
  final live = StreamController<RiderLivePoint?>.broadcast();
  final codes = StreamController<String?>.broadcast();
  Set<Marker> markers = {};
  final reads = <String>[];
  final orderReads = <String>[];
  void close() {
    orders.close();
    tasks.close();
    live.close();
    codes.close();
  }

  LiveTrackingScreen screen(String id, OrderModel? initial) =>
      LiveTrackingScreen(
        orderId: id,
        initialOrder: initial,
        orderSnapshots: (id) {
          orderReads.add(id);
          return orders.stream;
        },
        taskSnapshots: (id) {
          reads.add('task:$id');
          return tasks.stream;
        },
        liveSnapshots: (id) {
          reads.add('live:$id');
          return live.stream;
        },
        codeSnapshots: (id) {
          reads.add('code:$id');
          return codes.stream;
        },
        markerIcons: () async => null,
        mapBuilder: (value, lines) {
          markers = value;
          return const SizedBox.expand(key: Key('fixture-map'));
        },
      );
}

void main() {
  Future<void> mount(WidgetTester t, FormAuth auth, TrackingOrders orders,
      Feeds f, OrderModel? initial,
      {String id = 'OWN-FIXTURE',
      bool dark = false,
      double width = 600}) async {
    t.view.physicalSize = Size(width, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<OrderProvider>.value(value: orders),
      ChangeNotifierProvider<ThemeProvider>.value(value: FormTheme(dark)),
    ], child: MaterialApp(home: f.screen(id, initial))));
    await t.pump(const Duration(milliseconds: 800));
  }

  testWidgets('own live route preserves confirmed receipt', (t) async {
    final a = FormAuth(), o = TrackingOrders(), f = Feeds();
    addTearDown(f.close);
    await mount(t, a, o, f,
        row('owner_a', 'OWN-FIXTURE').copyWith(orderStatus: 'delivered'));
    expect(find.textContaining('OWN-FIXTURE'), findsWidgets);
    expect(o.reads, ['OWN-FIXTURE']);
  });
  for (final owner in <String?>['owner_b', null, 'owner_a']) {
    testWidgets('cached live receipt expires with session $owner', (t) async {
      final a = FormAuth(), o = TrackingOrders(), f = Feeds();
      addTearDown(f.close);
      await mount(t, a, o, f,
          row('owner_a', 'OWN-FIXTURE').copyWith(orderStatus: 'delivered'));
      a.change(owner);
      await t.pump();
      f.orders.add(
          row('owner_a', 'LATE-PRIVATE').copyWith(orderStatus: 'delivered'));
      f.codes.add('PRIVATE-CODE');
      await t.pump();
      expect(find.textContaining('OWN-FIXTURE'), findsNothing);
      expect(find.textContaining('LATE-PRIVATE'), findsNothing);
      expect(f.orders.hasListener, isFalse);
      expect(f.codes.hasListener, isFalse);
    });
  }
  for (final owner in ['owner_a', 'owner_b']) {
    testWidgets('foreign route initial data refuses auxiliary reads $owner',
        (t) async {
      final a = FormAuth(), o = TrackingOrders(), f = Feeds();
      addTearDown(f.close);
      await mount(t, a, o, f,
          row(owner, 'OTHER-FIXTURE').copyWith(orderStatus: 'delivered'));
      expect(find.textContaining('OTHER-FIXTURE'), findsNothing);
      expect(f.reads, isEmpty);
    });
  }
  testWidgets('incoming order must match opening owner and ID', (t) async {
    final a = FormAuth(), o = TrackingOrders(), f = Feeds();
    addTearDown(f.close);
    await mount(t, a, o, f,
        row('owner_a', 'OWN-FIXTURE').copyWith(orderStatus: 'delivered'));
    f.orders.add(
        row('owner_b', 'WRONG-FIXTURE').copyWith(orderStatus: 'delivered'));
    await t.pump();
    expect(find.textContaining('WRONG-FIXTURE'), findsNothing);
    expect(f.codes.hasListener, isFalse);
  });
  testWidgets('replacement auth expires live route', (t) async {
    final a = FormAuth(), o = TrackingOrders(), f = Feeds();
    addTearDown(f.close);
    final initial =
        row('owner_a', 'OWN-FIXTURE').copyWith(orderStatus: 'delivered');
    await mount(t, a, o, f, initial);
    await mount(t, FormAuth(), o, f, initial);
    expect(find.textContaining('OWN-FIXTURE'), findsNothing);
  });
  testWidgets('replacement order provider expires live route', (t) async {
    final a = FormAuth(), o = TrackingOrders(), f = Feeds();
    addTearDown(f.close);
    final initial =
        row('owner_a', 'OWN-FIXTURE').copyWith(orderStatus: 'delivered');
    await mount(t, a, o, f, initial);
    await mount(t, a, TrackingOrders(), f, initial);
    expect(find.textContaining('OWN-FIXTURE'), findsNothing);
  });
  testWidgets('retained live route cannot adopt changed ID', (t) async {
    final a = FormAuth(), o = TrackingOrders(), f = Feeds();
    addTearDown(f.close);
    final initial =
        row('owner_a', 'OWN-FIXTURE').copyWith(orderStatus: 'delivered');
    await mount(t, a, o, f, initial);
    await mount(t, a, o, f, initial, id: 'NEW-FIXTURE');
    expect(find.textContaining('OWN-FIXTURE'), findsNothing);
  });
  testWidgets('deep link delays private streams until owned order arrives',
      (t) async {
    final a = FormAuth(), o = TrackingOrders(), f = Feeds();
    addTearDown(f.close);
    await mount(t, a, o, f, null);
    expect(f.reads, isEmpty);
    f.orders
        .add(row('owner_a', 'OWN-FIXTURE').copyWith(orderStatus: 'delivered'));
    await t.pump();
    expect(f.reads.length, 3);
    expect(find.textContaining('OWN-FIXTURE'), findsWidgets);
  });
  testWidgets('signed out live route reads nothing', (t) async {
    final a = FormAuth()..owner = null, o = TrackingOrders(), f = Feeds();
    addTearDown(f.close);
    await mount(t, a, o, f,
        row('owner_a', 'OWN-FIXTURE').copyWith(orderStatus: 'delivered'));
    expect(f.orderReads, isEmpty);
    expect(f.reads, isEmpty);
    expect(o.reads, isEmpty);
  });
  Future<void> active(WidgetTester t, FormAuth a, TrackingOrders o, Feeds f,
      {bool dark = false, double width = 600}) async {
    await mount(t, a, o, f,
        row('owner_a', 'OWN-FIXTURE').copyWith(orderStatus: 'out_for_delivery'),
        dark: dark, width: width);
    f.tasks.add(const DeliveryTaskModel(
        orderId: 'OWN-FIXTURE',
        customerId: 'owner_a',
        status: DeliveryTaskStatus.enRoute));
    f.live.add(RiderLivePoint(lat: 12, lng: 77, at: DateTime.now()));
    f.codes.add('1234');
    await t.pump();
  }

  for (final dark in [false, true]) {
    testWidgets('phone active map fixture and code brightness $dark',
        (t) async {
      final a = FormAuth(), o = TrackingOrders(), f = Feeds();
      addTearDown(f.close);
      await active(t, a, o, f, dark: dark, width: 390);
      expect(find.byKey(const Key('fixture-map')), findsOneWidget);
      expect(find.byType(DeliveryCodeCard), findsOneWidget);
      expect(f.markers.any((m) => m.markerId.value == 'partner'), isTrue);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets(
      'active location and code are cleared at switch and cannot revive',
      (t) async {
    final a = FormAuth(), o = TrackingOrders(), f = Feeds();
    addTearDown(f.close);
    await active(t, a, o, f);
    expect(find.byType(DeliveryCodeCard), findsOneWidget);
    a.change('owner_b');
    await t.pump();
    f.tasks.add(const DeliveryTaskModel(
        orderId: 'OWN-FIXTURE', status: DeliveryTaskStatus.enRoute));
    f.live.add(const RiderLivePoint(lat: 13, lng: 78));
    f.codes.add('5678');
    await t.pump();
    expect(find.byType(DeliveryCodeCard), findsNothing);
    expect(find.byKey(const Key('fixture-map')), findsNothing);
    expect(f.live.hasListener, isFalse);
    expect(f.tasks.hasListener, isFalse);
  });
  for (final task in [
    const DeliveryTaskModel(
        orderId: 'OTHER', status: DeliveryTaskStatus.enRoute),
    const DeliveryTaskModel(
        orderId: 'OWN-FIXTURE',
        customerId: 'owner_b',
        status: DeliveryTaskStatus.enRoute),
  ]) {
    testWidgets(
        'task projection must match owner and route ${task.orderId}/${task.customerId}',
        (t) async {
      final a = FormAuth(), o = TrackingOrders(), f = Feeds();
      addTearDown(f.close);
      await active(t, a, o, f);
      f.tasks.add(task);
      await t.pump();
      expect(find.byKey(const Key('fixture-map')), findsNothing);
      expect(f.codes.hasListener, isFalse);
    });
  }
  testWidgets('failed private streams clear code and rider marker', (t) async {
    final a = FormAuth(), o = TrackingOrders(), f = Feeds();
    addTearDown(f.close);
    await active(t, a, o, f);
    f.codes.addError(StateError('unsafe fixture code detail'));
    f.live.addError(StateError('unsafe fixture coordinate detail'));
    await t.pump();
    expect(find.byType(DeliveryCodeCard), findsNothing);
    expect(f.markers.any((m) => m.markerId.value == 'partner'), isFalse);
    expect(find.textContaining('unsafe fixture'), findsNothing);
  });
  for (final missing in [true, false]) {
    testWidgets('missing or failed order invalidates caches $missing',
        (t) async {
      final a = FormAuth(), o = TrackingOrders(), f = Feeds();
      addTearDown(f.close);
      await active(t, a, o, f);
      if (missing) {
        f.orders.add(null);
      } else {
        f.orders.addError(StateError('unsafe fixture'));
      }
      await t.pump();
      expect(find.byType(DeliveryCodeCard), findsNothing);
      expect(f.codes.hasListener, isFalse);
      expect(find.textContaining('unsafe fixture'), findsNothing);
    });
  }
  testWidgets('captured receipt actions refuse late navigation', (t) async {
    final a = FormAuth(), o = TrackingOrders(), f = Feeds();
    addTearDown(f.close);
    await mount(t, a, o, f,
        row('owner_a', 'OWN-FIXTURE').copyWith(orderStatus: 'delivered'));
    final receipt = t.widget<DeliveredView>(find.byType(DeliveredView));
    a.change('owner_b');
    await t.pump();
    receipt.onHelp();
    receipt.onRate();
    receipt.onDone();
    await t.pump();
    expect(t.takeException(), isNull);
    expect(find.text('Your session changed. Reopen this order to continue.'),
        findsOneWidget);
  });
  testWidgets('dispose detaches every feed and ignores queued data', (t) async {
    final a = FormAuth(), o = TrackingOrders(), f = Feeds();
    addTearDown(f.close);
    await active(t, a, o, f);
    await t.pumpWidget(const SizedBox());
    f.orders.add(row('owner_a', 'OWN-FIXTURE'));
    f.codes.add('1234');
    await t.pump();
    expect(f.orders.hasListener, isFalse);
    expect(f.tasks.hasListener, isFalse);
    expect(f.live.hasListener, isFalse);
    expect(f.codes.hasListener, isFalse);
    expect(t.takeException(), isNull);
  });
}
