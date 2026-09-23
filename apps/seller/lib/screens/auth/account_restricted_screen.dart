import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/seller_auth_provider.dart';
import 'widgets/auth_brand_panel.dart';
import 'widgets/support_contact_card.dart';

/// Why the workspace is closed to this account.
enum RestrictionReason { noAccount, rejected, suspended }

/// A-07 Account restricted (ADR §10.1): rejected, suspended, or — until
/// SELLER-AUTH-1b ships the in-app application — no seller account yet.
/// Always says what happened, what it affects and how to get help.
class AccountRestrictedScreen extends StatelessWidget {
  const AccountRestrictedScreen({super.key, required this.reason});

  final RestrictionReason reason;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<SellerAuthProvider>();
    final t = context.ws;
    final text = context.wsText;
    final phone = auth.signedInPhone;

    final (IconData icon, Color fg, Color bg, String title, String body) = switch (reason) {
      RestrictionReason.rejected => (
          AgIcons.error,
          t.errorFg,
          t.errorBg,
          l10n.restrictedRejectedTitle,
          l10n.restrictedRejectedBody,
        ),
      RestrictionReason.suspended => (
          AgIcons.warning,
          t.warningFg,
          t.warningBg,
          l10n.restrictedSuspendedTitle,
          l10n.restrictedSuspendedBody,
        ),
      RestrictionReason.noAccount => (
          AgIcons.store,
          t.primary,
          t.primarySubtle,
          l10n.restrictedNoAccountTitle,
          phone == null || phone.isEmpty
              ? l10n.restrictedNoAccountBodyGeneric
              : l10n.restrictedNoAccountBody(AgFormat.maskPhone(phone)),
        ),
    };

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: WsSpace.page, vertical: WsSpace.s32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: WsSize.formMaxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AuthWordmark(),
                    const SizedBox(height: WsSpace.s40),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: WsSize.avatarLg,
                        height: WsSize.avatarLg,
                        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                        child: Icon(icon, color: fg, size: WsIconSize.feature),
                      ),
                    ),
                    const SizedBox(height: WsSpace.s24),
                    Text(title, style: text.headlineMedium),
                    const SizedBox(height: WsSpace.s8),
                    Text(body, style: text.bodyLarge!.copyWith(color: t.textSecondary)),
                    const SizedBox(height: WsSpace.s32),
                    const SupportContactCard(),
                    const SizedBox(height: WsSpace.s16),
                    SignOutButton(onConfirmed: auth.signOut),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
