import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/themes/app_colors.dart';
import '../../../../app/themes/app_text_styles.dart';
import '../../../../models/user_model.dart';
import 'role_badge.dart';

class UserDetailsModal extends StatelessWidget {
  final UserModel user;
  final VoidCallback onEdit;
  final VoidCallback onClose;

  const UserDetailsModal({
    Key? key,
    required this.user,
    required this.onEdit,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Hero(
                    tag: 'user-${user.uid}',
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: user.photoUrl != null
                          ? ClipOval(
                              child: Image.network(
                                user.photoUrl!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.blue.shade300, Colors.blue.shade600],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  user.initials,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
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
                          user.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        RoleBadge(role: user.role),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Contact Information'),
                    const SizedBox(height: 12),
                    _buildInfoTile(
                      icon: Icons.email_rounded,
                      label: 'Email',
                      value: user.email,
                      onCopy: () => _copyToClipboard(context, user.email),
                    ),
                    if (user.phone != null) ...[
                      const SizedBox(height: 12),
                      _buildInfoTile(
                        icon: Icons.phone_rounded,
                        label: 'Phone',
                        value: user.phone!,
                        onCopy: () => _copyToClipboard(context, user.phone!),
                      ),
                    ],

                    const SizedBox(height: 24),
                    _buildSectionTitle('Account Details'),
                    const SizedBox(height: 12),
                    _buildInfoTile(
                      icon: Icons.fingerprint_rounded,
                      label: 'User ID',
                      value: user.uid,
                      onCopy: () => _copyToClipboard(context, user.uid),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoTile(
                      icon: Icons.calendar_today_rounded,
                      label: 'Joined',
                      value: _formatDate(user.createdAt),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoTile(
                      icon: Icons.login_rounded,
                      label: 'Last Login',
                      value: user.lastLogin != null
                          ? _formatDate(user.lastLogin!)
                          : 'Never logged in',
                    ),
                    const SizedBox(height: 12),
                    _buildInfoTile(
                      icon: user.isActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      label: 'Status',
                      value: user.isActive ? 'Active' : 'Inactive',
                      valueColor: user.isActive ? Colors.green : Colors.red,
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onClose,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Close'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Edit User'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyles.titleMedium.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onCopy,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
          if (onCopy != null)
            IconButton(
              onPressed: onCopy,
              icon: const Icon(Icons.copy_rounded, size: 20),
              color: AppColors.primary,
              tooltip: 'Copy',
            ),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: $text'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
