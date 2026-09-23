import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/seller_auth_provider.dart';
import 'widgets/auth_brand_panel.dart';
import 'widgets/support_contact_card.dart';

/// A-06 Application status (ADR §10.1): where the application stands, what
/// happens next, how to reach support. The gate moves the seller on as soon
/// as [SellerAuthProvider.refresh] resolves `approved`.
class ApplicationStatusScreen extends StatefulWidget {
  const ApplicationStatusScreen({super.key});

  @override
  State<ApplicationStatusScreen> createState() => _ApplicationStatusScreenState();
}

class _ApplicationStatusScreenState extends State<ApplicationStatusScreen> {
  bool _checked = false;

  Future<void> _refresh() async {
    final auth = context.read<SellerAuthProvider>();
    await auth.refresh();
    if (mounted) setState(() => _checked = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<SellerAuthProvider>();
    final t = context.ws;
    final text = context.wsText;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
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
                      const SizedBox(height: WsSpace.s32),
                      Text(l10n.statusTitle, style: text.headlineMedium),
                      const SizedBox(height: WsSpace.s8),
                      Text(l10n.statusSubhead, style: text.bodyLarge!.copyWith(color: t.textSecondary)),
                      const SizedBox(height: WsSpace.s24),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(WsSpace.s20),
                          child: WsTimeline(
                            steps: [
                              WsTimelineStep(title: l10n.statusStepSubmitted, state: WsTimelineState.done),
                              WsTimelineStep(title: l10n.statusStepReview, state: WsTimelineState.current),
                              WsTimelineStep(title: l10n.statusStepApproved, state: WsTimelineState.upcoming),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: WsSpace.s16),
                      if (_checked && auth.access == SellerAccess.pending) ...[
                        SaInfoBanner(variant: SaBannerVariant.info, message: l10n.statusStillPending),
                        const SizedBox(height: WsSpace.s16),
                      ],
                      SaLoadingButton(
                        text: l10n.statusRefresh,
                        loadingText: l10n.statusRefreshing,
                        icon: AgIcons.refresh,
                        variant: SaButtonVariant.outlined,
                        isLoading: auth.access == SellerAccess.loading,
                        onPressed: _refresh,
                      ),
                      const SizedBox(height: WsSpace.s24),
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
      ),
    );
  }
}
