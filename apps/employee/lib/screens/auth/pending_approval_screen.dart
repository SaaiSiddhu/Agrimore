import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../providers/auth_provider.dart';
import '../support/help_support_screen.dart';

/// Screen displayed when an associate's account is pending administrator review.
class EmployeePendingApprovalScreen extends StatelessWidget {
  const EmployeePendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SaTokens.pageBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: SaTokens.space24,
              vertical: SaTokens.space32,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Icon
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: SaTokens.warningBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        SaIcons.triangleAlert,
                        size: 40,
                        color: SaTokens.warningFg,
                      ),
                    ),
                  ),
                  const SizedBox(height: SaTokens.space24),

                  Text(
                    'Application Pending Approval',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: SaTokens.space8),
                  Text(
                    'Your Sales Associate registration has been submitted and is currently being reviewed by the AgriMore administration team.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: SaTokens.textSecondary,
                          height: 1.5,
                        ),
                  ),
                  const SizedBox(height: SaTokens.space32),

                  // "What happens next" card
                  Container(
                    padding: const EdgeInsets.all(SaTokens.space24),
                    decoration: BoxDecoration(
                      color: SaTokens.surface,
                      borderRadius: BorderRadius.circular(SaTokens.radiusCard),
                      border: Border.all(color: SaTokens.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'What happens next?',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: SaTokens.space16),
                        _buildStepRow(
                          context,
                          number: '1',
                          title: 'Verification',
                          subtitle:
                              'Our team verifies your associate details and jurisdiction.',
                        ),
                        const SizedBox(height: SaTokens.space16),
                        _buildStepRow(
                          context,
                          number: '2',
                          title: 'Activation',
                          subtitle:
                              'Once approved, your associate code becomes active immediately.',
                        ),
                        const SizedBox(height: SaTokens.space16),
                        _buildStepRow(
                          context,
                          number: '3',
                          title: 'Start Earning',
                          subtitle:
                              'Share your code with buyers and track commissions in this app.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: SaTokens.space32),

                  // Actions
                  SaLoadingButton(
                    text: 'Contact Support',
                    variant: SaButtonVariant.outlined,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const HelpSupportScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: SaTokens.space16),

                  SaLoadingButton(
                    text: 'Sign Out',
                    variant: SaButtonVariant.outlined,
                    onPressed: () {
                      context.read<EmployeeAuthProvider>().signOut();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow(
    BuildContext context, {
    required String number,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: SaTokens.primarySubtle,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              fontSize: SaTokens.fsCaption,
              fontWeight: FontWeight.w700,
              color: SaTokens.primary,
            ),
          ),
        ),
        const SizedBox(width: SaTokens.space16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: SaTokens.fsBody,
                  fontWeight: FontWeight.w600,
                  color: SaTokens.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: SaTokens.fsLabel,
                  color: SaTokens.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
