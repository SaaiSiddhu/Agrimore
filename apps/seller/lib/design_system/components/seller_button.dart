import 'package:flutter/material.dart';

import '../format/seller_format.dart';
import '../icons/seller_icons.dart';
import '../theme/seller_focus.dart';
import '../tokens/seller_colors.dart';
import '../tokens/seller_tokens.dart';
import '../tokens/seller_typography.dart';
import 'seller_states.dart';

/// Visual weight of a [SellerButton] (board 08).
enum SellerButtonVariant {
  /// Filled teal — one per decision.
  primary,

  /// Outlined teal.
  secondary,

  /// Text only.
  tertiary,

  /// Mint fill, teal label ("Add photo", "Copy invoice number").
  tonal,

  /// Filled red — confirms something destructive.
  danger,

  /// Outlined red — the entry point to something destructive.
  dangerOutline,
}

/// The seller button (board 08; decisions D2).
///
/// - 48 dp tall (40 when [compact]), radius 8; labels wrap instead of clipping
///   at large text sizes (board 05).
/// - [loading] disables the button (no duplicate submissions), shows a spinner —
///   or a static hourglass with reduced motion (board 24-05) — and [loadingLabel].
/// - Keyboard focus thickens the button's own outline (single border).
class SellerButton extends StatelessWidget {
  const SellerButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = SellerButtonVariant.primary,
    this.icon,
    this.leading,
    this.trailingIcon,
    this.loading = false,
    this.loadingLabel,
    this.expand = true,
    this.compact = false,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
  });

  const SellerButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.leading,
    this.trailingIcon,
    this.loading = false,
    this.loadingLabel,
    this.expand = true,
    this.compact = false,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
  }) : variant = SellerButtonVariant.secondary;

  const SellerButton.tertiary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.leading,
    this.trailingIcon,
    this.loading = false,
    this.loadingLabel,
    this.expand = false,
    this.compact = false,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
  }) : variant = SellerButtonVariant.tertiary;

  const SellerButton.tonal({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.leading,
    this.trailingIcon,
    this.loading = false,
    this.loadingLabel,
    this.expand = true,
    this.compact = false,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
  }) : variant = SellerButtonVariant.tonal;

  const SellerButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.leading,
    this.trailingIcon,
    this.loading = false,
    this.loadingLabel,
    this.expand = true,
    this.compact = false,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
  }) : variant = SellerButtonVariant.danger;

  const SellerButton.dangerOutline({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.leading,
    this.trailingIcon,
    this.loading = false,
    this.loadingLabel,
    this.expand = true,
    this.compact = false,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
  }) : variant = SellerButtonVariant.dangerOutline;

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final SellerButtonVariant variant;
  final IconData? icon;

  /// A widget in place of [icon] — a brand mark such as Google's "G".
  final Widget? leading;
  final IconData? trailingIcon;
  final bool loading;
  final String? loadingLabel;

  /// Fill the available width (the default for form actions).
  final bool expand;
  final bool compact;
  final String? semanticLabel;
  final FocusNode? focusNode;
  final bool autofocus;

  bool get _enabled => onPressed != null && !loading;

  ButtonStyle _style(SellerColors c) {
    final height = compact ? SellerSize.controlCompact : SellerSize.control;
    final minimum = Size(expand ? double.infinity : SellerSize.touchTarget, height);
    BorderSide focusSide(Color color) =>
        BorderSide(color: color, width: SellerSize.focusStrong, strokeAlign: BorderSide.strokeAlignInside);

    switch (variant) {
      case SellerButtonVariant.primary:
        return ButtonStyle(minimumSize: WidgetStatePropertyAll(minimum));
      case SellerButtonVariant.secondary:
        return ButtonStyle(minimumSize: WidgetStatePropertyAll(minimum));
      case SellerButtonVariant.tertiary:
        return ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(expand ? double.infinity : SellerSize.touchTarget, height)));
      case SellerButtonVariant.tonal:
        return ButtonStyle(
          minimumSize: WidgetStatePropertyAll(minimum),
          backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? c.disabledFill : c.primaryContainer),
          foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? c.disabledText : c.onPrimaryContainer),
          side: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.disabled)) return BorderSide.none;
            if (sellerShowsFocus(s)) return focusSide(c.focus);
            return BorderSide(color: c.primaryContainer, width: SellerSize.hairline, strokeAlign: BorderSide.strokeAlignInside);
          }),
        );
      case SellerButtonVariant.danger:
        return ButtonStyle(
          minimumSize: WidgetStatePropertyAll(minimum),
          backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? c.disabledFill : c.dangerFill),
          foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? c.disabledText : c.onDangerFill),
          overlayColor: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.pressed)) return c.onDangerFill.withValues(alpha: SellerOpacity.pressed);
            if (s.contains(WidgetState.hovered)) return c.onDangerFill.withValues(alpha: SellerOpacity.hover);
            return Colors.transparent;
          }),
          side: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.disabled)) return BorderSide.none;
            if (sellerShowsFocus(s)) return focusSide(c.focusOnDanger);
            return BorderSide(color: c.dangerFill, width: SellerSize.hairline, strokeAlign: BorderSide.strokeAlignInside);
          }),
        );
      case SellerButtonVariant.dangerOutline:
        return ButtonStyle(
          minimumSize: WidgetStatePropertyAll(minimum),
          foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? c.disabledText : c.danger),
          overlayColor: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.pressed)) return c.danger.withValues(alpha: SellerOpacity.pressed);
            if (s.contains(WidgetState.hovered)) return c.danger.withValues(alpha: SellerOpacity.hover);
            return Colors.transparent;
          }),
          side: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.disabled)) {
              return BorderSide(color: c.disabledFill, width: SellerSize.outline, strokeAlign: BorderSide.strokeAlignInside);
            }
            if (sellerShowsFocus(s)) return focusSide(c.danger);
            return BorderSide(color: c.danger, width: SellerSize.outline, strokeAlign: BorderSide.strokeAlignInside);
          }),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shownLabel = loading ? (loadingLabel ?? label) : label;
    final content = _Content(
      label: shownLabel,
      icon: loading ? null : icon,
      leading: loading ? null : leading,
      trailingIcon: loading ? null : trailingIcon,
      loading: loading,
      expand: expand,
      spinnerColor: switch (variant) {
        SellerButtonVariant.primary => c.onPrimary,
        SellerButtonVariant.danger => c.onDangerFill,
        SellerButtonVariant.dangerOutline => c.danger,
        SellerButtonVariant.tonal => c.onPrimaryContainer,
        _ => c.primary,
      },
    );
    final style = _style(c);
    final pressed = _enabled ? onPressed : null;
    final Widget button = switch (variant) {
      SellerButtonVariant.primary || SellerButtonVariant.tonal || SellerButtonVariant.danger => FilledButton(
          onPressed: pressed,
          style: style,
          focusNode: focusNode,
          autofocus: autofocus,
          child: content,
        ),
      SellerButtonVariant.secondary || SellerButtonVariant.dangerOutline => OutlinedButton(
          onPressed: pressed,
          style: style,
          focusNode: focusNode,
          autofocus: autofocus,
          child: content,
        ),
      SellerButtonVariant.tertiary => TextButton(
          onPressed: pressed,
          style: style,
          focusNode: focusNode,
          autofocus: autofocus,
          child: content,
        ),
    };
    // The Material button already exposes its label (or the loading label),
    // role and enabled state. A custom [semanticLabel] replaces the name only.
    if (semanticLabel == null) return button;
    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: _enabled,
      onTap: pressed,
      excludeSemantics: true,
      child: button,
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.label,
    required this.icon,
    required this.leading,
    required this.trailingIcon,
    required this.loading,
    required this.expand,
    required this.spinnerColor,
  });

  final String label;
  final IconData? icon;
  final Widget? leading;
  final IconData? trailingIcon;
  final bool loading;
  final bool expand;
  final Color spinnerColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading) ...[
          SellerSpinner(size: SellerIconSize.md, color: spinnerColor),
          const SizedBox(width: SellerSpace.s12),
        ] else if (leading != null) ...[
          leading!,
          const SizedBox(width: SellerSpace.s12),
        ] else if (icon != null) ...[
          Icon(icon, size: SellerIconSize.md),
          const SizedBox(width: SellerSpace.s8),
        ],
        Flexible(
          child: Text(label, textAlign: TextAlign.center, softWrap: true),
        ),
        if (trailingIcon != null) ...[
          const SizedBox(width: SellerSpace.s8),
          Icon(trailingIcon, size: SellerIconSize.md),
        ],
      ],
    );
  }
}

/// A 48 × 48 icon button with a required accessible label (board 06: icon-only
/// actions need a name). [bordered] draws the rounded-square outline from
/// board 08; either way, keyboard focus thickens the button's own outline.
class SellerIconButton extends StatelessWidget {
  const SellerIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.bordered = false,
    this.color,
    this.badgeCount,
    this.showDot = false,
    this.size = SellerIconSize.lg,
    this.filled = false,
  });

  final IconData icon;

  /// Accessible name and tooltip.
  final String label;
  final VoidCallback? onPressed;
  final bool bordered;
  final Color? color;
  final int? badgeCount;
  final bool showDot;
  final double size;

  /// Filled teal circle (the "+" add action in the Catalogue app bar, send in chat).
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final count = badgeCount ?? 0;
    Widget glyph = Icon(icon, size: size);
    if (count > 0 || showDot) {
      glyph = Badge(
        isLabelVisible: true,
        smallSize: SellerSize.dot,
        backgroundColor: count > 0 ? c.primaryStrong : c.danger,
        textColor: c.onPrimary,
        label: count > 0 ? Text(count > 99 ? '99+' : SellerFormat.count(count)) : null,
        child: glyph,
      );
    }
    final style = ButtonStyle(
      foregroundColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.disabled)) return c.disabledText;
        return filled ? c.onPrimary : (color ?? c.textPrimary);
      }),
      backgroundColor: WidgetStatePropertyAll(filled ? c.primary : (bordered ? c.surface : Colors.transparent)),
      shape: WidgetStatePropertyAll(
        filled ? const CircleBorder() : RoundedRectangleBorder(borderRadius: BorderRadius.circular(SellerRadius.control)),
      ),
      side: WidgetStateProperty.resolveWith((s) {
        if (sellerShowsFocus(s)) {
          return BorderSide(
            color: filled ? c.focusOnFill : c.focus,
            width: filled ? SellerSize.focusStrong : SellerSize.focus,
            strokeAlign: BorderSide.strokeAlignInside,
          );
        }
        if (bordered) return BorderSide(color: c.border, width: SellerSize.hairline, strokeAlign: BorderSide.strokeAlignInside);
        return BorderSide.none;
      }),
    );
    return IconButton(
      tooltip: label,
      onPressed: onPressed,
      style: style,
      icon: glyph,
    );
  }
}

/// The floating "+ Add product" / "+ New post" action (boards 08, 18-01, 22-09):
/// a 56 dp pill that keeps the single-border focus rule.
class SellerFab extends StatelessWidget {
  const SellerFab({super.key, required this.label, required this.onPressed, this.icon = SellerIcons.add});

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: SellerIconSize.lg),
      label: Text(label),
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(SellerSize.fab, SellerSize.fab)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: SellerSpace.s20)),
        shape: const WidgetStatePropertyAll(StadiumBorder()),
        elevation: WidgetStatePropertyAll(c.isDark ? 0 : 3),
        shadowColor: WidgetStatePropertyAll(c.primaryStrong),
        textStyle: WidgetStatePropertyAll(context.text.titleSmall),
      ),
    );
  }
}
