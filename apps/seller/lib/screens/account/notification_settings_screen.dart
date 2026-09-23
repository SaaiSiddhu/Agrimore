import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = context.wsText;
    final t = context.ws;
    final p = _prefs;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.back,
          icon: const Icon(AgIcons.arrowLeft),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(l10n.prefTitle),
      ),
      body: p == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: WsSpace.s16),
              children: [
                if (_failed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(WsSpace.page, 0, WsSpace.page, WsSpace.s12),
                    child: SaInfoBanner(variant: SaBannerVariant.error, message: l10n.prefSaveFailed),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: WsSpace.page),
                  child: Text(l10n.prefIntro, style: text.bodyMedium!.copyWith(color: t.textSecondary)),
                ),
                const SizedBox(height: WsSpace.s8),
                for (final c in kNotificationCategories)
                  SwitchListTile(
                    value: p.isOn(c),
                    onChanged: (on) => _update(p.toggled(c, on)),
                    title: Text(_label(l10n, c), style: text.bodyLarge),
                  ),
                const Divider(height: WsSpace.s32),
                SwitchListTile(
                  value: p.quietHours,
                  onChanged: (on) => _update(p.copyWith(quietHours: on)),
                  title: Text(l10n.prefQuietHours, style: text.bodyLarge),
                  subtitle: Text(l10n.prefQuietHoursHint, style: text.bodySmall),
                ),
                if (p.quietHours) ...[
                  ListTile(
                    title: Text(l10n.prefQuietFrom, style: text.bodyLarge),
                    trailing: Text(_time(context, p.quietStartMin), style: text.titleSmall),
                    onTap: () => _pickTime(true),
                  ),
                  ListTile(
                    title: Text(l10n.prefQuietUntil, style: text.bodyLarge),
                    trailing: Text(_time(context, p.quietEndMin), style: text.titleSmall),
                    onTap: () => _pickTime(false),
                  ),
                ],
              ],
            ),
    );
  }
}
