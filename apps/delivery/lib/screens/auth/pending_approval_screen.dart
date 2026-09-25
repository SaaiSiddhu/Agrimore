// lib/screens/auth/pending_approval_screen.dart
//
// Shown to a signed-in delivery partner who may not work: pending review,
// rejected, suspended or deactivated (Phase DLV-1B / Phase 17), with the
// admin's reason. A pending or rejected rider can correct and resubmit the
// application (submitRiderApplication updates the same record); support
// contacts; sign-out; account deletion.
import 'package:agrimore_core/agrimore_core.dart' show RiderKycStatus;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../account/rider_account.dart';
import '../../account/support_card.dart';
import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../profile/rider_profile_screen.dart' show accountFailureText;
import 'rider_registration_screen.dart';

/// Title, body and icon for a blocked status.
({String title, String body, IconData icon}) statusCopy(
  AppLocalizations l,
  RiderKycStatus s,
) =>
    switch (s) {
      RiderKycStatus.rejected => (
          title: l.statusRejectedTitle,
          body: l.statusRejectedBody,
          icon: DeliveryIcons.packageX,
        ),
      RiderKycStatus.suspended => (
          title: l.statusSuspendedTitle,
          body: l.statusSuspendedBody,
          icon: DeliveryIcons.warning,
        ),
      RiderKycStatus.deactivated => (
          title: l.statusDeactivatedTitle,
          body: l.statusDeactivatedBody,
          icon: DeliveryIcons.close,
        ),
      _ => (
          title: l.statusPendingTitle,
          body: l.statusPendingBody,
          icon: DeliveryIcons.clock,
        ),
    };

/// Whether the rider may still change and resubmit the application.
bool canResubmit(RiderKycStatus s) =>
    s == RiderKycStatus.pending || s == RiderKycStatus.rejected;

class DeliveryPendingApprovalScreen extends StatefulWidget {
  const DeliveryPendingApprovalScreen({super.key, this.backend});
  final RiderAccountBackend? backend;

  @override
  State<DeliveryPendingApprovalScreen> createState() =>
      _DeliveryPendingApprovalScreenState();
}

class _DeliveryPendingApprovalScreenState
    extends State<DeliveryPendingApprovalScreen> {
  late final RiderAccountBackend _backend =
      widget.backend ?? CallableRiderAccountBackend();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // A partner can land here mid-shift (suspended while online). Stop the
    // location stream and go offline so dispatch stops offering them orders.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid = context.read<DeliveryAuthProvider>().user?.uid;
      final location = context.read<LocationProvider?>();
      location?.stopTracking();
      if (uid != null) location?.setOnlineStatus(uid, false);
    });
  }

  Future<void> _resubmit() async {
    final uid = context.read<DeliveryAuthProvider>().user?.uid;
    if (uid == null) return;
    setState(() => _busy = true);
    Map<String, dynamic>? record;
    try {
      record = (await FirebaseFirestore.instance
              .collection('delivery_partners')
              .doc(uid)
              .get())
          .data();
    } catch (e) {
      debugPrint('Application record not read: $e');
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RiderRegistrationScreen(initial: record),
      ),
    );
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final ok = await showDeliveryConfirmDialog(
      context: context,
      title: l.deleteConfirmTitle,
      body: l.deleteConfirmBody,
      confirmLabel: l.deleteConfirm,
      cancelLabel: l.cancel,
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await _backend.deleteAccount();
      if (!mounted) return;
      final auth = context.read<DeliveryAuthProvider>();
      showDeliveryToast(context, message: l.deleteDone);
      await auth.signOut();
    } on AccountActionException catch (e) {
      if (mounted) {
        showDeliveryToast(
          context,
          message: accountFailureText(l, e.failure),
          tone: DeliveryBannerTone.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    final auth = context.watch<DeliveryAuthProvider>();
    final status = auth.kycStatus ?? RiderKycStatus.pending;
    final copy = statusCopy(l, status);
    final reason = auth.statusReason;
    final severe = status == RiderKycStatus.rejected ||
        status == RiderKycStatus.suspended;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(DeliverySpace.page),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: DeliverySize.formMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DeliveryCard(
                    padding: const EdgeInsets.all(DeliverySpace.xxl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: DeliveryIllustration(
                            kind: severe
                                ? DeliveryIllustrationKind.kycRejected
                                : DeliveryIllustrationKind.kycReview,
                            size: DeliverySize.illustration,
                          ),
                        ),
                        const SizedBox(height: DeliverySpace.lg),
                        Center(
                          child: DeliveryBadge(
                            label: switch (status) {
                              RiderKycStatus.rejected =>
                                l.kycBadgeActionRequired,
                              RiderKycStatus.suspended ||
                              RiderKycStatus.deactivated =>
                                l.kycBadgeSuspended,
                              _ => l.kycBadgeUnderReview,
                            },
                            tone: severe
                                ? DeliveryBadgeTone.danger
                                : DeliveryBadgeTone.warning,
                            icon: copy.icon,
                          ),
                        ),
                        const SizedBox(height: DeliverySpace.md),
                        Text(
                          copy.title,
                          textAlign: TextAlign.center,
                          style: t.headlineSmall.copyWith(color: c.textPrimary),
                        ),
                        const SizedBox(height: DeliverySpace.sm),
                        Text(
                          copy.body,
                          textAlign: TextAlign.center,
                          style: t.bodyLarge.copyWith(color: c.textSecondary),
                        ),
                        if (reason != null && reason.isNotEmpty) ...[
                          const SizedBox(height: DeliverySpace.lg),
                          DeliveryBanner(
                            tone: severe
                                ? DeliveryBannerTone.danger
                                : DeliveryBannerTone.warning,
                            title: l.statusReason,
                            body: reason,
                          ),
                        ],
                        if (canResubmit(status)) ...[
                          const SizedBox(height: DeliverySpace.xxl),
                          DeliveryButton.primary(
                            key: const ValueKey('resubmit'),
                            label: status == RiderKycStatus.rejected
                                ? l.statusUpdateApplication
                                : l.statusEditApplication,
                            icon: DeliveryIcons.edit,
                            isLoading: _busy,
                            onPressed: _busy ? null : _resubmit,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: DeliverySpace.lg),
                  DeliveryCard(
                    padding: const EdgeInsets.all(DeliverySpace.lg),
                    child: const SupportContactButtons(),
                  ),
                  const SizedBox(height: DeliverySpace.lg),
                  DeliveryButton.secondary(
                    label: l.actionSignOut,
                    icon: DeliveryIcons.logout,
                    onPressed: _busy ? null : () => riderSignOut(context),
                  ),
                  const SizedBox(height: DeliverySpace.sm),
                  DeliveryButton.ghost(
                    label: l.deleteAccount,
                    icon: DeliveryIcons.delete,
                    onPressed: _busy ? null : _delete,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
