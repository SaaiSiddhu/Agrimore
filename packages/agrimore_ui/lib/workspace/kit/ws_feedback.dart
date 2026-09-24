import 'package:flutter/material.dart';

import '../ws_foundation.dart';
import '../ws_icons.dart';
import '../ws_tokens.dart';

/// Tone of a transient message (ADR §7 `WsToast`): never colour alone — an
/// icon carries the same meaning.
enum WsToastTone { neutral, success, error }

/// Workspace feedback (ADR §7): the only way Workspace apps show a transient
/// message or a confirmation. canon_check's FEEDBACK rule flags raw
/// SnackBar / AlertDialog in apps; these wrap them once, themed.
abstract final class WsToast {
  WsToast._();

  static void show(BuildContext context, String message, {WsToastTone tone = WsToastTone.neutral}) {
    final t = context.ws;
    final (IconData? icon, Color? color) = switch (tone) {
      WsToastTone.success => (AgIcons.success, t.successFg),
      WsToastTone.error => (AgIcons.error, t.errorFg),
      WsToastTone.neutral => (null, null),
    };
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Row(children: [
          if (icon != null) ...[
            Icon(icon, size: WsIconSize.control, color: color),
            const SizedBox(width: WsSpace.s12),
          ],
          Expanded(child: Text(message)),
        ]),
      ));
  }
}

/// A two-button confirmation; resolves true only on the confirm button.
/// [icon] heads the dialog; a long [message] scrolls; [dismissible] false
/// keeps a tap outside from closing it (a disclosure the user must answer).
Future<bool> wsConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
  IconData? icon,
  bool dismissible = true,
}) async {
  final t = context.ws;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: dismissible,
    builder: (ctx) => AlertDialog(
      icon: icon == null ? null : Icon(icon, size: WsIconSize.feature, color: t.primary),
      title: Text(title),
      content: SingleChildScrollView(child: Text(message)),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(cancelLabel)),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: t.errorFg, foregroundColor: t.surface) : null,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}
