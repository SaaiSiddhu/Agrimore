// lib/screens/home/home_app_bar.dart
//
// Phase DLVHOME1 — the redesigned, compact Home header: a left availability
// toggle (Online/Offline, wired straight through to DashboardScreen's own
// _toggleOnline — this widget owns no availability logic of its own) and
// three neutral circular icon buttons on the right (emergency, notifications,
// help), matching the owner-supplied reference's visual hierarchy. Replaces
// the old avatar+greeting header; Profile stays reachable only via its
// bottom-nav tab (brief: no header avatar unless the product requires one).
import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import '../../inbox/rider_inbox.dart';
import '../../l10n/app_localizations.dart';
import '../../safety/emergency_sheet.dart';
import '../inbox/inbox_screen.dart' show InboxButton;
import '../support/help_sheet.dart';

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HomeAppBar({
    super.key,
    required this.isOnline,
    required this.busy,
    required this.onToggle,
    required this.riderId,
    required this.inboxSource,
    required this.onOpenInbox,
  });

  final bool isOnline;
  final bool busy;
  final ValueChanged<bool> onToggle;
  final String riderId;
  final RiderInboxSource inboxSource;
  final VoidCallback onOpenInbox;

  @override
  Size get preferredSize => const Size.fromHeight(DeliverySize.control + DeliverySpace.lg * 2);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      color: c.background,
      padding: const EdgeInsets.symmetric(
        horizontal: DeliverySpace.page,
        vertical: DeliverySpace.lg,
      ),
      child: Row(
        children: [
          _AvailabilityToggle(isOnline: isOnline, busy: busy, onChanged: onToggle),
          const Spacer(),
          _CircleIconButton(
            valueKey: const ValueKey('home-appbar-emergency'),
            icon: DeliveryIcons.emergency,
            // DLVHOME1: the one deliberate place the restrained burnt-orange
            // accent survives, matching the reference's own SOS icon tint.
            iconColor: c.accent,
            tooltip: AppLocalizations.of(context).emergencyTitle,
            onTap: () => showEmergencySheet(context),
          ),
          const SizedBox(width: DeliverySpace.sm),
          _CircleIconButton(
            valueKey: const ValueKey('home-appbar-inbox'),
            child: InboxButton(
              riderId: riderId,
              source: inboxSource,
              onOpen: onOpenInbox,
            ),
          ),
          const SizedBox(width: DeliverySpace.sm),
          _CircleIconButton(
            valueKey: const ValueKey('home-appbar-help'),
            icon: DeliveryIcons.help,
            tooltip: AppLocalizations.of(context).profileSupport,
            onTap: () => showHelpSheet(context),
          ),
        ],
      ),
    );
  }
}

/// Compact left-side pill: real Online/Offline label, a Switch when idle, a
/// small spinner in place of the switch while [busy] — never shows Online
/// while the underlying go-online/go-offline call is still pending or has
/// failed, matching DashboardScreen's own _isOnline (only flips on
/// confirmation) and _toggling state exactly, not a locally-optimistic copy.
class _AvailabilityToggle extends StatelessWidget {
  const _AvailabilityToggle({
    required this.isOnline,
    required this.busy,
    required this.onChanged,
  });

  final bool isOnline;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    final label = isOnline ? l.homeAvailabilityOnline : l.homeAvailabilityOffline;
    return Semantics(
      toggled: isOnline,
      label: label,
      child: ExcludeSemantics(
        child: Container(
          key: const ValueKey('home-appbar-availability'),
          height: DeliverySize.touchTarget,
          padding: const EdgeInsets.only(left: DeliverySpace.md, right: DeliverySpace.xs),
          decoration: BoxDecoration(
            color: c.surfaceMuted,
            borderRadius: DeliveryRadius.rFull,
            border: Border.all(color: c.border, width: DeliverySize.hairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                // t.labelLarge is already semibold -- no extra literal
                // fontWeight override needed for "stronger text".
                label,
                style: t.labelLarge.copyWith(
                  color: isOnline ? c.onlineFg : c.textSecondary,
                ),
              ),
              const SizedBox(width: DeliverySpace.sm),
              if (busy)
                const SizedBox(
                  width: DeliverySpace.xxl,
                  height: DeliverySpace.xxl,
                  child: Padding(
                    padding: EdgeInsets.all(DeliverySpace.s4),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                Switch(value: isOnline, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

/// Neutral 48dp circular icon surface shared by the emergency, notification
/// and help buttons, matching the reference's uniform right-hand-side icon
/// row. Either [icon]+[onTap], or a pre-built [child] (InboxButton, which
/// owns its own IconButton/tooltip/badge and must not be double-wrapped).
class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.valueKey,
    this.icon,
    this.iconColor,
    this.tooltip,
    this.onTap,
    this.child,
  }) : assert(child != null || (icon != null && onTap != null));

  final Key valueKey;
  final IconData? icon;
  final Color? iconColor;
  final String? tooltip;
  final VoidCallback? onTap;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      key: valueKey,
      width: DeliverySize.touchTarget,
      height: DeliverySize.touchTarget,
      decoration: BoxDecoration(color: c.surfaceMuted, shape: BoxShape.circle),
      child: child ??
          IconButton(
            tooltip: tooltip,
            onPressed: onTap,
            icon: Icon(icon, color: iconColor ?? c.textPrimary),
          ),
    );
  }
}
