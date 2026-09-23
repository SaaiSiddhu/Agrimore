import 'package:flutter/material.dart';

import '../ws_foundation.dart';
import '../ws_tokens.dart';

/// Header of a multi-step flow (Workspace kit, ADR §7 `WsStepper`):
/// "Step 2 of 5" overline, the step title, and a segmented progress bar.
/// The caller supplies localised copy.
class WsStepHeader extends StatelessWidget {
  const WsStepHeader({
    super.key,
    required this.stepLabel,
    required this.title,
    required this.current,
    required this.total,
  });

  /// e.g. "Step 2 of 5" (localised by the caller).
  final String stepLabel;
  final String title;

  /// Zero-based index of the current step.
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final t = context.ws;
    final text = context.wsText;
    return Semantics(
      header: true,
      label: '$stepLabel. $title',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (var i = 0; i < total; i++) ...[
                if (i > 0) const SizedBox(width: WsSpace.s4),
                Expanded(
                  child: AnimatedContainer(
                    duration: WsMotion.standard,
                    curve: WsMotion.curveStandard,
                    height: WsSpace.s4,
                    decoration: BoxDecoration(
                      color: i <= current ? t.primary : t.primaryMuted,
                      borderRadius: BorderRadius.circular(WsRadius.pill),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: WsSpace.s16),
          Text(stepLabel.toUpperCase(), style: text.labelSmall!.copyWith(color: t.primary)),
          const SizedBox(height: WsSpace.s4),
          Text(title, style: text.headlineMedium),
        ],
      ),
    );
  }
}
