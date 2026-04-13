// lib/screens/admin/marketing/coupon_management_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/themes/app_colors.dart';
import '../../../app/themes/app_text_styles.dart';
import '../../../models/coupon_model.dart';
import '../../../providers/coupon_provider.dart';
import '../../../core/utils/snackbar_helper.dart';
import 'widgets/coupon_card.dart';
import 'add_coupon_screen.dart';

class CouponManagementScreen extends StatefulWidget {
  const CouponManagementScreen({Key? key}) : super(key: key);

  @override
  State<CouponManagementScreen> createState() => _CouponManagementScreenState();
}

class _CouponManagementScreenState extends State<CouponManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _filterIndex = 0; // 0=All, 1=Active, 2=Inactive, 3=Expired
  bool _selectionMode = false;
  final Set<String> _selectedCouponIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CouponProvider>(context, listen: false).loadCoupons();
    });
  }

  void _enterSelectionMode(String id) {
    setState(() {
      _selectionMode = true;
      _selectedCouponIds.add(id);
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      _selectedCouponIds.contains(id)
          ? _selectedCouponIds.remove(id)
          : _selectedCouponIds.add(id);
      if (_selectedCouponIds.isEmpty) _selectionMode = false;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectionMode = false;
      _selectedCouponIds.clear();
    });
  }

  Future<void> _bulkDeleteCoupons(CouponProvider provider) async {
    if (_selectedCouponIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete selected coupons'),
        content: Text(
          'Are you sure you want to delete ${_selectedCouponIds.length} coupon(s)? This action cannot be undone.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      for (final id in _selectedCouponIds) {
        await provider.deleteCoupon(id);
      }

      final deletedCount = _selectedCouponIds.length;
      _clearSelection();
      provider.loadCoupons();

      if (mounted) {
        SnackbarHelper.showSuccess(
          context,
          'Deleted $deletedCount coupon(s)',
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to delete selected coupons');
      }
    }
  }

  List<CouponModel> _filterCoupons(List<CouponModel> coupons) {
    var filtered = coupons;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((coupon) {
        final code = coupon.code.toLowerCase();
        final title = coupon.title.toLowerCase();
        final id = coupon.id.toLowerCase();
        return code.contains(q) || title.contains(q) || id.contains(q);
      }).toList();
    }

    // Apply status filter based on _filterIndex
    switch (_filterIndex) {
      case 1: // Active
        filtered = filtered
            .where((c) => c.isActive && c.validTo.isAfter(DateTime.now()))
            .toList();
        break;
      case 2: // Inactive
        filtered = filtered.where((c) => !c.isActive).toList();
        break;
      case 3: // Expired
        filtered =
            filtered.where((c) => c.validTo.isBefore(DateTime.now())).toList();
        break;
      case 0: // All
      default:
        break;
    }

    // Sort by creation date (newest first) if property exists
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return filtered;
  }

  Widget _filterChip(int index, String label) {
    final selected = _filterIndex == index;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filterIndex = index),
      selectedColor: AppColors.primary,
      backgroundColor: Colors.grey.shade100,
      labelStyle: TextStyle(color: selected ? Colors.white : Colors.black),
    );
  }

  Widget _buildStatsGrid(int total, int active, int inactive, int expired) {
    final stats = [
      {
        'title': 'Total',
        'value': total,
        'icon': Icons.local_offer_rounded,
        'color': AppColors.primary
      },
      {
        'title': 'Active',
        'value': active,
        'icon': Icons.check_circle_rounded,
        'color': Colors.green
      },
      {
        'title': 'Inactive',
        'value': inactive,
        'icon': Icons.pause_circle_filled_rounded,
        'color': Colors.orange
      },
      {
        'title': 'Expired',
        'value': expired,
        'icon': Icons.event_busy_rounded,
        'color': Colors.red
      },
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: stats.map((s) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              Icon(s['icon'] as IconData, color: s['color'] as Color, size: 20),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s['title'].toString(),
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  Text(
                    s['value'].toString(),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _navigateToAddCoupon(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddCouponScreen(),
      ),
    );
  }

  void _navigateToEditCoupon(BuildContext context, CouponModel coupon) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddCouponScreen(coupon: coupon),
      ),
    );
  }

  Future<void> _toggleCouponStatus(BuildContext context, CouponModel coupon) async {
    try {
      await Provider.of<CouponProvider>(context, listen: false)
          .toggleCouponStatus(coupon.id);
      if (context.mounted) {
        SnackbarHelper.showSuccess(
          context,
          'Coupon ${coupon.isActive ? 'disabled' : 'enabled'} successfully',
        );
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarHelper.showError(context, 'Failed to update coupon status');
      }
    }
  }

  void _showDeleteConfirmation(BuildContext context, CouponModel coupon) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.warning_rounded,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Delete Coupon'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete this coupon?',
              style: AppTextStyles.bodyLarge,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.local_offer_rounded,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          coupon.code,
                          style: AppTextStyles.titleSmall.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          coupon.title,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'This action cannot be undone.',
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.red.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              try {
                await Provider.of<CouponProvider>(context, listen: false)
                    .deleteCoupon(coupon.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  SnackbarHelper.showSuccess(
                    context,
                    'Coupon deleted successfully',
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  SnackbarHelper.showError(
                    context,
                    'Failed to delete coupon',
                  );
                }
              }
            },
            icon: const Icon(Icons.delete_rounded),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CouponProvider>(
      builder: (context, couponProvider, child) {
        final allCoupons = couponProvider.coupons;
        final filtered = _filterCoupons(allCoupons);

        final total = allCoupons.length;
        final active =
            allCoupons.where((c) => c.isActive && c.validTo.isAfter(DateTime.now())).length;
        final inactive = allCoupons.where((c) => !c.isActive).length;
        final expired = allCoupons.where((c) => c.validTo.isBefore(DateTime.now())).length;

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            title: _selectionMode
                ? Text('${_selectedCouponIds.length} selected')
                : const Text('Coupon Management'),
            actions: _selectionMode
                ? [
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete Coupons',
                      onPressed: () => _bulkDeleteCoupons(couponProvider),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Cancel Selection',
                      onPressed: _clearSelection,
                    ),
                  ]
                : [
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Refresh',
                      onPressed: couponProvider.loadCoupons,
                    ),
                  ],
            elevation: 0,
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Search bar
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search coupons by code or title...',
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
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Filter chips
                  Wrap(
                    spacing: 8,
                    children: [
                      _filterChip(0, 'All'),
                      _filterChip(1, 'Active'),
                      _filterChip(2, 'Inactive'),
                      _filterChip(3, 'Expired'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Stats grid
                  _buildStatsGrid(total, active, inactive, expired),
                  const SizedBox(height: 12),
                  // Content
                  Expanded(
                    child: Builder(builder: (context) {
                      if (couponProvider.isLoading && filtered.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (couponProvider.error != null) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.red.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Error loading coupons',
                                style: AppTextStyles.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                couponProvider.error!,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () => couponProvider.loadCoupons(),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      if (filtered.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.local_offer_outlined,
                                size: 100,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No coupons found'
                                    : 'No coupons yet',
                                style: AppTextStyles.titleLarge.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'Try adjusting your search'
                                    : 'Create your first coupon to get started',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              if (_searchQuery.isEmpty) ...[
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: () => _navigateToAddCoupon(context),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Create Coupon'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }

                      return RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: () async {
                          couponProvider.loadCoupons();
                          await Future.delayed(const Duration(milliseconds: 300));
                        },
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (ctx, i) {
                            final coupon = filtered[i];
                            final isSelected = _selectedCouponIds.contains(coupon.id);

                            return GestureDetector(
                              onLongPress: () => _enterSelectionMode(coupon.id),
                              child: Stack(
                                children: [
                                  CouponCard(
                                    coupon: coupon,
                                    onEdit: () => _navigateToEditCoupon(context, coupon),
                                    onDelete: () => _showDeleteConfirmation(context, coupon),
                                    onToggle: () => _toggleCouponStatus(context, coupon),
                                  ),
                                  if (_selectionMode)
                                    Positioned(
                                      left: 8,
                                      top: 8,
                                      child: Checkbox(
                                        value: isSelected,
                                        onChanged: (_) => _toggleSelect(coupon.id),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _navigateToAddCoupon(context),
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              'Add Coupon',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            elevation: 4,
          ),
        );
      },
    );
  }
}