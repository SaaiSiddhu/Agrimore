import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/seller_auth_provider.dart';
import 'notification_prefs.dart';

/// Persists preferences; injected in tests. Returns success.
typedef PrefsSaver = Future<bool> Function(NotificationPrefs prefs);

/// M-07 Notification preferences (ADR §10.6, SELLER-ACCOUNT-1b): a push
/// toggle per category and quiet hours. The server honours them
/// (notificationPrefs.ts); inbox entries are always kept.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key, this.initial, this.saver});
  final NotificationPrefs? initial;
  final PrefsSaver? saver;

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  NotificationPrefs? _prefs;
  bool _failed = false;

  DocumentReference<Map<String, dynamic>>? get _doc {
    final uid = context.read<SellerAuthProvider>().currentUser?.uid;
    return uid == null
        ? null
        : FirebaseFirestore.instance.collection('users').doc(uid).collection('settings').doc('notifications');
  }

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _prefs = widget.initial;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    try {
      final snap = await _doc?.get();
      if (mounted) setState(() => _prefs = NotificationPrefs.fromMap(snap?.data()));
    } catch (e) {
      debugPrint('Notification prefs load failed: $e');
      if (mounted) setState(() => _prefs = const NotificationPrefs());
    }
  }

  Future<bool> _defaultSave(NotificationPrefs p) async {
    try {
      await _doc?.set({...p.toMap(), 'updatedAt': FieldValue.serverTimestamp()});
      return true;
    } catch (e) {
      debugPrint('Notification prefs save failed: $e');
      return false;
    }
  }

  Future<void> _update(NotificationPrefs next) async {
    final previous = _prefs;
    setState(() {
      _prefs = next;
      _failed = false;
    });
    final ok = await (widget.saver ?? _defaultSave)(next);
    if (!ok && mounted) {
      setState(() {
        _prefs = previous;
        _failed = true;
      });
    }
  }

  Future<void> _pickTime(bool start) async {
    final p = _prefs!;
    final minutes = start ? p.quietStartMin : p.quietEndMin;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (picked == null) return;
    final value = picked.hour * 60 + picked.minute;
    await _update(start ? p.copyWith(quietStartMin: value) : p.copyWith(quietEndMin: value));
  }

  String _label(AppLocalizations l10n, String c) => switch (c) {
        'orders' => l10n.prefOrders,
        'quotes' => l10n.prefQuotes,
        'payments' => l10n.prefPayments,
        'stock' => l10n.prefStock,
        'reviews' => l10n.prefReviews,
        _ => l10n.prefAnnouncements,
      };

  String _time(BuildContext context, int minutes) =>
      MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60));

  IconData _icon(String c) => switch (c) {
        'orders' => SellerIcons.orders,
        'quotes' => SellerIcons.quote,
        'payments' => SellerIcons.payments,
        'stock' => SellerIcons.stock,
        'reviews' => SellerIcons.star,
        _ => SellerIcons.bell,
      };

  /// Board 23-02/23-03: a switch per category, quiet hours with From/Until
  /// time rows and a range summary; a failed save rolls back and says so.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = context.text;
    final p = _prefs;
    return Scaffold(
      appBar: SellerAppBar.detail(context, title: l10n.prefTitle),
      body: p == null
          ? SellerLoadingView(label: l10n.dsLoading)
          : SellerPage(
              gap: SellerSpace.s16,
              children: [
                if (_failed) SellerBanner(tone: SellerTone.danger, message: l10n.prefSaveFailed, announce: true),
                Text(l10n.prefIntro, style: text.bodyLarge),
                SellerMenuGroup(children: [
                  for (final c in kNotificationCategories)
                    SellerSwitchRow(title: _label(l10n, c), icon: _icon(c), value: p.isOn(c), onChanged: (on) => _update(p.toggled(c, on))),
                ]),
                SellerCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    SellerSwitchRow(
                      title: l10n.prefQuietHours,
                      subtitle: l10n.prefQuietHoursHint,
                      icon: SellerIcons.moon,
                      value: p.quietHours,
                      onChanged: (on) => _update(p.copyWith(quietHours: on)),
                    ),
                    if (p.quietHours) ...[
                      const SizedBox(height: SellerSpace.s8),
                      SellerPickerField(label: l10n.prefQuietFrom, icon: SellerIcons.clock, value: _time(context, p.quietStartMin), onTap: () => _pickTime(true)),
                      const SizedBox(height: SellerSpace.s12),
                      SellerPickerField(label: l10n.prefQuietUntil, icon: SellerIcons.clock, value: _time(context, p.quietEndMin), onTap: () => _pickTime(false)),
                      const SizedBox(height: SellerSpace.s12),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: SellerStatusBadge(
                          label: l10n.prefQuietRange(_time(context, p.quietStartMin), _time(context, p.quietEndMin)),
                          tone: SellerTone.brand,
                          icon: SellerIcons.moon,
                        ),
                      ),
                      if (p.quietEndMin < p.quietStartMin) ...[
                        const SizedBox(height: SellerSpace.s8),
                        Text(l10n.prefQuietNextMorning, style: text.bodyMedium),
                      ],
                    ],
                  ]),
                ),
              ],
            ),
    );
  }
}
