import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
    final text = context.wsText;
    final uploaded = ApplicationRules.requiredDocuments.where((k) => app.documents[k] is String).length;

    final sections = <(int, List<String>)>[
      (0, [
        d['name'] as String? ?? '',
        d['shopName'] as String? ?? '',
        ApplicationCopy.category(l10n, d['businessCategory'] as String? ?? ''),
        if ((d['gstin'] as String? ?? '').isNotEmpty) d['gstin'] as String,
      ]),
      (1, [
        d['shopAddress'] as String? ?? '',
        '${d['city'] ?? ''}, ${d['state'] ?? ''} ${d['pincode'] ?? ''}',
        l10n.radiusKm((d['deliveryRadiusKm'] as num? ?? 0).round()),
      ]),
      (2, [l10n.reviewDocumentsCount(uploaded, ApplicationRules.requiredDocuments.length)]),
      (3, [
        if (d['payoutMethod'] == 'upi') d['upiId'] as String? ?? ''
        else ...[
          d['accountHolder'] as String? ?? '',
          '${d['bankName'] ?? ''} · ${AgFormat.maskAccount(d['accountNumber'] as String? ?? '')}',
          d['ifsc'] as String? ?? '',
        ],
      ]),
    ];

    return StepBody(
      footer: StepFooter(
        primaryLabel: l10n.submitCta,
        busyLabel: l10n.submitting,
        busy: app.isSaving,
        onPrimary: _submit,
        onBack: app.back,
      ),
      children: [
        Text(l10n.reviewHelp, style: text.bodyLarge),
        const SizedBox(height: WsSpace.s16),
        if (_banner != null) ...[
          SaInfoBanner(variant: SaBannerVariant.error, message: _banner!),
          const SizedBox(height: WsSpace.s16),
        ],
        for (final (step, lines) in sections) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(WsSpace.s16, WsSpace.s8, WsSpace.s8, WsSpace.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(ApplicationCopy.stepTitle(l10n, step), style: text.titleSmall)),
                      TextButton(onPressed: () => app.goTo(step), child: Text(l10n.reviewEdit)),
                    ],
                  ),
                  for (final line in lines.where((l) => l.trim().isNotEmpty))
                    Padding(
                      padding: const EdgeInsets.only(top: WsSpace.s4),
                      child: Text(line, style: text.bodyMedium),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: WsSpace.s12),
        ],
        CheckboxListTile(
          value: _accepted,
          onChanged: (v) => setState(() => _accepted = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.acceptTerms, style: text.bodyMedium),
        ),
      ],
    );
  }
}
