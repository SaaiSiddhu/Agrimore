// lib/screens/inbox/inbox_screen.dart
//
// Phase DLV-N1 / Phase 30 — the rider's inbox (lib/inbox/rider_inbox.dart).
// Tapping a notice marks it read and, for money notices, opens Earnings.
import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import '../../inbox/rider_inbox.dart';
import '../../l10n/app_localizations.dart';
import '../money/money_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({
    super.key,
    required this.riderId,
    required this.source,
  });
  final String riderId;
  final RiderInboxSource source;

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  late final Stream<List<RiderNotice>> _latest =
      widget.source.latest(widget.riderId);
  List<RiderNotice> _shown = const [];

  Future<void> _markRead(Iterable<String> ids) async {
    if (ids.isEmpty) return;
    try {
      await widget.source.markRead(widget.riderId, ids);
    } catch (e) {
      debugPrint('Inbox mark read: $e');
      if (mounted) {
        showDeliveryToast(
          context,
          message: AppLocalizations.of(context).inboxMarkReadFailed,
          tone: DeliveryBannerTone.danger,
        );
      }
    }
  }

  void _open(RiderNotice n) {
    if (n.unread) _markRead([n.id]);
    if (n.target == NoticeTarget.money) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MoneyScreen(riderId: widget.riderId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: Text(l.inboxTitle),
        actions: [
          TextButton(
            onPressed: () =>
                _markRead(_shown.where((n) => n.unread).map((n) => n.id)),
            child: Text(l.inboxMarkAllRead),
          ),
        ],
      ),
      body: StreamBuilder<List<RiderNotice>>(
        stream: _latest,
        builder: (context, snap) {
          if (snap.hasError) {
            return _Centered(
              icon: DeliveryIcons.offline,
              text: l.inboxLoadError,
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = _shown = snap.data!;
          if (list.isEmpty) {
            return _Centered(
              icon: DeliveryIcons.bell,
              text: l.inboxEmpty,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: DeliverySpace.sm),
            itemCount: list.length + (list.length >= kInboxSize ? 1 : 0),
            separatorBuilder: (_, __) =>
                const Divider(height: DeliverySize.hairline),
            itemBuilder: (context, i) {
              if (i == list.length) {
                return Padding(
                  padding: const EdgeInsets.all(DeliverySpace.lg),
                  child: Text(
                    l.inboxLimitNote(kInboxSize),
                    textAlign: TextAlign.center,
                    style: t.bodySmall.copyWith(color: c.textTertiary),
                  ),
                );
              }
              final n = list[i];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: DeliverySpace.page,
                  vertical: DeliverySpace.xxs,
                ),
                leading: Icon(
                  n.unread ? DeliveryIcons.bell : DeliveryIcons.checkCircle,
                  color: n.unread ? c.brand : c.textTertiary,
                ),
                title: Text(
                  n.title,
                  style: (n.unread ? t.titleSmall : t.bodyLarge).copyWith(
                    color: c.textPrimary,
                  ),
                ),
                subtitle: Text(
                  [
                    n.body,
                    if (n.createdAt != null)
                      DeliveryFormat.dateTime(n.createdAt!.toLocal()),
                  ].join('\n'),
                  style: t.bodySmall.copyWith(color: c.textSecondary),
                ),
                isThreeLine: n.createdAt != null,
                trailing: n.target == NoticeTarget.money
                    ? Icon(
                        DeliveryIcons.chevronRight,
                        size: DeliveryIconSize.sm,
                        color: c.textTertiary,
                      )
                    : null,
                onTap: () => _open(n),
              );
            },
          );
        },
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DeliverySpace.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: DeliveryIconSize.hero, color: c.textTertiary),
            const SizedBox(height: DeliverySpace.md),
            Text(
              text,
              textAlign: TextAlign.center,
              style: t.bodyLarge.copyWith(color: c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// The dashboard's inbox icon with the unread count.
class InboxButton extends StatefulWidget {
  const InboxButton({
    super.key,
    required this.riderId,
    required this.source,
  });
  final String riderId;
  final RiderInboxSource source;

  @override
  State<InboxButton> createState() => _InboxButtonState();
}

class _InboxButtonState extends State<InboxButton> {
  late Stream<int> _unread = widget.source.unreadCount(widget.riderId);

  @override
  void didUpdateWidget(InboxButton old) {
    super.didUpdateWidget(old);
    if (old.riderId != widget.riderId) {
      _unread = widget.source.unreadCount(widget.riderId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return StreamBuilder<int>(
      stream: _unread,
      builder: (context, snap) {
        final n = snap.data ?? 0;
        return IconButton(
          key: const ValueKey('open-inbox'),
          tooltip: n > 0 ? l.inboxOpenUnread(n) : l.inboxOpen,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => InboxScreen(
                riderId: widget.riderId,
                source: widget.source,
              ),
            ),
          ),
          icon: Badge(
            isLabelVisible: n > 0,
            label: Text(unreadBadgeText(n)),
            child: const Icon(DeliveryIcons.bell),
          ),
        );
      },
    );
  }
}
