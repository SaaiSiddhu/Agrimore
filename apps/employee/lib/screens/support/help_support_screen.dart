import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

/// Comprehensive Help & Support screen for Sales Associates.
///
/// Grounded strictly in configured support channels ([AppConstants.supportEmail]
/// and [AppConstants.supportPhone]) without fabricating fictitious endpoints.
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SaTokens.pageBackground,
      appBar: AppBar(
        title: const Text('Help & Support'),
        leading: IconButton(
          icon: const Icon(SaIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(SaTokens.space24),
        children: [
          Text(
            'How can we help you?',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: SaTokens.space4),
          Text(
            'Contact our associate operations team or find answers to frequently asked questions below.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: SaTokens.space24),

          // Contact Cards
          _buildContactCard(
            context,
            icon: SaIcons.phone,
            title: 'Call Support',
            subtitle: AppConstants.supportPhone,
            actionLabel: 'Copy phone number',
            onTap: () => _copyToClipboard(
              context,
              AppConstants.supportPhone,
              'Phone number',
            ),
          ),
          const SizedBox(height: SaTokens.space16),
          _buildContactCard(
            context,
            icon: SaIcons.mail,
            title: 'Email Support',
            subtitle: AppConstants.supportEmail,
            actionLabel: 'Copy email address',
            onTap: () => _copyToClipboard(
              context,
              AppConstants.supportEmail,
              'Support email',
            ),
          ),
          const SizedBox(height: SaTokens.space16),
          _buildHoursCard(context),
          const SizedBox(height: SaTokens.space32),

          // Security Notice
          const SaInfoBanner(
            title: 'Security Advisory',
            message:
                'Agrimore staff will NEVER ask for your UPI PIN, banking passwords, or SMS verification codes. Keep your credentials private.',
            variant: SaBannerVariant.warning,
          ),
          const SizedBox(height: SaTokens.space32),

          Text(
            'Frequently Asked Questions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: SaTokens.space16),
          _buildFaqTile(
            context,
            question: 'How do I earn commission?',
            answer:
                'Share your unique associate code with buyers. When customers or businesses apply your code at checkout, those orders are attributed to your account. Commission is awarded on eligible completed orders.',
          ),
          _buildFaqTile(
            context,
            question: 'When is commission credited to my wallet?',
            answer:
                'Commission is credited directly to your wallet once an attributed order reaches "Delivered" or "Completed" status. Orders that are cancelled or returned do not accrue commission.',
          ),
          _buildFaqTile(
            context,
            question: 'How do payouts work?',
            answer:
                'You can request a payout of your available wallet balance at any time. When you submit a request, the balance is deducted immediately and queued for settlement to your registered bank account or UPI ID.',
          ),
          _buildFaqTile(
            context,
            question: 'What is the ₹500 onboarding fee?',
            answer:
                'Self-applied associates must clear a one-time ₹500 onboarding fee to unlock retail order attribution. B2B orders attribute regardless of fee status. Admin-created associates have this fee waived.',
          ),
          _buildFaqTile(
            context,
            question: 'How do I update my payout bank account or UPI ID?',
            answer:
                'Go to your Profile tab, tap "Payout Account", and update your bank account or UPI details. Ensure the legal name matches your KYC documents to prevent transfer delays.',
          ),
          const SizedBox(height: SaTokens.space32),
        ],
      ),
    );
  }

  Widget _buildContactCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    return Material(
      color: SaTokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SaTokens.radiusCard),
        side: const BorderSide(color: SaTokens.divider),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: SaTokens.space16,
          vertical: SaTokens.space8,
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: SaTokens.primarySubtle,
            borderRadius: BorderRadius.circular(SaTokens.radiusInput),
          ),
          child: Icon(icon, color: SaTokens.primary, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: SaTokens.fsBody,
            fontWeight: FontWeight.w600,
            color: SaTokens.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: SaTokens.fsLabel,
            color: SaTokens.textSecondary,
          ),
        ),
        trailing: TextButton.icon(
          onPressed: onTap,
          icon: const Icon(SaIcons.copy, size: 16),
          label: const Text('Copy'),
        ),
      ),
    );
  }

  Widget _buildHoursCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SaTokens.space16),
      decoration: BoxDecoration(
        color: SaTokens.surface,
        borderRadius: BorderRadius.circular(SaTokens.radiusCard),
        border: Border.all(color: SaTokens.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: SaTokens.pageBackground,
              borderRadius: BorderRadius.circular(SaTokens.radiusInput),
            ),
            child: const Icon(
              Icons.schedule_rounded,
              color: SaTokens.textSecondary,
              size: 22,
            ),
          ),
          const SizedBox(width: SaTokens.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Support Operating Hours',
                  style: TextStyle(
                    fontSize: SaTokens.fsBody,
                    fontWeight: FontWeight.w600,
                    color: SaTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Monday – Saturday, 9:00 AM – 6:00 PM IST',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqTile(
    BuildContext context, {
    required String question,
    required String answer,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: SaTokens.space8),
      child: Material(
        color: SaTokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SaTokens.radiusCard),
          side: const BorderSide(color: SaTokens.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
          iconColor: SaTokens.primary,
          collapsedIconColor: SaTokens.textSecondary,
          tilePadding: const EdgeInsets.symmetric(
            horizontal: SaTokens.space16,
            vertical: 4,
          ),
          childrenPadding: const EdgeInsets.only(
            left: SaTokens.space16,
            right: SaTokens.space16,
            bottom: SaTokens.space16,
          ),
          title: Text(
            question,
            style: const TextStyle(
              fontSize: SaTokens.fsBody,
              fontWeight: FontWeight.w600,
              color: SaTokens.textPrimary,
            ),
          ),
          children: [
            Text(
              answer,
              style: const TextStyle(
                fontSize: SaTokens.fsLabel,
                color: SaTokens.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}
