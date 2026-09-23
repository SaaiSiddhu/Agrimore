import 'package:flutter/material.dart';

import '../ws_foundation.dart';
import '../ws_icons.dart';
import '../ws_tokens.dart';

/// State of one [WsTimeline] step.
enum WsTimelineState { done, current, upcoming }

/// One step: a title, an optional caption (e.g. a timestamp) and its state.
@immutable
class WsTimelineStep {
  const WsTimelineStep({required this.title, required this.state, this.caption});
  final String title;
  final String? caption;
  final WsTimelineState state;
}

/// Vertical status timeline (Workspace kit, ADR §7 `WsTimeline`) — used for
/// seller applications, order status and payouts. Colour is never the only
/// signal: done steps carry a check icon, the current step a filled ring.
class WsTimeline extends StatelessWidget {
  const WsTimeline({super.key, required this.steps});

  final List<WsTimelineStep> steps;

  @override
  Widget build(BuildContext context) {
    final t = context.ws;
    final text = context.wsText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: WsIconSize.feature,
                  child: Column(
                    children: [
                      _Marker(state: steps[i].state, tokens: t),
                      if (i < steps.length - 1)
                        Expanded(
                          child: Container(
                            width: WsSize.focusRing,
                            margin: const EdgeInsets.symmetric(vertical: WsSpace.s4),
                            color: steps[i].state == WsTimelineState.done ? t.primary : t.divider,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: WsSpace.s12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: WsSpace.s4,
                      bottom: i < steps.length - 1 ? WsSpace.s24 : 0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i].title,
                          style: text.titleSmall!.copyWith(
                            color: steps[i].state == WsTimelineState.upcoming
                                ? t.textSecondary
                                : t.textPrimary,
                          ),
                        ),
                        if (steps[i].caption != null) ...[
                          const SizedBox(height: WsSpace.s2),
                          Text(steps[i].caption!, style: text.bodySmall),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Marker extends StatelessWidget {
  const _Marker({required this.state, required this.tokens});
  final WsTimelineState state;
  final WorkspaceTokens tokens;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    switch (state) {
      case WsTimelineState.done:
        return Container(
          width: WsIconSize.feature,
          height: WsIconSize.feature,
          decoration: BoxDecoration(color: t.primary, shape: BoxShape.circle),
          child: Icon(AgIcons.success, size: WsIconSize.control, color: t.onPrimary),
        );
      case WsTimelineState.current:
        return Container(
          width: WsIconSize.feature,
          height: WsIconSize.feature,
          decoration: BoxDecoration(
            color: t.primarySubtle,
            shape: BoxShape.circle,
            border: Border.all(color: t.primary, width: WsSize.focusRing),
          ),
          child: Icon(AgIcons.clock, size: WsIconSize.supporting, color: t.primary),
        );
      case WsTimelineState.upcoming:
        return Container(
          width: WsIconSize.feature,
          height: WsIconSize.feature,
          decoration: BoxDecoration(
            color: t.surface,
            shape: BoxShape.circle,
            border: Border.all(color: t.divider, width: WsSize.focusRing),
          ),
        );
    }
  }
}
