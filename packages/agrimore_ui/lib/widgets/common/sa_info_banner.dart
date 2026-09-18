// ignore_for_file: public_member_api_docs

import 'package:flutter/material.dart';
import '../../themes/sales_associate_icons.dart';
import '../../themes/sales_associate_tokens.dart';

/// Banner severity kind.
enum SaBannerVariant {
  /// Informational banner with blue surface (#EFF6FF).
  info,

  /// Warning banner with amber surface (#FFFBEB).
  warning,

  /// Error banner with red surface (#FEF2F2).
  error,

  /// Success banner with green surface (#F0FDF4).
  success,
}

/// Canonical inline status banner for AgriMore Sales Associate.
///
/// Implements the inline feedback banners from canonical boards 05 and 06:
/// - Distinct from [ErrorView] and [EmptyStateWidget] (which are full-screen
///   placeholder views).  [SaInfoBanner] is an inline card for form feedback,
///   status notices, and contextual hints.
/// - Surface colours and icons align with canonical semantic tokens.
/// - Pairs an icon with clear text (never relies on colour alone).
/// - 12 px corner radius matching input controls.
class SaInfoBanner extends StatelessWidget {
  const SaInfoBanner({
    super.key,
    required this.message,
    this.variant = SaBannerVariant.info,
    this.title,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  /// Primary message text.
  final String message;

  /// Visual severity variant.
  final SaBannerVariant variant;

  /// Optional bold title displayed above the message.
  final String? title;

  /// Optional override icon.  If null, defaults to the canonical variant icon.
  final IconData? icon;

  /// Optional action button label (e.g., "Retry").
  final String? actionLabel;

  /// Callback when the action button is tapped.
  final VoidCallback? onAction;

  IconData get _defaultIcon => switch (variant) {
        SaBannerVariant.info => SaIcons.info,
        SaBannerVariant.warning => SaIcons.triangleAlert,
        SaBannerVariant.error => SaIcons.circleAlert,
        SaBannerVariant.success => SaIcons.circleCheck,
      };

  Color get _surfaceColor => switch (variant) {
        SaBannerVariant.info => SaTokens.primarySubtle,
        SaBannerVariant.warning => SaTokens.warningBg,
        SaBannerVariant.error => SaTokens.errorBg,
        SaBannerVariant.success => SaTokens.successBg,
      };

  Color get _foregroundAccent => switch (variant) {
        SaBannerVariant.info => SaTokens.primary,
        SaBannerVariant.warning => SaTokens.warningFg,
        SaBannerVariant.error => SaTokens.errorFg,
        SaBannerVariant.success => SaTokens.successFg,
      };

  Color get _borderColor => switch (variant) {
        SaBannerVariant.info => const Color(0xFFBFDBFE), // blue-200
        SaBannerVariant.warning => const Color(0xFFFDE68A), // amber-200
        SaBannerVariant.error => const Color(0xFFFECACA), // red-200
        SaBannerVariant.success => const Color(0xFFBBF7D0), // green-200
      };

  @override
  Widget build(BuildContext context) {
    final effectiveIcon = icon ?? _defaultIcon;

    return Semantics(
      container: true,
      label: title != null ? '$title: $message' : message,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(SaTokens.space12),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(SaTokens.radiusInput),
          border: Border.all(color: _borderColor, width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              effectiveIcon,
              size: SaTokens.iconControl,
              color: _foregroundAccent,
            ),
            const SizedBox(width: SaTokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null) ...[
                    Text(
                      title!,
                      style: TextStyle(
                        fontSize: SaTokens.fsLabel,
                        fontWeight: FontWeight.w600,
                        color: _foregroundAccent,
                      ),
                    ),
                    const SizedBox(height: SaTokens.space4),
                  ],
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: SaTokens.fsLabel,
                      color: SaTokens.textPrimary,
                      height: 1.4,
                    ),
                  ),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: SaTokens.space8),
                    InkWell(
                      onTap: onAction,
                      child: Text(
                        actionLabel!,
                        style: TextStyle(
                          fontSize: SaTokens.fsLabel,
                          fontWeight: FontWeight.w600,
                          color: _foregroundAccent,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
