// ignore_for_file: public_member_api_docs

import 'package:flutter/material.dart';
import '../../themes/sales_associate_theme_extension.dart';
import '../../themes/sales_associate_tokens.dart';

/// Button visual variant.
enum SaButtonVariant {
  /// Filled blue button (#2563EB) for main actions.
  primary,

  /// Outlined button with blue border for secondary actions.
  outlined,
}

/// Canonical action button for AgriMore Sales Associate.
///
/// Implements the button specifications from canonical boards 05 and 06:
/// - 52 px standard control height ([SaTokens.controlHeight])
/// - 12 px corner radius ([SaTokens.radiusInput])
/// - Interactive states: default, pressed, disabled, and loading
/// - In loading state: shows a 20 px spinner with loading text
/// - Minimum 48 px touch target for accessibility
///
/// Does not duplicate [CustomButton] (which lacks loading-text/spinner states
/// and Sales Associate token binding).
class SaLoadingButton extends StatelessWidget {
  const SaLoadingButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.variant = SaButtonVariant.primary,
    this.isLoading = false,
    this.loadingText,
    this.icon,
    this.fullWidth = true,
  });

  /// Primary button text.
  final String text;

  /// Callback when pressed.  If null, the button is rendered in disabled state.
  final VoidCallback? onPressed;

  /// Button variant: primary (filled) or outlined.
  final SaButtonVariant variant;

  /// Whether the button is currently executing an asynchronous action.
  final bool isLoading;

  /// Optional text displayed next to spinner while [isLoading] is true.
  /// If null, defaults to [text].
  final String? loadingText;

  /// Optional leading icon (shown only when not loading).
  final IconData? icon;

  /// Whether the button expands to fill available horizontal width.
  final bool fullWidth;

  bool get _isEnabled => onPressed != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    final tokens = context.saTokens;
    final effectiveLoadingText = loadingText ?? text;

    final Widget content = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                variant == SaButtonVariant.primary
                    ? Colors.white
                    : tokens.primary,
              ),
            ),
          ),
          const SizedBox(width: SaTokens.space12),
          Text(
            effectiveLoadingText,
            style: const TextStyle(
              fontSize: SaTokens.fsBody,
              fontWeight: FontWeight.w600,
            ),
          ),
        ] else ...[
          if (icon != null) ...[
            Icon(
              icon,
              size: SaTokens.iconControl,
            ),
            const SizedBox(width: SaTokens.space8),
          ],
          Text(
            text,
            style: const TextStyle(
              fontSize: SaTokens.fsBody,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );

    final buttonStyle = switch (variant) {
      SaButtonVariant.primary => ElevatedButton.styleFrom(
          minimumSize: Size(
            fullWidth ? double.infinity : 120,
            SaTokens.controlHeight,
          ),
          backgroundColor: tokens.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: tokens.disabledContainer,
          disabledForegroundColor: tokens.disabledContent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SaTokens.radiusInput),
          ),
        ),
      SaButtonVariant.outlined => OutlinedButton.styleFrom(
          minimumSize: Size(
            fullWidth ? double.infinity : 120,
            SaTokens.controlHeight,
          ),
          foregroundColor: tokens.primary,
          disabledForegroundColor: tokens.disabledContent,
          side: BorderSide(
            color: _isEnabled ? tokens.primary : tokens.disabledContainer,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SaTokens.radiusInput),
          ),
        ),
    };


    final Widget button = switch (variant) {
      SaButtonVariant.primary => ElevatedButton(
          onPressed: _isEnabled ? onPressed : null,
          style: buttonStyle,
          child: content,
        ),
      SaButtonVariant.outlined => OutlinedButton(
          onPressed: _isEnabled ? onPressed : null,
          style: buttonStyle,
          child: content,
        ),
    };

    return Semantics(
      button: true,
      enabled: _isEnabled,
      label: isLoading ? effectiveLoadingText : text,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: SaTokens.minTouchTarget,
        ),
        child: button,
      ),
    );
  }
}
