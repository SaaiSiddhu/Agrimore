import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/seller_auth_provider.dart';

/// Inline error for auth forms: localised copy for the kinds we can name,
/// the server's own sentence for rate limits and unavailability (it carries
/// the retry detail), never a raw exception. A wrong code is shown under the
/// code boxes instead ([AuthInlineError]).
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.error, this.serverMessage});

  final SellerAuthError error;
  final String? serverMessage;

  @override
  Widget build(BuildContext context) {
    if (error == SellerAuthError.none || error == SellerAuthError.invalidCode) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final message = switch (error) {
      SellerAuthError.network => l10n.errorNetwork,
      SellerAuthError.rateLimited || SellerAuthError.unavailable => serverMessage ?? l10n.errorGeneric,
      _ => l10n.errorGeneric,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: SellerSpace.s16),
      child: SellerBanner(tone: SellerTone.danger, message: message, announce: true),
    );
  }
}

/// "That code didn't work. Try again." under the code boxes (board 16-02):
/// icon + text, so it does not rely on red alone.
class AuthInlineError extends StatelessWidget {
  const AuthInlineError({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(SellerIcons.error, size: SellerIconSize.md, color: c.danger),
          const SizedBox(width: SellerSpace.s8),
          Expanded(child: Text(message, style: context.text.bodyMedium!.copyWith(color: c.danger))),
        ],
      ),
    );
  }
}
