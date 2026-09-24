import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../icons/seller_icons.dart';
import '../tokens/seller_colors.dart';
import '../tokens/seller_tokens.dart';
import '../tokens/seller_typography.dart';

/// Inline, persistent message (board 13): tinted container, an icon that
/// repeats the meaning, optional title, message, action and dismiss.
/// Errors that follow a user action are announced politely ([announce]);
/// routine status banners never steal focus.
class SellerBanner extends StatelessWidget {
  const SellerBanner({
    super.key,
    required this.message,
    this.tone = SellerTone.info,
    this.title,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
    this.announce = false,
    this.trailing,
  });

  final String message;
  final SellerTone tone;
  final String? title;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;
  final bool announce;

  /// A widget at the end (e.g. an outlined "Resume" button).
  final Widget? trailing;

  IconData get _icon =>
      icon ??
      switch (tone) {
        SellerTone.success => SellerIcons.success,
        SellerTone.warning => SellerIcons.warning,
        SellerTone.danger => SellerIcons.error,
        _ => SellerIcons.info,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    // Informational banners use the brand's tinted surface (boards 16-01, 16-06);
    // status banners use their own tone pair.
    final brandTinted = tone == SellerTone.info || tone == SellerTone.brand || tone == SellerTone.neutral;
    final pair = c.tone(tone);
    final fill = brandTinted ? c.primarySubtle : pair.container;
    final iconColor = brandTinted ? c.primary : pair.foreground;
    return Semantics(
      container: true,
      liveRegion: announce,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(SellerSpace.s16, SellerSpace.s12, SellerSpace.s8, SellerSpace.s12),
        decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(SellerRadius.card)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: SellerSpace.s2),
              child: ExcludeSemantics(child: Icon(_icon, size: SellerIconSize.md, color: iconColor)),
            ),
            const SizedBox(width: SellerSpace.s12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: SellerSpace.s8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title != null) ...[
                      Text(title!, style: text.titleSmall!.copyWith(color: tone == SellerTone.danger ? c.danger : c.textPrimary)),
                      const SizedBox(height: SellerSpace.s2),
                    ],
                    Text(message, style: text.bodyMedium!.copyWith(color: c.textPrimary)),
                    if (actionLabel != null && onAction != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: onAction,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: SellerSpace.s4),
                            foregroundColor: tone == SellerTone.danger ? c.danger : c.primary,
                            textStyle: text.labelLarge!.copyWith(decoration: TextDecoration.underline),
                          ),
                          child: Text(actionLabel!),
                        ),
                      ),
                    if (trailing != null) ...[
                      const SizedBox(height: SellerSpace.s8),
                      trailing!,
                    ],
                  ],
                ),
              ),
            ),
            if (onDismiss != null)
              IconButton(
                tooltip: AppLocalizations.of(context).dsClose,
                onPressed: onDismiss,
                icon: Icon(SellerIcons.close, size: SellerIconSize.md, color: c.textSecondary),
              ),
          ],
        ),
      ),
    );
  }
}
