import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';

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

class _StoreScheduleScreenState extends State<StoreScheduleScreen> {
  late final DateTime _now = widget.now ?? DateTime.now();
  late final Set<int> _off = {...widget.initial.weeklyOff};
  late List<String> _holidays = widget.initial.upcoming(_now);
  bool _saving = false;

  Future<void> _addHoliday() async {
    final l10n = AppLocalizations.of(context);
    if (_holidays.length >= StoreSchedule.maxHolidays) {
      WsToast.show(context, l10n.scheduleHolidayLimit(StoreSchedule.maxHolidays), tone: WsToastTone.error);
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
    setState(() => _holidays = ([..._holidays, key]..sort()));
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (_off.length == 7) {
      WsToast.show(context, l10n.scheduleAllDaysOff, tone: WsToastTone.error);
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(StoreSchedule(weeklyOff: _off, holidays: _holidays));
      if (!mounted) return;
      WsToast.show(context, l10n.accountSaved, tone: WsToastTone.success);
      Navigator.of(context).maybePop();
    } catch (e) {
      debugPrint('Schedule save failed: $e');
      if (mounted) WsToast.show(context, l10n.profileSaveFailed, tone: WsToastTone.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final text = context.wsText;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: l10n.back, icon: const Icon(AgIcons.arrowLeft), onPressed: () => Navigator.of(context).maybePop()),
        title: Text(l10n.scheduleTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(WsSpace.page),
        children: [
          Text(l10n.scheduleWeeklyOff, style: text.titleSmall),
          const SizedBox(height: WsSpace.s4),
          Text(l10n.scheduleWeeklyOffHint, style: text.bodySmall!.copyWith(color: t.textSecondary)),
          const SizedBox(height: WsSpace.s12),
          Wrap(spacing: WsSpace.s8, runSpacing: WsSpace.s8, children: [
            for (var d = 1; d <= 7; d++)
              FilterChip(
                label: Text(weekdayShort(l10n, d)),
                selected: _off.contains(d),
                onSelected: (v) => setState(() => v ? _off.add(d) : _off.remove(d)),
              ),
          ]),
          const SizedBox(height: WsSpace.s24),
          Row(children: [
            Expanded(child: Text(l10n.scheduleHolidays, style: text.titleSmall)),
            TextButton.icon(onPressed: _addHoliday, icon: const Icon(AgIcons.add), label: Text(l10n.scheduleAddHoliday)),
          ]),
          if (_holidays.isEmpty)
            Text(l10n.scheduleNoHolidays, style: text.bodySmall!.copyWith(color: t.textSecondary))
          else
            for (final h in _holidays)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(AgIcons.calendar, color: t.primary),
                title: Text(AgFormat.date(parseDayKey(h)!), style: text.bodyLarge),
                trailing: IconButton(
                  tooltip: l10n.scheduleRemoveHoliday,
                  icon: const Icon(AgIcons.delete),
                  onPressed: () => setState(() => _holidays = [..._holidays]..remove(h)),
                ),
              ),
          const SizedBox(height: WsSpace.s16),
          SaInfoBanner(variant: SaBannerVariant.info, message: l10n.scheduleConsequence),
          const SizedBox(height: WsSpace.s24),
          FilledButton(onPressed: _saving ? null : _save, child: Text(l10n.accountSave)),
        ],
      ),
    );
  }
}
