import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

/// Phase ADMR-19.
///
/// Lists `commission_exceptions` — delivered, employee-attributed orders
/// whose commission rate could not be resolved at delivery time (no
/// employee override, no configured mode rate in settings/commission, or an
/// invalid one). Before this phase nothing in the app ever read this
/// collection despite firestore.rules already gating it `allow read: if
/// isAdmin()` "for admin visibility" — an admin had no way to know these
/// orders existed, let alone resolve them, short of a developer running
/// functions/scripts/phase_process_pending_commissions.js by hand.
///
/// "Retry now" calls the `retryCommissionException` callable, which
/// re-resolves the rate against CURRENT employees/settings data and, if
/// resolvable, pays the associate atomically and marks the row resolved.
class CommissionExceptionsScreen extends StatefulWidget {
  const CommissionExceptionsScreen({super.key});

  @override
  State<CommissionExceptionsScreen> createState() =>
      _CommissionExceptionsScreenState();
}

class _CommissionExceptionsScreenState
    extends State<CommissionExceptionsScreen> {
  final Set<String> _retrying = {};

  static String _reasonLabel(String? reason) {
    switch (reason) {
      case 'no_rate_configured':
        return 'No commission rate configured for this order mode';
      case 'rate_not_a_number':
        return 'Configured rate is not a valid number';
      case 'rate_not_positive':
        return 'Configured rate is zero or negative';
      case 'rate_exceeds_ceiling':
        return 'Configured rate exceeds the 100% ceiling';
      default:
        return reason ?? 'Unknown reason';
    }
  }

  Future<void> _retry(String exceptionId) async {
    setState(() => _retrying.add(exceptionId));
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('retryCommissionException')
          .call<Map<String, dynamic>>({'exceptionId': exceptionId});
      if (!mounted) return;
      final alreadyResolved = result.data['alreadyResolved'] == true;
      SnackbarHelper.showSuccess(
        context,
        alreadyResolved
            ? 'Already resolved — no action needed.'
            : 'Commission paid and marked resolved.',
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      if (e.code == 'failed-precondition') {
        final reason = e.details is Map ? (e.details as Map)['reason'] as String? : null;
        SnackbarHelper.showError(
          context,
          'Still unresolved: ${_reasonLabel(reason)}. Configure the rate, then retry again.',
        );
      } else {
        SnackbarHelper.showError(context, e.message ?? 'Retry failed');
      }
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'Retry failed: $e');
    } finally {
      if (mounted) setState(() => _retrying.remove(exceptionId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Commission Exceptions'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('commission_exceptions')
            .orderBy('createdAt', descending: true)
            .limit(200)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
                    SizedBox(height: 12),
                    Text(
                      'No commission exceptions',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Every delivered, attributed order has a resolved commission rate.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final d = doc.data();
              final status = (d['status'] ?? 'unresolved').toString();
              final isResolved = status == 'resolved';
              final orderNumber = d['orderNumber']?.toString() ?? d['orderId']?.toString() ?? doc.id;
              final employeeUid = d['employeeUid']?.toString() ?? '';
              final orderMode = d['orderMode']?.toString() ?? 'B2C';
              final total = (d['total'] as num?)?.toDouble();
              final reason = d['reason']?.toString();
              final isRetrying = _retrying.contains(doc.id);

              DateTime? createdAt;
              final ts = d['createdAt'];
              if (ts is Timestamp) createdAt = ts.toDate();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Order #$orderNumber',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isResolved ? Colors.green.shade50 : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isResolved ? Colors.green.shade800 : Colors.orange.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Associate: $employeeUid', style: const TextStyle(fontSize: 13)),
                      Text('Mode: $orderMode${total != null ? ' · Total: ₹${total.toStringAsFixed(0)}' : ''}',
                          style: const TextStyle(fontSize: 13, color: Colors.grey)),
                      if (!isResolved)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _reasonLabel(reason),
                            style: TextStyle(fontSize: 13, color: Colors.orange.shade800),
                          ),
                        ),
                      if (createdAt != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Flagged ${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      if (!isResolved) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: isRetrying ? null : () => _retry(doc.id),
                            icon: isRetrying
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.refresh, size: 16),
                            label: Text(isRetrying ? 'Retrying…' : 'Retry now'),
                          ),
                        ),
                      ],
                    ],
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
