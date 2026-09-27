// DLVOA1: currentDeviceReadiness always reads live state, never a
// "prompted once" flag. Under flutter_test the host is never Android, so
// every platform-channel-backed item (notifications, full-screen alert,
// background location, battery) is expected to report ready/not-actionable
// -- proving they never wrongly nag on an unsupported platform. The one
// item this suite can actually flip both ways is location, via its
// injected hasLocationPermission callback.
import 'package:delivery/offers/device_readiness.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns exactly the five documented concerns, in a stable order', () async {
    final items = await currentDeviceReadiness();
    expect(items.map((e) => e.id).toList(), [
      ReadinessItemId.notifications,
      ReadinessItemId.fullScreenAlert,
      ReadinessItemId.location,
      ReadinessItemId.backgroundLocation,
      ReadinessItemId.battery,
    ]);
  });

  test('platform-channel-backed items are ready and not actionable off Android', () async {
    final items = await currentDeviceReadiness();
    final byId = {for (final i in items) i.id: i};
    expect(byId[ReadinessItemId.notifications]!.ready, isTrue);
    expect(byId[ReadinessItemId.fullScreenAlert]!.ready, isTrue);
    expect(byId[ReadinessItemId.fullScreenAlert]!.actionable, isFalse);
    expect(byId[ReadinessItemId.backgroundLocation]!.ready, isTrue);
    expect(byId[ReadinessItemId.backgroundLocation]!.actionable, isFalse);
    expect(byId[ReadinessItemId.battery]!.ready, isTrue);
    expect(byId[ReadinessItemId.battery]!.actionable, isFalse);
  });

  test('location defaults to ready when no check is injected', () async {
    final items = await currentDeviceReadiness();
    final location = items.firstWhere((i) => i.id == ReadinessItemId.location);
    expect(location.ready, isTrue);
    expect(location.actionable, isTrue);
  });

  test('location reflects the injected check: granted', () async {
    final items = await currentDeviceReadiness(
      hasLocationPermission: () async => true,
    );
    final location = items.firstWhere((i) => i.id == ReadinessItemId.location);
    expect(location.ready, isTrue);
  });

  test('location reflects the injected check: not granted', () async {
    final items = await currentDeviceReadiness(
      hasLocationPermission: () async => false,
    );
    final location = items.firstWhere((i) => i.id == ReadinessItemId.location);
    expect(location.ready, isFalse);
    expect(location.actionable, isTrue);
  });
}
