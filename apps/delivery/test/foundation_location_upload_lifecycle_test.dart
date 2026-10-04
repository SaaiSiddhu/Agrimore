@TestOn('vm')
library;

import 'dart:async';
import 'package:delivery/location/location_policy.dart';
import 'package:delivery/providers/location_provider.dart';
import 'package:firebase_core/firebase_core.dart';
// Installed official SDK harness; synthetic host replies, no network.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
// ignore: depend_on_referenced_packages
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart'
    as fs;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
// ignore: depend_on_referenced_packages
import 'package:geolocator_apple/geolocator_apple.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Mirrors the existing marketplace SDK request fixture codec. Native request
// FieldValue/FieldPath tags are not decoded by the public reply codec.
class _WriteRequestCodec extends StandardMessageCodec {
  const _WriteRequestCodec();
  @override
  Object? readValueOfType(int type, ReadBuffer buffer) {
    switch (type) {
      case 130:
        return fs.DocumentReferenceRequest.decode(readValue(buffer)!);
      case 131:
        return fs.FirestorePigeonFirebaseApp.decode(readValue(buffer)!);
      case 135:
        return fs.PigeonFirebaseSettings.decode(readValue(buffer)!);
      case 188:
        return fs.Timestamp(buffer.getInt64(), buffer.getInt32());
      case 187:
        return 'fixture_server_timestamp';
      case 190:
        return readValue(buffer);
      case 192:
        final count = readSize(buffer);
        return List<String>.generate(count, (_) => readValue(buffer)! as String)
            .join('.');
      default:
        return super.readValueOfType(type, buffer);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  const methods = MethodChannel('flutter.baseflow.com/geolocator_apple');
  const events = MethodChannel('flutter.baseflow.com/geolocator_updates_apple');
  const updateChannel =
      'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceUpdate';
  const setChannel =
      'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceSet';
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final originalGeo = GeolocatorPlatform.instance;
  late LocationProvider provider;
  late bool disposed;
  late List<fs.DocumentReferenceRequest> updates, points;
  late Future<void> Function(fs.DocumentReferenceRequest) onUpdate, onPoint;
  late double latitude;
  Future<void> flush() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  void destroy() {
    if (!disposed) {
      provider.dispose();
      disposed = true;
    }
  }

  setUpAll(() async {
    await Firebase.initializeApp();
  });
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    SharedPreferences.setMockInitialValues(
        {'dlv3a_location_disclosure_accepted': true});
    GeolocatorPlatform.instance = GeolocatorApple();
    updates = [];
    points = [];
    disposed = false;
    latitude = 10;
    onUpdate = (_) async {};
    onPoint = (_) async {};
    messenger.setMockMethodCallHandler(
        methods,
        (c) async => switch (c.method) {
              'isLocationServiceEnabled' => true,
              'checkPermission' ||
              'requestPermission' =>
                LocationPermission.whileInUse.index,
              'getCurrentPosition' || 'getLastKnownPosition' => Position(
                      latitude: latitude,
                      longitude: 78,
                      timestamp: DateTime.utc(2026, 10, 4),
                      accuracy: 5,
                      altitude: 0,
                      altitudeAccuracy: 0,
                      heading: 0,
                      headingAccuracy: 0,
                      speed: 0,
                      speedAccuracy: 0)
                  .toJson(),
              _ => throw StateError('Unexpected GPS method ${c.method}')
            });
    messenger.setMockMethodCallHandler(events, (c) async => null);
    messenger.setMockMessageHandler(updateChannel, (message) async {
      final args = const _WriteRequestCodec().decodeMessage(message) as List;
      final request = args[1] as fs.DocumentReferenceRequest;
      updates.add(request);
      await onUpdate(request);
      return fs.FirebaseFirestoreHostApi.codec.encodeMessage([null]);
    });
    messenger.setMockMessageHandler(setChannel, (message) async {
      final args = const _WriteRequestCodec().decodeMessage(message) as List;
      final request = args[1] as fs.DocumentReferenceRequest;
      points.add(request);
      await onPoint(request);
      return fs.FirebaseFirestoreHostApi.codec.encodeMessage([null]);
    });
    provider = LocationProvider();
  });
  tearDown(() async {
    destroy();
    await flush();
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockMethodCallHandler(events, null);
    messenger.setMockMessageHandler(updateChannel, null);
    messenger.setMockMessageHandler(setChannel, null);
    GeolocatorPlatform.instance = originalGeo;
    debugDefaultTargetPlatformOverride = null;
  });
  test('owned upload retains partner and both task payloads', () async {
    provider.setActiveOrders(['one', 'two']);
    expect(await provider.startTracking('rider_a'), GoOnlineResult.started);
    expect(updates.single.path, 'delivery_partners/rider_a');
    expect(updates.single.data!['currentLat'], 10);
    expect(points.map((r) => r.path),
        ['delivery_tasks/one/live/rider', 'delivery_tasks/two/live/rider']);
    for (final p in points) {
      expect(p.data!['riderId'], 'rider_a');
      expect(p.data!['lat'], 10);
      expect(p.data!['at'], 'fixture_server_timestamp');
    }
    expect(provider.lastUploadAt, isNotNull);
    expect(await provider.startTracking('rider_a'), GoOnlineResult.started);
    expect(updates, hasLength(1));
  });
  test('offline during partner write prevents tasks and late freshness',
      () async {
    final entered = Completer<void>(), release = Completer<void>();
    onUpdate = (_) async {
      if (!entered.isCompleted) entered.complete();
      await release.future;
    };
    provider.setActiveOrders(['one']);
    final start = provider.startTracking('rider_a');
    await entered.future;
    provider.stopTracking();
    release.complete();
    expect(await start, GoOnlineResult.failed);
    expect(points, isEmpty);
    expect(provider.lastUploadAt, isNull);
    expect(provider.isTracking, false);
  });
  test('dispose during partner write prevents tasks and late notification',
      () async {
    final entered = Completer<void>(), release = Completer<void>();
    onUpdate = (_) async {
      if (!entered.isCompleted) entered.complete();
      await release.future;
    };
    provider.setActiveOrders(['one']);
    final start = provider.startTracking('rider_a');
    await entered.future;
    destroy();
    release.complete();
    expect(await start, GoOnlineResult.failed);
    expect(points, isEmpty);
    expect(provider.lastUploadAt, isNull);
  });
  test('old upload never targets the newer rider order list', () async {
    final entered = Completer<void>(), release = Completer<void>();
    onUpdate = (_) async {
      if (!entered.isCompleted) entered.complete();
      await release.future;
    };
    provider.setActiveOrders(['old_order']);
    final old = provider.startTracking('rider_a');
    await entered.future;
    provider.stopTracking();
    provider.setActiveOrders(['new_order']);
    latitude = 20;
    expect(await provider.startTracking('rider_b'), GoOnlineResult.started);
    release.complete();
    expect(await old, GoOnlineResult.failed);
    expect(points, isEmpty);
    expect(provider.lastUploadAt, isNull);
    expect(provider.latitude, 20);
    expect(provider.isTracking, true);
    onUpdate = (_) async {};
    expect(await provider.refreshNow(), true);
    expect(updates.last.path, 'delivery_partners/rider_b');
    expect(points.single.path, 'delivery_tasks/new_order/live/rider');
    expect(points.single.data!['riderId'], 'rider_b');
  });
  test('task reassignment during partner write excludes new and removed tasks',
      () async {
    final entered = Completer<void>(), release = Completer<void>();
    onUpdate = (_) async {
      if (!entered.isCompleted) entered.complete();
      await release.future;
    };
    provider.setActiveOrders(['removed', 'retained']);
    final start = provider.startTracking('rider_a');
    await entered.future;
    provider.setActiveOrders(['retained', 'added']);
    release.complete();
    expect(await start, GoOnlineResult.started);
    expect(points.map((r) => r.path), ['delivery_tasks/retained/live/rider']);
  });
  test('offline while first task is pending prevents additional task requests',
      () async {
    final entered = Completer<void>(), release = Completer<void>();
    onPoint = (_) async {
      if (!entered.isCompleted) entered.complete();
      await release.future;
    };
    provider.setActiveOrders(['one', 'two']);
    final start = provider.startTracking('rider_a');
    await entered.future;
    provider.stopTracking();
    release.complete();
    expect(await start, GoOnlineResult.failed);
    expect(points.map((r) => r.path), ['delivery_tasks/one/live/rider']);
    expect(provider.lastUploadAt, isNull);
  });
  test('dispose while first task is pending prevents additional task requests',
      () async {
    final entered = Completer<void>(), release = Completer<void>();
    onPoint = (_) async {
      if (!entered.isCompleted) entered.complete();
      await release.future;
    };
    provider.setActiveOrders(['one', 'two']);
    final start = provider.startTracking('rider_a');
    await entered.future;
    destroy();
    release.complete();
    expect(await start, GoOnlineResult.failed);
    expect(points.map((r) => r.path), ['delivery_tasks/one/live/rider']);
  });
  test('failed partner write retains tracking and allows owned refresh retry',
      () async {
    var first = true;
    onUpdate = (_) async {
      if (first) {
        first = false;
        throw PlatformException(code: 'unavailable');
      }
    };
    provider.setActiveOrders(['one']);
    expect(await provider.startTracking('rider_a'), GoOnlineResult.started);
    expect(provider.lastUploadAt, isNull);
    expect(points, isEmpty);
    expect(await provider.refreshNow(), true);
    expect(updates, hasLength(2));
    expect(points.single.data!['riderId'], 'rider_a');
    expect(provider.lastUploadAt, isNotNull);
  });
  for (final dispose in [false, true]) {
    test(
        'refresh pending partner write rejects late success after ${dispose ? "dispose" : "offline"}',
        () async {
      provider.setActiveOrders(['one']);
      expect(await provider.startTracking('rider_a'), GoOnlineResult.started);
      points.clear();
      final entered = Completer<void>(), release = Completer<void>();
      onUpdate = (_) async {
        if (!entered.isCompleted) entered.complete();
        await release.future;
      };
      latitude = 20;
      final refresh = provider.refreshNow();
      await entered.future;
      if (dispose) {
        destroy();
      } else {
        provider.stopTracking();
      }
      release.complete();
      expect(await refresh, false);
      expect(points, isEmpty);
      if (!dispose) expect(provider.lastUploadAt, isNull);
    });
  }
}
