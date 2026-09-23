import 'package:flutter/foundation.dart';

/// Push categories — keys match functions/src/common/notificationPrefs.ts
/// and the firestore.rules schema for users/{uid}/settings/notifications.
const List<String> kNotificationCategories = ['orders', 'quotes', 'payments', 'stock', 'reviews', 'announcements'];

@immutable
class NotificationPrefs {
  const NotificationPrefs({
    this.enabled = const {},
    this.quietHours = false,
    this.quietStartMin = 22 * 60,
    this.quietEndMin = 7 * 60,
  });

  factory NotificationPrefs.fromMap(Map<String, dynamic>? d) {
    int minute(Object? v, int fallback) => v is int && v >= 0 && v < 1440 ? v : fallback;
    return NotificationPrefs(
      enabled: {for (final c in kNotificationCategories) c: d?[c] != false},
      quietHours: d?['quietHours'] == true,
      quietStartMin: minute(d?['quietStartMin'], 22 * 60),
      quietEndMin: minute(d?['quietEndMin'], 7 * 60),
    );
  }

  /// Category → on. Missing = on (the server treats it the same).
  final Map<String, bool> enabled;
  final bool quietHours;
  final int quietStartMin;
  final int quietEndMin;

  bool isOn(String category) => enabled[category] ?? true;

  NotificationPrefs copyWith({Map<String, bool>? enabled, bool? quietHours, int? quietStartMin, int? quietEndMin}) =>
      NotificationPrefs(
        enabled: enabled ?? this.enabled,
        quietHours: quietHours ?? this.quietHours,
        quietStartMin: quietStartMin ?? this.quietStartMin,
        quietEndMin: quietEndMin ?? this.quietEndMin,
      );

  NotificationPrefs toggled(String category, bool on) => copyWith(enabled: {...enabled, category: on});

  /// The document (only schema keys; updatedAt added by the writer).
  Map<String, Object> toMap() => {
        for (final c in kNotificationCategories) c: isOn(c),
        'quietHours': quietHours,
        'quietStartMin': quietStartMin,
        'quietEndMin': quietEndMin,
      };
}
