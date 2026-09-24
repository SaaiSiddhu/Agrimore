import 'package:agrimore_core/agrimore_core.dart';
import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import 'quote_copy.dart';

/// Quote card (board 20-01): product photo, product + status, buyer, the
/// offer on the table (qty × price, total) and the expiry.
class QuoteTile extends StatelessWidget {
  const QuoteTile({super.key, required this.quote, required this.now, required this.onTap});
  final RfqModel quote;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final text = context.text;
    final offer = quote.lastOffer;
    final open = quote.status != RfqStatus.accepted && quote.status != RfqStatus.rejected;
    return SellerCard(
      onTap: onTap,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SellerImage(url: quote.productImageUrl, size: SellerSize.thumbLg),
        const SizedBox(width: SellerSpace.s12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: SellerSpace.s8, runSpacing: SellerSpace.s4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(l10n.productOf(quote), style: text.titleSmall),
              QuoteStatusPill(quote: quote, now: now),
            ]),
            const SizedBox(height: SellerSpace.s2),
            Text(l10n.buyerOf(quote), style: text.bodyMedium),
            const SizedBox(height: SellerSpace.s8),
            if (offer == null)
              Text(l10n.quoteNoPriceYet, style: text.bodyMedium!.copyWith(color: c.textPrimary))
            else
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: Text(
                    l10n.quoteQtyAtPrice(SellerFormat.count(offer.quantity), SellerFormat.money(offer.price)),
                    style: text.bodyMedium!.copyWith(color: c.textPrimary).tabular,
                  ),
                ),
                Text(SellerFormat.money(offer.total), style: text.titleSmall!.tabular),
              ]),
            if (offer != null && open) ...[
              const SizedBox(height: SellerSpace.s4),
              QuoteExpiryText(offer: offer, now: now),
            ],
          ]),
        ),
        const SizedBox(width: SellerSpace.s4),
        Icon(SellerIcons.chevronRight, size: SellerIconSize.md, color: c.textTertiary),
      ]),
    );
  }
}
