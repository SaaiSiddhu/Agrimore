import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/seller_auth_provider.dart';
import '../account/widgets/support_card.dart';
import '../onboarding/widgets/step_footer.dart';

/// A-06 Application under review (board 16-06): logo, illustration, what
/// is happening, the three-step status, Check status, support and sign
/// out. The gate moves on as soon as [SellerAuthProvider.refresh] resolves
/// `approved`.
class ApplicationStatusScreen extends StatefulWidget {
  const ApplicationStatusScreen({super.key});

  @override
  State<ApplicationStatusScreen> createState() => _ApplicationStatusScreenState();
}

class _ApplicationStatusScreenState extends State<ApplicationStatusScreen> {
  bool _checked = false;
  bool _checking = false;

  Future<void> _refresh() async {
    final auth = context.read<SellerAuthProvider>();
    setState(() => _checking = true);
    await auth.refresh();
    if (mounted) {
      setState(() {
        _checked = true;
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<SellerAuthProvider>();
    final text = context.text;
    return Scaffold(
      body: SafeArea(
        child: SellerPage(
          onRefresh: _refresh,
          gap: SellerSpace.s16,
          children: [
            const Center(child: SellerLogo()),
            const Center(child: SellerIllustration(icon: SellerIcons.document, badge: SellerIcons.pending)),
            Semantics(header: true, child: Text(l10n.statusTitle, style: text.headlineMedium, textAlign: TextAlign.center)),
            Text(l10n.statusSubhead, style: text.bodyLarge!.copyWith(color: context.colors.textSecondary), textAlign: TextAlign.center),
            SellerCard(
              child: SellerTimeline(showCurrentPill: false, steps: [
                SellerTimelineStep(title: l10n.statusStepSubmitted, subtitle: l10n.statusCompleted, state: SellerStepState.done),
                SellerTimelineStep(title: l10n.statusStepReview, subtitle: l10n.statusInProgress, state: SellerStepState.current),
                SellerTimelineStep(title: l10n.statusStepApproved, subtitle: l10n.statusPending, state: SellerStepState.upcoming),
              ]),
            ),
            SellerBanner(
              tone: SellerTone.info,
              message: _checked && auth.access == SellerAccess.pending ? l10n.statusStillPending : l10n.statusCheckHint,
              announce: _checked,
            ),
            SellerButton(label: l10n.statusRefresh, icon: SellerIcons.refresh, loading: _checking, loadingLabel: l10n.statusRefreshing, onPressed: _refresh),
            const SizedBox(height: SellerSpace.s8),
            const SellerSupportCard(),
            Center(child: ApplicationSignOut(onConfirmed: auth.signOut)),
          ],
        ),
      ),
    );
  }
}
