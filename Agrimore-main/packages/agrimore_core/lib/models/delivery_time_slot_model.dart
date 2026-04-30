/// Admin-configured delivery window (time-of-day only, local timezone).
class DeliveryTimeSlotModel {
  final String id;
  final String label;
  /// 24h "HH:mm" e.g. "06:00"
  final String start;
  final String end;
  final bool active;
  final String icon;

  const DeliveryTimeSlotModel({
    required this.id,
    required this.label,
    required this.start,
    required this.end,
    this.active = true,
    this.icon = '🕒',
  });

  String get displayTimeRange => '$start – $end';

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'start': start,
        'end': end,
        'active': active,
        'icon': icon,
      };

  factory DeliveryTimeSlotModel.fromMap(Map<String, dynamic> map) {
    return DeliveryTimeSlotModel(
      id: map['id']?.toString() ?? '',
      label: map['label']?.toString() ?? 'Slot',
      start: map['start']?.toString() ?? '09:00',
      end: map['end']?.toString() ?? '12:00',
      active: map['active'] != false,
      icon: map['icon']?.toString() ?? '🕒',
    );
  }

  /// Whether [moment]'s clock time falls inside [start, end) for the same calendar day.
  /// Supports overnight ranges when start > end (e.g. 22:00–02:00).
  bool containsClock(DateTime moment) {
    if (!active) return false;
    final nowMin = moment.hour * 60 + moment.minute;
    final s = _parseHHmmToMinutes(start);
    final e = _parseHHmmToMinutes(end);
    if (s == null || e == null) return false;
    if (s < e) {
      return nowMin >= s && nowMin < e;
    }
    return nowMin >= s || nowMin < e;
  }

  static int? _parseHHmmToMinutes(String raw) {
    final parts = raw.trim().split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  static List<DeliveryTimeSlotModel> defaultSlots() => const [
        DeliveryTimeSlotModel(
          id: 'default-1',
          label: 'Early morning',
          start: '06:00',
          end: '09:00',
          icon: '🌅',
        ),
        DeliveryTimeSlotModel(
          id: 'default-2',
          label: 'Late morning',
          start: '09:00',
          end: '12:00',
          icon: '☀️',
        ),
        DeliveryTimeSlotModel(
          id: 'default-3',
          label: 'Evening',
          start: '16:00',
          end: '19:00',
          icon: '🌇',
        ),
      ];
}
