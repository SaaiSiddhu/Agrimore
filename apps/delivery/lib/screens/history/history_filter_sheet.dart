// lib/screens/history/history_filter_sheet.dart
//
// Phase DLVC1 -- the canonical filter bottom sheet
// (30-delivery-history-inbox/01-history-filters.png, screen 2 of 3), closing
// two items DLVH1/DLVH11 both explicitly deferred: this sheet itself, and
// HistoryDateRange.custom (a rider-chosen date range).
//
// Staged, not immediate: every pill/radio tap here only updates this
// widget's own local state until Apply commits it to RiderHistory in one
// call -- Cancel (the sheet's own X / back-swipe / scrim tap) discards the
// staged selection entirely, matching the mockup's own Apply/Reset pair and
// the brief's own "Apply/reset/cancel behaviour" requirement. The mockup's
// own live result-count badge inside "Apply filters (12)" is treated as
// illustrative styling on the mockup's own fictional data (its top-right
// annotation says exactly that) -- rebuilding it truthfully would need a
// SEPARATE staged-filter count query fired on every pill/radio tap, before
// Apply is ever pressed, real Firestore cost for a button label. Recorded
// here, not silently dropped: this button says "Apply filters" alone.
//
// Status is ALSO offered here (a radio list, matching the mockup's own
// second section) even though the list screen's own inline status chips
// already work and are already tested -- the mockup keeps both, and a rider
// combining a custom range with a status change benefits from doing both in
// one Apply rather than two separate taps.
import 'package:flutter/material.dart';

import '../../data/rider_history.dart';
import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';

/// Opens the sheet; resolves once dismissed (Applied, Reset, or cancelled).
/// Reads [history]'s current filter/range as the sheet's own starting
/// selection; writes to it only if the rider taps Apply or Reset inside.
Future<void> showHistoryFilterSheet(BuildContext context, RiderHistory history) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => HistoryFilterSheet(history: history),
  );
}

class HistoryFilterSheet extends StatefulWidget {
  const HistoryFilterSheet({super.key, required this.history});
  final RiderHistory history;

  @override
  State<HistoryFilterSheet> createState() => _HistoryFilterSheetState();
}

class _HistoryFilterSheetState extends State<HistoryFilterSheet> {
  late HistoryDateRange _range = widget.history.dateRange;
  late HistoryFilter _status = widget.history.filter;

  /// The staged custom range, inclusive last day. Seeded from the currently
  /// APPLIED range when it is already custom (its own `until` is stored
  /// exclusive -- subtract a day so this field matches every other
  /// inclusive-last-day value here), so reopening the sheet never loses a
  /// rider's own already-chosen dates.
  late DateTimeRange? _customRange = widget.history.dateRange == HistoryDateRange.custom &&
          widget.history.since != null &&
          widget.history.until != null
      ? DateTimeRange(
          start: widget.history.since!,
          end: widget.history.until!.subtract(const Duration(days: 1)),
        )
      : null;

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _customRange,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _range = HistoryDateRange.custom;
      _customRange = picked;
    });
  }

  Future<void> _apply() async {
    final navigator = Navigator.of(context);
    if (_range == HistoryDateRange.custom) {
      final range = _customRange;
      if (range == null) return; // Custom selected but no dates chosen yet -- Apply is disabled for this case, see build().
      if (widget.history.filter != _status) widget.history.setFilter(_status);
      await widget.history.setCustomDateRange(range.start, range.end);
    } else {
      if (widget.history.filter != _status) widget.history.setFilter(_status);
      await widget.history.setDateRange(_range);
    }
    if (navigator.mounted) navigator.pop();
  }

  void _reset() {
    setState(() {
      _range = HistoryDateRange.allTime;
      _status = HistoryFilter.all;
      _customRange = null;
    });
    widget.history.clearFilters();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    final now = DateTime.now();
    final applyDisabled = _range == HistoryDateRange.custom && _customRange == null;

    String? subtitleFor(HistoryDateRange r) {
      if (r == HistoryDateRange.custom) {
        final range = _customRange;
        return range == null ? l.historyRangeCustomSelectDates : DeliveryFormat.dateRange(range.start, range.end);
      }
      final bounds = r.boundsAt(now);
      final since = bounds.since;
      if (since == null) return null; // allTime: no subtitle
      final untilInclusive = (bounds.until ?? now.add(const Duration(days: 1))).subtract(const Duration(days: 1));
      return DeliveryFormat.dateRange(since, untilInclusive);
    }

    Widget rangePill(HistoryDateRange r, String label) {
      final selected = _range == r;
      final subtitle = subtitleFor(r);
      return Expanded(
        child: Material(
          color: selected ? c.brandContainer : c.surface,
          borderRadius: DeliveryRadius.rMd,
          child: InkWell(
            key: ValueKey('history-sheet-range-${r.name}'),
            borderRadius: DeliveryRadius.rMd,
            onTap: () => r == HistoryDateRange.custom ? _pickCustomRange() : setState(() => _range = r),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: DeliverySpace.sm, horizontal: DeliverySpace.xs),
              decoration: BoxDecoration(
                borderRadius: DeliveryRadius.rMd,
                border: Border.all(
                  color: selected ? c.brand : c.border,
                  width: selected ? DeliverySize.strokeStrong : DeliverySize.stroke,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: t.labelMedium.copyWith(
                      color: selected ? c.onBrandContainer : c.textPrimary,
                      fontWeight: DeliveryType.bold,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: DeliverySpace.xxs),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.caption.copyWith(color: selected ? c.onBrandContainer : c.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    Widget statusRow(HistoryFilter f, String label) {
      return RadioListTile<HistoryFilter>(
        key: ValueKey('history-sheet-status-${f.name}'),
        value: f,
        title: Text(label, style: t.bodyMedium.copyWith(color: c.textPrimary)),
        activeColor: c.brand,
        contentPadding: EdgeInsets.zero,
        dense: true,
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        DeliverySpace.page,
        DeliverySpace.xxs,
        DeliverySpace.page,
        MediaQuery.of(context).viewInsets.bottom + DeliverySpace.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(l.historyFilterSheetTitle, style: t.headlineSmall.copyWith(color: c.textPrimary)),
                ),
                IconButton(
                  key: const ValueKey('history-sheet-close'),
                  icon: Icon(DeliveryIcons.close, color: c.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: DeliverySpace.sm),
            Text(
              l.historyFilterSheetDateRangeSection,
              style: t.labelLarge.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: DeliverySpace.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                rangePill(HistoryDateRange.thisWeek, l.historyRangeThisWeek),
                const SizedBox(width: DeliverySpace.sm),
                rangePill(HistoryDateRange.lastWeek, l.historyRangeLastWeek),
                const SizedBox(width: DeliverySpace.sm),
                rangePill(HistoryDateRange.custom, l.historyRangeCustom),
              ],
            ),
            const SizedBox(height: DeliverySpace.lg),
            Text(
              l.historyFilterSheetStatusSection,
              style: t.labelLarge.copyWith(color: c.textSecondary),
            ),
            RadioGroup<HistoryFilter>(
              groupValue: _status,
              onChanged: (v) => setState(() => _status = v!),
              child: Column(
                children: [
                  statusRow(HistoryFilter.all, l.historyFilterSheetAllStatuses),
                  statusRow(HistoryFilter.delivered, l.historyFilterDelivered),
                  statusRow(HistoryFilter.cancelled, l.historyFilterCancelled),
                  statusRow(HistoryFilter.returned, l.historyFilterReturned),
                ],
              ),
            ),
            const SizedBox(height: DeliverySpace.lg),
            DeliveryButton.primary(
              key: const ValueKey('history-sheet-apply'),
              label: l.historyFilterSheetApply,
              onPressed: applyDisabled ? null : _apply,
            ),
            const SizedBox(height: DeliverySpace.sm),
            DeliveryButton.secondary(
              key: const ValueKey('history-sheet-reset'),
              label: l.historyFilterSheetReset,
              onPressed: _reset,
            ),
          ],
        ),
      ),
    );
  }
}
