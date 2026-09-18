import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../utils/sa_formatters.dart';
import '../orders/order_detail_screen.dart';
import '../profile/onboarding_status_screen.dart';
import '../notifications/notifications_screen.dart';
import '../shell/employee_shell_screen.dart';

/// Employee sales dashboard screen.
///
/// Features:
/// - Associate code hero card (tap-to-copy + native share).
/// - Onboarding fee status card (links to [OnboardingStatusScreen]).
/// - Commission & wallet metrics row (tap switches to Wallet tab).
/// - Recent attributed orders preview (tap switches to Orders tab / opens [OrderDetailScreen]).
class DashboardScreen extends StatelessWidget {
  final String? employeeUid;
  final Stream<DocumentSnapshot<Map<String, dynamic>>>? employeeStream;
  final Stream<DocumentSnapshot<Map<String, dynamic>>>? walletStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? recentOrdersStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? notificationsStream;

  const DashboardScreen({
    super.key,
    this.employeeUid,
    this.employeeStream,
    this.walletStream,
    this.recentOrdersStream,
    this.notificationsStream,
  });

  @override
  Widget build(BuildContext context) {
    final uid = employeeUid ?? FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        backgroundColor: SaTokens.pageBackground,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: SaTokens.pageBackground,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AgriMore',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const Text(
              'Sales Associate',
              style: TextStyle(
                fontSize: SaTokens.fsCaption,
                fontWeight: FontWeight.w500,
                color: SaTokens.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          _NotificationBellButton(uid: uid, stream: notificationsStream),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(SaTokens.space16),
        children: [
          // Section 1: Associate Code Card & Onboarding Status Card
          _buildAssociateSection(uid),
          const SizedBox(height: SaTokens.space16),

          // Section 2: Financial Metrics Summary
          _buildCommissionSummary(context, uid),
          const SizedBox(height: SaTokens.space24),

          // Section 3: Recent Attributed Orders Preview
          _buildRecentOrdersHeader(context),
          const SizedBox(height: SaTokens.space12),
          _buildOrdersList(context, uid),
        ],
      ),
    );
  }

  Widget _buildAssociateSection(String uid) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: employeeStream ??
          FirebaseFirestore.instance.collection('employees').doc(uid).snapshots(),
      builder: (context, snap) {
        return Column(
          children: [
            _AssociateCodeCard(snapshot: snap),
            const SizedBox(height: SaTokens.space12),
            _OnboardingFeeStatusCard(snapshot: snap),
          ],
        );
      },
    );
  }

  Widget _buildCommissionSummary(BuildContext context, String uid) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: walletStream ??
          FirebaseFirestore.instance.collection('wallets').doc(uid).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final balance = (data?['balance'] as num?)?.toDouble() ?? 0.0;
        final lifetimeEarnings =
            (data?['lifetimeEarnings'] as num?)?.toDouble() ?? 0.0;

        return Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: SaIcons.wallet,
                label: 'Wallet Balance',
                value: SaFormatters.formatCurrency(balance),
                accentColor: SaTokens.successFg,
                onTap: () {
                  EmployeeShellController.of(context)?.switchTab(2);
                },
              ),
            ),
            const SizedBox(width: SaTokens.space12),
            Expanded(
              child: _MetricCard(
                icon: Icons.trending_up_rounded,
                label: 'Total Commission',
                value: SaFormatters.formatCurrency(lifetimeEarnings),
                accentColor: SaTokens.primary,
                onTap: () {
                  EmployeeShellController.of(context)?.switchTab(2);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecentOrdersHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Recent Orders',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        TextButton(
          onPressed: () {
            EmployeeShellController.of(context)?.switchTab(1);
          },
          child: const Text('View all'),
        ),
      ],
    );
  }

  Widget _buildOrdersList(BuildContext context, String uid) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: recentOrdersStream ??
          FirebaseFirestore.instance
              .collection('orders')
              .where('employeeUid', isEqualTo: uid)
              .orderBy('createdAt', descending: true)
              .limit(5)
              .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(SaTokens.space16),
              child: Text('Error loading orders: ${snap.error}'),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(SaTokens.space24),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(SaTokens.space24),
            decoration: BoxDecoration(
              color: SaTokens.surface,
              borderRadius: BorderRadius.circular(SaTokens.radiusCard),
              border: Border.all(color: SaTokens.divider),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(
                    SaIcons.shoppingBag,
                    size: 32,
                    color: SaTokens.textSecondary,
                  ),
                  const SizedBox(height: SaTokens.space8),
                  Text(
                    'No orders attributed yet',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: SaTokens.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: docs.map((doc) {
            final d = doc.data();
            final orderNumber = d['orderNumber']?.toString() ?? doc.id;
            final total = (d['total'] as num?)?.toDouble() ?? 0.0;
            final status = (d['orderStatus'] ?? 'pending').toString().toLowerCase();
            final rawMode = d['orderMode'];
            final normMode =
                rawMode is String ? rawMode.trim().toUpperCase() : null;
            final isDelivered = status == 'delivered' || status == 'completed';

            return Container(
              margin: const EdgeInsets.only(bottom: SaTokens.space8),
              decoration: BoxDecoration(
                color: SaTokens.surface,
                borderRadius: BorderRadius.circular(SaTokens.radiusCard),
                border: Border.all(color: SaTokens.divider),
              ),
              child: ListTile(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        OrderDetailScreen(orderId: doc.id, orderData: d),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: SaTokens.space16,
                  vertical: 4,
                ),
                title: Row(
                  children: [
                    Text(
                      '#$orderNumber',
                      style: const TextStyle(
                        fontSize: SaTokens.fsBody,
                        fontWeight: FontWeight.w700,
                        color: SaTokens.textPrimary,
                      ),
                    ),
                    if (normMode != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: normMode == 'B2B'
                              ? SaTokens.primarySubtle
                              : Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          normMode == 'B2B' ? 'B2B' : 'Retail',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: normMode == 'B2B'
                                ? SaTokens.primary
                                : Colors.purple.shade700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    SaFormatters.formatCurrency(total),
                    style: const TextStyle(
                      fontSize: SaTokens.fsLabel,
                      fontWeight: FontWeight.w600,
                      color: SaTokens.textSecondary,
                    ),
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDelivered ? SaTokens.successBg : SaTokens.warningBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: isDelivered ? SaTokens.successFg : SaTokens.warningFg,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _NotificationBellButton extends StatelessWidget {
  final String uid;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? stream;

  const _NotificationBellButton({required this.uid, this.stream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream ??
          FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('notifications')
              .where('read', isEqualTo: false)
              .limit(1)
              .snapshots(),
      builder: (context, snap) {
        final hasUnread = snap.data?.docs.isNotEmpty ?? false;

        return IconButton(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(SaIcons.bell),
              if (hasUnread)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: SaTokens.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          tooltip: 'Notifications',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const NotificationsScreen(),
              ),
            );
          },
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;
  final VoidCallback onTap;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SaTokens.radiusCard),
      child: Container(
        padding: const EdgeInsets.all(SaTokens.space16),
        decoration: BoxDecoration(
          color: SaTokens.surface,
          borderRadius: BorderRadius.circular(SaTokens.radiusCard),
          border: Border.all(color: SaTokens.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accentColor, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: SaTokens.fsCaption,
                      fontWeight: FontWeight.w600,
                      color: SaTokens.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: SaTokens.space8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: SaTokens.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _AssociateCodeCard extends StatelessWidget {
  final AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot;

  const _AssociateCodeCard({required this.snapshot});

  void _copy(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Associate code $code copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _share(String code) {
    HapticFeedback.lightImpact();
    Share.share(
      'Use my AgriMore Sales Associate code $code at checkout to connect your purchases: https://agrimore.in',
      subject: 'My AgriMore Associate Code',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (snapshot.hasError) {
      return _cardShell(
        child: const Text(
          'Could not load associate code right now.',
          style: TextStyle(color: SaTokens.textSecondary),
        ),
      );
    }
    if (!snapshot.hasData) {
      return _cardShell(
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(SaTokens.space16),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    final doc = snapshot.data!;
    if (!doc.exists || doc.data() == null) {
      return _cardShell(
        child: const Text('Associate profile not found.'),
      );
    }

    final employee = EmployeeModel.fromMap(doc.data()!, doc.id);
    final code = employee.employeeCode.trim();

    if (code.isEmpty) {
      return _cardShell(
        child: const Text('No associate code assigned yet.'),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SaTokens.pagePadding),
      decoration: BoxDecoration(
        color: SaTokens.surface,
        borderRadius: BorderRadius.circular(SaTokens.radiusCard),
        border: Border.all(color: SaTokens.primary, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: SaTokens.primary.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: SaTokens.primarySubtle,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      SaIcons.shoppingBag,
                      color: SaTokens.primary,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: SaTokens.space8),
                  const Text(
                    'Your Associate Code',
                    style: TextStyle(
                      fontSize: SaTokens.fsBody,
                      fontWeight: FontWeight.w700,
                      color: SaTokens.textPrimary,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(SaIcons.share2, color: SaTokens.primary, size: 20),
                tooltip: 'Share code',
                onPressed: () => _share(code),
              ),
            ],
          ),
          const SizedBox(height: SaTokens.space12),

          // Code pill container
          InkWell(
            onTap: () => _copy(context, code),
            borderRadius: BorderRadius.circular(SaTokens.radiusInput),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: SaTokens.space16,
                vertical: SaTokens.space12,
              ),
              decoration: BoxDecoration(
                color: SaTokens.pageBackground,
                borderRadius: BorderRadius.circular(SaTokens.radiusInput),
                border: Border.all(color: SaTokens.divider),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        code,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: SaTokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Tap to copy code',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: SaTokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: SaTokens.primarySubtle,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      SaIcons.copy,
                      color: SaTokens.primary,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: SaTokens.space12),

          Text(
            'Share this code with your customers. When applied at checkout, attributed orders earn you commission.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: SaTokens.textSecondary,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }

  Widget _cardShell({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SaTokens.space16),
      decoration: BoxDecoration(
        color: SaTokens.surface,
        borderRadius: BorderRadius.circular(SaTokens.radiusCard),
        border: Border.all(color: SaTokens.divider),
      ),
      child: child,
    );
  }
}

class _OnboardingFeeStatusCard extends StatelessWidget {
  final AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot;

  const _OnboardingFeeStatusCard({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    if (!snapshot.hasData) return const SizedBox.shrink();
    final doc = snapshot.data!;
    if (!doc.exists || doc.data() == null) return const SizedBox.shrink();

    final employee = EmployeeModel.fromMap(doc.data()!, doc.id);
    final isCleared = employee.hasClearedOnboardingGate;
    final isWaived = employee.onboardingWaived;

    final badgeLabel = isWaived
        ? 'Fee Waived'
        : isCleared
            ? 'Fee Paid (₹500)'
            : 'Payment Due (₹500)';

    final Color badgeBg = isCleared ? SaTokens.successBg : SaTokens.warningBg;
    final Color badgeFg = isCleared ? SaTokens.successFg : SaTokens.warningFg;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const OnboardingStatusScreen(),
          ),
        );
      },
      borderRadius: BorderRadius.circular(SaTokens.radiusCard),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: SaTokens.space16,
          vertical: SaTokens.space12,
        ),
        decoration: BoxDecoration(
          color: SaTokens.surface,
          borderRadius: BorderRadius.circular(SaTokens.radiusCard),
          border: Border.all(color: SaTokens.divider),
        ),
        child: Row(
          children: [
            Icon(
              isCleared ? SaIcons.circleCheck : SaIcons.triangleAlert,
              color: badgeFg,
              size: 18,
            ),
            const SizedBox(width: SaTokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Onboarding Status',
                    style: TextStyle(
                      fontSize: SaTokens.fsBody,
                      fontWeight: FontWeight.w600,
                      color: SaTokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isCleared
                        ? 'Retail & B2B attribution active'
                        : 'Complete fee for retail attribution',
                    style: TextStyle(
                      fontSize: SaTokens.fsCaption,
                      color: SaTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badgeLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: badgeFg,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              color: SaTokens.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
