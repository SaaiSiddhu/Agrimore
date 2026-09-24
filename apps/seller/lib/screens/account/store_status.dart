import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';

/// SELLER-OPS-1 (ADR M-06): whether the store takes orders. Mirrors
/// functions/src/common/sellerAvailability.ts isSellerPaused exactly.
@immutable
class StoreStatus {
  const StoreStatus({this.accepting = true, this.pausedUntil});

  factory StoreStatus.fromSeller(Map<String, dynamic>? d) {
    final until = d?['pausedUntil'];
    return StoreStatus(
      accepting: d?['acceptingOrders'] != false,
      pausedUntil: until is Timestamp ? until.toDate() : null,
    );
  }

  final bool accepting;
  final DateTime? pausedUntil;

  bool isPaused(DateTime now) => !accepting && (pausedUntil == null || pausedUntil!.isAfter(now));

  Map<String, Object?> toUpdate() => {
        'acceptingOrders': accepting,
        'pausedUntil': pausedUntil == null ? null : Timestamp.fromDate(pausedUntil!),
      };
}

/// Pause lengths offered (null = until resumed).
const List<int?> kPauseDays = [1, 3, 7, null];

/// Store status sheet (board 22-02): accepting switch, pause length (1 · 3 ·
/// 7 days · until I resume), the consequence, [Cancel][Pause my store] or
/// [Cancel][Save]. Returns the new status or null.
Future<StoreStatus?> showStoreStatusSheet(BuildContext context, StoreStatus current, {DateTime? now}) {
  return showModalBottomSheet<StoreStatus>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _StoreStatusSheet(current: current, now: now ?? DateTime.now()),
  );
}

class _StoreStatusSheet extends StatefulWidget {
  const _StoreStatusSheet({required this.current, required this.now});
  final StoreStatus current;
  final DateTime now;

  @override
  State<_StoreStatusSheet> createState() => _StoreStatusSheetState();
}

class _StoreStatusSheetState extends State<_StoreStatusSheet> {
  late bool _accepting = !widget.current.isPaused(widget.now);
  // -1 stands for "until I resume" inside the segmented control.
  int _days = kPauseDays.first!;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SellerSheetFrame(
      title: l10n.storeStatusTitle,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SellerSwitchRow(
          title: l10n.storeAcceptingOrders,
          subtitle: _accepting ? l10n.storeAcceptingHint : l10n.storePausedHint,
          value: _accepting,
          bordered: true,
          onChanged: (v) => setState(() => _accepting = v),
        ),
        if (!_accepting) ...[
          const SizedBox(height: SellerSpace.s16),
          SellerFieldLabel(label: l10n.storePauseFor),
          const SizedBox(height: SellerSpace.s6),
          SellerSegmented<int>(
            semanticLabel: l10n.storePauseFor,
            segments: [
              for (final d in kPauseDays) SellerSegment(d ?? -1, d == null ? l10n.storePauseUntilResumed : l10n.storePauseDays(d)),
            ],
            selected: _days,
            onChanged: (v) => setState(() => _days = v),
          ),
          const SizedBox(height: SellerSpace.s12),
          SellerBanner(tone: SellerTone.warning, message: l10n.storePauseConsequence),
        ] else ...[
          const SizedBox(height: SellerSpace.s12),
          Text(l10n.storeScheduledStillApply, style: context.text.bodyMedium),
        ],
      ]),
      footer: SellerButtonBar(children: [
        SellerButton.secondary(label: l10n.cancel, onPressed: () => Navigator.of(context).pop()),
        SellerButton(
          label: _accepting ? l10n.accountSave : l10n.storePauseCta,
          icon: _accepting ? SellerIcons.check : SellerIcons.paused,
          onPressed: () => Navigator.of(context).pop(_accepting
              ? const StoreStatus()
              : StoreStatus(accepting: false, pausedUntil: _days < 0 ? null : widget.now.add(Duration(days: _days)))),
        ),
      ]),
    );
  }
}
