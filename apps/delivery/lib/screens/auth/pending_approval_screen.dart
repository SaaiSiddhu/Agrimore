// lib/screens/auth/pending_approval_screen.dart
//
// Shown to a signed-in delivery partner who may not work: pending review,
// rejected, suspended or deactivated (Phase DLV-1B), with the admin's reason.
// Phase DLV-A2: Workspace + ARB; a pending or rejected rider can correct and
// resubmit the application (submitRiderApplication updates the same record);
// support contacts; sign-out; account deletion (deleteUserData's rider branch).
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../account/rider_account.dart';
import '../../account/support_card.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../profile/rider_profile_screen.dart' show accountFailureText;
import 'rider_registration_screen.dart';

/// Title, body and icon for a blocked status.
({String title, String body, IconData icon}) statusCopy(AppLocalizations l, RiderKycStatus s) => switch (s) {
      RiderKycStatus.rejected => (title: l.statusRejectedTitle, body: l.statusRejectedBody, icon: AgIcons.packageRejected),
      RiderKycStatus.suspended => (title: l.statusSuspendedTitle, body: l.statusSuspendedBody, icon: AgIcons.warning),
      RiderKycStatus.deactivated => (title: l.statusDeactivatedTitle, body: l.statusDeactivatedBody, icon: AgIcons.close),
      _ => (title: l.statusPendingTitle, body: l.statusPendingBody, icon: AgIcons.clock),
    };

/// Whether the rider may still change and resubmit the application.
bool canResubmit(RiderKycStatus s) => s == RiderKycStatus.pending || s == RiderKycStatus.rejected;

class DeliveryPendingApprovalScreen extends StatefulWidget {
  const DeliveryPendingApprovalScreen({super.key, this.backend});
  final RiderAccountBackend? backend;

  @override
  State<DeliveryPendingApprovalScreen> createState() => _DeliveryPendingApprovalScreenState();
}

class _DeliveryPendingApprovalScreenState extends State<DeliveryPendingApprovalScreen> {
  late final RiderAccountBackend _backend = widget.backend ?? CallableRiderAccountBackend();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // A partner can land here mid-shift (suspended while online). Stop the
    // location stream and go offline so dispatch stops offering them orders.
    // isOnline / lastStatusUpdate are on DLV-0's owner allowlist.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid = context.read<DeliveryAuthProvider>().user?.uid;
      final location = context.read<LocationProvider>();
      location.stopTracking();
      if (uid != null) location.setOnlineStatus(uid, false);
    });
  }

  Future<void> _resubmit() async {
    final uid = context.read<DeliveryAuthProvider>().user?.uid;
    if (uid == null) return;
    setState(() => _busy = true);
    Map<String, dynamic>? record;
    try {
      record = (await FirebaseFirestore.instance.collection('delivery_partners').doc(uid).get()).data();
    } catch (e) {
      debugPrint('Application record not read: $e');
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => RiderRegistrationScreen(initial: record)),
    );
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final ok = await wsConfirm(context,
        title: l.deleteConfirmTitle, message: l.deleteConfirmBody, confirmLabel: l.deleteConfirm, cancelLabel: l.cancel,
        destructive: true);
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await _backend.deleteAccount();
      if (!mounted) return;
      final auth = context.read<DeliveryAuthProvider>();
      WsToast.show(context, l.deleteDone);
      await auth.signOut();
    } on AccountActionException catch (e) {
      if (mounted) WsToast.show(context, accountFailureText(l, e.failure), tone: WsToastTone.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.ws;
    final text = Theme.of(context).textTheme;
    final auth = context.watch<DeliveryAuthProvider>();
    final status = auth.kycStatus ?? RiderKycStatus.pending;
    final copy = statusCopy(l, status);
    final reason = auth.statusReason;
    final severe = status == RiderKycStatus.rejected || status == RiderKycStatus.suspended;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(WsSpace.page),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: WsSize.formMaxWidth),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Icon(copy.icon, size: WsIconSize.empty, color: severe ? t.errorFg : t.textTertiary),
                const SizedBox(height: WsSpace.s16),
                Text(copy.title, textAlign: TextAlign.center, style: text.headlineSmall),
                const SizedBox(height: WsSpace.s8),
                Text(copy.body, textAlign: TextAlign.center, style: text.bodyLarge?.copyWith(color: t.textSecondary)),
                if (reason != null) ...[
                  const SizedBox(height: WsSpace.s16),
                  Container(
                    padding: const EdgeInsets.all(WsSpace.s12),
                    decoration: BoxDecoration(color: t.surfaceSunken, borderRadius: BorderRadius.circular(WsRadius.card)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.statusReason, style: text.labelMedium?.copyWith(color: t.textSecondary)),
                      const SizedBox(height: WsSpace.s4),
                      Text(reason, style: text.bodyMedium),
                    ]),
                  ),
                ],
                const SizedBox(height: WsSpace.s24),
                if (canResubmit(status)) ...[
                  FilledButton.icon(
                    key: const ValueKey('resubmit'),
                    onPressed: _busy ? null : _resubmit,
                    icon: const Icon(AgIcons.edit),
                    label: Text(status == RiderKycStatus.rejected ? l.statusUpdateApplication : l.statusEditApplication),
                  ),
                  const SizedBox(height: WsSpace.s16),
                ],
                const SupportContactButtons(),
                const SizedBox(height: WsSpace.s16),
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : () => riderSignOut(context),
                  icon: const Icon(AgIcons.logOut),
                  label: Text(l.actionSignOut),
                ),
                const SizedBox(height: WsSpace.s8),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: t.errorFg),
                  onPressed: _busy ? null : _delete,
                  child: Text(l.deleteAccount),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
