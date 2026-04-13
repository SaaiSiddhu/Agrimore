// lib/screens/admin/section_banners/section_banner_management_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../providers/section_banner_provider.dart';
import 'add_edit_section_banner_dialog.dart';

class SectionBannerManagementScreen extends StatefulWidget {
  const SectionBannerManagementScreen({Key? key}) : super(key: key);

  @override
  State<SectionBannerManagementScreen> createState() => _SectionBannerManagementScreenState();
}

class _SectionBannerManagementScreenState extends State<SectionBannerManagementScreen> {
  int _filterIndex = 0; // 0: All, 1: Active, 2: Inactive

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SectionBannerProvider>(context, listen: false).loadBanners();
    });
  }

  List<SectionBannerModel> _filterBanners(List<SectionBannerModel> banners) {
    if (_filterIndex == 1) {
      return banners.where((b) => b.isActive).toList();
    } else if (_filterIndex == 2) {
      return banners.where((b) => !b.isActive).toList();
    }
    return banners;
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (_) => const AddEditSectionBannerDialog(),
    );
  }

  void _showEditDialog(SectionBannerModel banner) {
    showDialog(
      context: context,
      builder: (_) => AddEditSectionBannerDialog(banner: banner),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SectionBannerProvider>(
      builder: (context, provider, _) {
        final filtered = _filterBanners(provider.banners);

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            elevation: 0,
            title: const Text('Section Banners'),
            actions: [
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
                  _buildFilters(),
                  const SizedBox(height: 12),
                  _buildStats(provider),
                  const SizedBox(height: 12),
                  Expanded(child: _buildContent(provider, filtered)),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('Add Banner'),
            backgroundColor: AppColors.primary,
            onPressed: _showAddDialog,
          ),
        );
      },
    );
  }

  Widget _buildFilters() {
    return Row(
      children: [
        _filterChip(0, 'All'),
        _filterChip(1, 'Active'),
        _filterChip(2, 'Inactive'),
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

  Widget _buildStats(SectionBannerProvider provider) {
    final total = provider.banners.length;
    final active = provider.banners.where((b) => b.isActive).length;
    final inactive = total - active;

    return Row(
      children: [
        _statCard('Total', total.toString(), Icons.image, AppColors.primary),
        const SizedBox(width: 8),
        _statCard('Active', active.toString(), Icons.check_circle, Colors.green),
        const SizedBox(width: 8),
        _statCard('Inactive', inactive.toString(), Icons.pause_circle, Colors.orange),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

  Widget _buildContent(SectionBannerProvider provider, List<SectionBannerModel> filtered) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text('No section banners found', style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _showAddDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Banner'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.loadBanners,
      child: ListView.separated(
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final banner = filtered[index];
          return _SectionBannerCard(
            banner: banner,
            onEdit: () => _showEditDialog(banner),
            onDelete: () => _confirmDelete(provider, banner),
            onToggle: () => provider.toggleBannerStatus(banner.id, !banner.isActive),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(SectionBannerProvider provider, SectionBannerModel banner) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Banner'),
        content: const Text('Are you sure you want to delete this banner?'),
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

    if (confirmed == true) {
      try {
        await provider.deleteBanner(banner.id, banner.imageUrl);
        if (mounted) {
          SnackbarHelper.showSuccess(context, 'Banner deleted');
        }
      } catch (e) {
        if (mounted) {
          SnackbarHelper.showError(context, 'Failed to delete banner');
        }
      }
    }
  }
}

class _SectionBannerCard extends StatelessWidget {
  final SectionBannerModel banner;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const _SectionBannerCard({
    required this.banner,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Image Preview
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: AspectRatio(
              aspectRatio: 2.5,
              child: CachedNetworkImage(
                imageUrl: banner.imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, size: 40),
                ),
              ),
            ),
          ),
          
          // Info Section
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: banner.isActive 
                                  ? Colors.green.withValues(alpha: 0.1) 
                                  : Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              banner.isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: banner.isActive ? Colors.green : Colors.orange,
                              ),
                            ),
                          ),
                          if (banner.showAdBadge) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Ad',
                                style: TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Position: ${banner.position} | After Section: ${banner.displayAfterSection}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      if (banner.hasShopButton) ...[
                        const SizedBox(height: 4),
                        Text(
                          'URL: ${banner.shopNowUrl}',
                          style: TextStyle(fontSize: 12, color: Colors.blue[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Actions
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        banner.isActive ? Icons.pause_circle : Icons.play_circle,
                        color: banner.isActive ? Colors.orange : Colors.green,
                      ),
                      onPressed: onToggle,
                      tooltip: banner.isActive ? 'Deactivate' : 'Activate',
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: onEdit,
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: onDelete,
                      tooltip: 'Delete',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
