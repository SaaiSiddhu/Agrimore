import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// App mark + name, used at the top of every auth screen.
class AuthWordmark extends StatelessWidget {
  const AuthWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.ws;
    final text = context.wsText;
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Container(
          width: WsSize.avatarMd,
          height: WsSize.avatarMd,
          decoration: BoxDecoration(color: t.primary, borderRadius: BorderRadius.circular(WsRadius.input)),
          child: Icon(AgIcons.store, color: t.onPrimary, size: WsIconSize.nav),
        ),
        const SizedBox(width: WsSpace.s12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.appName, style: text.titleSmall),
              Text(l10n.appTagline, style: text.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

/// Left half of the auth layout on tablet and desktop (ADR §10.1 A-01):
/// brand surface with the three value propositions.
class AuthBrandPanel extends StatelessWidget {
  const AuthBrandPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.ws;
    final text = context.wsText;
    final l10n = AppLocalizations.of(context);
    final values = <(IconData, String)>[
      (AgIcons.orders, l10n.authValueOrders),
      (AgIcons.inventory, l10n.authValueStock),
      (AgIcons.bank, l10n.authValuePayments),
    ];
    return Container(
      color: t.primarySubtle,
      padding: const EdgeInsets.all(WsSpace.s48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AuthWordmark(),
          const SizedBox(height: WsSpace.s48),
          Text(l10n.authHeadline, style: text.displayLarge),
          const SizedBox(height: WsSpace.s32),
          for (final (icon, label) in values)
            Padding(
              padding: const EdgeInsets.only(bottom: WsSpace.s16),
              child: Row(
                children: [
                  Container(
                    width: WsSize.avatarMd,
                    height: WsSize.avatarMd,
                    decoration: BoxDecoration(color: t.surface, shape: BoxShape.circle),
                    child: Icon(icon, color: t.primary, size: WsIconSize.control),
                  ),
                  const SizedBox(width: WsSpace.s16),
                  Expanded(child: Text(label, style: text.bodyLarge)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
