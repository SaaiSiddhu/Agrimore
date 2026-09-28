import 'package:flutter/widgets.dart';

/// Motion durations and curves for the Delivery Partner app (Phases 02, 32).
/// Respects system reduced-motion preferences (`MediaQuery.maybeDisableAnimationsOf`).
abstract final class DeliveryMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration standardDuration = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 320);
  static const Duration pulse = Duration(milliseconds: 900);

  /// 1-second countdown tick for live offer SLA rings.
  static const Duration tick = Duration(seconds: 1);
  static const Duration countdownTick = tick;

  /// 5-second GPS fix timeout for emergency incident snapshots.
  static const Duration locationTimeout = Duration(seconds: 5);

  /// 10-second bound on a push-token registration attempt (DLVC3) --
  /// `FirebaseMessaging.getToken()` can hang indefinitely on some devices/
  /// emulators rather than throw; registration is already fire-and-forget
  /// everywhere it's called, so this only bounds how long ONE attempt can
  /// leave a rider's device unregistered before falling back to "try again
  /// next opportunity", the same outcome an ordinary failure already has.
  static const Duration pushTokenTimeout = Duration(seconds: 10);

  /// Duration a confirmation toast remains visible.
  static const Duration toast = Duration(seconds: 4);

  /// Debounce delay for local search inputs.
  static const Duration debounce = Duration(milliseconds: 300);

  /// How long "not yet seen live" (active_order_screen.dart) is treated as
  /// still-checking before concluding an assignment was genuinely removed --
  /// covers the gap between an offer's one-off accept read and the live
  /// query catching up with the same new order (the golden path must never
  /// flash "removed").
  static const Duration assignmentConfirmGrace = Duration(seconds: 8);

  /// Below this (rider_route_card.dart), the rider's live position is shown
  /// as stale. Matches riderIncidents.ts's own FRESH_LOCATION_MS server-side
  /// constant for consistency (a position is "fresh" by the same definition
  /// whether the context is a safety incident or an active-delivery map) --
  /// independent client/server constants, not a shared import.
  static const Duration staleLocationThreshold = Duration(minutes: 2);

  /// Re-evaluate staleness on a timer, not only on a new Firestore event --
  /// the whole point is to notice when NOTHING has arrived in a while.
  static const Duration staleLocationCheckInterval = Duration(seconds: 30);

  static const Curve standard = Cubic(0.2, 0, 0, 1);
  static const Curve standardCurve = standard;
  static const Curve enter = Cubic(0, 0, 0, 1);
  static const Curve exit = Cubic(0.3, 0, 1, 1);
}

extension DeliveryMotionContext on BuildContext {
  /// True when the OS requests reduced motion ("Remove animations" / "Reduce Motion").
  bool get reduceMotion => MediaQuery.maybeDisableAnimationsOf(this) ?? false;

  /// Returns [duration], or [Duration.zero] when reduced motion is enabled.
  Duration motion(Duration duration) => reduceMotion ? Duration.zero : duration;
}
