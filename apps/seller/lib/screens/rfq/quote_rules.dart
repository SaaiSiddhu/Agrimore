import 'package:agrimore_core/agrimore_core.dart';

/// Q-01 inbox tabs (ADR §10.4). Pure — unit-tested.
enum QuoteBucket { needsResponse, negotiating, accepted, closed }

/// Offer validity choices on the counter sheet. Server bounds: 1–30 days
/// (functions/src/customer/rfq.ts MAX_VALID_DAYS); default 7.
const List<int> kQuoteValidityDays = [3, 7, 15, 30];
const int kDefaultQuoteValidityDays = 7;

/// Decline reasons. Sent as the free-text `reason` (the server bounds it to
/// 500 characters); the key's label is what the buyer reads.
const List<String> kQuoteDeclineReasons = [
  'price_too_low',
  'out_of_stock',
  'quantity_unavailable',
  'cannot_deliver',
  'other',
];

/// Which tab a quote belongs in, from the seller's side.
QuoteBucket quoteBucketOf(RfqModel q, DateTime now) {
  switch (q.status) {
    case RfqStatus.accepted:
      return QuoteBucket.accepted;
    case RfqStatus.rejected:
      return QuoteBucket.closed;
    case RfqStatus.pending:
    case RfqStatus.negotiating:
      if (q.awaitingResponseFrom == RfqRole.seller) return QuoteBucket.needsResponse;
      // Waiting on the buyer, but the seller's own offer has lapsed: nothing
      // further can happen unless the buyer counters, so it is closed here.
      final offer = q.lastOffer;
      if (offer != null && offer.isExpired(now)) return QuoteBucket.closed;
      return QuoteBucket.negotiating;
  }
}

/// Counts per tab, in [QuoteBucket] order.
Map<QuoteBucket, int> quoteCounts(Iterable<RfqModel> quotes, DateTime now) {
  final counts = {for (final b in QuoteBucket.values) b: 0};
  for (final q in quotes) {
    counts[quoteBucketOf(q, now)] = counts[quoteBucketOf(q, now)]! + 1;
  }
  return counts;
}

/// Fraction the offered price sits above (+) or below (−) the listed B2B
/// price, or null when there is no listed price to compare with.
double? priceVsListed(double price, double? listed) {
  if (listed == null || listed <= 0) return null;
  return (price - listed) / listed;
}

/// Whole days (rounded up) until [expiresAt]; 0 once it has passed.
int daysLeft(DateTime expiresAt, DateTime now) {
  final ms = expiresAt.difference(now).inMilliseconds;
  if (ms <= 0) return 0;
  const dayMs = Duration.millisecondsPerDay;
  return (ms + dayMs - 1) ~/ dayMs;
}
