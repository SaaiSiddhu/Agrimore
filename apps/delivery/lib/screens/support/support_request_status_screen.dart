// lib/screens/support/support_request_status_screen.dart
//
// Phase DLVSUP1 -- the request-details/status screen (31.4 panel 4): a
// Submitted -> Seen -> Closed timeline, the outcome once closed, and a "New
// request" action. Reached right after submitting (pushReplacement) or, per
// DLVSUP2's own MySupportRequestsScreen and a support notification's own
// exact-ticket routing, from a persistent list or an inbox notice for any
// past ticket -- never only "right after submitting".
//
// DLVC4: a read failure (e.g. a cross-rider permission-denied listener
// error, surfaced when a stale/historical notification names a ticket this
// signed-in rider no longer owns) used to fall through to the SAME branch as
// a genuinely nonexistent ticket, showing a bare Text with a string borrowed
// from the unrelated identity-change flow. Folded into the same honest
// "unavailable" RequestStatusCard every sibling by-id screen already uses
// (DocumentSubmissionScreen, IncidentStatusScreen) -- their own established
// reasoning applies identically here: a permission-denied read and a
// genuinely-deleted ticket are not safely distinguishable to the rider.
import 'package:agrimore_ui/agrimore_ui.dart' show AgFormat;
import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../../support/rider_support.dart';
import '../profile/identity_change_screen.dart' show RequestStatusCard;

class SupportRequestStatusScreen extends StatelessWidget {
  const SupportRequestStatusScreen({
    super.key,
    required this.ticketId,
    this.backend,
  });
  final String ticketId;
  final RiderSupportBackend? backend;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final backend0 = backend ?? CallableRiderSupportBackend();
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(title: Text(l.supportStatusTitle)),
      body: StreamBuilder<SupportTicket?>(
        stream: backend0.ticket(ticketId),
        builder: (context, snap) {
          // hasData is false for a legitimately-null value (no such ticket),
          // not just before the first event -- check connectionState for
          // "still waiting", never hasData, or this never leaves the spinner.
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final ticket = snap.hasError ? null : snap.data;
          if (ticket == null) {
            return RequestStatusCard(
              icon: DeliveryIcons.close,
              title: l.supportStatusUnavailable,
              body: l.supportStatusUnavailableBody,
            );
          }
          return _Timeline(ticket: ticket);
        },
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.ticket});
  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    final seen = ticket.status != SupportTicketStatus.submitted;
    final closed = ticket.status == SupportTicketStatus.closed;
    return ListView(
      padding: const EdgeInsets.all(DeliverySpace.page),
      children: [
        Text(ticket.message, style: t.bodyMedium.copyWith(color: c.textPrimary)),
        const SizedBox(height: DeliverySpace.lg),
        _Step(
          done: true,
          title: l.supportStatusSubmitted,
          body: l.supportStatusSubmittedBody,
          at: ticket.createdAt,
        ),
        _Step(
          done: seen,
          title: l.supportStatusSeen,
          body: l.supportStatusSeenBody,
          at: ticket.seenAt,
        ),
        _Step(
          done: closed,
          title: l.supportStatusClosed,
          body: l.supportStatusClosedBody,
          at: ticket.closedAt,
          isLast: true,
        ),
        if (closed && (ticket.resolutionNote ?? '').isNotEmpty) ...[
          const SizedBox(height: DeliverySpace.md),
          Text(l.supportOutcomeLabel, style: t.labelMedium.copyWith(color: c.textSecondary)),
          const SizedBox(height: DeliverySpace.xxs),
          DeliveryCard(
            padding: const EdgeInsets.all(DeliverySpace.md),
            child: Text(ticket.resolutionNote!, style: t.bodyMedium.copyWith(color: c.textPrimary)),
          ),
        ],
        const SizedBox(height: DeliverySpace.xl),
        DeliveryButton.secondary(
          key: const ValueKey('support-new-request'),
          label: l.supportNewRequest,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.done,
    required this.title,
    required this.body,
    required this.at,
    this.isLast = false,
  });
  final bool done;
  final String title;
  final String body;
  final DateTime? at;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final dotColor = done ? c.brand : c.border;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
              ),
              if (!isLast)
                Expanded(child: Container(width: 2, color: c.border)),
            ],
          ),
          const SizedBox(width: DeliverySpace.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: DeliverySpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: t.titleSmall.copyWith(color: done ? c.textPrimary : c.textSecondary),
                  ),
                  if (done) ...[
                    Text(body, style: t.bodySmall.copyWith(color: c.textSecondary)),
                    if (at != null)
                      Text(
                        AgFormat.dateTime(at!),
                        style: t.bodySmall.copyWith(color: c.textSecondary),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
