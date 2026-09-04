// lib/screens/admin/users/user_management_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

import '../../../providers/admin_provider.dart';
import 'edit_user_screen.dart';
import 'widgets/user_card.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({Key? key}) : super(key: key);

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _filterIndex = 0; // 0: All, 1: Active, 2: Inactive, 3: Admins, 4: Users
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).listenToUsers();
    });
  }

  void _enterSelectionMode(String id) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(id);
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      if (_selectedIds.isEmpty) _selectionMode = false;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _bulkToggleActive(AdminProvider provider, bool activate) async {
    try {
      for (final id in _selectedIds) {
        await provider.toggleUserStatus(id, activate);
      }
      _clearSelection();
      SnackbarHelper.showSuccess(context, 'Updated selected users');
    } catch (e) {
      SnackbarHelper.showError(context, 'Failed to update users');
    }
  }

  Future<void> _bulkDelete(AdminProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete selected users'),
        content: Text(
          'Are you sure you want to delete ${_selectedIds.length} user(s)? This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      for (final id in _selectedIds) {
        await provider.deleteUser(id);
      }
      _clearSelection();
      SnackbarHelper.showSuccess(context, 'Deleted selected users');
    } catch (e) {
      SnackbarHelper.showError(context, 'Failed to delete selected users');
    }
  }

  // ✅ Convert List<Map> -> List<UserModel>
  List<UserModel> _mapToUserModels(List<Map<String, dynamic>> rawUsers) {
    return rawUsers.map((data) {
      DateTime? parseTimestamp(dynamic value) {
        if (value == null) return null;
        if (value is Timestamp) return value.toDate();
        if (value is DateTime) return value;
        return null;
      }

      return UserModel(
        uid: data['id'] ?? '',
        name: data['name'] ?? 'Unknown User',
        email: data['email'] ?? '',
        phone: data['phone'],
        photoUrl: data['photoUrl'],
        role: data['role'] ?? 'user',
        createdAt: parseTimestamp(data['createdAt']) ?? DateTime.now(),
        lastLogin: parseTimestamp(data['lastLogin']),
        isActive: data['isActive'] ?? true,
        metadata: data['metadata'],
      );
    }).toList();
  }

  List<UserModel> _filterUsers(List<UserModel> users) {
    var filtered = users;

    // 🔍 Search
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered
          .where((u) =>
              u.name.toLowerCase().contains(query) ||
              u.email.toLowerCase().contains(query))
          .toList();
    }

    // 🚫 Exclude specific roles from the generic "Users" view
    filtered = filtered.where((u) => u.role == 'user' || u.role == 'admin').toList();

    // 🔄 Filter by category
    switch (_filterIndex) {
      case 1:
        filtered = filtered.where((u) => u.isActive).toList();
        break;
      case 2:
        filtered = filtered.where((u) => !u.isActive).toList();
        break;
      case 3:
        filtered = filtered.where((u) => u.role == 'admin').toList();
        break;
      case 4:
        filtered = filtered.where((u) => u.role != 'admin').toList();
        break;
    }

    filtered.sort((a, b) => a.name.compareTo(b.name));
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProvider>(
      builder: (context, provider, _) {
        final allUserMaps = provider.users; // ✅ List<Map<String, dynamic>>
        final allUsers = _mapToUserModels(allUserMaps); // convert to List<UserModel>
        final filteredUsers = _filterUsers(allUsers);

        final total = allUsers.length;
        final active = allUsers.where((u) => u.isActive).length;
        final admins = allUsers.where((u) => u.role == 'admin').length;

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            title: _selectionMode
                ? Text('${_selectedIds.length} selected')
                : const Text('User Management'),
            actions: _selectionMode
                ? [
                    IconButton(
                      icon: const Icon(Icons.check_circle_outline),
                      tooltip: 'Activate',
                      onPressed: () => _bulkToggleActive(provider, true),
                    ),
                    IconButton(
                      icon: const Icon(Icons.pause_circle_outline),
                      tooltip: 'Deactivate',
                      onPressed: () => _bulkToggleActive(provider, false),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete',
                      onPressed: () => _bulkDelete(provider),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Cancel',
                      onPressed: _clearSelection,
                    ),
                  ]
                : [
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: provider.listenToUsers,
                    ),
                  ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildSearchAndFilters(),
                  const SizedBox(height: 12),
                  _buildStatsRow(total, active, admins),
                  const SizedBox(height: 12),
                  Expanded(child: _buildContent(provider, filteredUsers)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchAndFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value.trim()),
          decoration: InputDecoration(
            hintText: 'Search users by name or email...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _filterChip(0, 'All'),
            _filterChip(1, 'Active'),
            _filterChip(2, 'Inactive'),
            _filterChip(3, 'Admins'),
            _filterChip(4, 'Users'),
          ],
        ),
      ],
    );
  }

  Widget _filterChip(int index, String label) {
    final selected = _filterIndex == index;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filterIndex = index),
        selectedColor: AppColors.primary,
        backgroundColor: Colors.grey.shade100,
        labelStyle: TextStyle(color: selected ? Colors.white : Colors.black),
      ),
    );
  }

  Widget _buildStatsRow(int total, int active, int admins) {
    final inactive = total - active;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _statCard('Total', total.toString(), Icons.people, AppColors.primary),
          const SizedBox(width: 8),
          _statCard('Active', active.toString(), Icons.check_circle, Colors.green),
          const SizedBox(width: 8),
          _statCard('Inactive', inactive.toString(), Icons.pause_circle, Colors.orange),
          const SizedBox(width: 8),
          _statCard('Admins', admins.toString(), Icons.admin_panel_settings, Colors.purple),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent(AdminProvider provider, List<UserModel> users) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_alt_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text(
              _searchQuery.isNotEmpty ? 'No users match your search' : 'No users found',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.listenToUsers,
      color: AppColors.primary,
      child: ListView.separated(
        itemCount: users.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) {
          final user = users[i];
          final isSelected = _selectedIds.contains(user.uid);

          return GestureDetector(
            onLongPress: () => _enterSelectionMode(user.uid),
            child: Stack(
              children: [
                UserCard(
                  user: user,
                  onTap: () => _navigateToEditUser(user), // Navigate to edit on tap
                  onEdit: () => _navigateToEditUser(user),
                  onToggleStatus: () => provider.toggleUserStatus(user.uid, !user.isActive),
                  onDelete: () async {
                    await provider.deleteUser(user.uid);
                    SnackbarHelper.showSuccess(context, 'User deleted');
                  },
                ),
                if (_selectionMode)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Checkbox(
                      value: isSelected,
                      onChanged: (_) => _toggleSelect(user.uid),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _navigateToEditUser(UserModel user) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => EditUserScreen(user: user)));
  }
}