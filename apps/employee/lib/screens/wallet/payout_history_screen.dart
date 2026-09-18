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
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        backgroundColor: SaTokens.pageBackground,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: SaTokens.pageBackground,
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
            color: SaTokens.surface,
            padding: const EdgeInsets.symmetric(
              horizontal: SaTokens.space16,
              vertical: SaTokens.space12,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All Payouts', _PayoutStatusFilter.all),
                  const SizedBox(width: SaTokens.space8),
                  _buildFilterChip('Requested', _PayoutStatusFilter.requested),
                  const SizedBox(width: SaTokens.space8),
                  _buildFilterChip('Paid / Settled', _PayoutStatusFilter.paid),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: SaTokens.divider),

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
                      child: Text('Error loading payouts: ${snap.error}'),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
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
                            decoration: const BoxDecoration(
                              color: SaTokens.primarySubtle,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              SaIcons.wallet,
                              size: 32,
                              color: SaTokens.primary,
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
                    return _buildPayoutCard(context, doc.id, d);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, _PayoutStatusFilter filter) {
    final selected = _statusFilter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (val) {
        if (val) setState(() => _statusFilter = filter);
      },
      selectedColor: SaTokens.primarySubtle,
      backgroundColor: SaTokens.surface,
      labelStyle: TextStyle(
        fontSize: SaTokens.fsLabel,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: selected ? SaTokens.primary : SaTokens.textSecondary,
      ),
      side: BorderSide(
        color: selected ? SaTokens.primary : SaTokens.divider,
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

    Color statusBg = SaTokens.warningBg;
    Color statusFg = SaTokens.warningFg;

    if (isPaid) {
      statusBg = SaTokens.successBg;
      statusFg = SaTokens.successFg;
    } else if (isFailed) {
      statusBg = SaTokens.errorBg;
      statusFg = SaTokens.errorFg;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: SaTokens.space12),
      decoration: BoxDecoration(
        color: SaTokens.surface,
        borderRadius: BorderRadius.circular(SaTokens.radiusCard),
        border: Border.all(color: SaTokens.divider),
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
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: SaTokens.textPrimary,
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
                          color: SaTokens.primarySubtle,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          method,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: SaTokens.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: SaTokens.space8),
                      if (createdAt != null)
                        Text(
                          SaFormatters.formatDate(createdAt),
                          style: const TextStyle(
                            fontSize: SaTokens.fsCaption,
                            color: SaTokens.textSecondary,
                          ),
                        ),
                    ],
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: SaTokens.textSecondary,
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
