import 'package:flutter/material.dart';

import '../icons/seller_icons.dart';
import '../theme/seller_focus.dart';
import '../tokens/seller_colors.dart';
import 'seller_layout.dart';
import '../tokens/seller_tokens.dart';
import '../tokens/seller_typography.dart';
import 'seller_card.dart';

/// One row: optional leading icon tile, title, subtitle, value / trailing
/// widget and a chevron when it navigates (boards 07, 11, 22-01, 23-04).
///
/// Rows inside a [SellerMenuGroup] have no border of their own; a standalone
/// row ([bordered]) is a card. Either way keyboard focus draws the row's own
/// rounded outline in the focus colour (single border).
class SellerListRow extends StatelessWidget {
  const SellerListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconTone = SellerTone.brand,
    this.leading,
    this.value,
    this.trailing,
    this.onTap,
    this.showChevron,
    this.destructive = false,
    this.bordered = false,
    this.semanticLabel,
    this.titleMaxLines,
    this.plainIcon = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final SellerTone iconTone;
  final Widget? leading;

  /// Right-aligned text (e.g. "₹855", "On").
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Defaults to true when the row navigates.
  final bool? showChevron;
  final bool destructive;
  final bool bordered;
  final String? semanticLabel;
  final int? titleMaxLines;

  /// Draws [icon] without a tinted tile (settings-style rows).
  final bool plainIcon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final fg = destructive ? c.danger : c.textPrimary;
    final chevron = showChevron ?? onTap != null;
    final stackValue = context.largeText;

    Widget? lead = leading;
    if (lead == null && icon != null) {
      lead = plainIcon
          ? ExcludeSemantics(child: Icon(icon, size: SellerIconSize.lg, color: destructive ? c.danger : c.textSecondary))
          : SellerIconTile(icon: icon!, tone: destructive ? SellerTone.danger : iconTone);
    }

    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: SellerSize.touchTarget + SellerSpace.s8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: SellerSpace.s16, vertical: SellerSpace.s12),
        child: Row(
          children: [
            if (lead != null) ...[lead, const SizedBox(width: SellerSpace.s12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: text.titleSmall!.copyWith(color: fg), maxLines: titleMaxLines),
                  if (subtitle != null) ...[
                    const SizedBox(height: SellerSpace.s2),
                    Text(subtitle!, style: text.bodyMedium),
                  ],
                  // Large text: the value goes under the title, so neither
                  // is squeezed into breaking mid-word (seen at 150 % on a device).
                  if (value != null && stackValue) ...[
                    const SizedBox(height: SellerSpace.s4),
                    Text(value!, style: text.titleSmall!.tabular),
                  ],
                ],
              ),
            ),
            if (value != null && !stackValue) ...[
              const SizedBox(width: SellerSpace.s12),
              Text(value!, style: text.titleSmall!.tabular, textAlign: TextAlign.end),
            ],
            if (trailing != null) ...[
              const SizedBox(width: SellerSpace.s12),
              trailing!,
            ],
            if (chevron) ...[
              const SizedBox(width: SellerSpace.s8),
              ExcludeSemantics(child: Icon(SellerIcons.chevronRight, size: SellerIconSize.md, color: destructive ? c.danger : c.textTertiary)),
            ],
          ],
        ),
      ),
    );

    if (onTap == null) {
      final body = bordered ? SellerCard(padding: EdgeInsets.zero, child: content) : content;
      return MergeSemantics(child: body);
    }

    return SellerFocusTracker(
      builder: (context, focused, node) {
        final radius = BorderRadius.circular(bordered ? SellerRadius.card : SellerRadius.control);
        final shape = RoundedRectangleBorder(
          borderRadius: radius,
          side: sellerOutline(
            c,
            focused: focused,
            rest: bordered ? (destructive ? c.danger : c.border) : Colors.transparent,
          ),
        );
        return Semantics(
          container: true,
          button: true,
          label: semanticLabel,
          child: MergeSemantics(
            child: Material(
              color: bordered ? c.surface : Colors.transparent,
              shape: shape,
              clipBehavior: Clip.antiAlias,
              child: InkWell(focusNode: node, onTap: onTap, customBorder: shape, child: content),
            ),
          ),
        );
      },
    );
  }
}

/// A titled group of rows in one card, divided by hairlines (boards 22-01, 23-08).
class SellerMenuGroup extends StatelessWidget {
  const SellerMenuGroup({super.key, required this.children, this.title});

  final List<Widget> children;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(left: SellerSpace.s4, bottom: SellerSpace.s8),
            child: Semantics(header: true, child: Text(title!, style: context.text.labelLarge!.copyWith(color: c.textSecondary))),
          ),
        SellerCard(
          padding: const EdgeInsets.all(SellerSpace.s4),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(height: SellerSize.hairline, indent: SellerSpace.s12, endIndent: SellerSpace.s12),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Label on the left (muted), value on the right; long values wrap and stay
/// right-aligned (board 11 "key/value").
class SellerKeyValueRow extends StatelessWidget {
  const SellerKeyValueRow({
    super.key,
    required this.label,
    this.value,
    this.valueWidget,
    this.emphasis = false,
    this.valueColor,
    this.icon,
    this.tabular = true,
  });

  final String label;
  final String? value;
  final Widget? valueWidget;
  final bool emphasis;
  final Color? valueColor;
  final IconData? icon;
  final bool tabular;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final labelStyle = emphasis ? text.titleSmall : text.bodyMedium;
    var valueStyle = (emphasis ? text.titleMedium : text.bodyLarge)!.copyWith(color: valueColor);
    if (tabular) valueStyle = valueStyle.tabular;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: SellerSpace.s6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Padding(
                padding: const EdgeInsets.only(top: SellerSpace.s2),
                child: ExcludeSemantics(child: Icon(icon, size: SellerIconSize.md, color: c.textSecondary)),
              ),
              const SizedBox(width: SellerSpace.s8),
            ],
            Expanded(flex: 2, child: Text(label, style: labelStyle)),
            const SizedBox(width: SellerSpace.s12),
            Expanded(
              flex: 3,
              child: Align(
                alignment: Alignment.centerRight,
                child: valueWidget ?? Text(value ?? '', style: valueStyle, textAlign: TextAlign.end),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section title with an optional count pill and a trailing action ("See all").
class SellerSectionHeader extends StatelessWidget {
  const SellerSectionHeader({super.key, required this.title, this.count, this.actionLabel, this.onAction, this.subtitle});

  final String title;
  final String? subtitle;
  final int? count;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    return Padding(
      padding: const EdgeInsets.only(bottom: SellerSpace.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: SellerSpace.s8,
                    children: [
                      Text(title, style: text.titleMedium),
                      if (count != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: SellerSpace.s8, vertical: SellerSpace.s2),
                          decoration: BoxDecoration(color: c.primaryContainer, borderRadius: BorderRadius.circular(SellerRadius.pill)),
                          child: Text('$count', style: text.labelMedium!.copyWith(color: c.onPrimaryContainer).tabular),
                        ),
                    ],
                  ),
                  if (subtitle != null) Text(subtitle!, style: text.bodySmall),
                ],
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}
