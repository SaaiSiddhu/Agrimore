import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../providers/auth_provider.dart';
import '../support/help_support_screen.dart';

/// Screen displayed when an associate's account has been suspended by an admin.
///
/// States plainly that the account is suspended and provides direct contact
/// options without fabricating reasons or server-side appeal flows.
class SuspendedScreen extends StatelessWidget {
  const SuspendedScreen({super.key});

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
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: SaTokens.errorBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        SaIcons.circleAlert,
                        size: 40,
                        color: SaTokens.errorFg,
                      ),
                    ),
                  ),
                  const SizedBox(height: SaTokens.space24),

                  Text(
                    'Account Suspended',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: SaTokens.space8),
                  Text(
                    'Your Sales Associate account has been suspended by an administrator. Attribution of new orders has been paused.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: SaTokens.textSecondary,
                          height: 1.5,
                        ),
                  ),
                  const SizedBox(height: SaTokens.space32),

                  // Contact Support Card
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
                          'Need Assistance?',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: SaTokens.space8),
                        Text(
                          'If you believe this suspension is in error, please contact the AgriMore associate operations desk:',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: SaTokens.textSecondary,
                              ),
                        ),
                        const SizedBox(height: SaTokens.space16),
                        _buildContactRow(
                          icon: SaIcons.mail,
                          label: 'Email Support',
                          value: AppConstants.supportEmail,
                        ),
                        const SizedBox(height: SaTokens.space8),
                        _buildContactRow(
                          icon: SaIcons.phone,
                          label: 'Phone Support',
                          value: AppConstants.supportPhone,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: SaTokens.space32),

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

  Widget _buildContactRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: SaTokens.primary),
        const SizedBox(width: SaTokens.space8),
        Expanded(
          child: Text(
            '$label: $value',
            style: const TextStyle(
              fontSize: SaTokens.fsBody,
              fontWeight: FontWeight.w600,
              color: SaTokens.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
