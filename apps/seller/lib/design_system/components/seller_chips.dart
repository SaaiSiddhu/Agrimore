import 'package:flutter/material.dart';

import '../icons/seller_icons.dart';
import '../theme/seller_focus.dart';
import '../tokens/seller_colors.dart';
import '../tokens/seller_tokens.dart';
import '../tokens/seller_typography.dart';
import 'seller_badge.dart';

/// How a chip shows selection.
enum SellerChipStyle {
  /// Single choice among tabs/filters (orders stages, catalogue filters):
  /// selected = filled teal (boards 17-01, 18-01, 20-01).
  tab,

  /// Independent toggle (B2B, star filters): selected = mint with a check
  /// (board 08).
  toggle,
}

/// A filter chip: label, optional count and icon; 36 dp tall inside a 48 dp
/// hit area; selection shown by fill AND (for toggles) a check; keyboard focus
/// thickens the chip's own outline.
class SellerChip extends StatelessWidget {
  const SellerChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.count,
    this.icon,
    this.style = SellerChipStyle.tab,
    this.onRemove,
    this.removeLabel,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final int? count;
  final IconData? icon;
  final SellerChipStyle style;

  /// Removable tag ("Farm fresh ×", board 08 / 22-07).
  final VoidCallback? onRemove;
  final String? removeLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final filled = selected && style == SellerChipStyle.tab;
    final minted = selected && style == SellerChipStyle.toggle;
    final Color fill = filled ? c.primary : (minted ? c.primaryContainer : c.surface);
    final Color fg = filled ? c.onPrimary : (minted ? c.onPrimaryContainer : c.textPrimary);
    final Color rest = filled ? c.primary : (minted ? c.primaryContainer : c.border);

    return SellerFocusTracker(
      builder: (context, focused, node) {
        final shape = StadiumBorder(
          side: sellerOutline(c, focused: focused, rest: rest, focusColor: filled ? c.focusOnFill : c.focus),
        );
        final semanticsLabel = count == null ? label : '$label, $count';
        return Semantics(
          button: onSelected != null,
          selected: selected,
          label: semanticsLabel,
          excludeSemantics: true,
          onTap: onSelected == null ? null : () => onSelected!(!selected),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: SellerSize.touchTarget),
            child: Center(
              widthFactor: 1,
              child: Material(
                color: fill,
                shape: shape,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  focusNode: node,
                  onTap: onSelected == null ? null : () => onSelected!(!selected),
                  customBorder: shape,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: SellerSize.chip),
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: SellerSpace.s12,
                        right: onRemove != null ? SellerSpace.s4 : SellerSpace.s12,
                        top: SellerSpace.s6,
                        bottom: SellerSpace.s6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (minted) ...[
                            Icon(SellerIcons.check, size: SellerIconSize.sm, color: fg),
                            const SizedBox(width: SellerSpace.s4),
                          ] else if (icon != null) ...[
                            Icon(icon, size: SellerIconSize.sm, color: fg),
                            const SizedBox(width: SellerSpace.s6),
                          ],
                          Flexible(child: Text(label, style: text.labelLarge!.copyWith(color: fg))),
                          if (count != null) ...[
                            const SizedBox(width: SellerSpace.s6),
                            SellerCount(count: count!, inverse: filled),
                          ],
                          if (onRemove != null)
                            SizedBox(
                              width: SellerSize.touchTarget - SellerSpace.s8,
                              height: SellerSize.chip - SellerSpace.s12,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                tooltip: removeLabel,
                                onPressed: onRemove,
                                icon: Icon(SellerIcons.close, size: SellerIconSize.sm, color: fg),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A horizontally scrolling row of chips with the page inset (boards 10, 17-01).
class SellerChipBar extends StatelessWidget {
  const SellerChipBar({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: SellerSpace.page),
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: SellerSpace.s8),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// One segment of a [SellerSegmented].
@immutable
class SellerSegment<T> {
  const SellerSegment(this.value, this.label, {this.icon});
  final T value;
  final String label;
  final IconData? icon;
}

/// Segmented control (boards 08, 21-02, 22-02, 23-04): a sunken track with the
/// selected segment filled teal (dark: bright teal, dark label) and a check.
/// Each segment is focusable; keyboard focus outlines the segment itself.
/// Labels wrap at large text sizes instead of clipping.
class SellerSegmented<T> extends StatelessWidget {
  const SellerSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.semanticLabel,
    this.showCheck = false,
  });

  final List<SellerSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final String? semanticLabel;
  final bool showCheck;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    return Semantics(
      container: true,
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsets.all(SellerSpace.s4),
        decoration: BoxDecoration(
          color: c.sunken,
          borderRadius: BorderRadius.circular(SellerRadius.control + SellerSpace.s4),
          border: Border.all(color: c.border),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final s in segments)
                Expanded(
                  child: SellerFocusTracker(
                    builder: (context, focused, node) {
                      final isSelected = s.value == selected;
                      final shape = RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(SellerRadius.control),
                        side: sellerOutline(
                          c,
                          focused: focused,
                          rest: Colors.transparent,
                          focusColor: isSelected ? c.focusOnFill : c.focus,
                        ),
                      );
                      final fg = isSelected ? c.onPrimary : c.textPrimary;
                      return Semantics(
                        button: true,
                        selected: isSelected,
                        label: s.label,
                        excludeSemantics: true,
                        onTap: () => onChanged(s.value),
                        child: Material(
                          color: isSelected ? c.primary : Colors.transparent,
                          shape: shape,
                          child: InkWell(
                            focusNode: node,
                            customBorder: shape,
                            onTap: () => onChanged(s.value),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: SellerSize.controlCompact),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: SellerSpace.s8, vertical: SellerSpace.s8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (isSelected && showCheck) ...[
                                      Icon(SellerIcons.check, size: SellerIconSize.sm, color: fg),
                                      const SizedBox(width: SellerSpace.s4),
                                    ] else if (s.icon != null) ...[
                                      Icon(s.icon, size: SellerIconSize.sm, color: fg),
                                      const SizedBox(width: SellerSpace.s4),
                                    ],
                                    Flexible(
                                      child: Text(
                                        s.label,
                                        textAlign: TextAlign.center,
                                        style: text.labelLarge!.copyWith(color: fg),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
