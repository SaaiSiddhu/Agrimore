import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';

/// Left half of the sign-in layout from 840 dp (board 04): the logo, the
/// landscape, the headline and the three things the app is for.
class AuthBrandPanel extends StatelessWidget {
  const AuthBrandPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final l10n = AppLocalizations.of(context);
    final values = <(IconData, String)>[
      (SellerIcons.orders, l10n.authValueOrders),
      (SellerIcons.inventory, l10n.authValueStock),
      (SellerIcons.bank, l10n.authValuePayments),
    ];
    return ColoredBox(
      color: c.primarySubtle,
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          padding: const EdgeInsets.all(SellerSpace.s48),
          child: ConstrainedBox(
            // Fill the panel's height; centre the content when it is short.
            constraints: BoxConstraints(minHeight: box.maxHeight - SellerSpace.s48 * 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SellerLogo(large: true),
                const SizedBox(height: SellerSpace.s32),
                const SellerFarmScene(),
                const SizedBox(height: SellerSpace.s32),
                Text(l10n.authHeadline, style: text.displaySmall),
                const SizedBox(height: SellerSpace.s24),
                for (final (icon, label) in values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: SellerSpace.s16),
                    child: Row(
                      children: [
                        SellerIconTile(icon: icon),
                        const SizedBox(width: SellerSpace.s16),
                        Expanded(child: Text(label, style: text.bodyLarge)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
