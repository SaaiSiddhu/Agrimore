import 'package:flutter/material.dart';

import '../ws_foundation.dart';
import '../ws_icons.dart';
import '../ws_tokens.dart';

/// Persistent notice shown while the server's phone-OTP test mode filled in
/// the code (Workspace kit, ADR §7 `WsTestModeRibbon`, Phase SEC-P0). Never
/// hidden in release builds: if a real user ever sees it, the allowlist is
/// wrong and they should know. Warning pair, icon + text (not colour alone).
class WsTestModeRibbon extends StatelessWidget {
  const WsTestModeRibbon({super.key, required this.label});

  /// Localised copy supplied by the app.
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.ws;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: WsSpace.s12, vertical: WsSpace.s8),
        decoration: BoxDecoration(
          color: t.warningBg,
          borderRadius: BorderRadius.circular(WsRadius.small),
          border: Border.all(color: t.warningFg, width: WsSize.hairline),
        ),
        child: Row(
          children: [
            Icon(AgIcons.warning, size: WsIconSize.supporting, color: t.warningFg),
            const SizedBox(width: WsSpace.s8),
            Expanded(
              child: Text(
                label,
                style: context.wsText.labelMedium!.copyWith(color: t.warningFg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
