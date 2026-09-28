import 'package:flutter/material.dart';

import '../icons/delivery_icons.dart';
import '../tokens/delivery_colors.dart';
import '../tokens/delivery_tokens.dart';
import '../tokens/delivery_typography.dart';
import 'delivery_badge.dart';

/// Destination item for [DeliveryBottomNav].
class DeliveryNavDestination {
  const DeliveryNavDestination({
    required this.label,
    required this.icon,
    this.selectedIcon,
    this.badgeCount = 0,
  });

  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final int badgeCount;
}

/// The 5-tab bottom navigation bar (`Home`, `Deliveries`, `Earnings`,
/// `Inbox`, `Profile` — see `DeliveryShell`). DLVHOME1: no pill/rectangle
/// indicator behind the selected icon — selection reads from icon/label
/// colour (monochrome `primary`) and bold label weight alone, plus tabular
/// badge counts.
class DeliveryBottomNav extends StatelessWidget {
  const DeliveryBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.destinations,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<DeliveryNavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(
          top: BorderSide(color: c.border, width: DeliverySize.stroke),
        ),
        boxShadow: DeliveryElevation.stickyBottom(c.shadow),
      ),
      child: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onTap,
        destinations: [
          for (final d in destinations)
            NavigationDestination(
              icon: _badgedIcon(c, d.icon, d.badgeCount),
              selectedIcon: _badgedIcon(
                c,
                d.selectedIcon ?? d.icon,
                d.badgeCount,
                selected: true,
              ),
              label: d.label,
            ),
        ],
      ),
    );
  }

  Widget _badgedIcon(
    DeliveryColors c,
    IconData icon,
    int count, {
    bool selected = false,
  }) {
    // DLVHOME1: no filled Lucide variant exists for any of the 5 nav icons
    // (Lucide is stroke-only) -- emphasis is colour (monochrome `primary`,
    // full-contrast) plus the bold label weight already applied in
    // delivery_theme.dart's navigationBarTheme, not a background shape.
    final iconWidget = Icon(
      icon,
      color: selected ? c.primary : c.textSecondary,
    );
    if (count <= 0) return iconWidget;
    return Badge.count(
      count: count,
      backgroundColor: c.danger.solid,
      textColor: c.danger.onSolid,
      child: iconWidget,
    );
  }
}

/// High-visibility Online / Offline duty header card used on the Rider
/// Dashboard. Pairs a semantic status badge, clear subtitle, and an accessible
/// [Switch] so existing widget tests (`find.byType(Switch)`) continue to pass.
class DeliveryOnlineSwitch extends StatelessWidget {
  const DeliveryOnlineSwitch({
    super.key,
    required this.isOnline,
    String? title,
    String? subtitle,
    String? onlineTitle,
    String? offlineTitle,
    String? onlineSubtitle,
    String? offlineSubtitle,
    required this.onChanged,
    bool busy = false,
    bool isLoading = false,
    this.onlineBadgeLabel = 'ONLINE',
    this.offlineBadgeLabel = 'OFFLINE',
  })  : _title = title,
        _subtitle = subtitle,
        _onlineTitle = onlineTitle,
        _offlineTitle = offlineTitle,
        _onlineSubtitle = onlineSubtitle,
        _offlineSubtitle = offlineSubtitle,
        busy = busy || isLoading;

  final bool isOnline;
  final String? _title;
  final String? _subtitle;
  final String? _onlineTitle;
  final String? _offlineTitle;
  final String? _onlineSubtitle;
  final String? _offlineSubtitle;
  final ValueChanged<bool>? onChanged;
  final bool busy;
  final String onlineBadgeLabel;
  final String offlineBadgeLabel;

  String get title =>
      _title ??
      (isOnline
          ? (_onlineTitle ?? onlineBadgeLabel)
          : (_offlineTitle ?? offlineBadgeLabel));

  String get subtitle =>
      _subtitle ??
      (isOnline ? (_onlineSubtitle ?? '') : (_offlineSubtitle ?? ''));

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final tone = isOnline ? DeliveryTone.success : DeliveryTone.neutral;
    final pair = c.tone(tone);

    return Container(
      padding: const EdgeInsets.all(DeliverySpace.lg),
      decoration: BoxDecoration(
        color: isOnline ? c.brandContainer : c.surface,
        borderRadius: DeliveryRadius.rXl,
        border: Border.all(
          color: isOnline ? c.brandBorder : c.borderStrong,
          width: DeliverySize.strokeStrong,
        ),
        boxShadow: DeliveryElevation.card(c.shadow),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isOnline ? c.brand : c.surfaceMuted,
              borderRadius: DeliveryRadius.rMd,
            ),
            alignment: Alignment.center,
            child: Icon(
              isOnline ? DeliveryIcons.online : DeliveryIcons.offline,
              size: DeliveryIconSize.lg,
              color: isOnline ? c.onBrand : c.textSecondary,
            ),
          ),
          const SizedBox(width: DeliverySpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    DeliveryBadge(
                      label: isOnline ? onlineBadgeLabel : offlineBadgeLabel,
                      tone: isOnline
                          ? DeliveryTone.success
                          : DeliveryTone.neutral,
                      showDot: true,
                    ),
                    if (busy) ...[
                      const SizedBox(width: DeliverySpace.sm),
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: pair.icon,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: DeliverySpace.xs),
                Text(
                  title,
                  style: t.titleMedium.copyWith(
                    color: isOnline ? c.onBrandContainer : c.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: t.bodySmall.copyWith(
                    color: isOnline
                        ? c.onBrandContainer.withValues(alpha: 0.85)
                        : c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: DeliverySpace.sm),
          Switch(
            value: isOnline,
            onChanged: busy ? null : onChanged,
          ),
        ],
      ),
    );
  }
}
