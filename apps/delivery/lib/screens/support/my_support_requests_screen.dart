// lib/screens/support/my_support_requests_screen.dart
//
// Phase DLVSUP2 (brief §7.2) -- a persistent way to reach an existing
// support ticket after leaving the screen or restarting the app. DLVSUP1
// built the submit-and-track flow but only ever reached the status screen
// via a pushReplacement right after submitting; there was no list to come
// back to it from. Reuses SupportRequestStatusScreen unchanged -- this
// screen is only the list in front of it.
import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../../support/rider_support.dart';
import 'support_request_status_screen.dart';

class MySupportRequestsScreen extends StatefulWidget {
  const MySupportRequestsScreen({
    super.key,
    required this.riderId,
    this.backend,
  });
  final String riderId;

  /// Injectable for tests; defaults to the real callable-backed service.
  final RiderSupportBackend? backend;

  @override
  State<MySupportRequestsScreen> createState() => _MySupportRequestsScreenState();
}

class _MySupportRequestsScreenState extends State<MySupportRequestsScreen> {
  late final RiderSupportBackend _backend = widget.backend ?? CallableRiderSupportBackend();
  late Stream<List<SupportTicket>> _tickets = _backend.tickets(widget.riderId);

  void _retry() => setState(() => _tickets = _backend.tickets(widget.riderId));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: Text(l.mySupportRequestsTitle)),
      body: StreamBuilder<List<SupportTicket>>(
        stream: _tickets,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _MessageState(
              icon: DeliveryIcons.cloudOff,
              title: l.mySupportRequestsNetworkError,
              actionLabel: l.actionRetry,
              onAction: _retry,
            );
          }
          final tickets = snap.data ?? const [];
          if (tickets.isEmpty) {
            return _MessageState(
              icon: DeliveryIcons.support,
              title: l.mySupportRequestsEmpty,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(DeliverySpace.page),
            itemCount: tickets.length,
            separatorBuilder: (_, __) => const SizedBox(height: DeliverySpace.sm),
            itemBuilder: (context, i) => _TicketRow(
              ticket: tickets[i],
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SupportRequestStatusScreen(
                    ticketId: tickets[i].id,
                    backend: widget.backend,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TicketRow extends StatelessWidget {
  const _TicketRow({required this.ticket, required this.onTap});
  final SupportTicket ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    final (tone, statusLabel) = switch (ticket.status) {
      SupportTicketStatus.submitted => (DeliveryTone.neutral, l.supportStatusSubmitted),
      SupportTicketStatus.seen => (DeliveryTone.brand, l.supportStatusSeen),
      SupportTicketStatus.closed => (DeliveryTone.success, l.supportStatusClosed),
    };
    return DeliveryCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: DeliverySpace.md, vertical: DeliverySpace.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  supportCategoryLabel(l, ticket.category),
                  style: t.titleSmall.copyWith(color: c.textPrimary),
                ),
                const SizedBox(height: DeliverySpace.xxs),
                Text(
                  ticket.message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodySmall.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: DeliverySpace.sm),
          DeliveryBadge(label: statusLabel, tone: tone),
          const SizedBox(width: DeliverySpace.xs),
          Icon(DeliveryIcons.chevronRight, size: DeliveryIconSize.md, color: c.textSecondary),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DeliverySpace.page),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: DeliveryIconSize.xl, color: c.textSecondary),
            const SizedBox(height: DeliverySpace.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: t.bodyMedium.copyWith(color: c.textSecondary),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: DeliverySpace.lg),
              DeliveryButton.secondary(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}
