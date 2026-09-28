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
import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';

class HomeOperationsPanel extends StatefulWidget {
  const HomeOperationsPanel({super.key, required this.children});

  final List<Widget> children;

  @override
  State<HomeOperationsPanel> createState() => _HomeOperationsPanelState();
}

class _HomeOperationsPanelState extends State<HomeOperationsPanel> {
  final _sheet = DraggableScrollableController();
  bool _expanded = false;

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  void _toggle() {
    final target = _expanded ? 0.3 : 0.86;
    _sheet.animateTo(
      target,
      duration: DeliveryMotion.standardDuration,
      curve: DeliveryMotion.standard,
    );
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppLocalizations.of(context);
    return DraggableScrollableSheet(
      controller: _sheet,
      initialChildSize: 0.3,
      minChildSize: 0.16,
      maxChildSize: 0.86,
      snap: true,
      snapSizes: const [0.16, 0.3, 0.86],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: c.raised,
            borderRadius: DeliveryRadius.sheetTop,
            border: Border(top: BorderSide(color: c.border, width: DeliverySize.hairline)),
            boxShadow: DeliveryElevation.raised(c.shadow),
          ),
          child: Column(
            children: [
              Semantics(
                button: true,
                label: _expanded ? l.homePanelCollapse : l.homePanelExpand,
                child: InkWell(
                  key: const ValueKey('home-panel-handle'),
                  onTap: _toggle,
                  child: SizedBox(
                    height: DeliverySpace.xxl,
                    child: Center(
                      child: Icon(
                        _expanded ? DeliveryIcons.chevronDown : DeliveryIcons.chevronUp,
                        color: c.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: widget.children,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
