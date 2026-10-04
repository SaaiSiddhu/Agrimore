@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';
import 'package:delivery/location/location_policy.dart';
import 'package:delivery/providers/location_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
// Installed endorsed SDK: actual channel serialization, synthetic OS replies.
// ignore: depend_on_referenced_packages
import 'package:geolocator_apple/geolocator_apple.dart';
// ignore: depend_on_referenced_packages
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

// No native GPS/device/permission grant/Firestore/provider network proof.
// Firebase stays uninitialized; the provider's upload catch makes no request.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('flutter.baseflow.com/geolocator_apple');
  const events = MethodChannel('flutter.baseflow.com/geolocator_updates_apple');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final originalGeo = GeolocatorPlatform.instance;
  late LocationProvider provider;
  late List<Map<dynamic, dynamic>> streams;
  late List<String> calls;
  late Future<Object?> Function(MethodCall) reply;
  late int cancellations;
  late bool disposed;
  Map<String, dynamic> fix(double lat) => Position(
          latitude: lat,
          longitude: 78,
          timestamp: DateTime.utc(2026, 10, 4),
          accuracy: 5,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0)
      .toJson();
  Future<void> flush() async {
    for (var i = 0; i < 3; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  void destroy() {
    if (!disposed) {
      provider.dispose();
      disposed = true;
    }
  }

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    SharedPreferences.setMockInitialValues(
        {'dlv3a_location_disclosure_accepted': true});
    GeolocatorPlatform.instance = GeolocatorApple();
    streams = [];
    calls = [];
    cancellations = 0;
    disposed = false;
    reply = (c) async => switch (c.method) {
          'isLocationServiceEnabled' => true,
          'checkPermission' ||
          'requestPermission' =>
            LocationPermission.whileInUse.index,
          'getCurrentPosition' || 'getLastKnownPosition' => fix(10),
          _ => throw StateError('Unexpected method ${c.method}')
        };
    messenger.setMockMethodCallHandler(methods, (c) async {
      calls.add(c.method);
      return reply(c);
    });
    messenger.setMockMethodCallHandler(events, (c) async {
      if (c.method == 'listen') {
        streams.add(Map.of(c.arguments as Map));
      } else if (c.method == 'cancel') {
        cancellations++;
      } else {
        throw StateError('Unexpected stream ${c.method}');
      }
      return null;
    });
    provider = LocationProvider();
  });
  tearDown(() async {
    destroy();
    await flush();
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockMethodCallHandler(events, null);
    GeolocatorPlatform.instance = originalGeo;
    debugDefaultTargetPlatformOverride = null;
  });
  test(
      'iOS SDK stream receives explicit background/indicator and unchanged sampling',
      () async {
    expect(await provider.startTracking('rider'), GoOnlineResult.started);
    await flush();
    expect(streams.single['allowBackgroundLocationUpdates'], true);
    expect(streams.single['showBackgroundLocationIndicator'], true);
    expect(streams.single['pauseLocationUpdatesAutomatically'], false);
    expect(streams.single['activityType'], ActivityType.otherNavigation.index);
    expect(streams.single['accuracy'], LocationAccuracy.high.index);
    expect(
        streams.single['distanceFilter'], samplingProfile.distanceFilterMeters);
    expect(calls, isNot(contains('requestPermission')));
  });
  test('source plist enables exactly location mode with existing privacy text',
      () {
    final p = File('ios/Runner/Info.plist').readAsStringSync();
    final m = RegExp(r'<key>UIBackgroundModes</key>\s*<array>(.*?)</array>',
            dotAll: true)
        .firstMatch(p);
    expect(m, isNotNull);
    expect(
        RegExp(r'<string>(.*?)</string>')
            .allMatches(m!.group(1)!)
            .map((x) => x.group(1))
            .toList(),
        ['location']);
    expect(p, contains('NSLocationAlwaysAndWhenInUseUsageDescription'));
    expect(p, contains('NSLocationWhenInUseUsageDescription'));
  });
  test('missing disclosure refuses before permission or GPS calls', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await provider.startTracking('rider'),
        GoOnlineResult.disclosureDeclined);
    await flush();
    expect(calls, isEmpty);
    expect(streams, isEmpty);
    expect(provider.isTracking, false);
  });
  test('denied permission cannot start a background stream', () async {
    reply = (c) async => switch (c.method) {
          'isLocationServiceEnabled' => true,
          'checkPermission' ||
          'requestPermission' =>
            LocationPermission.denied.index,
          _ => throw StateError('GPS after denial')
        };
    expect(
        await provider.startTracking('rider'), GoOnlineResult.permissionDenied);
    await flush();
    expect(streams, isEmpty);
    expect(provider.isTracking, false);
  });
  test('offline during pending initial fix cannot reactivate iOS', () async {
    final pending = Completer<Object?>(), entered = Completer<void>();
    final normal = reply;
    reply = (c) {
      if (c.method == 'getCurrentPosition') {
        entered.complete();
        return pending.future;
      }
      return normal(c);
    };
    final start = provider.startTracking('rider');
    await entered.future;
    provider.stopTracking();
    pending.complete(fix(10));
    expect(await start, GoOnlineResult.failed);
    await flush();
    expect(provider.isTracking, false);
    expect(provider.currentPosition, isNull);
    expect(streams, isEmpty);
  });
  test('dispose during pending initial fix cannot start or notify', () async {
    final pending = Completer<Object?>(), entered = Completer<void>();
    final normal = reply;
    reply = (c) {
      if (c.method == 'getCurrentPosition') {
        entered.complete();
        return pending.future;
      }
      return normal(c);
    };
    final start = provider.startTracking('rider');
    await entered.future;
    destroy();
    pending.complete(fix(10));
    expect(await start, GoOnlineResult.failed);
    await flush();
    expect(streams, isEmpty);
  });
  test('older iOS startup cannot overwrite newer rider point', () async {
    final pending = Completer<Object?>(), entered = Completer<void>();
    var first = true;
    final normal = reply;
    reply = (c) {
      if (c.method == 'getCurrentPosition' && first) {
        first = false;
        entered.complete();
        return pending.future;
      }
      return normal(c);
    };
    final old = provider.startTracking('old-rider');
    await entered.future;
    expect(await provider.startTracking('new-rider'), GoOnlineResult.started);
    await flush();
    pending.complete(fix(20));
    expect(await old, GoOnlineResult.failed);
    await flush();
    expect(provider.latitude, 10);
    expect(provider.isTracking, true);
    expect(streams.length, 1);
  });
  test('offline during permission read prevents later initial GPS', () async {
    final pending = Completer<Object?>(), entered = Completer<void>();
    final normal = reply;
    reply = (c) {
      if (c.method == 'checkPermission') {
        entered.complete();
        return pending.future;
      }
      return normal(c);
    };
    final start = provider.startTracking('rider');
    await entered.future;
    provider.stopTracking();
    pending.complete(LocationPermission.whileInUse.index);
    expect(await start, GoOnlineResult.failed);
    await flush();
    expect(calls, isNot(contains('getCurrentPosition')));
    expect(streams, isEmpty);
  });
  test('dispose during permission read cannot notify or request GPS', () async {
    final pending = Completer<Object?>(), entered = Completer<void>();
    final normal = reply;
    reply = (c) {
      if (c.method == 'checkPermission') {
        entered.complete();
        return pending.future;
      }
      return normal(c);
    };
    final start = provider.startTracking('rider');
    await entered.future;
    destroy();
    pending.complete(LocationPermission.whileInUse.index);
    expect(await start, GoOnlineResult.failed);
    await flush();
    expect(calls, isNot(contains('getCurrentPosition')));
    expect(streams, isEmpty);
  });
  test('offline during refresh rejects late point and success', () async {
    expect(await provider.startTracking('rider'), GoOnlineResult.started);
    await flush();
    final pending = Completer<Object?>(), entered = Completer<void>();
    final normal = reply;
    reply = (c) {
      if (c.method == 'getCurrentPosition') {
        entered.complete();
        return pending.future;
      }
      return normal(c);
    };
    final refresh = provider.refreshNow();
    await entered.future;
    provider.stopTracking();
    pending.complete(fix(20));
    expect(await refresh, false);
    expect(provider.latitude, 10);
    expect(provider.isTracking, false);
  });
  test('iOS pause keeps stream while offline cancels and resume stays offline',
      () async {
    expect(await provider.startTracking('rider'), GoOnlineResult.started);
    await flush();
    provider.didChangeAppLifecycleState(AppLifecycleState.paused);
    await flush();
    expect(streams.length, 1);
    expect(cancellations, 0);
    provider.stopTracking();
    await flush();
    expect(cancellations, 1);
    expect(provider.isTracking, false);
    provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await flush();
    expect(streams.length, 1);
  });
  test('Android fallback retains foreground notification and interval',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(await provider.startTracking('rider'), GoOnlineResult.started);
    await flush();
    expect(streams.single['timeInterval'],
        samplingProfile.streamInterval.inMilliseconds);
    expect(streams.single['foregroundNotificationConfig'], isA<Map>());
    expect(streams.single['allowBackgroundLocationUpdates'], isNull);
  });
  test('native Android UI stream remains generic and pauses/resumes', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    provider.attachToRunningService('rider');
    await flush();
    expect(streams.single['allowBackgroundLocationUpdates'], isNull);
    expect(streams.single['foregroundNotificationConfig'], isNull);
    provider.didChangeAppLifecycleState(AppLifecycleState.paused);
    await flush();
    expect(cancellations, 1);
    provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await flush();
    expect(streams.length, 2);
  });
}
