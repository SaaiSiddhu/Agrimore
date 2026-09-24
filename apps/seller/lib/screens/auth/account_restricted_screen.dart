import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/seller_application_provider.dart';
import '../../providers/seller_auth_provider.dart';
import '../account/widgets/support_card.dart';
import '../onboarding/widgets/step_footer.dart';

/// Why the workspace is closed to this account.
enum RestrictionReason { rejected, suspended }

/// A-07 Not approved (board 16-07, with "Fix and resubmit", which reopens
/// the application as a draft) or suspended (board 16-08). Always says what
/// happened, what it affects and how to get help.
class AccountRestrictedScreen extends StatelessWidget {
  const AccountRestrictedScreen({super.key, required this.reason, this.applicationFactory});

  final RestrictionReason reason;

  /// Injected in tests; defaults to a Firebase-backed provider.
  final SellerApplicationProvider Function()? applicationFactory;

  Future<void> _reopen(BuildContext context) async {
    final auth = context.read<SellerAuthProvider>();
    final app = (applicationFactory ?? SellerApplicationProvider.new)();
    if (await app.reopenAfterRejection()) await auth.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<SellerAuthProvider>();
    final text = context.text;
    final (IconData icon, IconData badge, SellerTone tone, String title, String body) = switch (reason) {
      RestrictionReason.rejected => (SellerIcons.document, SellerIcons.error, SellerTone.danger, l10n.restrictedRejectedTitle, l10n.restrictedRejectedBody),
      RestrictionReason.suspended => (SellerIcons.shieldAlert, SellerIcons.warning, SellerTone.warning, l10n.restrictedSuspendedTitle, l10n.restrictedSuspendedBody),
    };
    return Scaffold(
      body: SafeArea(
        child: SellerPage(
          gap: SellerSpace.s16,
          children: [
            const Center(child: SellerLogo()),
            Center(child: SellerIllustration(icon: icon, badge: badge, tone: tone)),
            Semantics(header: true, child: Text(title, style: text.headlineMedium, textAlign: TextAlign.center)),
            Text(body, style: text.bodyLarge!.copyWith(color: context.colors.textSecondary), textAlign: TextAlign.center),
            if (reason == RestrictionReason.rejected)
              SellerButton(label: l10n.applyReopenCta, icon: SellerIcons.edit, onPressed: () => _reopen(context)),
            const SizedBox(height: SellerSpace.s8),
            const SellerSupportCard(),
            Center(child: ApplicationSignOut(onConfirmed: auth.signOut)),
          ],
        ),
      ),
    );
  }
}
