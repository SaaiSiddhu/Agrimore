import 'package:agrimore_core/agrimore_core.dart';
import 'package:flutter/foundation.dart';

import '../orders/order_stage.dart';
import '../rfq/quote_rules.dart';

/// SELLER-HOME-1c: H-04 insights and H-05 account health — pure, unit-tested.

@immutable
class ProductSales {
  const ProductSales({required this.productId, required this.name, required this.units, required this.revenue});
  final String productId;
  final String name;
  final int units;
  final double revenue;
}

/// Orders placed in [from, to) that were not cancelled.
List<OrderModel> ordersIn(Iterable<OrderModel> orders, DateTime from, DateTime to) => [
      for (final o in orders)
        if (!o.createdAt.isBefore(from) && o.createdAt.isBefore(to) && orderStageOf(o.orderStatus) != OrderStage.cancelled) o,
    ];

/// Best sellers by revenue, then units.
List<ProductSales> topProducts(Iterable<OrderModel> orders, {int limit = 5}) {
  final byId = <String, ProductSales>{};
  for (final o in orders) {
    for (final i in o.items) {
      final prev = byId[i.productId];
      byId[i.productId] = ProductSales(
        productId: i.productId,
        name: i.productName,
        units: (prev?.units ?? 0) + i.quantity,
        revenue: (prev?.revenue ?? 0) + i.price * i.quantity,
      );
    }
  }
  final list = byId.values.toList()
    ..sort((a, b) => b.revenue != a.revenue ? b.revenue.compareTo(a.revenue) : b.units.compareTo(a.units));
  return list.take(limit).toList();
}

/// Orders per stage (all orders placed in the window, cancelled included).
Map<OrderStage, int> stageCounts(Iterable<OrderModel> orders, DateTime from, DateTime to) {
  final counts = <OrderStage, int>{};
  for (final o in orders) {
    if (o.createdAt.isBefore(from) || !o.createdAt.isBefore(to)) continue;
    final s = orderStageOf(o.orderStatus);
    counts[s] = (counts[s] ?? 0) + 1;
  }
  return counts;
}

// ---------------------------------------------------------------- health

enum HealthInput { fulfilment, cancellations, rating, listings, quotes }

@immutable
class HealthScore {
  const HealthScore({required this.input, required this.value, required this.target, required this.score});
  final HealthInput input;

  /// The measured value (a fraction, or a rating out of 5).
  final double value;
  final double target;

  /// 0–100 contribution.
  final double score;

  bool get meetsTarget => input == HealthInput.cancellations ? value <= target : value >= target;
}

/// Targets (ADR §10.2 H-05). Fractions, except rating (out of 5).
const double kFulfilmentTarget = 0.95;
const double kCancellationTarget = 0.05;
const double kRatingTarget = 4.0;
const double kListingTarget = 0.8;
const double kQuoteTarget = 0.9;
const int kMinOrdersForRates = 5;
const int kMinReviewsForRating = 3;
const Duration kQuoteResponseWindow = Duration(hours: 24);
const Duration kHealthWindow = Duration(days: 30);

double _higherIsBetter(double value, double target) => (value / target * 100).clamp(0, 100).toDouble();

/// 100 at or under target, 0 at four times the target.
double _lowerIsBetter(double value, double target) {
  if (value <= target) return 100;
  final worst = target * 4;
  return ((worst - value) / (worst - target) * 100).clamp(0, 100).toDouble();
}

/// A listing is complete with a photo, a description and HSN + GST rate.
bool listingComplete(ProductModel p) =>
    p.images.isNotEmpty && p.description.trim().isNotEmpty && (p.hsnCode ?? '').isNotEmpty && p.gstRate != null;

/// Only inputs with enough data are returned (and weighted equally).
List<HealthScore> healthInputs({
  required List<OrderModel> orders,
  required List<ProductModel> products,
  required List<RfqModel> quotes,
  required double? rating,
  required int reviewCount,
  required DateTime now,
}) {
  final from = now.subtract(kHealthWindow);
  final recent = orders.where((o) => !o.createdAt.isBefore(from)).toList();
  final out = <HealthScore>[];

  final delivered = recent.where((o) => orderStageOf(o.orderStatus) == OrderStage.delivered).length;
  final cancelled = recent.where((o) => orderStageOf(o.orderStatus) == OrderStage.cancelled).length;
  if (delivered + cancelled >= kMinOrdersForRates) {
    final f = delivered / (delivered + cancelled);
    out.add(HealthScore(input: HealthInput.fulfilment, value: f, target: kFulfilmentTarget, score: _higherIsBetter(f, kFulfilmentTarget)));
  }
  if (recent.length >= kMinOrdersForRates) {
    final c = cancelled / recent.length;
    out.add(HealthScore(input: HealthInput.cancellations, value: c, target: kCancellationTarget, score: _lowerIsBetter(c, kCancellationTarget)));
  }
  if (rating != null && reviewCount >= kMinReviewsForRating) {
    out.add(HealthScore(input: HealthInput.rating, value: rating, target: kRatingTarget, score: _higherIsBetter(rating, kRatingTarget)));
  }
  final live = products.where((p) => p.isActive && !p.isDraft).toList();
  if (live.isNotEmpty) {
    final q = live.where(listingComplete).length / live.length;
    out.add(HealthScore(input: HealthInput.listings, value: q, target: kListingTarget, score: _higherIsBetter(q, kListingTarget)));
  }
  final recentQuotes = quotes.where((r) => !r.createdAt.isBefore(from)).toList();
  if (recentQuotes.isNotEmpty) {
    // A quote counts as missed when it still waits on the seller past the window.
    final missed = recentQuotes
        .where((r) => quoteBucketOf(r, now) == QuoteBucket.needsResponse && now.difference(r.updatedAt) > kQuoteResponseWindow)
        .length;
    final answered = (recentQuotes.length - missed) / recentQuotes.length;
    out.add(HealthScore(input: HealthInput.quotes, value: answered, target: kQuoteTarget, score: _higherIsBetter(answered, kQuoteTarget)));
  }
  return out;
}

/// Overall 0–100, or null when there is nothing to score yet.
int? overallHealth(List<HealthScore> inputs) {
  if (inputs.isEmpty) return null;
  return (inputs.fold<double>(0, (s, i) => s + i.score) / inputs.length).round();
}

enum HealthBand { good, fair, poor }

HealthBand bandOf(int score) => score >= 80 ? HealthBand.good : (score >= 60 ? HealthBand.fair : HealthBand.poor);
