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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AgriMore',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: tokens.textPrimary,
                  ),
            ),
            Text(
              'Sales Associate',
              style: TextStyle(
                fontSize: SaTokens.fsCaption,
                fontWeight: FontWeight.w500,
                color: tokens.textSecondary,
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
        Expanded(
          child: Text(
            'Recent Orders',
            style: Theme.of(context).textTheme.titleMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: SaTokens.space8),
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
    final tokens = context.saTokens;
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
              child: Text(
                'Error loading orders: ${snap.error}',
                style: TextStyle(color: tokens.textSecondary),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.all(SaTokens.space16),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(SaTokens.radiusCard),
              border: Border.all(color: tokens.divider),
            ),
            child: Row(
              children: [
                Icon(
                  SaIcons.shoppingBag,
                  color: tokens.textSecondary.withValues(alpha: 0.5),
                  size: 20,
                ),
                const SizedBox(width: SaTokens.space12),
                Expanded(
                  child: Text(
                    'Loading orders...',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: SaTokens.fsLabel,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(SaTokens.space24),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(SaTokens.radiusCard),
              border: Border.all(color: tokens.divider),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    SaIcons.shoppingBag,
                    size: 32,
                    color: tokens.textSecondary,
                  ),
                  const SizedBox(height: SaTokens.space8),
                  Text(
                    'No orders attributed yet',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: tokens.textSecondary,
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
                color: tokens.surface,
                borderRadius: BorderRadius.circular(SaTokens.radiusCard),
                border: Border.all(color: tokens.divider),
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
                    Flexible(
                      child: Text(
                        '#$orderNumber',
                        style: TextStyle(
                          fontSize: SaTokens.fsBody,
                          fontWeight: FontWeight.w700,
                          color: tokens.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
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
                              ? tokens.primarySubtle
                              : (Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF3B0764)
                                  : Colors.purple.shade50),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          normMode == 'B2B' ? 'B2B' : 'Retail',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: normMode == 'B2B'
                                ? tokens.primary
                                : (Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFC084FC)
                                    : Colors.purple.shade700),
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
                    style: TextStyle(
                      fontSize: SaTokens.fsLabel,
                      fontWeight: FontWeight.w600,
                      color: tokens.textSecondary,
                    ),
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDelivered ? tokens.successBg : tokens.warningBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: isDelivered ? tokens.successFg : tokens.warningFg,
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
    final tokens = context.saTokens;
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
                    decoration: BoxDecoration(
                      color: tokens.primary,
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
    final tokens = context.saTokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SaTokens.radiusCard),
      child: Container(
        padding: const EdgeInsets.all(SaTokens.space16),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(SaTokens.radiusCard),
          border: Border.all(color: tokens.divider),
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
                    style: TextStyle(
                      fontSize: SaTokens.fsCaption,
                      fontWeight: FontWeight.w600,
                      color: tokens.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: SaTokens.space8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: tokens.textPrimary,
                ),
                maxLines: 1,
              ),
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
    final tokens = context.saTokens;
    if (snapshot.hasError) {
      return _cardShell(
        context,
        child: Text(
          'Could not load associate code right now.',
          style: TextStyle(color: tokens.textSecondary),
        ),
      );
    }
    if (!snapshot.hasData) {
      return _cardShell(
        context,
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tokens.primarySubtle,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.qr_code_2_rounded, color: tokens.primary, size: 20),
            ),
            const SizedBox(width: SaTokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Associate Code',
                    style: TextStyle(
                      fontSize: SaTokens.fsCaption,
                      fontWeight: FontWeight.w600,
                      color: tokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Loading code...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final doc = snapshot.data!;
    if (!doc.exists || doc.data() == null) {
      return _cardShell(
        context,
        child: Text(
          'Associate profile not found.',
          style: TextStyle(color: tokens.textSecondary),
        ),
      );
    }

    final employee = EmployeeModel.fromMap(doc.data()!, doc.id);
    final code = employee.employeeCode.trim();

    if (code.isEmpty) {
      return _cardShell(
        context,
        child: Text(
          'No associate code assigned yet.',
          style: TextStyle(color: tokens.textSecondary),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SaTokens.pagePadding),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(SaTokens.radiusCard),
        border: Border.all(color: tokens.primary, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: tokens.primary.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: tokens.primarySubtle,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        SaIcons.shoppingBag,
                        color: tokens.primary,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: SaTokens.space8),
                    Expanded(
                      child: Text(
                        'Your Associate Code',
                        style: TextStyle(
                          fontSize: SaTokens.fsBody,
                          fontWeight: FontWeight.w700,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(SaIcons.share2, color: tokens.primary, size: 20),
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
                color: tokens.pageBackground,
                borderRadius: BorderRadius.circular(SaTokens.radiusInput),
                border: Border.all(color: tokens.divider),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            code,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: tokens.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tap to copy code',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: SaTokens.space8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: tokens.primarySubtle,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      SaIcons.copy,
                      color: tokens.primary,
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
                  color: tokens.textSecondary,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }

  Widget _cardShell(BuildContext context, {required Widget child}) {
    final tokens = context.saTokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SaTokens.space16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(SaTokens.radiusCard),
        border: Border.all(color: tokens.divider),
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

    final tokens = context.saTokens;
    final employee = EmployeeModel.fromMap(doc.data()!, doc.id);
    final isCleared = employee.hasClearedOnboardingGate;
    final isWaived = employee.onboardingWaived;

    final badgeLabel = isWaived
        ? 'Fee Waived'
        : isCleared
            ? 'Fee Paid (₹500)'
            : 'Payment Due (₹500)';

    final Color badgeBg = isCleared ? tokens.successBg : tokens.warningBg;
    final Color badgeFg = isCleared ? tokens.successFg : tokens.warningFg;

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
          color: tokens.surface,
          borderRadius: BorderRadius.circular(SaTokens.radiusCard),
          border: Border.all(color: tokens.divider),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(1.0);
            final isStacked = constraints.maxWidth < 320 || textScale > 1.15;
            final badgeWidget = Container(
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
            );

            if (isStacked) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                        Text(
                          'Onboarding Status',
                          style: TextStyle(
                            fontSize: SaTokens.fsBody,
                            fontWeight: FontWeight.w600,
                            color: tokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isCleared
                              ? 'Retail & B2B attribution active'
                              : 'Complete fee for retail attribution',
                          style: TextStyle(
                            fontSize: SaTokens.fsCaption,
                            color: tokens.textSecondary,
                          ),
                        ),
                        const SizedBox(height: SaTokens.space8),
                        badgeWidget,
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: tokens.textSecondary,
                    size: 20,
                  ),
                ],
              );
            }

            return Row(
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
                      Text(
                        'Onboarding Status',
                        style: TextStyle(
                          fontSize: SaTokens.fsBody,
                          fontWeight: FontWeight.w600,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isCleared
                            ? 'Retail & B2B attribution active'
                            : 'Complete fee for retail attribution',
                        style: TextStyle(
                          fontSize: SaTokens.fsCaption,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: SaTokens.space8),
                badgeWidget,
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: tokens.textSecondary,
                  size: 20,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
