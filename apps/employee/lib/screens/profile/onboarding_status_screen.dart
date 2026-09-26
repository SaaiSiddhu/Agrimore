import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../utils/sa_formatters.dart';

/// Screen explaining the associate's onboarding fee status and attribution rules.
///
/// Reads directly from `employees/{uid}` without mutating state.
class OnboardingStatusScreen extends StatelessWidget {
  final String? employeeUid;
  final Stream<DocumentSnapshot<Map<String, dynamic>>>? employeeStream;

  const OnboardingStatusScreen({
    super.key,
    this.employeeUid,
    this.employeeStream,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.saTokens;
    final uid = employeeUid ?? FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        backgroundColor: tokens.pageBackground,
        body: Center(
          child: Text(
            'Sign in to view onboarding status',
            style: TextStyle(color: tokens.textSecondary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: tokens.pageBackground,
      appBar: AppBar(
        title: const Text('Onboarding Status'),
        leading: IconButton(
          icon: const Icon(SaIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: employeeStream ??
            FirebaseFirestore.instance
                .collection('employees')
                .doc(uid)
                .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(SaTokens.space24),
                child: Text(
                  'Error loading status: ${snap.error}',
                  style: TextStyle(color: tokens.errorFg),
                ),
              ),
            );
          }
          if (!snap.hasData) {
            return ListView(
              padding: const EdgeInsets.all(SaTokens.space24),
              children: [
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: tokens.surface,
                    borderRadius: BorderRadius.circular(SaTokens.radiusCard),
                    border: Border.all(color: tokens.divider),
                  ),
                ),
              ],
            );
          }

          final doc = snap.data!;
          if (!doc.exists || doc.data() == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(SaTokens.space24),
                child: Text(
                  'Associate record not found',
                  style: TextStyle(color: tokens.textSecondary),
                ),
              ),
            );
          }

          final employee = EmployeeModel.fromMap(doc.data()!, doc.id);
          final isCleared = employee.hasClearedOnboardingGate;
          final isWaived = employee.onboardingWaived;
          final isPaid = employee.onboardingPaid;

          return ListView(
            padding: const EdgeInsets.all(SaTokens.space24),
            children: [
              // Status Hero Card
              _buildStatusCard(context, tokens, employee, isCleared, isWaived, isPaid),
              const SizedBox(height: SaTokens.space24),

              // Attribution Rules Explanation
              Text(
                'Attribution & Commission Rules',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: tokens.textPrimary,
                    ),
              ),
              const SizedBox(height: SaTokens.space12),

              _buildRuleCard(
                context,
                tokens: tokens,
                title: 'B2B Wholesale Orders',
                statusLabel: 'Active & Unrestricted',
                isUnlocked: true,
                description:
                    'Your associate code attributes all wholesale and B2B orders immediately. Commission is earned regardless of onboarding fee status.',
              ),
              const SizedBox(height: SaTokens.space12),

              _buildRuleCard(
                context,
                tokens: tokens,
                title: 'Retail (B2C) Orders',
                statusLabel: isCleared ? 'Active & Unrestricted' : 'Locked — Fee Required',
                isUnlocked: isCleared,
                description: isCleared
                    ? 'Retail buyer orders using your code are actively attributed and earn commission upon delivery.'
                    : 'Retail attribution is paused until the ₹500 onboarding fee is cleared. Self-applied associates pay this once to unlock retail commission.',
              ),
              const SizedBox(height: SaTokens.space24),

              // How to complete onboarding (if not cleared)
              if (!isCleared) ...[
                const SaInfoBanner(
                  title: 'How to pay the onboarding fee',
                  message:
                      'Open the AgriMore customer app where you submitted your associate application. Under Profile, tap "Become a Sales Associate" — you will be taken straight to the payment step to complete your ₹500 fee.',
                  variant: SaBannerVariant.info,
                ),
                const SizedBox(height: SaTokens.space24),
              ],

              // Terms & Conditions notice
              Container(
                padding: const EdgeInsets.all(SaTokens.space16),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(SaTokens.radiusCard),
                  border: Border.all(color: tokens.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Programme Integrity',
                      style: TextStyle(
                        fontSize: SaTokens.fsBody,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: SaTokens.space4),
                    Text(
                      'The one-time fee covers KYC identity verification and onboarding setup for self-applied associates. Associate status is non-transferable and subject to AgriMore terms of service.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: tokens.textSecondary,
                            height: 1.5,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(
    BuildContext context,
    SalesAssociateTokens tokens,
    EmployeeModel employee,
    bool isCleared,
    bool isWaived,
    bool isPaid,
  ) {
    final statusTitle = isWaived
        ? 'Fee Waived (Admin Assigned)'
        : isPaid
            ? 'Fee Paid (₹500)'
            : 'Payment Pending (₹500)';

    final statusSubtitle = isWaived
        ? 'Your onboarding fee was waived by an administrator as an enterprise associate.'
        : isPaid
            ? 'Your one-time onboarding fee has been verified. All attribution channels are active.'
            : 'Complete the ₹500 fee in the customer app to activate retail attribution.';

    return Container(
      padding: const EdgeInsets.all(SaTokens.space24),
      decoration: BoxDecoration(
        color: isCleared ? tokens.successBg : tokens.warningBg,
        borderRadius: BorderRadius.circular(SaTokens.radiusCard),
        border: Border.all(
          color: isCleared ? tokens.successFg : tokens.warningFg,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCleared ? SaIcons.circleCheck : SaIcons.triangleAlert,
                color: isCleared ? tokens.successFg : tokens.warningFg,
                size: 24,
              ),
              const SizedBox(width: SaTokens.space12),
              Expanded(
                child: Text(
                  statusTitle,
                  style: TextStyle(
                    fontSize: SaTokens.fsSectionHeading,
                    fontWeight: FontWeight.w700,
                    color: isCleared ? tokens.successFg : tokens.warningFg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: SaTokens.space12),
          Text(
            statusSubtitle,
            style: TextStyle(
              fontSize: SaTokens.fsBody,
              color: isCleared
                  ? tokens.successFg.withValues(alpha: 0.9)
                  : tokens.warningFg.withValues(alpha: 0.9),
              height: 1.4,
            ),
          ),
          if (employee.onboardingPaidAt != null) ...[
            const SizedBox(height: SaTokens.space12),
            Text(
              'Cleared on ${SaFormatters.formatDate(employee.onboardingPaidAt!)}',
              style: TextStyle(
                fontSize: SaTokens.fsCaption,
                fontWeight: FontWeight.w600,
                color: isCleared ? tokens.successFg : tokens.warningFg,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRuleCard(
    BuildContext context, {
    required SalesAssociateTokens tokens,
    required String title,
    required String statusLabel,
    required bool isUnlocked,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(SaTokens.space16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(SaTokens.radiusCard),
        border: Border.all(color: tokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(1.0);
              final isStacked = constraints.maxWidth < 320 || textScale > 1.15;
              final badgeWidget = Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isUnlocked ? tokens.successBg : tokens.warningBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isUnlocked ? tokens.successFg : tokens.warningFg,
                  ),
                ),
              );

              if (isStacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: SaTokens.fsBody,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: SaTokens.space8),
                    badgeWidget,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: SaTokens.fsBody,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: SaTokens.space8),
                  badgeWidget,
                ],
              );
            },
          ),
          const SizedBox(height: SaTokens.space8),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: tokens.textSecondary,
                  height: 1.45,
                ),
          ),
        ],
      ),
    );
  }
}
