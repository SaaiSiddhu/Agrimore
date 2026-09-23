import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/seller_application_provider.dart';
import '../../providers/seller_auth_provider.dart';
import '../auth/widgets/auth_brand_panel.dart';
import '../auth/widgets/support_contact_card.dart';

/// A-05 intro (ADR §10.1): what the application needs, then "Start
/// application", which creates the draft; the gate then opens the stepper.
class ApplyIntroScreen extends StatefulWidget {
  const ApplyIntroScreen({super.key, this.applicationFactory});

  /// Injected in tests; defaults to a Firebase-backed provider.
  final SellerApplicationProvider Function()? applicationFactory;

  @override
  State<ApplyIntroScreen> createState() => _ApplyIntroScreenState();
}

class _ApplyIntroScreenState extends State<ApplyIntroScreen> {
  bool _starting = false;
  bool _failed = false;

  Future<void> _start() async {
    final auth = context.read<SellerAuthProvider>();
    setState(() {
      _starting = true;
      _failed = false;
    });
    final app = (widget.applicationFactory ?? SellerApplicationProvider.new)();
    await app.loadOrStart();
    if (!mounted) return;
    if (app.lastActionFailed) {
      setState(() {
        _starting = false;
        _failed = true;
      });
      return;
    }
    await auth.refresh(); // → SellerAccess.draft → the stepper
    if (mounted) setState(() => _starting = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<SellerAuthProvider>();
    final t = context.ws;
    final text = context.wsText;
    final needs = <(IconData, String)>[
      (AgIcons.store, l10n.applyNeedBusiness),
      (AgIcons.location, l10n.applyNeedAddress),
      (AgIcons.camera, l10n.applyNeedDocuments),
      (AgIcons.bank, l10n.applyNeedPayout),
    ];

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
                    const SizedBox(height: WsSpace.s32),
                    Text(l10n.applyTitle, style: text.headlineMedium),
                    const SizedBox(height: WsSpace.s8),
                    Text(l10n.applySubhead, style: text.bodyLarge!.copyWith(color: t.textSecondary)),
                    const SizedBox(height: WsSpace.s24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(WsSpace.s16),
                        child: Column(
                          children: [
                            for (final (icon, label) in needs)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: WsSpace.s8),
                                child: Row(
                                  children: [
                                    Container(
                                      width: WsSize.avatarMd,
                                      height: WsSize.avatarMd,
                                      decoration: BoxDecoration(color: t.primarySubtle, shape: BoxShape.circle),
                                      child: Icon(icon, color: t.primary, size: WsIconSize.control),
                                    ),
                                    const SizedBox(width: WsSpace.s12),
                                    Expanded(child: Text(label, style: text.bodyLarge)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: WsSpace.s24),
                    if (_failed) ...[
                      SaInfoBanner(variant: SaBannerVariant.error, message: l10n.saveFailed),
                      const SizedBox(height: WsSpace.s16),
                    ],
                    SaLoadingButton(
                      text: l10n.applyStartCta,
                      loadingText: l10n.saving,
                      isLoading: _starting,
                      onPressed: _starting ? null : _start,
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
    );
  }
}
