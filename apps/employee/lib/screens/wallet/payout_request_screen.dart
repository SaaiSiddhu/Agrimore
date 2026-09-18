import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../utils/sa_formatters.dart';
import 'payout_account_screen.dart';
import 'payout_review_screen.dart';

/// Screen allowing an associate to enter a payout amount and select presets.
///
/// Validates amount against available balance, ensures a registered payout account
/// exists, and navigates to [PayoutReviewScreen] without making mutations directly.
class PayoutRequestScreen extends StatefulWidget {
  const PayoutRequestScreen({super.key});

  @override
  State<PayoutRequestScreen> createState() => _PayoutRequestScreenState();
}

class _PayoutRequestScreenState extends State<PayoutRequestScreen> {
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  double _enteredAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() {
      final amt = double.tryParse(_amountController.text.trim()) ?? 0.0;
      if (amt != _enteredAmount) {
        setState(() => _enteredAmount = amt);
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _applyPreset(double amount, double availableBalance) {
    if (amount > availableBalance) return;
    HapticFeedback.selectionClick();
    _amountController.text = amount.toStringAsFixed(0);
  }

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
        title: const Text('Request Payout'),
        leading: IconButton(
          icon: const Icon(SaIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('wallets')
            .doc(uid)
            .snapshots(),
        builder: (context, walletSnap) {
          if (!walletSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final walletData = walletSnap.data?.data();
          final availableBalance =
              (walletData?['balance'] as num?)?.toDouble() ?? 0.0;

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('employees')
                .doc(uid)
                .snapshots(),
            builder: (context, employeeSnap) {
              final employeeData = employeeSnap.data?.data();
              final method =
                  employeeData?['payoutMethod']?.toString().toLowerCase();
              final hasAccount = method != null &&
                  ((method == 'bank' &&
                          (employeeData?['accountNumber']
                                  ?.toString()
                                  .isNotEmpty ??
                              false)) ||
                      (method == 'upi' &&
                          (employeeData?['upiId']?.toString().isNotEmpty ??
                              false)));

              return SingleChildScrollView(
                padding: const EdgeInsets.all(SaTokens.space16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Available Balance Header Card
                      _buildBalanceHeader(availableBalance),
                      const SizedBox(height: SaTokens.space24),

                      // Destination Card
                      _buildDestinationCard(
                        context,
                        hasAccount: hasAccount,
                        employeeData: employeeData,
                      ),
                      const SizedBox(height: SaTokens.space24),

                      if (!hasAccount) ...[
                        const SaInfoBanner(
                          title: 'Payout Account Required',
                          message:
                              'Please register your bank account or UPI ID before requesting a payout.',
                          variant: SaBannerVariant.warning,
                        ),
                        const SizedBox(height: SaTokens.space24),
                      ],

                      // Amount Input Card
                      Container(
                        padding: const EdgeInsets.all(SaTokens.space16),
                        decoration: BoxDecoration(
                          color: SaTokens.surface,
                          borderRadius:
                              BorderRadius.circular(SaTokens.radiusCard),
                          border: Border.all(color: SaTokens.divider),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payout Amount',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: SaTokens.space12),

                            TextFormField(
                              controller: _amountController,
                              keyboardType: TextInputType.number,
                              enabled: hasAccount && availableBalance > 0,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration(
                                prefixText: '₹ ',
                                hintText: 'Enter amount',
                              ),
                              validator: (v) {
                                final val = double.tryParse(v?.trim() ?? '');
                                if (val == null || val <= 0) {
                                  return 'Enter a valid payout amount';
                                }
                                if (val > availableBalance) {
                                  return 'Amount exceeds available balance';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: SaTokens.space16),

                            // Quick amount presets
                            const Text(
                              'Quick Presets',
                              style: TextStyle(
                                fontSize: SaTokens.fsCaption,
                                color: SaTokens.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: SaTokens.space8),
                            Row(
                              children: [
                                _buildPresetButton(
                                    1000, availableBalance, hasAccount),
                                const SizedBox(width: SaTokens.space8),
                                _buildPresetButton(
                                    2500, availableBalance, hasAccount),
                                const SizedBox(width: SaTokens.space8),
                                _buildPresetButton(
                                    5000, availableBalance, hasAccount),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: SaTokens.space24),

                      // Calculation summary
                      if (_enteredAmount > 0) ...[
                        Container(
                          padding: const EdgeInsets.all(SaTokens.space16),
                          decoration: BoxDecoration(
                            color: SaTokens.surface,
                            borderRadius:
                                BorderRadius.circular(SaTokens.radiusCard),
                            border: Border.all(color: SaTokens.divider),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Calculation Summary',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: SaTokens.space8),
                              _buildSummaryRow('Available Balance',
                                  SaFormatters.formatCurrency(availableBalance)),
                              _buildSummaryRow('Requested Amount',
                                  '- ${SaFormatters.formatCurrency(_enteredAmount)}'),
                              const Divider(height: 16, color: SaTokens.divider),
                              _buildSummaryRow(
                                'Remaining Balance',
                                SaFormatters.formatCurrency(
                                  (availableBalance - _enteredAmount)
                                      .clamp(0.0, double.infinity),
                                ),
                                isBold: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: SaTokens.space24),
                      ],

                      // Notice
                      const SaInfoBanner(
                        title: 'Settlement Information',
                        message:
                            'Requested payouts are deducted from your wallet balance immediately upon confirmation.',
                        variant: SaBannerVariant.info,
                      ),
                      const SizedBox(height: SaTokens.space32),

                      // Next action
                      SaLoadingButton(
                        text: 'Review Payout Request',
                        onPressed: (!hasAccount ||
                                availableBalance <= 0 ||
                                _enteredAmount <= 0 ||
                                _enteredAmount > availableBalance)
                            ? null
                            : () {
                                if (!_formKey.currentState!.validate()) return;
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PayoutReviewScreen(
                                      requestedAmount: _enteredAmount,
                                      availableBalance: availableBalance,
                                      destinationData: employeeData!,
                                    ),
                                  ),
                                );
                              },
                      ),
                      const SizedBox(height: SaTokens.space24),
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

  Widget _buildBalanceHeader(double balance) {
    return Container(
      padding: const EdgeInsets.all(SaTokens.space24),
      decoration: BoxDecoration(
        color: SaTokens.surface,
        borderRadius: BorderRadius.circular(SaTokens.radiusCard),
        border: Border.all(color: SaTokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Available for Payout',
            style: TextStyle(
              fontSize: SaTokens.fsCaption,
              color: SaTokens.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: SaTokens.space4),
          Text(
            SaFormatters.formatCurrency(balance),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: SaTokens.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDestinationCard(
    BuildContext context, {
    required bool hasAccount,
    required Map<String, dynamic>? employeeData,
  }) {
    final method = employeeData?['payoutMethod']?.toString().toLowerCase();
    final isBank = method == 'bank';
    final accNum = employeeData?['accountNumber']?.toString() ?? '';
    final bankName = employeeData?['bankName']?.toString() ?? 'Bank Account';
    final upiId = employeeData?['upiId']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(SaTokens.space16),
      decoration: BoxDecoration(
        color: SaTokens.surface,
        borderRadius: BorderRadius.circular(SaTokens.radiusCard),
        border: Border.all(color: SaTokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Destination Account',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PayoutAccountScreen(),
                    ),
                  );
                },
                child: Text(hasAccount ? 'Change' : 'Set up'),
              ),
            ],
          ),
          const SizedBox(height: SaTokens.space8),
          if (hasAccount) ...[
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: SaTokens.primarySubtle,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isBank ? Icons.account_balance : Icons.qr_code,
                    color: SaTokens.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: SaTokens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isBank ? bankName : 'UPI ID',
                        style: const TextStyle(
                          fontSize: SaTokens.fsBody,
                          fontWeight: FontWeight.w700,
                          color: SaTokens.textPrimary,
                        ),
                      ),
                      Text(
                        isBank
                            ? SaFormatters.formatMaskedAccount(accNum)
                            : upiId,
                        style: const TextStyle(
                          fontSize: SaTokens.fsLabel,
                          color: SaTokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            const Text(
              'No payout account linked yet.',
              style: TextStyle(
                fontSize: SaTokens.fsLabel,
                color: SaTokens.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPresetButton(
    double amount,
    double availableBalance,
    bool hasAccount,
  ) {
    final disabled = !hasAccount || amount > availableBalance;
    final isSelected = _enteredAmount == amount;

    return Expanded(
      child: OutlinedButton(
        onPressed: disabled ? null : () => _applyPreset(amount, availableBalance),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10),
          backgroundColor:
              isSelected ? SaTokens.primarySubtle : Colors.transparent,
          side: BorderSide(
            color: isSelected ? SaTokens.primary : SaTokens.divider,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SaTokens.radiusInput),
          ),
        ),
        child: Text(
          '₹${amount.toInt()}',
          style: TextStyle(
            fontSize: SaTokens.fsLabel,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? SaTokens.primary
                : (disabled
                    ? SaTokens.disabledContent
                    : SaTokens.textPrimary),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: SaTokens.fsLabel,
              color: isBold ? SaTokens.textPrimary : SaTokens.textSecondary,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: SaTokens.fsLabel,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
              color: SaTokens.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
