import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../utils/sa_formatters.dart';
import '../support/help_support_screen.dart';

/// Detailed lifecycle and progression timeline screen for an individual payout.
///
/// Streams `employee_payouts/{payoutId}` to reflect real-time status changes
/// (e.g. when an admin marks the payout processed/paid).
class PayoutDetailsScreen extends StatelessWidget {
  final String payoutId;
  final Map<String, dynamic>? initialData;

  const PayoutDetailsScreen({
    super.key,
    required this.payoutId,
    this.initialData,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SaTokens.pageBackground,
      appBar: AppBar(
        title: const Text('Payout Details'),
        leading: IconButton(
          icon: const Icon(SaIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('employee_payouts')
            .doc(payoutId)
            .snapshots(),
        builder: (context, snap) {
          final data = snap.data?.data() ?? initialData;

          if (data == null) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(SaTokens.space24),
                child: Text('Payout details not found'),
              ),
            );
          }

          final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
          final status = (data['status'] ?? 'requested').toString().toLowerCase();
          final referenceId = data['referenceId']?.toString() ??
              data['payoutNumber']?.toString() ??
              payoutId;

          DateTime? createdAt;
          final tsCreated = data['createdAt'];
          if (tsCreated is Timestamp) createdAt = tsCreated.toDate();

          DateTime? paidAt;
          final tsPaid = data['paidAt'];
          if (tsPaid is Timestamp) paidAt = tsPaid.toDate();

          final isPaid = status == 'paid';
          final isFailed = status == 'failed' || status == 'rejected';

          return ListView(
            padding: const EdgeInsets.all(SaTokens.space16),
            children: [
              // Hero Amount Card
              _buildAmountHero(amount, status, isPaid, isFailed),
              const SizedBox(height: SaTokens.space16),

              // Timeline Progression Card
              _buildTimelineCard(context, createdAt, paidAt, isPaid, isFailed),
              const SizedBox(height: SaTokens.space16),

              // Summary Details Card
              _buildSummaryCard(context, referenceId, data),
              const SizedBox(height: SaTokens.space24),

              // Help & Support Link
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const HelpSupportScreen(),
                      ),
                    );
                  },
                  icon: const Icon(SaIcons.headphones, size: 16),
                  label: const Text('Have a question about this payout? Contact Support'),
                ),
              ),
              const SizedBox(height: SaTokens.space16),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAmountHero(
    double amount,
    String status,
    bool isPaid,
    bool isFailed,
  ) {
    Color bg = SaTokens.warningBg;
    Color fg = SaTokens.warningFg;
    IconData icon = Icons.schedule_rounded;

    if (isPaid) {
      bg = SaTokens.successBg;
      fg = SaTokens.successFg;
      icon = SaIcons.circleCheck;
    } else if (isFailed) {
      bg = SaTokens.errorBg;
      fg = SaTokens.errorFg;
      icon = SaIcons.circleAlert;
    }

    return Container(
      padding: const EdgeInsets.all(SaTokens.space24),
      decoration: BoxDecoration(
        color: SaTokens.surface,
        borderRadius: BorderRadius.circular(SaTokens.radiusCard),
        border: Border.all(color: SaTokens.divider),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: 4),
                Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: SaTokens.space12),
          Text(
            SaFormatters.formatCurrency(amount),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: SaTokens.textPrimary,
            ),
          ),
          const SizedBox(height: SaTokens.space4),
          const Text(
            'Requested Payout Amount',
            style: TextStyle(
              fontSize: SaTokens.fsCaption,
              color: SaTokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard(
    BuildContext context,
    DateTime? createdAt,
    DateTime? paidAt,
    bool isPaid,
    bool isFailed,
  ) {
    return Container(
      padding: const EdgeInsets.all(SaTokens.space16),
      decoration: BoxDecoration(
        color: SaTokens.surface,
        borderRadius: BorderRadius.circular(SaTokens.radiusCard),
        border: Border.all(color: SaTokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payout Progress',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: SaTokens.space16),

          // Step 1: Requested
          _buildTimelineStep(
            isDone: true,
            isCurrent: !isPaid && !isFailed,
            title: 'Payout request submitted',
            subtitle: createdAt != null
                ? SaFormatters.formatDate(createdAt)
                : 'Recorded on ledger',
          ),
          const SizedBox(height: SaTokens.space12),

          // Step 2: Settlement
          _buildTimelineStep(
            isDone: isPaid,
            isCurrent: isPaid,
            isError: isFailed,
            isLast: true,
            title: isPaid
                ? 'Funds settled to account'
                : (isFailed ? 'Payout rejected / failed' : 'Bank settlement in progress'),
            subtitle: isPaid
                ? (paidAt != null
                    ? 'Completed on ${SaFormatters.formatDate(paidAt)}'
                    : 'Transferred')
                : (isFailed
                    ? 'Please contact associate support'
                    : 'Transfers typically take 1–2 banking days'),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({
    required bool isDone,
    required bool isCurrent,
    required String title,
    required String subtitle,
    bool isError = false,
    bool isLast = false,
  }) {
    Color iconBg = SaTokens.pageBackground;
    Color iconFg = SaTokens.textSecondary;

    if (isError) {
      iconBg = SaTokens.errorBg;
      iconFg = SaTokens.errorFg;
    } else if (isDone) {
      iconBg = SaTokens.successBg;
      iconFg = SaTokens.successFg;
    } else if (isCurrent) {
      iconBg = SaTokens.primarySubtle;
      iconFg = SaTokens.primary;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isError
                    ? SaIcons.circleAlert
                    : isDone
                        ? SaIcons.circleCheck
                        : Icons.schedule_rounded,
                size: 16,
                color: iconFg,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 32,
                color: isDone ? SaTokens.successFg : SaTokens.divider,
              ),
          ],
        ),
        const SizedBox(width: SaTokens.space12),
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
                  fontSize: SaTokens.fsCaption,
                  color: SaTokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String referenceId,
    Map<String, dynamic> data,
  ) {
    final method = data['payoutMethod']?.toString().toUpperCase() ?? 'BANK';
    final destination = data['destination']?.toString() ??
        data['accountNumber']?.toString() ??
        data['upiId']?.toString() ??
        'Registered account';

    return Container(
      padding: const EdgeInsets.all(SaTokens.space16),
      decoration: BoxDecoration(
        color: SaTokens.surface,
        borderRadius: BorderRadius.circular(SaTokens.radiusCard),
        border: Border.all(color: SaTokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transfer Summary',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: SaTokens.space12),
          _buildInfoRow('Reference ID', referenceId),
          _buildInfoRow('Payout Method', method),
          _buildInfoRow('Destination', destination),
          if (data['notes'] != null && data['notes'].toString().isNotEmpty)
            _buildInfoRow('Notes', data['notes'].toString()),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: SaTokens.fsLabel,
              color: SaTokens.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: SaTokens.fsLabel,
              fontWeight: FontWeight.w600,
              color: SaTokens.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
