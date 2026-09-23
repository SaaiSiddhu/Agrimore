import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'quote_copy.dart';

/// One row of the Q-01 inbox (`WsQuoteItem`, ADR §7): product, buyer, the
/// offer on the table, status and expiry.
class QuoteTile extends StatelessWidget {
  const QuoteTile({super.key, required this.quote, required this.now, required this.onTap});
  final RfqModel quote;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final text = context.wsText;
    final offer = quote.lastOffer;
    final image = quote.productImageUrl;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(WsRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(WsSpace.s16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(WsRadius.small),
                child: SizedBox.square(
                  dimension: WsSize.thumbMd,
                  child: image == null
                      ? ColoredBox(
                          color: t.surfaceSunken,
                          child: Icon(AgIcons.product, color: t.textTertiary),
                        )
                      : Image.network(image, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => ColoredBox(color: t.surfaceSunken)),
                ),
              ),
              const SizedBox(width: WsSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(l10n.productOf(quote),
                            style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: WsSpace.s8),
                      QuoteStatusPill(quote: quote, now: now),
                    ]),
                    const SizedBox(height: WsSpace.s2),
                    Text(l10n.buyerOf(quote),
                        style: text.bodySmall!.copyWith(color: t.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: WsSpace.s8),
                    if (offer == null)
                      Text(l10n.quoteNoPriceYet, style: text.bodyMedium)
                    else
                      Text(
                        '${l10n.quoteQtyAtPrice(AgFormat.count(offer.quantity), AgFormat.rupees(offer.price))}'
                        '  ·  ${AgFormat.rupees(offer.total)}',
                        style: text.bodyMedium!.copyWith(fontFeatures: WsType.tabularFigures),
                      ),
                    if (offer != null && quote.status != RfqStatus.accepted && quote.status != RfqStatus.rejected) ...[
                      const SizedBox(height: WsSpace.s4),
                      QuoteExpiryText(offer: offer, now: now),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
