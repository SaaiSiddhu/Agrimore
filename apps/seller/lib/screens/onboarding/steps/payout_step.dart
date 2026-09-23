import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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
    final text = context.wsText;
    String? required(String? v) => ApplicationRules.text(v) ? null : l10n.errRequired;

    return StepBody(
      footer: StepFooter(
        primaryLabel: l10n.saveContinue,
        busyLabel: l10n.saving,
        busy: app.isSaving,
        onPrimary: _continue,
        onBack: app.back,
      ),
      children: [
        Text(l10n.payoutHelp, style: text.bodyLarge),
        const SizedBox(height: WsSpace.s16),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'bank', icon: const Icon(AgIcons.bank), label: Text(l10n.payoutBank)),
            ButtonSegment(value: 'upi', icon: const Icon(AgIcons.wallet), label: Text(l10n.payoutUpi)),
          ],
          selected: {_method},
          onSelectionChanged: (s) => setState(() => _method = s.first),
        ),
        const SizedBox(height: WsSpace.s24),
        Form(
          key: _form,
          child: _method == 'bank'
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _holder,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(labelText: l10n.fieldAccountHolder),
                      validator: required,
                    ),
                    const SizedBox(height: WsSpace.s16),
                    TextFormField(
                      controller: _bank,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(labelText: l10n.fieldBankName),
                      validator: required,
                    ),
                    const SizedBox(height: WsSpace.s16),
                    TextFormField(
                      controller: _account,
                      keyboardType: TextInputType.number,
                      maxLength: _accountMaxLength,
                      obscureText: true,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(labelText: l10n.fieldAccountNumber, counterText: ''),
                      validator: (v) => ApplicationRules.account.hasMatch(v ?? '') ? null : l10n.errAccount,
                    ),
                    const SizedBox(height: WsSpace.s16),
                    TextFormField(
                      controller: _accountConfirm,
                      keyboardType: TextInputType.number,
                      maxLength: _accountMaxLength,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(labelText: l10n.fieldAccountNumberConfirm, counterText: ''),
                      validator: (v) => v == _account.text ? null : l10n.accountMismatch,
                    ),
                    const SizedBox(height: WsSpace.s16),
                    TextFormField(
                      controller: _ifsc,
                      maxLength: _ifscLength,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                        TextInputFormatter.withFunction(
                          (_, v) => v.copyWith(text: v.text.toUpperCase()),
                        ),
                      ],
                      decoration: InputDecoration(labelText: l10n.fieldIfsc, counterText: ''),
                      validator: (v) => ApplicationRules.ifsc.hasMatch(v ?? '') ? null : l10n.errIfsc,
                    ),
                  ],
                )
              : TextFormField(
                  controller: _upi,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: l10n.fieldUpiId),
                  validator: (v) => ApplicationRules.upi.hasMatch((v ?? '').trim()) ? null : l10n.errUpi,
                ),
        ),
      ],
    );
  }
}
