import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Sticky footer of every application step: Back (when not first) and the
/// primary action (Save and continue / Submit).
class StepFooter extends StatelessWidget {
  const StepFooter({
    super.key,
    required this.primaryLabel,
    required this.busyLabel,
    required this.busy,
    required this.onPrimary,
    this.onBack,
  });

  final String primaryLabel;
  final String busyLabel;
  final bool busy;
  final VoidCallback? onPrimary;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.divider, width: WsSize.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(WsSpace.page, WsSpace.s12, WsSpace.page, WsSpace.s12),
          child: Row(
            children: [
              if (onBack != null) ...[
                Expanded(
                  child: SaLoadingButton(
                    text: l10n.back,
                    variant: SaButtonVariant.outlined,
                    onPressed: busy ? null : onBack,
                  ),
                ),
                const SizedBox(width: WsSpace.s12),
              ],
              Expanded(
                flex: 2,
                child: SaLoadingButton(
                  text: primaryLabel,
                  loadingText: busyLabel,
                  isLoading: busy,
                  onPressed: busy ? null : onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
