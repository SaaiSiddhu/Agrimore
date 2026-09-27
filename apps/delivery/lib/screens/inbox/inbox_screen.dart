// lib/screens/inbox/inbox_screen.dart
//
// Phase DLV-N1 / Phase 30 — the rider's inbox (lib/inbox/rider_inbox.dart).
// Phase DLVI1 — tapping a notice re-reads its real target fresh (never
// trusts the payload as authorization) and opens it: a delivery (active or
// historical), a statement, or the payout-details section of Earnings.
import 'package:agrimore_core/agrimore_core.dart'
    show DeliveryTaskStatus, OrderModel;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../app/delivery_tab.dart';
import '../../data/order_timeline.dart';
import '../../data/rider_history.dart';
import '../../design_system/design_system.dart';
import '../../inbox/rider_inbox.dart';
import '../../l10n/app_localizations.dart';
import '../../money/rider_money.dart';
import '../history/rider_history_screen.dart';
import '../money/money_screen.dart';
import '../money/statement_screen.dart';
import '../orders/active_order_screen.dart';
import '../profile/identity_change_screen.dart';
import '../support/support_request_status_screen.dart';

/// Fetches one order fresh (never trusts a notice's own payload): the
/// security rule (`deliveryPartnerId == request.auth.uid`, among others)
/// is what actually authorizes it, not this call succeeding on its own.
typedef OrderLoader = Future<OrderModel?> Function(String orderId);

/// DLVI3: a notice's own icon, by its real `RiderNoticeType` (server-defined
/// in `functions/src/delivery/riderNotices.ts`) rather than only read/unread
/// — every case here names an actual, currently-written type, not an
/// invented one. Falls back to the pre-existing read/unread pair for a type
/// this client doesn't recognise (empty, or older than this mapping).
IconData noticeIcon(String type, {required bool unread}) => switch (type) {
      'delivery_assigned' => DeliveryIcons.package,
      'delivery_unassigned' => DeliveryIcons.packageX,
      'delivery_problem_resolved' => DeliveryIcons.documentWarning,
      'statement_ready' => DeliveryIcons.statement,
      'payout_sent' => DeliveryIcons.rupee,
      'bank_change_approved' || 'bank_change_rejected' => DeliveryIcons.bank,
      'identity_change_approved' || 'identity_change_rejected' => DeliveryIcons.idCard,
      'document_review_approved' || 'document_review_rejected' => DeliveryIcons.document,
      'incident_acknowledged' || 'incident_resolved' => DeliveryIcons.shieldCheck,
      'support_request_seen' || 'support_request_closed' => DeliveryIcons.support,
      'rider_offline' => DeliveryIcons.offline,
      _ => unread ? DeliveryIcons.bell : DeliveryIcons.checkCircle,
    };

/// Null for "not there" (deleted, or no longer this rider's — the exact
/// `delivery_unassigned` case, enforced by the security rule itself, not by
/// this code); anything else rethrown, matching the shape of
/// [RiderMoneyService.earningFor]/[RiderMoneyService.payoutById].
Future<OrderModel?> _firestoreOrder(String orderId) async {
  try {
    final doc = await FirebaseFirestore.instance.collection('orders').doc(orderId).get();
    final data = doc.data();
    return data == null ? null : historyOrder(orderId, data);
  } on FirebaseException catch (e) {
    if (e.code == 'permission-denied' || e.code == 'not-found') return null;
    rethrow;
  }
}

class InboxScreen extends StatefulWidget {
  const InboxScreen({
    super.key,
    required this.riderId,
    required this.source,
    this.onOpenTab,
    this.loadOrder,
    this.loadPayout,
  });
  final String riderId;
  final RiderInboxSource source;

  /// DLVNAV1: when this screen runs as the shell's Inbox tab, a
  /// payout-details notice switches to the Earnings tab through this
  /// instead of pushing a duplicate tab-root route. Null when not inside a
  /// shell (standalone, tests): falls back to the original push behaviour
  /// unchanged.
  final void Function(DeliveryTab tab)? onOpenTab;

  /// DLVI1: injectable for tests; defaults to a real orders/{orderId} read.
  final OrderLoader? loadOrder;

  /// DLVI1: injectable for tests; defaults to rider_payouts/{statementId}
  /// (the same PayoutLoader shape DLVH3 already established).
  final PayoutLoader? loadPayout;

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  late final Stream<List<RiderNotice>> _latest =
      widget.source.latest(widget.riderId);
  bool _markingAll = false;

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

  /// Unlike [_markRead], reaches every unread notice server-side, not just
  /// whichever page [_latest] last emitted (capped at [kInboxSize]) — a
  /// rider with more notices than that would otherwise have older unread
  /// ones this button could never actually clear. Guards against duplicate
  /// taps while a request is already in flight, matching the mockup's own
  /// disabled/loading button state; shows a success toast only after the
  /// server has actually confirmed, never before.
  Future<void> _markAllRead() async {
    if (_markingAll) return;
    setState(() => _markingAll = true);
    final l = AppLocalizations.of(context);
    var failed = false;
    try {
      await widget.source.markAllRead(widget.riderId);
    } catch (e) {
      debugPrint('Inbox mark all read: $e');
      failed = true;
    }
    if (!mounted) return;
    setState(() => _markingAll = false);
    showDeliveryToast(
      context,
      message: failed ? l.inboxMarkReadFailed : l.inboxMarkAllReadSuccess,
      tone: failed ? DeliveryBannerTone.danger : DeliveryBannerTone.success,
    );
  }

  void _open(RiderNotice n) {
    if (n.unread) _markRead([n.id]);
    switch (n.target) {
      case NoticeTarget.payoutDetails:
        _openPayoutDetails();
      case NoticeTarget.statement:
        _openStatement(n.payoutId!);
      case NoticeTarget.delivery:
        _openDelivery(n.orderId!);
      case NoticeTarget.identityRequest:
        _openIdentityRequest(n);
      case NoticeTarget.supportTicket:
        _openSupportTicket(n.ticketId!);
      case NoticeTarget.none:
        break;
    }
  }

  /// DLVSUP2: routes to the exact ticket the notice named, reusing the same
  /// status screen the submit flow itself pushes to — never "whichever
  /// ticket is latest".
  void _openSupportTicket(String ticketId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SupportRequestStatusScreen(ticketId: ticketId),
      ),
    );
  }

  /// DLVID3: routes to the EXACT request the notice named (never "whichever
  /// is latest", which can silently be a different, newer request of the
  /// same type submitted since the notice arrived), with the correct
  /// changeType so a vehicle-change notice never opens the name-change form.
  void _openIdentityRequest(RiderNotice n) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => IdentityChangeScreen(
          riderId: widget.riderId,
          changeType: n.changeType,
          requestId: n.requestId,
        ),
      ),
    );
  }

  void _openPayoutDetails() {
    final go = widget.onOpenTab;
    if (go != null) {
      go(DeliveryTab.earnings);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MoneyScreen(riderId: widget.riderId),
      ),
    );
  }

  /// Deferred to first invocation (never constructed until actually called):
  /// bare construction touches `FirebaseFirestore.instance`, which must not
  /// happen on a code path a test means to short-circuit with its own
  /// `widget.loadPayout` / `widget.loadOrder` override.
  Future<RiderEarning?> _defaultLoadEarning(String id) async =>
      RiderMoneyService(widget.riderId).earningFor(id);

  Future<RiderPayout?> _defaultLoadPayout(String id) async =>
      RiderMoneyService(widget.riderId).payoutById(id);

  Future<StatementPage> _loadStatementLines(
    String statementId,
    DocumentSnapshot<Map<String, dynamic>>? after,
  ) async =>
      RiderMoneyService(widget.riderId).statementLines(statementId, after: after);

  Future<void> _openStatement(String payoutId) async {
    final l = AppLocalizations.of(context);
    RiderPayout? payout;
    var failed = false;
    try {
      payout = await (widget.loadPayout ?? _defaultLoadPayout)(payoutId);
    } catch (e) {
      failed = true;
    }
    if (!mounted) return;
    if (failed) {
      showDeliveryToast(
        context,
        message: l.historyDetailStatementNetworkError,
        tone: DeliveryBannerTone.danger,
      );
      return;
    }
    if (payout == null) {
      showDeliveryToast(
        context,
        message: l.historyDetailStatementUnavailable,
        tone: DeliveryBannerTone.danger,
      );
      return;
    }
    final resolved = payout;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StatementScreen(
          payout: resolved,
          load: (after) => _loadStatementLines(resolved.id, after),
        ),
      ),
    );
  }

  Future<void> _openDelivery(String orderId) async {
    final l = AppLocalizations.of(context);
    OrderModel? order;
    var failed = false;
    try {
      order = await (widget.loadOrder ?? _firestoreOrder)(orderId);
    } catch (e) {
      failed = true;
    }
    if (!mounted) return;
    if (failed) {
      showDeliveryToast(
        context,
        message: l.inboxDeliveryNetworkError,
        tone: DeliveryBannerTone.danger,
      );
      return;
    }
    if (order == null) {
      showDeliveryToast(
        context,
        message: l.inboxDeliveryUnavailable,
        tone: DeliveryBannerTone.danger,
      );
      return;
    }
    final resolved = order;
    final status = DeliveryTaskStatus.fromOrderStatus(
      orderStatus: resolved.orderStatus,
      status: null,
      hasPartner: true,
    );
    if (status != null && status.isTerminal) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text(l.historyDetailTitle)),
            body: HistoryDetail(
              order: resolved,
              loadEarning: _defaultLoadEarning,
              loadTimeline: firestoreOrderTimeline,
              loadPayout: widget.loadPayout ?? _defaultLoadPayout,
            ),
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ActiveOrderScreen(order: resolved),
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
            onPressed: _markingAll ? null : _markAllRead,
            child: _markingAll
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: DeliveryIconSize.sm,
                        height: DeliveryIconSize.sm,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: DeliverySpace.xs),
                      Text(l.inboxMarkingAllRead),
                    ],
                  )
                : Text(l.inboxMarkAllRead),
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
          final list = snap.data!;
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
                  noticeIcon(n.type, unread: n.unread),
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
                trailing: n.target != NoticeTarget.none
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
    this.onOpen,
  });
  final String riderId;
  final RiderInboxSource source;

  /// DLVNAV1: overrides the default push-to-InboxScreen tap behaviour (used
  /// when this button sits inside the shell and tapping it should switch
  /// to the Inbox tab instead). Null keeps the original push.
  final VoidCallback? onOpen;

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
          onPressed: widget.onOpen ??
              () => Navigator.of(context).push(
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
