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
Future<bool> wsConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
}) async {
  final t = context.ws;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
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
