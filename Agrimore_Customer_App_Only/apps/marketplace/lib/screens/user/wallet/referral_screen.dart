import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

import '../../../providers/wallet_provider.dart';
import '../../../providers/theme_provider.dart';

/// Referral screen for sharing referral code and entering friend's code
class ReferralScreen extends StatefulWidget {
  const ReferralScreen({Key? key}) : super(key: key);

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final _referralCodeController = TextEditingController();
  bool _isApplying = false;
  String? _errorMessage;

  @override
  void dispose() {
    _referralCodeController.dispose();
    super.dispose();
  }

  Future<void> _applyReferralCode() async {
    final code = _referralCodeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Please enter a referral code');
      return;
    }

    setState(() {
      _isApplying = true;
      _errorMessage = null;
    });

    try {
      final walletProvider = context.read<WalletProvider>();
      
      // Check if already referred
      if (walletProvider.wallet?.referredBy != null) {
        setState(() {
          _errorMessage = 'You have already used a referral code';
          _isApplying = false;
        });
        return;
      }

      // Validate code
      final isValid = await walletProvider.validateReferralCode(code);
      if (!isValid) {
        setState(() {
          _errorMessage = 'Invalid referral code';
          _isApplying = false;
        });
        return;
      }

      // Check if it's user's own code
      if (code == walletProvider.referralCode) {
        setState(() {
          _errorMessage = 'You cannot use your own code';
          _isApplying = false;
        });
        return;
      }

      // Apply the code
      await walletProvider.applyReferralCode(code);
      
      if (mounted) {
        setState(() => _isApplying = false);
        _referralCodeController.clear();
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.celebration, color: Colors.white),
                const SizedBox(width: 12),
                Text('🎉 You earned ${walletProvider.config.referredBonus} coins!'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to apply code. Try again.';
        _isApplying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final walletProvider = Provider.of<WalletProvider>(context);
    final isDark = themeProvider.isDarkMode;
    
    final backgroundColor = isDark ? const Color(0xFF121212) : AppColors.background;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final accentColor = const Color(0xFF6366F1);
    
    final hasAlreadyReferred = walletProvider.wallet?.referredBy != null;

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
          'Refer & Earn',
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
          children: [
            // Hero Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6366F1),
                    const Color(0xFF8B5CF6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.card_giftcard,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Earn ${walletProvider.config.referrerBonus} Coins',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'for every friend who joins!',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Referral Code Card (Your Code)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Your Referral Code',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: accentColor.withOpacity(0.3),
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          walletProvider.referralCode.isEmpty 
                              ? 'Loading...' 
                              : walletProvider.referralCode,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: walletProvider.referralCode));
                            HapticFeedback.lightImpact();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Row(
                                  children: [
                                    Icon(Icons.check, color: Colors.white),
                                    SizedBox(width: 12),
                                    Text('Code copied!'),
                                  ],
                                ),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                margin: const EdgeInsets.all(16),
                              ),
                            );
                          },
                          icon: Icon(
                            Icons.copy_rounded,
                            color: accentColor,
                          ),
                          tooltip: 'Copy code',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Share Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Share.share(walletProvider.generateShareText());
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.share, color: Colors.white),
                      label: const Text(
                        'Share with Friends',
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

            const SizedBox(height: 28),

            // Enter Friend's Referral Code (if not already referred)
            if (!hasAlreadyReferred)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.redeem, color: Colors.amber[700], size: 22),
                        const SizedBox(width: 10),
                        Text(
                          'Have a Referral Code?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your friend\'s code to earn ${walletProvider.config.referredBonus} coins!',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _referralCodeController,
                      textCapitalization: TextCapitalization.characters,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: 'XXXX00',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.grey[600] : Colors.grey[400],
                          letterSpacing: 2,
                        ),
                        filled: true,
                        fillColor: isDark ? Colors.grey[850] : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        prefixIcon: Icon(
                          Icons.confirmation_number_outlined,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      onChanged: (_) {
                        if (_errorMessage != null) {
                          setState(() => _errorMessage = null);
                        }
                      },
                    ),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.red[400],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isApplying ? null : _applyReferralCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber[700],
                          disabledBackgroundColor: Colors.amber[200],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isApplying
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Apply Code',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              )
            else
              // Already referred badge
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[600], size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Referral Applied!',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                          Text(
                            'Code: ${walletProvider.wallet?.referredBy}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 28),

            // How It Works
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How it works',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildStep(
                    1,
                    'Share your code',
                    'Send your unique referral code to friends',
                    Icons.share,
                    isDark,
                    accentColor,
                  ),
                  const SizedBox(height: 16),
                  _buildStep(
                    2,
                    'Friend signs up',
                    'They use your code during registration',
                    Icons.person_add,
                    isDark,
                    accentColor,
                  ),
                  const SizedBox(height: 16),
                  _buildStep(
                    3,
                    'Both earn coins!',
                    'You get ${walletProvider.config.referrerBonus} coins, friend gets ${walletProvider.config.referredBonus}',
                    Icons.celebration,
                    isDark,
                    accentColor,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Stats Card
            if (walletProvider.wallet != null && walletProvider.wallet!.referralCount > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '${walletProvider.wallet!.referralCount}',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Referrals',
                            style: TextStyle(
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 50,
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '${walletProvider.wallet!.referralCount * walletProvider.config.referrerBonus}',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Coins Earned',
                            style: TextStyle(
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(int number, String title, String subtitle, IconData icon, bool isDark, Color accentColor) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              '$number',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        Icon(icon, color: accentColor.withOpacity(0.5), size: 20),
      ],
    );
  }
}
