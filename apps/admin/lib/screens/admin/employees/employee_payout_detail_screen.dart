import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

/// Refusals from markEmployeePayoutPaid/rejectEmployeePayout, in admin words.
/// Mirrors seller_wallet_admin.dart's sellerWalletRefusal exactly — same
/// callable-error shape (functions/src/customer/reviewEmployeePayout.ts).
String _employeePayoutRefusal(String code, String? reason) => switch (reason) {
      'not_requested' => 'This payout has already been reviewed — it may already be settled.',
      'bad_reference' => 'Enter the UTR / payment reference (4–64 characters).',
      'reason_required' => 'Give a reason (3–200 characters) — required to reject a request.',
      'not_found' => 'Not found — it may have been removed.',
      _ => code == 'permission-denied'
          ? 'Only admins can do this.'
          : (code == 'unavailable' || code == 'deadline-exceeded')
              ? 'No connection. Try again.'
              : 'Could not complete that. Please try again.',
    };

/// Screen displaying complete details for an individual employee payout request,
/// including payment mode (Bank/UPI) with one-tap copy buttons, employee info,
/// lifecycle timestamps, and admin processing actions (Mark Paid, Reject).
class EmployeePayoutDetailScreen extends StatefulWidget {
  final String payoutId;
  final Map<String, dynamic>? initialData;

  const EmployeePayoutDetailScreen({
    super.key,
    required this.payoutId,
    this.initialData,
  });

  @override
  State<EmployeePayoutDetailScreen> createState() =>
      _EmployeePayoutDetailScreenState();
}

class _EmployeePayoutDetailScreenState
    extends State<EmployeePayoutDetailScreen> {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isProcessing = false;

  void _copyToClipboard(String text, String label) {
    if (text.isEmpty || text == '-') return;
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    if (mounted) {
      SnackbarHelper.showSuccess(context, '$label copied to clipboard');
    }
  }

  String _formatMoney(double value) {
    return '₹${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2)}';
  }

  String _formatDateTime(dynamic ts) {
    if (ts == null) return '-';
    DateTime dt;
    if (ts is Timestamp) {
      dt = ts.toDate();
    } else if (ts is DateTime) {
      dt = ts;
    } else if (ts is String) {
      final parsed = DateTime.tryParse(ts);
      if (parsed == null) return ts;
      dt = parsed;
    } else {
      return ts.toString();
    }
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/$year, $hour:$minute';
  }

  Future<void> _showMarkPaidDialog(
    double amount,
    String employeeName,
    String method,
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
              'Confirm that ${_formatMoney(amount)} has been transferred to $employeeName via ${method.toUpperCase()}?',
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

    final utr = utrController.text.trim();
    if (confirmed == true && utr.isEmpty && mounted) {
      SnackbarHelper.showError(context, 'Enter the UTR / payment reference (4–64 characters).');
      return;
    }
    if (confirmed == true && mounted) {
      setState(() => _isProcessing = true);
      try {
        // Phase ADMR-3: the only path — see reviewEmployeePayout.ts's header
        // for why the previous direct Firestore write always failed the
        // moment a UTR was entered (the rules' hasOnly() allowlist named a
        // different field, paymentReference, not transactionRef).
        await FirebaseFunctions.instance
            .httpsCallable('markEmployeePayoutPaid')
            .call<Map<String, dynamic>>({'payoutId': widget.payoutId, 'paymentReference': utr});
        if (mounted) {
          SnackbarHelper.showSuccess(context, 'Payout marked as paid successfully');
        }
      } on FirebaseFunctionsException catch (e) {
        debugPrint('markEmployeePayoutPaid: ${e.code} ${e.details}');
        final reason = e.details is Map ? (e.details as Map)['reason'] as String? : null;
        if (mounted) SnackbarHelper.showError(context, _employeePayoutRefusal(e.code, reason));
      } catch (e) {
        debugPrint('markEmployeePayoutPaid: $e');
        if (mounted) SnackbarHelper.showError(context, _employeePayoutRefusal('unknown', null));
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _showRejectDialog() async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.red),
            SizedBox(width: 8),
            Text('Reject Payout'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to reject this payout request?',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Reason for rejection',
                hintText: 'e.g. Incorrect bank details',
                helperText: 'Required — the associate sees this.',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.comment_outlined),
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
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Reject Payout'),
          ),
        ],
      ),
    );

    final reason = reasonController.text.trim();
    if (confirmed == true && reason.isEmpty && mounted) {
      SnackbarHelper.showError(context, 'Give a reason (3–200 characters) — required to reject a request.');
      return;
    }
    if (confirmed == true && mounted) {
      setState(() => _isProcessing = true);
      try {
        // Phase ADMR-3: the only path — see reviewEmployeePayout.ts's header.
        // The previous direct Firestore write had ALWAYS failed
        // permission-denied (firestore.rules never had a branch permitting a
        // transition to 'rejected'), so the associate's already-debited
        // wallet amount had no way back. This callable credits it back,
        // exactly once, in the same transaction that records the rejection.
        await FirebaseFunctions.instance
            .httpsCallable('rejectEmployeePayout')
            .call<Map<String, dynamic>>({'payoutId': widget.payoutId, 'reason': reason});
        if (mounted) {
          SnackbarHelper.showSuccess(context, 'Payout request rejected — the amount was returned to their wallet');
        }
      } on FirebaseFunctionsException catch (e) {
        debugPrint('rejectEmployeePayout: ${e.code} ${e.details}');
        final r = e.details is Map ? (e.details as Map)['reason'] as String? : null;
        if (mounted) SnackbarHelper.showError(context, _employeePayoutRefusal(e.code, r));
      } catch (e) {
        debugPrint('rejectEmployeePayout: $e');
        if (mounted) SnackbarHelper.showError(context, _employeePayoutRefusal('unknown', null));
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Payout Details'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('employee_payouts')
            .doc(widget.payoutId)
            .snapshots(),
        builder: (context, payoutSnap) {
          if (payoutSnap.connectionState == ConnectionState.waiting &&
              widget.initialData == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final payoutData = payoutSnap.data?.data() ?? widget.initialData;

          if (payoutData == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long_outlined,
                        size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text(
                      'Payout Not Found',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This payout record could not be loaded.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            );
          }

          final rawAmount = payoutData['amount'] ??
              payoutData['netAmount'] ??
              payoutData['grossAmount'] ??
              payoutData['commissionAmount'];
          final amount = (rawAmount as num?)?.toDouble() ?? 0.0;
          final status = (payoutData['status'] ?? 'pending')
              .toString()
              .toLowerCase();
          final employeeId = (payoutData['employeeId'] ?? '').toString();
          final createdAt = payoutData['createdAt'];
          final paidAt = payoutData['paidAt'];
          final transactionRef = payoutData['transactionRef']?.toString() ??
              payoutData['referenceId']?.toString();
          final rejectionReason = payoutData['rejectionReason']?.toString();

          final isPaid = status == 'paid';
          final isRejected = status == 'rejected' || status == 'failed';
          final isPending = !isPaid && !isRejected;

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: employeeId.isNotEmpty
                ? _firestore.collection('employees').doc(employeeId).snapshots()
                : null,
            builder: (context, empSnap) {
              final empData = empSnap.data?.data() ?? <String, dynamic>{};

              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: employeeId.isNotEmpty
                    ? _firestore.collection('users').doc(employeeId).snapshots()
                    : null,
                builder: (context, userSnap) {
                  final userData = userSnap.data?.data() ?? <String, dynamic>{};

                  final employeeName = (empData['name'] ??
                          userData['name'] ??
                          empData['accountHolderName'] ??
                          'Sales Associate')
                      .toString();
                  final email = (empData['email'] ?? userData['email'] ?? '-')
                      .toString();
                  final phone = (empData['phone'] ??
                          empData['mobile'] ??
                          userData['phone'] ??
                          '-')
                      .toString();
                  final employeeCode = (empData['employeeCode'] ??
                          empData['code'] ??
                          (employeeId.isNotEmpty ? employeeId : '-'))
                      .toString();

                  // Payout method resolution
                  final method = (payoutData['payoutMethod'] ??
                          empData['payoutMethod'] ??
                          (empData.containsKey('upiId') &&
                                  empData['upiId'] != null &&
                                  empData['upiId'].toString().isNotEmpty
                              ? 'upi'
                              : 'bank'))
                      .toString()
                      .toLowerCase();
                  final isUpi = method == 'upi';

                  // Account details
                  final upiId = (payoutData['upiId'] ??
                          empData['upiId'] ??
                          '-')
                      .toString();
                  final accountNumber = (payoutData['accountNumber'] ??
                          empData['accountNumber'] ??
                          '-')
                      .toString();
                  final ifscCode = (payoutData['ifscCode'] ??
                          empData['ifscCode'] ??
                          empData['ifsc'] ??
                          '-')
                      .toString();
                  final bankName = (payoutData['bankName'] ??
                          empData['bankName'] ??
                          '-')
                      .toString();
                  final holderName = (payoutData['accountHolderName'] ??
                          empData['accountHolderName'] ??
                          employeeName)
                      .toString();

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Hero Amount & Status Card
                      _buildHeroCard(amount, status, isPaid, isRejected),
                      const SizedBox(height: 16),

                      // Payment Mode & Destination Card (Core Feature with Copy Buttons)
                      _buildPaymentDetailsCard(
                        isUpi: isUpi,
                        upiId: upiId,
                        accountNumber: accountNumber,
                        ifscCode: ifscCode,
                        bankName: bankName,
                        holderName: holderName,
                      ),
                      const SizedBox(height: 16),

                      // Employee Information Card
                      _buildEmployeeInfoCard(
                        employeeName: employeeName,
                        email: email,
                        phone: phone,
                        employeeCode: employeeCode,
                        employeeId: employeeId,
                      ),
                      const SizedBox(height: 16),

                      // Payout Lifecycle & Timestamps Card
                      _buildLifecycleCard(
                        payoutId: widget.payoutId,
                        createdAt: createdAt,
                        paidAt: paidAt,
                        transactionRef: transactionRef,
                        rejectionReason: rejectionReason,
                        isPaid: isPaid,
                        isRejected: isRejected,
                      ),
                      const SizedBox(height: 24),

                      // Admin Processing Action Buttons
                      if (isPending) ...[
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isProcessing
                                    ? null
                                    : () => _showRejectDialog(),
                                icon: const Icon(Icons.close_rounded,
                                    color: Colors.red),
                                label: const Text('Reject Request',
                                    style: TextStyle(color: Colors.red)),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.red.shade300),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _isProcessing
                                    ? null
                                    : () => _showMarkPaidDialog(
                                          amount,
                                          employeeName,
                                          method,
                                        ),
                                icon: _isProcessing
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : const Icon(Icons.check_circle_outline),
                                label: const Text('Mark as Paid'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF15803D),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else if (isPaid) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.verified,
                                  color: Color(0xFF15803D), size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Payout Completed',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Color(0xFF15803D),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Paid on ${_formatDateTime(paidAt)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeroCard(
    double amount,
    String status,
    bool isPaid,
    bool isRejected,
  ) {
    Color bg = Colors.amber.shade50;
    Color fg = Colors.amber.shade900;
    IconData icon = Icons.hourglass_top_rounded;

    if (isPaid) {
      bg = Colors.green.shade50;
      fg = const Color(0xFF15803D);
      icon = Icons.check_circle_rounded;
    } else if (isRejected) {
      bg = Colors.red.shade50;
      fg = Colors.red.shade800;
      icon = Icons.cancel_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 6),
                Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: fg,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _formatMoney(amount),
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Requested Payout Amount',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDetailsCard({
    required bool isUpi,
    required String upiId,
    required String accountNumber,
    required String ifscCode,
    required String bankName,
    required String holderName,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isUpi
                        ? Colors.deepPurple.shade50
                        : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isUpi ? Icons.qr_code_scanner : Icons.account_balance,
                    size: 20,
                    color: isUpi ? Colors.deepPurple : Colors.blue.shade800,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isUpi ? 'UPI Transfer' : 'Bank Account Transfer',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isUpi
                            ? 'Instant VPA settlement'
                            : 'Direct NEFT/IMPS settlement',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isUpi
                        ? Colors.deepPurple.shade50
                        : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isUpi ? 'UPI' : 'BANK',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isUpi ? Colors.deepPurple : Colors.blue.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (isUpi) ...[
            _buildCopyableRow(
              title: 'UPI ID / VPA',
              value: upiId,
              icon: Icons.alternate_email_rounded,
              isProminent: true,
            ),
            const Divider(height: 1),
            _buildCopyableRow(
              title: 'Registered Account Name',
              value: holderName,
              icon: Icons.person_outline,
            ),
          ] else ...[
            _buildCopyableRow(
              title: 'Bank Name',
              value: bankName,
              icon: Icons.account_balance_outlined,
            ),
            const Divider(height: 1),
            _buildCopyableRow(
              title: 'Account Number',
              value: accountNumber,
              icon: Icons.pin_outlined,
              isProminent: true,
            ),
            const Divider(height: 1),
            _buildCopyableRow(
              title: 'IFSC Code',
              value: ifscCode,
              icon: Icons.tag_rounded,
              isProminent: true,
            ),
            const Divider(height: 1),
            _buildCopyableRow(
              title: 'Account Holder Name',
              value: holderName,
              icon: Icons.person_outline,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmployeeInfoCard({
    required String employeeName,
    required String email,
    required String phone,
    required String employeeCode,
    required String employeeId,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.badge_outlined,
                    size: 20,
                    color: Colors.teal.shade800,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Employee Profile',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _buildCopyableRow(
            title: 'Full Name',
            value: employeeName,
            icon: Icons.person_rounded,
          ),
          const Divider(height: 1),
          _buildCopyableRow(
            title: 'Email Address',
            value: email,
            icon: Icons.email_outlined,
          ),
          const Divider(height: 1),
          _buildCopyableRow(
            title: 'Phone Number',
            value: phone,
            icon: Icons.phone_outlined,
          ),
          const Divider(height: 1),
          _buildCopyableRow(
            title: 'Employee ID / Code',
            value: employeeCode,
            icon: Icons.fingerprint_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildLifecycleCard({
    required String payoutId,
    required dynamic createdAt,
    required dynamic paidAt,
    required String? transactionRef,
    required String? rejectionReason,
    required bool isPaid,
    required bool isRejected,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.history_rounded,
                    size: 20,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Lifecycle & Reference',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _buildCopyableRow(
            title: 'Payout Request ID',
            value: payoutId,
            icon: Icons.tag,
          ),
          const Divider(height: 1),
          _buildDetailRow(
            title: 'Date Requested',
            value: _formatDateTime(createdAt),
            icon: Icons.calendar_today_outlined,
          ),
          if (isPaid) ...[
            const Divider(height: 1),
            _buildDetailRow(
              title: 'Date Paid',
              value: _formatDateTime(paidAt),
              icon: Icons.check_circle_outline,
              valueColor: const Color(0xFF15803D),
            ),
            if (transactionRef != null && transactionRef.isNotEmpty) ...[
              const Divider(height: 1),
              _buildCopyableRow(
                title: 'Transaction / UTR Reference',
                value: transactionRef,
                icon: Icons.receipt_long,
                isProminent: true,
              ),
            ],
          ],
          if (isRejected &&
              rejectionReason != null &&
              rejectionReason.isNotEmpty) ...[
            const Divider(height: 1),
            _buildDetailRow(
              title: 'Rejection Reason',
              value: rejectionReason,
              icon: Icons.warning_amber_rounded,
              valueColor: Colors.red.shade800,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCopyableRow({
    required String title,
    required String value,
    required IconData icon,
    bool isProminent = false,
  }) {
    final canCopy = value.isNotEmpty && value != '-';
    return InkWell(
      onTap: canCopy ? () => _copyToClipboard(value, title) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: isProminent ? 15 : 14,
                      fontWeight:
                          isProminent ? FontWeight.w800 : FontWeight.w600,
                      color: isProminent
                          ? const Color(0xFF0F172A)
                          : Colors.grey.shade800,
                      letterSpacing: isProminent ? 0.3 : 0,
                    ),
                  ),
                ],
              ),
            ),
            if (canCopy)
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18),
                color: AppColors.primary,
                tooltip: 'Copy $title',
                onPressed: () => _copyToClipboard(value, title),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required String title,
    required String value,
    required IconData icon,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
