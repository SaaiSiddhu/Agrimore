import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../app/app_router.dart';

/// Review `employees` and approve / reject self-applied requests, edit
/// commission rate on approved employees. Unlike sellers, employees are a
/// single collection (`employees/{uid}`) with a `status` field — there is no
/// separate staging collection to also write.
class EmployeeManagementScreen extends StatelessWidget {
  const EmployeeManagementScreen({Key? key}) : super(key: key);

  Future<void> _approve(BuildContext context, String uid) async {
    HapticFeedback.mediumImpact();
    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.set(
        FirebaseFirestore.instance.collection('employees').doc(uid),
        {'status': 'approved', 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      batch.set(
        FirebaseFirestore.instance.collection('users').doc(uid),
        {'employeeStatus': 'approved', 'role': 'employee'},
        SetOptions(merge: true),
      );
      await batch.commit();
      if (context.mounted) {
        SnackbarHelper.showSuccess(context, 'Employee approved');
      }
    } catch (e) {
      if (context.mounted) SnackbarHelper.showError(context, 'Failed: $e');
    }
  }

  Future<void> _reject(BuildContext context, String uid) async {
    HapticFeedback.selectionClick();
    try {
      final batch = FirebaseFirestore.instance.batch();
      // EmployeeModel.status only supports pending/approved/suspended (no
      // 'rejected' value, unlike sellerRequests) — 'suspended' is the
      // closest equivalent for a declined self-apply request.
      batch.set(
        FirebaseFirestore.instance.collection('employees').doc(uid),
        {'status': 'suspended', 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      batch.set(
        FirebaseFirestore.instance.collection('users').doc(uid),
        {'employeeStatus': 'suspended'},
        SetOptions(merge: true),
      );
      await batch.commit();
      if (context.mounted) {
        SnackbarHelper.showInfo(context, 'Employee request rejected');
      }
    } catch (e) {
      if (context.mounted) SnackbarHelper.showError(context, 'Failed: $e');
    }
  }

  Future<void> _editCommissionRate(
    BuildContext context,
    String uid,
    double currentRate,
  ) async {
    final controller =
        TextEditingController(text: currentRate.toStringAsFixed(1));
    final newRate = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Commission Rate'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Commission Rate (%)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(controller.text.trim())),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newRate == null) return;
    try {
      await FirebaseFirestore.instance.collection('employees').doc(uid).set(
        {
          'commissionRate': newRate,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      if (context.mounted) {
        SnackbarHelper.showSuccess(context, 'Commission rate updated');
      }
    } catch (e) {
      if (context.mounted) SnackbarHelper.showError(context, 'Failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Employees'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          // Phase ADMR-5: pending associate bank/UPI change requests.
          IconButton(
            icon: const Icon(Icons.account_balance_outlined),
            tooltip: 'Bank/UPI changes',
            onPressed: () =>
                context.push(AdminRoutes.employeePayoutAccountReview),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AdminRoutes.addEmployee),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Employee'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('employees').snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs.toList()
            ..sort((a, b) {
              final ta = a.data()['createdAt'];
              final tb = b.data()['createdAt'];
              if (ta is Timestamp && tb is Timestamp) {
                return tb.toDate().compareTo(ta.toDate());
              }
              return 0;
            });
          if (docs.isEmpty) {
            return const Center(child: Text('No employees yet'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final doc = docs[i];
              final d = doc.data();
              final status = (d['status'] ?? 'pending').toString();
              final uid = doc.id;
              final commissionRate =
                  (d['commissionRate'] as num?)?.toDouble() ?? 0.0;

              return Card(
                child: InkWell(
                  onTap: () => context.push(
                      AdminRoutes.associateDetail.replaceFirst(':id', uid)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                d['name']?.toString() ?? 'Employee',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: status == 'approved'
                                    ? Colors.green.shade50
                                    : status == 'suspended'
                                        ? Colors.red.shade50
                                        : Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: status == 'approved'
                                      ? Colors.green.shade800
                                      : status == 'suspended'
                                          ? Colors.red.shade800
                                          : Colors.amber.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('${d['email'] ?? ''} · ${d['phone'] ?? ''}'),
                        const SizedBox(height: 4),
                        Text(
                          'Code: ${d['employeeCode'] ?? '-'} · Commission: ${commissionRate.toStringAsFixed(1)}%',
                          style: TextStyle(
                              color: Colors.grey.shade700, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (status == 'pending') ...[
                              FilledButton(
                                onPressed: () => _approve(context, uid),
                                style: FilledButton.styleFrom(
                                    backgroundColor: Colors.green.shade700),
                                child: const Text('Approve'),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton(
                                onPressed: () => _reject(context, uid),
                                child: const Text('Reject'),
                              ),
                            ] else ...[
                              OutlinedButton.icon(
                                onPressed: () => _editCommissionRate(
                                    context, uid, commissionRate),
                                icon: const Icon(Icons.percent, size: 16),
                                label: const Text('Edit Commission'),
                              ),
                            ],
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
    );
  }
}
