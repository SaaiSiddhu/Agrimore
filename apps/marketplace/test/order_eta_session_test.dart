import 'dart:async';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_marketplace/providers/auth_provider.dart';
import 'package:agrimore_marketplace/screens/user/orders/widgets/live_eta_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'foundation_edit_profile_form_test.dart' show FormAuth;

class EtaFeeds {
  final tasks = StreamController<DeliveryTaskModel?>.broadcast();
  final live = StreamController<RiderLivePoint?>.broadcast();
  final taskReads = <String>[], liveReads = <String>[];
  DateTime time = DateTime.utc(2026);
  Stream<DeliveryTaskModel?> taskStream(String id) {
    taskReads.add(id);
    return tasks.stream.map((v) => v);
  }

  Stream<RiderLivePoint?> liveStream(String id) {
    liveReads.add(id);
    return live.stream.map((v) => v);
  }

  void close() {
    tasks.close();
    live.close();
  }

  Widget widget(
          {String id = 'OWN',
          String owner = 'owner_a',
          bool dark = false,
          String status = 'confirmed'}) =>
      LiveEtaText(
          orderId: id,
          ownerId: owner,
          orderStatus: status,
          isDark: dark,
          taskSnapshots: taskStream,
          liveSnapshots: liveStream,
          now: () => time);
}

DeliveryTaskModel arrival({String id = 'OWN', String? owner = 'owner_a'}) =>
    DeliveryTaskModel(
        orderId: id,
        customerId: owner,
        status: DeliveryTaskStatus.atDrop,
        drop: const DeliveryPoint(lat: 12, lng: 77));
void main() {
  Future<void> mount(WidgetTester t, FormAuth a, EtaFeeds f,
      {String id = 'OWN',
      String owner = 'owner_a',
      bool dark = false,
      String status = 'confirmed'}) async {
    await t.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: a,
        child: MaterialApp(
            home: Scaffold(
                body: f.widget(
                    id: id, owner: owner, dark: dark, status: status)))));
    await t.pump();
  }

  Future<void> emit(WidgetTester t, EtaFeeds f, DeliveryTaskModel? task) async {
    f.tasks.add(task);
    await t.pump();
    await t.pump();
  }

  testWidgets('owned arrival stage and live route remain available', (t) async {
    final a = FormAuth(), f = EtaFeeds();
    addTearDown(f.close);
    await mount(t, a, f);
    await emit(t, f, arrival());
    expect(find.text('Your delivery partner has arrived'), findsWidgets);
    expect(f.liveReads, ['OWN']);
  });
  testWidgets('no location stream before owned task arrives', (t) async {
    final a = FormAuth(), f = EtaFeeds();
    addTearDown(f.close);
    await mount(t, a, f);
    expect(f.liveReads, isEmpty);
  });
  for (final uid in <String?>['owner_b', null, 'owner_a']) {
    testWidgets('cached ETA expires with opening session $uid', (t) async {
      final a = FormAuth(), f = EtaFeeds();
      addTearDown(f.close);
      await mount(t, a, f);
      await emit(t, f, arrival());
      a.change(uid);
      await t.pump();
      await emit(t, f, arrival());
      expect(find.text('Your delivery partner has arrived'), findsNothing);
      expect(f.tasks.hasListener, isFalse);
      expect(f.live.hasListener, isFalse);
    });
  }
  for (final owner in ['owner_b', '']) {
    testWidgets('foreign or blank owner cannot subscribe $owner', (t) async {
      final a = FormAuth(), f = EtaFeeds();
      addTearDown(f.close);
      await mount(t, a, f, owner: owner);
      expect(f.taskReads, isEmpty);
      expect(f.liveReads, isEmpty);
    });
  }
  testWidgets('signed-out opening cannot subscribe', (t) async {
    final a = FormAuth()..owner = null, f = EtaFeeds();
    addTearDown(f.close);
    await mount(t, a, f);
    expect(f.taskReads, isEmpty);
    expect(f.liveReads, isEmpty);
  });
  for (final task in [arrival(id: 'OTHER'), arrival(owner: 'owner_b')]) {
    testWidgets(
        'task must match order and present customer ${task.orderId}/${task.customerId}',
        (t) async {
      final a = FormAuth(), f = EtaFeeds();
      addTearDown(f.close);
      await mount(t, a, f);
      await emit(t, f, task);
      expect(find.text('Your delivery partner has arrived'), findsNothing);
      expect(f.liveReads, isEmpty);
    });
  }
  testWidgets('status/theme rebuild does not recreate either subscription',
      (t) async {
    final a = FormAuth(), f = EtaFeeds();
    addTearDown(f.close);
    await mount(t, a, f);
    await emit(t, f, arrival());
    await mount(t, a, f, dark: true, status: 'out_for_delivery');
    await emit(t, f, arrival());
    expect(f.taskReads, ['OWN']);
    expect(f.liveReads, ['OWN']);
  });
  testWidgets('retained route cannot adopt another order', (t) async {
    final a = FormAuth(), f = EtaFeeds();
    addTearDown(f.close);
    await mount(t, a, f);
    await emit(t, f, arrival());
    await mount(t, a, f, id: 'OTHER');
    expect(find.text('Your delivery partner has arrived'), findsNothing);
    expect(f.taskReads, ['OWN']);
  });
  testWidgets('replacement auth provider expires ETA', (t) async {
    final a = FormAuth(), f = EtaFeeds();
    addTearDown(f.close);
    await mount(t, a, f);
    await emit(t, f, arrival());
    await mount(t, FormAuth(), f);
    expect(find.text('Your delivery partner has arrived'), findsNothing);
    expect(f.tasks.hasListener, isFalse);
  });
  testWidgets('null or failed task clears cached arrival and location',
      (t) async {
    final a = FormAuth(), f = EtaFeeds();
    addTearDown(f.close);
    await mount(t, a, f);
    await emit(t, f, arrival());
    await emit(t, f, null);
    expect(f.live.hasListener, isFalse);
    await emit(t, f, arrival());
    f.tasks.addError(StateError('unsafe fixture'));
    await t.pump();
    await t.pump();
    expect(find.text('Your delivery partner has arrived'), findsNothing);
    expect(find.textContaining('unsafe fixture'), findsNothing);
    expect(f.live.hasListener, isFalse);
  });
  testWidgets('server route ETA ticks then expires without GPS traffic request',
      (t) async {
    final a = FormAuth(), f = EtaFeeds();
    addTearDown(f.close);
    await mount(t, a, f);
    final computed = f.time;
    await emit(
        t,
        f,
        DeliveryTaskModel(
            orderId: 'OWN',
            customerId: 'owner_a',
            status: DeliveryTaskStatus.enRoute,
            drop: const DeliveryPoint(lat: 12, lng: 77),
            route: DeliveryRoute(
                plan: 'to_drop',
                legs: [],
                durationSeconds: 600,
                computedAt: computed)));
    expect(find.text('Arriving in 12 min'), findsOneWidget);
    f.time = computed.add(const Duration(minutes: 2));
    await t.pump(const Duration(seconds: 20));
    expect(find.text('Arriving in 10 min'), findsOneWidget);
    f.time = computed.add(const Duration(minutes: 8));
    await t.pump(const Duration(seconds: 20));
    expect(find.textContaining('Arriving in'), findsNothing);
  });
  testWidgets('dispose detaches task and location subscriptions', (t) async {
    final a = FormAuth(), f = EtaFeeds();
    addTearDown(f.close);
    await mount(t, a, f);
    await emit(t, f, arrival());
    await t.pumpWidget(const SizedBox());
    f.tasks.add(arrival());
    await t.pump();
    expect(f.tasks.hasListener, isFalse);
    expect(f.live.hasListener, isFalse);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'legacy task without customer id remains compatible then recovers error',
      (t) async {
    final a = FormAuth(), f = EtaFeeds();
    addTearDown(f.close);
    await mount(t, a, f);
    await emit(t, f, arrival(owner: null));
    expect(find.text('Your delivery partner has arrived'), findsWidgets);
    f.tasks.addError(StateError('fixture'));
    await t.pump();
    await t.pump();
    expect(find.text('Tracking is unavailable right now.'), findsOneWidget);
    await emit(t, f, arrival());
    expect(find.text('Tracking is unavailable right now.'), findsNothing);
    expect(find.text('Your delivery partner has arrived'), findsWidgets);
    expect(f.liveReads, ['OWN', 'OWN']);
  });
  testWidgets('retained ETA cannot adopt new owner', (t) async {
    final a = FormAuth(), f = EtaFeeds();
    addTearDown(f.close);
    await mount(t, a, f);
    await emit(t, f, arrival());
    await mount(t, a, f, owner: 'owner_b');
    expect(find.text('Your delivery partner has arrived'), findsNothing);
    expect(f.tasks.hasListener, isFalse);
    expect(f.live.hasListener, isFalse);
  });
  testWidgets('transport replacement expires retained ETA', (t) async {
    final a = FormAuth(), first = EtaFeeds(), replacement = EtaFeeds();
    addTearDown(first.close);
    addTearDown(replacement.close);
    await mount(t, a, first);
    await emit(t, first, arrival());
    await mount(t, a, replacement);
    expect(find.text('Your delivery partner has arrived'), findsNothing);
    expect(first.tasks.hasListener, isFalse);
    expect(replacement.taskReads, isEmpty);
  });
}
