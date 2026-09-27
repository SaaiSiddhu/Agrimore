// ADMR-57 — Seller 360.
//
// Consolidates a seller's identity/store, catalog, fulfillment, finance
// and bank/payout destination into one deep-linkable workspace (mirrors
// ADMR-56's Customer 360). ManageSellersScreen's own card tap used to go
// straight to the edit-only EditSellerScreen -- the exact shape
// UserManagementScreen had before ADMR-56 -- with no consolidated view
// anywhere. Scoped to already-approved sellers, matching
// ManageSellersScreen's own existing boundary; a not-yet-approved
// applicant has no `sellers` doc yet and stays in
// SellerRequestsManagementScreen's own queue, untouched.
//
// Every collection and composite index this screen needs was already
// admin-readable/indexed before this phase -- confirmed by reading
// firestore.rules and firestore.indexes.json, and by the fact that
// seller_wallet_admin.dart/seller_payouts_screen.dart already read every
// one of them client-side. No rules, index or functions change.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

import '../orders/admin_order_details_screen.dart';
import '../products/product_form_screen.dart';
import '../widgets/actor_support_cases_section.dart';
import '../widgets/paginated_query_list.dart';
import 'edit_seller_screen.dart';

class SellerDetailScreen extends StatefulWidget {
  const SellerDetailScreen({
    super.key,
    required this.sellerId,
    FirebaseFirestore? firestore,
  }) : _firestoreOverride = firestore;

  final String sellerId;
  final FirebaseFirestore? _firestoreOverride;

  @override
  State<SellerDetailScreen> createState() => _SellerDetailScreenState();
}

class _SellerDetailScreenState extends State<SellerDetailScreen>
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
        title: const Text('Seller'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        key: ValueKey('seller-doc-${widget.sellerId}'),
        stream: _firestore.collection('sellers').doc(widget.sellerId).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return const SectionMessage(
              icon: Icons.error_outline,
              message: "Couldn't load this seller. Check your connection and try again.",
            );
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const SectionMessage(
              icon: Icons.storefront_outlined,
              message: 'Seller not found, or not yet approved. Not-yet-approved '
                  'applications are reviewed under Seller Requests.',
            );
          }

          final data = snap.data!.data()!;
          final sellerId = widget.sellerId;

          return Column(
            children: [
              _HeaderCard(
                sellerId: sellerId,
                data: data,
                onEdit: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditSellerScreen(sellerId: sellerId, initialData: data),
                  ),
                ),
              ),
              Material(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: Colors.grey.shade600,
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Catalog'),
                    Tab(text: 'Orders'),
                    Tab(text: 'Finance'),
                    Tab(text: 'Bank & Payout'),
                    Tab(text: 'Support & Audit'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _OverviewTab(
                      key: const ValueKey('overview'),
                      sellerId: sellerId,
                      data: data,
                      firestore: _firestore,
                    ),
                    _CatalogTab(
                      key: const ValueKey('catalog'),
                      sellerId: sellerId,
                      firestore: _firestore,
                    ),
                    _OrdersTab(
                      key: const ValueKey('orders'),
                      sellerId: sellerId,
                      firestore: _firestore,
                    ),
                    _FinanceTab(
                      key: const ValueKey('finance'),
                      sellerId: sellerId,
                      firestore: _firestore,
                    ),
                    _BankPayoutTab(
                      key: const ValueKey('bank'),
                      sellerId: sellerId,
                      firestore: _firestore,
                    ),
                    _SupportTab(
                      key: const ValueKey('support'),
                      sellerId: sellerId,
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
  const _HeaderCard({required this.sellerId, required this.data, required this.onEdit});
  final String sellerId;
  final Map<String, dynamic> data;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final shopName = (data['shopName'] ?? 'Shop').toString();
    final logoUrl = (data['logoUrl'] as String?)?.trim();
    final status = (data['status'] ?? 'unknown').toString();

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
            backgroundImage: (logoUrl != null && logoUrl.isNotEmpty) ? NetworkImage(logoUrl) : null,
            child: (logoUrl == null || logoUrl.isEmpty)
                ? const Icon(Icons.storefront_rounded, color: AppColors.primary)
                : null,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 160),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(shopName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('${data['name'] ?? ''} · ${data['email'] ?? ''}',
                    style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          ),
          _StatusChip(
            label: status == 'approved' ? 'Approved' : status,
            color: status == 'approved' ? Colors.green : Colors.orange,
          ),
          ElevatedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit profile'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
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

// ── Overview ──

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    super.key,
    required this.sellerId,
    required this.data,
    required this.firestore,
  });
  final String sellerId;
  final Map<String, dynamic> data;
  final FirebaseFirestore firestore;

  String _str(String key) => (data[key] ?? '').toString();

  @override
  Widget build(BuildContext context) {
    final createdAt = data['createdAt'];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionHeader('Store'),
        _InfoTile(icon: Icons.storefront_outlined, label: 'Shop name', value: _str('shopName')),
        _InfoTile(
            icon: Icons.location_on_outlined,
            label: 'Shop address',
            value: _str('shopAddress').isEmpty ? 'Not provided' : _str('shopAddress')),
        _InfoTile(
            icon: Icons.category_outlined,
            label: 'Business category',
            value: _str('businessCategory').isEmpty ? 'Not provided' : _str('businessCategory')),
        _InfoTile(
            icon: Icons.badge_outlined,
            label: 'GSTIN',
            value: _str('gstin').isEmpty ? 'Not provided' : _str('gstin')),
        _InfoTile(
            icon: Icons.map_outlined,
            label: 'City / State / Pincode',
            value: '${_str('city')}, ${_str('state')} ${_str('pincode')}'.trim()),
        const SizedBox(height: 16),
        const _SectionHeader('Contact'),
        _InfoTile(icon: Icons.person_outline, label: 'Owner name', value: _str('name')),
        _InfoTile(icon: Icons.email_outlined, label: 'Email', value: _str('email')),
        _InfoTile(icon: Icons.phone_outlined, label: 'Mobile', value: _str('mobile')),
        const SizedBox(height: 16),
        const _SectionHeader('Verification'),
        _InfoTile(
            icon: Icons.verified_outlined,
            label: 'Approval status',
            value: _str('status').isEmpty ? 'unknown' : _str('status')),
        _InfoTile(
            icon: Icons.calendar_today_outlined,
            label: 'Approved / profile created',
            value: createdAt is Timestamp ? AgFormat.dateTime(createdAt.toDate()) : 'Unknown'),
        const SizedBox(height: 8),
        Text(
          'Approval status is the platform decision to let this seller trade. It '
          'is separate from whether their store is currently open (their own '
          'operating hours, set in the seller app) and separate from any '
          'platform restriction placed on them -- none of these are combined '
          'into one figure.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child:
          Text(title, style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
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
                Text(value.isEmpty ? 'Not provided' : value,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Catalog ──

class _CatalogTab extends StatelessWidget {
  const _CatalogTab({super.key, required this.sellerId, required this.firestore});
  final String sellerId;
  final FirebaseFirestore firestore;

  @override
  Widget build(BuildContext context) {
    return PaginatedQueryList(
      key: ValueKey('catalog-$sellerId'),
      baseQuery: firestore
          .collection('products')
          .where('sellerId', isEqualTo: sellerId)
          .orderBy('createdAt', descending: true),
      emptyLabel: 'No products listed yet.',
      itemBuilder: (context, doc) {
        final d = doc.data();
        final name = (d['name'] ?? 'Product').toString();
        final isActive = (d['isActive'] as bool?) ?? true;
        final isDraft = (d['isDraft'] as bool?) ?? false;
        final stock = (d['stock'] as num?)?.toInt() ?? 0;
        final price = (d['salePrice'] as num?)?.toDouble() ?? 0;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            title: Text(name),
            subtitle: Text(isDraft
                ? 'Draft (not published)'
                : '${isActive ? 'Active' : 'Inactive'} · Stock $stock'),
            trailing: Text(AgFormat.rupees(price), style: const TextStyle(fontWeight: FontWeight.bold)),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProductFormScreen(productId: doc.id)),
            ),
          ),
        );
      },
    );
  }
}

// ── Orders (fulfillment) ──

class _OrdersTab extends StatelessWidget {
  const _OrdersTab({super.key, required this.sellerId, required this.firestore});
  final String sellerId;
  final FirebaseFirestore firestore;

  @override
  Widget build(BuildContext context) {
    return PaginatedQueryList(
      key: ValueKey('seller-orders-$sellerId'),
      baseQuery: firestore
          .collection('orders')
          .where('sellerId', isEqualTo: sellerId)
          .orderBy('createdAt', descending: true),
      emptyLabel: 'No orders for this seller yet.',
      itemBuilder: (context, doc) {
        final d = doc.data();
        final orderNumber = (d['orderNumber'] ?? doc.id).toString();
        final status = (d['orderStatus'] ?? 'unknown').toString();
        final total = (d['total'] as num?)?.toDouble() ?? 0;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            title: Text('Order #$orderNumber'),
            subtitle: Text(status),
            trailing: Text(AgFormat.rupees(total), style: const TextStyle(fontWeight: FontWeight.bold)),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AdminOrderDetailsScreen(orderId: doc.id)),
            ),
          ),
        );
      },
    );
  }
}

// ── Finance ──

class _FinanceTab extends StatelessWidget {
  const _FinanceTab({super.key, required this.sellerId, required this.firestore});
  final String sellerId;
  final FirebaseFirestore firestore;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionHeader('Wallet balance'),
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: firestore.collection('seller_wallets').doc(sellerId).snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return const SectionMessage(icon: Icons.error_outline, message: "Couldn't load the wallet.");
            }
            if (!snap.hasData) {
              return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()));
            }
            final balance = (snap.data?.data()?['balance'] as num?)?.toDouble() ?? 0;
            final pending = (snap.data?.data()?['payoutChangePending']);
            return Row(children: [
              Expanded(child: _MetricCard(label: 'Available balance', value: AgFormat.rupees(balance))),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricCard(
                  label: 'Bank/UPI change',
                  value: (pending is String && pending.isNotEmpty) ? 'Waiting review' : 'None pending',
                ),
              ),
            ]);
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Wallet balance, a withdrawal request and a per-order payout are '
          'three distinct things: balance is what the seller can request; a '
          'withdrawal is a request against that balance; an order payout is '
          'this platform settling one specific delivered order. None of them '
          'implies the others are complete.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 20),
        const _SectionHeader('Withdrawal requests'),
        PaginatedQueryList(
          key: ValueKey('seller-withdrawals-$sellerId'),
          baseQuery: firestore
              .collection('seller_withdrawals')
              .where('sellerId', isEqualTo: sellerId)
              .orderBy('createdAt', descending: true),
          emptyLabel: 'No withdrawal requests yet.',
          pageSize: 10,
          shrinkWrapInList: true,
          itemBuilder: (context, doc) {
            final w = doc.data();
            final amount = ((w['amountPaise'] as num?) ?? 0) / 100;
            final status = (w['status'] ?? 'unknown').toString();
            final created = w['createdAt'];
            return ListTile(
              dense: true,
              title: Text(AgFormat.rupees(amount)),
              subtitle: Text('$status'
                  '${created is Timestamp ? ' · ${AgFormat.date(created.toDate())}' : ''}'
                  '${status == 'paid' && (w['paymentReference'] ?? '').toString().isNotEmpty ? ' · Ref ${w['paymentReference']}' : ''}'
                  '${status == 'rejected' && (w['rejectionReason'] ?? '').toString().isNotEmpty ? ' · ${w['rejectionReason']}' : ''}'),
            );
          },
        ),
        const SizedBox(height: 20),
        const _SectionHeader('Per-order payouts'),
        PaginatedQueryList(
          key: ValueKey('seller-payouts-$sellerId'),
          baseQuery: firestore
              .collection('seller_payouts')
              .where('sellerId', isEqualTo: sellerId)
              .orderBy('createdAt', descending: true),
          emptyLabel: 'No order payouts recorded yet.',
          pageSize: 10,
          shrinkWrapInList: true,
          itemBuilder: (context, doc) {
            final p = doc.data();
            final net = ((p['netAmount'] ?? p['amount']) as num?)?.toDouble() ?? 0;
            final gross = (p['grossAmount'] as num?)?.toDouble() ?? 0;
            final commission = (p['commissionAmount'] as num?)?.toDouble() ?? 0;
            final status = (p['status'] ?? 'unknown').toString();
            return ListTile(
              dense: true,
              title: Text('Order ${p['orderNumber'] ?? p['orderId'] ?? doc.id}'),
              subtitle: Text('$status · gross ${AgFormat.rupees(gross)} · commission ${AgFormat.rupees(commission)}'),
              trailing: Text(AgFormat.rupees(net), style: const TextStyle(fontWeight: FontWeight.bold)),
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

// ── Bank & payout destination ──

class _BankPayoutTab extends StatefulWidget {
  const _BankPayoutTab({super.key, required this.sellerId, required this.firestore});
  final String sellerId;
  final FirebaseFirestore firestore;

  @override
  State<_BankPayoutTab> createState() => _BankPayoutTabState();
}

class _BankPayoutTabState extends State<_BankPayoutTab> {
  Future<void> _review(String requestId, bool approve) async {
    String? reason;
    if (!approve) {
      reason = await _askReason(context, 'Reject change', 'Reject');
      if (reason == null) return;
    }
    try {
      await FirebaseFunctions.instance.httpsCallable('reviewSellerPayoutChange').call<Map<String, dynamic>>({
        'requestId': requestId,
        'approve': approve,
        if (reason != null) 'reason': reason,
      });
      if (mounted) {
        SnackbarHelper.showSuccess(
            context, approve ? 'Approved — payouts now go to the new details' : 'Rejected');
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('reviewSellerPayoutChange: ${e.code} ${e.details}');
      if (mounted) SnackbarHelper.showError(context, 'Could not complete that. Please try again.');
    } catch (e) {
      debugPrint('reviewSellerPayoutChange: $e');
      if (mounted) SnackbarHelper.showError(context, 'Could not complete that. Please try again.');
    }
  }

  Future<String?> _askReason(BuildContext context, String title, String action) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLength: 200,
          decoration: const InputDecoration(labelText: 'Reason (shown to the seller)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
        ],
      ),
    );
    final reason = c.text.trim();
    c.dispose();
    return ok == true ? reason : null;
  }

  String _destination(Map<String, dynamic>? d) {
    if (d == null) return 'No payout account on file';
    if (d['payoutMethod'] == 'upi') {
      return 'UPI ${d['upiId'] ?? '—'}';
    }
    final acct = (d['accountNumber'] ?? '').toString();
    return '${d['bankName'] ?? 'Bank'} · ${AgFormat.maskAccount(acct)} · IFSC ${d['ifsc'] ?? '—'}';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionHeader('Current payout destination'),
        FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: widget.firestore.collection('seller_payout_details').doc(widget.sellerId).get(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()));
            }
            if (snap.hasError) {
              return const SectionMessage(icon: Icons.error_outline, message: "Couldn't load payout details.");
            }
            return _InfoTile(
              icon: Icons.account_balance_outlined,
              label: 'Destination on file',
              value: _destination(snap.data?.data()),
            );
          },
        ),
        const SizedBox(height: 20),
        const _SectionHeader('Pending change request'),
        FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
          future: widget.firestore
              .collection('seller_payout_change_requests')
              .where('sellerId', isEqualTo: widget.sellerId)
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
                  icon: Icons.check_circle_outline, message: 'No bank/UPI change waiting.');
            }
            final doc = docs.first;
            final d = doc.data();
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('New destination requested', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    SelectableText(_destination(d)),
                    const SizedBox(height: 4),
                    Text(
                      'The current destination above stays in effect, and payouts '
                      'to this seller are blocked, until this request is reviewed.',
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
  const _SupportTab({super.key, required this.sellerId, required this.firestore});
  final String sellerId;
  final FirebaseFirestore firestore;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionHeader('Application decision'),
        FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: firestore.collection('sellerRequests').doc(sellerId).get(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()));
            }
            if (snap.hasError || !(snap.data?.exists ?? false)) {
              return const SectionMessage(
                icon: Icons.description_outlined,
                message: 'No application record found for this seller (they may predate the '
                    'in-app application flow).',
              );
            }
            final d = snap.data!.data()!;
            final reviewedAt = d['reviewedAt'];
            return _InfoTile(
              icon: Icons.fact_check_outlined,
              label: 'Application status',
              value: '${d['status'] ?? 'unknown'}'
                  '${reviewedAt is Timestamp ? ' · reviewed ${AgFormat.dateTime(reviewedAt.toDate())}' : ''}',
            );
          },
        ),
        const SizedBox(height: 20),
        ActorSupportCasesSection(firestore: firestore, actorType: 'seller', actorId: sellerId),
      ],
    );
  }
}
