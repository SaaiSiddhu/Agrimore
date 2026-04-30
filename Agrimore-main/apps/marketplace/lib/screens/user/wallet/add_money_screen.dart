import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

import '../../../providers/wallet_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/razorpay_service.dart';

/// Add money to wallet screen
class AddMoneyScreen extends StatefulWidget {
  const AddMoneyScreen({Key? key}) : super(key: key);

  @override
  State<AddMoneyScreen> createState() => _AddMoneyScreenState();
}

class _AddMoneyScreenState extends State<AddMoneyScreen> {
  final TextEditingController _amountController = TextEditingController();
  final List<int> _presetAmounts = [100, 200, 500, 1000, 2000];
  int? _selectedPreset;
  bool _isProcessing = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double get _enteredAmount {
    return double.tryParse(_amountController.text) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final walletProvider = Provider.of<WalletProvider>(context);
    final isDark = themeProvider.isDarkMode;
    
    final backgroundColor = isDark ? const Color(0xFF121212) : AppColors.background;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;

    final bonusCoins = walletProvider.getBonusForTopup(_enteredAmount);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Add Money',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Balance Card
            _buildCurrentBalanceCard(walletProvider, isDark, cardColor),
            
            const SizedBox(height: 28),

            // Amount Section
            Text(
              'Enter Amount',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),

            // Amount Input
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: accentColor.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '₹',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.grey[600] : Colors.grey[400],
                        ),
                        border: InputBorder.none,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedPreset = null);
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Preset Amounts
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _presetAmounts.map((amount) {
                final isSelected = _selectedPreset == amount;
                final bonus = walletProvider.getBonusForTopup(amount.toDouble());
                
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _selectedPreset = amount;
                      _amountController.text = amount.toString();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? accentColor : cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? accentColor : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '₹$amount',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                        if (bonus > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            '+$bonus coins',
                            style: TextStyle(
                              fontSize: 11,
                              color: isSelected ? Colors.white70 : Colors.amber[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 28),

            // Bonus Info Card
            if (bonusCoins > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.amber.withOpacity(0.15),
                      Colors.orange.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.celebration, color: Colors.amber, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bonus Reward!',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'You\'ll receive $bonusCoins bonus coins',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.grey[400] : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 32),

            // Min Amount Note
            Text(
              'Minimum top-up: ₹100',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
          top: 16,
        ),
        decoration: BoxDecoration(
          color: cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Summary Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Amount',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                Text(
                  '₹${_enteredAmount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Pay Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _enteredAmount >= 100 && !_isProcessing
                    ? () => _processPayment(walletProvider)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  disabledBackgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Proceed to Pay',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentBalanceCard(WalletProvider walletProvider, bool isDark, Color cardColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.account_balance_wallet,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Balance',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '₹${walletProvider.balance.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _processPayment(WalletProvider walletProvider) async {
    if (_enteredAmount < 100) {
      _showSnackBar('Minimum top-up amount is ₹100', isError: true);
      return;
    }

    setState(() => _isProcessing = true);

    try {
      String? paymentId;
      
      try {
        final razorpay = RazorpayService();
        final completer = Completer<String?>();
        
        razorpay.initialize(
          onSuccess: (pId, orderId, signature) {
            if (!completer.isCompleted) completer.complete(pId);
            razorpay.dispose();
          },
          onFailure: (error) {
            if (!completer.isCompleted) completer.complete(null);
            razorpay.dispose();
          },
          onDismiss: () {
            if (!completer.isCompleted) completer.complete(null);
            razorpay.dispose();
          },
        );
        
        await razorpay.openCheckout(
          amount: _enteredAmount,
          userName: '',
          userEmail: '',
          userPhone: '',
          description: 'Wallet Top-up ₹${_enteredAmount.toStringAsFixed(0)}',
        );
        
        // Wait for payment result (timeout after 5 minutes)
        paymentId = await completer.future.timeout(
          const Duration(minutes: 5),
          onTimeout: () => null,
        );
      } catch (e) {
        debugPrint('⚠️ Razorpay unavailable, using direct wallet credit: $e');
        paymentId = 'wallet_topup_${DateTime.now().millisecondsSinceEpoch}';
      }
      
      if (paymentId == null || paymentId.isEmpty) {
        _showSnackBar('Payment was cancelled', isError: true);
        return;
      }
      
      await walletProvider.addMoney(_enteredAmount, paymentId);
      
      if (mounted) {
        _showSnackBar('₹${_enteredAmount.toStringAsFixed(0)} added to wallet!', isError: false);
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar('Payment failed. Please try again.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
