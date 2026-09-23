import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/seller_auth_provider.dart';

/// Inline error for auth forms (ADR §11 "Errors"): localised copy for the
/// kinds we can name, the server's own sentence for rate limits and
/// unavailability (it carries the retry detail), never a raw exception.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.error, this.serverMessage});

  final SellerAuthError error;
  final String? serverMessage;

  @override
  Widget build(BuildContext context) {
    if (error == SellerAuthError.none) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final String message;
    switch (error) {
      case SellerAuthError.network:
        message = l10n.errorNetwork;
      case SellerAuthError.rateLimited:
      case SellerAuthError.unavailable:
      case SellerAuthError.invalidCode:
        message = serverMessage ?? l10n.errorGeneric;
      case SellerAuthError.conflict:
      case SellerAuthError.generic:
      case SellerAuthError.none:
        message = l10n.errorGeneric;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: WsSpace.s16),
      child: SaInfoBanner(variant: SaBannerVariant.error, message: message),
    );
  }
}
