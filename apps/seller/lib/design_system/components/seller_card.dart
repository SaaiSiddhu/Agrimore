import 'package:flutter/material.dart';

import '../theme/seller_focus.dart';
import '../tokens/seller_colors.dart';
import '../tokens/seller_tokens.dart';

/// Background of a [SellerCard].
enum SellerCardTone { surface, subtle, mint, sunken, success, warning, danger, info }

/// The seller card (board 11): radius 12, hairline border, flat. When it acts
/// as a control ([onTap]) keyboard focus thickens its own border (single
/// border, decisions D2) and its content reads as one screen-reader node.
class SellerCard extends StatelessWidget {
  const SellerCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(SellerSpace.card),
    this.tone = SellerCardTone.surface,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.bordered = true,
    this.semanticLabel,
    this.radius = SellerRadius.card,
    this.clip = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final SellerCardTone tone;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Selected list item in a list + detail layout (board 04: mint fill, teal border).
  final bool selected;
  final bool bordered;
  final String? semanticLabel;
  final double radius;
  final bool clip;

  Color _fill(SellerColors c) => switch (tone) {
        SellerCardTone.surface => selected ? c.primarySubtle : c.surface,
        SellerCardTone.subtle => c.primarySubtle,
        SellerCardTone.mint => c.primaryContainer,
        SellerCardTone.sunken => c.sunken,
        SellerCardTone.success => c.successContainer,
        SellerCardTone.warning => c.warningContainer,
        SellerCardTone.danger => c.dangerContainer,
        SellerCardTone.info => c.infoContainer,
      };

  Color _rest(SellerColors c) {
    if (selected) return c.primary;
    if (!bordered) return Colors.transparent;
    return switch (tone) {
      SellerCardTone.surface => c.border,
      SellerCardTone.sunken => c.border,
      _ => Colors.transparent,
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final interactive = onTap != null || onLongPress != null;
    if (!interactive) {
      return Container(
        clipBehavior: clip ? Clip.antiAlias : Clip.none,
        decoration: ShapeDecoration(
          color: _fill(c),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: sellerOutline(c, focused: false, rest: _rest(c), restWidth: selected ? SellerSize.focus : SellerSize.hairline),
          ),
        ),
        child: Padding(padding: padding, child: child),
      );
    }
    return SellerFocusTracker(
      builder: (context, focused, node) {
        final shape = RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: sellerOutline(
            c,
            focused: focused,
            rest: _rest(c),
            restWidth: selected ? SellerSize.focus : SellerSize.hairline,
            // A selected card already has a 2 dp teal border; focus must
            // still read as a change of that same border.
            focusWidth: selected ? SellerSize.focusStrong : SellerSize.focus,
          ),
        );
        final body = Material(
          color: _fill(c),
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            focusNode: node,
            onTap: onTap,
            onLongPress: onLongPress,
            customBorder: shape,
            child: Padding(padding: padding, child: child),
          ),
        );
        return Semantics(
          container: true,
          button: onTap != null,
          selected: selected ? true : null,
          label: semanticLabel,
          child: semanticLabel != null ? body : MergeSemantics(child: body),
        );
      },
    );
  }
}

/// Rounded tile holding an icon, tinted by tone (boards 11, 22-01).
class SellerIconTile extends StatelessWidget {
  const SellerIconTile({super.key, required this.icon, this.tone = SellerTone.brand, this.size = SellerSize.avatarMd, this.circle = false});

  final IconData icon;
  final SellerTone tone;
  final double size;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final pair = context.colors.tone(tone);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: pair.container,
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: circle ? null : BorderRadius.circular(SellerRadius.control),
        ),
        child: Icon(icon, size: size >= SellerSize.avatarLg ? SellerIconSize.lg : SellerIconSize.md, color: pair.foreground),
      ),
    );
  }
}
