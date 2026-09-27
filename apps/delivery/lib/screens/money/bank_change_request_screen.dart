// lib/screens/money/bank_change_request_screen.dart
//
// Phase DLVBANK1 — opened from a bank-change notification, pinned to the
// EXACT historical request it named (never "whichever is latest", which can
// silently be a different, newer request submitted since the notification
// arrived — the same problem DLVID3 already fixed for identity-change
// requests; this mirrors that screen's own state shape).
import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../../money/rider_money.dart';
import '../profile/identity_change_screen.dart' show RequestStatusCard;
import 'money_screen.dart' show BankChangeForm;

class BankChangeRequestScreen extends StatefulWidget {
  const BankChangeRequestScreen({
    super.key,
    required this.riderId,
    required this.requestId,
    this.backend,
  });
  final String riderId;
  final String requestId;

  /// Injectable for tests; defaults to a real Firestore-backed read.
  final Stream<BankChangeRequest?> Function(String requestId)? backend;

  @override
  State<BankChangeRequestScreen> createState() => _BankChangeRequestScreenState();
}

class _BankChangeRequestScreenState extends State<BankChangeRequestScreen> {
  late final Stream<BankChangeRequest?> _request =
      (widget.backend ?? _defaultRequestById)(widget.requestId);

  Stream<BankChangeRequest?> _defaultRequestById(String requestId) =>
      RiderMoneyService(widget.riderId).bankChangeRequestById(requestId);

  Future<void> _correct() async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => const BankChangeForm(),
    );
    // A fresh request from here creates a NEW, separate request this
    // screen's own by-id stream would never see (it stays pinned to the
    // old, now-superseded one) -- pop rather than keep showing it, matching
    // IdentityChangeScreen's own by-id resubmit behaviour.
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(title: Text(l.bankChangeRequestTitle)),
      body: StreamBuilder<BankChangeRequest?>(
        stream: _request,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final r = snap.data;
          if (r == null) {
            // Deleted, or no longer this rider's (enforced by the security
            // rule itself, not by this check).
            return RequestStatusCard(
              icon: DeliveryIcons.close,
              title: l.bankChangeRequestNotFoundTitle,
              body: l.bankChangeRequestNotFoundBody,
            );
          }
          return switch (r.status) {
            'approved' => RequestStatusCard(
                icon: DeliveryIcons.checkCircle,
                title: l.bankChangeRequestApprovedTitle,
                body: l.bankChangeRequestApprovedBody,
              ),
            'rejected' => RequestStatusCard(
                icon: DeliveryIcons.close,
                title: l.bankChangeRequestRejectedTitle,
                body: (r.rejectionReason ?? '').isEmpty
                    ? l.bankChangeRejectedNoReason
                    : l.bankChangeRejected(r.rejectionReason!),
                action: DeliveryButton.primary(
                  key: const ValueKey('bank-change-correct'),
                  label: l.bankChangeRequestCorrect,
                  onPressed: _correct,
                ),
              ),
            _ => RequestStatusCard(
                icon: DeliveryIcons.clock,
                title: l.bankChangeRequestPendingTitle,
                body: l.bankChangeReviewing,
              ),
          };
        },
      ),
    );
  }
}
