import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';

/// GST slabs a product can declare (percent). `null` = not declared.
const List<double> kGstRates = [0, 5, 12, 18, 28];

/// HSN codes are 4, 6 or 8 digits (SAC codes for services start with 99).
final RegExp kHsnPattern = RegExp(r'^(\d{4}|\d{6}|\d{8})$');

/// "Tax details (optional)" (board 18-06, SELLER-CATALOGUE-1): HSN code +
/// GST rate, used by GST invoices. Both optional — most fresh produce is
/// GST-exempt and many sellers are unregistered; an invoice without them is
/// issued as a bill of supply.
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SellerSectionHeader(title: l10n.taxSectionTitle, subtitle: l10n.taxSectionHelp),
        SellerTextField(
          label: l10n.fieldHsn,
          optional: true,
          controller: hsnController,
          keyboardType: TextInputType.number,
          maxLength: _hsnMaxLength,
          tabular: true,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (v) {
            final value = v.trim();
            if (value.isEmpty) return null;
            return kHsnPattern.hasMatch(value) ? null : l10n.errHsn;
          },
        ),
        const SizedBox(height: SellerSpace.s12),
        SellerSelectField<double?>(
          label: l10n.fieldGstRate,
          optional: true,
          value: gstRate,
          options: [
            SellerOption<double?>(null, l10n.gstNotDeclared),
            for (final r in kGstRates) SellerOption<double?>(r, l10n.gstRatePercent(r.round())),
          ],
          onChanged: onGstRateChanged,
        ),
      ],
    );
  }
}
