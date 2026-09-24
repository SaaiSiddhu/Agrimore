import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../icons/seller_icons.dart';
import '../tokens/seller_colors.dart';
import '../tokens/seller_motion.dart';
import '../tokens/seller_tokens.dart';
import '../tokens/seller_typography.dart';
import 'seller_button.dart';

/// Tone of a transient message.
enum SellerToastTone { neutral, success, danger }

/// Brief confirmation above the bottom controls (board 13): deep-teal toast,
/// white text, an icon that repeats the meaning, and a close button. Only
/// called after the server confirmed the action — never optimistically.
abstract final class SellerToast {
  static void show(
    BuildContext context,
    String message, {
    SellerToastTone tone = SellerToastTone.neutral,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final c = context.colors;
    final (IconData? icon, Color? color) = switch (tone) {
      SellerToastTone.success => (SellerIcons.success, c.toastSuccess),
      SellerToastTone.danger => (SellerIcons.error, c.toastDanger),
      SellerToastTone.neutral => (null, null),
    };
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: SellerMotion.toast,
          showCloseIcon: true,
          closeIconColor: c.onToast,
          action: actionLabel == null || onAction == null
              ? null
              : SnackBarAction(label: actionLabel, textColor: c.toastSuccess, onPressed: onAction),
          content: Semantics(
            liveRegion: true,
            child: Row(children: [
              if (icon != null) ...[
                ExcludeSemantics(child: Icon(icon, size: SellerIconSize.md, color: color)),
                const SizedBox(width: SellerSpace.s12),
              ],
              Expanded(child: Text(message)),
            ]),
          ),
          dismissDirection: DismissDirection.horizontal,
        ),
        snackBarAnimationStyle: context.reduceMotion ? AnimationStyle.noAnimation : null,
      );
  }
}

/// A two-choice confirmation (board 14): optional icon in a tinted circle,
/// title, what happens, optional detail (e.g. the product being deleted),
/// then Cancel / Confirm. Resolves true only on the confirm button; dismissal
/// never confirms.
Future<bool> sellerConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String? cancelLabel,
  bool destructive = false,
  IconData? icon,
  Widget? detail,
  String? consequence,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final c = ctx.colors;
      final text = ctx.text;
      final l10n = AppLocalizations.of(ctx);
      final cancel = SellerButton.secondary(
        label: cancelLabel ?? l10n.cancel,
        onPressed: () => Navigator.of(ctx).pop(false),
      );
      final confirm = destructive
          ? SellerButton.danger(label: confirmLabel, onPressed: () => Navigator.of(ctx).pop(true))
          : SellerButton(label: confirmLabel, onPressed: () => Navigator.of(ctx).pop(true));
      return Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: SellerSize.formMaxWidth - SellerSpace.s64 * 2),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(SellerSpace.s24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (icon != null) ...[
                  Center(
                    child: ExcludeSemantics(
                      child: Container(
                        width: SellerSize.avatarLg,
                        height: SellerSize.avatarLg,
                        decoration: BoxDecoration(
                          color: destructive ? c.dangerContainer : c.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: destructive ? c.danger : c.onPrimaryContainer, size: SellerIconSize.lg),
                      ),
                    ),
                  ),
                  const SizedBox(height: SellerSpace.s16),
                ],
                Semantics(
                  header: true,
                  namesRoute: true,
                  child: Text(title, style: text.titleLarge, textAlign: icon != null ? TextAlign.center : TextAlign.start),
                ),
                const SizedBox(height: SellerSpace.s8),
                Text(message, style: text.bodyLarge!.copyWith(color: c.textSecondary), textAlign: icon != null ? TextAlign.center : TextAlign.start),
                if (detail != null) ...[
                  const SizedBox(height: SellerSpace.s16),
                  detail,
                ],
                if (consequence != null) ...[
                  const SizedBox(height: SellerSpace.s12),
                  Text(consequence, style: text.bodyMedium!.copyWith(color: c.danger), textAlign: TextAlign.center),
                ],
                const SizedBox(height: SellerSpace.s24),
                LayoutBuilder(
                  builder: (context, box) {
                    // Side by side when both labels fit; stacked at large text.
                    final scale = MediaQuery.textScalerOf(context).scale(1);
                    if (box.maxWidth / scale < SellerSpace.s64 * 4) {
                      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        confirm,
                        const SizedBox(height: SellerSpace.s8),
                        cancel,
                      ]);
                    }
                    return Row(children: [
                      Expanded(child: cancel),
                      const SizedBox(width: SellerSpace.s12),
                      Expanded(child: confirm),
                    ]);
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  return result == true;
}

/// "Discard changes? — You have unsaved changes." (board 14). True = discard.
Future<bool> sellerConfirmDiscard(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return sellerConfirm(
    context,
    title: l10n.dsDiscardTitle,
    message: l10n.dsDiscardBody,
    confirmLabel: l10n.dsDiscard,
    cancelLabel: l10n.dsKeepEditing,
    destructive: true,
  );
}

/// Asks before leaving a screen with unsaved edits (Android back, iOS swipe,
/// the app-bar back button all go through [PopScope]).
class SellerDiscardGuard extends StatelessWidget {
  const SellerDiscardGuard({super.key, required this.hasChanges, required this.child});

  final bool hasChanges;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await sellerConfirmDiscard(context)) navigator.pop(result);
      },
      child: child,
    );
  }
}

/// Opens a bottom sheet with a drag handle, a title row with a close button,
/// a scrolling body and an optional sticky [footer] that stays above the
/// keyboard (boards 14, 17-06, 18-03, 20-05). One focused task per sheet.
Future<T?> showSellerSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
  WidgetBuilder? footer,
  String? subtitle,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    useSafeArea: true,
    builder: (ctx) => SellerSheetFrame(title: title, subtitle: subtitle, body: builder(ctx), footer: footer?.call(ctx)),
  );
}

/// The layout of a seller sheet — also used directly by sheets that manage state.
class SellerSheetFrame extends StatelessWidget {
  const SellerSheetFrame({super.key, required this.title, required this.body, this.footer, this.subtitle, this.showClose = true});

  final String title;
  final String? subtitle;
  final Widget body;
  final Widget? footer;
  final bool showClose;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final l10n = AppLocalizations.of(context);
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(SellerSpace.s20, 0, SellerSpace.s8, SellerSpace.s4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: SellerSpace.s8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(header: true, namesRoute: true, child: Text(title, style: text.titleLarge)),
                        if (subtitle != null) ...[
                          const SizedBox(height: SellerSpace.s4),
                          Text(subtitle!, style: text.bodyMedium),
                        ],
                      ],
                    ),
                  ),
                ),
                if (showClose)
                  IconButton(
                    tooltip: l10n.dsClose,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(SellerIcons.close),
                  ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(SellerSpace.s20, SellerSpace.s8, SellerSpace.s20, SellerSpace.s16),
              child: body,
            ),
          ),
          if (footer != null)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(SellerSpace.s20, SellerSpace.s8, SellerSpace.s20, SellerSpace.s16),
                child: footer,
              ),
            )
          else
            const SafeArea(top: false, child: SizedBox(height: SellerSpace.s8)),
        ],
      ),
    );
  }
}
