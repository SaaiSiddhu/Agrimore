import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../icons/seller_icons.dart';
import '../tokens/seller_colors.dart';
import '../tokens/seller_tokens.dart';
import '../tokens/seller_typography.dart';
import 'seller_badge.dart';

/// Where a step stands. Each state has its own marker shape (check · ring ·
/// hollow circle · "!"), so it reads without colour (boards 12, 16-06, 19-03).
enum SellerStepState { done, current, upcoming, failed }

@immutable
class SellerTimelineStep {
  const SellerTimelineStep({required this.title, required this.state, this.subtitle, this.detail});

  final String title;
  final SellerStepState state;

  /// Date or status line ("24 Sep 2026", "In progress", "Awaiting payment record").
  final String? subtitle;

  /// Extra content under the step, e.g. an offer card in a negotiation history.
  final Widget? detail;
}

/// Vertical stage list: order stages (17-04), application status (16-06),
/// settlement status (19-03), negotiation history (20-02). Done = filled teal
/// check; current = teal ring + "Current" pill, bold title; upcoming = hollow
/// grey circle; the connector into an upcoming step is dashed.
class SellerTimeline extends StatelessWidget {
  const SellerTimeline({super.key, required this.steps, this.showCurrentPill = true, this.dense = false});

  final List<SellerTimelineStep> steps;
  final bool showCurrentPill;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < steps.length; i++)
          _StepRow(
            step: steps[i],
            next: i + 1 < steps.length ? steps[i + 1] : null,
            showCurrentPill: showCurrentPill,
            dense: dense,
          ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.next, required this.showCurrentPill, required this.dense});

  final SellerTimelineStep step;
  final SellerTimelineStep? next;
  final bool showCurrentPill;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final l10n = AppLocalizations.of(context);
    final marker = dense ? SellerIconSize.md : SellerIconSize.lg;
    final isCurrent = step.state == SellerStepState.current;
    final stateWord = switch (step.state) {
      SellerStepState.done => l10n.dsStepCompleted,
      SellerStepState.current => l10n.dsStepCurrent,
      SellerStepState.upcoming => l10n.dsStepUpcoming,
      SellerStepState.failed => l10n.dsStepFailed,
    };
    final pill = isCurrent && showCurrentPill;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: marker,
            child: Column(
              children: [
                _Marker(state: step.state, size: marker),
                if (next != null)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: SellerSpace.s2),
                      child: CustomPaint(
                        painter: _ConnectorPainter(
                          solid: next!.state == SellerStepState.done || next!.state == SellerStepState.current,
                          color: next!.state == SellerStepState.upcoming ? c.controlBorder : c.primary,
                        ),
                        child: const SizedBox(width: SellerSize.focus),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: SellerSpace.s12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: next == null ? 0 : (dense ? SellerSpace.s12 : SellerSpace.s20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MergeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: SellerSpace.s8,
                          runSpacing: SellerSpace.s4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              step.title,
                              style: (dense ? text.labelLarge : text.titleSmall)!.copyWith(
                                fontWeight: isCurrent ? SellerType.bold : null,
                                color: step.state == SellerStepState.upcoming ? c.textSecondary : c.textPrimary,
                              ),
                            ),
                            if (pill) SellerStatusBadge(label: l10n.dsStepCurrent, tone: SellerTone.brand),
                          ],
                        ),
                        if (step.subtitle != null) ...[
                          const SizedBox(height: SellerSpace.s2),
                          Text(step.subtitle!, style: text.bodySmall!.tabular),
                        ],
                        // The state is always spoken; visually it is the marker shape.
                        if (!pill) Semantics(label: stateWord, child: const SizedBox.shrink()),
                      ],
                    ),
                  ),
                  if (step.detail != null) ...[const SizedBox(height: SellerSpace.s8), step.detail!],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Marker extends StatelessWidget {
  const _Marker({required this.state, required this.size});
  final SellerStepState state;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final inner = size * 0.6;
    final (Color fill, Color border, double width, Widget? child) = switch (state) {
      SellerStepState.done => (c.primary, c.primary, SellerSize.focus, Icon(SellerIcons.check, size: inner, color: c.onPrimary)),
      SellerStepState.current => (
          c.surface,
          c.primary,
          SellerSize.focus,
          Container(
            width: size / 3,
            height: size / 3,
            decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
          ),
        ),
      SellerStepState.upcoming => (c.surface, c.controlBorder, SellerSize.outline, null),
      SellerStepState.failed => (c.dangerContainer, c.danger, SellerSize.focus, Icon(SellerIcons.warning, size: inner, color: c.danger)),
    };
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: fill, shape: BoxShape.circle, border: Border.all(color: border, width: width)),
        child: child,
      ),
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  _ConnectorPainter({required this.solid, required this.color});
  final bool solid;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = SellerSize.focus
      ..strokeCap = StrokeCap.round;
    final x = size.width / 2;
    if (solid) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
      return;
    }
    const dash = SellerSpace.s4;
    const gap = SellerSpace.s4;
    for (var y = 0.0; y < size.height; y += dash + gap) {
      canvas.drawLine(Offset(x, y), Offset(x, math.min(y + dash, size.height)), p);
    }
  }

  @override
  bool shouldRepaint(_ConnectorPainter old) => old.solid != solid || old.color != color;
}

/// How [SellerStepProgress] draws the steps.
enum SellerStepProgressStyle { dots, segments }

/// "Step 3 of 5" + connected dots (16-03/16-04) or a segmented bar (16-05).
/// Read as one phrase: "Step 3 of 5, Documents".
class SellerStepProgress extends StatelessWidget {
  const SellerStepProgress({
    super.key,
    required this.current,
    required this.total,
    this.stepTitle,
    this.style = SellerStepProgressStyle.dots,
  });

  /// 1-based.
  final int current;
  final int total;
  final String? stepTitle;
  final SellerStepProgressStyle style;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final l10n = AppLocalizations.of(context);
    final caption = l10n.stepOf(current, total);
    final spoken = stepTitle == null ? caption : '$caption, $stepTitle';

    final Widget track = switch (style) {
      SellerStepProgressStyle.segments => Row(
          children: [
            for (var i = 1; i <= total; i++) ...[
              if (i > 1) const SizedBox(width: SellerSpace.s4),
              Expanded(
                child: Container(
                  height: SellerSpace.s6,
                  decoration: BoxDecoration(
                    color: i <= current ? c.primary : c.border,
                    borderRadius: BorderRadius.circular(SellerRadius.pill),
                  ),
                ),
              ),
            ],
          ],
        ),
      SellerStepProgressStyle.dots => Row(
          children: [
            for (var i = 1; i <= total; i++) ...[
              if (i > 1)
                Expanded(
                  child: Container(height: SellerSize.focus, color: i <= current ? c.primary : c.border),
                ),
              Container(
                width: i == current ? SellerSpace.s16 : SellerSpace.s12,
                height: i == current ? SellerSpace.s16 : SellerSpace.s12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < current ? c.primary : (i == current ? c.surface : c.surface),
                  border: Border.all(
                    color: i <= current ? c.primary : c.controlBorder,
                    width: i == current ? SellerSize.focusStrong : SellerSize.outline,
                  ),
                ),
              ),
            ],
          ],
        ),
    };

    return Semantics(
      label: spoken,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(caption, style: text.labelLarge!.copyWith(color: c.primary))),
              if (stepTitle != null && style == SellerStepProgressStyle.segments) Text(stepTitle!, style: text.bodySmall),
            ],
          ),
          const SizedBox(height: SellerSpace.s8),
          track,
        ],
      ),
    );
  }
}
