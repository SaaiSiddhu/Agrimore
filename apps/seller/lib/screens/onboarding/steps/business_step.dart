import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/seller_application_provider.dart';
import '../application_rules.dart';
import '../application_screen.dart';
import '../widgets/application_copy.dart';
import '../widgets/step_footer.dart';

/// Step 1 — business details.
class BusinessStep extends StatefulWidget {
  const BusinessStep({super.key});

  @override
  State<BusinessStep> createState() => _BusinessStepState();
}

class _BusinessStepState extends State<BusinessStep> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _shop;
  late final TextEditingController _gstin;
  String? _category;

  @override
  void initState() {
    super.initState();
    final d = context.read<SellerApplicationProvider>().data;
    _name = TextEditingController(text: d['name'] as String? ?? '');
    _shop = TextEditingController(text: d['shopName'] as String? ?? '');
    _gstin = TextEditingController(text: d['gstin'] as String? ?? '');
    final c = d['businessCategory'] as String?;
    _category = ApplicationRules.categories.contains(c) ? c : null;
  }

  @override
  void dispose() {
    _name.dispose();
    _shop.dispose();
    _gstin.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_form.currentState!.validate()) return;
    await context.read<SellerApplicationProvider>().saveAndAdvance({
      'name': _name.text.trim(),
      'shopName': _shop.text.trim(),
      'businessCategory': _category,
      'gstin': _gstin.text.trim().toUpperCase(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final app = context.watch<SellerApplicationProvider>();
    String? required(String? v) => ApplicationRules.text(v) ? null : l10n.errRequired;

    return StepBody(
      footer: StepFooter(
        primaryLabel: l10n.saveContinue,
        busyLabel: l10n.saving,
        busy: app.isSaving,
        onPrimary: _continue,
      ),
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                decoration: InputDecoration(labelText: l10n.fieldOwnerName),
                validator: required,
              ),
              const SizedBox(height: WsSpace.s16),
              TextFormField(
                controller: _shop,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: l10n.fieldShopName,
                  prefixIcon: const Icon(AgIcons.store, size: WsIconSize.control),
                ),
                validator: required,
              ),
              const SizedBox(height: WsSpace.s16),
              DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.fieldCategory),
                items: [
                  for (final c in ApplicationRules.categories)
                    DropdownMenuItem(value: c, child: Text(ApplicationCopy.category(l10n, c))),
                ],
                onChanged: (v) => setState(() => _category = v),
                validator: (v) => v == null ? l10n.errRequired : null,
              ),
              const SizedBox(height: WsSpace.s16),
              TextFormField(
                controller: _gstin,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(labelText: l10n.fieldGstin, helperText: l10n.fieldGstinHelp),
                validator: (v) {
                  final value = (v ?? '').trim().toUpperCase();
                  if (value.isEmpty) return null;
                  return ApplicationRules.gstin.hasMatch(value) ? null : l10n.errGstin;
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
