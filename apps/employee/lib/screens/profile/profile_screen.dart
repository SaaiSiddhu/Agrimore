import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/sa_formatters.dart';
import '../wallet/payout_account_screen.dart';
import 'onboarding_status_screen.dart';
import '../notifications/notifications_screen.dart';
import '../support/help_support_screen.dart';

/// The associate's own account and profile hub screen.
///
/// Features:
/// - Associate identity card with initials avatar and copyable associate code.
/// - KYC and registered account details card.
/// - Navigation tiles to Payout Account, Onboarding Status, Notifications, and Support.
/// - Confirmed sign-out action.
class ProfileScreen extends StatelessWidget {
  final String? employeeUid;
  final Stream<DocumentSnapshot<Map<String, dynamic>>>? employeeStream;

  const ProfileScreen({
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
        body: const SizedBox.shrink(),
      );
    }

    return Scaffold(
      backgroundColor: tokens.pageBackground,
      appBar: AppBar(
        title: const Text('My Profile'),
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
                  'Could not load profile right now.',
                  style: TextStyle(color: tokens.textSecondary),
                ),
              ),
            );
          }
          if (!snap.hasData) {
            return const SizedBox.shrink();
          }

          final doc = snap.data!;
          if (!doc.exists || doc.data() == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(SaTokens.space24),
                child: Text(
                  'Associate profile record not found.',
                  style: TextStyle(color: tokens.textSecondary),
                ),
              ),
            );
          }

          final employee = EmployeeModel.fromMap(doc.data()!, doc.id);

          return ListView(
            padding: const EdgeInsets.all(SaTokens.space16),
            children: [
              // 1. Identity Hero Card
              _buildIdentityCard(context, employee),
              const SizedBox(height: SaTokens.space16),

              // 2. Appearance & Theme Settings
              _buildAppearanceSection(context),
              const SizedBox(height: SaTokens.space16),

              // 3. Navigation Actions Section
              _buildNavigationSection(context),
              const SizedBox(height: SaTokens.space16),

              // 4. Account Details Card
              _buildAccountDetailsCard(context, employee),
              const SizedBox(height: SaTokens.space24),

              // 5. Sign Out Button
              _buildSignOutButton(context),
              const SizedBox(height: SaTokens.space24),
            ],
          );
        },
      ),
    );
  }

  Widget _buildIdentityCard(BuildContext context, EmployeeModel employee) {
    final tokens = context.saTokens;
    final name = employee.name.trim();
    final initials = name.isNotEmpty
        ? name
            .split(' ')
            .take(2)
            .map((part) => part.isNotEmpty ? part[0] : '')
            .join()
            .toUpperCase()
        : 'SA';

    final status = employee.status.toLowerCase();
    final isApproved = status == 'approved';
    final isSuspended = status == 'suspended';

    Color statusBg = tokens.warningBg;
    Color statusFg = tokens.warningFg;
    String statusText = 'Pending Approval';

    if (isApproved) {
      statusBg = tokens.successBg;
      statusFg = tokens.successFg;
      statusText = 'Active Associate';
    } else if (isSuspended) {
      statusBg = tokens.errorBg;
      statusFg = tokens.errorFg;
      statusText = 'Suspended';
    }

    return Container(
      padding: const EdgeInsets.all(SaTokens.space24),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(SaTokens.radiusCard),
        border: Border.all(color: tokens.divider),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Initials Avatar
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tokens.primarySubtle,
                  shape: BoxShape.circle,
                  border: Border.all(color: tokens.primary.withValues(alpha: 0.2)),
                ),
                child: Text(
                  initials,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: tokens.primary,
                  ),
                ),
              ),
              const SizedBox(width: SaTokens.space16),

              // Name & Role
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isNotEmpty ? name : 'Sales Associate',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Sales Associate',
                      style: TextStyle(
                        fontSize: SaTokens.fsCaption,
                        color: tokens.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: statusFg,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (employee.employeeCode.isNotEmpty) ...[
            const SizedBox(height: SaTokens.space16),
            Divider(color: tokens.divider),
            const SizedBox(height: SaTokens.space8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Associate Referral Code',
                        style: TextStyle(
                          fontSize: SaTokens.fsCaption,
                          color: tokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        employee.employeeCode,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: SaTokens.space8),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: employee.employeeCode),
                    );
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Code ${employee.employeeCode} copied to clipboard',
                        ),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(SaIcons.copy, size: 16),
                  label: const Text('Copy'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAppearanceSection(BuildContext context) {
    final tokens = context.saTokens;
    final themeProvider = Provider.of<EmployeeThemeProvider?>(context);
    if (themeProvider == null) {
      return const SizedBox.shrink();
    }

    final isDark = themeProvider.isDarkMode ||
        (themeProvider.isSystem &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return Material(
      color: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SaTokens.radiusCard),
        side: BorderSide(color: tokens.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SaTokens.space16,
          vertical: SaTokens.space12,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tokens.primarySubtle,
                borderRadius: BorderRadius.circular(SaTokens.radiusInput),
              ),
              child: Icon(
                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                size: 20,
                color: tokens.primary,
              ),
            ),
            const SizedBox(width: SaTokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dark Mode',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isDark ? 'Dark theme active' : 'Light theme active',
                    style: TextStyle(
                      fontSize: SaTokens.fsCaption,
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: isDark,
              activeTrackColor: tokens.primary,
              onChanged: (_) {
                HapticFeedback.lightImpact();
                themeProvider.toggleTheme(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationSection(BuildContext context) {
    final tokens = context.saTokens;
    return Material(
      color: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SaTokens.radiusCard),
        side: BorderSide(color: tokens.divider),
      ),
      child: Column(
        children: [
          _buildNavTile(
            context,
            icon: Icons.account_balance_outlined,
            title: 'Payout Account',
            subtitle: 'Bank account & UPI destination',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PayoutAccountScreen(),
                ),
              );
            },
          ),
          Divider(height: 1, color: tokens.divider),
          _buildNavTile(
            context,
            icon: SaIcons.circleCheck,
            title: 'Onboarding Status',
            subtitle: 'Attribution & registration rules',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const OnboardingStatusScreen(),
                ),
              );
            },
          ),
          Divider(height: 1, color: tokens.divider),
          _buildNavTile(
            context,
            icon: SaIcons.bell,
            title: 'Notifications',
            subtitle: 'Order & settlement updates',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const NotificationsScreen(),
                ),
              );
            },
          ),
          Divider(height: 1, color: tokens.divider),
          _buildNavTile(
            context,
            icon: SaIcons.headphones,
            title: 'Help & Support',
            subtitle: 'FAQs, contact desk & operating hours',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const HelpSupportScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final tokens = context.saTokens;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: SaTokens.space16,
        vertical: 4,
      ),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: tokens.primarySubtle,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: tokens.primary, size: 18),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: SaTokens.fsBody,
          fontWeight: FontWeight.w600,
          color: tokens.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: SaTokens.fsCaption,
          color: tokens.textSecondary,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: tokens.textSecondary,
        size: 20,
      ),
    );
  }

  Widget _buildAccountDetailsCard(
    BuildContext context,
    EmployeeModel employee,
  ) {
    final tokens = context.saTokens;
    final maskedPhone = employee.phone.isNotEmpty
        ? SaFormatters.formatMaskedPhone(employee.phone)
        : 'Not on file';

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
          Text(
            'Account Details',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: tokens.textPrimary,
                ),
          ),
          const SizedBox(height: SaTokens.space12),
          _buildInfoRow(
            context,
            icon: SaIcons.phone,
            label: 'Phone Number',
            value: maskedPhone,
          ),
          Divider(height: 16, color: tokens.divider),
          _buildInfoRow(
            context,
            icon: SaIcons.mail,
            label: 'Email Address',
            value: employee.email.isNotEmpty ? employee.email : 'Not on file',
          ),
          Divider(height: 16, color: tokens.divider),
          _buildInfoRow(
            context,
            icon: Icons.percent_rounded,
            label: 'Default Commission Rate',
            value: employee.commissionRate > 0
                ? '${employee.commissionRate.toStringAsFixed(1)}%'
                : 'Standard programme rate',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final tokens = context.saTokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: tokens.textSecondary),
        const SizedBox(width: SaTokens.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: tokens.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              SelectableText(
                value,
                style: TextStyle(
                  fontSize: SaTokens.fsBody,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSignOutButton(BuildContext context) {
    return SaLoadingButton(
      text: 'Sign Out',
      variant: SaButtonVariant.outlined,
      onPressed: () async {
        final confirmed = await DialogHelper.showConfirmation(
          context,
          title: 'Sign Out',
          message:
              'Are you sure you want to sign out of your associate account?',
          confirmText: 'Sign Out',
          isDangerous: true,
        );
        if (confirmed == true && context.mounted) {
          final navigator = Navigator.of(context);
          await context.read<EmployeeAuthProvider>().signOut();
          if (navigator.mounted) {
            navigator.popUntil((route) => route.isFirst);
          }
        }
      },
    );
  }
}
