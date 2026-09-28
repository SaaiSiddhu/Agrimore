// lib/screens/home/home_operations_panel.dart
//
// Phase DLVHOME1 — the expandable panel above the bottom nav that keeps
// every existing operational surface (pending proof, active-work states,
// earnings, quick actions) reachable once Home's main area became the map
// (owner brief: "reachable through compact overlays or an appropriate
// expandable panel... do not delete or hide critical work"). Purely
// presentational: DashboardScreen still owns every stream, provider read
// and state transition and simply hands this panel the widgets to show —
// this file adds no business logic of its own.
//
// Rider-requested resting shape (2026-09-28, twice refined after on-device
// checks): collapsed, the panel shows exactly [peek] (handle + Today/This
// week toggle + Earned card) and nothing else, AND the whole panel must be
// draggable up from anywhere on it (not just tap-to-toggle the handle) to
// reveal [expanded]. Both requirements point to the SAME structure: one
// single ListView, bound to the sheet's own scrollController, with the
// [peek] content as its first item and [expanded] right after it —
// DraggableScrollableSheet only recognises a drag-to-resize gesture on the
// Scrollable built from the controller it hands the builder, so an earlier
// version that put [peek] in a separate, non-scrolling Column sibling
// could only be toggled by tapping the handle, never dragged. A ListView
// also never throws a RenderFlex overflow regardless of how the minimum
// size estimate compares to the real content (an actual, repeated problem
// with the two fixed/measured-Column versions tried before this one) — it
// just scrolls, which is exactly the desired behaviour here too.
//
// minChildSize is a genuine measurement of [peek]'s real rendered height
// (via GlobalKey, corrected on the first frame after layout), not a
// static guess: a fixed pixel estimate reliably left either a visible gap
// (over-estimated) or revealed a sliver of the next real card
// (under-estimated) on an actual device, where font metrics/DPI differ
// from a decision made by reading source alone.
import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';

class HomeOperationsPanel extends StatefulWidget {
  const HomeOperationsPanel({
    super.key,
    required this.peek,
    required this.expanded,
  });

  /// The collapsed sheet's own content — handle included, sized to its own
  /// real rendered height, nothing more.
  final Widget peek;

  /// Scrolls into view only once the rider drags (or taps the handle) the
  /// sheet open past [peek]'s own height.
  final List<Widget> expanded;

  @override
  State<HomeOperationsPanel> createState() => _HomeOperationsPanelState();
}

class _HomeOperationsPanelState extends State<HomeOperationsPanel> {
  final _sheet = DraggableScrollableController();
  final _peekKey = GlobalKey();
  bool _expandedState = false;

  // Generous first-frame default (shrinking after measurement never
  // overflows a ListView anyway, but starting close avoids a visible jump).
  double _peekHeightPx = 200;
  double _lastMinFraction = 0.3;

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  void _toggle() {
    final target = _expandedState ? _lastMinFraction : 1.0;
    _sheet.animateTo(
      target,
      duration: DeliveryMotion.standardDuration,
      curve: DeliveryMotion.standard,
    );
    setState(() => _expandedState = !_expandedState);
  }

  // The sheet is asked for a hairline more than [heightPx] actually needs:
  // DraggableScrollableSheet's own fraction-to-pixel conversion measurably
  // does not round-trip to the exact pixel value asked for, and asking for
  // precisely the measured height reproduced a 1px RenderFlex overflow in
  // an earlier version of this widget (fixed there by giving the sheet and
  // its content two DIFFERENT numbers, never the same one twice).
  double _fractionFor(double heightPx, double totalHeight) =>
      ((heightPx + DeliverySize.hairline + DeliverySpace.xs) / totalHeight).clamp(0.1, 0.6);

  /// Runs after every frame: reads [peek]'s real rendered height (handle
  /// included) and corrects the sheet to match. `minChildSize` only takes
  /// effect on the sheet's first insertion — rebuilding with a new value
  /// alone does not resize an already-built sheet — so its actual current
  /// size is corrected explicitly via the controller too, only while
  /// collapsed (never yanks it mid-drag or while expanded).
  void _measure(double totalHeight) {
    final box = _peekKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || totalHeight <= 0) return;
    final h = box.size.height;
    if ((h - _peekHeightPx).abs() > 0.5) {
      setState(() => _peekHeightPx = h);
      if (!_expandedState && _sheet.isAttached) {
        _sheet.jumpTo(_fractionFor(h, totalHeight));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalHeight = constraints.maxHeight;
        _lastMinFraction =
            totalHeight > 0 ? _fractionFor(_peekHeightPx, totalHeight) : 0.3;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _measure(totalHeight);
        });
        return DraggableScrollableSheet(
          controller: _sheet,
          initialChildSize: _lastMinFraction,
          minChildSize: _lastMinFraction,
          // Expands all the way to the top of its own area — right below
          // the app bar, per the rider's own instruction.
          maxChildSize: 1.0,
          snap: true,
          snapSizes: [_lastMinFraction, 1.0],
          builder: (context, scrollController) {
            return DecoratedBox(
              decoration: BoxDecoration(color: c.raised, boxShadow: DeliveryElevation.raised(c.shadow)),
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.zero,
                children: [
                  // A plain ListView item, not BoxDecoration.border:
                  // Container.build() ADDS an explicit `padding` to a
                  // decoration's own border-padding instead of overriding
                  // it (confirmed by reading Container.build() directly),
                  // which reproducibly caused a 1px overflow in an earlier
                  // version of this file that used BoxDecoration.border.
                  Container(height: DeliverySize.hairline, color: c.border),
                  Column(
                    key: _peekKey,
                    children: [
                      Semantics(
                        button: true,
                        label: _expandedState ? l.homePanelCollapse : l.homePanelExpand,
                        child: InkWell(
                          key: const ValueKey('home-panel-handle'),
                          onTap: _toggle,
                          child: SizedBox(
                            height: DeliverySpace.xxl,
                            child: Center(
                              child: Icon(
                                _expandedState ? DeliveryIcons.chevronDown : DeliveryIcons.chevronUp,
                                color: c.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      widget.peek,
                    ],
                  ),
                  ...widget.expanded,
                ],
              ),
            );
          },
        );
      },
    );
  }
}
