import 'package:flutter/widgets.dart';

/// Motion (board 02: fast 120 · standard 200 · slow 320 ms, ease-out
/// cubic(0.2, 0, 0, 1); reduced motion = 0 ms — board 24-05).
abstract final class SellerMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration standard = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 320);

  /// How long a transient confirmation stays on screen.
  static const Duration toast = Duration(seconds: 4);

  /// Delay before a search query runs while typing.
  static const Duration debounce = Duration(milliseconds: 300);

  static const Curve standardCurve = Cubic(0.2, 0, 0, 1);
  static const Curve enter = Cubic(0, 0, 0, 1);
  static const Curve exit = Cubic(0.3, 0, 1, 1);
}

extension SellerMotionContext on BuildContext {
  /// True when the device asks for reduced motion (Android "Remove animations",
  /// iOS "Reduce Motion").
  bool get reduceMotion => MediaQuery.maybeDisableAnimationsOf(this) ?? false;

  /// [duration], or zero when reduced motion is on.
  Duration motion(Duration duration) => reduceMotion ? Duration.zero : duration;
}
