// DLVACC1: StreamStatus is deliberately tiny and pure -- these tests exist
// mostly to lock its construction/access semantics, since the real coverage
// of "what a stream error does to the UI" lives in
// rider_route_card_test.dart where it actually drives the widget.
import 'package:delivery/screens/orders/widgets/route_recovery.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StreamStatus', () {
    test('pending is neither ok nor an error', () {
      const s = StreamStatus.pending();
      expect(s.health, StreamHealth.pending);
      expect(s.code, isNull);
      expect(s.fromCache, isFalse);
      expect(s.isPermissionDenied, isFalse);
    });

    test('ok carries whether the data came from cache', () {
      const fromCache = StreamStatus.ok(fromCache: true);
      const live = StreamStatus.ok();
      expect(fromCache.health, StreamHealth.ok);
      expect(fromCache.fromCache, isTrue);
      expect(live.fromCache, isFalse);
    });

    test('error carries the FirebaseException code when known', () {
      const denied = StreamStatus.error('permission-denied');
      const unknown = StreamStatus.error(null);
      expect(denied.health, StreamHealth.error);
      expect(denied.isPermissionDenied, isTrue);
      expect(unknown.isPermissionDenied, isFalse);
    });
  });
}
