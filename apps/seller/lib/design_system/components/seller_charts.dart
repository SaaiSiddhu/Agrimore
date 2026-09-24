import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../icons/seller_icons.dart';
import '../theme/seller_focus.dart';
import '../tokens/seller_colors.dart';
import '../tokens/seller_tokens.dart';
import '../tokens/seller_typography.dart';
import 'seller_button.dart';
import 'seller_card.dart';

// Accessible charts (boards 21-01…21-08, 24-07). Every chart:
// - has a visible title and a one-line text summary;
// - uses a non-colour cue for comparison (dashed line, hollow dots, hatching);
// - is announced by its summary, with the values available as a data table;
// - is drawn statically (no entry animation), so reduced motion needs nothing.
// Charts only draw numbers the caller read from the server; a chart with no
// data shows [SellerChartUnavailable], never a placeholder line.

/// One x-axis value.
@immutable
class SellerChartPoint {
  const SellerChartPoint(this.label, this.value, this.valueLabel);

  /// Axis label, e.g. "18 Sep".
  final String label;
  final double value;

  /// Formatted value used in labels, touch read-outs and tables, e.g. "₹2,000".
  final String valueLabel;
}

/// A line of points. The comparison series ([previous]) is dashed, muted and
/// has hollow dots.
@immutable
class SellerChartSeries {
  const SellerChartSeries({required this.name, required this.points, this.previous = false});
  final String name;
  final List<SellerChartPoint> points;
  final bool previous;
}

double _niceMax(double v) {
  if (v <= 0) return 1;
  final exp = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
  for (final m in const [1.0, 2.0, 2.5, 5.0, 10.0]) {
    if (v <= m * exp) return m * exp;
  }
  return 10 * exp;
}

Path _dashed(Path source, {double dash = 6, double gap = 4}) {
  final out = Path();
  for (final metric in source.computeMetrics()) {
    var d = 0.0;
    while (d < metric.length) {
      final end = math.min(d + dash, metric.length);
      out.addPath(metric.extractPath(d, end), Offset.zero);
      d = end + gap;
    }
  }
  return out;
}

void _paintHatched(Canvas canvas, RRect rrect, {required Color fill, required Color stroke}) {
  canvas.save();
  canvas.clipRRect(rrect);
  canvas.drawRRect(rrect, Paint()..color = fill);
  final line = Paint()
    ..color = stroke
    ..strokeWidth = SellerSize.outline;
  final r = rrect.outerRect;
  for (var x = r.left - r.height; x < r.right; x += SellerSpace.s6) {
    canvas.drawLine(Offset(x, r.bottom), Offset(x + r.height, r.top), line);
  }
  canvas.restore();
  canvas.drawRRect(
    rrect.deflate(SellerSize.hairline / 2),
    Paint()
      ..style = PaintingStyle.stroke
      ..color = stroke
      ..strokeWidth = SellerSize.hairline,
  );
}

TextPainter _label(String text, TextStyle style, TextScaler scaler) =>
    TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr, textScaler: scaler, maxLines: 1)
      ..layout();

// ───────────────────────────── Line chart ─────────────────────────────

/// This period (solid teal line, filled dots) against the previous period
/// (dashed grey line, hollow dots), with ₹ ticks, day labels, an end-point
/// label and a touch read-out of both values (board 21-04).
class SellerLineChart extends StatefulWidget {
  const SellerLineChart({
    super.key,
    required this.series,
    required this.axisLabel,
    required this.semanticSummary,
    this.height = SellerSize.chartHeight,
    this.showEndLabel = true,
  });

  /// The first series is the current period; an optional second is the comparison.
  final List<SellerChartSeries> series;

  /// Formats a y-axis tick, e.g. compact money.
  final String Function(double value) axisLabel;
  final String semanticSummary;
  final double height;
  final bool showEndLabel;

  @override
  State<SellerLineChart> createState() => _SellerLineChartState();
}

class _SellerLineChartState extends State<SellerLineChart> {
  int? _selected;

  int get _count => widget.series.fold<int>(0, (m, s) => math.max(m, s.points.length));

  void _select(Offset local, double width, double left, double right) {
    final n = _count;
    if (n == 0) return;
    final plot = width - left - right;
    final t = n == 1 ? 0.0 : ((local.dx - left) / plot).clamp(0.0, 1.0);
    setState(() => _selected = (t * (n - 1)).round());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final scaler = MediaQuery.textScalerOf(context);
    final height = scaler.scale(widget.height).clamp(widget.height, widget.height * 1.6);
    return Semantics(
      container: true,
      label: widget.semanticSummary,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, box) {
            final painter = _LineChartPainter(
              series: widget.series,
              axisLabel: widget.axisLabel,
              colors: c,
              axisStyle: text.labelSmall!.copyWith(color: c.textSecondary).tabular,
              valueStyle: text.labelMedium!.copyWith(color: c.textPrimary).tabular,
              tipStyle: text.labelMedium!.copyWith(color: c.onToast).tabular,
              scaler: scaler,
              selected: _selected,
              showEndLabel: widget.showEndLabel,
            );
            final left = painter.leftInset();
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _select(d.localPosition, box.maxWidth, left, SellerSpace.s8),
              onHorizontalDragUpdate: (d) => _select(d.localPosition, box.maxWidth, left, SellerSpace.s8),
              child: CustomPaint(size: Size(box.maxWidth, height), painter: painter),
            );
          },
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.series,
    required this.axisLabel,
    required this.colors,
    required this.axisStyle,
    required this.valueStyle,
    required this.tipStyle,
    required this.scaler,
    required this.selected,
    required this.showEndLabel,
  });

  final List<SellerChartSeries> series;
  final String Function(double) axisLabel;
  final SellerColors colors;
  final TextStyle axisStyle;
  final TextStyle valueStyle;
  final TextStyle tipStyle;
  final TextScaler scaler;
  final int? selected;
  final bool showEndLabel;

  double get _max => series.expand((s) => s.points).fold<double>(0, (m, p) => math.max(m, p.value));

  List<double> get _ticks {
    final max = _max;
    if (max <= 0) return const [0];
    final top = _niceMax(max);
    return [0, top / 2, top];
  }

  double leftInset() {
    var w = 0.0;
    for (final t in _ticks) {
      final tp = _label(axisLabel(t), axisStyle, scaler);
      w = math.max(w, tp.width);
      tp.dispose();
    }
    return w + SellerSpace.s8;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final ticks = _ticks;
    final top = ticks.last <= 0 ? 1.0 : ticks.last;
    final left = leftInset();
    const right = SellerSpace.s8;
    final xProbe = _label('0', axisStyle, scaler);
    final bottom = xProbe.height + SellerSpace.s8;
    final topPad = showEndLabel ? xProbe.height + SellerSpace.s8 : SellerSpace.s8;
    xProbe.dispose();
    final plot = Rect.fromLTRB(left, topPad, size.width - right, size.height - bottom);
    if (plot.width <= 0 || plot.height <= 0) return;

    // Grid + y ticks.
    final grid = Paint()
      ..color = colors.border
      ..strokeWidth = SellerSize.hairline;
    for (final t in ticks) {
      final y = plot.bottom - (t / top) * plot.height;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      final tp = _label(axisLabel(t), axisStyle, scaler);
      tp.paint(canvas, Offset(left - SellerSpace.s8 - tp.width, y - tp.height / 2));
      tp.dispose();
    }

    final n = series.fold<int>(0, (m, s) => math.max(m, s.points.length));
    if (n == 0) return;
    double xAt(int i) => n == 1 ? plot.center.dx : plot.left + plot.width * i / (n - 1);
    double yAt(double v) => plot.bottom - (v / top) * plot.height;

    // X labels, thinned so they never overlap.
    final base = series.firstWhere((s) => s.points.length == n).points;
    var widest = 0.0;
    for (final p in base) {
      final tp = _label(p.label, axisStyle, scaler);
      widest = math.max(widest, tp.width);
      tp.dispose();
    }
    final per = n == 1 ? plot.width : plot.width / (n - 1);
    final stride = math.max(1, ((widest + SellerSpace.s8) / per).ceil());
    final shown = <int>[for (var i = 0; i < n; i += stride) i];
    if (shown.last != n - 1 && (n - 1 - shown.last) * per >= widest + SellerSpace.s8) shown.add(n - 1);
    for (final i in shown) {
      final tp = _label(base[i].label, axisStyle, scaler);
      final x = (xAt(i) - tp.width / 2).clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(x, plot.bottom + SellerSpace.s6));
      tp.dispose();
    }

    // Series: previous first so the current line sits on top.
    final ordered = [...series.where((s) => s.previous), ...series.where((s) => !s.previous)];
    for (final s in ordered) {
      if (s.points.isEmpty) continue;
      final color = s.previous ? colors.textSecondary : colors.primary;
      final path = Path();
      for (var i = 0; i < s.points.length; i++) {
        final o = Offset(xAt(i), yAt(s.points[i].value));
        i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      final stroke = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.previous ? SellerSize.outline : SellerSize.focus
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(s.previous ? _dashed(path) : path, stroke);
      final showDots = n <= 31;
      for (var i = 0; i < s.points.length; i++) {
        if (!showDots && i != s.points.length - 1) continue;
        final o = Offset(xAt(i), yAt(s.points[i].value));
        if (s.previous) {
          canvas.drawCircle(o, SellerSpace.s4, Paint()..color = colors.surface);
          canvas.drawCircle(
            o,
            SellerSpace.s4,
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = SellerSize.outline,
          );
        } else {
          canvas.drawCircle(o, SellerSpace.s4, Paint()..color = color);
        }
      }
      if (showEndLabel && !s.previous) {
        final last = s.points.last;
        final tp = _label(last.valueLabel, valueStyle, scaler);
        final o = Offset(xAt(s.points.length - 1), yAt(last.value));
        final x = (o.dx - tp.width).clamp(0.0, size.width - tp.width);
        final y = math.max(0.0, o.dy - tp.height - SellerSpace.s6);
        tp.paint(canvas, Offset(x, y));
        tp.dispose();
      }
    }

    // Touch read-out: guide line + tip with the date and every series' value.
    final sel = selected;
    if (sel != null && sel < n) {
      final x = xAt(sel);
      canvas.drawLine(
        Offset(x, plot.top),
        Offset(x, plot.bottom),
        Paint()
          ..color = colors.textSecondary
          ..strokeWidth = SellerSize.hairline,
      );
      final lines = <String>[
        base[sel].label,
        for (final s in series)
          if (sel < s.points.length) '${s.name}  ${s.points[sel].valueLabel}',
      ];
      final painters = [for (final l in lines) _label(l, tipStyle, scaler)];
      final w = painters.fold<double>(0, (m, p) => math.max(m, p.width)) + SellerSpace.s16;
      final h = painters.fold<double>(0, (m, p) => m + p.height) + SellerSpace.s12;
      final tipLeft = (x + SellerSpace.s8 + w > size.width) ? x - SellerSpace.s8 - w : x + SellerSpace.s8;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(tipLeft.clamp(0.0, math.max(0.0, size.width - w)), plot.top, w, h),
        const Radius.circular(SellerRadius.control),
      );
      canvas.drawRRect(rect, Paint()..color = colors.toast);
      var y = rect.top + SellerSpace.s6;
      for (final p in painters) {
        p.paint(canvas, Offset(rect.left + SellerSpace.s8, y));
        y += p.height;
        p.dispose();
      }
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter old) =>
      old.series != series || old.selected != selected || old.colors != colors || old.scaler != scaler || old.showEndLabel != showEndLabel;
}

// ───────────────────────────── Sparkline ─────────────────────────────

/// Decorative trend inside a metric card (boards 11, 21-01): an area line or
/// mini bars. The card's text carries the numbers, so this is hidden from
/// screen readers.
class SellerSparkline extends StatelessWidget {
  const SellerSparkline({super.key, required this.values, this.bars = false, this.height = SellerSize.sparklineHeight});

  final List<double> values;
  final bool bars;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _SparkPainter(values, bars, context.colors)),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values, this.bars, this.colors);
  final List<double> values;
  final bool bars;
  final SellerColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final max = values.fold<double>(0, math.max);
    final top = max <= 0 ? 1.0 : max;
    final inset = SellerSize.focus;
    final h = size.height - inset * 2;
    if (bars) {
      final slot = size.width / values.length;
      final w = math.max(SellerSpace.s2, slot * 0.6);
      for (var i = 0; i < values.length; i++) {
        final bh = math.max(SellerSize.focus, h * values[i] / top);
        final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(slot * i + (slot - w) / 2, size.height - inset - bh, w, bh),
          const Radius.circular(SellerRadius.xs / 2),
        );
        canvas.drawRRect(r, Paint()..color = colors.primary);
      }
      return;
    }
    final n = values.length;
    Offset at(int i) => Offset(n == 1 ? size.width / 2 : size.width * i / (n - 1), inset + h - h * values[i] / top);
    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < n; i++) {
      line.lineTo(at(i).dx, at(i).dy);
    }
    final area = Path.from(line)
      ..lineTo(at(n - 1).dx, size.height)
      ..lineTo(at(0).dx, size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = colors.primary.withValues(alpha: SellerOpacity.pressed));
    canvas.drawPath(
      line,
      Paint()
        ..color = colors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = SellerSize.focus
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.values != values || old.bars != bars || old.colors != colors;
}

// ───────────────────────────── Bar chart ─────────────────────────────

/// Vertical bars with the value written on each bar and the day under it
/// (board 24-07). When bars are too narrow for their labels the labels are
/// left out and the data table carries the values.
class SellerBarChart extends StatelessWidget {
  const SellerBarChart({super.key, required this.points, required this.semanticSummary, this.height = SellerSize.chartHeight});

  final List<SellerChartPoint> points;
  final String semanticSummary;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final scaler = MediaQuery.textScalerOf(context);
    return Semantics(
      container: true,
      label: semanticSummary,
      child: ExcludeSemantics(
        child: SizedBox(
          height: scaler.scale(height).clamp(height, height * 1.6),
          width: double.infinity,
          child: CustomPaint(
            painter: _BarPainter(
              points,
              c,
              text.labelMedium!.copyWith(color: c.textPrimary).tabular,
              text.labelSmall!.copyWith(color: c.textSecondary),
              scaler,
            ),
          ),
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.points, this.colors, this.valueStyle, this.axisStyle, this.scaler);
  final List<SellerChartPoint> points;
  final SellerColors colors;
  final TextStyle valueStyle;
  final TextStyle axisStyle;
  final TextScaler scaler;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final probe = _label('0', axisStyle, scaler);
    final bottom = probe.height + SellerSpace.s8;
    final topPad = probe.height + SellerSpace.s8;
    probe.dispose();
    final plot = Rect.fromLTRB(0, topPad, size.width, size.height - bottom);
    final max = points.fold<double>(0, (m, p) => math.max(m, p.value));
    final top = max <= 0 ? 1.0 : max;
    final slot = plot.width / points.length;
    final w = math.min(SellerSpace.s48, slot * 0.6);
    canvas.drawLine(
      Offset(plot.left, plot.bottom),
      Offset(plot.right, plot.bottom),
      Paint()
        ..color = colors.border
        ..strokeWidth = SellerSize.hairline,
    );
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final cx = slot * i + slot / 2;
      final bh = p.value <= 0 ? 0.0 : math.max(SellerSize.focus, plot.height * p.value / top);
      final rect = Rect.fromLTWH(cx - w / 2, plot.bottom - bh, w, bh);
      if (bh > 0) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(rect, topLeft: const Radius.circular(SellerRadius.xs), topRight: const Radius.circular(SellerRadius.xs)),
          Paint()..color = colors.primary,
        );
      }
      final v = _label(p.valueLabel, valueStyle, scaler);
      if (v.width <= slot - SellerSpace.s4) v.paint(canvas, Offset(cx - v.width / 2, rect.top - v.height - SellerSpace.s4));
      v.dispose();
      final a = _label(p.label, axisStyle, scaler);
      if (a.width <= slot - SellerSpace.s4) a.paint(canvas, Offset(cx - a.width / 2, plot.bottom + SellerSpace.s6));
      a.dispose();
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) => old.points != points || old.colors != colors || old.scaler != scaler;
}

// ───────────────────────────── Horizontal bars ─────────────────────────────

/// Pattern of a horizontal bar.
enum SellerBarStyle { solid, hatched }

/// One horizontal bar row: label (+ caption) and value on one line, the bar
/// under it — the stacked layout survives 200 % text (boards 21-02, 21-05, 21-07).
@immutable
class SellerBarItem {
  const SellerBarItem({
    required this.label,
    required this.value,
    required this.valueLabel,
    this.caption,
    this.icon,
    this.tone = SellerTone.brand,
    this.style = SellerBarStyle.solid,
  });

  final String label;
  final double value;
  final String valueLabel;
  final String? caption;
  final IconData? icon;
  final SellerTone tone;
  final SellerBarStyle style;
}

class SellerBarList extends StatelessWidget {
  const SellerBarList({super.key, required this.items, this.max});

  final List<SellerBarItem> items;

  /// Full-length value; defaults to the largest item.
  final double? max;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final l10n = AppLocalizations.of(context);
    final top = max ?? items.fold<double>(0, (m, i) => math.max(m, i.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in items)
          Semantics(
            container: true,
            label: l10n.dsCellLabel(item.caption == null ? item.label : '${item.label}, ${item.caption}', item.valueLabel),
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: SellerSpace.s8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.icon != null) ...[
                        Icon(item.icon, size: SellerIconSize.md, color: c.tone(item.tone).foreground),
                        const SizedBox(width: SellerSpace.s8),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.label, style: text.labelLarge),
                            if (item.caption != null) Text(item.caption!, style: text.bodySmall),
                          ],
                        ),
                      ),
                      const SizedBox(width: SellerSpace.s12),
                      Text(item.valueLabel, style: text.labelLarge!.tabular),
                    ],
                  ),
                  const SizedBox(height: SellerSpace.s6),
                  SizedBox(
                    height: SellerSize.progressTrack + SellerSpace.s4,
                    child: CustomPaint(
                      painter: _HBarPainter(
                        fraction: top <= 0 ? 0 : (item.value / top).clamp(0.0, 1.0),
                        color: item.style == SellerBarStyle.hatched ? c.textSecondary : c.tone(item.tone).foreground,
                        track: c.sunken,
                        hatched: item.style == SellerBarStyle.hatched,
                        surface: c.surface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _HBarPainter extends CustomPainter {
  _HBarPainter({required this.fraction, required this.color, required this.track, required this.hatched, required this.surface});
  final double fraction;
  final Color color;
  final Color track;
  final bool hatched;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = Radius.circular(SellerRadius.xs);
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, radius), Paint()..color = track);
    if (fraction <= 0) return;
    final bar = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, math.max(size.height, size.width * fraction), size.height), radius);
    if (hatched) {
      _paintHatched(canvas, bar, fill: surface, stroke: color);
    } else {
      canvas.drawRRect(bar, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_HBarPainter old) =>
      old.fraction != fraction || old.color != color || old.track != track || old.hatched != hatched || old.surface != surface;
}

/// "Current (18 – 24 Sep) ₹14,000" solid against "Previous (11 – 17 Sep)
/// ₹11,200" hatched (boards 21-02, 21-03).
class SellerComparisonBars extends StatelessWidget {
  const SellerComparisonBars({
    super.key,
    required this.currentLabel,
    required this.current,
    required this.currentValueLabel,
    required this.previousLabel,
    required this.previous,
    required this.previousValueLabel,
  });

  final String currentLabel;
  final double current;
  final String currentValueLabel;
  final String previousLabel;
  final double previous;
  final String previousValueLabel;

  @override
  Widget build(BuildContext context) {
    return SellerBarList(items: [
      SellerBarItem(label: currentLabel, value: current, valueLabel: currentValueLabel),
      SellerBarItem(label: previousLabel, value: previous, valueLabel: previousValueLabel, style: SellerBarStyle.hatched, tone: SellerTone.neutral),
    ]);
  }
}

/// Proportion meter: "Listing snapshot 75% complete", onboarding progress
/// (boards 16-05, 21-08). The label is spoken; the bar is decoration.
class SellerMeter extends StatelessWidget {
  const SellerMeter({super.key, required this.value, this.tone = SellerTone.brand, this.semanticLabel, this.height = SellerSize.progressTrack});

  /// 0…1.
  final double value;
  final SellerTone tone;
  final String? semanticLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bar = SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _HBarPainter(fraction: value.clamp(0.0, 1.0), color: c.tone(tone).foreground, track: c.sunken, hatched: false, surface: c.surface),
      ),
    );
    return semanticLabel == null ? ExcludeSemantics(child: bar) : Semantics(label: semanticLabel, excludeSemantics: true, child: bar);
  }
}

// ───────────────────────────── Rings ─────────────────────────────

class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction, required this.color, required this.track, required this.stroke});
  final double? fraction;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final base = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);
    final f = fraction;
    if (f == null || f <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * f.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction || old.color != color || old.track != track || old.stroke != stroke;
}

/// Share donut: "40%" inside, "₹5,600 of ₹14,000" beside it (boards 21-01, 21-04).
class SellerDonut extends StatelessWidget {
  const SellerDonut({super.key, required this.fraction, required this.centerLabel, this.size = SellerSize.avatarXl, this.semanticLabel});

  /// 0…1, or null when there is nothing to divide.
  final double? fraction;
  final String centerLabel;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = MediaQuery.textScalerOf(context).scale(size).clamp(size, size * 1.6);
    final ring = SizedBox.square(
      dimension: s,
      child: CustomPaint(
        painter: _RingPainter(fraction: fraction, color: c.primary, track: c.border, stroke: SellerSpace.s8),
        child: Center(child: Text(centerLabel, style: context.text.labelLarge!.tabular)),
      ),
    );
    return semanticLabel == null ? ExcludeSemantics(child: ring) : Semantics(label: semanticLabel, excludeSemantics: true, child: ring);
  }
}

/// Account-health ring: "91 / out of 100" coloured by band, or "—" with
/// "Not enough activity yet" (board 21-08). The band word is shown next to
/// the ring by the caller — colour never carries the band alone.
class SellerScoreRing extends StatelessWidget {
  const SellerScoreRing({super.key, required this.score, this.max = 100, this.tone = SellerTone.brand, this.size = SellerSize.scoreRing, this.semanticLabel});

  final int? score;
  final int max;
  final SellerTone tone;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final l10n = AppLocalizations.of(context);
    final s = MediaQuery.textScalerOf(context).scale(size).clamp(size, size * 2);
    final color = tone == SellerTone.brand ? c.primary : c.tone(tone).foreground;
    final ring = SizedBox.square(
      dimension: s,
      child: CustomPaint(
        painter: _RingPainter(fraction: score == null ? null : score! / max, color: color, track: c.border, stroke: SellerSize.ringStroke),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(score?.toString() ?? '—', style: text.displayMedium!.tabular),
              Text(l10n.dsOutOf(max), style: text.bodySmall),
            ],
          ),
        ),
      ),
    );
    return Semantics(
      label: semanticLabel ?? (score == null ? l10n.dsScoreUnavailable : '$score ${l10n.dsOutOf(max)}'),
      excludeSemantics: true,
      child: ring,
    );
  }
}

// ───────────────────────────── Legend, table, card ─────────────────────────────

enum SellerLegendKind { line, dashedLine, bar, hatchedBar }

@immutable
class SellerLegendItem {
  const SellerLegendItem(this.label, this.kind);
  final String label;
  final SellerLegendKind kind;
}

/// "● This period  ‑●‑ Previous period" (board 21-04).
class SellerChartLegend extends StatelessWidget {
  const SellerChartLegend({super.key, required this.items});
  final List<SellerLegendItem> items;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Wrap(
      spacing: SellerSpace.s16,
      runSpacing: SellerSpace.s4,
      children: [
        for (final item in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: SizedBox(
                  width: SellerSpace.s24,
                  height: SellerSpace.s12,
                  child: CustomPaint(painter: _LegendPainter(item.kind, c)),
                ),
              ),
              const SizedBox(width: SellerSpace.s6),
              Text(item.label, style: context.text.bodySmall),
            ],
          ),
      ],
    );
  }
}

class _LegendPainter extends CustomPainter {
  _LegendPainter(this.kind, this.colors);
  final SellerLegendKind kind;
  final SellerColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    switch (kind) {
      case SellerLegendKind.line || SellerLegendKind.dashedLine:
        final previous = kind == SellerLegendKind.dashedLine;
        final color = previous ? colors.textSecondary : colors.primary;
        final path = Path()
          ..moveTo(0, mid)
          ..lineTo(size.width, mid);
        final p = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = previous ? SellerSize.outline : SellerSize.focus;
        canvas.drawPath(previous ? _dashed(path, dash: 4, gap: 3) : path, p);
        final o = Offset(size.width / 2, mid);
        if (previous) {
          canvas.drawCircle(o, SellerSpace.s4, Paint()..color = colors.surface);
          canvas.drawCircle(o, SellerSpace.s4, p..strokeWidth = SellerSize.outline);
        } else {
          canvas.drawCircle(o, SellerSpace.s4, Paint()..color = color);
        }
      case SellerLegendKind.bar:
        canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(SellerRadius.xs)), Paint()..color = colors.primary);
      case SellerLegendKind.hatchedBar:
        _paintHatched(canvas, RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(SellerRadius.xs)),
            fill: colors.surface, stroke: colors.textSecondary);
    }
  }

  @override
  bool shouldRepaint(_LegendPainter old) => old.kind != kind || old.colors != colors;
}

@immutable
class SellerTableColumn {
  const SellerTableColumn(this.label, {this.numeric = false, this.flex = 1});
  final String label;
  final bool numeric;
  final int flex;
}

/// A small data table under a chart, or a statement table on wide screens
/// (boards 17-02, 19-02, 24-07). Each row is read as one sentence
/// ("Day: 18 Sep, Orders: 4"); tappable rows show the single-border focus.
class SellerDataTable extends StatelessWidget {
  const SellerDataTable({super.key, required this.columns, required this.rows, this.onRowTap});

  final List<SellerTableColumn> columns;
  final List<List<String>> rows;
  final ValueChanged<int>? onRowTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final l10n = AppLocalizations.of(context);

    Widget cells(List<String> values, {required bool header}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: SellerSpace.s12, vertical: SellerSpace.s12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < columns.length; i++) ...[
                if (i > 0) const SizedBox(width: SellerSpace.s12),
                Expanded(
                  flex: columns[i].flex,
                  child: Text(
                    i < values.length ? values[i] : '',
                    textAlign: columns[i].numeric ? TextAlign.end : TextAlign.start,
                    style: header
                        ? text.labelMedium
                        : (columns[i].numeric ? text.bodyMedium!.copyWith(color: c.textPrimary).tabular : text.bodyMedium!.copyWith(color: c.textPrimary)),
                  ),
                ),
              ],
            ],
          ),
        );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(SellerRadius.control),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(SellerRadius.control),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExcludeSemantics(
              child: ColoredBox(color: c.sunken, child: cells([for (final col in columns) col.label], header: true)),
            ),
            for (var r = 0; r < rows.length; r++) ...[
              Divider(height: SellerSize.hairline, color: c.border),
              _TableRow(
                label: [
                  for (var i = 0; i < columns.length && i < rows[r].length; i++) l10n.dsCellLabel(columns[i].label, rows[r][i]),
                ].join(', '),
                onTap: onRowTap == null ? null : () => onRowTap!(r),
                child: cells(rows[r], header: false),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({required this.label, required this.child, this.onTap});
  final String label;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return Semantics(label: label, excludeSemantics: true, child: child);
    final c = context.colors;
    return SellerFocusTracker(
      builder: (context, focused, node) => Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        onTap: onTap,
        child: Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(side: sellerOutline(c, focused: focused, rest: Colors.transparent)),
          child: InkWell(focusNode: node, onTap: onTap, child: child),
        ),
      ),
    );
  }
}

/// Dashed box with a chart icon: "Sales data unavailable" (board 21-04).
class SellerChartUnavailable extends StatelessWidget {
  const SellerChartUnavailable({super.key, this.message, this.height = SellerSize.chartHeight});
  final String? message;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    return CustomPaint(
      painter: _DashedBorderPainter(c.controlBorder),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: height / 2, minWidth: double.infinity),
        child: Padding(
          padding: const EdgeInsets.all(SellerSpace.s16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ExcludeSemantics(child: Icon(SellerIcons.chartBar, color: c.textSecondary, size: SellerIconSize.xl)),
              const SizedBox(height: SellerSpace.s8),
              Text(message ?? l10n.dsChartSummaryUnavailable, style: context.text.bodyMedium, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius((Offset.zero & size).deflate(SellerSize.hairline / 2), const Radius.circular(SellerRadius.card));
    canvas.drawPath(
      _dashed(Path()..addRRect(r)),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = SellerSize.hairline,
    );
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}

/// Public dashed outline for empty upload slots and "Add tier" rows (boards 15, 22-02).
class SellerDashedBorder extends StatelessWidget {
  const SellerDashedBorder({super.key, required this.child, this.color});
  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _DashedBorderPainter(color ?? context.colors.controlBorder), child: child);
}

/// Chart card: title, visible summary, the chart, a legend and the same
/// numbers as a table (shown or behind "Show as table").
class SellerChartCard extends StatefulWidget {
  const SellerChartCard({
    super.key,
    required this.title,
    required this.chart,
    this.summary,
    this.legend,
    this.table,
    this.trailing,
    this.initiallyShowTable = false,
  });

  final String title;
  final String? summary;
  final Widget chart;
  final Widget? legend;
  final Widget? table;
  final Widget? trailing;
  final bool initiallyShowTable;

  @override
  State<SellerChartCard> createState() => _SellerChartCardState();
}

class _SellerChartCardState extends State<SellerChartCard> {
  late bool _table = widget.initiallyShowTable;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final l10n = AppLocalizations.of(context);
    return SellerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(header: true, child: Text(widget.title, style: text.titleMedium)),
                    if (widget.summary != null) ...[
                      const SizedBox(height: SellerSpace.s2),
                      Text(widget.summary!, style: text.bodyMedium),
                    ],
                  ],
                ),
              ),
              if (widget.trailing != null) widget.trailing!,
            ],
          ),
          const SizedBox(height: SellerSpace.s16),
          widget.chart,
          if (widget.legend != null) ...[const SizedBox(height: SellerSpace.s12), widget.legend!],
          if (widget.table != null) ...[
            const SizedBox(height: SellerSpace.s8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: SellerButton.tertiary(
                label: _table ? l10n.dsHideTable : l10n.dsShowTable,
                icon: _table ? SellerIcons.chevronUp : SellerIcons.chevronDown,
                compact: true,
                onPressed: () => setState(() => _table = !_table),
              ),
            ),
            if (_table) ...[const SizedBox(height: SellerSpace.s8), widget.table!],
          ],
        ],
      ),
    );
  }
}
