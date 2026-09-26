import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'employee_payout_detail_screen.dart';

/// Phase ADMR-20. Refusals from markEmployeePayoutPaid, in admin words —
/// the subset relevant to THIS screen's own action (it never rejects, only
/// marks paid). Deliberately duplicated rather than imported from
/// employee_payout_detail_screen.dart's private `_employeePayoutRefusal`
/// (file-private, and reject's `reason_required` case does not apply here).
String _employeePayoutPaidRefusal(String code, String? reason) => switch (reason) {
      'not_requested' => 'This payout has already been reviewed — it may already be settled.',
      'bad_reference' => 'Enter the UTR / payment reference (4–64 characters).',
      'not_found' => 'Not found — it may have been removed.',
      _ => code == 'permission-denied'
          ? 'Only admins can do this.'
          : (code == 'unavailable' || code == 'deadline-exceeded')
              ? 'No connection. Try again.'
              : 'Could not complete that. Please try again.',
    };

/// Lists `employee_payouts` documents with real-time status, payment mode
/// badges (UPI/Bank), search/filter chips, and one-tap navigation to the
/// full payout detail screen with copyable payment credentials.
class EmployeePayoutsScreen extends StatefulWidget {
  const EmployeePayoutsScreen({super.key});

  @override
  State<EmployeePayoutsScreen> createState() => _EmployeePayoutsScreenState();
}

class _EmployeePayoutsScreenState extends State<EmployeePayoutsScreen> {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedFilter = 'all'; // all, pending, paid, rejected

  Future<void> _markPaid(
    BuildContext context,
    String payoutId,
    double amount,
  ) async {
    final utrController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Color(0xFF15803D)),
            SizedBox(width: 8),
            Text('Mark as Paid'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confirm that ${_formatMoney(amount)} has been transferred to this associate?',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: utrController,
              decoration: InputDecoration(
                labelText: 'UTR / Transaction Reference',
                hintText: 'e.g. 423589234823',
                helperText: 'Required — this is the only record of where the money went.',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.receipt_long_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF15803D),
            ),
            child: const Text('Confirm Paid'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final utr = utrController.text.trim();
    try {
      // Phase ADMR-20: this screen's own "Mark Paid" button previously wrote
      // directly to Firestore (`employee_payouts` doc `.update({status:
      // 'paid', ...})`) — firestore.rules' employee_payouts collection has
      // had `allow update: if false` since Phase ADMR-3 (Admin SDK only, via
      // this exact callable), so every click of that button has always
      // failed with permission-denied. The sibling detail screen
      // (employee_payout_detail_screen.dart) was fixed in ADMR-3; this list
      // screen's own copy of the same action was missed.
      await FirebaseFunctions.instance
          .httpsCallable('markEmployeePayoutPaid')
          .call<Map<String, dynamic>>({'payoutId': payoutId, 'paymentReference': utr});
      if (context.mounted) {
        SnackbarHelper.showSuccess(context, 'Payout marked as paid successfully');
      }
    } on FirebaseFunctionsException catch (e) {
      final reason = e.details is Map ? (e.details as Map)['reason'] as String? : null;
      if (context.mounted) {
        SnackbarHelper.showError(context, _employeePayoutPaidRefusal(e.code, reason));
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarHelper.showError(context, _employeePayoutPaidRefusal('unknown', null));
      }
    }
  }

  static double _amountOf(Map<String, dynamic> d) {
    final raw = d['amount'] ??
        d['netAmount'] ??
        d['commissionAmount'] ??
        d['grossAmount'];
    return (raw as num?)?.toDouble() ?? 0.0;
  }

  static String _formatMoney(double value) {
    return '₹${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2)}';
  }

  static String _formatDate(dynamic ts) {
    if (ts == null) return '';
    DateTime dt;
    if (ts is Timestamp) {
      dt = ts.toDate();
    } else if (ts is DateTime) {
      dt = ts;
    } else {
      return '';
    }
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  void _openDetail(String payoutId, Map<String, dynamic> data) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EmployeePayoutDetailScreen(
          payoutId: payoutId,
          initialData: data,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Employee Payouts'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'All Payouts'),
                  const SizedBox(width: 8),
                  _buildFilterChip('pending', 'Pending / Requested'),
                  const SizedBox(width: 8),
                  _buildFilterChip('paid', 'Paid'),
                  const SizedBox(width: 8),
                  _buildFilterChip('rejected', 'Rejected'),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // Payouts Stream List
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestore
                  .collection('employee_payouts')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _MessageState(
                    icon: Icons.error_outline_rounded,
                    title: 'Unable to load employee payouts',
                    subtitle: snapshot.error.toString(),
                  );
                }

                final allDocs = snapshot.data?.docs ?? [];

                // Apply client-side filter
                final docs = allDocs.where((doc) {
                  final status = (doc.data()['status'] ?? 'pending')
                      .toString()
                      .toLowerCase();
                  if (_selectedFilter == 'pending') {
                    return status == 'pending' ||
                        status == 'requested' ||
                        status == 'processing';
                  } else if (_selectedFilter == 'paid') {
                    return status == 'paid';
                  } else if (_selectedFilter == 'rejected') {
                    return status == 'rejected' || status == 'failed';
                  }
                  return true;
                }).toList();

                if (docs.isEmpty) {
                  return _MessageState(
                    icon: Icons.payments_outlined,
                    title: _selectedFilter == 'all'
                        ? 'No employee payouts yet'
                        : 'No ${_selectedFilter.toUpperCase()} payouts found',
                    subtitle: _selectedFilter == 'all'
                        ? 'Payout requests from sales associates will appear here.'
                        : 'Try selecting a different filter.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final d = doc.data();
                    final status = (d['status'] ?? 'pending')
                        .toString()
                        .toLowerCase();
                    final amount = _amountOf(d);
                    final employeeId = (d['employeeId'] ?? '').toString();
                    final dateStr = _formatDate(d['createdAt']);

                    final isPaid = status == 'paid';
                    final isRejected =
                        status == 'rejected' || status == 'failed';

                    Color statusBg = Colors.amber.shade50;
                    Color statusFg = Colors.amber.shade900;
                    if (isPaid) {
                      statusBg = Colors.green.shade50;
                      statusFg = const Color(0xFF15803D);
                    } else if (isRejected) {
                      statusBg = Colors.red.shade50;
                      statusFg = Colors.red.shade800;
                    }

                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      elevation: 0,
                      child: InkWell(
                        onTap: () => _openDetail(doc.id, d),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Amount & Date
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _formatMoney(amount),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 20,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        if (dateStr.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            'Requested on $dateStr',
                                            style: TextStyle(
                                              color: Colors.grey.shade500,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  // Status Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusBg,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      status.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: statusFg,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 12),

                              // Employee Details & Destination resolver
                              _EmployeeSummaryRow(
                                employeeId: employeeId,
                                payoutData: d,
                              ),
                              const SizedBox(height: 12),

                              // Card Footer: Actions and "View Details" hint
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Tap for payment details & copy',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!isPaid && !isRejected) ...[
                                        FilledButton(
                                          onPressed: () =>
                                              _markPaid(context, doc.id, amount),
                                          style: FilledButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF15803D),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 8),
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                          child: const Text('Mark Paid'),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: Colors.grey,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _selectedFilter = key);
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.12),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? AppColors.primary : Colors.grey.shade700,
      ),
      backgroundColor: Colors.grey.shade100,
      side: BorderSide(
        color: isSelected ? AppColors.primary : Colors.transparent,
      ),
    );
  }
}

/// Helper row that resolves the employee's name and payment method badge
class _EmployeeSummaryRow extends StatelessWidget {
  final String employeeId;
  final Map<String, dynamic> payoutData;

  const _EmployeeSummaryRow({
    required this.employeeId,
    required this.payoutData,
  });

  @override
  Widget build(BuildContext context) {
    if (employeeId.isEmpty) {
      return Text(
        'Employee: -',
        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('employees')
          .doc(employeeId)
          .snapshots(),
      builder: (context, snap) {
        final emp = snap.data?.data() ?? <String, dynamic>{};
        final name = (emp['name'] ?? emp['accountHolderName'] ?? '').toString();
        final method = (payoutData['payoutMethod'] ??
                emp['payoutMethod'] ??
                (emp.containsKey('upiId') &&
                        emp['upiId'] != null &&
                        emp['upiId'].toString().isNotEmpty
                    ? 'upi'
                    : 'bank'))
            .toString()
            .toLowerCase();
        final isUpi = method == 'upi';

        return Row(
          children: [
            Icon(
              Icons.badge_outlined,
              size: 16,
              color: Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                name.isNotEmpty ? '$name (${emp['employeeCode'] ?? employeeId})' : employeeId,
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isUpi
                    ? Colors.deepPurple.shade50
                    : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isUpi ? Icons.qr_code_scanner : Icons.account_balance,
                    size: 12,
                    color: isUpi ? Colors.deepPurple : Colors.blue.shade800,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isUpi ? 'UPI' : 'BANK',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isUpi ? Colors.deepPurple : Colors.blue.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _MessageState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(28),
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
