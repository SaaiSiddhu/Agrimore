import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';

/// SELLER-OPS-2: weekly off days and holidays. Mirrors
/// functions/src/common/sellerAvailability.ts sellerClosedReason — a day is
/// the Indian calendar day, weekdays are ISO (1 = Monday … 7 = Sunday),
/// holidays are "YYYY-MM-DD".
enum ClosedToday { weeklyOff, holiday }

/// The Indian calendar day of [now].
DateTime istDate(DateTime now) {
  final ist = now.toUtc().add(const Duration(hours: 5, minutes: 30));
  return DateTime(ist.year, ist.month, ist.day);
}

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? parseDayKey(String k) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(k);
  return m == null ? null : DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
}

@immutable
class StoreSchedule {
  const StoreSchedule({this.weeklyOff = const {}, this.holidays = const []});

  factory StoreSchedule.fromSeller(Map<String, dynamic>? d) => StoreSchedule(
        weeklyOff: {
          for (final v in (d?['weeklyOff'] as List?) ?? const [])
            if (v is int && v >= 1 && v <= 7) v,
        },
        holidays: ([
          for (final v in (d?['holidays'] as List?) ?? const [])
            if (v is String && parseDayKey(v) != null) v,
        ]..sort()),
      );

  static const int maxHolidays = 30;

  final Set<int> weeklyOff;
  final List<String> holidays;

  ClosedToday? closedOn(DateTime now) {
    final day = istDate(now);
    if (weeklyOff.contains(day.weekday)) return ClosedToday.weeklyOff;
    if (holidays.contains(dayKey(day))) return ClosedToday.holiday;
    return null;
  }

  /// Holidays today or later, sorted.
  List<String> upcoming(DateTime now) {
    final today = dayKey(istDate(now));
    return [for (final h in holidays) if (h.compareTo(today) >= 0) h];
  }

  StoreSchedule copyWith({Set<int>? weeklyOff, List<String>? holidays}) =>
      StoreSchedule(weeklyOff: weeklyOff ?? this.weeklyOff, holidays: holidays ?? this.holidays);

  /// Past holidays are dropped on save.
  Map<String, Object?> toUpdate(DateTime now) => {
        'weeklyOff': (weeklyOff.toList()..sort()),
        'holidays': upcoming(now).take(maxHolidays).toList(),
      };
}

String weekdayShort(AppLocalizations l10n, int isoWeekday) => switch (isoWeekday) {
      1 => l10n.weekdayMon,
      2 => l10n.weekdayTue,
      3 => l10n.weekdayWed,
      4 => l10n.weekdayThu,
      5 => l10n.weekdayFri,
      6 => l10n.weekdaySat,
      _ => l10n.weekdaySun,
    };

/// One line for the Account tile.
String describeSchedule(StoreSchedule s, AppLocalizations l10n, DateTime now) {
  final days = (s.weeklyOff.toList()..sort()).map((d) => weekdayShort(l10n, d)).join(', ');
  final holidays = s.upcoming(now).length;
  if (days.isEmpty && holidays == 0) return l10n.scheduleOpenEveryDay;
  if (holidays == 0) return l10n.scheduleOffDays(days);
  if (days.isEmpty) return l10n.scheduleHolidayCount(holidays);
  return l10n.scheduleOffDaysAndHolidays(days, holidays);
}

class StoreScheduleScreen extends StatefulWidget {
  const StoreScheduleScreen({super.key, required this.initial, required this.onSave, this.now});
  final StoreSchedule initial;
  final Future<void> Function(StoreSchedule) onSave;
  final DateTime? now;

  @override
  State<StoreScheduleScreen> createState() => _StoreScheduleScreenState();
}

/// Weekly off & holidays (boards 22-03 + 22-04, one screen): day chips
/// with a summary, upcoming holidays with remove, add holiday (IST dates,
/// up to 30), at least one open day, sticky Save.
class _StoreScheduleScreenState extends State<StoreScheduleScreen> {
  late final DateTime _now = widget.now ?? DateTime.now();
  late final Set<int> _off = {...widget.initial.weeklyOff};
  late List<String> _holidays = widget.initial.upcoming(_now);
  bool _saving = false;
  bool _dirty = false;
  bool _allOffError = false;

  Future<void> _addHoliday() async {
    final l10n = AppLocalizations.of(context);
    if (_holidays.length >= StoreSchedule.maxHolidays) {
      SellerToast.show(context, l10n.scheduleHolidayLimit(StoreSchedule.maxHolidays), tone: SellerToastTone.danger);
      return;
    }
    final today = istDate(_now);
    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      helpText: l10n.scheduleAddHoliday,
    );
    if (picked == null || !mounted) return;
    final key = dayKey(picked);
    if (_holidays.contains(key)) return;
    setState(() {
      _holidays = ([..._holidays, key]..sort());
      _dirty = true;
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (_off.length == 7) {
      setState(() => _allOffError = true);
      SellerToast.show(context, l10n.scheduleAllDaysOff, tone: SellerToastTone.danger);
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(StoreSchedule(weeklyOff: _off, holidays: _holidays));
      if (!mounted) return;
      _dirty = false;
      SellerToast.show(context, l10n.scheduleSaved, tone: SellerToastTone.success);
      // pop(), not maybePop(): the unsaved-changes guard must not ask
      // "Discard changes?" right after a successful save.
      final navigator = Navigator.of(context);
      if (navigator.canPop()) navigator.pop();
    } catch (e) {
      debugPrint('Schedule save failed: $e');
      if (mounted) SellerToast.show(context, l10n.profileSaveFailed, tone: SellerToastTone.danger);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final text = context.text;
    final offDays = (_off.toList()..sort()).map((d) => weekdayShort(l10n, d)).join(', ');
    return SellerDiscardGuard(
      hasChanges: _dirty && !_saving,
      child: Scaffold(
        appBar: SellerAppBar.detail(context, title: l10n.scheduleTitle),
        body: SellerPage(
          gap: SellerSpace.s16,
          footer: SellerButton(label: l10n.accountSave, expand: true, loading: _saving, loadingLabel: l10n.saving, onPressed: _save),
          children: [
            SellerCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SellerSectionHeader(title: l10n.scheduleWeeklyOff, subtitle: l10n.scheduleWeeklyOffHint),
                Wrap(spacing: SellerSpace.s8, runSpacing: SellerSpace.s4, children: [
                  for (var d = 1; d <= 7; d++)
                    SellerChip(
                      label: weekdayShort(l10n, d),
                      style: SellerChipStyle.toggle,
                      selected: _off.contains(d),
                      onSelected: (v) => setState(() {
                        v ? _off.add(d) : _off.remove(d);
                        _dirty = true;
                        _allOffError = false;
                      }),
                    ),
                ]),
                const SizedBox(height: SellerSpace.s12),
                Row(children: [
                  Icon(SellerIcons.calendar, size: SellerIconSize.md, color: c.primary),
                  const SizedBox(width: SellerSpace.s8),
                  Expanded(
                    child: Text(
                      offDays.isEmpty ? l10n.scheduleOpenEveryDay : l10n.scheduleClosedEvery(offDays),
                      style: text.bodyLarge,
                    ),
                  ),
                ]),
                if (_allOffError) ...[
                  const SizedBox(height: SellerSpace.s12),
                  SellerBanner(tone: SellerTone.danger, message: l10n.scheduleKeepOneOpen, announce: true),
                ],
              ]),
            ),
            SellerCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SellerSectionHeader(title: l10n.scheduleHolidays, subtitle: l10n.scheduleHolidayHint, count: _holidays.isEmpty ? null : _holidays.length),
                if (_holidays.isEmpty)
                  SellerEmptyState(icon: SellerIcons.calendarAdd, title: l10n.scheduleNoHolidays, compact: true)
                else
                  for (final h in _holidays)
                    SellerListRow(
                      icon: SellerIcons.calendar,
                      title: SellerFormat.date(parseDayKey(h)!),
                      showChevron: false,
                      trailing: SellerIconButton(
                        icon: SellerIcons.delete,
                        label: l10n.scheduleRemoveHoliday,
                        color: c.danger,
                        onPressed: () => setState(() {
                          _holidays = [..._holidays]..remove(h);
                          _dirty = true;
                        }),
                      ),
                    ),
                const SizedBox(height: SellerSpace.s12),
                SellerButton.secondary(
                  label: l10n.scheduleAddHoliday,
                  icon: SellerIcons.calendarAdd,
                  expand: true,
                  onPressed: _holidays.length >= StoreSchedule.maxHolidays ? null : _addHoliday,
                ),
                const SizedBox(height: SellerSpace.s8),
                Text(l10n.scheduleHolidayLimitNote(StoreSchedule.maxHolidays), style: text.bodySmall),
              ]),
            ),
            SellerBanner(tone: SellerTone.info, message: l10n.scheduleConsequence),
          ],
        ),
      ),
    );
  }
}
