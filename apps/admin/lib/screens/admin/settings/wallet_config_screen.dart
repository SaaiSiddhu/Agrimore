import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/wallet_config_provider.dart';
import '../../../providers/theme_provider.dart';

/// Admin screen for configuring wallet settings
class WalletConfigScreen extends StatefulWidget {
  const WalletConfigScreen({Key? key}) : super(key: key);

  @override
  State<WalletConfigScreen> createState() => _WalletConfigScreenState();
}

class _WalletConfigScreenState extends State<WalletConfigScreen> {
  // Referral controllers
  final _referrerBonusController = TextEditingController();
  final _referredBonusController = TextEditingController();
  final _firstOrderBonusController = TextEditingController();

  // Coin controllers
  final _maxCoinsPercentageController = TextEditingController();
  final _minOrderController = TextEditingController();

  // Bonus controllers
  final _signupBonusController = TextEditingController();
  final _cashbackController = TextEditingController();
  final _firstOrderCashbackController = TextEditingController();

  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadControllerValues();
    });
  }

  void _loadControllerValues() {
    final config = context.read<WalletConfigProvider>();
    _referrerBonusController.text = config.referrerBonus.toString();
    _referredBonusController.text = config.referredBonus.toString();
    _firstOrderBonusController.text = config.referralFirstOrderBonus.toString();
    _maxCoinsPercentageController.text = config.maxCoinsPercentage.toString();
    _minOrderController.text = config.minOrderForCoins.toString();
    _signupBonusController.text = config.signupBonus.toString();
    _cashbackController.text = config.cashbackPercentage.toString();
    _firstOrderCashbackController.text = config.firstOrderCashback.toString();
  }

  @override
  void dispose() {
    _referrerBonusController.dispose();
    _referredBonusController.dispose();
    _firstOrderBonusController.dispose();
    _maxCoinsPercentageController.dispose();
    _minOrderController.dispose();
    _signupBonusController.dispose();
    _cashbackController.dispose();
    _firstOrderCashbackController.dispose();
    super.dispose();
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  Future<void> _saveChanges() async {
    final provider = context.read<WalletConfigProvider>();

    // Update all values
    provider.updateReferralBonuses(
      referrerBonus: int.tryParse(_referrerBonusController.text) ?? 50,
      referredBonus: int.tryParse(_referredBonusController.text) ?? 25,
      firstOrderBonus: int.tryParse(_firstOrderBonusController.text) ?? 100,
    );

    provider.updateCoinSettings(
      maxPercentage: double.tryParse(_maxCoinsPercentageController.text) ?? 20,
      minOrder: double.tryParse(_minOrderController.text) ?? 100,
    );

    provider.updateBonusSettings(
      signupBonus: int.tryParse(_signupBonusController.text) ?? 50,
      cashbackPercentage: double.tryParse(_cashbackController.text) ?? 2,
      firstOrderCashback: double.tryParse(_firstOrderCashbackController.text) ?? 5,
    );

    final success = await provider.saveConfig();

    if (mounted) {
      setState(() => _hasChanges = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle : Icons.error,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(success ? 'Settings saved!' : 'Failed to save'),
            ],
          ),
          backgroundColor: success ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final provider = context.watch<WalletConfigProvider>();

    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final accentColor = isDark ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32);

    if (provider.isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(
          child: CircularProgressIndicator(color: accentColor),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        title: Text(
          'Wallet Settings',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          if (_hasChanges || provider.isSaving)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: ElevatedButton.icon(
                onPressed: provider.isSaving ? null : _saveChanges,
                icon: provider.isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save, size: 18),
                label: Text(provider.isSaving ? 'Saving...' : 'Save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Feature Toggles
            _buildSection(
              title: 'Feature Toggles',
              icon: Icons.toggle_on,
              isDark: isDark,
              cardColor: cardColor,
              accentColor: accentColor,
              children: [
                _buildSwitchTile(
                  title: 'Enable Wallet',
                  subtitle: 'Allow users to use wallet balance',
                  value: provider.isWalletEnabled,
                  onChanged: (v) {
                    provider.updateFeatureToggles(walletEnabled: v);
                    _markChanged();
                  },
                  isDark: isDark,
                  accentColor: accentColor,
                ),
                _buildSwitchTile(
                  title: 'Enable Coins',
                  subtitle: 'Allow users to earn and use coins',
                  value: provider.isCoinsEnabled,
                  onChanged: (v) {
                    provider.updateFeatureToggles(coinsEnabled: v);
                    _markChanged();
                  },
                  isDark: isDark,
                  accentColor: accentColor,
                ),
                _buildSwitchTile(
                  title: 'Enable Referrals',
                  subtitle: 'Allow referral program',
                  value: provider.isReferralEnabled,
                  onChanged: (v) {
                    provider.updateFeatureToggles(referralEnabled: v);
                    _markChanged();
                  },
                  isDark: isDark,
                  accentColor: accentColor,
                ),
                _buildSwitchTile(
                  title: 'Enable Cashback',
                  subtitle: 'Allow cashback on orders',
                  value: provider.isCashbackEnabled,
                  onChanged: (v) {
                    provider.updateFeatureToggles(cashbackEnabled: v);
                    _markChanged();
                  },
                  isDark: isDark,
                  accentColor: accentColor,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Referral Bonuses
            _buildSection(
              title: 'Referral Bonuses',
              icon: Icons.people,
              isDark: isDark,
              cardColor: cardColor,
              accentColor: accentColor,
              children: [
                _buildNumberField(
                  label: 'Referrer Bonus (coins)',
                  controller: _referrerBonusController,
                  hint: 'Coins given to referrer',
                  isDark: isDark,
                  onChanged: _markChanged,
                ),
                const SizedBox(height: 12),
                _buildNumberField(
                  label: 'Referred Bonus (coins)',
                  controller: _referredBonusController,
                  hint: 'Coins given to new user',
                  isDark: isDark,
                  onChanged: _markChanged,
                ),
                const SizedBox(height: 12),
                _buildNumberField(
                  label: 'First Order Bonus (coins)',
                  controller: _firstOrderBonusController,
                  hint: 'Extra coins on first order',
                  isDark: isDark,
                  onChanged: _markChanged,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Coin Settings
            _buildSection(
              title: 'Coin Usage Limits',
              icon: Icons.monetization_on,
              isDark: isDark,
              cardColor: cardColor,
              accentColor: accentColor,
              children: [
                _buildNumberField(
                  label: 'Max Coins % per Order',
                  controller: _maxCoinsPercentageController,
                  hint: 'Maximum % of order payable by coins',
                  isDark: isDark,
                  isDecimal: true,
                  suffix: '%',
                  onChanged: _markChanged,
                ),
                const SizedBox(height: 12),
                _buildNumberField(
                  label: 'Minimum Order for Coins',
                  controller: _minOrderController,
                  hint: 'Min order value to use coins',
                  isDark: isDark,
                  isDecimal: true,
                  prefix: '₹',
                  onChanged: _markChanged,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Bonus Settings
            _buildSection(
              title: 'Bonus & Cashback',
              icon: Icons.card_giftcard,
              isDark: isDark,
              cardColor: cardColor,
              accentColor: accentColor,
              children: [
                _buildNumberField(
                  label: 'Sign-up Bonus (coins)',
                  controller: _signupBonusController,
                  hint: 'Coins on new registration',
                  isDark: isDark,
                  onChanged: _markChanged,
                ),
                const SizedBox(height: 12),
                _buildNumberField(
                  label: 'Order Cashback %',
                  controller: _cashbackController,
                  hint: 'Cashback on every order',
                  isDark: isDark,
                  isDecimal: true,
                  suffix: '%',
                  onChanged: _markChanged,
                ),
                const SizedBox(height: 12),
                _buildNumberField(
                  label: 'First Order Cashback %',
                  controller: _firstOrderCashbackController,
                  hint: 'Cashback for first order',
                  isDark: isDark,
                  isDecimal: true,
                  suffix: '%',
                  onChanged: _markChanged,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Top-up Bonuses
            _buildSection(
              title: 'Top-up Bonus Tiers',
              icon: Icons.trending_up,
              isDark: isDark,
              cardColor: cardColor,
              accentColor: accentColor,
              trailing: IconButton(
                icon: Icon(Icons.add_circle, color: accentColor),
                onPressed: () => _showAddTopupBonusDialog(isDark, accentColor),
              ),
              children: [
                if (provider.topupBonuses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No bonus tiers configured',
                      style: TextStyle(
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                else
                  ..._buildTopupBonusTiles(provider.topupBonuses, isDark, accentColor),
              ],
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTopupBonusTiles(Map<int, int> bonuses, bool isDark, Color accentColor) {
    final sortedAmounts = bonuses.keys.toList()..sort();
    return sortedAmounts.map((amount) {
      final coins = bonuses[amount]!;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.monetization_on,
                  color: Colors.amber[700],
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add ₹$amount+',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      'Get $coins bonus coins',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.edit, size: 18, color: accentColor),
                onPressed: () => _showEditTopupBonusDialog(amount, coins, isDark, accentColor),
              ),
              IconButton(
                icon: Icon(Icons.delete, size: 18, color: Colors.red[400]),
                onPressed: () {
                  context.read<WalletConfigProvider>().removeTopupBonus(amount);
                  _markChanged();
                },
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required bool isDark,
    required Color cardColor,
    required Color accentColor,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
            child: Row(
              children: [
                Icon(icon, size: 20, color: accentColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? Colors.grey[800] : Colors.grey[200],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
    required Color accentColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: accentColor,
          ),
        ],
      ),
    );
  }

  Widget _buildNumberField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    bool isDecimal = false,
    String? prefix,
    String? suffix,
    VoidCallback? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
          inputFormatters: [
            if (isDecimal)
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
            else
              FilteringTextInputFormatter.digitsOnly,
          ],
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark ? Colors.grey[600] : Colors.grey[400],
              fontSize: 13,
            ),
            prefixText: prefix,
            suffixText: suffix,
            filled: true,
            fillColor: isDark ? Colors.grey[850] : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          onChanged: (_) => onChanged?.call(),
        ),
      ],
    );
  }

  void _showAddTopupBonusDialog(bool isDark, Color accentColor) {
    final amountController = TextEditingController();
    final coinsController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          'Add Top-up Bonus Tier',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Minimum Amount (₹)',
                labelStyle: TextStyle(color: isDark ? Colors.grey[400] : null),
              ),
              style: TextStyle(color: isDark ? Colors.white : null),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: coinsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Bonus Coins',
                labelStyle: TextStyle(color: isDark ? Colors.grey[400] : null),
              ),
              style: TextStyle(color: isDark ? Colors.white : null),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = int.tryParse(amountController.text) ?? 0;
              final coins = int.tryParse(coinsController.text) ?? 0;
              if (amount > 0 && coins > 0) {
                context.read<WalletConfigProvider>().addTopupBonus(amount, coins);
                _markChanged();
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: accentColor),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditTopupBonusDialog(int oldAmount, int oldCoins, bool isDark, Color accentColor) {
    final amountController = TextEditingController(text: oldAmount.toString());
    final coinsController = TextEditingController(text: oldCoins.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          'Edit Top-up Bonus Tier',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Minimum Amount (₹)',
                labelStyle: TextStyle(color: isDark ? Colors.grey[400] : null),
              ),
              style: TextStyle(color: isDark ? Colors.white : null),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: coinsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Bonus Coins',
                labelStyle: TextStyle(color: isDark ? Colors.grey[400] : null),
              ),
              style: TextStyle(color: isDark ? Colors.white : null),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = int.tryParse(amountController.text) ?? 0;
              final coins = int.tryParse(coinsController.text) ?? 0;
              if (amount > 0 && coins > 0) {
                context.read<WalletConfigProvider>().editTopupBonus(oldAmount, amount, coins);
                _markChanged();
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: accentColor),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
