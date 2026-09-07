import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/ai_connection_provider.dart';
import '../../../providers/wallet_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  bool _pushNotifications = true;
  bool _emailNotifications = false;
  bool _orderUpdates = true;
  bool _promotions = false;
  bool _showPrices = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _fadeController.forward();

    // Mirrors profile_screen.dart's own pattern for WalletProvider: loaded
    // here so a user who opens Settings without ever visiting Wallet still
    // sees a real balance in the AI Assistant section below, not a stale
    // zero.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AiConnectionProvider>().loadStatus();
      context.read<WalletProvider>().loadWallet();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {required bool isDark}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
    required bool isDark,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
                ),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : AppColors.primary,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.white),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          children: [
            // Appearance Section
            _buildSectionTitle('Appearance', isDark),
            _buildSettingCard(
              isDark: isDark,
              children: [
                _buildSwitchTile(
                  title: 'Dark Mode',
                  subtitle: isDark ? 'Dark theme enabled' : 'Light theme enabled',
                  icon: isDark ? Icons.dark_mode : Icons.light_mode,
                  iconColor: isDark ? Colors.purple.shade300 : Colors.purple,
                  value: isDark,
                  isDark: isDark,
                  onChanged: (value) async {
                    HapticFeedback.mediumImpact();
                    await themeProvider.toggleTheme();
                    if (mounted) {
                      _showSnackBar(
                        value ? '🌙 Dark mode enabled' : '☀️ Light mode enabled',
                        isDark: value,
                      );
                    }
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Notifications Section
            _buildSectionTitle('Notifications', isDark),
            _buildSettingCard(
              isDark: isDark,
              children: [
                _buildSwitchTile(
                  title: 'Push Notifications',
                  subtitle: 'Receive notifications on your device',
                  icon: Icons.notifications_active,
                  iconColor: isDark ? Colors.orange.shade300 : Colors.orange,
                  value: _pushNotifications,
                  isDark: isDark,
                  onChanged: (value) {
                    setState(() => _pushNotifications = value);
                    HapticFeedback.selectionClick();
                    _showSnackBar(
                      value
                          ? 'Push notifications enabled'
                          : 'Push notifications disabled',
                      isDark: isDark,
                    );
                  },
                ),
                Divider(
                  height: 1,
                  color: isDark ? Colors.grey[800] : Colors.grey[300],
                ),
                _buildSwitchTile(
                  title: 'Order Updates',
                  subtitle: 'Get notified about your order status',
                  icon: Icons.shopping_bag,
                  iconColor: isDark ? Colors.green.shade300 : Colors.green,
                  value: _orderUpdates,
                  isDark: isDark,
                  onChanged: (value) {
                    setState(() => _orderUpdates = value);
                    HapticFeedback.selectionClick();
                  },
                ),
                Divider(
                  height: 1,
                  color: isDark ? Colors.grey[800] : Colors.grey[300],
                ),
                _buildSwitchTile(
                  title: 'Email Notifications',
                  subtitle: 'Receive updates via email',
                  icon: Icons.email,
                  iconColor: isDark ? Colors.blue.shade300 : Colors.blue,
                  value: _emailNotifications,
                  isDark: isDark,
                  onChanged: (value) {
                    setState(() => _emailNotifications = value);
                    HapticFeedback.selectionClick();
                  },
                ),
                Divider(
                  height: 1,
                  color: isDark ? Colors.grey[800] : Colors.grey[300],
                ),
                _buildSwitchTile(
                  title: 'Promotions & Offers',
                  subtitle: 'Get exclusive deals and discounts',
                  icon: Icons.local_offer,
                  iconColor: isDark ? Colors.red.shade300 : Colors.red,
                  value: _promotions,
                  isDark: isDark,
                  onChanged: (value) {
                    setState(() => _promotions = value);
                    HapticFeedback.selectionClick();
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),

            // App Preferences Section
            _buildSectionTitle('App Preferences', isDark),
            _buildSettingCard(
              isDark: isDark,
              children: [
                _buildSwitchTile(
                  title: 'Show Product Prices',
                  subtitle: 'Display prices on product cards',
                  icon: Icons.attach_money,
                  iconColor: isDark ? Colors.teal.shade300 : Colors.teal,
                  value: _showPrices,
                  isDark: isDark,
                  onChanged: (value) {
                    setState(() => _showPrices = value);
                    HapticFeedback.selectionClick();
                  },
                ),
                Divider(
                  height: 1,
                  color: isDark ? Colors.grey[800] : Colors.grey[300],
                ),
                _buildActionTile(
                  title: 'Language',
                  subtitle: 'English (US)',
                  icon: Icons.language,
                  iconColor: isDark ? Colors.indigo.shade300 : Colors.indigo,
                  isDark: isDark,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pushNamed(context, '/language');
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),

            // AI Assistant Section (Phase AI-3)
            _buildAiAssistantSection(isDark),

            const SizedBox(height: 20),

            // Data & Storage Section
            _buildSectionTitle('Data & Storage', isDark),
            _buildSettingCard(
              isDark: isDark,
              children: [
                _buildActionTile(
                  title: 'Clear Cache',
                  subtitle: 'Free up storage space',
                  icon: Icons.delete_outline,
                  iconColor: Colors.red,
                  isDark: isDark,
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    final confirmed = await _showConfirmDialog(
                      title: 'Clear Cache',
                      message:
                          'This will clear all cached data. The app will reload.',
                      isDark: isDark,
                    );

                    if (confirmed && mounted) {
                      _showSnackBar('Cache cleared successfully',
                          isDark: isDark);
                    }
                  },
                ),
                Divider(
                  height: 1,
                  color: isDark ? Colors.grey[800] : Colors.grey[300],
                ),
                _buildActionTile(
                  title: 'Download Quality',
                  subtitle: 'High quality images',
                  icon: Icons.download_outlined,
                  iconColor: isDark ? Colors.blue.shade300 : Colors.blue,
                  isDark: isDark,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showSnackBar('Image quality set to high resolution',
                        isDark: isDark);
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),

            // About Section
            _buildSectionTitle('About', isDark),
            _buildSettingCard(
              isDark: isDark,
              children: [
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.info_outline,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  title: Text(
                    'App Version',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.success,
                          AppColors.success.withValues(alpha: 0.8)
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Latest',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Divider(
                  height: 1,
                  color: isDark ? Colors.grey[800] : Colors.grey[300],
                ),
                _buildActionTile(
                  title: 'Report a Bug',
                  subtitle: 'Help us improve',
                  icon: Icons.bug_report_outlined,
                  iconColor: isDark ? Colors.orange.shade300 : Colors.orange,
                  isDark: isDark,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showSnackBar('Bug report submitted. Thank you!', isDark: isDark);
                  },
                ),
                Divider(
                  height: 1,
                  color: isDark ? Colors.grey[800] : Colors.grey[300],
                ),
                _buildActionTile(
                  title: 'Terms & Conditions',
                  subtitle: 'Read our terms',
                  icon: Icons.description_outlined,
                  iconColor: Colors.grey,
                  isDark: isDark,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pushNamed(context, '/terms');
                  },
                ),
              ],
            ),

            const SizedBox(height: 30),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  _showSnackBar('Settings saved successfully', isDark: isDark);
                },
                icon: const Icon(Icons.check_circle, size: 20),
                label: const Text(
                  'Save Settings',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.grey[400] : Colors.grey[700],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingCard({
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool value,
    required bool isDark,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ),
      trailing: Transform.scale(
        scale: 0.8,
        child: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: isDark ? AppColors.primaryLight : AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 16,
        color: isDark ? Colors.grey[600] : Colors.grey[400],
      ),
    );
  }

  // ==========================================================
  // AI Assistant (Phase AI-3)
  // ==========================================================
  // Unlike the switches above this section, every control here is wired to
  // a real backend effect — connectAiProvider/disconnectAiProvider
  // (functions/src/customer/aiConnection.ts, Phase AI-1) — not a local
  // setState() with nothing behind it.

  Widget _buildAiAssistantSection(bool isDark) {
    return Consumer2<AiConnectionProvider, WalletProvider>(
      builder: (context, aiConnection, wallet, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('AI Assistant', isDark),
            _buildSettingCard(
              isDark: isDark,
              children: [
                if (aiConnection.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else if (aiConnection.connected) ...[
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.smart_toy_outlined,
                          color: AppColors.success, size: 24),
                    ),
                    title: Text(
                      'Connected: ${_aiProviderLabel(aiConnection.provider)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        aiConnection.connectedAt != null
                            ? 'Since ${aiConnection.connectedAt!.day}/${aiConnection.connectedAt!.month}/${aiConnection.connectedAt!.year}'
                            : 'Active',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: isDark ? Colors.grey[800] : Colors.grey[300],
                  ),
                  _buildActionTile(
                    title: 'Change key or provider',
                    subtitle: 'Reconnect with a different key — no extra charge',
                    icon: Icons.sync,
                    iconColor: isDark ? Colors.blue.shade300 : Colors.blue,
                    isDark: isDark,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showAiConnectSheet(isDark, wallet.balance);
                    },
                  ),
                  Divider(
                    height: 1,
                    color: isDark ? Colors.grey[800] : Colors.grey[300],
                  ),
                  _buildActionTile(
                    title: 'Disconnect AI Assistant',
                    subtitle: 'The ₹50 activation fee is not refunded',
                    icon: Icons.link_off,
                    iconColor: Colors.red,
                    isDark: isDark,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      _confirmDisconnectAi(isDark);
                    },
                  ),
                ] else
                  _buildActionTile(
                    title: 'Connect AI Assistant',
                    subtitle:
                        'Use your own Gemini or ChatGPT key — ₹50 one-time activation',
                    icon: Icons.smart_toy_outlined,
                    iconColor: isDark ? Colors.purple.shade300 : Colors.purple,
                    isDark: isDark,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showAiConnectSheet(isDark, wallet.balance);
                    },
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  String _aiProviderLabel(String? provider) {
    switch (provider) {
      case 'gemini':
        return 'Gemini';
      case 'chatgpt':
        return 'ChatGPT';
      default:
        return 'AI Assistant';
    }
  }

  void _showAiConnectSheet(bool isDark, double walletBalance) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AiConnectFormSheet(isDark: isDark, walletBalance: walletBalance),
    );
  }

  Future<void> _confirmDisconnectAi(bool isDark) async {
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: 'Disconnect AI Assistant?',
      message:
          'Your key will be removed. The ₹50 activation fee is not refunded, and '
          'reconnecting later will charge ₹50 again.',
      confirmText: 'Disconnect',
      isDangerous: true,
    );
    if (confirmed == true && mounted) {
      final aiConnection = context.read<AiConnectionProvider>();
      try {
        await aiConnection.disconnect();
        if (mounted) {
          SnackbarHelper.showSuccess(context, 'AI Assistant disconnected');
        }
      } catch (_) {
        if (mounted) {
          SnackbarHelper.showError(
            context,
            aiConnection.error ?? 'Failed to disconnect',
          );
        }
      }
    }
  }
}

/// Bottom sheet form for connecting (or rotating) an AI provider key.
/// Isolated as its own StatefulWidget so its form state (the text
/// controller, the selected provider, the obscure-text toggle) doesn't leak
/// into _SettingsScreenState.
class _AiConnectFormSheet extends StatefulWidget {
  final bool isDark;
  final double walletBalance;

  const _AiConnectFormSheet({required this.isDark, required this.walletBalance});

  @override
  State<_AiConnectFormSheet> createState() => _AiConnectFormSheetState();
}

class _AiConnectFormSheetState extends State<_AiConnectFormSheet> {
  String _provider = 'gemini';
  bool _obscureKey = true;
  bool _submitting = false;
  final _keyController = TextEditingController();

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final apiKey = _keyController.text.trim();
    if (apiKey.isEmpty) {
      SnackbarHelper.showWarning(context, 'Enter your API key first');
      return;
    }
    if (widget.walletBalance < 50) {
      SnackbarHelper.showWarning(
        context,
        'You need at least ₹50 in your Agrimore Wallet to connect an AI provider',
      );
      return;
    }

    final providerName = _provider == 'gemini' ? 'Gemini' : 'ChatGPT';
    final providerCompany = _provider == 'gemini' ? 'Google' : 'OpenAI';
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: 'Connect $providerName?',
      message:
          'AgriMore charges a one-time ₹50 activation fee from your Wallet. '
          'Any usage cost your own $providerName key incurs afterwards is billed '
          'to you directly by $providerCompany, not AgriMore.',
      confirmText: 'Connect for ₹50',
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    final aiConnection = context.read<AiConnectionProvider>();
    try {
      await aiConnection.connect(provider: _provider, apiKey: apiKey);
      if (mounted) {
        Navigator.of(context).pop();
        SnackbarHelper.showSuccess(context, 'AI Assistant connected');
      }
    } catch (_) {
      if (mounted) {
        SnackbarHelper.showError(
          context,
          aiConnection.error ?? 'Failed to connect AI Assistant',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connect AI Assistant',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Gemini'),
                  value: 'gemini',
                  groupValue: _provider,
                  onChanged: (v) => setState(() => _provider = v!),
                ),
              ),
              Expanded(
                child: RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('ChatGPT'),
                  value: 'chatgpt',
                  groupValue: _provider,
                  onChanged: (v) => setState(() => _provider = v!),
                ),
              ),
            ],
          ),
          TextField(
            controller: _keyController,
            obscureText: _obscureKey,
            decoration: InputDecoration(
              labelText: '${_provider == 'gemini' ? 'Gemini' : 'ChatGPT'} API key',
              suffixIcon: IconButton(
                icon: Icon(_obscureKey ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isDark ? AppColors.primaryLight : AppColors.primary)
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'AgriMore charges a one-time ₹50 activation fee from your Wallet. '
              'This is separate from your AI provider\'s own usage charges, if '
              'any — those are billed to you directly by Google/OpenAI, never '
              'by AgriMore.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Wallet balance: ${PriceFormatter.formatPrice(widget.walletBalance)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Connect for ₹50',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
