// lib/screens/orders/widgets/route_recovery.dart
//
// Phase DLVACC1 — explicit health tracking for RiderRouteCard's two
// Firestore streams (the delivery task, the rider's own live position),
// replacing `onError: (e) => debugPrint(...)`, which left no state at all
// for the UI to react to. Pure: no Firebase, no widget -- covered by
// test/route_recovery_test.dart.
//
// Firestore's `snapshots()` does not always resubscribe itself after
// onError fires (a `permission-denied` is terminal for that subscription
// instance); a genuine retry means cancelling and re-listening, which is
// why this tracks health as explicit, settable state rather than inferring
// everything from whether the last-known data happens to be null.
//
// Deliberately not one page-level state machine that hides everything at
// once: a task error blocks the details view (pickup/drop/leg are all
// task-derived), but a position error does not -- it only means the "how
// far along" figure is unavailable, so callers show it as its own smaller
// notice alongside a still-usable leg.
enum StreamHealth { pending, ok, error }

/// One Firestore listener's current health. [code] is the
/// FirebaseException.code when [health] is [StreamHealth.error].
class StreamStatus {
  const StreamStatus._(this.health, this.code, this.fromCache);

  const StreamStatus.pending() : this._(StreamHealth.pending, null, false);
  const StreamStatus.ok({bool fromCache = false}) : this._(StreamHealth.ok, null, fromCache);
  const StreamStatus.error(String? code) : this._(StreamHealth.error, code, false);

  final StreamHealth health;
  final String? code;
  final bool fromCache;

  bool get isPermissionDenied => code == 'permission-denied';
}
