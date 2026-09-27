// DLVACC1: RiderRouteCard previously read Firestore with no seam at all
// (see rider_route_stale_test.dart's own header comment) -- these tests use
// the newly added taskStream/riderStream injection points to drive real
// state transitions (loading, missing coordinates, a listener failure,
// retry, the Map/Details toggle) without touching a real backend.
//
// DocumentSnapshot is `@sealed` (a meta-package lint, not a language
// `sealed` keyword) -- implementable outside its library for a test double,
// just discouraged; no fake-Firestore package exists in this repo to avoid
// it (rider_route_stale_test.dart's own header comment says the same).
// ignore_for_file: subtype_of_sealed_class
import 'dart:async';

import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery/l10n/app_localizations.dart';
import 'package:delivery/providers/location_provider.dart';
import 'package:delivery/screens/orders/widgets/rider_route_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeMetadata implements SnapshotMetadata {
  const _FakeMetadata({this.isFromCache = false});
  @override
  final bool isFromCache;
  @override
  bool get hasPendingWrites => false;
}

/// A hand-rolled DocumentSnapshot double (see the file header for why).
class _FakeDocSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeDocSnapshot({required this.id, Map<String, dynamic>? data, bool fromCache = false})
      : _data = data,
        exists = data != null,
        metadata = _FakeMetadata(isFromCache: fromCache);

  @override
  final String id;
  final Map<String, dynamic>? _data;
  @override
  final bool exists;
  @override
  final SnapshotMetadata metadata;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  dynamic get(Object field) => _data?[field];

  @override
  dynamic operator [](Object field) => get(field);

  @override
  DocumentReference<Map<String, dynamic>> get reference => throw UnsupportedError('not read by RiderRouteCard');
}

/// A real LocationProvider is required (RiderRouteCard reads it directly);
/// its own native-service/permission plumbing is not this phase's concern,
/// so it is used exactly as its own existing tests construct it.
Widget _host(Widget child) => ChangeNotifierProvider<LocationProvider>(
      create: (_) => LocationProvider(),
      child: MaterialApp(
        theme: WorkspaceTheme.build(WorkspaceBrand.delivery, Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

Map<String, dynamic> _task({
  String status = 'assigned',
  Map<String, dynamic>? pickup,
  Map<String, dynamic>? drop,
}) => {
      'orderId': 'o1',
      'status': status,
      if (pickup != null) 'pickup': pickup,
      if (drop != null) 'drop': drop,
    };

const _pickupMap = {'lat': 12.9, 'lng': 77.6, 'pincode': '560001'};
const _dropMap = {'lat': 12.95, 'lng': 77.65, 'pincode': '560002'};

class _Fixture {
  _Fixture()
      : taskCtrl = StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast(),
        riderCtrl = StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast();

  final StreamController<DocumentSnapshot<Map<String, dynamic>>> taskCtrl;
  final StreamController<DocumentSnapshot<Map<String, dynamic>>> riderCtrl;

  RiderRouteCard card({
    int stepIndex = 0,
    String? storeName,
    String? customerName,
    String? customerPhone,
  }) =>
      RiderRouteCard(
        orderId: 'o1',
        stepIndex: stepIndex,
        storeName: storeName,
        customerName: customerName,
        customerPhone: customerPhone,
        taskStream: taskCtrl.stream,
        riderStream: riderCtrl.stream,
      );

  void dispose() {
    taskCtrl.close();
    riderCtrl.close();
  }
}

void main() {
  testWidgets('loading: no task or position yet renders neither an error nor stale content', (t) async {
    final f = _Fixture();
    addTearDown(f.dispose);

    await t.pumpWidget(_host(f.card()));
    await t.pump();

    expect(find.text('Route information unavailable'), findsNothing);
    expect(find.text('Live position unavailable'), findsNothing);
  });

  testWidgets('missing pickup coordinates: the details view says so distinctly from loading', (t) async {
    final f = _Fixture();
    addTearDown(f.dispose);

    await t.pumpWidget(_host(f.card()));
    f.taskCtrl.add(_FakeDocSnapshot(id: 'o1', data: _task(status: 'assigned')));
    f.riderCtrl.add(_FakeDocSnapshot(id: 'rider', data: null));
    await t.pump();

    await t.tap(find.text('Details'));
    await t.pump();
    expect(find.text("Pickup location isn't available for this delivery."), findsOneWidget);
  });

  testWidgets('map and details show the same pickup -- never two divergent destinations', (t) async {
    final f = _Fixture();
    addTearDown(f.dispose);

    await t.pumpWidget(_host(f.card(storeName: 'Ravi Stores')));
    f.taskCtrl.add(_FakeDocSnapshot(id: 'o1', data: _task(status: 'assigned', pickup: _pickupMap)));
    f.riderCtrl.add(_FakeDocSnapshot(id: 'rider', data: null));
    await t.pump();
    expect(find.text('Head to the store'), findsOneWidget); // map headline, unchanged wording

    await t.tap(find.text('Details'));
    await t.pump();
    expect(find.text('Ravi Stores'), findsOneWidget);
    expect(find.text('560001'), findsOneWidget);
  });

  testWidgets('leg changes after pickup: details reflects the customer as the relevant stop', (t) async {
    final f = _Fixture();
    addTearDown(f.dispose);

    await t.pumpWidget(_host(f.card(stepIndex: 0, customerName: 'Priya')));
    f.taskCtrl.add(_FakeDocSnapshot(id: 'o1', data: _task(status: 'assigned', pickup: _pickupMap, drop: _dropMap)));
    f.riderCtrl.add(_FakeDocSnapshot(id: 'rider', data: null));
    await t.pump();
    await t.tap(find.text('Details'));
    await t.pump();
    expect(find.text('Head to the store'), findsOneWidget);

    await t.pumpWidget(_host(f.card(stepIndex: 2, customerName: 'Priya'))); // pickedUp
    await t.pump();
    expect(find.textContaining('Priya'), findsWidgets);
  });

  testWidgets('a task listener failure shows a distinct error with a working retry', (t) async {
    final f = _Fixture();
    addTearDown(f.dispose);

    await t.pumpWidget(_host(f.card()));
    f.taskCtrl.addError(FirebaseException(plugin: 'firestore', code: 'permission-denied'));
    await t.pump();

    expect(find.text('Route information unavailable'), findsOneWidget);
    expect(find.text("You may no longer have access to this delivery's route."), findsOneWidget);

    // A genuine retry resets to pending immediately -- before any new data
    // arrives -- which a no-op retry could never do (it would leave the
    // error banner showing, since nothing reset _taskStatus at all).
    await t.tap(find.text('Try again'));
    await t.pump();
    expect(find.text('Route information unavailable'), findsNothing);

    f.taskCtrl.add(_FakeDocSnapshot(id: 'o1', data: _task(status: 'assigned')));
    await t.pump();
    expect(find.text('Route information unavailable'), findsNothing);
  });

  testWidgets('a position listener failure does not hide otherwise-valid pickup details', (t) async {
    final f = _Fixture();
    addTearDown(f.dispose);

    await t.pumpWidget(_host(f.card(storeName: 'Ravi Stores')));
    f.taskCtrl.add(_FakeDocSnapshot(id: 'o1', data: _task(status: 'assigned', pickup: _pickupMap)));
    f.riderCtrl.addError(FirebaseException(plugin: 'firestore', code: 'unavailable'));
    await t.pump();

    expect(find.text('Live position unavailable'), findsOneWidget);
    await t.tap(find.text('Details'));
    await t.pump();
    expect(find.text('Ravi Stores'), findsOneWidget); // still shown despite the position error
  });

  testWidgets('cached data is labelled, not shown as if it were live', (t) async {
    final f = _Fixture();
    addTearDown(f.dispose);

    await t.pumpWidget(_host(f.card()));
    f.taskCtrl.add(_FakeDocSnapshot(id: 'o1', data: _task(status: 'assigned', pickup: _pickupMap), fromCache: true));
    f.riderCtrl.add(_FakeDocSnapshot(id: 'rider', data: null));
    await t.pump();

    await t.tap(find.text('Details'));
    await t.pump();
    expect(find.text('Offline · showing last known route'), findsOneWidget);
  });
}
