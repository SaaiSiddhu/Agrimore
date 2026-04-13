// lib/screens/admin/banners/banner_management_screen.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/themes/app_colors.dart';
import '../../../app/themes/app_text_styles.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/banner_model.dart';
import '../../../providers/banner_provider.dart';
import 'banner_card.dart';
import 'add_edit_banner_dialog.dart';

class BannerManagementScreen extends StatefulWidget {
  const BannerManagementScreen({Key? key}) : super(key: key);

  @override
  State<BannerManagementScreen> createState() =>
      _BannerManagementScreenState();
}

class _BannerManagementScreenState extends State<BannerManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _filterIndex = 0; // 0: All, 1: Active, 2: Inactive
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BannerProvider>(context, listen: false).loadBanners();
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

  Future<void> _bulkDelete(BannerProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete selected banners'),
        content: Text(
          'Are you sure you want to delete ${_selectedIds.length} banner(s)? This cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
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
      for (final id in _selectedIds.toList()) {
        final banner = provider.banners
            .firstWhere((b) => b.id == id, orElse: () => _emptyBanner());
        if (banner.id.isNotEmpty) {
          await provider.deleteBanner(banner.id, banner.imageUrl);
        }
      }
      _clearSelection();
      SnackbarHelper.showSuccess(context, 'Deleted selected banners');
      await provider.loadBanners();
    } catch (e) {
      SnackbarHelper.showError(context, 'Failed to delete selected banners');
    }
  }

  Future<void> _bulkToggleActive(
      BannerProvider provider, bool activate) async {
    try {
      for (final id in _selectedIds.toList()) {
        final banner = provider.banners
            .firstWhere((b) => b.id == id, orElse: () => _emptyBanner());
        if (banner.id.isNotEmpty && banner.isActive != activate) {
          await provider.toggleBannerStatus(banner.id, activate);
        }
      }
      _clearSelection();
      SnackbarHelper.showSuccess(context, 'Updated selected banners');
      await provider.loadBanners();
    } catch (e) {
      SnackbarHelper.showError(context, 'Failed to update status');
    }
  }

  List<BannerModel> _filterBanners(List<BannerModel> banners) {
    var filtered = banners;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((b) {
        return b.title.toLowerCase().contains(q) ||
            b.subtitle.toLowerCase().contains(q);
      }).toList();
    }

    if (_filterIndex == 1) {
      filtered = filtered.where((b) => b.isActive).toList();
    } else if (_filterIndex == 2) {
      filtered = filtered.where((b) => !b.isActive).toList();
    }

    filtered.sort((a, b) => b.priority.compareTo(a.priority));
    return filtered;
  }

  void _navigateToAddBanner() {
    showDialog(context: context, builder: (_) => const AddEditBannerDialog());
  }

  void _navigateToEditBanner(BannerModel banner) {
    showDialog(
      context: context,
      builder: (_) => AddEditBannerDialog(banner: banner),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BannerProvider>(
      builder: (context, provider, _) {
        final filtered = _filterBanners(provider.banners);

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            elevation: 0,
            title: _selectionMode
                ? Text('${_selectedIds.length} selected')
                : const Text('Banner Management'),
            actions: _selectionMode
                ? [
                    IconButton(
                      icon: const Icon(Icons.check_circle),
                      tooltip: 'Enable',
                      onPressed: () => _bulkToggleActive(provider, true),
                    ),
                    IconButton(
                      icon: const Icon(Icons.pause_circle),
                      tooltip: 'Disable',
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
                      onPressed: provider.loadBanners,
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
                  _buildStatsRow(provider),
                  const SizedBox(height: 12),
                  Expanded(child: _buildContent(provider, filtered)),
                ],
              ),
            ),
          ),
          floatingActionButton: !_selectionMode
              ? FloatingActionButton.extended(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Banner'),
                  backgroundColor: AppColors.primary,
                  onPressed: _navigateToAddBanner,
                )
              : null,
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
            hintText: 'Search banners...',
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
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _filterChip(0, 'All'),
            _filterChip(1, 'Active'),
            _filterChip(2, 'Inactive'),
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

  Widget _buildStatsRow(BannerProvider provider) {
    final total = provider.banners.length;
    final active = provider.banners.where((b) => b.isActive).length;
    final inactive = total - active;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _statCard(
            'Total',
            total.toString(),
            Icons.view_carousel,
            AppColors.primary,
          ),
          const SizedBox(width: 8),
          _statCard(
            'Active',
            active.toString(),
            Icons.check_circle,
            Colors.green,
          ),
          const SizedBox(width: 8),
          _statCard(
            'Inactive',
            inactive.toString(),
            Icons.pause_circle,
            Colors.orange,
          ),
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
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
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
              Text(
                title,
                style:
                    const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              Text(
                value,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BannerProvider provider, List<BannerModel> filtered) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported,
                size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No banners match your search'
                  : 'No banners found',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _navigateToAddBanner,
              icon: const Icon(Icons.add),
              label: const Text('Create Banner'),
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.loadBanners,
      color: AppColors.primary,
      child: ListView.separated(
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) {
          final banner = filtered[i];
          final isSelected = _selectedIds.contains(banner.id);
          return GestureDetector(
            onLongPress: () => _enterSelectionMode(banner.id),
            child: Stack(
              children: [
                BannerCard(
                  banner: banner,
                  onEdit: () => _navigateToEditBanner(banner),
                  onDelete: () => _bulkDelete(provider),
                  onToggle: () => provider.toggleBannerStatus(
                      banner.id, !banner.isActive),
                ),
                if (_selectionMode)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Checkbox(
                      value: isSelected,
                      onChanged: (_) => _toggleSelect(banner.id),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  BannerModel _emptyBanner() {
    return BannerModel(
      id: '',
      title: '',
      subtitle: '',
      imageUrl: '',
      iconName: '',
      targetRoute: '',
      colorHex: '',
      priority: 0,
      isActive: false,
      createdAt: DateTime.now(),
    );
  }
}
