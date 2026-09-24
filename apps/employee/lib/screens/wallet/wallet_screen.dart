import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../utils/sa_formatters.dart';
import 'payout_request_screen.dart';
import 'payout_history_screen.dart';
import 'payout_account_screen.dart';

enum _TransactionFilter { all, credits, debits }

/// Dedicated Sales Associate Wallet screen.
///
/// Features:
/// - Balance hero card with available balance & lifetime commission.
/// - Quick action pills: "Request payout", "Payout history", "Payout account".
/// - Filter chips: All, Credits, Debits.
/// - Paginated ledger stream on `wallet_transactions` where `userId == uid`.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  int _pageSize = 20;
  _TransactionFilter _filter = _TransactionFilter.all;

  @override
  Widget build(BuildContext context) {
    final tokens = context.saTokens;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        backgroundColor: tokens.pageBackground,
        body: const SizedBox.shrink(),
      );
    }

    return Scaffold(
      backgroundColor: tokens.pageBackground,
      appBar: AppBar(
        title: const Text('Commission Wallet'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(SaTokens.space16),
        children: [
          // 1. Balance Hero Card
          _buildBalanceHero(context, uid),
          const SizedBox(height: SaTokens.space16),

          // 2. Quick Action Buttons
          _buildQuickActions(context),
          const SizedBox(height: SaTokens.space24),

          // 3. Transactions Section Header & Filter Chips
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Transaction History',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: SaTokens.space12),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(context, 'All Transactions', _TransactionFilter.all),
                const SizedBox(width: SaTokens.space8),
                _buildFilterChip(context, 'Credits', _TransactionFilter.credits),
                const SizedBox(width: SaTokens.space8),
                _buildFilterChip(context, 'Debits / Payouts', _TransactionFilter.debits),
              ],
            ),
          ),
          const SizedBox(height: SaTokens.space12),

          // 4. Ledger Transaction List
          _buildTransactionsList(context, uid),
        ],
      ),
    );
  }

  Widget _buildBalanceHero(BuildContext context, String uid) {
    final tokens = context.saTokens;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('wallets')
          .doc(uid)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final balance = (data?['balance'] as num?)?.toDouble() ?? 0.0;
        final lifetimeEarnings =
            (data?['lifetimeEarnings'] as num?)?.toDouble() ?? 0.0;

        return Container(
          padding: const EdgeInsets.all(SaTokens.space24),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(SaTokens.radiusCard),
            border: Border.all(color: tokens.primary, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: tokens.primary.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      'Available Balance',
                      style: TextStyle(
                        fontSize: SaTokens.fsCaption,
                        fontWeight: FontWeight.w600,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: SaTokens.space8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.primarySubtle,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Ready for Payout',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: tokens.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SaTokens.space4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  SaFormatters.formatCurrency(balance),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: tokens.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: SaTokens.space12),
              Divider(color: tokens.divider),
              const SizedBox(height: SaTokens.space8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      'Lifetime Commission',
                      style: TextStyle(
                        fontSize: SaTokens.fsCaption,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: SaTokens.space8),
                  Text(
                    SaFormatters.formatCurrency(lifetimeEarnings),
                    style: TextStyle(
                      fontSize: SaTokens.fsBody,
                      fontWeight: FontWeight.w700,
                      color: tokens.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionTile(
            icon: SaIcons.arrowLeft, // inverted arrow for payout out
            iconWidget: Icon(Icons.arrow_upward_rounded,
                color: Theme.of(context).colorScheme.onPrimary, size: 18),
            label: 'Request Payout',
            isPrimary: true,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PayoutRequestScreen(),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: SaTokens.space8),
        Expanded(
          child: _ActionTile(
            icon: SaIcons.rotateCcw,
            label: 'Payout History',
            isPrimary: false,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PayoutHistoryScreen(),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: SaTokens.space8),
        Expanded(
          child: _ActionTile(
            icon: Icons.account_balance_outlined,
            label: 'Payout Account',
            isPrimary: false,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PayoutAccountScreen(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(BuildContext context, String label, _TransactionFilter filter) {
    final tokens = context.saTokens;
    final selected = _filter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (val) {
        if (val) setState(() => _filter = filter);
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

  Widget _buildTransactionsList(BuildContext context, String uid) {
    final tokens = context.saTokens;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('wallet_transactions')
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(_pageSize)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(SaTokens.space16),
              child: Text(
                'Error: ${snap.error}',
                style: TextStyle(color: tokens.textSecondary),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const SizedBox.shrink();
        }

        final allDocs = snap.data!.docs;

        final filteredDocs = allDocs.where((doc) {
          final data = doc.data();
          final type = (data['type'] ?? 'credit').toString().toLowerCase();
          final isCredit = type == 'credit';

          if (_filter == _TransactionFilter.credits && !isCredit) return false;
          if (_filter == _TransactionFilter.debits && isCredit) return false;
          return true;
        }).toList();

        if (filteredDocs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(SaTokens.space32),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(SaTokens.radiusCard),
              border: Border.all(color: tokens.divider),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    SaIcons.wallet,
                    size: 32,
                    color: tokens.textSecondary,
                  ),
                  const SizedBox(height: SaTokens.space8),
                  Text(
                    'No transactions recorded',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: tokens.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
          );
        }

        final reachedPageLimit = allDocs.length >= _pageSize;

        return Column(
          children: [
            ...filteredDocs.map((doc) {
              final d = doc.data();
              return _buildTransactionCard(context, d);
            }),
            if (reachedPageLimit) ...[
              const SizedBox(height: SaTokens.space8),
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _pageSize += 20),
                  child: const Text('Load more transactions'),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildTransactionCard(BuildContext context, Map<String, dynamic> d) {
    final tokens = context.saTokens;
    final amount = (d['amount'] as num?)?.toDouble() ?? 0.0;
    final type = (d['type'] ?? 'credit').toString().toLowerCase();
    final isCredit = type == 'credit';
    final description = d['description']?.toString() ??
        (isCredit ? 'Commission credit' : 'Payout debit');
    final source = d['source']?.toString() ?? (isCredit ? 'order' : 'payout');

    DateTime? createdAt;
    final ts = d['createdAt'];
    if (ts is Timestamp) {
      createdAt = ts.toDate();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: SaTokens.space8),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(SaTokens.radiusCard),
        border: Border.all(color: tokens.divider),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: SaTokens.space16,
          vertical: 4,
        ),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isCredit ? tokens.successBg : tokens.pageBackground,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
            size: 18,
            color: isCredit ? tokens.successFg : tokens.textSecondary,
          ),
        ),
        title: Text(
          description,
          style: TextStyle(
            fontSize: SaTokens.fsBody,
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
          ),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: tokens.pageBackground,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                source.toUpperCase(),
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: tokens.textSecondary,
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
        trailing: Text(
          '${isCredit ? "+" : "-"} ${SaFormatters.formatCurrency(amount)}',
          style: TextStyle(
            fontSize: SaTokens.fsBody,
            fontWeight: FontWeight.w800,
            color: isCredit ? tokens.successFg : tokens.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Widget? iconWidget;
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    this.iconWidget,
    required this.label,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.saTokens;
    // UI-SA1: text on the primary fill follows the theme (navy in dark mode).
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SaTokens.radiusInput),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: SaTokens.space8,
          vertical: SaTokens.space12,
        ),
        decoration: BoxDecoration(
          color: isPrimary ? tokens.primary : tokens.surface,
          borderRadius: BorderRadius.circular(SaTokens.radiusInput),
          border: Border.all(
            color: isPrimary ? tokens.primary : tokens.divider,
          ),
        ),
        child: Column(
          children: [
            iconWidget ??
                Icon(
                  icon,
                  size: 20,
                  color: isPrimary ? onPrimary : tokens.primary,
                ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isPrimary ? onPrimary : tokens.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
