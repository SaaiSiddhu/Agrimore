import 'package:flutter/material.dart';

import '../ws_foundation.dart';
import '../ws_tokens.dart';

/// A time-boxed decision (a delivery offer): a draining ring with the whole
/// seconds left in the middle. Turns to the error colour once [urgent].
class WsCountdownRing extends StatelessWidget {
  const WsCountdownRing({
    super.key,
    required this.fractionLeft,
    required this.secondsLeft,
    required this.unitLabel,
    this.urgent = false,
  });

  /// 1 → 0 as the time runs out.
  final double fractionLeft;
  final int secondsLeft;

  /// What the number counts ("seconds"), from the app's l10n.
  final String unitLabel;
  final bool urgent;

  static const double _size = 150;
  static const double _stroke = 10;
  static const double _numberSize = 44;

  @override
  Widget build(BuildContext context) {
    final t = context.ws;
    final text = Theme.of(context).textTheme;
    return SizedBox.square(
      dimension: _size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: fractionLeft.clamp(0, 1),
            strokeWidth: _stroke,
            backgroundColor: t.surfaceSunken,
            color: urgent ? t.errorFg : t.primary,
          ),
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                '$secondsLeft',
                style: text.displaySmall?.copyWith(
                  fontSize: _numberSize,
                  fontWeight: WsType.bold,
                  color: t.textPrimary,
                  fontFeatures: WsType.tabularFigures,
                ),
              ),
              Text(unitLabel, style: text.bodyMedium?.copyWith(color: t.textSecondary)),
            ]),
          ),
        ],
      ),
    );
  }
}
