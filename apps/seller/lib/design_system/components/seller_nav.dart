import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../icons/seller_icons.dart';
import '../theme/seller_focus.dart';
import '../tokens/seller_colors.dart';
import '../tokens/seller_tokens.dart';
import '../tokens/seller_typography.dart';

/// One root destination.
@immutable
class SellerNavItem {
  const SellerNavItem({required this.icon, required this.label, this.badgeCount = 0, this.semanticLabel});
  final IconData icon;
  final String label;
  final int badgeCount;

  /// Full spoken name, e.g. "Orders, 3 need action".
  final String? semanticLabel;
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.index,
    required this.count,
  });

  final SellerNavItem item;
  final bool selected;
  final VoidCallback onTap;
  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final l10n = AppLocalizations.of(context);
    final pillFill = selected ? (c.isDark ? c.primary : c.primaryContainer) : Colors.transparent;
    final iconColor = selected ? (c.isDark ? c.onPrimary : c.primary) : c.textSecondary;
    final labelColor = selected ? c.primary : c.textSecondary;
    return SellerFocusTracker(
      builder: (context, focused, node) {
        Widget icon = Icon(item.icon, size: SellerIconSize.lg, color: iconColor);
        if (item.badgeCount > 0) {
          icon = Badge(
            backgroundColor: item.badgeCount > 99 ? c.dangerFill : c.primaryStrong,
            textColor: c.onPrimary,
            label: Text(item.badgeCount > 99 ? '99+' : '${item.badgeCount}', style: text.labelSmall!.copyWith(color: c.onPrimary).tabular),
            child: icon,
          );
        }
        return Semantics(
          button: true,
          selected: selected,
          label: item.semanticLabel ?? item.label,
          hint: l10n.dsTabPosition(index + 1, count),
          excludeSemantics: true,
          onTap: onTap,
          child: InkWell(
            focusNode: node,
            onTap: onTap,
            customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SellerRadius.control)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: SellerSize.navBar, minWidth: SellerSize.touchTarget),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: SellerSpace.s8, horizontal: SellerSpace.s2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: SellerSize.navIndicatorWidth,
                      height: SellerSize.navIndicatorHeight,
                      decoration: ShapeDecoration(
                        color: pillFill,
                        shape: StadiumBorder(
                          side: sellerOutline(
                            c,
                            focused: focused,
                            rest: Colors.transparent,
                            focusColor: selected && c.isDark ? c.focusOnFill : c.focus,
                          ),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: icon,
                    ),
                    const SizedBox(height: SellerSpace.s4),
                    // Like the system navigation bars, labels grow with the
                    // text size only up to 130 %; the full name is always in
                    // the semantics label above.
                    MediaQuery.withClampedTextScaling(
                      maxScaleFactor: SellerNavBar.maxLabelScale,
                      child: Text(
                        item.label,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: text.labelSmall!.copyWith(
                          color: labelColor,
                          letterSpacing: 0,
                          fontWeight: selected ? SellerType.bold : SellerType.semibold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Bottom navigation for phones (< 600 dp; boards 04, 07): five roots, labels
/// always shown, the selected item in a mint pill (bright teal in dark mode),
/// count badges ("99+" in red).
class SellerNavBar extends StatelessWidget {
  const SellerNavBar({super.key, required this.items, required this.selectedIndex, required this.onSelected});

  /// Largest text scale applied to nav labels.
  static const double maxLabelScale = 1.3;

  final List<SellerNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.border))),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _NavButton(item: items[i], selected: i == selectedIndex, onTap: () => onSelected(i), index: i, count: items.length),
              ),
          ],
        ),
      ),
    );
  }
}

/// Navigation rail for tablets and wide windows (≥ 600 dp; board 04).
class SellerNavRail extends StatelessWidget {
  const SellerNavRail({super.key, required this.items, required this.selectedIndex, required this.onSelected, this.leading});

  final List<SellerNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(color: c.surface, border: Border(right: BorderSide(color: c.border))),
      child: SafeArea(
        right: false,
        child: SizedBox(
          width: SellerSize.rail,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: SellerSpace.s12),
            child: Column(
              children: [
                if (leading != null) ...[leading!, const SizedBox(height: SellerSpace.s16)],
                for (var i = 0; i < items.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: SellerSpace.s4, horizontal: SellerSpace.s4),
                    child: _NavButton(item: items[i], selected: i == selectedIndex, onTap: () => onSelected(i), index: i, count: items.length),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// App bars (board 07): root screens get a large left title and no back
/// arrow; detail screens a back arrow and a title; modal composers a close
/// "×" and a text action. Heights grow with the system text size so titles
/// are never clipped (board 24-04).
abstract final class SellerAppBar {
  static double _height(BuildContext context, double lineHeight, double base, {int lines = 1}) {
    final scaled = MediaQuery.textScalerOf(context).scale(lineHeight);
    return math.max(base, scaled * lines + SellerSpace.s16);
  }

  static bool _large(BuildContext context) => MediaQuery.textScalerOf(context).scale(1) > 1.15;

  /// Root destination: large title, actions (search, bell, …).
  static PreferredSizeWidget root(
    BuildContext context, {
    required String title,
    List<Widget> actions = const [],
    PreferredSizeWidget? bottom,
    Widget? subtitle,
  }) {
    final text = context.text;
    final scaler = MediaQuery.textScalerOf(context);
    final titleLines = _large(context) ? 2 : 1;
    final subtitleLines = subtitle == null ? 0 : 2;
    final height = math.max(
      SellerSize.navBar,
      scaler.scale(32) * titleLines + scaler.scale(20) * subtitleLines + SellerSpace.s16,
    );
    final heading = Semantics(
      header: true,
      child: Text(title, style: text.headlineMedium, maxLines: titleLines, overflow: TextOverflow.ellipsis),
    );
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: height,
      titleSpacing: SellerSpace.page,
      title: subtitle == null
          ? heading
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                heading,
                DefaultTextStyle.merge(maxLines: subtitleLines, overflow: TextOverflow.ellipsis, child: subtitle),
              ],
            ),
      actions: [...actions, const SizedBox(width: SellerSpace.s8)],
      bottom: bottom,
    );
  }

  /// Root tab whose heading lives in the page body (Home, board 03): a
  /// standard-height bar with only the actions, so the greeting can wrap
  /// at any text size instead of being cut in the bar.
  static PreferredSizeWidget actionsOnly(BuildContext context, {required List<Widget> actions}) {
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: SellerSize.navBar,
      actions: [...actions, const SizedBox(width: SellerSpace.s8)],
    );
  }

  /// Just a back arrow (boards 16-01 panels 02–03, 16-02): the page's own
  /// heading names the screen.
  static PreferredSizeWidget backOnly(BuildContext context, {VoidCallback? onBack}) {
    final l10n = AppLocalizations.of(context);
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: SellerSize.navBar,
      leading: IconButton(
        tooltip: l10n.back,
        onPressed: onBack ?? () => Navigator.of(context).maybePop(),
        icon: const Icon(SellerIcons.back),
      ),
    );
  }

  /// Pushed screen: back arrow (or × for a modal), title, optional status and actions.
  static PreferredSizeWidget detail(
    BuildContext context, {
    required String title,
    String? subtitle,
    List<Widget> actions = const [],
    VoidCallback? onBack,
    bool close = false,
    Widget? status,
    PreferredSizeWidget? bottom,
    bool centerTitle = false,
    bool showBack = true,
  }) {
    final text = context.text;
    final l10n = AppLocalizations.of(context);
    final lines = (subtitle != null ? 1 : 0) + (_large(context) ? 2 : 1);
    final height = _height(context, 28, kToolbarHeight, lines: lines);
    return AppBar(
      toolbarHeight: height,
      centerTitle: centerTitle,
      automaticallyImplyLeading: false,
      titleSpacing: showBack ? null : SellerSpace.pageWide,
      leading: showBack
          ? Builder(
              builder: (ctx) => IconButton(
                tooltip: close ? l10n.dsClose : l10n.back,
                icon: Icon(close ? SellerIcons.close : SellerIcons.back),
                onPressed: onBack ?? () => Navigator.of(ctx).maybePop(),
              ),
            )
          : null,
      title: Row(
        mainAxisSize: centerTitle ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: centerTitle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: text.titleLarge, maxLines: _large(context) ? 2 : 1, overflow: TextOverflow.ellipsis),
                ),
                if (subtitle != null) Text(subtitle, style: text.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (status != null) ...[const SizedBox(width: SellerSpace.s8), status],
        ],
      ),
      actions: [...actions, const SizedBox(width: SellerSpace.s4)],
      bottom: bottom,
    );
  }
}
