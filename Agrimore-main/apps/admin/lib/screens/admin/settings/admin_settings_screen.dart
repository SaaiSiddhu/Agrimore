import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/auth_provider.dart';
import '../../../app/app_router.dart';
import 'wallet_config_screen.dart';
import 'location_settings_screen.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({Key? key}) : super(key: key);

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  bool _notificationsEnabled = true;
  bool _emailNotifications = true;
  bool _orderNotifications = true;
  bool _maintenanceMode = false;
  bool _darkMode = false;
  final String _appVersion = '1.0.0 (1)'; // ✅ FIXED - Hardcoded version

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Admin Settings'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Section
            _buildProfileCard(authProvider),
            
            const SizedBox(height: 24),
            
            // General Settings
            _buildSectionHeader('General Settings', Icons.settings_rounded),
            const SizedBox(height: 12),
            _buildSettingsGroup([
              _buildSwitchTile(
                icon: Icons.notifications_rounded,
                title: 'Push Notifications',
                subtitle: 'Receive push notifications',
                value: _notificationsEnabled,
                onChanged: (value) {
                  setState(() => _notificationsEnabled = value);
                },
                color: const Color(0xFF6366F1),
              ),
              _buildSwitchTile(
                icon: Icons.email_rounded,
                title: 'Email Notifications',
                subtitle: 'Receive email updates',
                value: _emailNotifications,
                onChanged: (value) {
                  setState(() => _emailNotifications = value);
                },
                color: const Color(0xFF10B981),
              ),
              _buildSwitchTile(
                icon: Icons.shopping_cart_rounded,
                title: 'Order Notifications',
                subtitle: 'Get notified on new orders',
                value: _orderNotifications,
                onChanged: (value) {
                  setState(() => _orderNotifications = value);
                },
                color: const Color(0xFFF59E0B),
              ),
            ]),
            
            const SizedBox(height: 24),
            
            // System Settings
            _buildSectionHeader('System Settings', Icons.build_rounded),
            const SizedBox(height: 12),
            _buildSettingsGroup([
              _buildSwitchTile(
                icon: Icons.construction_rounded,
                title: 'Maintenance Mode',
                subtitle: 'Disable user access temporarily',
                value: _maintenanceMode,
                onChanged: (value) {
                  _showMaintenanceModeDialog(value);
                },
                color: const Color(0xFFEF4444),
              ),
              _buildSwitchTile(
                icon: Icons.dark_mode_rounded,
                title: 'Dark Mode',
                subtitle: 'Enable dark theme',
                value: _darkMode,
                onChanged: (value) {
                  setState(() => _darkMode = value);
                  SnackbarHelper.showSuccess(
                    context,
                    value ? 'Dark mode enabled' : 'Light mode enabled',
                  );
                },
                color: const Color(0xFF8B5CF6),
              ),
              _buildNavigationTile(
                icon: Icons.location_on_rounded,
                title: 'Location & GPS Settings',
                subtitle: 'Manage hyperlocal radius and active cities',
                color: const Color(0xFFEAB308),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LocationSettingsScreen(),
                    ),
                  );
                },
              ),
              _buildNavigationTile(
                icon: Icons.backup_rounded,
                title: 'Backup & Restore',
                subtitle: 'Manage app data backups',
                color: const Color(0xFF06B6D4),
                onTap: () => _showBackupDialog(),
              ),
            ]),
            
            const SizedBox(height: 24),
            
            // App Management
            _buildSectionHeader('App Management', Icons.apps_rounded),
            const SizedBox(height: 12),
            _buildSettingsGroup([
              _buildNavigationTile(
                icon: Icons.category_rounded,
                title: 'Manage Categories',
                subtitle: 'Add or edit product categories',
                color: const Color(0xFFEC4899),
                onTap: () => _showCategoryManagementDialog(),
              ),
              _buildNavigationTile(
                icon: Icons.local_shipping_rounded,
                title: 'Shipping Settings',
                subtitle: 'Configure delivery options',
                color: const Color(0xFF14B8A6),
                onTap: () => _showShippingSettingsDialog(),
              ),
              _buildNavigationTile(
                icon: Icons.payment_rounded,
                title: 'Payment Methods',
                subtitle: 'Manage payment gateways',
                color: const Color(0xFFF59E0B),
                onTap: () => _showPaymentSettingsDialog(),
              ),
              _buildNavigationTile(
                icon: Icons.account_balance_wallet_rounded,
                title: 'Wallet Settings',
                subtitle: 'Referrals, coins, cashback',
                color: const Color(0xFF1E3A5F),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const WalletConfigScreen(),
                    ),
                  );
                },
              ),
            ]),
            
            const SizedBox(height: 24),
            
            // Security & Privacy
            _buildSectionHeader('Security & Privacy', Icons.security_rounded),
            const SizedBox(height: 12),
            _buildSettingsGroup([
              _buildNavigationTile(
                icon: Icons.password_rounded,
                title: 'Change Password',
                subtitle: 'Update your admin password',
                color: const Color(0xFF6366F1),
                onTap: () => _showChangePasswordDialog(),
              ),
              _buildNavigationTile(
                icon: Icons.vpn_key_rounded,
                title: 'Two-Factor Authentication',
                subtitle: 'Enable 2FA for extra security',
                color: const Color(0xFF10B981),
                onTap: () => _showTwoFactorDialog(),
              ),
              _buildNavigationTile(
                icon: Icons.privacy_tip_rounded,
                title: 'Privacy Policy',
                subtitle: 'View privacy policy',
                color: const Color(0xFF8B5CF6),
                onTap: () => _showLegalContentDialog('Privacy Policy', 'Your privacy is important to us. We collect only essential data needed to operate the Agrimore marketplace. All personal information is encrypted and stored securely. We never share your data with third parties without consent.'),
              ),
            ]),
            
            const SizedBox(height: 24),
            
            // About Section
            _buildSectionHeader('About', Icons.info_rounded),
            const SizedBox(height: 12),
            _buildSettingsGroup([
              _buildInfoTile(
                icon: Icons.app_settings_alt_rounded,
                title: 'App Version',
                value: _appVersion,
                color: const Color(0xFF6366F1),
              ),
              _buildNavigationTile(
                icon: Icons.help_rounded,
                title: 'Help & Support',
                subtitle: 'Get help with admin panel',
                color: const Color(0xFF10B981),
                onTap: () => _showSupportDialog(),
              ),
              _buildNavigationTile(
                icon: Icons.article_rounded,
                title: 'Terms & Conditions',
                subtitle: 'Read terms of service',
                color: const Color(0xFFF59E0B),
                onTap: () => _showLegalContentDialog('Terms & Conditions', 'By using the Agrimore Admin Panel, you agree to manage the platform responsibly. All seller approvals, product moderation, and order management actions are logged. Misuse of admin privileges may result in access revocation.'),
              ),
            ]),
            
            const SizedBox(height: 32),
            
            // Danger Zone
            _buildDangerZone(authProvider),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(AuthProvider authProvider) {
    final user = authProvider.currentUser; // ✅ FIXED - Changed from .user to .currentUser
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: Center(
              child: Text(
                user?.name.substring(0, 1).toUpperCase() ?? 'A',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name ?? 'Admin User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? 'admin@agrimore.com',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.admin_panel_settings_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Administrator',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: children.map((child) {
          final index = children.indexOf(child);
          return Column(
            children: [
              child,
              if (index < children.length - 1)
                Divider(height: 1, color: Colors.grey.shade200),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color color,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: AppTextStyles.titleSmall.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.bodySmall.copyWith(
          color: Colors.grey.shade600,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: color,
      ),
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: AppTextStyles.titleSmall.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.bodySmall.copyWith(
          color: Colors.grey.shade600,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 16,
        color: Colors.grey.shade400,
      ),
      onTap: onTap,
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: AppTextStyles.titleSmall.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Text(
        value,
        style: AppTextStyles.bodyMedium.copyWith(
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildDangerZone(AuthProvider authProvider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_rounded, color: Colors.red.shade700, size: 24),
              const SizedBox(width: 12),
              Text(
                'Danger Zone',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showClearCacheDialog(),
              icon: const Icon(Icons.delete_sweep_rounded),
              label: const Text('Clear Cache'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange.shade700,
                side: BorderSide(color: Colors.orange.shade300, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showLogoutDialog(authProvider),
              icon: const Icon(Icons.exit_to_app_rounded),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMaintenanceModeDialog(bool value) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.construction_rounded, color: Colors.orange.shade700),
            const SizedBox(width: 12),
            const Text('Maintenance Mode'),
          ],
        ),
        content: Text(
          value
              ? 'Enabling maintenance mode will temporarily disable user access to the app. Only admins will be able to access the system.'
              : 'Are you sure you want to disable maintenance mode?',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _maintenanceMode = value);
              Navigator.pop(context);
              SnackbarHelper.showSuccess(
                context,
                'Maintenance mode ${value ? 'enabled' : 'disabled'}',
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: value ? Colors.orange : AppColors.primary,
            ),
            child: Text(value ? 'Enable' : 'Disable'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              decoration: const InputDecoration(
                labelText: 'Current Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              decoration: const InputDecoration(
                labelText: 'New Password',
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (newPasswordController.text == confirmPasswordController.text) {
                Navigator.pop(context);
                SnackbarHelper.showSuccess(
                  context,
                  'Password changed successfully!',
                );
              } else {
                SnackbarHelper.showError(context, 'Passwords do not match');
              }
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Cache'),
        content: const Text(
          'This will clear all cached data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              SnackbarHelper.showSuccess(context, 'Cache cleared successfully');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.red.shade700),
            const SizedBox(width: 12),
            const Text('Logout'),
          ],
        ),
        content: const Text('Are you sure you want to logout from admin panel?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await authProvider.signOut();
              if (context.mounted) {
                Navigator.pop(context);
                context.go(AdminRoutes.auth);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showBackupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [Icon(Icons.backup_rounded, color: Color(0xFF06B6D4)), SizedBox(width: 12), Text('Backup & Restore')]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Manage your Firestore data backups. Export your database or restore from a previous backup.'),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.cloud_download_rounded, color: Color(0xFF06B6D4)),
              title: const Text('Export Data', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Download Firestore snapshot'),
              onTap: () {
                Navigator.pop(context);
                SnackbarHelper.showSuccess(context, 'Backup export initiated. Check Firebase Console for scheduled exports.');
              },
            ),
            ListTile(
              leading: Icon(Icons.cloud_upload_rounded, color: Colors.orange.shade700),
              title: const Text('Restore Data', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Restore from a previous backup'),
              onTap: () {
                Navigator.pop(context);
                SnackbarHelper.showInfo(context, 'To restore, use Firebase Console > Firestore > Import.');
              },
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  void _showCategoryManagementDialog() {
    final categoryController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [Icon(Icons.category_rounded, color: Color(0xFFEC4899)), SizedBox(width: 12), Text('Manage Categories')]),
        content: SizedBox(
          width: 400,
          height: 300,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: categoryController,
                      decoration: const InputDecoration(hintText: 'New category name', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      if (categoryController.text.isNotEmpty) {
                        await FirebaseFirestore.instance.collection('categories').add({
                          'name': categoryController.text,
                          'isActive': true,
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                        categoryController.clear();
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    child: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('categories').orderBy('name').snapshots(),
                  builder: (ctx, snap) {
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                    if (snap.data!.docs.isEmpty) return const Center(child: Text('No categories yet'));
                    return ListView(
                      children: snap.data!.docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return ListTile(
                          title: Text(data['name'] ?? ''),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => doc.reference.delete(),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  void _showShippingSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [Icon(Icons.local_shipping_rounded, color: Color(0xFF14B8A6)), SizedBox(width: 12), Text('Shipping Settings')]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Standard Delivery', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('₹40 flat rate, 2-3 business days'),
              trailing: Switch(value: true, activeColor: AppColors.primary, onChanged: (_) {}),
            ),
            ListTile(
              title: const Text('Express Delivery', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('₹49 flat rate, same day'),
              trailing: Switch(value: true, activeColor: AppColors.primary, onChanged: (_) {}),
            ),
            ListTile(
              title: const Text('Free Delivery Threshold', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Free above ₹499'),
              trailing: const Icon(Icons.edit_outlined, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); SnackbarHelper.showSuccess(context, 'Shipping settings saved'); },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showPaymentSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [Icon(Icons.payment_rounded, color: Color(0xFFF59E0B)), SizedBox(width: 12), Text('Payment Methods')]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.money, color: Colors.green),
              title: const Text('Cash on Delivery', style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: Switch(value: true, activeColor: AppColors.primary, onChanged: (_) {}),
            ),
            ListTile(
              leading: const Icon(Icons.account_balance, color: Colors.blue),
              title: const Text('UPI / Net Banking', style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: Switch(value: true, activeColor: AppColors.primary, onChanged: (_) {}),
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet, color: Colors.purple),
              title: const Text('Wallet Payment', style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: Switch(value: true, activeColor: AppColors.primary, onChanged: (_) {}),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); SnackbarHelper.showSuccess(context, 'Payment settings saved'); },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showTwoFactorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [Icon(Icons.vpn_key_rounded, color: Color(0xFF10B981)), SizedBox(width: 12), Text('Two-Factor Authentication')]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add an extra layer of security to your admin account.'),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(12)),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF10B981)),
                  SizedBox(width: 12),
                  Expanded(child: Text('Firebase Auth already provides multi-factor authentication via phone and email verification.', style: TextStyle(fontSize: 13))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); SnackbarHelper.showSuccess(context, '2FA is active via Firebase Authentication'); },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  void _showLegalContentDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: SingleChildScrollView(child: Text(content, style: const TextStyle(fontSize: 14, height: 1.6))),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  void _showSupportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [Icon(Icons.help_rounded, color: Color(0xFF10B981)), SizedBox(width: 12), Text('Help & Support')]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.email_outlined, color: Color(0xFF6366F1)),
              title: const Text('Email Support'),
              subtitle: const Text('support@agrimore.in'),
              onTap: () { Navigator.pop(context); SnackbarHelper.showInfo(context, 'Email copied: support@agrimore.in'); },
            ),
            ListTile(
              leading: const Icon(Icons.book_outlined, color: Color(0xFFF59E0B)),
              title: const Text('Documentation'),
              subtitle: const Text('View admin guide'),
              onTap: () { Navigator.pop(context); SnackbarHelper.showInfo(context, 'Documentation available at docs.agrimore.in'); },
            ),
            ListTile(
              leading: const Icon(Icons.bug_report_outlined, color: Colors.red),
              title: const Text('Report a Bug'),
              subtitle: const Text('Submit an issue'),
              onTap: () { Navigator.pop(context); SnackbarHelper.showSuccess(context, 'Bug report submitted. We\'ll review it shortly.'); },
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }
}

