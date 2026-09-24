import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/seller_application_provider.dart';
import '../../../providers/seller_auth_provider.dart';
import '../application_rules.dart';
import '../application_screen.dart';
import '../widgets/application_copy.dart';
import '../widgets/step_footer.dart';

/// Step 5 — review everything, accept the terms, submit through the
/// `submitSellerApplication` callable. On success the auth gate moves to the
/// application-status screen.
class ReviewStep extends StatefulWidget {
  const ReviewStep({super.key});

  @override
  State<ReviewStep> createState() => _ReviewStepState();
}

class _ReviewStepState extends State<ReviewStep> {
  late bool _accepted;
  String? _banner;

  @override
  void initState() {
    super.initState();
    _accepted = context.read<SellerApplicationProvider>().data['acceptedTerms'] == true;
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final app = context.read<SellerApplicationProvider>();
    final auth = context.read<SellerAuthProvider>();
    if (!_accepted) {
      setState(() => _banner = l10n.errRequired);
      return;
    }
    if (!await app.save({'acceptedTerms': true})) return;
    final outcome = await app.submit();
    if (!mounted) return;
    switch (outcome) {
      case SubmitOutcome.submitted:
        await auth.refresh();
      case SubmitOutcome.invalid:
        setState(() => _banner = l10n.submitInvalid);
      case SubmitOutcome.failed:
        setState(() => _banner = l10n.submitFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final app = context.watch<SellerApplicationProvider>();
    final d = app.data;
    final text = context.text;
    final uploaded = ApplicationRules.requiredDocuments.where((k) => app.documents[k] is String).length;

    final sections = <(int, IconData, List<String>)>[
      (0, SellerIcons.business, [
        d['shopName'] as String? ?? '',
        ApplicationCopy.category(l10n, d['businessCategory'] as String? ?? ''),
        d['name'] as String? ?? '',
        if ((d['gstin'] as String? ?? '').isNotEmpty) d['gstin'] as String,
      ]),
      (1, SellerIcons.location, [
        d['shopAddress'] as String? ?? '',
        '${d['city'] ?? ''}, ${d['state'] ?? ''} ${d['pincode'] ?? ''}',
        l10n.radiusKm((d['deliveryRadiusKm'] as num? ?? 0).round()),
      ]),
      (2, SellerIcons.document, [l10n.reviewDocumentsCount(uploaded, ApplicationRules.requiredDocuments.length)]),
      (3, SellerIcons.bank, [
        if (d['payoutMethod'] == 'upi') SellerFormat.maskUpi(d['upiId'] as String? ?? '')
        else ...[
          d['accountHolder'] as String? ?? '',
          l10n.payoutAccountBank(d['bankName'] as String? ?? '', SellerFormat.maskAccount(d['accountNumber'] as String? ?? '')),
          d['ifsc'] as String? ?? '',
        ],
      ]),
    ];

    return StepBody(
      footer: StepFooter(primaryLabel: l10n.submitCta, busyLabel: l10n.submitting, busy: app.isSaving, onPrimary: _submit, onBack: app.back),
      children: [
        Text(l10n.reviewHelp, style: text.bodyLarge),
        const SizedBox(height: SellerSpace.s16),
        if (_banner != null) ...[
          SellerBanner(tone: SellerTone.danger, message: _banner!, announce: true),
          const SizedBox(height: SellerSpace.s16),
        ],
        for (final (step, icon, lines) in sections) ...[
          SellerCard(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SellerIconTile(icon: icon),
              const SizedBox(width: SellerSpace.s12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ApplicationCopy.stepTitle(l10n, step), style: text.titleSmall),
                  for (final line in lines.where((l) => l.trim().isNotEmpty)) Text(line, style: text.bodyMedium!.tabular),
                ]),
              ),
              SellerButton.tertiary(label: l10n.reviewEdit, compact: true, onPressed: () => app.goTo(step)),
            ]),
          ),
          const SizedBox(height: SellerSpace.s12),
        ],
        SellerCheckRow(
          value: _accepted,
          onChanged: (v) => setState(() {
            _accepted = v;
            _banner = null;
          }),
          title: l10n.acceptTerms,
        ),
      ],
    );
  }
}
