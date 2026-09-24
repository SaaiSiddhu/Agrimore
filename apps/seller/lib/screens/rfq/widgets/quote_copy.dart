import 'package:agrimore_core/agrimore_core.dart';
import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';
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

/// Status badge for a quote (board 20-02): text + icon + tone, never colour
/// alone. Accepted and Order placed are different states.
class QuoteStatusPill extends StatelessWidget {
  const QuoteStatusPill({super.key, required this.quote, required this.now});
  final RfqModel quote;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (String label, SellerTone tone, IconData icon) = switch (quoteBucketOf(quote, now)) {
      QuoteBucket.needsResponse => (l10n.quoteYourTurn, SellerTone.warning, SellerIcons.pending),
      QuoteBucket.negotiating => (l10n.quoteWaitingBuyer, SellerTone.info, SellerIcons.hourglass),
      QuoteBucket.accepted => quote.consumedByOrderId != null
          ? (l10n.quoteStatusOrdered, SellerTone.info, SellerIcons.packing)
          : (l10n.quoteStatusAccepted, SellerTone.success, SellerIcons.success),
      QuoteBucket.closed => quote.status == RfqStatus.rejected
          ? (l10n.quoteStatusDeclined, SellerTone.danger, SellerIcons.cancelled)
          : (l10n.quoteExpired, SellerTone.neutral, SellerIcons.timer),
    };
    return SellerStatusBadge(label: label, tone: tone, icon: icon);
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
    final c = context.colors;
    final expired = offer.isExpired(now);
    final left = daysLeft(at, now);
    final urgent = expired || left <= 1;
    final color = urgent ? c.warning : c.textSecondary;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(SellerIcons.timer, size: SellerIconSize.sm, color: color),
      const SizedBox(width: SellerSpace.s4),
      Flexible(
        child: Text(
          expired ? l10n.quoteExpired : l10n.quoteExpiresIn(left),
          style: context.text.bodyMedium!.copyWith(color: color),
        ),
      ),
    ]);
  }
}
