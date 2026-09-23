import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

/// Sheet to pause or resume the store; returns the new status or null.
Future<StoreStatus?> showStoreStatusSheet(BuildContext context, StoreStatus current, {DateTime? now}) {
  return showModalBottomSheet<StoreStatus>(
    context: context,
    isScrollControlled: true,
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
  int? _days = kPauseDays.first;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final text = context.wsText;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(WsSpace.page, 0, WsSpace.page, WsSpace.s24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l10n.storeStatusTitle, style: text.titleMedium),
          const SizedBox(height: WsSpace.s8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _accepting,
            onChanged: (v) => setState(() => _accepting = v),
            title: Text(l10n.storeAcceptingOrders, style: text.bodyLarge),
            subtitle: Text(_accepting ? l10n.storeAcceptingHint : l10n.storePausedHint, style: text.bodySmall),
          ),
          if (!_accepting) ...[
            const SizedBox(height: WsSpace.s8),
            Text(l10n.storePauseFor, style: text.labelLarge),
            const SizedBox(height: WsSpace.s8),
            Wrap(spacing: WsSpace.s8, runSpacing: WsSpace.s8, children: [
              for (final d in kPauseDays)
                ChoiceChip(
                  label: Text(d == null ? l10n.storePauseUntilResumed : l10n.storePauseDays(d)),
                  selected: _days == d,
                  onSelected: (_) => setState(() => _days = d),
                ),
            ]),
            const SizedBox(height: WsSpace.s12),
            SaInfoBanner(variant: SaBannerVariant.warning, message: l10n.storePauseConsequence),
          ],
          const SizedBox(height: WsSpace.s16),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_accepting
                ? const StoreStatus()
                : StoreStatus(
                    accepting: false,
                    pausedUntil: _days == null ? null : widget.now.add(Duration(days: _days!)),
                  )),
            style: _accepting ? null : FilledButton.styleFrom(backgroundColor: t.warningFg, foregroundColor: t.surface),
            child: Text(_accepting ? l10n.accountSave : l10n.storePauseCta),
          ),
        ]),
      ),
    );
  }
}
