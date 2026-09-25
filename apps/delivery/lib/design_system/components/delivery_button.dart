import 'package:flutter/material.dart';

import '../theme/delivery_focus.dart';
import '../tokens/delivery_colors.dart';
import '../tokens/delivery_tokens.dart';
import '../tokens/delivery_typography.dart';

enum DeliveryButtonVariant { primary, secondary, tonal, ghost, danger }

enum DeliveryButtonSize { sm, md, lg }

/// Primary action button across all Delivery flows.
///
/// Enforces a minimum 48dp touch target (`52dp` for `lg`), wraps long labels
/// cleanly at 200% text scale, swaps label for a progress indicator when
/// [loading] is true, and renders a high-contrast focus ring only for keyboard
/// traversal.
class DeliveryButton extends StatelessWidget {
  const DeliveryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = DeliveryButtonVariant.primary,
    this.size = DeliveryButtonSize.lg,
    this.icon,
    this.trailingIcon,
    bool loading = false,
    bool isLoading = false,
    bool expand = true,
    bool? fullWidth,
    this.semanticLabel,
  })  : loading = loading || isLoading,
        expand = fullWidth ?? expand;

  const DeliveryButton.primary({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    IconData? trailingIcon,
    bool loading = false,
    bool isLoading = false,
    bool expand = true,
    bool? fullWidth,
    DeliveryButtonSize size = DeliveryButtonSize.lg,
    String? semanticLabel,
  }) : this(
          key: key,
          label: label,
          onPressed: onPressed,
          variant: DeliveryButtonVariant.primary,
          size: size,
          icon: icon,
          trailingIcon: trailingIcon,
          loading: loading || isLoading,
          expand: fullWidth ?? expand,
          semanticLabel: semanticLabel,
        );

  const DeliveryButton.secondary({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    IconData? trailingIcon,
    bool loading = false,
    bool isLoading = false,
    bool expand = true,
    bool? fullWidth,
    DeliveryButtonSize size = DeliveryButtonSize.md,
    String? semanticLabel,
  }) : this(
          key: key,
          label: label,
          onPressed: onPressed,
          variant: DeliveryButtonVariant.secondary,
          size: size,
          icon: icon,
          trailingIcon: trailingIcon,
          loading: loading || isLoading,
          expand: fullWidth ?? expand,
          semanticLabel: semanticLabel,
        );

  const DeliveryButton.tonal({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    IconData? trailingIcon,
    bool loading = false,
    bool isLoading = false,
    bool expand = false,
    bool? fullWidth,
    DeliveryButtonSize size = DeliveryButtonSize.md,
    String? semanticLabel,
  }) : this(
          key: key,
          label: label,
          onPressed: onPressed,
          variant: DeliveryButtonVariant.tonal,
          size: size,
          icon: icon,
          trailingIcon: trailingIcon,
          loading: loading || isLoading,
          expand: fullWidth ?? expand,
          semanticLabel: semanticLabel,
        );

  const DeliveryButton.ghost({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    IconData? trailingIcon,
    bool loading = false,
    bool isLoading = false,
    bool expand = false,
    bool? fullWidth,
    DeliveryButtonSize size = DeliveryButtonSize.md,
    String? semanticLabel,
  }) : this(
          key: key,
          label: label,
          onPressed: onPressed,
          variant: DeliveryButtonVariant.ghost,
          size: size,
          icon: icon,
          trailingIcon: trailingIcon,
          loading: loading || isLoading,
          expand: fullWidth ?? expand,
          semanticLabel: semanticLabel,
        );

  const DeliveryButton.danger({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    IconData? trailingIcon,
    bool loading = false,
    bool isLoading = false,
    bool expand = true,
    bool? fullWidth,
    DeliveryButtonSize size = DeliveryButtonSize.lg,
    String? semanticLabel,
  }) : this(
          key: key,
          label: label,
          onPressed: onPressed,
          variant: DeliveryButtonVariant.danger,
          size: size,
          icon: icon,
          trailingIcon: trailingIcon,
          loading: loading || isLoading,
          expand: fullWidth ?? expand,
          semanticLabel: semanticLabel,
        );

  final String label;
  final VoidCallback? onPressed;
  final DeliveryButtonVariant variant;
  final DeliveryButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool loading;
  final bool expand;
  final String? semanticLabel;

  double get _minHeight => switch (size) {
        DeliveryButtonSize.sm => DeliverySize.buttonSm,
        DeliveryButtonSize.md => DeliverySize.buttonMd,
        DeliveryButtonSize.lg => DeliverySize.buttonLg,
      };

  EdgeInsets get _padding => switch (size) {
        DeliveryButtonSize.sm => const EdgeInsets.symmetric(
            horizontal: DeliverySpace.md,
            vertical: DeliverySpace.xs,
          ),
        DeliveryButtonSize.md => const EdgeInsets.symmetric(
            horizontal: DeliverySpace.lg,
            vertical: DeliverySpace.sm,
          ),
        DeliveryButtonSize.lg => const EdgeInsets.symmetric(
            horizontal: DeliverySpace.xl,
            vertical: DeliverySpace.md,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final effectiveOnPressed = loading ? null : onPressed;

    final (Color bg, Color fg, Color? borderColor, Color hoverOverlay) =
        switch (variant) {
      DeliveryButtonVariant.primary => (
          c.brand,
          c.onBrand,
          null,
          c.onBrand.withValues(alpha: DeliveryOpacity.pressed),
        ),
      DeliveryButtonVariant.secondary => (
          c.surface,
          c.textPrimary,
          c.borderStrong,
          c.brand.withValues(alpha: DeliveryOpacity.hover),
        ),
      DeliveryButtonVariant.tonal => (
          c.brandContainer,
          c.onBrandContainer,
          c.brandBorder,
          c.brand.withValues(alpha: DeliveryOpacity.hover),
        ),
      DeliveryButtonVariant.ghost => (
          Colors.transparent,
          c.brand,
          null,
          c.brand.withValues(alpha: DeliveryOpacity.hover),
        ),
      DeliveryButtonVariant.danger => (
          c.danger.solid,
          c.danger.onSolid,
          null,
          c.danger.onSolid.withValues(alpha: DeliveryOpacity.pressed),
        ),
    };

    final textStyle = (size == DeliveryButtonSize.sm
            ? t.labelMedium
            : t.labelLarge)
        .copyWith(color: effectiveOnPressed == null ? c.textDisabled : fg);

    final style = ButtonStyle(
      elevation: const WidgetStatePropertyAll(0),
      minimumSize: WidgetStatePropertyAll(
        Size(expand ? double.infinity : DeliverySize.minTouch, _minHeight),
      ),
      padding: WidgetStatePropertyAll(_padding),
      backgroundColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.disabled)) {
          return variant == DeliveryButtonVariant.ghost
              ? Colors.transparent
              : c.surfaceMuted;
        }
        if (s.contains(WidgetState.pressed) &&
            variant == DeliveryButtonVariant.primary) {
          return c.brandPressed;
        }
        if (s.contains(WidgetState.hovered) &&
            variant == DeliveryButtonVariant.primary) {
          return c.brandHover;
        }
        return bg;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.disabled)) return c.textDisabled;
        return fg;
      }),
      overlayColor: WidgetStatePropertyAll(hoverOverlay),
      shape: WidgetStatePropertyAll(
        const RoundedRectangleBorder(borderRadius: DeliveryRadius.rMd),
      ),
      side: deliveryOutline(
        context,
        focusRing: c.focusRing,
        normal: borderColor != null
            ? BorderSide(color: borderColor, width: DeliverySize.stroke)
            : BorderSide.none,
      ),
      textStyle: WidgetStatePropertyAll(textStyle),
    );

    final Widget content = loading
        ? Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: DeliveryIconSize.md,
                height: DeliveryIconSize.md,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: fg,
                ),
              ),
              const SizedBox(width: DeliverySpace.sm),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          )
        : Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: DeliveryIconSize.md),
                const SizedBox(width: DeliverySpace.sm),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: DeliverySpace.xs),
                Icon(trailingIcon, size: DeliveryIconSize.sm),
              ],
            ],
          );

    final button = switch (variant) {
      DeliveryButtonVariant.primary ||
      DeliveryButtonVariant.danger =>
        FilledButton(
          onPressed: effectiveOnPressed,
          style: style,
          child: content,
        ),
      DeliveryButtonVariant.secondary ||
      DeliveryButtonVariant.tonal =>
        OutlinedButton(
          onPressed: effectiveOnPressed,
          style: style,
          child: content,
        ),
      DeliveryButtonVariant.ghost => TextButton(
          onPressed: effectiveOnPressed,
          style: style,
          child: content,
        ),
    };

    if (semanticLabel == null) return button;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: button,
    );
  }
}

/// Accessible 48x48 icon action button with mandatory tooltip + semantic label.
class DeliveryIconButton extends StatelessWidget {
  const DeliveryIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badgeCount = 0,
    this.tonal = false,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final int badgeCount;
  final bool tonal;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    Widget iconWidget = Icon(
      icon,
      size: DeliveryIconSize.md,
      color: color ?? (tonal ? c.onBrandContainer : c.textPrimary),
    );
    if (badgeCount > 0) {
      iconWidget = Stack(
        clipBehavior: Clip.none,
        children: [
          iconWidget,
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: DeliverySpace.xxs),
              decoration: BoxDecoration(
                color: c.danger.solid,
                borderRadius: DeliveryRadius.rFull,
                border: Border.all(color: c.surface, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                style: t.caption.copyWith(
                  color: c.danger.onSolid,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Semantics(
      button: true,
      label: tooltip,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        constraints: const BoxConstraints(
          minWidth: DeliverySize.minTouch,
          minHeight: DeliverySize.minTouch,
        ),
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(
            tonal ? c.brandContainer : Colors.transparent,
          ),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: DeliveryRadius.rMd),
          ),
          side: deliveryOutline(context, focusRing: c.focusRing),
        ),
        icon: iconWidget,
      ),
    );
  }
}
