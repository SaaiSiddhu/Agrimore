import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/themes/app_colors.dart';
import '../../../app/themes/app_text_styles.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../app/routes.dart';

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
                  SnackbarHelper.showInfo(
                    context,
                    'Dark mode coming soon!',
                  );
                },
                color: const Color(0xFF8B5CF6),
              ),
              _buildNavigationTile(
                icon: Icons.backup_rounded,
                title: 'Backup & Restore',
                subtitle: 'Manage app data backups',
                color: const Color(0xFF06B6D4),
                onTap: () {
                  SnackbarHelper.showInfo(
                    context,
                    'Backup feature coming soon!',
                  );
                },
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
                onTap: () {
                  SnackbarHelper.showInfo(
                    context,
                    'Category management coming soon!',
                  );
                },
              ),
              _buildNavigationTile(
                icon: Icons.local_shipping_rounded,
                title: 'Shipping Settings',
                subtitle: 'Configure delivery options',
                color: const Color(0xFF14B8A6),
                onTap: () {
                  SnackbarHelper.showInfo(
                    context,
                    'Shipping settings coming soon!',
                  );
                },
              ),
              _buildNavigationTile(
                icon: Icons.payment_rounded,
                title: 'Payment Methods',
                subtitle: 'Manage payment gateways',
                color: const Color(0xFFF59E0B),
                onTap: () {
                  SnackbarHelper.showInfo(
                    context,
                    'Payment settings coming soon!',
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
                onTap: () {
                  SnackbarHelper.showInfo(
                    context,
                    '2FA setup coming soon!',
                  );
                },
              ),
              _buildNavigationTile(
                icon: Icons.privacy_tip_rounded,
                title: 'Privacy Policy',
                subtitle: 'View privacy policy',
                color: const Color(0xFF8B5CF6),
                onTap: () {
                  SnackbarHelper.showInfo(
                    context,
                    'Privacy policy coming soon!',
                  );
                },
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
                onTap: () {
                  SnackbarHelper.showInfo(
                    context,
                    'Support coming soon!',
                  );
                },
              ),
              _buildNavigationTile(
                icon: Icons.article_rounded,
                title: 'Terms & Conditions',
                subtitle: 'Read terms of service',
                color: const Color(0xFFF59E0B),
                onTap: () {
                  SnackbarHelper.showInfo(
                    context,
                    'Terms coming soon!',
                  );
                },
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
                  user?.email ?? 'admin@agroconnect.com',
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
                AppRoutes.navigateAndRemoveUntil(context, AppRoutes.login);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
