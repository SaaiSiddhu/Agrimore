import 'package:flutter/material.dart';

import '../icons/delivery_icons.dart';
import '../tokens/delivery_colors.dart';
import '../tokens/delivery_tokens.dart';
import '../tokens/delivery_typography.dart';
import 'delivery_button.dart';

/// Top bar for Delivery screens with optional subtitle, leading back action,
/// trailing action slots, and subtle bottom border.
class DeliveryAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DeliveryAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const <Widget>[],
    this.bottom,
    this.showDivider = true,
    this.backTooltip = 'Back',
  });

  final Widget title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;
  final PreferredSizeWidget? bottom;
  final bool showDivider;
  final String backTooltip;

  factory DeliveryAppBar.titled(
    String titleText, {
    Key? key,
    String? subtitle,
    Widget? leading,
    List<Widget> actions = const <Widget>[],
    PreferredSizeWidget? bottom,
    bool showDivider = true,
    String backTooltip = 'Back',
  }) {
    return DeliveryAppBar(
      key: key,
      title: Text(titleText, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle,
      leading: leading,
      actions: actions,
      bottom: bottom,
      showDivider: showDivider,
      backTooltip: backTooltip,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
        (subtitle != null ? 64.0 : 56.0) +
            (bottom?.preferredSize.height ?? 0.0),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final canPop = ModalRoute.of(context)?.canPop ?? false;

    return AppBar(
      toolbarHeight: subtitle != null ? 64.0 : 56.0,
      backgroundColor: c.surface,
      foregroundColor: c.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      automaticallyImplyLeading: false,
      leading: leading ??
          (canPop
              ? DeliveryIconButton(
                  icon: DeliveryIcons.back,
                  tooltip: backTooltip,
                  onPressed: () => Navigator.of(context).maybePop(),
                )
              : null),
      title: subtitle == null
          ? DefaultTextStyle(style: t.titleLarge, child: title)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                DefaultTextStyle(style: t.titleMedium, child: title),
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.caption.copyWith(color: c.textSecondary),
                ),
              ],
            ),
      actions: [
        ...actions,
        if (actions.isNotEmpty) const SizedBox(width: DeliverySpace.sm),
      ],
      bottom: bottom ??
          (showDivider
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Divider(height: 1, thickness: 1, color: c.border),
                )
              : null),
    );
  }
}

/// Pinned bottom action bar that lifts above the software keyboard and bottom
/// safe area. Never clips its contents at 200% text scale.
class DeliveryBottomActionBar extends StatelessWidget {
  const DeliveryBottomActionBar({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
      DeliverySpace.lg,
      DeliverySpace.md,
      DeliverySpace.lg,
      DeliverySpace.md,
    ),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Material(
        color: c.surface,
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(
              top: BorderSide(color: c.border, width: DeliverySize.stroke),
            ),
            boxShadow: DeliveryElevation.stickyBottom(c.shadow),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Centers content on tablet / foldable viewports while keeping full-bleed
/// ergonomics on phone viewports.
class DeliveryResponsiveBody extends StatelessWidget {
  const DeliveryResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth = DeliveryLayout.contentMaxWidth,
    this.padding,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final content = padding != null
        ? Padding(padding: padding!, child: child)
        : child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: content,
      ),
    );
  }
}
