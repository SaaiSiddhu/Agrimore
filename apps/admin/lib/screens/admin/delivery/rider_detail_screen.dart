// ADMR-58 — Delivery Partner 360.
//
// Consolidates a rider's identity/verification, availability/assignment,
// earnings, COD/cash, bank/payout destination and support/audit into one
// deep-linkable workspace (/delivery-partners/:id), mirroring ADMR-56/57.
//
// Heavy reuse, not duplication: embeds RiderReviewSheet verbatim for
// identity/verification (its KYC document previews, masked identity/bank
// rows and status-conditioned review actions are already correct); links
// out to the existing RiderCashLedgerScreen (ADMR-52) for the full cash
// history rather than embedding it (it owns its own Scaffold/AppBar, so
// embedding would render a nested app bar); reuses the existing
// reviewRiderIdentityChange/reviewDocumentSubmission/reviewRiderBankChange
// callables directly for this rider's own pending changes, rather than the
// global tabs' widgets.
//
// Every collection here is already admin-readable with a uniform riderId
// field (confirmed by reading firestore.rules before scoping). rider_
// incidents/delivery_exceptions have only a (status, createdAt) index, not
// (riderId, createdAt) -- rather than add a new index, this queries them
// equality-only and sorts client-side, mirroring rider_payouts_screen.
// dart's own established _StatementsTab convention. No rules, index or
// functions change.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

import '../orders/admin_order_details_screen.dart';
import '../widgets/paginated_query_list.dart';
import 'rider_cash_ledger_screen.dart';
import 'rider_review_sheet.dart';

class RiderDetailScreen extends StatefulWidget {
  const RiderDetailScreen({
    super.key,
    required this.riderId,
    FirebaseFirestore? firestore,
  }) : _firestoreOverride = firestore;

  final String riderId;
  final FirebaseFirestore? _firestoreOverride;

  @override
  State<RiderDetailScreen> createState() => _RiderDetailScreenState();
}

class _RiderDetailScreenState extends State<RiderDetailScreen>
    with SingleTickerProviderStateMixin {
  late final FirebaseFirestore _firestore =
      widget._firestoreOverride ?? FirebaseFirestore.instance;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
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
        title: const Text('Delivery Partner'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        key: ValueKey('rider-doc-${widget.riderId}'),
        stream: _firestore.collection('delivery_partners').doc(widget.riderId).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return const SectionMessage(
              icon: Icons.error_outline,
              message: "Couldn't load this delivery partner. Check your connection and try again.",
            );
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const SectionMessage(
              icon: Icons.no_accounts_outlined,
              message: 'Delivery partner not found. They may have been removed.',
            );
          }

          final data = snap.data!.data()!;
          final rider = DeliveryPartnerModel.fromMap(data, widget.riderId);
          final riderId = widget.riderId;

          return Column(
            children: [
              _HeaderCard(rider: rider),
              Material(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: Colors.grey.shade600,
                  tabs: const [
                    Tab(text: 'Identity & Verification'),
                    Tab(text: 'Assignments'),
                    Tab(text: 'Earnings'),
                    Tab(text: 'COD & Cash'),
                    Tab(text: 'Bank & Payout'),
                    Tab(text: 'Support & Audit'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _IdentityTab(
                      key: const ValueKey('identity'),
                      riderId: riderId,
                      data: data,
                      firestore: _firestore,
                    ),
                    _AssignmentsTab(
                      key: const ValueKey('assignments'),
                      rider: rider,
                      firestore: _firestore,
                    ),
                    _EarningsTab(
                      key: const ValueKey('earnings'),
                      riderId: riderId,
                      firestore: _firestore,
                    ),
                    _CodCashTab(
                      key: const ValueKey('cod'),
                      riderId: riderId,
                      firestore: _firestore,
                    ),
                    _BankPayoutTab(
                      key: const ValueKey('bank'),
                      riderId: riderId,
                      data: data,
                      firestore: _firestore,
                    ),
                    _SupportTab(
                      key: const ValueKey('support'),
                      riderId: riderId,
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
  const _HeaderCard({required this.rider});
  final DeliveryPartnerModel rider;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                backgroundImage: rider.photoUrl != null ? NetworkImage(rider.photoUrl!) : null,
                child: rider.photoUrl == null
                    ? Text(rider.name.isNotEmpty ? rider.name[0].toUpperCase() : 'P',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: rider.isOnline ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 160),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(rider.name.isEmpty ? 'Unnamed partner' : rider.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(rider.phone, style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          ),
          _StatusChip(
            label: rider.isOnline ? 'Online' : 'Offline',
            color: rider.isOnline ? Colors.green : Colors.grey,
          ),
          _StatusChip(label: '${rider.totalDeliveries} deliveries', color: AppColors.primary),
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
      child: Text(label,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Identity & verification ──

class _IdentityTab extends StatelessWidget {
  const _IdentityTab({
    super.key,
    required this.riderId,
    required this.data,
    required this.firestore,
  });
  final String riderId;
  final Map<String, dynamic> data;
  final FirebaseFirestore firestore;

  Future<void> _askReasonAndCall(
    BuildContext context, {
    required String callableName,
    required String requestId,
    required bool approve,
    required String title,
  }) async {
    String? reason;
    if (!approve) {
      final c = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: TextField(
              controller: c,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Reason (shown to the rider)')),
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
      await FirebaseFunctions.instance.httpsCallable(callableName).call<Map<String, dynamic>>({
        'requestId': requestId,
        'approve': approve,
        if (reason != null) 'reason': reason,
      });
      if (context.mounted) {
        SnackbarHelper.showSuccess(context, approve ? 'Approved' : 'Rejected');
      }
    } catch (e) {
      debugPrint('$callableName: $e');
      if (context.mounted) {
        SnackbarHelper.showError(context, 'Could not complete that. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // RiderReviewSheet embedded verbatim -- its own KYC doc previews,
        // masked identity/bank rows and review actions, unchanged.
        RiderReviewSheet(uid: riderId, data: data),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Divider(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text('Pending changes',
              style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
        FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
          future: firestore
              .collection('rider_identity_change_requests')
              .where('riderId', isEqualTo: riderId)
              .where('status', isEqualTo: 'pending')
              .limit(5)
              .get(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                  padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()));
            }
            final docs = snap.data?.docs ?? const [];
            if (docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text('No identity change waiting.',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
              );
            }
            return Column(
              children: docs.map((d) {
                final v = d.data();
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Change: ${v['changeType'] ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('Reason: ${v['reason'] ?? ''}'),
                        const SizedBox(height: 8),
                        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                          TextButton(
                            onPressed: () => _askReasonAndCall(
                              context,
                              callableName: 'reviewRiderIdentityChange',
                              requestId: d.id,
                              approve: false,
                              title: 'Reject identity change',
                            ),
                            child: const Text('Reject'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () => _askReasonAndCall(
                              context,
                              callableName: 'reviewRiderIdentityChange',
                              requestId: d.id,
                              approve: true,
                              title: 'Approve identity change',
                            ),
                            child: const Text('Approve'),
                          ),
                        ]),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text('Pending document resubmissions',
              style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
        FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
          future: firestore
              .collection('document_review_submissions')
              .where('riderId', isEqualTo: riderId)
              .where('status', isEqualTo: 'pending')
              .limit(5)
              .get(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                  padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()));
            }
            final docs = snap.data?.docs ?? const [];
            if (docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Text('No document resubmission waiting.',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
              );
            }
            return Column(
              children: [
                for (final d in docs)
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${d.data()['docType'] ?? 'Document'}',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                            TextButton(
                              onPressed: () => _askReasonAndCall(
                                context,
                                callableName: 'reviewDocumentSubmission',
                                requestId: d.id,
                                approve: false,
                                title: 'Reject document',
                              ),
                              child: const Text('Reject'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () => _askReasonAndCall(
                                context,
                                callableName: 'reviewDocumentSubmission',
                                requestId: d.id,
                                approve: true,
                                title: 'Approve document',
                              ),
                              child: const Text('Approve'),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ── Assignments ──

class _AssignmentsTab extends StatelessWidget {
  const _AssignmentsTab({super.key, required this.rider, required this.firestore});
  final DeliveryPartnerModel rider;
  final FirebaseFirestore firestore;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Online means available to be offered an order, not currently assigned one -- '
            'check the most recent order below for the actual current assignment.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
        Expanded(
          child: PaginatedQueryList(
            key: ValueKey('rider-orders-${rider.id}'),
            baseQuery: firestore
                .collection('orders')
                .where('deliveryPartnerId', isEqualTo: rider.id)
                .orderBy('createdAt', descending: true),
            emptyLabel: 'No assignments for this rider yet.',
            itemBuilder: (context, doc) {
              final d = doc.data();
              final orderNumber = (d['orderNumber'] ?? doc.id).toString();
              final status = (d['orderStatus'] ?? 'unknown').toString();
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  title: Text('Order #$orderNumber'),
                  subtitle: Text(status),
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

// ── Earnings ──

class _EarningsTab extends StatelessWidget {
  const _EarningsTab({super.key, required this.riderId, required this.firestore});
  final String riderId;
  final FirebaseFirestore firestore;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Per-delivery earning lines, newest first. This is history, not a lifetime '
            'total -- see the rider\'s own statements for settled totals.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
        Expanded(
          child: PaginatedQueryList(
            key: ValueKey('rider-earnings-$riderId'),
            baseQuery: firestore
                .collection('rider_earnings')
                .where('riderId', isEqualTo: riderId)
                .orderBy('createdAt', descending: true),
            emptyLabel: 'No earnings recorded yet.',
            itemBuilder: (context, doc) =>
                _EarningTile(record: RiderEarningRecord.fromMap(doc.data(), doc.id)),
          ),
        ),
      ],
    );
  }
}

class _EarningTile extends StatelessWidget {
  const _EarningTile({required this.record});
  final RiderEarningRecord record;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text('Order ${record.orderNumber ?? record.orderId}'),
        subtitle: Text(
            '${record.km.toStringAsFixed(1)} km (${record.kmSource})'
            '${record.statementId != null ? ' · statement ${record.statementId}' : ' · not yet in a statement'}'),
        trailing: Text(AgFormat.rupees(record.total), style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ── COD & cash ──

class _CodCashTab extends StatelessWidget {
  const _CodCashTab({super.key, required this.riderId, required this.firestore});
  final String riderId;
  final FirebaseFirestore firestore;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: firestore.collection('rider_accounts').doc(riderId).get(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()));
            }
            if (snap.hasError) {
              return const SectionMessage(
                  icon: Icons.error_outline, message: "Couldn't load the cash account.");
            }
            final account =
                RiderCashAccountRecord.fromMap(snap.data?.data() ?? {}, riderId);
            return _MetricCard(
                label: 'Cash currently held', value: AgFormat.rupees(account.cashHeld));
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Cash collected on delivery, a deposit and a netted-against-payout '
          'event are three distinct ledger entries -- see the full history below.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => RiderCashLedgerScreen(riderId: riderId)),
          ),
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('View full cash ledger'),
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
    required this.riderId,
    required this.data,
    required this.firestore,
  });
  final String riderId;
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
              decoration: const InputDecoration(labelText: 'Reason (shown to the rider)')),
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
      final r = await FirebaseFunctions.instance
          .httpsCallable('reviewRiderBankChange')
          .call<Map<String, dynamic>>({
        'requestId': requestId,
        'approve': approve,
        if (reason != null) 'reason': reason,
      });
      final released = (r.data['released'] as num?)?.toInt() ?? 0;
      if (mounted) {
        SnackbarHelper.showSuccess(context,
            '${approve ? 'Approved' : 'Rejected'}${released > 0 ? ' · $released held statement${released == 1 ? '' : 's'} released' : ''}');
      }
    } catch (e) {
      debugPrint('reviewRiderBankChange: $e');
      if (mounted) {
        SnackbarHelper.showError(context, 'Could not complete that. Please try again.');
      }
    }
  }

  String _destination(Map<String, dynamic> d) {
    final upi = (d['upiId'] as String?) ?? '';
    if (upi.isNotEmpty) return 'UPI $upi';
    final acct = (d['bankAccountNumber'] as String?) ?? '';
    if (acct.isEmpty) return 'No payout account on file';
    return '${d['accountHolderName'] ?? ''} · ${AgFormat.maskAccount(acct)} · IFSC ${d['ifscCode'] ?? '—'}';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Current payout destination',
            style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Text(_destination(widget.data)),
        ),
        const SizedBox(height: 20),
        Text('Pending change request',
            style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
          future: widget.firestore
              .collection('rider_bank_change_requests')
              .where('riderId', isEqualTo: widget.riderId)
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
                    SelectableText(_destination(d)),
                    const SizedBox(height: 4),
                    Text(
                      'The current destination above stays in effect, and paying this '
                      'rider is blocked, until this request is reviewed.',
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

// ── Support & audit ──

class _SupportTab extends StatelessWidget {
  const _SupportTab({super.key, required this.riderId, required this.firestore});
  final String riderId;
  final FirebaseFirestore firestore;

  Widget _list({
    required String collection,
    required String field,
    required String emptyLabel,
    required Widget Function(Map<String, dynamic>) itemBuilder,
  }) {
    return PaginatedQueryList(
      key: ValueKey('rider-$collection-$riderId'),
      baseQuery: firestore
          .collection(collection)
          .where(field, isEqualTo: riderId)
          .orderBy('createdAt', descending: true),
      emptyLabel: emptyLabel,
      pageSize: 10,
      shrinkWrapInList: true,
      itemBuilder: (context, doc) =>
          Card(margin: const EdgeInsets.only(bottom: 6), child: itemBuilder(doc.data())),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Support tickets', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _list(
          collection: 'rider_support_tickets',
          field: 'riderId',
          emptyLabel: 'No support tickets from this rider.',
          itemBuilder: (d) => ListTile(
            dense: true,
            title: Text((d['subject'] ?? d['message'] ?? 'Ticket').toString()),
            subtitle: Text((d['status'] ?? 'unknown').toString()),
          ),
        ),
        const SizedBox(height: 20),
        Text('Incidents', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _list(
          collection: 'rider_incidents',
          field: 'riderId',
          emptyLabel: 'No incidents reported for this rider.',
          itemBuilder: (d) => ListTile(
            dense: true,
            title: Text((d['type'] ?? 'Incident').toString()),
            subtitle: Text((d['status'] ?? 'unknown').toString()),
          ),
        ),
        const SizedBox(height: 20),
        Text('Delivery exceptions',
            style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _list(
          collection: 'delivery_exceptions',
          field: 'riderId',
          emptyLabel: 'No delivery exceptions reported for this rider.',
          itemBuilder: (d) => ListTile(
            dense: true,
            title: Text((d['reason'] ?? d['type'] ?? 'Exception').toString()),
            subtitle: Text((d['status'] ?? 'unknown').toString()),
          ),
        ),
      ],
    );
  }
}
