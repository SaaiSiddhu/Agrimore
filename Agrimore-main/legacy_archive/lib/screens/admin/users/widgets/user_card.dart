import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/themes/app_colors.dart';
import '../../../../app/themes/app_text_styles.dart';
import '../../../../models/user_model.dart';
import 'role_badge.dart';


class UserCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;


  const UserCard({
    Key? key,
    required this.user,
    required this.onTap,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onDelete,
  }) : super(key: key);


  @override
  Widget build(BuildContext context) {
    final daysSinceJoined = DateTime.now().difference(user.createdAt).inDays;
    final lastLoginText = user.lastLogin != null
        ? _formatLastLogin(user.lastLogin!)
        : 'Never logged in';


    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shadowColor: user.isActive
          ? AppColors.primary.withValues(alpha: 0.2)
          : Colors.red.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: user.isActive
              ? AppColors.primary.withOpacity(0.3)  // ← FIXED: Added this line
              : Colors.red.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Header Row
              Row(
                children: [
                  // Avatar
                  Stack(
                    children: [
                      Hero(
                        tag: 'user-${user.uid}',
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: user.isAdmin
                                  ? [Colors.purple.shade400, Colors.purple.shade600]
                                  : [AppColors.primary, AppColors.primary.withOpacity(0.7)],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (user.isAdmin ? Colors.purple : AppColors.primary)
                                    .withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: user.photoUrl != null
                              ? ClipOval(
                                  child: Image.network(
                                    user.photoUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        _buildInitials(),
                                  ),
                                )
                              : _buildInitials(),
                        ),
                      ),
                      // Online indicator
                      if (user.lastLogin != null &&
                          DateTime.now().difference(user.lastLogin!).inMinutes < 5)
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),


                  const SizedBox(width: 16),


                  // User Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                user.name,
                                style: AppTextStyles.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            RoleBadge(role: user.role),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.email_rounded, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                user.email,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (user.phone != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.phone_rounded, size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                user.phone!,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),


                  // Status Badge
                  _buildStatusBadge(),
                ],
              ),


              const SizedBox(height: 16),


              // Stats Row
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      icon: Icons.calendar_today_rounded,
                      label: 'Joined',
                      value: '$daysSinceJoined days ago',
                      color: Colors.blue,
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey.shade300,
                    ),
                    _buildStatItem(
                      icon: Icons.login_rounded,
                      label: 'Last Login',
                      value: lastLoginText,
                      color: Colors.green,
                    ),
                  ],
                ),
              ),


              const SizedBox(height: 16),


              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onToggleStatus,
                      icon: Icon(
                        user.isActive
                            ? Icons.block_rounded
                            : Icons.check_circle_rounded,
                        size: 18,
                      ),
                      label: Text(user.isActive ? 'Deactivate' : 'Activate'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: user.isActive ? Colors.orange : Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_rounded),
                    color: Colors.red,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildInitials() {
    return Center(
      child: Text(
        user.initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }


  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: user.isActive ? Colors.green.shade100 : Colors.red.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: user.isActive ? Colors.green.shade300 : Colors.red.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: user.isActive ? Colors.green : Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            user.isActive ? 'Active' : 'Inactive',
            style: AppTextStyles.bodySmall.copyWith(
              color: user.isActive ? Colors.green.shade700 : Colors.red.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: Colors.grey.shade600,
            fontSize: 10,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.bodySmall.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }


  String _formatLastLogin(DateTime lastLogin) {
    final difference = DateTime.now().difference(lastLogin);


    if (difference.inMinutes < 5) {
      return 'Online now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 30) {
      return '${difference.inDays}d ago';
    } else {
      final months = (difference.inDays / 30).floor();
      return '$months mo ago';
    }
  }
}
