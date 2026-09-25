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

  /// Duration a confirmation toast remains visible.
  static const Duration toast = Duration(seconds: 4);

  /// Debounce delay for local search inputs.
  static const Duration debounce = Duration(milliseconds: 300);

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
