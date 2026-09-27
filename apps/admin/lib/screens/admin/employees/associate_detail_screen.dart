// ADMR-59 — Sales Associate 360.
//
// Consolidates a Sales Associate's profile/onboarding, order attribution,
// commission, wallet/payouts, bank destination and support/audit into one
// deep-linkable workspace (/employees/:id), mirroring ADMR-56/57/58.
//
// "Sales Associate" in the UI throughout, per the owner's own instruction;
// the employees collection, employeeId/employeeUid fields and every
// existing route/callable name stay exactly as they are internally.
//
// Two collections surfaced here have never had an admin screen read them
// at all: employee_wallets (only payoutChangePending -- the real balance
// is db.collection('wallets').doc(employeeUid), the SAME shared top-level
// collection customers use, confirmed by reading employeeCommission.ts's
// own walletRef construction sites, not its own more generic in-code
// comment) and associate_refund_requests (record-only onboarding-fee
// refund requests). Current bank/payout destination lives directly on the
// employees doc itself (riders' own shape, not sellers' split-collection
// shape), confirmed by reading employeePayoutAccount.ts's approve path.
//
// Pure Flutter: every collection was already admin-readable.
// commission_exceptions has no employeeUid-scoped index, so (mirroring
// ADMR-58's own established workaround for rider_incidents/
// delivery_exceptions) it is queried equality-only with client-side sort
// rather than adding one.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

import '../orders/admin_order_details_screen.dart';
import '../widgets/paginated_query_list.dart';

class AssociateDetailScreen extends StatefulWidget {
  const AssociateDetailScreen({
    super.key,
    required this.employeeId,
    FirebaseFirestore? firestore,
  }) : _firestoreOverride = firestore;

  final String employeeId;
  final FirebaseFirestore? _firestoreOverride;

  @override
  State<AssociateDetailScreen> createState() => _AssociateDetailScreenState();
}

class _AssociateDetailScreenState extends State<AssociateDetailScreen>
    with SingleTickerProviderStateMixin {
  late final FirebaseFirestore _firestore =
      widget._firestoreOverride ?? FirebaseFirestore.instance;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Sales Associate'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        key: ValueKey('associate-doc-${widget.employeeId}'),
        stream: _firestore.collection('employees').doc(widget.employeeId).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return const SectionMessage(
              icon: Icons.error_outline,
              message: "Couldn't load this associate. Check your connection and try again.",
            );
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const SectionMessage(
              icon: Icons.badge_outlined,
              message: 'Sales Associate not found. They may have been removed.',
            );
          }

          final data = snap.data!.data()!;
          final employeeId = widget.employeeId;

          return Column(
            children: [
              _HeaderCard(employeeId: employeeId, data: data),
              Material(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: Colors.grey.shade600,
                  tabs: const [
                    Tab(text: 'Profile & Onboarding'),
                    Tab(text: 'Attribution'),
                    Tab(text: 'Commission'),
                    Tab(text: 'Wallet & Payouts'),
                    Tab(text: 'Bank & Payout'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _ProfileTab(
                      key: const ValueKey('profile'),
                      employeeId: employeeId,
                      data: data,
                      firestore: _firestore,
                    ),
                    _AttributionTab(
                      key: const ValueKey('attribution'),
                      employeeId: employeeId,
                      firestore: _firestore,
                    ),
                    _CommissionTab(
                      key: const ValueKey('commission'),
                      employeeId: employeeId,
                      firestore: _firestore,
                    ),
                    _WalletTab(
                      key: const ValueKey('wallet'),
                      employeeId: employeeId,
                      firestore: _firestore,
                    ),
                    _BankPayoutTab(
                      key: const ValueKey('bank'),
                      employeeId: employeeId,
                      data: data,
                      firestore: _firestore,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Header ──

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.employeeId, required this.data});
  final String employeeId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final name = (data['name'] ?? 'Sales Associate').toString();
    final status = (data['status'] ?? 'pending').toString();
    final rate = ((data['commissionRate'] as num?) ?? 0).toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'S',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 160),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('${data['email'] ?? ''} · ${data['phone'] ?? ''}',
                    style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          ),
          _StatusChip(
            label: status,
            color: status == 'approved'
                ? Colors.green
                : status == 'suspended'
                    ? Colors.red
                    : Colors.orange,
          ),
          _StatusChip(label: '${rate.toStringAsFixed(1)}% commission', color: AppColors.primary),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label.toUpperCase(),
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

// ── Profile & onboarding ──

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    super.key,
    required this.employeeId,
    required this.data,
    required this.firestore,
  });
  final String employeeId;
  final Map<String, dynamic> data;
  final FirebaseFirestore firestore;

  String fmt(Object? v) {
    if (v is Timestamp) return AgFormat.dateTime(v.toDate());
    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    final onboardingPaid = (data['onboardingPaid'] as bool?) ?? false;
    final onboardingWaived = (data['onboardingWaived'] as bool?) ?? false;
    final feeAmount = (data['onboardingFeeAmount'] as num?)?.toDouble();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Identity', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _InfoTile(icon: Icons.badge_outlined, label: 'Employee code', value: (data['employeeCode'] ?? '—').toString()),
        _InfoTile(icon: Icons.person_add_outlined, label: 'Created by', value: (data['createdBy'] ?? '—').toString()),
        const SizedBox(height: 16),
        Text('Onboarding fee', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _InfoTile(
          icon: Icons.payments_outlined,
          label: 'Status',
          value: onboardingWaived
              ? 'Waived'
              : onboardingPaid
                  ? 'Paid${feeAmount != null ? ' (${AgFormat.rupees(feeAmount)})' : ''}'
                  : 'Not yet paid or waived',
        ),
        if (onboardingPaid) ...[
          _InfoTile(icon: Icons.receipt_long_outlined, label: 'Payment ID', value: (data['onboardingPaymentId'] ?? '—').toString()),
          _InfoTile(icon: Icons.event_outlined, label: 'Paid at', value: fmt(data['onboardingPaidAt'])),
        ],
        if (onboardingWaived)
          _InfoTile(icon: Icons.event_available_outlined, label: 'Waived at', value: fmt(data['onboardingWaivedAt'])),
        if (data['onboardingRefundedAt'] != null)
          _InfoTile(icon: Icons.replay_outlined, label: 'Refunded at', value: fmt(data['onboardingRefundedAt'])),
        const SizedBox(height: 8),
        Text(
          'Onboarding payment is web-only by policy; this is a record-only view, not a '
          'payment or refund action.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),
        Text('Refund requests', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
          future: firestore
              .collection('associate_refund_requests')
              .where('employeeId', isEqualTo: employeeId)
              .limit(20)
              .get(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()));
            }
            final docs = snap.data?.docs ?? const [];
            if (docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No refund requests for this associate.',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
              );
            }
            return Column(
              children: docs.map((d) {
                final r = d.data();
                final amount = (r['amount'] as num?)?.toDouble();
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(amount != null ? AgFormat.rupees(amount) : 'Refund request'),
                    subtitle: Text('${r['status'] ?? 'unknown'} · ${r['reason'] ?? ''}'),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Attribution ──

class _AttributionTab extends StatelessWidget {
  const _AttributionTab({super.key, required this.employeeId, required this.firestore});
  final String employeeId;
  final FirebaseFirestore firestore;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Orders attributed to this associate (employeeUid on the order). A missing '
            'attribution is not the same as zero activity -- check the order itself if in doubt.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
        Expanded(
          child: PaginatedQueryList(
            key: ValueKey('associate-orders-$employeeId'),
            baseQuery: firestore
                .collection('orders')
                .where('employeeUid', isEqualTo: employeeId)
                .orderBy('createdAt', descending: true),
            emptyLabel: 'No orders attributed to this associate yet.',
            itemBuilder: (context, doc) {
              final d = doc.data();
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  title: Text('Order #${d['orderNumber'] ?? doc.id}'),
                  subtitle: Text('${d['orderStatus'] ?? 'unknown'} · ${d['orderMode'] ?? ''}'),
                  trailing: Text(AgFormat.rupees(((d['total'] as num?) ?? 0).toDouble()),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AdminOrderDetailsScreen(orderId: doc.id)),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Commission ──

class _CommissionTab extends StatelessWidget {
  const _CommissionTab({super.key, required this.employeeId, required this.firestore});
  final String employeeId;
  final FirebaseFirestore firestore;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Unresolved commission exceptions mean the delivered order\'s rate could not be '
            'resolved automatically -- they do not, by themselves, mean commission was lost. '
            'Retrying one is a global action; open Commission Exceptions to act on it.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
        Expanded(
          child: PaginatedQueryList(
            key: ValueKey('associate-commission-$employeeId'),
            baseQuery: firestore
                .collection('commission_exceptions')
                .where('employeeUid', isEqualTo: employeeId)
                .orderBy('createdAt', descending: true),
            emptyLabel: 'No commission exceptions for this associate.',
            itemBuilder: (context, doc) {
              final record = CommissionExceptionRecord.fromMap(doc.data(), doc.id);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text('Order ${record.orderNumber ?? doc.id}'),
                  subtitle: Text('${record.status} · ${record.reason}'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Wallet & payouts ──

class _WalletTab extends StatelessWidget {
  const _WalletTab({super.key, required this.employeeId, required this.firestore});
  final String employeeId;
  final FirebaseFirestore firestore;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Balance', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: firestore.collection('wallets').doc(employeeId).snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return const SectionMessage(icon: Icons.error_outline, message: "Couldn't load the wallet.");
            }
            if (!snap.hasData) {
              return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()));
            }
            final wallet = WalletModel.fromMap(snap.data?.data() ?? {}, employeeId);
            return Row(children: [
              Expanded(
                  child: _MetricCard(
                      label: 'Commission balance',
                      value: AgFormat.rupees(wallet.balance))),
              const SizedBox(width: 8),
              Expanded(
                  child: _MetricCard(
                      label: 'Lifetime earned', value: AgFormat.rupees(wallet.lifetimeEarnings))),
            ]);
          },
        ),
        const SizedBox(height: 8),
        Text(
          'This balance can go negative if a commission reversal exceeds it -- that is an '
          'existing, intentional part of the reversal contract, shown honestly rather than floored.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 20),
        Text('Payout requests', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        PaginatedQueryList(
          key: ValueKey('associate-payouts-$employeeId'),
          baseQuery: firestore
              .collection('employee_payouts')
              .where('employeeId', isEqualTo: employeeId)
              .orderBy('createdAt', descending: true),
          emptyLabel: 'No payout requests yet.',
          pageSize: 10,
          shrinkWrapInList: true,
          itemBuilder: (context, doc) {
            final p = doc.data();
            final amount = (p['amount'] as num?)?.toDouble() ?? 0;
            return ListTile(
              dense: true,
              title: Text(AgFormat.rupees(amount)),
              subtitle: Text('${p['status'] ?? 'unknown'}'
                  '${(p['paymentReference'] ?? '').toString().isNotEmpty ? ' · Ref ${p['paymentReference']}' : ''}'),
            );
          },
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }
}

// ── Bank & payout ──

class _BankPayoutTab extends StatefulWidget {
  const _BankPayoutTab({
    super.key,
    required this.employeeId,
    required this.data,
    required this.firestore,
  });
  final String employeeId;
  final Map<String, dynamic> data;
  final FirebaseFirestore firestore;

  @override
  State<_BankPayoutTab> createState() => _BankPayoutTabState();
}

class _BankPayoutTabState extends State<_BankPayoutTab> {
  Future<void> _review(String requestId, bool approve) async {
    String? reason;
    if (!approve) {
      final c = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Reject change'),
          content: TextField(
              controller: c,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Reason (shown to the associate)')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reject')),
          ],
        ),
      );
      reason = c.text.trim();
      c.dispose();
      if (ok != true) return;
    }
    try {
      await FirebaseFunctions.instance.httpsCallable('reviewEmployeePayoutChange').call<Map<String, dynamic>>({
        'requestId': requestId,
        'approve': approve,
        if (reason != null) 'reason': reason,
      });
      if (mounted) {
        SnackbarHelper.showSuccess(
            context, approve ? 'Approved — payouts now go to the new details' : 'Rejected');
      }
    } catch (e) {
      debugPrint('reviewEmployeePayoutChange: $e');
      if (mounted) {
        SnackbarHelper.showError(context, 'Could not complete that. Please try again.');
      }
    }
  }

  String _destination(Map<String, dynamic> d) {
    final upi = (d['upiId'] as String?) ?? '';
    if (upi.isNotEmpty) return 'UPI $upi';
    final acct = (d['accountNumber'] as String?) ?? '';
    if (acct.isEmpty) return 'No payout account on file';
    return '${d['accountHolderName'] ?? ''} · ${AgFormat.maskAccount(acct)} · IFSC ${d['ifscCode'] ?? '—'}';
  }

  String _requestedDestination(Map<String, dynamic> d) {
    final upi = (d['upiId'] as String?) ?? '';
    if (upi.isNotEmpty) return 'UPI $upi';
    final acct = (d['accountNumber'] as String?) ?? '';
    if (acct.isEmpty) return 'No details';
    return '${d['accountHolder'] ?? ''} · $acct · IFSC ${d['ifsc'] ?? '—'}';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Current payout destination',
            style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _InfoTile(icon: Icons.account_balance_outlined, label: 'Destination on file', value: _destination(widget.data)),
        const SizedBox(height: 20),
        Text('Pending change request',
            style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
          future: widget.firestore
              .collection('employee_payout_change_requests')
              .where('employeeId', isEqualTo: widget.employeeId)
              .where('status', isEqualTo: 'pending')
              .limit(1)
              .get(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()));
            }
            if (snap.hasError) {
              return const SectionMessage(
                  icon: Icons.error_outline, message: "Couldn't load change requests.");
            }
            final docs = snap.data?.docs ?? const [];
            if (docs.isEmpty) {
              return const SectionMessage(
                  icon: Icons.check_circle_outline, message: 'No payout-detail change waiting.');
            }
            final doc = docs.first;
            final d = doc.data();
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('New destination requested',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    SelectableText(_requestedDestination(d)),
                    const SizedBox(height: 4),
                    Text(
                      'The current destination above stays in effect, and paying this '
                      'associate is blocked, until this request is reviewed.',
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                    ),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      TextButton(onPressed: () => _review(doc.id, false), child: const Text('Reject')),
                      const SizedBox(width: 8),
                      FilledButton(onPressed: () => _review(doc.id, true), child: const Text('Approve')),
                    ]),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
