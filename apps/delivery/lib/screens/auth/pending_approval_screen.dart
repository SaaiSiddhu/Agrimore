import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';

/// Shown to a signed-in delivery partner who may not work: pending review,
/// rejected, suspended or deactivated (Phase DLV-1B — previously every one of
/// those read as "Pending Approval", with no reason).
class DeliveryPendingApprovalScreen extends StatefulWidget {
  const DeliveryPendingApprovalScreen({super.key});

  @override
  State<DeliveryPendingApprovalScreen> createState() =>
      _DeliveryPendingApprovalScreenState();
}

class _DeliveryPendingApprovalScreenState
    extends State<DeliveryPendingApprovalScreen> {
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final auth = context.watch<DeliveryAuthProvider>();
    final status = auth.kycStatus ?? RiderKycStatus.pending;
    final reason = auth.statusReason;

    final (IconData icon, Color tone, String title, String body) =
        switch (status) {
      RiderKycStatus.rejected => (
          Icons.assignment_late_rounded,
          colorScheme.error,
          'Application not approved',
          'Your delivery partner application was not approved.',
        ),
      RiderKycStatus.suspended => (
          Icons.block_rounded,
          colorScheme.error,
          'Account suspended',
          'You cannot go online or accept orders until an admin reinstates your account.',
        ),
      RiderKycStatus.deactivated => (
          Icons.person_off_rounded,
          colorScheme.outline,
          'Account deactivated',
          'This delivery partner account is no longer active.',
        ),
      _ => (
          Icons.delivery_dining_rounded,
          colorScheme.primary,
          'Pending approval',
          'Your delivery partner account is under review by the admin team. '
              'Once approved, you can start accepting delivery orders.',
        ),
    };
    final showSupport =
        status != RiderKycStatus.pending && status != RiderKycStatus.approved;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 56, color: tone),
                ),
                const SizedBox(height: 32),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                if (reason != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reason',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          reason,
                          style: TextStyle(
                            fontSize: 15,
                            color: colorScheme.onSurface,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (showSupport) ...[
                  const SizedBox(height: 20),
                  Text(
                    'If you think this is a mistake, contact Agrimore support at '
                    '${AppConstants.supportPhone} or ${AppConstants.supportEmail}.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 48),
                FilledButton.icon(
                  onPressed: () {
                    context.read<DeliveryAuthProvider>().signOut();
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign Out'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    backgroundColor: colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
