import 'package:flutter/material.dart';

import '../icons/delivery_icons.dart';
import '../tokens/delivery_colors.dart';
import '../tokens/delivery_tokens.dart';
import '../tokens/delivery_typography.dart';
import 'delivery_brand.dart';
import 'delivery_button.dart';
import 'delivery_card.dart';
import 'delivery_states.dart';

/// Illustrated empty state with title, body, and optional primary/secondary
/// actions.
class DeliveryEmptyState extends StatelessWidget {
  const DeliveryEmptyState({
    super.key,
    this.icon,
    this.kind,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.tone = DeliveryTone.brand,
    this.compact = false,
  });

  final IconData? icon;
  final DeliveryIllustrationKind? kind;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final DeliveryTone tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(compact ? DeliverySpace.lg : DeliverySpace.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DeliveryIllustration(
                icon: icon,
                kind: kind,
                tone: kind != null ? null : tone,
                size: compact ? 56 : 76,
              ),
              SizedBox(height: compact ? DeliverySpace.md : DeliverySpace.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: compact ? t.titleMedium : t.titleLarge,
              ),
              if (body != null && body!.isNotEmpty) ...[
                const SizedBox(height: DeliverySpace.sm),
                Text(
                  body!,
                  textAlign: TextAlign.center,
                  style: t.bodyMedium.copyWith(color: c.textSecondary),
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: DeliverySpace.xl),
                DeliveryButton.primary(
                  label: actionLabel!,
                  onPressed: onAction,
                  expand: false,
                ),
              ],
              if (secondaryLabel != null && onSecondary != null) ...[
                const SizedBox(height: DeliverySpace.sm),
                DeliveryButton.ghost(
                  label: secondaryLabel!,
                  onPressed: onSecondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Recoverable error state with clear message and retry action.
class DeliveryErrorState extends StatelessWidget {
  const DeliveryErrorState({
    super.key,
    required this.title,
    this.body,
    this.retryLabel = 'Try again',
    this.onRetry,
    this.icon = DeliveryIcons.cloudOff,
  });

  final String title;
  final String? body;
  final String retryLabel;
  final VoidCallback? onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DeliveryEmptyState(
      icon: icon,
      tone: DeliveryTone.danger,
      title: title,
      body: body,
      actionLabel: onRetry != null ? retryLabel : null,
      onAction: onRetry,
    );
  }
}

/// Accessible skeleton list for initial screen loads.
class DeliveryLoadingList extends StatelessWidget {
  const DeliveryLoadingList({
    super.key,
    this.itemCount = 4,
    this.itemHeight = 96,
    this.padding = const EdgeInsets.all(DeliverySpace.lg),
    this.semanticLabel = 'Loading',
  });

  final int itemCount;
  final double itemHeight;
  final EdgeInsetsGeometry padding;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: ListView.separated(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: DeliverySpace.md),
        itemBuilder: (context, _) => DeliveryCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  DeliverySkeleton(width: 40, height: 40),
                  SizedBox(width: DeliverySpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DeliverySkeleton(width: 140, height: 14),
                        SizedBox(height: DeliverySpace.xs),
                        DeliverySkeleton(width: 96, height: 12),
                      ],
                    ),
                  ),
                  DeliverySkeleton(width: 64, height: 24),
                ],
              ),
              if (itemHeight > 80) ...const [
                SizedBox(height: DeliverySpace.md),
                DeliverySkeleton(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows a themed bottom sheet with grabber handle, safe-area + keyboard-inset
/// padding, and scrollable content.
Future<T?> showDeliverySheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  String? subtitle,
  bool isScrollControlled = true,
  bool isDismissible = true,
}) {
  final c = context.colors;
  final t = context.text;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    useSafeArea: true,
    backgroundColor: c.surface,
    shape: const RoundedRectangleBorder(borderRadius: DeliveryRadius.sheetTop),
    builder: (sheetCtx) {
      final insets = MediaQuery.viewInsetsOf(sheetCtx);
      return Padding(
        padding: EdgeInsets.only(bottom: insets.bottom),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              DeliverySpace.lg,
              DeliverySpace.xs,
              DeliverySpace.lg,
              DeliverySpace.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: t.titleLarge),
                            if (subtitle != null) ...[
                              const SizedBox(height: DeliverySpace.xxs),
                              Text(
                                subtitle,
                                style: t.bodySmall.copyWith(
                                  color: c.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      DeliveryIconButton(
                        icon: DeliveryIcons.close,
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(sheetCtx).maybePop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: DeliverySpace.md),
                  Divider(height: 1, color: c.border),
                  const SizedBox(height: DeliverySpace.lg),
                ],
                builder(sheetCtx),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Shows a confirmation dialog with primary/danger and cancel buttons.
Future<bool> showDeliveryConfirmDialog({
  required BuildContext context,
  required String title,
  required String body,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
  IconData? icon,
}) async {
  final c = context.colors;
  final t = context.text;
  final pair = destructive ? c.danger : c.tone(DeliveryTone.brand);
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: DeliveryRadius.rXl),
      title: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: pair.container,
                borderRadius: DeliveryRadius.rSm,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: DeliveryIconSize.md, color: pair.icon),
            ),
            const SizedBox(width: DeliverySpace.md),
          ],
          Expanded(child: Text(title, style: t.titleLarge)),
        ],
      ),
      content: Text(
        body,
        style: t.bodyMedium.copyWith(color: c.textSecondary),
      ),
      actions: [
        DeliveryButton.secondary(
          label: cancelLabel,
          expand: false,
          onPressed: () => Navigator.of(dialogCtx).pop(false),
        ),
        destructive
            ? DeliveryButton.danger(
                label: confirmLabel,
                expand: false,
                size: DeliveryButtonSize.md,
                onPressed: () => Navigator.of(dialogCtx).pop(true),
              )
            : DeliveryButton.primary(
                label: confirmLabel,
                expand: false,
                size: DeliveryButtonSize.md,
                onPressed: () => Navigator.of(dialogCtx).pop(true),
              ),
      ],
    ),
  );
  return result ?? false;
}

/// Shows a custom disclosure dialog with leading icon, body widget, and action buttons.
Future<bool> showDeliveryDisclosureDialog({
  required BuildContext context,
  required String title,
  required IconData icon,
  required Widget content,
  required String cancelLabel,
  required String confirmLabel,
}) async {
  final c = context.colors;
  final t = context.text;
  final pair = c.tone(DeliveryTone.brand);

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: DeliveryRadius.rXl),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: pair.container,
              borderRadius: DeliveryRadius.rMd,
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: DeliveryIconSize.md,
              color: pair.icon,
            ),
          ),
          const SizedBox(width: DeliverySpace.md),
          Expanded(
            child: Text(title, style: t.titleLarge),
          ),
        ],
      ),
      content: SingleChildScrollView(child: content),
      actions: [
        DeliveryButton.ghost(
          label: cancelLabel,
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
        DeliveryButton.primary(
          label: confirmLabel,
          expand: false,
          size: DeliveryButtonSize.md,
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Shows a floating semantic toast notification.
void showDeliveryToast(
  BuildContext context, {
  required String message,
  DeliveryTone tone = DeliveryTone.neutral,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final c = context.colors;
  final t = context.text;
  final pair = c.tone(tone);
  final bg = tone == DeliveryTone.neutral ? c.textPrimary : pair.solid;
  final fg = tone == DeliveryTone.neutral ? c.surface : pair.onSolid;

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: DeliveryRadius.rMd),
        content: Text(
          message,
          style: t.bodyMedium.copyWith(color: fg, fontWeight: FontWeight.w500),
        ),
        action: actionLabel != null && onAction != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: fg,
                onPressed: onAction,
              )
            : null,
      ),
    );
}
