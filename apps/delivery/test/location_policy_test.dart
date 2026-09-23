// Phase DLV-3A — rider location cadence and the live-point payload, checked
// against what the server and the rules actually enforce.
import 'dart:io';

import 'package:delivery/location/location_policy.dart';
import 'package:flutter_test/flutter_test.dart';

int _msConst(String src, String name) {
  final m = RegExp('$name = ([0-9 *]+);').firstMatch(src)!;
  return m.group(1)!.split('*').map((s) => int.parse(s.trim())).reduce((a, b) => a * b);
}

void main() {
  final t0 = DateTime(2026, 9, 23, 12);

  group('cadence', () {
    test('first send always goes', () {
      expect(shouldUpload(now: t0, lastUploadAt: null, hasNewFix: false, profile: idleProfile), isTrue);
    });

    test('a new fix waits for the minimum gap', () {
      for (final p in [idleProfile, taskProfile]) {
        final justBefore = t0.add(p.minUploadGap - const Duration(seconds: 1));
        expect(shouldUpload(now: justBefore, lastUploadAt: t0, hasNewFix: true, profile: p), isFalse, reason: p.name);
        expect(shouldUpload(now: t0.add(p.minUploadGap), lastUploadAt: t0, hasNewFix: true, profile: p), isTrue, reason: p.name);
      }
    });

    test('standing still re-sends on the heartbeat', () {
      for (final p in [idleProfile, taskProfile]) {
        expect(shouldUpload(now: t0.add(p.heartbeat - const Duration(seconds: 1)), lastUploadAt: t0, hasNewFix: false, profile: p), isFalse, reason: p.name);
        expect(shouldUpload(now: t0.add(p.heartbeat), lastUploadAt: t0, hasNewFix: false, profile: p), isTrue, reason: p.name);
      }
    });

    test('an order switches to the faster profile', () {
      expect(profileFor(onOrder: true), same(taskProfile));
      expect(profileFor(onOrder: false), same(idleProfile));
      expect(taskProfile.minUploadGap, lessThanOrEqualTo(const Duration(seconds: 10)));
      expect(taskProfile.distanceFilterMeters, lessThanOrEqualTo(25));
      expect(idleProfile.heartbeat, lessThanOrEqualTo(const Duration(seconds: 60)));
    });

    test('heartbeats sit well inside dispatch freshness and the offline sweep', () {
      final dispatch = File('../../functions/src/delivery/dispatch.ts').readAsStringSync();
      final presence = File('../../functions/src/delivery/riderPresence.ts').readAsStringSync();
      final fresh = Duration(milliseconds: _msConst(dispatch, 'LOCATION_FRESHNESS_MS'));
      final silent = Duration(milliseconds: _msConst(presence, 'SILENT_OFFLINE_MS'));
      for (final p in [idleProfile, taskProfile]) {
        // At least three heartbeats before a location counts as stale.
        expect(p.heartbeat * 3, lessThanOrEqualTo(fresh), reason: p.name);
        expect(p.heartbeat * 3, lessThan(silent), reason: p.name);
      }
    });
  });

  group('live point', () {
    test('keys are exactly the rules allowlist (plus the server timestamp)', () {
      final rules = File('../../firestore.rules').readAsStringSync();
      final block = rules.substring(rules.indexOf('function livePointIsValid()'));
      final list = RegExp(r"hasOnly\(\[([^\]]*)\]\)").firstMatch(block)!.group(1)!;
      final allowed = RegExp(r"'([^']+)'").allMatches(list).map((m) => m.group(1)).toSet();
      final fields = livePointFields(riderId: 'r', lat: 1, lng: 2).keys.toSet()..add('at');
      expect(fields, allowed);
    });

    test('Android "no value" readings become null, not a refused write', () {
      final f = livePointFields(riderId: 'r', lat: 9.9, lng: 78.1, accuracy: 12, speed: -1, heading: -1);
      expect(f['speed'], isNull);
      expect(f['heading'], isNull);
      expect(f['accuracy'], 12);
      final g = livePointFields(riderId: 'r', lat: 9.9, lng: 78.1, speed: 150, heading: 361, accuracy: double.nan);
      expect(g['speed'], isNull);
      expect(g['heading'], isNull);
      expect(g['accuracy'], isNull);
      final h = livePointFields(riderId: 'r', lat: 9.9, lng: 78.1, speed: 8.5, heading: 360, isMocked: true);
      expect(h['speed'], 8.5);
      expect(h['heading'], 360);
      expect(h['isMocked'], isTrue);
    });

    test('only real coordinates are sent', () {
      expect(isValidFix(9.9, 78.1), isTrue);
      expect(isValidFix(91, 0), isFalse);
      expect(isValidFix(0, -181), isFalse);
      expect(isValidFix(double.nan, 0), isFalse);
    });
  });

  group('rider messages', () {
    test('every failure to go online says what to do', () {
      for (final r in GoOnlineResult.values) {
        final silent = r == GoOnlineResult.started || r == GoOnlineResult.disclosureDeclined;
        expect(r.message == null, silent, reason: r.name);
      }
      expect(GoOnlineResult.servicesOff.needsSettings, isTrue);
      expect(GoOnlineResult.permissionDeniedForever.needsSettings, isTrue);
      expect(GoOnlineResult.permissionDenied.needsSettings, isFalse);
    });

    test('the server sweep reason is explained; anything else stays quiet', () {
      final presence = File('../../functions/src/delivery/riderPresence.ts').readAsStringSync();
      expect(presence, contains('offlineReason: "no_location"'));
      expect(serverOfflineMessage('no_location'), contains('15 minutes'));
      expect(serverOfflineMessage(null), isNull);
      expect(serverOfflineMessage('other'), isNull);
    });

    test('the disclosure says background, purpose and how to stop', () {
      expect(locationDisclosureBody, contains('when the app is closed or not in use'));
      expect(locationDisclosureBody, contains('nearby orders'));
      expect(locationDisclosureBody, contains('go offline'));
    });
  });
}
