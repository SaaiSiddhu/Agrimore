import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../utils/sa_formatters.dart';
import 'payout_details_screen.dart';

/// Confirmation boundary screen before submitting an irreversible wallet payout debit.
///
/// Ensures the associate clearly reviews the amount, destination, and resulting
/// wallet balance before invoking the real `requestEmployeePayout` Cloud Function.
class PayoutReviewScreen extends StatefulWidget {
  final double requestedAmount;
  final double availableBalance;
  final Map<String, dynamic> destinationData;

  const PayoutReviewScreen({
    super.key,
    required this.requestedAmount,
    required this.availableBalance,
    required this.destinationData,
  });

  @override
  State<PayoutReviewScreen> createState() => _PayoutReviewScreenState();
}

class _PayoutReviewScreenState extends State<PayoutReviewScreen> {
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('requestEmployeePayout');
      final result = await callable.call({'amount': widget.requestedAmount});

      if (!mounted) return;

      final resData = result.data;
      final payoutId = (resData is Map && resData['payoutId'] != null)
          ? resData['payoutId'].toString()
          : 'recent';

      // Replace this screen with the PayoutDetailsScreen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PayoutDetailsScreen(
            payoutId: payoutId,
            initialData: {
              'amount': widget.requestedAmount,
              'status': 'requested',
              'payoutMethod': widget.destinationData['payoutMethod'] ?? 'bank',
              'destination': widget.destinationData['accountNumber'] ??
                  widget.destinationData['upiId'] ??
                  'Registered Account',
              'createdAt': DateTime.now(),
            },
          ),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.message ?? 'Failed to process payout request';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'An error occurred: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.saTokens;
    final balanceAfter = widget.availableBalance - widget.requestedAmount;
    final method = widget.destinationData['payoutMethod']?.toString().toLowerCase();
    final isBank = method == 'bank';
    final accNum = widget.destinationData['accountNumber']?.toString() ?? '';
    final bankName = widget.destinationData['bankName']?.toString() ?? 'Bank Account';
    final upiId = widget.destinationData['upiId']?.toString() ?? '';
    final holderName = widget.destinationData['accountHolderName']?.toString() ?? '';

    return Scaffold(
      backgroundColor: tokens.pageBackground,
      appBar: AppBar(
        title: const Text('Review Payout'),
        leading: IconButton(
          icon: const Icon(SaIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SaTokens.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Confirm Payout Request',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: SaTokens.space4),
              Text(
                'Please verify the transfer details and debit calculation before submitting.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: SaTokens.space24),

              if (_errorMessage != null) ...[
                SaInfoBanner(
                  title: 'Submission Error',
                  message: _errorMessage!,
                  variant: SaBannerVariant.error,
                ),
                const SizedBox(height: SaTokens.space16),
              ],

              // Amount Card
              Container(
                padding: const EdgeInsets.all(SaTokens.space24),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(SaTokens.radiusCard),
                  border: Border.all(color: tokens.primary, width: 1.5),
                ),
                child: Column(
                  children: [
                    Text(
                      'Requested Payout Amount',
                      style: TextStyle(
                        fontSize: SaTokens.fsCaption,
                        color: tokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: SaTokens.space4),
                    Text(
                      SaFormatters.formatCurrency(widget.requestedAmount),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: tokens.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SaTokens.space16),

              // Destination Account Card
              Container(
                padding: const EdgeInsets.all(SaTokens.space16),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(SaTokens.radiusCard),
                  border: Border.all(color: tokens.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transfer Destination',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: SaTokens.space12),
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: tokens.primarySubtle,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isBank ? Icons.account_balance : Icons.qr_code,
                            color: tokens.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: SaTokens.space12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isBank ? bankName : 'UPI ID',
                                style: TextStyle(
                                  fontSize: SaTokens.fsBody,
                                  fontWeight: FontWeight.w700,
                                  color: tokens.textPrimary,
                                ),
                              ),
                              Text(
                                isBank
                                    ? SaFormatters.formatMaskedAccount(accNum)
                                    : upiId,
                                style: TextStyle(
                                  fontSize: SaTokens.fsLabel,
                                  color: tokens.textSecondary,
                                ),
                              ),
                              if (holderName.isNotEmpty)
                                Text(
                                  'Holder: $holderName',
                                  style: TextStyle(
                                    fontSize: SaTokens.fsCaption,
                                    color: tokens.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SaTokens.space16),

              // Financial Ledger Calculation Breakdown
              Container(
                padding: const EdgeInsets.all(SaTokens.space16),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(SaTokens.radiusCard),
                  border: Border.all(color: tokens.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Balance Breakdown',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: SaTokens.space12),
                    _buildRow(
                      'Available Balance',
                      SaFormatters.formatCurrency(widget.availableBalance),
                      tokens,
                    ),
                    _buildRow(
                      'Deduction Amount',
                      '- ${SaFormatters.formatCurrency(widget.requestedAmount)}',
                      tokens,
                      valueColor: tokens.errorFg,
                    ),
                    Divider(height: 20, color: tokens.divider),
                    _buildRow(
                      'Remaining Balance',
                      SaFormatters.formatCurrency(balanceAfter),
                      tokens,
                      isBold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SaTokens.space16),

              // Important Immediate Debit notice
              const SaInfoBanner(
                title: 'Immediate Wallet Debit',
                message:
                    'When you confirm, the requested amount is deducted from your wallet immediately while bank settlement is initiated.',
                variant: SaBannerVariant.warning,
              ),
              const SizedBox(height: SaTokens.space32),

              // Submit Action
              SaLoadingButton(
                text: 'Confirm & Request Payout',
                isLoading: _isSubmitting,
                onPressed: _handleSubmit,
              ),
              const SizedBox(height: SaTokens.space16),

              Center(
                child: TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel & Change Amount'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(
    String label,
    String value,
    SalesAssociateTokens tokens, {
    Color? valueColor,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: SaTokens.fsLabel,
              color: isBold ? tokens.textPrimary : tokens.textSecondary,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: SaTokens.fsLabel,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
              color: valueColor ?? tokens.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
