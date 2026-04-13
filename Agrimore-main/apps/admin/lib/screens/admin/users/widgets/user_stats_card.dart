import 'package:flutter/material.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

class UserStatsCard extends StatelessWidget {
  final int totalUsers;
  final int activeUsers;
  final int adminUsers;
  final int newUsersToday;

  const UserStatsCard({
    Key? key,
    required this.totalUsers,
    required this.activeUsers,
    required this.adminUsers,
    required this.newUsersToday,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.people_rounded,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: 12),
              Text(
                'User Statistics',
                style: AppTextStyles.titleLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Total', totalUsers.toString(), Icons.group_rounded),
              _buildDivider(),
              _buildStatItem('Active', activeUsers.toString(), Icons.check_circle_rounded),
              _buildDivider(),
              _buildStatItem('Admins', adminUsers.toString(), Icons.admin_panel_settings_rounded),
              _buildDivider(),
              _buildStatItem('New Today', newUsersToday.toString(), Icons.person_add_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 60,
      color: Colors.white30,
    );
  }
}
