import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/seller_auth_provider.dart';
import '../../providers/seller_order_provider.dart';
import '../orders/seller_order_detail_screen.dart';
import '../rfq/seller_rfq_detail_screen.dart';
import '../shell/seller_shell.dart';
import 'inbox_rules.dart';

CollectionReference<Map<String, dynamic>> _inbox(String uid) =>
    FirebaseFirestore.instance.collection('users').doc(uid).collection('notifications');

/// Bell for app bars: unread count from the seller's inbox.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, this.unreadOverride});

  /// Fixed count for tests; otherwise streamed.
  final int? unreadOverride;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final uid = unreadOverride == null ? context.read<SellerAuthProvider>().currentUser?.uid : null;
    Widget bell(int n) => IconButton(
          tooltip: n == 0 ? l10n.notificationsTitle : l10n.notificationsUnread(n),
          // The bell sits inside the shell; a pushed route does not, so the
          // tab switch is handed over as a callback bound to this context.
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => NotificationsScreen(onTab: (tab) => SellerShell.goToTab(context, tab)))),
          icon: Badge(
            isLabelVisible: n > 0,
            label: Text(n > 99 ? '99+' : AgFormat.count(n)),
            child: const Icon(AgIcons.bell),
          ),
        );
    if (unreadOverride != null || uid == null) return bell(unreadOverride ?? 0);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _inbox(uid).where('unread', isEqualTo: true).limit(100).snapshots(),
      builder: (context, snap) => bell(snap.data?.docs.length ?? 0),
    );
  }
}

/// H-02 Notifications (ADR §10.2, SELLER-HOME-1b): Today / Earlier, filter
/// by category, unread dot, swipe or tap to mark read, mark all read, and
/// every entry opens what it is about.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.entries, this.now, this.onTab});

  /// Switches the shell's bottom bar (the screen itself is outside it).
  final void Function(SellerTab tab)? onTab;

  /// Injected in tests; otherwise streamed.
  final List<InboxEntry>? entries;
  final DateTime? now;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const int _limit = 100;
  InboxCategory? _filter;
  bool _actionFailed = false;

  String? get _uid => widget.entries == null ? context.read<SellerAuthProvider>().currentUser?.uid : null;

  Future<void> _markRead(InboxEntry e) async {
    final uid = _uid;
    if (uid == null || !e.unread) return;
    try {
      await _inbox(uid).doc(e.id).update(markReadUpdate());
    } catch (err) {
      debugPrint('Mark read failed: $err');
    }
  }

  Future<void> _markAllRead(List<InboxEntry> entries) async {
    final uid = _uid;
    if (uid == null) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final e in entries.where((e) => e.unread)) {
      batch.update(_inbox(uid).doc(e.id), markReadUpdate());
    }
    try {
      await batch.commit();
      if (mounted && _actionFailed) setState(() => _actionFailed = false);
    } catch (err) {
      debugPrint('Mark all read failed: $err');
      if (mounted) setState(() => _actionFailed = true);
    }
  }

  void _open(InboxEntry e) {
    _markRead(e);
    final link = e.link;
    switch (link.target) {
      case InboxTarget.order:
        OrderModel? order;
        for (final o in context.read<SellerOrderProvider>().allOrders) {
          if (o.id == link.id) order = o;
        }
        final found = order;
        if (found != null) {
          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SellerOrderDetailScreen(order: found)));
        } else {
          Navigator.of(context).pop();
          widget.onTab?.call(SellerTab.orders);
        }
      case InboxTarget.quote:
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SellerRfqDetailScreen(rfqId: link.id)));
      case InboxTarget.payments:
        Navigator.of(context).pop();
        widget.onTab?.call(SellerTab.payments);
      case InboxTarget.none:
        break;
    }
  }

  String _chip(AppLocalizations l10n, InboxCategory? c) => switch (c) {
        null => l10n.notificationsAll,
        InboxCategory.orders => l10n.notificationsOrders,
        InboxCategory.quotes => l10n.notificationsQuotes,
        InboxCategory.payments => l10n.notificationsPayments,
        InboxCategory.account => l10n.notificationsAccount,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final injected = widget.entries;
    if (injected != null) return _scaffold(context, l10n, injected);
    final uid = _uid;
    if (uid == null) return _scaffold(context, l10n, const []);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _inbox(uid).orderBy('createdAt', descending: true).limit(_limit).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          debugPrint('Notifications failed: ${snap.error}');
          return _scaffold(context, l10n, const [], failed: true);
        }
        if (!snap.hasData) return _scaffold(context, l10n, const [], loading: true);
        return _scaffold(context, l10n, [for (final d in snap.data!.docs) InboxEntry.fromMap(d.id, d.data())]);
      },
    );
  }

  Widget _scaffold(BuildContext context, AppLocalizations l10n, List<InboxEntry> all,
      {bool loading = false, bool failed = false}) {
    final t = context.ws;
    final text = context.wsText;
    final now = widget.now ?? DateTime.now();
    final shown = _filter == null ? all : all.where((e) => e.category == _filter).toList();
    final today = shown.where((e) => e.isToday(now)).toList();
    final earlier = shown.where((e) => !e.isToday(now)).toList();
    final anyUnread = all.any((e) => e.unread);

    Widget section(String title, List<InboxEntry> items) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(WsSpace.page, WsSpace.s16, WsSpace.page, WsSpace.s8),
              child: Text(title, style: text.labelLarge!.copyWith(color: t.textSecondary)),
            ),
            for (final e in items) _tile(context, e),
          ],
        );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.back,
          icon: const Icon(AgIcons.arrowLeft),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(l10n.notificationsTitle),
        actions: [
          if (anyUnread) TextButton(onPressed: () => _markAllRead(all), child: Text(l10n.notificationsMarkAllRead)),
        ],
      ),
      body: Column(children: [
        SizedBox(
          height: WsSize.chipHeight + WsSpace.s16,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: WsSpace.page, vertical: WsSpace.s8),
            children: [
              for (final c in <InboxCategory?>[null, ...InboxCategory.values])
                Padding(
                  padding: const EdgeInsets.only(right: WsSpace.s8),
                  child: ChoiceChip(
                    label: Text(_chip(l10n, c)),
                    selected: _filter == c,
                    onSelected: (_) => setState(() => _filter = c),
                  ),
                ),
            ],
          ),
        ),
        if (_actionFailed)
          Padding(
            padding: const EdgeInsets.fromLTRB(WsSpace.page, 0, WsSpace.page, WsSpace.s8),
            child: SaInfoBanner(variant: SaBannerVariant.error, message: l10n.notificationsActionFailed),
          ),
        Expanded(
          child: failed
              ? Padding(
                  padding: const EdgeInsets.all(WsSpace.page),
                  child: SaInfoBanner(variant: SaBannerVariant.error, message: l10n.notificationsLoadFailed),
                )
              : loading
                  ? const Center(child: CircularProgressIndicator())
                  : shown.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(WsSpace.s32),
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Icon(AgIcons.bell, size: WsIconSize.empty, color: t.textTertiary),
                              const SizedBox(height: WsSpace.s12),
                              Text(l10n.notificationsEmpty, style: text.bodyMedium, textAlign: TextAlign.center),
                            ]),
                          ),
                        )
                      : ListView(children: [
                          if (today.isNotEmpty) section(l10n.notificationsToday, today),
                          if (earlier.isNotEmpty) section(l10n.notificationsEarlier, earlier),
                        ]),
        ),
      ]),
    );
  }

  Widget _tile(BuildContext context, InboxEntry e) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final text = context.wsText;
    final icon = switch (e.category) {
      InboxCategory.orders => AgIcons.orders,
      InboxCategory.quotes => AgIcons.quote,
      InboxCategory.payments => AgIcons.wallet,
      InboxCategory.account => AgIcons.info,
    };
    final tile = ListTile(
      onTap: () => _open(e),
      tileColor: e.unread ? t.primarySubtle : null,
      leading: Icon(icon, color: e.unread ? t.primary : t.textTertiary),
      title: Text(e.title, style: e.unread ? text.titleSmall : text.bodyLarge),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (e.body.isNotEmpty) Text(e.body, style: text.bodyMedium),
        if (e.createdAt != null)
          Text(AgFormat.dateTime(e.createdAt!), style: text.bodySmall!.copyWith(color: t.textTertiary)),
      ]),
      trailing: e.unread
          ? Semantics(
              label: l10n.notificationsUnreadLabel,
              child: Container(
                width: WsSpace.s8,
                height: WsSpace.s8,
                decoration: BoxDecoration(color: t.primary, shape: BoxShape.circle),
              ),
            )
          : null,
    );
    if (!e.unread) return tile;
    return Dismissible(
      key: ValueKey('n-${e.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _markRead(e);
        return false; // Stays in the list, now read.
      },
      background: Container(
        color: t.surfaceSunken,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: WsSpace.page),
        child: Text(l10n.notificationsMarkRead, style: text.labelLarge),
      ),
      child: tile,
    );
  }
}
