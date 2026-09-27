// ADMR-56 — Customer 360.
//
// Replaces the dialog-only UserDetailsModal (ADMR-54) as the primary
// customer view: a real, deep-linkable workspace at /users/:id consolidating
// identity/account, paginated orders, wallet + rewards, payments and
// addresses. An injectable FirebaseFirestore (the pattern established by
// OrderProvider/ADMR-48 onward) makes every section testWidgets-testable.
//
// Deliberately kept separate rather than summed into one figure, per section
// 4 of the owner's own restructuring prompt: account access vs profile
// completion vs verification; wallet balance vs coins vs Product Credit;
// a payment being verified vs an order's own payment/refund status.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

import '../../../providers/admin_provider.dart';
import '../orders/admin_order_details_screen.dart';
import '../widgets/paginated_query_list.dart';
import 'edit_user_screen.dart';

class CustomerDetailScreen extends StatefulWidget {
  const CustomerDetailScreen({
    super.key,
    required this.userId,
    FirebaseFirestore? firestore,
  }) : _firestoreOverride = firestore;

  final String userId;
  final FirebaseFirestore? _firestoreOverride;

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen>
    with SingleTickerProviderStateMixin {
  late final FirebaseFirestore _firestore =
      widget._firestoreOverride ?? FirebaseFirestore.instance;

  // Eagerly constructed in initState, not lazily via `late final` -- a
  // not-found customer never reaches the part of build() that references
  // a tab controller, and a lazily-created one would then be constructed
  // for the first time inside dispose() itself, after the element is
  // already deactivated, crashing with "Looking up a deactivated widget's
  // ancestor is unsafe." Caught by this phase's own not-found widget test.
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

  void _navigateToEditUser(UserModel user) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditUserScreen(user: user)),
    );
  }

  Future<void> _toggleActive(UserModel user) async {
    final provider = context.read<AdminProvider>();
    try {
      await provider.toggleUserStatus(user.uid, !user.isActive);
      if (mounted) {
        SnackbarHelper.showSuccess(
          context,
          user.isActive ? 'Deactivated' : 'Activated',
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Could not update this account');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('Customer'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        key: ValueKey('customer-doc-${widget.userId}'),
        stream: _firestore.collection('users').doc(widget.userId).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return SectionMessage(
              icon: Icons.error_outline,
              message: "Couldn't load this customer. Check your connection "
                  'and try again.',
            );
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const SectionMessage(
              icon: Icons.person_off_outlined,
              message: 'Customer not found. They may have been removed.',
            );
          }

          final user = UserModel.fromMap(snap.data!.data()!, snap.data!.id);

          return Column(
            children: [
              _HeaderCard(
                user: user,
                onEdit: () => _navigateToEditUser(user),
                onToggleActive: () => _toggleActive(user),
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
                    Tab(text: 'Orders'),
                    Tab(text: 'Wallet & Rewards'),
                    Tab(text: 'Payments'),
                    Tab(text: 'Addresses'),
                    Tab(text: 'Support & Audit'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _OverviewTab(key: const ValueKey('overview'), user: user),
                    _OrdersTab(
                      key: const ValueKey('orders'),
                      userId: user.uid,
                      firestore: _firestore,
                    ),
                    _WalletTab(
                      key: const ValueKey('wallet'),
                      userId: user.uid,
                      firestore: _firestore,
                    ),
                    _PaymentsTab(
                      key: const ValueKey('payments'),
                      userId: user.uid,
                      firestore: _firestore,
                    ),
                    _AddressesTab(
                      key: const ValueKey('addresses'),
                      userId: user.uid,
                      firestore: _firestore,
                    ),
                    const _SupportTab(key: ValueKey('support')),
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
  const _HeaderCard({
    required this.user,
    required this.onEdit,
    required this.onToggleActive,
  });

  final UserModel user;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

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
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            backgroundImage:
                user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
            child: user.photoUrl == null
                ? Text(
                    user.initials,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  )
                : null,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 160),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(user.displayName,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(user.email,
                    style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          ),
          Wrap(spacing: 6, children: [
            _StatusChip(
              label: user.isActive ? 'Active' : 'Inactive',
              color: user.isActive ? Colors.green : Colors.red,
            ),
            _StatusChip(
              label: user.phoneVerified ? 'Phone verified' : 'Phone unverified',
              color: user.phoneVerified ? Colors.green : Colors.orange,
            ),
            _StatusChip(
              label: user.emailVerified ? 'Email verified' : 'Email unverified',
              color: user.emailVerified ? Colors.green : Colors.orange,
            ),
            _StatusChip(
              label: user.profileCompleted
                  ? 'Profile complete'
                  : 'Profile incomplete',
              color: user.profileCompleted ? Colors.green : Colors.grey,
            ),
          ]),
          Row(mainAxisSize: MainAxisSize.min, children: [
            OutlinedButton.icon(
              onPressed: onToggleActive,
              icon: Icon(user.isActive
                  ? Icons.pause_circle_outline
                  : Icons.check_circle_outline),
              label: Text(user.isActive ? 'Deactivate' : 'Activate'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ]),
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
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Overview ──

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({super.key, required this.user});
  final UserModel user;

  @override
  Widget build(BuildContext context) {
    String fmt(DateTime? d) => d == null
        ? 'Unknown'
        : '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader('Identity'),
        _InfoTile(icon: Icons.fingerprint, label: 'User ID', value: user.uid),
        _InfoTile(icon: Icons.email_outlined, label: 'Email', value: user.email),
        _InfoTile(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: user.phone ?? 'Not provided'),
        _InfoTile(
            icon: Icons.badge_outlined,
            label: 'Role',
            value: user.role),
        _InfoTile(
            icon: Icons.cake_outlined,
            label: 'Date of birth',
            value: user.dateOfBirth != null
                ? fmt(user.dateOfBirth)
                : 'Not provided'),
        _InfoTile(
            icon: Icons.wc_outlined,
            label: 'Gender',
            value: user.gender ?? 'Not provided'),
        const SizedBox(height: 16),
        _SectionHeader('Account'),
        _InfoTile(
            icon: Icons.calendar_today_outlined,
            label: 'Joined',
            value: fmt(user.createdAt)),
        _InfoTile(
            icon: Icons.login_outlined,
            label: 'Last login',
            value: user.lastLogin != null ? fmt(user.lastLogin) : 'Never'),
        _InfoTile(
            icon: Icons.verified_user_outlined,
            label: 'Profile completed',
            value: user.profileCompletedAt != null
                ? fmt(user.profileCompletedAt)
                : (user.profileCompleted ? 'Yes' : 'Not yet')),
      ],
    );
  }
}

// ── Orders ──

class _OrdersTab extends StatelessWidget {
  const _OrdersTab({super.key, required this.userId, required this.firestore});
  final String userId;
  final FirebaseFirestore firestore;

  @override
  Widget build(BuildContext context) {
    final query = firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true);

    return PaginatedQueryList(
      key: ValueKey('orders-list-$userId'),
      baseQuery: query,
      emptyLabel: 'No orders yet.',
      itemBuilder: (context, doc) {
        final order = OrderModel.fromMap(doc.data(), doc.id);
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            title: Text('Order #${order.orderNumber}'),
            subtitle: Text(
                '${order.orderStatus} · ${order.paymentMethod} · ${order.paymentStatus}'),
            trailing: Text('₹${order.total.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdminOrderDetailsScreen(orderId: order.id),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Wallet & rewards ──

class _WalletTab extends StatelessWidget {
  const _WalletTab({super.key, required this.userId, required this.firestore});
  final String userId;
  final FirebaseFirestore firestore;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader('Wallet balance'),
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: firestore.collection('wallets').doc(userId).snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return const SectionMessage(
                  icon: Icons.error_outline,
                  message: "Couldn't load the wallet.");
            }
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (!snap.data!.exists) {
              return const SectionMessage(
                  icon: Icons.account_balance_wallet_outlined,
                  message: 'No wallet yet for this customer.');
            }
            final wallet = WalletModel.fromMap(snap.data!.data()!, userId);
            return Row(
              children: [
                Expanded(
                  child: _MetricCard(
                      label: 'Cash balance',
                      value: '₹${wallet.balance.toStringAsFixed(2)}'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricCard(
                      label: 'Coins', value: wallet.coins.toString()),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricCard(
                      label: 'Referrals',
                      value: '${wallet.referralCount} (${wallet.referralCode})'),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Cash and coins are shown separately -- they are not the same '
          'asset and are never added together.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 20),
        _SectionHeader('Product Credit'),
        FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future:
              firestore.collection('product_credit_balances').doc(userId).get(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError) {
              return const SectionMessage(
                  icon: Icons.error_outline,
                  message: "Couldn't load Product Credit.");
            }
            final data = snap.data?.data();
            final balance = ProductCreditBalanceModel.fromMap(data ?? {}, userId);
            return Row(
              children: [
                Expanded(
                    child: _MetricCard(
                        label: 'Available',
                        value: '₹${balance.available.toStringAsFixed(2)}')),
                const SizedBox(width: 8),
                Expanded(
                    child: _MetricCard(
                        label: 'On hold',
                        value: '₹${balance.onHold.toStringAsFixed(2)}')),
                const SizedBox(width: 8),
                Expanded(
                    child: _MetricCard(
                        label: 'Lifetime earned',
                        value: '₹${balance.lifetimeEarned.toStringAsFixed(2)}')),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        _SectionHeader('Wallet transaction history'),
        PaginatedQueryList(
          key: ValueKey('wallet-tx-$userId'),
          baseQuery: firestore
              .collection('wallet_transactions')
              .where('userId', isEqualTo: userId)
              .orderBy('createdAt', descending: true),
          emptyLabel: 'No wallet transactions yet.',
          pageSize: 10,
          shrinkWrapInList: true,
          itemBuilder: (context, doc) {
            final tx = WalletTransactionModel.fromMap(doc.data(), doc.id);
            return ListTile(
              dense: true,
              leading: Icon(tx.icon, color: tx.color),
              title: Text(tx.sourceLabel),
              subtitle: Text('${tx.formattedDate} · ${tx.formattedTime}'),
              trailing:
                  Text(tx.formattedAmount, style: TextStyle(color: tx.color)),
            );
          },
        ),
        const SizedBox(height: 20),
        _SectionHeader('Product Credit ledger'),
        PaginatedQueryList(
          key: ValueKey('pc-ledger-$userId'),
          baseQuery: firestore
              .collection('product_credit_ledger')
              .where('customerId', isEqualTo: userId)
              .orderBy('createdAt', descending: true),
          emptyLabel: 'No Product Credit activity yet.',
          pageSize: 10,
          shrinkWrapInList: true,
          itemBuilder: (context, doc) {
            final entry = ProductCreditLedgerModel.fromMap(doc.data(), doc.id);
            return ListTile(
              dense: true,
              title: Text(entry.type),
              subtitle: Text(entry.description.isNotEmpty
                  ? entry.description
                  : '${entry.createdAt}'),
              trailing: Text('₹${entry.amount.toStringAsFixed(2)}'),
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Scratch card claim history is not shown here -- it is stored '
          'per-customer and admin has no read access to it today.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }
}

// ── Payments ──

class _PaymentsTab extends StatelessWidget {
  const _PaymentsTab(
      {super.key, required this.userId, required this.firestore});
  final String userId;
  final FirebaseFirestore firestore;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Verified payment attempts for this customer. A verified '
            'payment is not the same as a completed order or a confirmed '
            'refund -- check Order 360 for the order\'s own status.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
        Expanded(
          child: PaginatedQueryList(
            key: ValueKey('verified-payments-$userId'),
            baseQuery: firestore
                .collection('verified_payments')
                .where('userId', isEqualTo: userId)
                .orderBy('verifiedAt', descending: true),
            emptyLabel: 'No verified payments found.',
            itemBuilder: (context, doc) {
              final p = VerifiedPaymentRecord.fromMap(doc.data(), doc.id);
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  title: Text(p.orderId != null
                      ? 'Order ${p.orderId}'
                      : p.paymentId),
                  subtitle: Text(
                      '${p.method ?? 'unknown method'} · ${p.status ?? 'unknown status'}'
                      '${p.isTest ? ' · TEST' : ''}'),
                  trailing: p.amount != null
                      ? Text('₹${p.amount!.toStringAsFixed(2)}')
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Addresses ──

class _AddressesTab extends StatelessWidget {
  const _AddressesTab(
      {super.key, required this.userId, required this.firestore});
  final String userId;
  final FirebaseFirestore firestore;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: firestore
          .collection('addresses')
          .where('userId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return SectionMessage(
            icon: Icons.error_outline,
            message: "Couldn't load addresses. This needs the addresses "
                'collection\'s admin-read rule deployed '
                '(firebase deploy --only firestore:rules) -- until then '
                'this fails closed rather than showing an empty list.',
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const SectionMessage(
              icon: Icons.location_off_outlined,
              message: 'No saved addresses.');
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: docs.map((d) {
            final a = AddressModel.fromMap(d.data());
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(a.isDefault ? Icons.star : Icons.location_on_outlined,
                    color: a.isDefault ? Colors.amber.shade700 : null),
                title: Text('${a.name} · ${a.phone}'),
                subtitle: Text(
                    '${a.addressLine1}, ${a.addressLine2}, ${a.city}, ${a.state} ${a.zipcode}'),
                trailing: a.addressType != null ? Text(a.addressType!) : null,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ── Support & audit ──

class _SupportTab extends StatelessWidget {
  const _SupportTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const SectionMessage(
      icon: Icons.support_agent_outlined,
      message: 'No dedicated customer support-case system exists yet. '
          'Rider support tickets are a separate, rider-only system; there '
          'is no per-customer case or audit trail to show here today. '
          'This is a disclosed gap, not a missing wire-up -- a unified '
          'support model is planned as its own later phase.',
    );
  }
}

// ── Shared small widgets ──

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
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
                Text(label,
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                Text(value,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// SectionMessage and PaginatedQueryList moved to
// ../widgets/paginated_query_list.dart (ADMR-57) so Seller/Delivery
// Partner/Sales Associate 360 can share them too.
