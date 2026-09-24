import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/seller_application_provider.dart';
import '../application_rules.dart';
import '../application_screen.dart';
import '../widgets/step_footer.dart';

/// Step 4 — payout destination (bank or UPI). Kept in the private
/// sellerRequests/{uid}; the admin approval copies it into
/// seller_payout_details/{uid} (FIX-2) — never into the public sellers doc.
class PayoutStep extends StatefulWidget {
  const PayoutStep({super.key});

  @override
  State<PayoutStep> createState() => _PayoutStepState();
}

class _PayoutStepState extends State<PayoutStep> {
  static const int _ifscLength = 11;
  static const int _accountMaxLength = 18;

  final _form = GlobalKey<FormState>();
  late String _method;
  late final TextEditingController _holder;
  late final TextEditingController _bank;
  late final TextEditingController _account;
  late final TextEditingController _accountConfirm;
  late final TextEditingController _ifsc;
  late final TextEditingController _upi;

  @override
  void initState() {
    super.initState();
    final d = context.read<SellerApplicationProvider>().data;
    _method = d['payoutMethod'] == 'upi' ? 'upi' : 'bank';
    _holder = TextEditingController(text: d['accountHolder'] as String? ?? d['name'] as String? ?? '');
    _bank = TextEditingController(text: d['bankName'] as String? ?? '');
    _account = TextEditingController(text: d['accountNumber'] as String? ?? '');
    _accountConfirm = TextEditingController(text: d['accountNumber'] as String? ?? '');
    _ifsc = TextEditingController(text: d['ifsc'] as String? ?? '');
    _upi = TextEditingController(text: d['upiId'] as String? ?? '');
  }

  @override
  void dispose() {
    for (final c in [_holder, _bank, _account, _accountConfirm, _ifsc, _upi]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_form.currentState!.validate()) return;
    final fields = <String, dynamic>{'payoutMethod': _method};
    if (_method == 'bank') {
      fields.addAll({
        'accountHolder': _holder.text.trim(),
        'bankName': _bank.text.trim(),
        'accountNumber': _account.text.trim(),
        'ifsc': _ifsc.text.trim().toUpperCase(),
      });
    } else {
      fields['upiId'] = _upi.text.trim();
    }
    await context.read<SellerApplicationProvider>().saveAndAdvance(fields);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final app = context.watch<SellerApplicationProvider>();
    String? required(String v) => ApplicationRules.text(v) ? null : l10n.errRequired;
    const gap = SizedBox(height: SellerSpace.s16);

    return StepBody(
      footer: StepFooter(primaryLabel: l10n.saveContinue, busyLabel: l10n.saving, busy: app.isSaving, onPrimary: _continue, onBack: app.back),
      children: [
        Text(l10n.payoutHelp, style: context.text.bodyLarge),
        gap,
        SellerSegmented<String>(
          semanticLabel: l10n.stepPayout,
          segments: [SellerSegment('bank', l10n.payoutBank, icon: SellerIcons.bank), SellerSegment('upi', l10n.payoutUpi, icon: SellerIcons.upi)],
          selected: _method,
          onChanged: (v) => setState(() => _method = v),
        ),
        const SizedBox(height: SellerSpace.s24),
        Form(
          key: _form,
          child: _method == 'bank'
              ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SellerTextField(label: l10n.fieldAccountHolder, required: true, controller: _holder, textCapitalization: TextCapitalization.words, validator: required),
                  gap,
                  SellerTextField(label: l10n.fieldBankName, required: true, controller: _bank, prefixIcon: SellerIcons.bank, textCapitalization: TextCapitalization.words, validator: required),
                  gap,
                  SellerTextField(
                    label: l10n.fieldAccountNumber,
                    required: true,
                    controller: _account,
                    obscure: true,
                    tabular: true,
                    keyboardType: TextInputType.number,
                    maxLength: _accountMaxLength,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => ApplicationRules.account.hasMatch(v) ? null : l10n.errAccount,
                  ),
                  gap,
                  SellerTextField(
                    label: l10n.fieldAccountNumberConfirm,
                    required: true,
                    controller: _accountConfirm,
                    tabular: true,
                    keyboardType: TextInputType.number,
                    maxLength: _accountMaxLength,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => v == _account.text ? null : l10n.accountMismatch,
                  ),
                  gap,
                  SellerTextField(
                    label: l10n.fieldIfsc,
                    required: true,
                    controller: _ifsc,
                    tabular: true,
                    maxLength: _ifscLength,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                      TextInputFormatter.withFunction((_, v) => v.copyWith(text: v.text.toUpperCase())),
                    ],
                    validator: (v) => ApplicationRules.ifsc.hasMatch(v) ? null : l10n.errIfsc,
                  ),
                ])
              : SellerTextField(
                  label: l10n.fieldUpiId,
                  required: true,
                  controller: _upi,
                  prefixIcon: SellerIcons.upi,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => ApplicationRules.upi.hasMatch(v.trim()) ? null : l10n.errUpi,
                ),
        ),
      ],
    );
  }
}
