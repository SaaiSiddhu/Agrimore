import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';

/// GST slabs a product can declare (percent). `null` = not declared.
const List<double> kGstRates = [0, 5, 12, 18, 28];

/// HSN codes are 4, 6 or 8 digits (SAC codes for services start with 99).
final RegExp kHsnPattern = RegExp(r'^(\d{4}|\d{6}|\d{8})$');

/// C-03 "Price & tax" (ADR §10.4, SELLER-CATALOGUE-1): HSN code + GST rate,
/// used by GST invoices (SELLER-ORDERS-2). Both optional — most fresh produce
/// is GST-exempt and many sellers are unregistered; an invoice without them
/// is issued as a bill of supply.
class ProductTaxSection extends StatelessWidget {
  const ProductTaxSection({
    super.key,
    required this.hsnController,
    required this.gstRate,
    required this.onGstRateChanged,
  });

  final TextEditingController hsnController;
  final double? gstRate;
  final ValueChanged<double?> onGstRateChanged;

  static const int _hsnMaxLength = 8;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = context.wsText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.taxSectionTitle, style: text.titleSmall),
        const SizedBox(height: WsSpace.s4),
        Text(l10n.taxSectionHelp, style: text.bodySmall),
        const SizedBox(height: WsSpace.s12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: hsnController,
                keyboardType: TextInputType.number,
                maxLength: _hsnMaxLength,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: l10n.fieldHsn, counterText: ''),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return null;
                  return kHsnPattern.hasMatch(value) ? null : l10n.errHsn;
                },
              ),
            ),
            const SizedBox(width: WsSpace.s12),
            Expanded(
              child: DropdownButtonFormField<double?>(
                initialValue: gstRate,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.fieldGstRate),
                items: [
                  DropdownMenuItem<double?>(value: null, child: Text(l10n.gstNotDeclared)),
                  for (final r in kGstRates)
                    DropdownMenuItem<double?>(value: r, child: Text(l10n.gstRatePercent(r.round()))),
                ],
                onChanged: onGstRateChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
