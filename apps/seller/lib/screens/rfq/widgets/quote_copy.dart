import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/rfq_provider.dart';
import '../quote_rules.dart';

/// Shared copy for the quote screens — one place per label.
extension QuoteCopy on AppLocalizations {
  String bucketLabel(QuoteBucket b) => switch (b) {
        QuoteBucket.needsResponse => quotesTabNeedsResponse,
        QuoteBucket.negotiating => quotesTabNegotiating,
        QuoteBucket.accepted => quotesTabAccepted,
        QuoteBucket.closed => quotesTabClosed,
      };

  String declineReasonLabel(String key) => switch (key) {
        'price_too_low' => declineReasonPriceTooLow,
        'out_of_stock' => declineReasonOutOfStock,
        'quantity_unavailable' => declineReasonQuantity,
        'cannot_deliver' => declineReasonCannotDeliver,
        _ => declineReasonOther,
      };

  String quoteError(QuoteActionError? e) => switch (e) {
        QuoteActionError.expired => quoteErrorExpired,
        QuoteActionError.notYourTurn => quoteErrorNotYourTurn,
        QuoteActionError.closed => quoteErrorClosed,
        _ => quoteErrorGeneric,
      };

  String productOf(RfqModel q) => q.productName ?? quoteUnknownProduct;

  String buyerOf(RfqModel q) => q.buyerBusinessName ?? q.buyerName ?? quoteUnknownBuyer;

  /// "8% below your B2B price" etc., or null without a listed price.
  String? vsListed(double price, double? listed) {
    final d = priceVsListed(price, listed);
    if (d == null) return null;
    final pct = '${(d.abs() * 100).round()}%';
    if (d.abs() < 0.005) return quoteVsListedSame;
    return d < 0 ? quoteVsListedBelow(pct) : quoteVsListedAbove(pct);
  }
}

/// Status pill for a quote: tone + label, never colour alone.
class QuoteStatusPill extends StatelessWidget {
  const QuoteStatusPill({super.key, required this.quote, required this.now});
  final RfqModel quote;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final (String label, Color fg, Color bg) = switch (quoteBucketOf(quote, now)) {
      QuoteBucket.needsResponse => (l10n.quoteYourTurn, t.warningFg, t.warningBg),
      QuoteBucket.negotiating => (l10n.quoteWaitingBuyer, t.infoFg, t.infoBg),
      QuoteBucket.accepted => quote.consumedByOrderId != null
          ? (l10n.quoteStatusOrdered, t.successFg, t.successBg)
          : (l10n.quoteStatusAccepted, t.successFg, t.successBg),
      QuoteBucket.closed => quote.status == RfqStatus.rejected
          ? (l10n.quoteStatusDeclined, t.textSecondary, t.surfaceSunken)
          : (l10n.quoteExpired, t.textSecondary, t.surfaceSunken),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: WsSpace.s8, vertical: WsSpace.s2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(WsRadius.pill)),
      child: Text(label, style: context.wsText.labelMedium!.copyWith(color: fg)),
    );
  }
}

/// "Expires in 3 days" / "Offer expired" for an open offer, else nothing.
class QuoteExpiryText extends StatelessWidget {
  const QuoteExpiryText({super.key, required this.offer, required this.now});
  final RfqOffer offer;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final at = offer.expiresAt;
    if (at == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final expired = offer.isExpired(now);
    final left = daysLeft(at, now);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(AgIcons.timer, size: WsIconSize.supporting, color: expired || left <= 1 ? t.warningFg : t.textTertiary),
      const SizedBox(width: WsSpace.s4),
      Text(
        expired ? l10n.quoteExpired : l10n.quoteExpiresIn(left),
        style: context.wsText.bodySmall!.copyWith(color: expired || left <= 1 ? t.warningFg : t.textSecondary),
      ),
    ]);
  }
}
