import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/seller_application_provider.dart';
import '../../providers/seller_auth_provider.dart';
import '../account/widgets/support_card.dart';
import 'widgets/step_footer.dart';

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

  /// Board 16-03 intro: logo, illustration, what the application needs,
  /// Start application, support and sign out.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<SellerAuthProvider>();
    final text = context.text;
    final needs = <(IconData, String)>[
      (SellerIcons.store, l10n.applyNeedBusiness),
      (SellerIcons.location, l10n.applyNeedAddress),
      (SellerIcons.camera, l10n.applyNeedDocuments),
      (SellerIcons.bank, l10n.applyNeedPayout),
    ];
    return Scaffold(
      body: SafeArea(
        child: SellerPage(
          gap: SellerSpace.s16,
          footer: SellerButton(label: l10n.applyStartCta, trailingIcon: SellerIcons.forward, loading: _starting, loadingLabel: l10n.saving, onPressed: _start),
          children: [
            const SellerLogo(),
            SellerCard(
              tone: SellerCardTone.mint,
              child: Row(children: [
                const SellerLeafMark(size: SellerSize.avatarLg),
                const SizedBox(width: SellerSpace.s12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Semantics(header: true, child: Text(l10n.applyTitle, style: text.titleLarge)),
                    Text(l10n.applyAbout, style: text.bodyMedium!.copyWith(color: context.colors.textPrimary)),
                  ]),
                ),
              ]),
            ),
            Text(l10n.applySubhead, style: text.bodyLarge),
            SellerMenuGroup(children: [
              for (final (icon, label) in needs) SellerListRow(icon: icon, title: label, showChevron: false),
            ]),
            if (_failed) SellerBanner(tone: SellerTone.danger, message: l10n.saveFailed, announce: true),
            const SellerSupportCard(),
            Center(child: ApplicationSignOut(onConfirmed: auth.signOut)),
          ],
        ),
      ),
    );
  }
}
