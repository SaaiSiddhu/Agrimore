import 'package:flutter/foundation.dart';

/// SELLER-HOME-1a: KPI maths over `seller_stats_daily` (written server-side
/// by functions/src/seller/sellerStats.ts). Pure — unit-tested. Days are
/// Indian calendar days, matching the server's istDay().

const Duration kIstOffset = Duration(hours: 5, minutes: 30);

/// yyyyMMdd of the Indian calendar day containing [instant].
String istDayKey(DateTime instant) {
  final d = instant.toUtc().add(kIstOffset);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}${two(d.month)}${two(d.day)}';
}

/// Keys for the [count] Indian days ending with the one containing [now],
/// oldest first.
List<String> istDayKeys(DateTime now, int count, {int endOffsetDays = 0}) {
  final end = now.toUtc().subtract(Duration(days: endOffsetDays));
  return [for (var i = count - 1; i >= 0; i--) istDayKey(end.subtract(Duration(days: i)))];
}

/// One `seller_stats_daily` document.
@immutable
class DayStat {
  const DayStat({
    required this.day,
    this.orders = 0,
    this.cancelled = 0,
    this.delivered = 0,
    this.gross = 0,
    this.units = 0,
    this.b2bGross = 0,
  });

  factory DayStat.fromMap(Map<String, dynamic> d) {
    num n(Object? v) => v is num ? v : 0;
    return DayStat(
      day: (d['day'] ?? '').toString(),
      orders: n(d['orders']).toInt(),
      cancelled: n(d['cancelled']).toInt(),
      delivered: n(d['delivered']).toInt(),
      gross: n(d['gross']).toDouble(),
      units: n(d['units']).toInt(),
      b2bGross: n(d['b2bGross']).toDouble(),
    );
  }

  final String day;
  final int orders;
  final int cancelled;
  final int delivered;
  final double gross;
  final int units;
  final double b2bGross;

  /// Orders that were not cancelled.
  int get placed => orders - cancelled;
}

enum KpiPeriod { today, days7, days30 }

extension KpiPeriodDays on KpiPeriod {
  int get days => switch (this) {
        KpiPeriod.today => 1,
        KpiPeriod.days7 => 7,
        KpiPeriod.days30 => 30,
      };
}

@immutable
class KpiTotals {
  const KpiTotals({required this.gross, required this.orders});
  final double gross;

  /// Orders that were not cancelled.
  final int orders;

  /// Average order value, or null with no orders.
  double? get aov => orders == 0 ? null : gross / orders;
}

@immutable
class KpiSummary {
  const KpiSummary({required this.current, required this.previous, required this.series});
  final KpiTotals current;
  final KpiTotals previous;

  /// Daily gross over the current period (at least 7 days), oldest first.
  final List<double> series;

  /// Relative change, or null when the previous period had nothing.
  static double? delta(num current, num previous) => previous == 0 ? null : (current - previous) / previous;

  double? get grossDelta => delta(current.gross, previous.gross);
  int get ordersDelta => current.orders - previous.orders;
  double? get aovDelta {
    final c = current.aov, p = previous.aov;
    return c == null || p == null ? null : delta(c, p);
  }

  /// The period ending today vs the same-length period right before it.
  static KpiSummary of(Map<String, DayStat> byDay, KpiPeriod period, DateTime now) {
    final days = period.days;
    final cur = istDayKeys(now, days);
    final prev = istDayKeys(now, days, endOffsetDays: days);
    KpiTotals sum(List<String> keys) {
      var gross = 0.0;
      var orders = 0;
      for (final k in keys) {
        final s = byDay[k];
        if (s == null) continue;
        gross += s.gross;
        orders += s.placed;
      }
      return KpiTotals(gross: gross, orders: orders);
    }

    return KpiSummary(
      current: sum(cur),
      previous: sum(prev),
      // At least a week, so "Today" still shows a trend.
      series: [for (final k in istDayKeys(now, days < 7 ? 7 : days)) byDay[k]?.gross ?? 0],
    );
  }
}
