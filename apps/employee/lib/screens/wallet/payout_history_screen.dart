import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../utils/sa_formatters.dart';
import 'payout_details_screen.dart';

enum _PayoutStatusFilter { all, requested, paid }

/// Dedicated Payout History screen for Sales Associates.
///
/// Streams `employee_payouts` where `employeeId == uid` ordered by `createdAt` desc,
/// bounded by `_pageSize` pagination, with client-side status filtering.
class PayoutHistoryScreen extends StatefulWidget {
  const PayoutHistoryScreen({super.key});

  @override
  State<PayoutHistoryScreen> createState() => _PayoutHistoryScreenState();
}

class _PayoutHistoryScreenState extends State<PayoutHistoryScreen> {
  int _pageSize = 20;
  _PayoutStatusFilter _statusFilter = _PayoutStatusFilter.all;

  @override
  Widget build(BuildContext context) {
    final tokens = context.saTokens;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        backgroundColor: tokens.pageBackground,
        body: const Center(
          child: Text(
            'Associate session unavailable',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: tokens.pageBackground,
      appBar: AppBar(
        title: const Text('Payout History'),
        leading: IconButton(
          icon: const Icon(SaIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips Row
          Container(
            color: tokens.surface,
            padding: const EdgeInsets.symmetric(
              horizontal: SaTokens.space16,
              vertical: SaTokens.space12,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All Payouts', _PayoutStatusFilter.all, tokens),
                  const SizedBox(width: SaTokens.space8),
                  _buildFilterChip('Requested', _PayoutStatusFilter.requested, tokens),
                  const SizedBox(width: SaTokens.space8),
                  _buildFilterChip('Paid / Settled', _PayoutStatusFilter.paid, tokens),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: tokens.divider),

          // Payouts stream
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('employee_payouts')
                  .where('employeeId', isEqualTo: uid)
                  .orderBy('createdAt', descending: true)
                  .limit(_pageSize)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(SaTokens.space24),
                      child: Text(
                        'Error loading payouts: ${snap.error}',
                        style: TextStyle(color: tokens.textSecondary),
                      ),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return ListView.builder(
                    padding: const EdgeInsets.all(SaTokens.space16),
                    itemCount: 4,
                    itemBuilder: (_, __) => Container(
                      height: 72,
                      margin: const EdgeInsets.only(bottom: SaTokens.space12),
                      decoration: BoxDecoration(
                        color: tokens.surface,
                        borderRadius: BorderRadius.circular(SaTokens.radiusCard),
                        border: Border.all(color: tokens.divider),
                      ),
                    ),
                  );
                }

                final allDocs = snap.data!.docs;

                final filteredDocs = allDocs.where((doc) {
                  final data = doc.data();
                  final status =
                      (data['status'] ?? 'requested').toString().toLowerCase();

                  if (_statusFilter == _PayoutStatusFilter.requested &&
                      status != 'requested') {
                    return false;
                  }
                  if (_statusFilter == _PayoutStatusFilter.paid &&
                      status != 'paid') {
                    return false;
                  }
                  return true;
                }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(SaTokens.space32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: tokens.primarySubtle,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              SaIcons.wallet,
                              size: 32,
                              color: tokens.primary,
                            ),
                          ),
                          const SizedBox(height: SaTokens.space16),
                          Text(
                            'No payouts found',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: SaTokens.space4),
                          Text(
                            'Payouts you request from your wallet will appear here.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final reachedPageLimit = allDocs.length >= _pageSize;

                return ListView.builder(
                  padding: const EdgeInsets.all(SaTokens.space16),
                  itemCount: filteredDocs.length + (reachedPageLimit ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == filteredDocs.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: SaTokens.space16,
                        ),
                        child: Center(
                          child: OutlinedButton(
                            onPressed: () =>
                                setState(() => _pageSize += 20),
                            child: const Text('Load more payouts'),
                          ),
                        ),
                      );
                    }

                    final doc = filteredDocs[index];
                    final d = doc.data();
                    return _buildPayoutCard(context, doc.id, d, tokens);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    _PayoutStatusFilter filter,
    SalesAssociateTokens tokens,
  ) {
    final selected = _statusFilter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (val) {
        if (val) setState(() => _statusFilter = filter);
      },
      selectedColor: tokens.primarySubtle,
      backgroundColor: tokens.surface,
      labelStyle: TextStyle(
        fontSize: SaTokens.fsLabel,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: selected ? tokens.primary : tokens.textSecondary,
      ),
      side: BorderSide(
        color: selected ? tokens.primary : tokens.divider,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SaTokens.radiusInput),
      ),
    );
  }

  Widget _buildPayoutCard(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
    SalesAssociateTokens tokens,
  ) {
    final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
    final status = (data['status'] ?? 'requested').toString().toLowerCase();
    final isPaid = status == 'paid';
    final isFailed = status == 'failed' || status == 'rejected';

    DateTime? createdAt;
    final ts = data['createdAt'];
    if (ts is Timestamp) {
      createdAt = ts.toDate();
    }

    final method = data['payoutMethod']?.toString().toUpperCase() ?? 'BANK';

    Color statusBg = tokens.warningBg;
    Color statusFg = tokens.warningFg;

    if (isPaid) {
      statusBg = tokens.successBg;
      statusFg = tokens.successFg;
    } else if (isFailed) {
      statusBg = tokens.errorBg;
      statusFg = tokens.errorFg;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: SaTokens.space12),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(SaTokens.radiusCard),
        border: Border.all(color: tokens.divider),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PayoutDetailsScreen(
                payoutId: docId,
                initialData: data,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(SaTokens.radiusCard),
        child: Padding(
          padding: const EdgeInsets.all(SaTokens.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    SaFormatters.formatCurrency(amount),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: tokens.textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusFg,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SaTokens.space8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.primarySubtle,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          method,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: tokens.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: SaTokens.space8),
                      if (createdAt != null)
                        Text(
                          SaFormatters.formatDate(createdAt),
                          style: TextStyle(
                            fontSize: SaTokens.fsCaption,
                            color: tokens.textSecondary,
                          ),
                        ),
                    ],
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: tokens.textSecondary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
